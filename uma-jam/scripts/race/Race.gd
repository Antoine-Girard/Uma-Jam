extends Node2D

const LAPS := 3
const SKIP_SPEED_MULT := 12.0
const BASE_MAX_SPEED := 55.0
const BASE_ACCEL := 5.5
const MAX_PLAYERS := 6

const BOT_CHAR_IDS := ["tachyon", "el_condor_passa", "gold_ship", "maruzenski",
	"oguri_cap", "sakura", "spe_chan", "rudolf"]

@onready var _track:        Node2D  = $Track
@onready var _horses_node:  Node2D  = $Horses

@onready var _lap_label:    Label   = $UI/LapPanel/VBox/LapLabel
@onready var _pos_label:    Label   = $UI/PosPanel/VBox/PosLabel
@onready var _pos_sub:      Label   = $UI/PosPanel/VBox/PosSubLabel
@onready var _inner_btn:    Button  = $UI/LaneButtons/InnerBtn
@onready var _outer_btn:    Button  = $UI/LaneButtons/OuterBtn
@onready var _lane_num:     Label   = $UI/LaneButtons/LaneInfo/LaneNum
@onready var _countdown:    Label   = $UI/Countdown
@onready var _end_overlay:  Control = $UI/EndOverlay
@onready var _win_title:    Label   = $UI/EndOverlay/VBox/WinTitle
@onready var _win_name:     Label   = $UI/EndOverlay/VBox/WinName
@onready var _rankings:     Label   = $UI/EndOverlay/VBox/Rankings
@onready var _lane_btns:    Control = $UI/LaneButtons
@onready var _skip_btn:     Button  = $UI/SkipBtn
@onready var _retry_btn:    Button  = $UI/EndOverlay/VBox/RetryBtn
@onready var _menu_btn:     Button  = $UI/EndOverlay/VBox/MenuBtn
@onready var _ui:           CanvasLayer = $UI

var _my_horse:     HorseRacer         = null
var _horses:       Array[HorseRacer]  = []
var _finish_order: Array[HorseRacer]  = []
var _race_over:    bool               = false
var _race_started: bool               = false
var _my_finished:  bool               = false
var _skipping:     bool               = false

var _skill_buttons: Array[Button]     = []
var _skill_ids_ordered: Array[String] = []
var _endurance_bar: ProgressBar       = null
var _endurance_label: Label           = null
var _skill_panel: PanelContainer      = null
var _skill_tooltip: PanelContainer    = null
var _tooltip_label: Label             = null
var _tooltip_timer: float             = 0.0
var _tooltip_btn: Button              = null

var _stats_panel: PanelContainer      = null
var _speed_label: Label               = null
var _max_speed_label: Label           = null
var _accel_label: Label               = null

var _player_horses: Dictionary        = {}

var _sync_timer: float               = 0.0
const SYNC_INTERVAL: float           = 0.2

var _pause_overlay: Control          = null
var _paused: bool                    = false

# Bot lane change AI
var _bot_lane_timers: Dictionary     = {}  # horse -> float cooldown
const BOT_LANE_CHECK_INTERVAL: float = 0.8

func _ready() -> void:
	_inner_btn.pressed.connect(_on_inner)
	_outer_btn.pressed.connect(_on_outer)
	_skip_btn.pressed.connect(_on_skip)
	_retry_btn.pressed.connect(_on_retry)
	_menu_btn.pressed.connect(_on_menu)
	_lane_btns.visible = false
	_skip_btn.visible = false
	_skip_btn.modulate.a = 0.0
	_countdown.visible = false
	$UI/LapPanel.modulate.a = 0.0
	$UI/PosPanel.modulate.a = 0.0
	if NetworkManager.is_online:
		NetworkManager.lane_change_received.connect(_on_remote_lane_change)
		NetworkManager.position_update_received.connect(_on_remote_position_update)
		NetworkManager.skill_use_received.connect(_on_remote_skill_use)
		NetworkManager.player_left.connect(_on_remote_player_left)

	_spawn_horses()
	_freeze_horses()
	_build_skill_ui()
	_build_pause_menu()
	_show_intro()

func _show_intro() -> void:
	var bg := ColorRect.new()
	bg.name = "IntroBG"
	bg.color = Color(0.0, 0.0, 0.05, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_right = 0
	bg.offset_bottom = 0
	_ui.add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -280.0
	center.offset_right = 280.0
	center.offset_top = -230.0
	center.offset_bottom = 230.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 6)
	bg.add_child(center)

	var title := Label.new()
	title.text = "RACERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	center.add_child(title)
	title.modulate.a = 0.0

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	center.add_child(sep)

	var cards: Array[Control] = []
	for h: HorseRacer in _horses:
		var card := _make_player_card(h)
		card.modulate.a = 0.0
		center.add_child(card)
		cards.append(card)

	await get_tree().create_timer(0.3).timeout
	var t_tw := create_tween()
	t_tw.tween_property(title, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.4).timeout

	for card: Control in cards:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)
		tw.tween_property(card, "position:x", card.position.x, 0.3) \
			.from(card.position.x + 60.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.18).timeout

	await get_tree().create_timer(1.5).timeout

	var fade := create_tween()
	fade.tween_property(bg, "modulate:a", 0.0, 0.5)
	await fade.finished
	bg.queue_free()

	var panel_tw := create_tween().set_parallel(true)
	panel_tw.tween_property($UI/LapPanel, "modulate:a", 1.0, 0.3)
	panel_tw.tween_property($UI/PosPanel, "modulate:a", 1.0, 0.3)
	if _stats_panel:
		panel_tw.tween_property(_stats_panel, "modulate:a", 1.0, 0.3)

	_start_countdown()

func _make_player_card(horse: HorseRacer) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.85)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	var horse_color: Color = HorseRacer.HORSE_COLORS[horse.color_idx % HorseRacer.HORSE_COLORS.size()]
	style.border_width_left = 5
	style.border_color = horse_color

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 52)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hbox)

	# Portrait du personnage
	var icon_id: String = GameData.CHAR_ID_TO_ICON.get(horse.char_id, "")
	var portrait_tex := load("res://assets/characters/%s.png" % icon_id) as Texture2D if icon_id != "" else null

	if portrait_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = portrait_tex
		tex_rect.custom_minimum_size = Vector2(42, 42)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		hbox.add_child(tex_rect)
	else:
		var img_frame := PanelContainer.new()
		var img_style := StyleBoxFlat.new()
		img_style.bg_color = horse_color.darkened(0.2)
		img_style.set_corner_radius_all(6)
		img_frame.add_theme_stylebox_override("panel", img_style)
		img_frame.custom_minimum_size = Vector2(42, 42)
		hbox.add_child(img_frame)
		var img_label := Label.new()
		img_label.text = "?"
		img_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		img_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		img_label.add_theme_font_size_override("font_size", 20)
		img_frame.add_child(img_label)

	var name_label := Label.new()
	name_label.text = horse.horse_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if horse == _my_horse:
		name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.65))
	hbox.add_child(name_label)

	var trophy_hbox := HBoxContainer.new()
	trophy_hbox.add_theme_constant_override("separation", 4)
	hbox.add_child(trophy_hbox)

	var trophy_icon := Label.new()
	trophy_icon.text = "T"
	trophy_icon.add_theme_font_size_override("font_size", 16)
	trophy_icon.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	trophy_hbox.add_child(trophy_icon)

	var trophy_count := Label.new()
	trophy_count.text = "0"
	trophy_count.add_theme_font_size_override("font_size", 18)
	trophy_count.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	trophy_hbox.add_child(trophy_count)

	return panel

func _start_countdown() -> void:
	_countdown.visible = true
	_countdown.modulate.a = 1.0
	for i in [3, 2, 1]:
		_countdown.text = str(i)
		_countdown.scale = Vector2(1.3, 1.3)
		_countdown.remove_theme_color_override("font_color")
		var tween := create_tween()
		tween.tween_property(_countdown, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.85).timeout

	_countdown.text = "GO!"
	_countdown.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var tween := create_tween()
	tween.tween_property(_countdown, "modulate:a", 0.0, 0.6).set_delay(0.3)

	_race_started = true
	_lane_btns.visible = true
	if _skill_panel:
		_skill_panel.visible = true
	if NetworkManager.is_online:
		_skip_btn.visible = false
	else:
		_skip_btn.visible = true
		var fade := create_tween()
		fade.tween_property(_skip_btn, "modulate:a", 1.0, 0.5).set_delay(1.0)
	_unfreeze_horses()

func _freeze_horses() -> void:
	for h: HorseRacer in _horses:
		h.set_process(false)

func _unfreeze_horses() -> void:
	for h: HorseRacer in _horses:
		h.set_process(true)

func _spawn_horses() -> void:
	var player_char_id: String = GameData.character_id

	if NetworkManager.race_seed != 0:
		seed(NetworkManager.race_seed)

	if NetworkManager.is_online and not NetworkManager.players_connected.is_empty():
		var players: Dictionary = NetworkManager.players_connected
		var i := 0
		for pid in players.keys():
			var pdata: Dictionary = players[pid]
			var pname: String = pdata.get("name", "P%d" % (i + 1))
			var is_me: bool = (pid == NetworkManager.my_player_id)
			# Use the player's chosen character, fallback to a bot character
			var cid: String = player_char_id if is_me else pdata.get("character_id", BOT_CHAR_IDS[i % BOT_CHAR_IDS.size()])
			var horse := _make_horse(i, pname, cid, is_me)
			_player_horses[pid] = horse
			if is_me:
				_my_horse = horse
			else:
				# Remote players: don't simulate locally, rely on network updates
				horse.is_remote = true
			i += 1

		var bot_names := ["Sakura", "Hana", "Kaze", "Tsuki", "Hoshi"]
		var bot_idx := 0
		while _horses.size() < MAX_PLAYERS:
			var bot_cid: String = BOT_CHAR_IDS[(i + bot_idx) % BOT_CHAR_IDS.size()]
			_make_horse(_horses.size(), bot_names[bot_idx % bot_names.size()] + " (bot)", bot_cid, false)
			bot_idx += 1
	else:
		if player_char_id == "":
			player_char_id = "tachyon"
		_my_horse = _make_horse(0, GameData.player_name, player_char_id, true)
		var bot_names := ["Sakura", "Hana", "Kaze", "Tsuki", "Hoshi"]
		for b in range(5):
			var bot_cid: String = BOT_CHAR_IDS[(b + 1) % BOT_CHAR_IDS.size()]
			_make_horse(b + 1, bot_names[b] + " (bot)", bot_cid, false)

	# Give every horse a reference to all horses for blocking checks
	for h: HorseRacer in _horses:
		h.all_horses = _horses

func _make_horse(lane: int, pname: String, char_id: String = "", is_local: bool = false) -> HorseRacer:
	var horse := HorseRacer.new()
	horse.track        = _track
	horse.lane_idx     = lane
	horse.color_idx    = lane
	horse.horse_name   = pname
	horse.char_id      = char_id
	horse.progress     = 0.0
	horse.current_speed = 0.0
	horse.max_speed    = BASE_MAX_SPEED
	horse.acceleration = BASE_ACCEL
	_horses_node.add_child(horse)
	_horses.append(horse)

	var sm := SkillManager.new()
	sm.name = "SkillManager"
	horse.add_child(sm)
	horse.skill_manager = sm

	call_deferred("_init_skill_manager", sm, horse, char_id, is_local)

	return horse

func _init_skill_manager(sm: SkillManager, horse: HorseRacer, char_id: String, is_local: bool) -> void:
	sm.init(horse, self, _horses, char_id, is_local)
	# Si c'est un bot (pas local et pas un joueur online), lui donner une IA
	if not is_local and not _player_horses.values().has(horse):
		var all_skill_ids := SkillData.ACTIVE_SKILLS.keys()
		var bot_deck: Array = []
		var shuffled := all_skill_ids.duplicate()
		shuffled.shuffle()
		for j in mini(5, shuffled.size()):
			bot_deck.append(shuffled[j])
		sm.init_bot(bot_deck)

func _on_inner() -> void:
	if _my_horse and not _my_finished and _race_started:
		_my_horse.move_inner()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("inner")

func _on_outer() -> void:
	if _my_horse and not _my_finished and _race_started:
		_my_horse.move_outer()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("outer")

func _on_skip() -> void:
	if _skipping:
		return
	_skipping = true
	_lane_btns.visible = false
	if _skill_panel:
		_skill_panel.visible = false
	_skip_btn.text = "ACCELERATING..."
	_skip_btn.disabled = true
	for h: HorseRacer in _horses:
		if not _finish_order.has(h):
			h.set_process(true)
			h.max_speed *= SKIP_SPEED_MULT
			h.acceleration *= SKIP_SPEED_MULT

func _exit_tree() -> void:
	if NetworkManager.lane_change_received.is_connected(_on_remote_lane_change):
		NetworkManager.lane_change_received.disconnect(_on_remote_lane_change)
	if NetworkManager.position_update_received.is_connected(_on_remote_position_update):
		NetworkManager.position_update_received.disconnect(_on_remote_position_update)
	if NetworkManager.skill_use_received.is_connected(_on_remote_skill_use):
		NetworkManager.skill_use_received.disconnect(_on_remote_skill_use)
	if NetworkManager.player_left.is_connected(_on_remote_player_left):
		NetworkManager.player_left.disconnect(_on_remote_player_left)

func _on_retry() -> void:
	if NetworkManager.is_online:
		NetworkManager.disconnect_from_relay()
		GameManager.go_to_main_menu()
	else:
		GameManager.go_to_race()

func _on_menu() -> void:
	if NetworkManager.is_online:
		NetworkManager.disconnect_from_relay()
	GameManager.go_to_main_menu()

func _on_remote_lane_change(player_id: String, direction: String) -> void:
	if player_id in _player_horses:
		var horse: HorseRacer = _player_horses[player_id]
		# Remote players bypass blocking checks — their client is authoritative
		if direction == "inner" and horse.lane_idx > 0:
			horse._switch_lane(horse.lane_idx - 1)
		elif direction == "outer" and horse.lane_idx < 5:
			horse._switch_lane(horse.lane_idx + 1)

func _on_remote_position_update(player_id: String, progress_val: float, laps: int, lane: int, speed: float) -> void:
	if player_id in _player_horses:
		var horse: HorseRacer = _player_horses[player_id]
		horse.progress = progress_val
		horse.laps_completed = laps
		horse.lane_idx = lane
		horse.current_speed = speed

func _on_remote_skill_use(player_id: String, skill_id: String) -> void:
	if player_id in _player_horses:
		var horse: HorseRacer = _player_horses[player_id]
		if horse.skill_manager != null:
			horse.skill_manager.activate_skill(skill_id)
			print("[Race] Player %s used skill '%s'" % [player_id, skill_id])

func _on_remote_player_left(player_id: String) -> void:
	if player_id in _player_horses:
		print("[Race] Player %s disconnected, their horse continues as bot" % player_id)
		_player_horses.erase(player_id)

func _update_bot_lanes(delta: float) -> void:
	if not _race_started:
		return
	for h: HorseRacer in _horses:
		if h.skill_manager == null or not h.skill_manager.is_bot:
			continue
		if _finish_order.has(h):
			continue

		# Cooldown per bot (initial delay of 2s so bots don't move at GO)
		var cd: float = _bot_lane_timers.get(h, 2.0)
		cd -= delta
		if cd > 0.0:
			_bot_lane_timers[h] = cd
			continue

		# Strategy: if blocked, try to change to an adjacent lane to overtake
		if h.is_blocked:
			# Try inner first (faster in turns), then outer
			var moved := false
			if h.lane_idx > 0 and not h.is_lane_blocked_by_neighbor(h.lane_idx - 1):
				h.move_inner()
				moved = true
			elif h.lane_idx < 5 and not h.is_lane_blocked_by_neighbor(h.lane_idx + 1):
				h.move_outer()
				moved = true
			if moved:
				_bot_lane_timers[h] = randf_range(0.6, 1.5)
				continue

		# If not blocked and not on inner lane, try to move inner for speed advantage
		if not h.is_blocked and h.lane_idx > 0:
			if not h.is_lane_blocked_by_neighbor(h.lane_idx - 1):
				h.move_inner()
				_bot_lane_timers[h] = randf_range(1.0, 2.5)
				continue

		_bot_lane_timers[h] = BOT_LANE_CHECK_INTERVAL

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _race_started and not _race_over:
		if _paused:
			_on_resume()
		else:
			_paused = true
			_pause_overlay.visible = true
		return

	if _my_horse == null or _my_finished or not _race_started or _paused:
		return
	if event.is_action_pressed("ui_left"):
		_my_horse.move_inner()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("inner")
	if event.is_action_pressed("ui_right"):
		_my_horse.move_outer()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("outer")

func _process(delta: float) -> void:
	if not _race_started or _race_over:
		return
	for h: HorseRacer in _horses:
		if h.skill_manager != null:
			h.skill_manager.update(delta)
	_update_bot_lanes(delta)
	_check_finishers()
	_update_ui()
	_update_endurance_ui()
	_update_stats_ui()
	_update_tooltip(delta)
	if NetworkManager.is_online and _my_horse and not _my_finished:
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			NetworkManager.send_position_update(
				_my_horse.progress,
				_my_horse.laps_completed,
				_my_horse.lane_idx,
				_my_horse.current_speed
			)

func _check_finishers() -> void:
	for h: HorseRacer in _horses:
		if _finish_order.has(h):
			continue
		# Finish = 3 full laps + end of bottom straight (finish line on the right)
		var finish_prog: float = _track.get_finish_progress(h.lane_idx)
		var finished := false
		if h.laps_completed > LAPS:
			# Way past — definitely finished
			finished = true
		elif h.laps_completed == LAPS and h.progress >= finish_prog:
			# Completed all laps and crossed the finish line at end of bottom straight
			finished = true

		if not finished:
			continue

		_finish_order.append(h)
		h.set_process(false)
		h.is_blocked = false
		h.blocked_by = null
		var rank := _finish_order.size()
		print("[Race] %s finished %s (%d/%d)" % [
			h.horse_name, _ordinal(rank), rank, _horses.size()])

		# Place finished horse at the finish line, each on its own lane
		h.lane_idx = rank - 1
		h.laps_completed = LAPS
		var target_finish: float = _track.get_finish_progress(h.lane_idx)
		h.progress = target_finish
		h.position = _track.get_horse_pos(h.lane_idx, h.progress)
		h.rotation = 0.0  # Face right on the straight

		if h == _my_horse and not _my_finished:
			_my_finished = true
			_lane_btns.visible = false
			if _skill_panel:
				_skill_panel.visible = false

	if _finish_order.size() >= _horses.size():
		_race_over = true
		_show_results()

func _update_ui() -> void:
	if _my_horse == null:
		return

	var current_lap := mini(_my_horse.laps_completed + 1, LAPS)
	_lap_label.text = "%d / %d" % [current_lap, LAPS]

	var my_rank := _get_rank(_my_horse)
	_pos_label.text = _ordinal(my_rank)
	_pos_sub.text = "/ %d racers" % _horses.size()

	match my_rank:
		1: _pos_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
		2: _pos_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		3: _pos_label.add_theme_color_override("font_color", Color(0.8, 0.55, 0.3))
		_: _pos_label.add_theme_color_override("font_color", Color.WHITE)

	if not _my_finished:
		_lane_num.text = str(_my_horse.lane_idx + 1)
		var inner_blocked := _my_horse.lane_idx <= 0 or _my_horse.is_lane_blocked_by_neighbor(_my_horse.lane_idx - 1)
		var outer_blocked := _my_horse.lane_idx >= 5 or _my_horse.is_lane_blocked_by_neighbor(_my_horse.lane_idx + 1)
		_inner_btn.disabled = inner_blocked
		_outer_btn.disabled = outer_blocked
		_inner_btn.modulate.a = 0.4 if inner_blocked else 1.0
		_outer_btn.modulate.a = 0.4 if outer_blocked else 1.0

func _get_rank(horse: HorseRacer) -> int:
	var idx := _finish_order.find(horse)
	if idx >= 0:
		return idx + 1
	var rank := _finish_order.size() + 1
	for h: HorseRacer in _horses:
		if h == horse or _finish_order.has(h):
			continue
		if (h.laps_completed + h.progress) > (horse.laps_completed + horse.progress):
			rank += 1
	return rank

func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n

func get_horse_rank(horse: HorseRacer) -> int:
	return _get_rank(horse)

func get_total_laps() -> int:
	return LAPS

func _build_skill_ui() -> void:
	var skill_ids: Array = GameData.get_skill_ids()
	if skill_ids.is_empty():
		skill_ids = ["speed_boost", "accel_boost", "endurance_recovery", "speed_while_overtaking", "groundwork"]

	_skill_panel = PanelContainer.new()
	_skill_panel.name = "SkillPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.12, 0.8)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	_skill_panel.add_theme_stylebox_override("panel", panel_style)

	_skill_panel.anchor_left = 0.0
	_skill_panel.anchor_right = 1.0
	_skill_panel.anchor_top = 1.0
	_skill_panel.anchor_bottom = 1.0
	_skill_panel.offset_top = -130.0
	_skill_panel.offset_bottom = -8.0
	_skill_panel.offset_left = 200.0
	_skill_panel.offset_right = -200.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_skill_panel.add_child(vbox)

	var endurance_hbox := HBoxContainer.new()
	endurance_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(endurance_hbox)

	var end_label := Label.new()
	end_label.text = "ENDURANCE"
	end_label.add_theme_font_size_override("font_size", 12)
	end_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	endurance_hbox.add_child(end_label)

	_endurance_bar = ProgressBar.new()
	_endurance_bar.min_value = 0.0
	_endurance_bar.max_value = SkillData.MAX_ENDURANCE
	_endurance_bar.value = SkillData.MAX_ENDURANCE
	_endurance_bar.custom_minimum_size = Vector2(0, 18)
	_endurance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endurance_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	bar_bg.set_corner_radius_all(4)
	_endurance_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.6, 1.0, 1.0)
	bar_fill.set_corner_radius_all(4)
	_endurance_bar.add_theme_stylebox_override("fill", bar_fill)
	endurance_hbox.add_child(_endurance_bar)

	_endurance_label = Label.new()
	_endurance_label.text = "10 / 10"
	_endurance_label.add_theme_font_size_override("font_size", 12)
	_endurance_label.add_theme_color_override("font_color", Color.WHITE)
	_endurance_label.custom_minimum_size = Vector2(55, 0)
	endurance_hbox.add_child(_endurance_label)

	# Boutons de skills - design compact
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_skill_buttons = []
	_skill_ids_ordered = []
	for skill_id in skill_ids:
		if not SkillData.ACTIVE_SKILLS.has(skill_id):
			continue
		var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]

		# Bouton carré compact
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Styles
		var _make_style := func(bg: Color, border: Color) -> StyleBoxFlat:
			var s := StyleBoxFlat.new()
			s.bg_color = bg
			s.set_corner_radius_all(10)
			s.border_color = border
			s.set_border_width_all(2)
			s.content_margin_left = 2.0
			s.content_margin_right = 2.0
			s.content_margin_top = 2.0
			s.content_margin_bottom = 2.0
			return s

		btn.add_theme_stylebox_override("normal", _make_style.call(
			Color(0.1, 0.15, 0.3, 0.9), Color(0.35, 0.5, 0.85, 0.6)))
		btn.add_theme_stylebox_override("hover", _make_style.call(
			Color(0.15, 0.22, 0.45, 0.95), Color(0.5, 0.7, 1.0, 0.9)))
		btn.add_theme_stylebox_override("pressed", _make_style.call(
			Color(0.06, 0.08, 0.2, 0.95), Color(0.3, 0.4, 0.7, 0.8)))
		btn.add_theme_stylebox_override("disabled", _make_style.call(
			Color(0.08, 0.08, 0.12, 0.5), Color(0.2, 0.2, 0.25, 0.3)))

		# Contenu: icône centrée
		var btn_content := VBoxContainer.new()
		btn_content.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_content.add_theme_constant_override("separation", 1)
		btn_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(btn_content)

		# Icône de la carte (plus grande)
		var icon_path := "res://assets/cards/%s.png" % def.get("icon", "")
		var tex := load(icon_path) as Texture2D
		if tex:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(50, 50)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_content.add_child(icon)

		# Nom court + coût en bas
		var info_label := Label.new()
		info_label.text = "%s  -%d" % [def.get("short", "?"), int(def["endurance_cost"])]
		info_label.add_theme_font_size_override("font_size", 11)
		info_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_content.add_child(info_label)

		btn.pressed.connect(_on_skill_button.bind(skill_id))
		btn.mouse_entered.connect(_on_skill_hover_start.bind(btn, skill_id))
		btn.mouse_exited.connect(_on_skill_hover_end)
		btn_hbox.add_child(btn)
		_skill_buttons.append(btn)
		_skill_ids_ordered.append(skill_id)

	_ui.add_child(_skill_panel)
	_skill_panel.visible = false

	_skill_tooltip = PanelContainer.new()
	_skill_tooltip.name = "SkillTooltip"
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	tt_style.set_corner_radius_all(8)
	tt_style.border_color = Color(0.4, 0.55, 0.9, 0.7)
	tt_style.set_border_width_all(1)
	tt_style.content_margin_left = 12.0
	tt_style.content_margin_right = 12.0
	tt_style.content_margin_top = 8.0
	tt_style.content_margin_bottom = 8.0
	_skill_tooltip.add_theme_stylebox_override("panel", tt_style)
	_skill_tooltip.anchor_left = 0.5
	_skill_tooltip.anchor_right = 0.5
	_skill_tooltip.anchor_top = 1.0
	_skill_tooltip.anchor_bottom = 1.0
	_skill_tooltip.offset_left = -200.0
	_skill_tooltip.offset_right = 200.0
	_skill_tooltip.offset_top = -180.0
	_skill_tooltip.offset_bottom = -160.0
	_skill_tooltip.visible = false
	_skill_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_tooltip.add_child(_tooltip_label)
	_ui.add_child(_skill_tooltip)

	_build_stats_panel()

func _on_skill_button(skill_id: String) -> void:
	if _my_horse == null or _my_finished or not _race_started:
		return
	if _my_horse.skill_manager == null:
		return
	var ok: bool = _my_horse.skill_manager.activate_skill(skill_id)
	if ok:
		print("[Race] Skill '%s' activated!" % skill_id)
		if NetworkManager.is_online:
			NetworkManager.send_skill_use(skill_id)

func _on_skill_hover_start(btn: Button, skill_id: String) -> void:
	_tooltip_btn = btn
	_tooltip_timer = 0.0
	if not SkillData.ACTIVE_SKILLS.has(skill_id):
		return
	var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]
	_tooltip_label.text = "%s — %s" % [def["label"], def.get("desc", "")]

func _on_skill_hover_end() -> void:
	_tooltip_btn = null
	_tooltip_timer = 0.0
	if _skill_tooltip:
		_skill_tooltip.visible = false

func _update_tooltip(delta: float) -> void:
	if _tooltip_btn == null or _skill_tooltip == null:
		return
	_tooltip_timer += delta
	if _tooltip_timer >= 1.0 and not _skill_tooltip.visible:
		_skill_tooltip.visible = true

func _build_stats_panel() -> void:
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "StatsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.75)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_stats_panel.add_theme_stylebox_override("panel", style)

	_stats_panel.anchor_left = 0.0
	_stats_panel.anchor_top = 0.0
	_stats_panel.offset_left = 20.0
	_stats_panel.offset_top = 100.0
	_stats_panel.offset_right = 180.0
	_stats_panel.offset_bottom = 220.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_stats_panel.add_child(vbox)

	var title := Label.new()
	title.text = "STATS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(title)

	_speed_label = Label.new()
	_speed_label.text = "Speed: 0"
	_speed_label.add_theme_font_size_override("font_size", 14)
	_speed_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(_speed_label)

	_max_speed_label = Label.new()
	_max_speed_label.text = "Max: 0"
	_max_speed_label.add_theme_font_size_override("font_size", 14)
	_max_speed_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_max_speed_label)

	_accel_label = Label.new()
	_accel_label.text = "Accel: 0"
	_accel_label.add_theme_font_size_override("font_size", 14)
	_accel_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(_accel_label)

	_ui.add_child(_stats_panel)
	_stats_panel.modulate.a = 0.0

func _update_stats_ui() -> void:
	if _my_horse == null or _stats_panel == null:
		return
	var effective_max := _my_horse.max_speed
	var effective_accel := _my_horse.acceleration
	if _my_horse.skill_manager != null:
		var speed_bonus: float = _my_horse.skill_manager.get_speed_bonus()
		var accel_bonus: float = _my_horse.skill_manager.get_accel_bonus()
		effective_max = _my_horse.max_speed + (speed_bonus / SkillData.BASE_SPEED) * _my_horse.max_speed
		effective_accel = _my_horse.acceleration + (accel_bonus / SkillData.BASE_ACCEL) * _my_horse.acceleration

	_speed_label.text = "Speed: %.1f" % _my_horse.current_speed
	_max_speed_label.text = "Max: %.1f" % effective_max
	_accel_label.text = "Accel: %.1f" % effective_accel

	if effective_max > _my_horse.max_speed:
		_max_speed_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		_max_speed_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	if effective_accel > _my_horse.acceleration:
		_accel_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		_accel_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))

func _update_endurance_ui() -> void:
	if _my_horse == null or _my_horse.skill_manager == null:
		return
	var sm: SkillManager = _my_horse.skill_manager
	var end_val: float = sm.get_endurance()
	if _endurance_bar:
		_endurance_bar.value = end_val
		var ratio := end_val / SkillData.MAX_ENDURANCE
		var fill_style := StyleBoxFlat.new()
		fill_style.set_corner_radius_all(4)
		if ratio > 0.5:
			fill_style.bg_color = Color(0.2, 0.6, 1.0, 1.0)
		elif ratio > 0.25:
			fill_style.bg_color = Color(1.0, 0.7, 0.2, 1.0)
		else:
			fill_style.bg_color = Color(1.0, 0.25, 0.2, 1.0)
		_endurance_bar.add_theme_stylebox_override("fill", fill_style)
	if _endurance_label:
		_endurance_label.text = "%.0f / %.0f" % [end_val, SkillData.MAX_ENDURANCE]

	for i in _skill_buttons.size():
		var btn: Button = _skill_buttons[i]
		if i < _skill_ids_ordered.size():
			var sid: String = _skill_ids_ordered[i]
			if SkillData.ACTIVE_SKILLS.has(sid):
				var def: Dictionary = SkillData.ACTIVE_SKILLS[sid]
				var cost: float = def["endurance_cost"]
				if sm.character_id == "maruzenski":
					cost += 1.0
				# Check condition
				var condition_met := sm.check_skill_condition(def["condition"])
				var enough_endurance := end_val >= cost
				btn.disabled = not enough_endurance or not condition_met
				# Dim the button more if condition is not met
				if not condition_met:
					btn.modulate.a = 0.35
				elif not enough_endurance:
					btn.modulate.a = 0.5
				else:
					btn.modulate.a = 1.0

func _build_pause_menu() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.visible = false

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.05, 0.7)
	_pause_overlay.add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -160.0
	center.offset_right = 160.0
	center.offset_top = -100.0
	center.offset_bottom = 100.0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	_pause_overlay.add_child(center)

	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(250, 50)
	resume_btn.add_theme_font_size_override("font_size", 20)
	var resume_style := StyleBoxFlat.new()
	resume_style.bg_color = Color(0.15, 0.45, 0.2, 0.95)
	resume_style.set_corner_radius_all(10)
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	resume_btn.add_theme_stylebox_override("hover", resume_style)
	resume_btn.add_theme_stylebox_override("pressed", resume_style)
	resume_btn.pressed.connect(_on_resume)
	center.add_child(resume_btn)

	var abandon_btn := Button.new()
	abandon_btn.text = "FORFEIT"
	abandon_btn.custom_minimum_size = Vector2(250, 50)
	abandon_btn.add_theme_font_size_override("font_size", 20)
	var abandon_style := StyleBoxFlat.new()
	abandon_style.bg_color = Color(0.6, 0.15, 0.15, 0.95)
	abandon_style.set_corner_radius_all(10)
	abandon_btn.add_theme_stylebox_override("normal", abandon_style)
	abandon_btn.add_theme_stylebox_override("hover", abandon_style)
	abandon_btn.add_theme_stylebox_override("pressed", abandon_style)
	abandon_btn.pressed.connect(_on_abandon)
	center.add_child(abandon_btn)

	_ui.add_child(_pause_overlay)

func _on_resume() -> void:
	_pause_overlay.visible = false
	_paused = false

func _on_abandon() -> void:
	_pause_overlay.visible = false
	_paused = false
	if NetworkManager.is_online:
		NetworkManager.disconnect_from_relay()
	GameManager.go_to_main_menu()

func _show_results() -> void:
	_skip_btn.visible = false

	var my_rank := _finish_order.find(_my_horse) + 1

	match my_rank:
		1:
			_win_title.text = "VICTORY!"
			_win_title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		2, 3:
			_win_title.text = "WELL PLAYED!"
			_win_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		_:
			_win_title.text = "RACE FINISHED"
			_win_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	_win_name.text = "%s finished %s" % [_finish_order[0].horse_name, _ordinal(1)]

	var lines := ""
	for i in _finish_order.size():
		var h: HorseRacer = _finish_order[i]
		var medal := ""
		match i:
			0: medal = "  [GOLD]"
			1: medal = "  [SILVER]"
			2: medal = "  [BRONZE]"
		var marker := "  >>  " if h == _my_horse else "      "
		lines += "%s%s%s%s\n" % [_ordinal(i + 1), marker, h.horse_name, medal]
	_rankings.text = lines

	if NetworkManager.is_online:
		_retry_btn.text = "BACK TO MENU"
	else:
		_retry_btn.text = "REPLAY"

	_end_overlay.modulate.a = 0.0
	_end_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_end_overlay, "modulate:a", 1.0, 0.6)

	print("[Race] Race finished! Winner: %s" % _finish_order[0].horse_name)
