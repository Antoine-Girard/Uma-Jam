extends Node

const IP_ADDRESS: String = "localhost"
const PORT = 8080
const MAX_PLAYERS = 6

var peer: ENetMultiplayerPeer

func _ready():
	print("[NetworkManager] Initialisé")

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Serveur lancé sur le port %d (ID: %d)" % [PORT, GameData.player_id])

func start_client(ip_address: String) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Démarrage du client...")

func player_ready() -> void:
	print("[NetworkManager] Player is ready")

func player_unready() -> void:
	print("[NetworkManager] Player isn't ready anymore")

#func get_player_count() -> int:
#	return players_connected.size()

func _get_local_ip() -> String:
	var ip_name = IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")),1)
	return ip_name
