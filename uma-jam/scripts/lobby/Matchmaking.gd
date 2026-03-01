extends Control

enum MatchState { CONNECTING, SEARCHING, IN_LOBBY, STARTING }
var _state: MatchState = MatchState.CONNECTING
var _dots_timer: float = 0.0
var _dots_count: int = 0
var _connect_elapsed: float = 0.0

@onready var _status_label: Label = $Panel/VBox/StatusLabel
@onready var _player_list: VBoxContainer = $Panel/VBox/PlayerList
@onready var _count_label: Label = $Panel/VBox/CountLabel
@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _cancel_btn: Button = $Panel/VBox/CancelBtn

func _ready() -> void:
	_cancel_btn.pressed.connect(_on_cancel)

	NetworkManager.connected_to_relay.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.race_starting.connect(_on_race_starting)

	_set_state(MatchState.CONNECTING)
	NetworkManager.connect_to_relay()

func _process(delta: float) -> void:
	if _state == MatchState.CONNECTING or _state == MatchState.SEARCHING:
		_dots_timer += delta
		if _state == MatchState.CONNECTING:
			_connect_elapsed += delta
		if _dots_timer > 0.5:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			var dots := ".".repeat(_dots_count)
			if _state == MatchState.CONNECTING:
				var secs := int(_connect_elapsed)
				_status_label.text = _get_connect_message(secs, dots)
				_timer_label.text = "%ds" % secs
			else:
				_status_label.text = "Searching for opponents%s" % dots

func _set_state(new_state: MatchState) -> void:
	_state = new_state
	_dots_count = 0
	_dots_timer = 0.0

	match _state:
		MatchState.CONNECTING:
			_status_label.text = "Connecting to server..."
			_count_label.text = ""
			_timer_label.text = "0s"
			_connect_elapsed = 0.0
			_clear_player_list()

		MatchState.SEARCHING:
			_status_label.text = "Searching for opponents..."
			_count_label.text = ""
			_timer_label.text = ""

		MatchState.IN_LOBBY:
			_status_label.text = "Opponents found!"

		MatchState.STARTING:
			_status_label.text = "The race is starting!"
			_timer_label.text = ""
			_cancel_btn.disabled = true

func _on_connected() -> void:
	_set_state(MatchState.SEARCHING)
	NetworkManager.find_match()

func _on_connection_failed() -> void:
	_status_label.text = "Unable to connect.\nCheck your connection."
	_timer_label.text = ""
	_count_label.text = ""
	_cancel_btn.text = "RETRY"
	_cancel_btn.pressed.disconnect(_on_cancel)
	_cancel_btn.pressed.connect(_on_retry)

func _on_lobby_updated(players: Array, time_remaining: int) -> void:
	if _state == MatchState.SEARCHING or _state == MatchState.CONNECTING:
		_set_state(MatchState.IN_LOBBY)

	_count_label.text = "%d / 6 players" % players.size()

	if players.size() <= 1:
		_status_label.text = "Waiting for opponents..."
	else:
		_status_label.text = "Opponents found!"

	if time_remaining > 0:
		_timer_label.text = "Starting in %ds" % time_remaining
	else:
		_timer_label.text = "Starting..."

	_clear_player_list()
	for p in players:
		var lbl := Label.new()
		var pname: String = str(p.get("name", "?"))
		var pid: String = str(p.get("id", ""))
		if pid == NetworkManager.my_player_id:
			lbl.text = ">> %s (you)" % pname
			lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.65))
		else:
			lbl.text = "   %s" % pname
			lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 18)
		_player_list.add_child(lbl)

func _on_race_starting(_seed_val: int, _players: Array) -> void:
	_set_state(MatchState.STARTING)
	await get_tree().create_timer(0.5).timeout
	GameManager.go_to_race()

func _on_cancel() -> void:
	NetworkManager.disconnect_from_relay()
	GameManager.go_to_main_menu()

func _clear_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()

func _get_connect_message(secs: int, dots: String) -> String:
	if secs < 5:
		return "Connecting to server%s" % dots
	elif secs < 15:
		return "Waking up server%s\nServer is starting, please wait..." % dots
	elif secs < 30:
		return "Starting up%s\nPreparing server (%ds)" % [dots, secs]
	elif secs < 45:
		return "Almost ready%s\nServer is launching (%ds)" % [dots, secs]
	else:
		return "Taking a while%s\nServer is slow to respond (%ds)" % [dots, secs]

func _on_retry() -> void:
	_cancel_btn.text = "CANCEL"
	if _cancel_btn.pressed.is_connected(_on_retry):
		_cancel_btn.pressed.disconnect(_on_retry)
	if not _cancel_btn.pressed.is_connected(_on_cancel):
		_cancel_btn.pressed.connect(_on_cancel)
	_connect_elapsed = 0.0
	_set_state(MatchState.CONNECTING)
	NetworkManager.connect_to_relay()
