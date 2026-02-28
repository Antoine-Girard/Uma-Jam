extends Node

## URL du serveur relay — à changer après déploiement sur Render
const RELAY_URL := "ws://localhost:8080"
const MAX_PLAYERS := 6

# ─── État ─────────────────────────────────────────────────────────────────────

enum State { DISCONNECTED, CONNECTING, IN_LOBBY, IN_RACE }
var state: State = State.DISCONNECTED

var solo_mode: bool = false
var is_online: bool = false
var my_player_id: String = ""
var race_seed: int = 0
var players_connected: Dictionary = {}  # player_id -> { "name", "slot" }

var _ws: WebSocketPeer = null
var _was_open: bool = false

# ─── Signaux ──────────────────────────────────────────────────────────────────

signal connected_to_relay
signal connection_failed
signal lobby_updated(players: Array, time_remaining: int)
signal race_starting(seed_val: int, players: Array)
signal lane_change_received(player_id: String, direction: String)
signal player_left(player_id: String)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	print("[NetworkManager] Initialisé")


func _process(_delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()

	var ws_state := _ws.get_ready_state()

	if ws_state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		is_online = true
		state = State.IN_LOBBY
		print("[NetworkManager] Connecté au relay!")
		connected_to_relay.emit()

	elif ws_state == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		print("[NetworkManager] Déconnecté du relay (code %d)" % code)
		var was_connecting := (state == State.CONNECTING)
		_ws = null
		_was_open = false
		is_online = false
		state = State.DISCONNECTED
		if was_connecting:
			connection_failed.emit()
		return

	# Lire les messages entrants
	while _ws != null and _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			_handle_message(parsed)


# ─── Connexion ────────────────────────────────────────────────────────────────

func connect_to_relay() -> void:
	if _ws != null:
		disconnect_from_relay()

	print("[NetworkManager] Connexion à %s..." % RELAY_URL)
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(RELAY_URL)
	if err != OK:
		print("[NetworkManager] Erreur de connexion: %d" % err)
		_ws = null
		connection_failed.emit()
		return
	state = State.CONNECTING
	_was_open = false


func disconnect_from_relay() -> void:
	if _ws != null:
		_send({"type": "leave"})
		_ws.close()
		_ws = null
	_was_open = false
	is_online = false
	state = State.DISCONNECTED
	my_player_id = ""
	players_connected.clear()


## Ping HTTP pour réveiller le serveur Render (appelé depuis MainMenu)
func wake_up_server() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var url := RELAY_URL.replace("ws://", "http://").replace("wss://", "https://")
	http.request(url)
	http.request_completed.connect(func(_result, _code, _headers, _body):
		print("[NetworkManager] Serveur pingé (wake-up)")
		http.queue_free()
	)


# ─── Envoi de messages ────────────────────────────────────────────────────────

func find_match() -> void:
	_send({"type": "find_match", "player_name": GameData.player_name})


func send_lane_change(direction: String) -> void:
	_send({"type": "lane_change", "direction": direction})


func send_skill_use(skill_id: String) -> void:
	_send({"type": "skill_use", "skill_id": skill_id})


func _send(data: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(data))


# ─── Réception de messages ────────────────────────────────────────────────────

func _handle_message(data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")

	match msg_type:
		"joined":
			my_player_id = str(data.get("player_id", ""))
			print("[NetworkManager] Rejoint la room %s (ID: %s)" % [
				str(data.get("room_id", "")), my_player_id])

		"lobby_update":
			var players_arr: Array = data.get("players", [])
			var time_remaining: int = int(data.get("time_remaining", 0))

			players_connected.clear()
			for p in players_arr:
				var pid: String = str(p.get("id", ""))
				players_connected[pid] = {
					"name": str(p.get("name", "?")),
					"slot": int(p.get("slot", 0))
				}

			lobby_updated.emit(players_arr, time_remaining)

		"race_start":
			race_seed = int(data.get("seed", 0))
			var players_arr: Array = data.get("players", [])

			players_connected.clear()
			for p in players_arr:
				var pid: String = str(p.get("id", ""))
				players_connected[pid] = {
					"name": str(p.get("name", "?")),
					"slot": int(p.get("slot", 0))
				}

			state = State.IN_RACE
			print("[NetworkManager] Course lancée! seed=%d, %d joueurs" % [
				race_seed, players_arr.size()])
			race_starting.emit(race_seed, players_arr)

		"lane_change":
			var pid: String = str(data.get("player_id", ""))
			var direction: String = str(data.get("direction", ""))
			lane_change_received.emit(pid, direction)

		"player_left":
			var pid: String = str(data.get("player_id", ""))
			if pid in players_connected:
				players_connected.erase(pid)
			print("[NetworkManager] Joueur %s a quitté" % pid)
			player_left.emit(pid)

		"error":
			print("[NetworkManager] Erreur serveur: %s" % str(data.get("message", "")))


# ─── Helpers ──────────────────────────────────────────────────────────────────

func get_player_count() -> int:
	return players_connected.size()
