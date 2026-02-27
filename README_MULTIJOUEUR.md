# 📚 Récapitulatif - Architecture Multijoueur Uma Racing

## ✅ Qu'est-ce qu'on a créé?

### Autoloads (Singletons - disponibles partout)
1. **GameData.gd** - Stocke tes données locales (perso, deck)
2. **NetworkManager.gd** - Gère tout le multijoueur (connexion, RPC, joueurs)
3. **GameManager.gd** - Transitions entre scènes

### Scripts pour les scènes
- **MainMenu.gd** - Menu principal
- **Matchmaking.gd** - Créer/rejoindre partie
- **Lobby.gd** - Affiche joueurs + bouton "Prêt"
- **Race.gd** - La course (à développer)

### Scènes (.tscn)
- **scenes/menu/Main_Menu.tscn** - Interface menu
- **scenes/lobby/Matchmaking.tscn** - Interface matchmaking
- **scenes/lobby/Lobby.tscn** - Interface lobby
- **scenes/race/Race.tscn** - Interface course

### Documentation
- **ARCHITECTURE_MULTIJOUEUR.md** - Explications détaillées
- **GUIDE_TEST_RAPIDE.md** - Comment tester
- **DIAGRAMMES.md** - Visualisations
- **README_MULTIJOUEUR.md** - Ce fichier

---

## 🎯 Comment ça fonctionne (résumé)

### Phase 1: Sélection (LOCAL - pas de réseau)
```gdscript
# Quand tu sélectionnes un perso:
GameData.select_character("Uma", "Final Spurt", "Natural Born Runner")

# Quand tu sélectionnes un deck:
GameData.set_deck(["Sprint", "Dash", "Barrier", "Heal", "Boost"])

# Tes données sont stockées LOCALEMENT jusqu'au matchmaking
```

### Phase 2: Matchmaking (ONLINE - connexion réseau)
```gdscript
# Tu es le HOST:
NetworkManager.start_server()  # Crée un serveur sur port 8080

# Ton ami est CLIENT:
NetworkManager.join_server("127.0.0.1")  # Se connecte à toi
```

### Phase 3: Lobby (ONLINE - attente)
```gdscript
# Vous voyez la liste des joueurs
# Vous cliquez "PRÊT"
NetworkManager.player_ready()  # Notifie le serveur

# Quand TOUS sont prêts → Démarrage automatique de la course
```

### Phase 4: Course (ONLINE - synchronisé)
```gdscript
# Votre chevaux se bougent (synchronisé via MultiplayerSynchronizer)
# Vous activez des skills via RPC
rpc("activate_skill", skill_id)  # Tout le monde le voit

# Le serveur compte les tours et détermine le gagnant
```

---

## 🔧 Clés du système

### 1️⃣ RPC (Remote Procedure Call) - Pour les actions

```gdscript
# Appeler UNE FONCTION sur un autre joueur

# Sur TOUS les joueurs:
rpc("activate_skill", skill_id)

# Seulement sur le SERVEUR:
rpc_id(1, "validate_action", player_id)

# Sur UN CLIENT spécifique:
rpc_id(2, "update_player_position", x, y)
```

### 2️⃣ MultiplayerSynchronizer - Pour les données continues

```
À ajouter dans les scènes:
[Horse.tscn]
├─ Node2D (Horse)
├─ MultiplayerSynchronizer
│  └─ Propriétés synchronisées:
│     ├─ position
│     ├─ velocity
│     ├─ stamina
│     ├─ current_lap
│     └─ ...

→ Ces données se synchronisent AUTOMATIQUEMENT!
```

### 3️⃣ Autorité - Qui contrôle quoi

```gdscript
# Seulement le SERVEUR exécute ça:
@rpc("authority", "call_local")
func start_race():
    # Code du serveur
    print("Course lancée!")

# N'IMPORTE QUI peut l'appeler, mais le résultat est centralisé:
@rpc("any_peer")
func request_skill(skill_id: int):
    # Le serveur valide et décide
    if is_authorized(skill_id):
        rpc("skill_activated", skill_id)
```

---

## 📡 Flux de données entre joueurs

```
Joueur A (Input: "JE CLIQUE PRÊT")
    │
    ├─ rpc_id(1, "_player_confirmed_ready", my_id)
    │       │
    │       ▼ [Réseau TCP/ENet]
    │
Serveur (Valide & Traite)
    │
    ├─ all_players_ready() → true?
    │
    └─ rpc("start_race")  ←─ Broadcast
        │
        ├─▶ [Réseau] Joueur A reçoit
        │
        └─▶ [Réseau] Joueur B reçoit
            │        │
            ▼        ▼
         [Race]   [Race]
```

---

## 📊 État des joueurs (Dictionary)

```gdscript
# Stocké sur le serveur:
NetworkManager.players_connected = {
    1: {
        "name": "Alice",
        "ready": true,
        "character": "Uma",
        "deck": ["Sprint", "Dash", ...],
        "position": Vector2(100, 200),
        "stamina": 80
    },
    2: {
        "name": "Bob",
        "ready": false,
        "character": "Mejiro McQueen",
        "deck": ["Burst", "Shield", ...],
        "position": Vector2(110, 200),
        "stamina": 95
    },
    ...
}

# Synchronisé à TOUS via RPC:
rpc("sync_player_list", NetworkManager.players_connected)
```

---

## 🧪 Tester le système

### Test Local (sur le même PC)
```bash
# Terminal 1: Lancer Godot instance 1
godot

# Terminal 2: Lancer Godot instance 2 (optionnel)
godot

# Dans Godot 1:
1. Run Project
2. JOUER → CRÉER PARTIE

# Dans Godot 2 (ou nouvelle fenêtre):
1. Run Project
2. JOUER → IP: 127.0.0.1 → REJOINDRE
```

### Test Réseau (différents PC)
```bash
# PC 1 (Host):
1. Récuper ton IP locale: ipconfig → IPv4 Address (ex: 192.168.1.100)
2. JOUER → CRÉER PARTIE

# PC 2 (Client):
1. Rentre l'IP du host: 192.168.1.100
2. JOUER → REJOINDRE

Note: Les PCs doivent être sur le MÊME réseau (wifi/cable)
```

---

## 🚀 Prochaines étapes

### Quand tu seras prêt pour développer:

1. **Créer les chevaux** (Horse.tscn)
   - Modèle 3D ou sprite 2D
   - Script pour le mouvement

2. **Synchroniser les positions** via MultiplayerSynchronizer
   - Position X/Y
   - Direction
   - Animation

3. **Système de skills**
   - 5 cartes du deck
   - Activation via UI
   - Consommation d'endurance

4. **Endurance**
   - Diminue quand on utilise un skill
   - Se régénère lentement
   - Synchronisé pour tous

5. **Circuit/Piste**
   - Zone de départ
   - 3 tours à faire
   - Détection du gagnant

6. **Sélection de personnage/deck**
   - Interface avant matchmaking
   - Chaque perso a ulti + passif
   - Sauvegarde du choix

---

## ❓ Questions importantes avant de continuer

1. **Comment synchroniser les positions des chevaux?**
   - Réponse: MultiplayerSynchronizer (automatique)

2. **Comment valider les actions des joueurs?**
   - Réponse: Le serveur valide sur RPC reçues

3. **Comment gérer les déconnexions?**
   - Réponse: Les callbacks `peer_disconnected` les retirent

4. **Comment faire du vraie online (sur internet)?**
   - Réponse: Un serveur dédié (Node.js, Godot Server, etc)

---

## 📚 Fichiers importants à consulter

1. **NetworkManager.gd** - Cœur du système
   - Lis les commentaires pour comprendre chaque fonction
   - 7 fonctions principales bien expliquées

2. **GameData.gd** - Données du joueur
   - Sections commentées
   - Méthodes faciles à utiliser

3. **ARCHITECTURE_MULTIJOUEUR.md** - Document détaillé
   - Explications approfondies
   - Diagrammes du flow

4. **GUIDE_TEST_RAPIDE.md** - Comment tester
   - Pas à pas pour reproduire
   - Checklist de vérification

---

## 💡 Conseils de développement

1. **Always test local first**
   - 2 instances du jeu sur le même PC
   - C'est plus rapide que différents PCs

2. **Lire la console**
   - (Godot Window → Toggle Bottom Panel)
   - Les logs te disent EXACTEMENT ce qui passe

3. **Commenter ton code**
   - C'est déjà fait dans les fichiers fournis
   - Continue comme ça!

4. **Ne pas modifier les constantes PORT/MAX_PLAYERS**
   - À moins que tu saches vraiment ce que tu fais

5. **Faire des commits Git régulièrement**
   - Des petits pas = plus facile à déboguer

---

## 🎓 Concepts Godot à comprendre

- [ ] Autoloads / Singletons
- [ ] Signals
- [ ] RPC (Remote Procedure Call)
- [ ] Peer ID
- [ ] MultiplayerAPI
- [ ] MultiplayerSynchronizer
- [ ] Node ownership

---

## 📞 Si quelque chose ne marche pas

**Regarde la console (F5 depuis Godot):**
- `[NetworkManager]` = messages du réseau
- `[Matchmaking]` = messages matchmaking
- `[Lobby]` = messages lobby
- `[Race]` = messages race

**Problèmes courants:**
1. "ERREUR: Impossible de créer le serveur" → Port 8080 utilisé
2. "Le client ne se connecte pas" → Mauvaise IP ou firewall
3. "Rien ne s'affiche" → Console pas visible (F5)

---

## 🎉 Félicitations!

Tu as maintenant une **structure complète de multijoueur** qui:
- ✅ Créé et rejoint des serveurs
- ✅ Synchronise les joueurs
- ✅ Gère le flow Lobby → Course
- ✅ Est prêt pour le gameplay

**C'est juste le fondement du château. Le vrai craft commence maintenant!** 🏇

---

Pour continuer: demande-moi ce que tu veux faire en priorité!
- Créer les chevaux?
- Créer le système de skills?
- Implémenter le circuit?
- Autre?

*Je suis là pour t'aider à chaque étape!* 😊
