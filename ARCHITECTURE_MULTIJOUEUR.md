# Guide d'Architecture Multijoueur pour Uma Racing

## 📋 Table des matières
1. Comment ça fonctionne
2. Structure des fichiers
3. Flow du jeu
4. Devenir online vraiment
5. Questions fréquentes

---

## 1️⃣ Comment ça fonctionne

### Système CLIENT-SERVER

Le multijoueur dans Godot fonctionne ainsi:

```
Host (Serveur)                    Clients
┌─────────────┐                 ┌─────────┐
│  Peer ID 1  │ ◄──────RPC───► │ Peer 2  │
│  (L'autorité) │                 └─────────┘
│ - Valide les │                 ┌─────────┐
│   actions    │ ◄──────RPC───► │ Peer 3  │
│ - Synchronise│                 └─────────┘
│   l'état     │                 ┌─────────┐
└─────────────┘ ◄──────RPC───► │ Peer 4  │
                                └─────────┘
```

**Qui est le serveur?**
- Le joueur qui clique "CRÉER PARTIE"
- C'est lui qui valide les actions

**Qui sont les clients?**
- Les joueurs qui cliquent "REJOINDRE"
- Ils envoient leurs actions au serveur
- Le serveur répond à tous

### Les 3 concepts clés

#### 1. **Peer ID** (identifiant du joueur)
```gdscript
var my_id = multiplayer.get_unique_id()
# Retourne: 1 (si serveur) ou 2, 3, 4... (si client)
```

#### 2. **RPC** (Remote Procedure Call = "appel distant")
```gdscript
# Appeler une fonction sur TOUS les joueurs
rpc("activate_skill", skill_id)

# Appeler une fonction SEULEMENT sur le serveur (peer 1)
rpc_id(1, "activate_skill", skill_id)

# Appeler sur un client spécifique
rpc_id(2, "update_position", x, y)
```

#### 3. **MultiplayerSynchronizer** (synchronisation auto)
- Pour les données qui changent SOUVENT (position, endurance)
- Synchronise automatiquement sans RPC

---

## 2️⃣ Structure des fichiers

```
uma-jam/
├─ scripts/
│  ├─ GameData.gd          ← Données du joueur LOCAL (perso, deck)
│  ├─ NetworkManager.gd    ← Le cœur du multijoueur
│  ├─ GameManager.gd       ← Transitions entre scènes
│  ├─ MainMenu.gd          ← Menu principal
│  ├─ Matchmaking.gd       ← Créer/rejoindre partie
│  ├─ Lobby.gd             ← Affiche les joueurs + "Prêt"
│  └─ Race.gd              ← La course (à développer)
│
├─ scenes/
│  ├─ menu/
│  │  └─ Main_Menu.tscn     ← Menu de démarrage
│  ├─ lobby/
│  │  ├─ Matchmaking.tscn   ← Interface matchmaking
│  │  └─ Lobby.tscn         ← Interface lobby
│  └─ race/
│     └─ Race.tscn          ← Interface course
│
└─ project.godot            ← Configuration du projet
```

### Ordre de chargement

```
project.godot
  ↓
Autoloads (singletons):
  - GameData.gd       ✓ Dès le démarrage
  - NetworkManager.gd ✓ Dès le démarrage
  - GameManager.gd    ✓ Dès le démarrage
  ↓
Main_Menu.tscn (scène initiale)
```

---

## 3️⃣ Flow du jeu (comment ça s'enchaîne)

### Scénario: 2 joueurs décident de s'affronter

```
JOUEUR A (Host)              JOUEUR B (Client)
        ↓                            ↓
[MainMenu]                    [MainMenu]
        ↓                            ↓
    Clique JOUER              Clique JOUER
        ↓                            ↓
[Matchmaking]                 [Matchmaking]
        ↓                            ↓
  Clique                      Rentre IP du serveur
  "CRÉER"                      (ex: 127.0.0.1)
        ↓                            ↓
 start_server()              join_server("127.0.0.1")
        ↓                            ↓
[Lobby] ← ─ ─ ─ ─ ─ RPC ─ ─ ─ ▶ [Lobby]
  (Serveur)      (Sync)       (Client)
  "2/2 joueurs"   Liste des   "2/2 joueurs"
        │          joueurs      │
        │                       │
 Clique ◀ ─ ─ ─ ─ PlayerReady ─│
"PRÊT" (RPC)                   Clique
  │    ─ ─ ─ ─ ▶ Sync                "PRÊT"
        │        joueurs      │   ─ ▶
        │                     │
        └──────▶ [Race] ◀─────┘
         (Tous prêts)
         start_race() (RPC)
```

---

## 4️⃣ Utilisation en PRACTICE LOCAL

C'est comme ça qu'on teste pour l'instant:

### Test 1: Un host seul
```
1. Lancer le jeu
2. Clique "JOUER"
3. Clique "CRÉER PARTIE"
4. → Lobby vide (en attente de clients)
   (Ou clique Ctrl+Alt+2 pour ouvrir une 2ème fenêtre)
```

### Test 2: Deux instances locales
```
Terminal 1:
$ godot --main-scene res://scenes/menu/Main_Menu.tscn

Terminal 2:
$ godot --main-scene res://scenes/menu/Main_Menu.tscn

Fenêtre 1:
1. JOUER → CRÉER PARTIE
   (Note l'IP affichée, ex: 127.0.0.1)

Fenêtre 2:
1. JOUER → Rentre 127.0.0.1 → REJOINDRE
   (Doit se connecter au host)
```

---

## 5️⃣ Devenir ONLINE vraiment

Pour du multijoueur **sur internet**, il faut un **serveur dédié**. 3 approches:

### Approche 1: Serveur dédié (Recommandé 🌟)
- Tu héberges un serveur Node.js/Python/C#
- Les joueurs se connectent à TON serveur
- Coût: ~$5-10/mois (DigitalOcean, AWS, Heroku)

```gdscript
# Remplacer dans NetworkManager.gd
const SERVER_IP = "ma-app.herokuapp.com"  # Ton serveur
const PORT = 8080
```

### Approche 2: Relay/Cloud (Plus facile 🎮)
- Utiliser un service: **Nakama**, **Photon**, **PlayFab**
- Ils gèrent le matchmaking + relay automatiquement
- Intégration simple

### Approche 3: P2P avec signaling (Complexe)
- Utiliser WebRTC
- Moins stable pour les jeux

**Pour maintenant, continue avec le LOCAL et lorsque tu seras prêt à aller online, on implémentera un vrai serveur.**

---

## ❓ Questions Fréquentes

### Q: Comment envoyer des données entre joueurs?
```gdscript
# Via RPC (action ponctuelle):
rpc("activate_skill", skill_id)  # Tous le voient

# Via MultiplayerSynchronizer (continu):
# Dans le nœud Horse.tscn:
# - Ajouter un MultiplayerSynchronizer
# - "Ajouter propriété" → position, vitesse, endurance
# → Sera synchronisé automatiquement
```

### Q: Comment savoir qui a gagné?
```gdscript
# Le serveur compte les tours
# Quand quelqu'un termine 3 tours:
rpc("player_finished", peer_id, time)  # Broadcast à tous
```

### Q: Comment gérer les déconnexions?
```gdscript
# Déjà fait dans NetworkManager.gd:
multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Si un joueur part:
# 1. On le retire de players_connected
# 2. On synchronise la nouvelle liste
# 3. Si la course a commencé: le déclasser
```

### Q: Je veux ajouter un chat?
```gdscript
# Utiliser RPC aussi:
@rpc
func send_message(player_name: str, message: str):
    chat_display.add_text("[%s]: %s\n" % [player_name, message])

# L'appeler:
rpc("send_message", GameData.player_name, "Hello!")
```

---

## 🛠️ Prochaines étapes

Quand tu seras prêt, on va:
1. ✅ **Créer les chevaux** avec mouvement basique
2. ✅ **Synchroniser les positions** via MultiplayerSynchronizer
3. ✅ **Créer le système de skills** (5 cartes, endurance)
4. ✅ **Créer la sélection de personnage/deck**
5. ✅ **Implémenter l'endurance** qui se régénère
6. ✅ **Créer le circuit** (fond, piste, tours)

---

**Des questions sur cette architecture? Demande-moi! 😊**
