extends Control

# ============================================================================
# Matchmaking.gd - Auto-matchmaking (style Clash Royale)
# Se connecte au relay, cherche un match, affiche les joueurs, lance la course
# ============================================================================

enum MatchState { CONNECTING, SEARCHING, IN_LOBBY, STARTING }
var _state: MatchState = MatchState.CONNECTING
var _dots_timer: float = 0.0
var _dots_count: int = 0

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
		if _dots_timer > 0.5:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			var dots := ".".repeat(_dots_count)
			if _state == MatchState.CONNECTING:
				_status_label.text = "Connexion au serveur%s\n(peut prendre ~30s)" % dots
			else:
				_status_label.text = "Recherche d'adversaires%s" % dots


func _set_state(new_state: MatchState) -> void:
	_state = new_state
	_dots_count = 0
	_dots_timer = 0.0

	match _state:
		MatchState.CONNECTING:
			_status_label.text = "Connexion au serveur...\n(peut prendre ~30s)"
			_count_label.text = ""
			_timer_label.text = ""
			_clear_player_list()

		MatchState.SEARCHING:
			_status_label.text = "Recherche d'adversaires..."
			_count_label.text = ""
			_timer_label.text = ""

		MatchState.IN_LOBBY:
			_status_label.text = "Adversaires trouves !"

		MatchState.STARTING:
			_status_label.text = "La course commence !"
			_timer_label.text = ""
			_cancel_btn.disabled = true


# ─── Signaux NetworkManager ──────────────────────────────────────────────────

func _on_connected() -> void:
	_set_state(MatchState.SEARCHING)
	NetworkManager.find_match()


func _on_connection_failed() -> void:
	_status_label.text = "Impossible de se connecter.\nVerifiez votre connexion."
	_timer_label.text = ""
	_count_label.text = ""


func _on_lobby_updated(players: Array, time_remaining: int) -> void:
	if _state == MatchState.SEARCHING or _state == MatchState.CONNECTING:
		_set_state(MatchState.IN_LOBBY)

	_count_label.text = "%d / 6 joueurs" % players.size()
	_timer_label.text = "Lancement dans %ds" % time_remaining if time_remaining > 0 else "Lancement..."

	_clear_player_list()
	for p in players:
		var lbl := Label.new()
		var pname: String = str(p.get("name", "?"))
		var pid: String = str(p.get("id", ""))
		if pid == NetworkManager.my_player_id:
			lbl.text = ">> %s (vous)" % pname
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


# ─── Actions ─────────────────────────────────────────────────────────────────

func _on_cancel() -> void:
	NetworkManager.disconnect_from_relay()
	GameManager.go_to_main_menu()


func _clear_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()
