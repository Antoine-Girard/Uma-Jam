# ============================================================================
# NetworkManager.gd - Gère tout le multijoueur
# ============================================================================
# Point clé: Ce script crée/join une partie multijoueur
# C'est le cœur du système réseau
#
# Fonctionne en mode CLIENT-SERVER:
#   - UN joueur = SERVEUR (l'host)
#   - LES AUTRES = CLIENTS (se connectent au serveur)
#
# Utilisation:
#   NetworkManager.start_server()       → Lancer une partie (toi = serveur)
#   NetworkManager.join_server(ip)      → Rejoindre une partie (toi = client)
# ============================================================================

extends Node

# ─── CONSTANTES (À MODIFIER POUR DU VRAI ONLINE) ───
const PORT = 8080                    # Port reseau (doit être même pour tous)
const MAX_PLAYERS = 6                # Maximum 6 joueurs
const PASSWORD = "jump_uma"          # Shared secret (sécurité basique)

# ─── VARIABLES ───
var is_server: bool = false          # Suis-je le serveur?
var players_connected: Dictionary = {} # {"id": {"name": "Joueur", "ready": false}}

# ─── SIGNAUX (les autres scripts peuvent "écouter" ces événements) ───
signal peer_connected(id: int, name: String)
signal peer_disconnected(id: int)
signal server_started
signal client_connected
signal player_list_updated(players: Dictionary)

func _ready():
	print("[NetworkManager] Initialisé")
	
	# ───────────────────────────────────────────────────────────────
	# PART 1: SE CONNECTER AUX SIGNAUX DU MULTIJOUEUR
	# ───────────────────────────────────────────────────────────────
	# Les signaux Godot préviennent automatiquement quand:
	
	# Le client réussit à se connecter au serveur
	multiplayer.connected_to_server.connect(_on_client_connected)
	
	# Le client perd la connexion au serveur
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Un AUTRE joueur rejoint (serveur le reçoit)
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	# Un AUTRE joueur part (serveur le reçoit)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 1: LANCER UN SERVEUR (Host)
# ─────────────────────────────────────────────────────────────────────────
# 
# Quand appeler: Le joueur clique "Créer une partie"
# Ce que ça fait:
#   1. Crée un objet ENetMultiplayerPeer (socket réseau)
#   2. Configure-le en MODE SERVEUR sur le port 8080
#   3. Max 6 joueurs connecté (dont toi)
#   4. Envoie le signal "server_started"
#
# Retour: void (rien)
#
# Exemple:
#   NetworkManager.start_server()
#   # → Attend les connexions des clients
#
func start_server() -> void:
	print("[NetworkManager] Démarrage du serveur...")
	
	# Créer une socket réseau ENet
	var peer = ENetMultiplayerPeer.new()
	
	# Configurer en mode SERVEUR
	# create_server(port, max_clients)
	# port = 8080, max_clients = 5 (+ toi = 6 total)
	var error = peer.create_server(PORT, MAX_PLAYERS - 1)
	
	if error != OK:
		print("[NetworkManager] ERREUR: Impossible de créer le serveur")
		return
	
	# Assigner cette socket au système multijoueur de Godot
	multiplayer.multiplayer_peer = peer
	
	# Je suis le serveur (peer id = 1)
	is_server = true
	GameData.player_id = multiplayer.get_unique_id()
	players_connected[GameData.player_id] = {
		"name": GameData.player_name,
		"ready": false
	}
	
	print("[NetworkManager] ✓ Serveur lancé sur le port %d (ID: %d)" % [PORT, GameData.player_id])
	print("[NetworkManager] En attente de %d joueurs..." % (MAX_PLAYERS - 1))
	
	# Signal pour notifier l'UI
	server_started.emit()

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 2: REJOINDRE UN SERVEUR (Client)
# ─────────────────────────────────────────────────────────────────────────
#
# Quand appeler: Le joueur clique "Rejoindre une partie" et rentre une IP
# Ce que ça fait:
#   1. Crée un objet ENetMultiplayerPeer (socket réseau)
#   2. Configure-le en MODE CLIENT
#   3. Se connecte à l'IP + port donnés
#   4. Attend la réponse du serveur
#
# Paramètres:
#   - ip (String): Adresse IP du serveur (ex: "192.168.1.100")
#
# Retour: void (rien)
#
# Exemple:
#   NetworkManager.join_server("192.168.1.100")
#   # → Essaie de se connecter
#   # → Si succès: _on_client_connected() est appelé
#   # → Si erreur: afficher message d'erreur
#
func join_server(ip: String) -> void:
	print("[NetworkManager] Tentative de connexion à %s:%d..." % [ip, PORT])
	
	# Créer une socket réseau ENet
	var peer = ENetMultiplayerPeer.new()
	
	# Configurer en mode CLIENT
	# create_client(host_address, host_port)
	var error = peer.create_client(ip, PORT)
	
	if error != OK:
		print("[NetworkManager] ERREUR: Impossible de créer le client")
		return
	
	# Assigner cette socket au système multijoueur de Godot
	multiplayer.multiplayer_peer = peer
	
	# Je ne suis PAS le serveur
	is_server = false
	
	print("[NetworkManager] ⏳ Connexion en cours...")
	# On attend le signal _on_client_connected()

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 3: AJOUTER UN JOUEUR À LA LISTE
# ─────────────────────────────────────────────────────────────────────────
#
# Quand appeler: En interne (quand quelqu'un rejoint)
# Ce que ça fait:
#   1. Ajoute le joueur au dictionnaire players_connected
#   2. Envoie un RPC à TOUS les clients pour synchroniser la liste
#
# Paramètres:
#   - peer_id (int): L'ID du joueur (ex: 2, 3, 4...)
#   - name (String): Son nom (ex: "Alice")
#
func add_player(peer_id: int, name: String) -> void:
	if peer_id not in players_connected:
		players_connected[peer_id] = {"name": name, "ready": false}
		print("[NetworkManager] ✓ Joueur ajouté: %s (ID: %d)" % [name, peer_id])
		
		# Notifier tous les clients
		if is_server:
			rpc("sync_player_list", players_connected)

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 4: RPC - Synchroniser la liste des joueurs
# ─────────────────────────────────────────────────────────────────────────
#
# IMPORTANT: @rpc signifie "cet appel réseau peut être appelé par d'autres"
#
# Ce que ça fait: Envoyer la liste complète des joueurs à TOUS les clients
# pour qu'ils le mettent à jour (on appelle ça "synchroniser")
#
# Paramètres:
#   - players (Dictionary): {"id": {"name": "...", "ready": false}}
#
# Exemple interne (le serveur le fait):
#   rpc("sync_player_list", {"1": {"name": "Host", ...}, "2": {...}})
#
@rpc("authority", "call_local")
func sync_player_list(players: Dictionary) -> void:
	players_connected = players
	print("[NetworkManager] Liste des joueurs synchronisée: %d joueur(s)" % players_connected.size())
	
	# Signal pour notify l'interface
	player_list_updated.emit(players_connected)

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 5: MARQUER UN JOUEUR COMME PRÊT
# ─────────────────────────────────────────────────────────────────────────
#
# Quand appeler: Quand le joueur clique "Je suis prêt!"
# Ce que ça fait:
#   1. Appelle RPC sur le serveur
#   2. Le serveur marque le joueur comme "ready"
#   3. Le serveur diffuse la nouvelle liste à tous
#   4. Si TOUS sont prêts → Lance la course
#
func player_ready() -> void:
	# Appeler le serveur (peer_id = 1)
	rpc_id(1, "_player_confirmed_ready", multiplayer.get_unique_id())

@rpc("any_peer", "call_remote")
func _player_confirmed_ready(peer_id: int) -> void:
	# Seulement le serveur exécute ça
	if not is_server:
		return
	
	if peer_id in players_connected:
		players_connected[peer_id]["ready"] = true
		print("[NetworkManager] Joueur %d est prêt" % peer_id)
		
		# Notifier tous les clients
		rpc("sync_player_list", players_connected)
		
		# Vérifier si TOUS sont prêts
		if all_players_ready():
			print("[NetworkManager] 🎬 TOUS LES JOUEURS SONT PRÊTS → Lancement course!")
			rpc("start_race")

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 6: VÉRIFIER SI TOUS SONT PRÊTS
# ─────────────────────────────────────────────────────────────────────────
#
# Retour: true si tous >= 2 joueurs ET tous "ready"
#
func all_players_ready() -> bool:
	# Besoin de minimum 2 joueurs
	if players_connected.size() < 2:
		return false
	
	# Tous doivent avoir "ready" = true
	for player_info in players_connected.values():
		if not player_info.get("ready", false):
			return false
	
	return true

# ─────────────────────────────────────────────────────────────────────────
# FONCTION 7: RPC - DÉMARRER LA COURSE
# ─────────────────────────────────────────────────────────────────────────
#
# Ce que ça fait: Charge la scène de la course et la lance pour tous
#
@rpc("authority", "call_local")
func start_race() -> void:
	print("[NetworkManager] 🏁 Course lancée!")
	# TODO: Charger la scène "res://scenes/race/Race.tscn"
	# Pour maintenant, juste un message
	get_tree().change_scene_to_file("res://scenes/race/Race.tscn")

# ─────────────────────────────────────────────────────────────────────────
# CALLBACKS (fonctions appelées automatiquement)
# ─────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# Quand: Un CLIENT se connecte au SERVEUR avec succès
# ──────────────────────────────────────────────────────────────
func _on_client_connected() -> void:
	print("[NetworkManager] ✓ Connecté au serveur!")
	GameData.player_id = multiplayer.get_unique_id()
	
	# Notifier le serveur: "Hey, je suis un nouveau client!"
	rpc_id(1, "_notify_new_player", GameData.player_name)
	
	client_connected.emit()

# ──────────────────────────────────────────────────────────────
# Quand: Un CLIENT perd la connexion au SERVEUR
# ──────────────────────────────────────────────────────────────
func _on_server_disconnected() -> void:
	print("[NetworkManager] ✗ Déconnecté du serveur!")
	is_server = false
	players_connected.clear()
	# TODO: Retourner au menu principal

# ──────────────────────────────────────────────────────────────
# Quand: Un AUTRE joueur rejoint (le serveur reçoit ça)
# ──────────────────────────────────────────────────────────────
func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Quelqu'un a tenté de rejoindre: ID %d" % peer_id)
	# On attendra que le client nous envoie son nom via RPC

# ──────────────────────────────────────────────────────────────
# Quand: Un AUTRE joueur part
# ──────────────────────────────────────────────────────────────
func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Joueur déconnecté: %d" % peer_id)
	if peer_id in players_connected:
		players_connected.erase(peer_id)
		# Synchroniser
		rpc("sync_player_list", players_connected)

# ─────────────────────────────────────────────────────────────────────────
# RPC: Le serveur reçoit la notification d'un nouveau client
# ─────────────────────────────────────────────────────────────────────────
@rpc("any_peer")
func _notify_new_player(player_name: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	add_player(peer_id, player_name)
	peer_connected.emit(peer_id, player_name)

# ─────────────────────────────────────────────────────────────────────────
# FONCTION: Obtenir les infos d'un joueur
# ─────────────────────────────────────────────────────────────────────────
func get_player_name(peer_id: int) -> String:
	if peer_id in players_connected:
		return players_connected[peer_id]["name"]
	return "Inconnu"

# ─────────────────────────────────────────────────────────────────────────
# INFO: NB de joueurs connectés
# ─────────────────────────────────────────────────────────────────────────
func get_player_count() -> int:
	return players_connected.size()

# ─────────────────────────────────────────────────────────────────────────
# INFO: Suis-je le serveur?
# ─────────────────────────────────────────────────────────────────────────
func am_server() -> bool:
	return is_server
