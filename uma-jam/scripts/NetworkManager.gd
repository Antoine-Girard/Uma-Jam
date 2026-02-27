extends Node

const PORT = 8080
const MAX_PLAYERS = 6
const PASSWORD = "funny_uma"

var is_server: bool = false
var players_connected: Dictionary = {}

signal peer_connected(id: int, name: String)
signal peer_disconnected(id: int)
signal server_started
signal client_connected
signal player_list_updated(players: Dictionary)

func _ready():
	print("[NetworkManager] Initialisé")
	multiplayer.connected_to_server.connect(_on_client_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# signal called when a client fails to connect (timeout, unreachable)
	multiplayer.connection_failed.connect(_on_connection_failed)

func start_server() -> void:
	print("[NetworkManager] Démarrage du serveur...")
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		print("[NetworkManager] ERREUR: Impossible de créer le serveur")
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	GameData.player_id = multiplayer.get_unique_id()
	players_connected[GameData.player_id] = {
		"name": GameData.player_name,
		"ready": false
	}
	print("[NetworkManager] ✓ Serveur lancé sur le port %d (ID: %d)" % [PORT, GameData.player_id])
	print("[NetworkManager] En attente de %d joueurs..." % (MAX_PLAYERS - 1))
	server_started.emit()

func join_server(ip: String) -> void:
	print("[NetworkManager] Tentative de connexion à %s:%d..." % [ip, PORT])
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("[NetworkManager] ERREUR: Impossible de créer le client")
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	print("[NetworkManager] ⏳ Connexion en cours...")

func add_player(peer_id: int, name: String) -> void:
	if peer_id not in players_connected:
		players_connected[peer_id] = {"name": name, "ready": false}
		print("[NetworkManager] ✓ Joueur ajouté: %s (ID: %d)" % [name, peer_id])
		if is_server:
			rpc("sync_player_list", players_connected)

@rpc("authority", "call_local")
func sync_player_list(players: Dictionary) -> void:
	players_connected = players
	print("[NetworkManager] Liste des joueurs synchronisée: %d joueur(s)" % players_connected.size())
	player_list_updated.emit(players_connected)

func player_ready() -> void:
	rpc_id(1, "_player_confirmed_ready", multiplayer.get_unique_id())

@rpc("any_peer", "call_remote")
func _player_confirmed_ready(peer_id: int) -> void:
	if not is_server:
		return
	if peer_id in players_connected:
		players_connected[peer_id]["ready"] = true
		print("[NetworkManager] Joueur %d est prêt" % peer_id)
		rpc("sync_player_list", players_connected)
		if all_players_ready():
			print("[NetworkManager] 🎬 TOUS LES JOUEURS SONT PRÊTS → Lancement course!")
			rpc("start_race")

func player_unready() -> void:
	rpc_id(1, "_player_confirmed_unready", multiplayer.get_unique_id())

@rpc("any_peer", "call_remote")
func _player_confirmed_unready(peer_id: int) -> void:
	if not is_server:
		return
	if peer_id in players_connected:
		players_connected[peer_id]["ready"] = false
		print("[NetworkManager] Joueur %d n'est plus prêt" % peer_id)
		rpc("sync_player_list", players_connected)

func all_players_ready() -> bool:
	if players_connected.size() < 2:
		return false
	for player_info in players_connected.values():
		if not player_info.get("ready", false):
			return false
	return true

@rpc("authority", "call_local")
func start_race() -> void:
	print("[NetworkManager] 🏁 Course lancée!")
	get_tree().change_scene_to_file("res://scenes/race/Race.tscn")

func _on_client_connected() -> void:
	print("[NetworkManager] ✓ Connecté au serveur!")
	GameData.player_id = multiplayer.get_unique_id()
	rpc_id(1, "_notify_new_player", GameData.player_name)
	client_connected.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] ✗ Échec de connexion au serveur")
	# You can show a UI warning here if needed

func _on_server_disconnected() -> void:
	print("[NetworkManager] ✗ Déconnecté du serveur!")
	is_server = false
	players_connected.clear()

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Quelqu'un a tenté de rejoindre: ID %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Joueur déconnecté: %d" % peer_id)
	if peer_id in players_connected:
		players_connected.erase(peer_id)
		rpc("sync_player_list", players_connected)

@rpc("any_peer")
func _notify_new_player(player_name: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	add_player(peer_id, player_name)
	peer_connected.emit(peer_id, player_name)

func get_player_name(peer_id: int) -> String:
	if peer_id in players_connected:
		return players_connected[peer_id]["name"]
	return "Inconnu"

func get_player_count() -> int:
	return players_connected.size()

func am_server() -> bool:
	return is_server
