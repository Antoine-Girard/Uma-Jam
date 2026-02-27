# 🧪 GUIDE TEST RAPIDE - Multijoueur Uma Racing

## Test 1: Démarrer le serveur (Host)

```
1. Ouvrir Godot
2. Ouvrir le projet "Uma Jam"
3. Cliquer "Run Project" (ou F5)

→ Fenêtre du jeu s'ouvre

4. Clique "JOUER"
5. Clique "CRÉER PARTIE"

✓ Tu vois "Serveur lancé!"
✓ Status: "En attente de 1 joueur(s)"
✓ Tu es envoyé au Lobby
✓ Tu vois "1 / 6 joueurs connectés"
```

## Test 2: Rejoindre le serveur (Client) - Même PC

```
1. Cliquer sur l'onglet "Run" → Cliquer "Play Scene" sur Main_Menu.tscn
   (Ou Ctrl+Alt+2 pour demander une 2ème instance)

→ Une 2ème fenêtre du jeu s'ouvre

2. Clique "JOUER"
3. L'IP input contient déjà "127.0.0.1" (localhost)
4. Clique "REJOINDRE"

[Fenêtre Client]
✓ Status: "Connexion en cours..."
✓ Après 1 sec: "Connecté! En attente du Lobby..."
✓ Tu es envoyé au Lobby
✓ Tu vois "2 / 6 joueurs connectés"
✓ Tu vois 2 joueurs dans la liste:
   - ○ Joueur (En attente...)
   - ○ Joueur (En attente...)

[Fenêtre Host]
✓ Status change à "2 / 6 joueurs connectés"
✓ Liste mise à jour
```

## Test 3: Marquer les joueurs comme PRÊT

```
[Fenêtre Host - Clique "JE SUIS PRÊT!"]
✓ Bouton devient vert et désactivé
✓ Status: "Tu es marqué comme PRÊT!"
✓ Dans la liste: "✓ Joueur (Prêt)"

[Fenêtre Client - Clique "JE SUIS PRÊT!"]
✓ Bouton devient vert et désactivé
✓ Status: "Tu es marqué comme PRÊT!"
✓ Dans la liste: "✓ Joueur (Prêt)"
                "✓ Joueur (Prêt)"

[AUTOMATIQUE]
✓ TOUS LES DEUX sont prêts
✓ Les deux fenêtres changent à [Race]
✓ Tu vois "🏁 RACE STARTED! 🏁"
✓ List players:
   - Joueur
   - Joueur
```

---

## 🎯 Checklist de vérification

### Connexion réseau

- [ ] Host peut créer un serveur
- [ ] Client peut se connecter au host
- [ ] Les joueurs apparaissent dans le lobby
- [ ] La liste se synchronise entre host et client

### Lobby

- [ ] Les 2 joueurs voient la liste correctement
- [ ] Quand host clique "Prêt" → sa liste change (✓)
- [ ] Quand client clique "Prêt" → sa liste change
- [ ] Host voit le client marquer comme prêt
- [ ] Quand TOUS sont prêts → Race se lance

### Race

- [ ] Les 2 joueurs entrent dans la scène Race
- [ ] Ils voient les 2 joueurs listés
- [ ] (À développer...)

---

## 🐛 Troubleshooting

### "Erreur: Impossible de créer le serveur"
**Cause:** Port 8080 déjà utilisé
**Solution:** 
```gdscript
# Dans NetworkManager.gd, changer:
const PORT = 8081  # ou 8082, etc.
```

### "Le client ne se connecte pas"
**Cause:** Mauvaise IP ou port fermé
**Solution:**
```
1. Vérifier la console du serveur (Host):
   → "Serveur lancé sur le port 8080 (ID: 1)"
   → "Quel IP affiche-t-il?"
   
2. Utiliser cette IP dans le client
3. Si sur le MÊME PC: utiliser "127.0.0.1"
4. Si sur différents PCs: utiliser "192.168.x.x" (adresse locale)
```

### "Logs vides ou pas d'affichage"
**Cause:** Console pas visible
**Solution:**
```
Godot → Window → Toggle Bottom Panel (ou F5)
→ Voir l'onglet "Output" en bas
```

---

## 📊 Logs attendus (dans la console)

### Host
```
[NetworkManager] Démarrage du serveur...
[NetworkManager] ✓ Serveur lancé sur le port 8080 (ID: 1)
[NetworkManager] En attente de 5 joueurs...
[NetworkManager] Quelqu'un a tenté de rejoindre: ID 2
[NetworkManager] ✓ Joueur ajouté: Joueur (ID: 2)
[NetworkManager] Liste des joueurs synchronisée: 2 joueur(s)
[NetworkManager] Joueur 2 est prêt
[NetworkManager] 🎬 TOUS LES JOUEURS SONT PRÊTS → Lancement course!
[NetworkManager] 🏁 Course lancée!
```

### Client
```
[NetworkManager] Tentative de connexion à 127.0.0.1:8080...
[NetworkManager] ⏳ Connexion en cours...
[NetworkManager] ✓ Connecté au serveur!
[NetworkManager] Liste des joueurs synchronisée: 2 joueur(s)
[NetworkManager] 🎬 TOUS LES JOUEURS SONT PRÊTS → Lancement course!
[NetworkManager] 🏁 Course lancée!
```

---

## 📝 Notes importantes

1. **GameData** stocke le perso/deck LOCAL (pas synchronisé réseau)
   - À gérer quand on crée le système de sélection

2. **NetworkManager** gère TOUT le réseau
   - Le serveur valide les actions
   - Les clients envoient les infos

3. **Lobby.gd** affiche juste l'interface
   - Appelle `NetworkManager.player_ready()`
   - Écoute les signaux pour mettre à jour l'affichage

4. **RPC vs MultiplayerSynchronizer**:
   - RPC = pour les actions ponctuelles (skill activé, message envoyé)
   - MultiplayerSynchronizer = pour les données continues (position, endurance)

---

**C'est bon? Des questions sur le test?**
