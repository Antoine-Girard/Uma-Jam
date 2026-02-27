# Architecture Multijoueur - Diagrammes Visuels

## 1. Flow de connexion

```
┌──────────────────────────────────────────────────────────┐
│ JOUEUR 1 (Host)          JOUEUR 2 (Client)               │
├──────────────────────────────────────────────────────────┤
│                                                           │
│ [MainMenu]               [MainMenu]                      │
│      ↓                        ↓                           │
│   JOUER                    JOUER                         │
│      ↓                        ↓                           │
│ [Matchmaking]            [Matchmaking]                   │
│      ↓                        ↓                           │
│  CRÉER PARTIE             IP: 127.0.0.1                 │
│      ↓                        ↓                           │
│  start_server()          join_server()                   │
│      ↓                ◄──── TCP ────►              │
│      ├─ Peer ID = 1         ↓                           │
│      │                  Connecté!                        │
│      │                      ↓                            │
│      └──────── RPC ──→ _notify_new_player()             │
│              (sync)    ◄─── RPC ────┘                   │
│      ↓                        ↓                           │
│ [Lobby]◄──── BROADCAST ───[Lobby]                      │
│  sync_player_list()                                      │
│      ↓                        ↓                           │
│   PRÊT?                     PRÊT?                        │
│      ├─ Peer 1 Ready    Peer 2 Ready                    │
│      │      ↓                ↓                           │
│      └─ RPC _player_confirmed_ready                     │
│              ├─ rpc_id(1, "...")    rpc_id(1, "...")    │
│              │      ↓ [Serveur valide]                  │
│              └─ rpc("start_race") ──────→              │
│                    ↓                    ↓                │
│              [Race]◄────── Broadcast ──[Race]           │
│                    ↓                    ↓                │
│                 START                START               │
│                    ↓                    ↓                │
│           🏇 COURSE 🏇         🏇 COURSE 🏇            │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## 2. Architecture interne

```
┌─────────────────────────────────────────────────────────────┐
│ Godot Multiplayer System                                     │
└─────────────────────────────────────────────────────────────┘
            ↑                          ↑
            │                          │
       [NetworkManager]          [MultiplayerAPI]
       ✓ RPC functions           ✓ Peer system
       ✓ Player management       ✓ Authority
       ✓ Game flow               ✓ Signals

                    ↓
            ┌───────┴───────┐
            │               │
        [Host]         [Clients]
       (Peer 1)     (Peer 2,3,4...)
            │               │
       ✓ Valide       ✓ Send requests
       ✓ Broadcasts  ✓ Receive updates
       ✓ Authority   ✓ Sync with host
```

## 3. État des joueurs

```
Host Console:
┌─────────────────────────────────────────────┐
│ NetworkManager.players_connected            │
│ ─────────────────────────────────────────── │
│ {                                           │
│   1: {"name": "Alice", "ready": true},     │
│   2: {"name": "Bob", "ready": false},      │
│   3: {"name": "Charlie", "ready": true}    │
│ }                                           │
└─────────────────────────────────────────────┘
         ↓ RPC: sync_player_list() ↓
         │                         │
    ┌────┴──────────┐       ┌──────┴────────┐
    │ Client 2      │       │ Client 3      │
    │ (Bob)         │       │ (Charlie)     │
    │               │       │               │
    │ Reçoit et     │       │ Reçoit et     │
    │ affiche:      │       │ affiche:      │
    │ ✓ Alice       │       │ ✓ Alice       │
    │ ○ Bob (self)  │       │ ○ Bob         │
    │ ✓ Charlie     │       │ ✓ Charlie     │
    └───────────────┘       └───────────────┘
```

## 4. Communication RPC

```
JOUEUR ENVOIE ACTION:
└─ Input: Clique bouton "PRÊT"
   ↓
   EmetEvent: NetworkManager.player_ready()
   ↓
   rpc_id(1, "_player_confirmed_ready", my_id)
   ↓
┌─────────────────────────────────────────────┐
│ Réseau (TCP via ENet)                       │
│ [Alice's PRÊT request] ──────→ [Host]       │
└─────────────────────────────────────────────┘
   ↓
   SERVEUR TRAITE:
   _player_confirmed_ready(2)  ← received
   ├─ players_connected[2]["ready"] = true
   ├─ Tous prêts? YES
   └─ rpc("start_race")
      ↓
┌─────────────────────────────────────────────┐
│ Réseau (TCP via ENet)                       │
│ [start_race() broadcast] ──────→ [Clients]  │
└─────────────────────────────────────────────┘
   ↓
   CLIENTS REÇOIVENT & EXÉCUTENT:
   [Alice] start_race() ✓
   [Bob]   start_race() ✓
```

## 5. Classes & Hiérarchie

```
GameData (Autoload / Singleton)
├─ selected_character: String
├─ character_ultimate: String
├─ character_passive: String
├─ selected_deck: Array[String]
├─ player_id: int
├─ player_name: String
└─ Methods:
   ├─ select_character(name, ult, pass)
   ├─ set_deck(cards: Array) → bool
   ├─ get_character_info() → Dictionary
   ├─ get_deck() → Array
   └─ reset()

NetworkManager (Autoload / Singleton)
├─ is_server: bool
├─ players_connected: Dictionary
├─ PORT: const 8080
├─ MAX_PLAYERS: const 6
├─ Signals:
│  ├─ peer_connected(id, name)
│  ├─ peer_disconnected(id)
│  ├─ server_started
│  ├─ client_connected
│  └─ player_list_updated(players)
├─ Methods:
│  ├─ start_server()
│  ├─ join_server(ip)
│  ├─ add_player(id, name)
│  ├─ player_ready()
│  ├─ all_players_ready()
│  ├─ get_player_count()
│  └─ am_server()
└─ RPC Methods:
   ├─ sync_player_list(Dictionary)
   ├─ _notify_new_player(String)
   ├─ start_race()
   └─ _player_confirmed_ready(int)

GameManager (Autoload)
├─ Signals:
│  └─ scene_changed(name)
└─ Methods:
   ├─ go_to_main_menu()
   ├─ go_to_character_select()
   ├─ go_to_deck_select()
   ├─ go_to_matchmaking()
   ├─ go_to_lobby()
   ├─ go_to_race()
   └─ go_to_results()
```

## 6. Autorité Godot

```
┌──────────────────────────────────────────────┐
│ Qui contrôle quoi? (Authority)               │
├──────────────────────────────────────────────┤
│                                              │
│ ✓ RPC avec @rpc("authority", "call_local")  │
│   → Seulement le serveur peut l'exécuter     │
│   → Mais tout le monde est notifié           │
│                                              │
│ ✓ RPC avec @rpc("any_peer")                 │
│   → N'importe qui peut l'appeler             │
│   → Mais le serveur décide                   │
│                                              │
│ ✓ MultiplayerSynchronizer                   │
│   → Le serveur est maître de vérité          │
│   → Les clients reçoivent les updates        │
│                                              │
└──────────────────────────────────────────────┘
```

## 7. Cycle de vie d'une partie

```
┌─────────────────────────────────────────────────────────┐
│ Étapes du jeu                                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Stage 1: SELECTION (LOCAL)                             │
│  Player 1: Choisit perso → GameData.select_character() │
│  Player 1: Choisit deck → GameData.set_deck()          │
│  (Pas de réseau ici)                                    │
│       ↓                                                  │
│ Stage 2: MATCHMAKING (Réseau ON)                       │
│  Player 1: Créé serveur → NetworkManager.start_server()│
│  Player 2: Rejoint → NetworkManager.join_server(ip)    │
│       ↓                                                  │
│ Stage 3: LOBBY (Réseau)                                │
│  Affiche liste des joueurs                             │
│  Players cliquent "PRÊT"                               │
│  Serveur vérifie tout_pret()                          │
│       ↓                                                  │
│ Stage 4: RACE (Réseau + Sync)                          │
│  rpc("start_race") lancé                               │
│  Les chevaux commencent (synchronisé)                  │
│  Skills activés via RPC                               │
│       ↓                                                  │
│ Stage 5: RESULTS (Réseau)                              │
│  Gagnant déterminé                                      │
│  Afficher classement                                    │
│  Retourner au menu                                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

**C'est compréhensible? Des questions sur ce diagramme?**
