extends Node

const RELAY_URL := "wss://uma-jam.onrender.com"
const MAX_PLAYERS := 6

enum State { DISCONNECTED, CONNECTING, IN_LOBBY, IN_RACE }
var state: State = State.DISCONNECTED

var solo_mode: bool = false
var is_online: bool = false
var my_player_id: String = ""
var race_seed: int = 0
var players_connected: Dictionary = {}

var _ws: WebSocketPeer = null
var _was_open: bool = false

signal connected_to_relay
signal connection_failed
signal lobby_updated(players: Array, time_remaining: int)
signal race_starting(seed_val: int, players: Array)
signal lane_change_received(player_id: String, direction: String)
signal position_update_received(player_id: String, progress_val: float, laps: int, lane: int, speed: float)
signal skill_use_received(player_id: String, skill_id: String)
signal player_left(player_id: String)

func _ready() -> void:
	print("[NetworkManager] Initialized")

func _process(_delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()

	var ws_state := _ws.get_ready_state()

	if ws_state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		is_online = true
		state = State.IN_LOBBY
		print("[NetworkManager] Connected to relay!")
		connected_to_relay.emit()

	elif ws_state == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		print("[NetworkManager] Disconnected from relay (code %d)" % code)
		var was_connecting := (state == State.CONNECTING)
		_ws = null
		_was_open = false
		is_online = false
		state = State.DISCONNECTED
		if was_connecting:
			connection_failed.emit()
		return

	while _ws != null and _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			_handle_message(parsed)

func connect_to_relay() -> void:
	if _ws != null:
		disconnect_from_relay()

	print("[NetworkManager] Connecting to %s..." % RELAY_URL)
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(RELAY_URL)
	if err != OK:
		print("[NetworkManager] Connection error: %d" % err)
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

func wake_up_server() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var url := RELAY_URL.replace("ws://", "http://").replace("wss://", "https://")
	http.request(url)
	http.request_completed.connect(func(_result, _code, _headers, _body):
		print("[NetworkManager] Server pinged (wake-up)")
		http.queue_free()
	)

func find_match() -> void:
	_send({"type": "find_match", "player_name": GameData.player_name})

func send_lane_change(direction: String) -> void:
	_send({"type": "lane_change", "direction": direction})

func send_skill_use(skill_id: String) -> void:
	_send({"type": "skill_use", "skill_id": skill_id})

func send_position_update(progress_val: float, laps: int, lane: int, speed: float) -> void:
	_send({
		"type": "position_update",
		"progress": progress_val,
		"laps": laps,
		"lane": lane,
		"speed": speed
	})

func _send(data: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(data))

func _handle_message(data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")

	match msg_type:
		"joined":
			my_player_id = str(data.get("player_id", ""))
			print("[NetworkManager] Joined room %s (ID: %s)" % [
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
			print("[NetworkManager] Race started! seed=%d, %d players" % [
				race_seed, players_arr.size()])
			race_starting.emit(race_seed, players_arr)

		"lane_change":
			var pid: String = str(data.get("player_id", ""))
			var direction: String = str(data.get("direction", ""))
			lane_change_received.emit(pid, direction)

		"position_update":
			var pid: String = str(data.get("player_id", ""))
			var prog: float = float(data.get("progress", 0.0))
			var laps: int = int(data.get("laps", 0))
			var lane: int = int(data.get("lane", 0))
			var spd: float = float(data.get("speed", 0.0))
			position_update_received.emit(pid, prog, laps, lane, spd)

		"skill_use":
			var pid: String = str(data.get("player_id", ""))
			var sid: String = str(data.get("skill_id", ""))
			skill_use_received.emit(pid, sid)

		"player_left":
			var pid: String = str(data.get("player_id", ""))
			if pid in players_connected:
				players_connected.erase(pid)
			print("[NetworkManager] Player %s left" % pid)
			player_left.emit(pid)

		"error":
			print("[NetworkManager] Server error: %s" % str(data.get("message", "")))

func get_player_count() -> int:
	return players_connected.size()
