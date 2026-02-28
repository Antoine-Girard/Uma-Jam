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

# UI refs
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
var _endurance_bar: ProgressBar       = null
var _endurance_label: Label           = null
var _skill_panel: PanelContainer      = null

# Multiplayer mapping: player_id (String) -> HorseRacer
var _player_horses: Dictionary        = {}


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
	# Cacher les panels pendant l'intro
	$UI/LapPanel.modulate.a = 0.0
	$UI/PosPanel.modulate.a = 0.0
	# Connecter les signaux multijoueur si online
	if NetworkManager.is_online:
		NetworkManager.lane_change_received.connect(_on_remote_lane_change)
		NetworkManager.player_left.connect(_on_remote_player_left)

	_spawn_horses()
	_freeze_horses()
	_build_skill_ui()
	_show_intro()


# ─── Intro joueurs (style Clash Royale) ──────────────────────────────────────

func _show_intro() -> void:
	# Fond semi-transparent
	var bg := ColorRect.new()
	bg.name = "IntroBG"
	bg.color = Color(0.0, 0.0, 0.05, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_right = 0
	bg.offset_bottom = 0
	_ui.add_child(bg)

	# Container centré
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

	# Titre
	var title := Label.new()
	title.text = "COUREURS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	center.add_child(title)
	title.modulate.a = 0.0

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	center.add_child(sep)

	# Créer les cartes joueurs (cachées)
	var cards: Array[Control] = []
	for h: HorseRacer in _horses:
		var card := _make_player_card(h)
		card.modulate.a = 0.0
		center.add_child(card)
		cards.append(card)

	# Animation : titre d'abord
	await get_tree().create_timer(0.3).timeout
	var t_tw := create_tween()
	t_tw.tween_property(title, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.4).timeout

	# Puis chaque carte une par une
	for card: Control in cards:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)
		tw.tween_property(card, "position:x", card.position.x, 0.3) \
			.from(card.position.x + 60.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.18).timeout

	# Attendre un peu que le joueur voit tout
	await get_tree().create_timer(1.5).timeout

	# Fade out l'intro
	var fade := create_tween()
	fade.tween_property(bg, "modulate:a", 0.0, 0.5)
	await fade.finished
	bg.queue_free()

	# Afficher les panels de course
	var panel_tw := create_tween().set_parallel(true)
	panel_tw.tween_property($UI/LapPanel, "modulate:a", 1.0, 0.3)
	panel_tw.tween_property($UI/PosPanel, "modulate:a", 1.0, 0.3)

	# Lancer le countdown
	_start_countdown()


func _make_player_card(horse: HorseRacer) -> PanelContainer:
	# Style du panel
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

	# Bordure colorée à gauche selon le cheval
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

	# Placeholder image du personnage (carré coloré)
	var img_frame := PanelContainer.new()
	var img_style := StyleBoxFlat.new()
	img_style.bg_color = horse_color.darkened(0.2)
	img_style.corner_radius_top_left = 6
	img_style.corner_radius_top_right = 6
	img_style.corner_radius_bottom_right = 6
	img_style.corner_radius_bottom_left = 6
	img_frame.add_theme_stylebox_override("panel", img_style)
	img_frame.custom_minimum_size = Vector2(36, 36)
	hbox.add_child(img_frame)

	# Icône placeholder "?" au centre
	var img_label := Label.new()
	img_label.text = "?"
	img_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	img_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	img_label.add_theme_font_size_override("font_size", 20)
	img_label.add_theme_color_override("font_color", Color.WHITE)
	img_frame.add_child(img_label)

	# Nom du joueur
	var name_label := Label.new()
	name_label.text = horse.horse_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if horse == _my_horse:
		name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.65))
	hbox.add_child(name_label)

	# Trophées
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


# ─── Countdown ────────────────────────────────────────────────────────────────

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

	_countdown.text = "GO !"
	_countdown.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var tween := create_tween()
	tween.tween_property(_countdown, "modulate:a", 0.0, 0.6).set_delay(0.3)

	_race_started = true
	_lane_btns.visible = true
	_skip_btn.visible = true
	if _skill_panel:
		_skill_panel.visible = true
	var fade := create_tween()
	fade.tween_property(_skip_btn, "modulate:a", 1.0, 0.5).set_delay(1.0)
	_unfreeze_horses()


func _freeze_horses() -> void:
	for h: HorseRacer in _horses:
		h.set_process(false)

func _unfreeze_horses() -> void:
	for h: HorseRacer in _horses:
		h.set_process(true)


# ─── Spawn ────────────────────────────────────────────────────────────────────

func _spawn_horses() -> void:
	var player_char_id: String = GameData.character_id

	# Seed déterministe pour que tous les clients aient les mêmes vitesses de bots
	if NetworkManager.race_seed != 0:
		seed(NetworkManager.race_seed)

	if NetworkManager.is_online and not NetworkManager.players_connected.is_empty():
		# Mode online : spawn les vrais joueurs
		var players: Dictionary = NetworkManager.players_connected
		var i := 0
		for pid in players.keys():
			var pname: String = players[pid].get("name", "P%d" % (i + 1))
			var is_me: bool = (pid == NetworkManager.my_player_id)
			var cid: String = player_char_id if is_me else BOT_CHAR_IDS[i % BOT_CHAR_IDS.size()]
			var horse := _make_horse(i, pname, cid, is_me)
			_player_horses[pid] = horse
			if is_me:
				_my_horse = horse
			i += 1

		# Remplir avec des bots jusqu'à 6
		var bot_names := ["Sakura", "Hana", "Kaze", "Tsuki", "Hoshi"]
		var bot_idx := 0
		while _horses.size() < MAX_PLAYERS:
			var bot_cid: String = BOT_CHAR_IDS[(i + bot_idx) % BOT_CHAR_IDS.size()]
			_make_horse(_horses.size(), bot_names[bot_idx % bot_names.size()], bot_cid, false)
			bot_idx += 1
	else:
		# Mode solo / test
		if player_char_id == "":
			player_char_id = "tachyon"
		_my_horse = _make_horse(0, "Joueur", player_char_id, true)
		var bot_names := ["Sakura", "Hana", "Kaze", "Tsuki", "Hoshi"]
		for b in range(5):
			var bot_cid: String = BOT_CHAR_IDS[(b + 1) % BOT_CHAR_IDS.size()]
			_make_horse(b + 1, bot_names[b], bot_cid, false)


func _make_horse(lane: int, pname: String, char_id: String = "", is_local: bool = false) -> HorseRacer:
	var horse := HorseRacer.new()
	horse.track        = _track
	horse.lane_idx     = lane
	horse.color_idx    = lane
	horse.horse_name   = pname
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


# ─── Controles ────────────────────────────────────────────────────────────────

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
	_skip_btn.text = "ACCELERATION..."
	_skip_btn.disabled = true
	for h: HorseRacer in _horses:
		if not _finish_order.has(h):
			h.set_process(true)
			h.max_speed *= SKIP_SPEED_MULT
			h.acceleration *= SKIP_SPEED_MULT

func _exit_tree() -> void:
	if NetworkManager.lane_change_received.is_connected(_on_remote_lane_change):
		NetworkManager.lane_change_received.disconnect(_on_remote_lane_change)
	if NetworkManager.player_left.is_connected(_on_remote_player_left):
		NetworkManager.player_left.disconnect(_on_remote_player_left)

func _on_retry() -> void:
	GameManager.go_to_race()

func _on_menu() -> void:
	if NetworkManager.is_online:
		NetworkManager.disconnect_from_relay()
	GameManager.go_to_main_menu()


# ─── Réseau : réception ─────────────────────────────────────────────────────

func _on_remote_lane_change(player_id: String, direction: String) -> void:
	if player_id in _player_horses:
		var horse: HorseRacer = _player_horses[player_id]
		if direction == "inner":
			horse.move_inner()
		elif direction == "outer":
			horse.move_outer()


func _on_remote_player_left(player_id: String) -> void:
	if player_id in _player_horses:
		# Le cheval continue tout seul (comme un bot)
		print("[Race] Joueur %s déconnecté, son cheval continue en bot" % player_id)
		_player_horses.erase(player_id)


func _input(event: InputEvent) -> void:
	if _my_horse == null or _my_finished or not _race_started:
		return
	if event.is_action_pressed("ui_left"):
		_my_horse.move_inner()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("inner")
	if event.is_action_pressed("ui_right"):
		_my_horse.move_outer()
		if NetworkManager.is_online:
			NetworkManager.send_lane_change("outer")


# ─── Boucle principale ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _race_started or _race_over:
		return
	for h: HorseRacer in _horses:
		if h.skill_manager != null:
			h.skill_manager.update(delta)
	_check_finishers()
	_update_ui()
	_update_endurance_ui()


func _check_finishers() -> void:
	for h: HorseRacer in _horses:
		if h.laps_completed >= LAPS and not _finish_order.has(h):
			_finish_order.append(h)
			h.set_process(false)
			print("[Race] %s termine %s (%d/%d)" % [
				h.horse_name, _ordinal(_finish_order.size()),
				_finish_order.size(), _horses.size()])

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
	_pos_sub.text = "/ %d coureurs" % _horses.size()

	match my_rank:
		1: _pos_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
		2: _pos_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		3: _pos_label.add_theme_color_override("font_color", Color(0.8, 0.55, 0.3))
		_: _pos_label.add_theme_color_override("font_color", Color.WHITE)

	if not _my_finished:
		_lane_num.text = str(_my_horse.lane_idx + 1)
		_inner_btn.disabled = _my_horse.lane_idx <= 0
		_outer_btn.disabled = _my_horse.lane_idx >= 5
		_inner_btn.modulate.a = 0.4 if _inner_btn.disabled else 1.0
		_outer_btn.modulate.a = 0.4 if _outer_btn.disabled else 1.0


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
	if n == 1:
		return "1er"
	return "%deme" % n


# ─── Skill system helpers (used by SkillManager) ─────────────────────────────

## Returns the 1-based rank of the given horse (1 = first).
## Called by SkillManager._get_my_rank() to avoid duplicating logic.
func get_horse_rank(horse: HorseRacer) -> int:
	return _get_rank(horse)


## Returns the total number of laps in this race.
## Called by SkillManager._get_race_phase() for phase calculation.
func get_total_laps() -> int:
	return LAPS


# ─── Skill UI ─────────────────────────────────────────────────────────────────

func _build_skill_ui() -> void:
	var skill_ids: Array = GameData.get_skill_ids()
	if skill_ids.is_empty():
		skill_ids = ["speed_boost", "accel_boost", "endurance_recovery"]

	_skill_panel = PanelContainer.new()
	_skill_panel.name = "SkillPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.12, 0.75)
	panel_style.set_corner_radius_all(10)
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
	_skill_panel.offset_bottom = -10.0
	_skill_panel.offset_left = 10.0
	_skill_panel.offset_right = -10.0

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

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_skill_buttons = []
	for skill_id in skill_ids:
		if not SkillData.ACTIVE_SKILLS.has(skill_id):
			continue
		var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]
		var btn := Button.new()
		btn.text = def["label"]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.25, 0.5, 0.9)
		btn_style.set_corner_radius_all(8)
		btn_style.border_color = Color(0.4, 0.6, 1.0, 0.6)
		btn_style.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.2, 0.35, 0.65, 0.95)
		btn_hover.set_corner_radius_all(8)
		btn_hover.border_color = Color(0.5, 0.7, 1.0, 0.8)
		btn_hover.set_border_width_all(1)
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.1, 0.15, 0.35, 0.9)
		btn_pressed.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		var btn_disabled := StyleBoxFlat.new()
		btn_disabled.bg_color = Color(0.12, 0.12, 0.18, 0.6)
		btn_disabled.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("disabled", btn_disabled)

		btn.add_theme_font_size_override("font_size", 13)

		var cost_str := "  (-%d end)" % int(def["endurance_cost"])
		btn.tooltip_text = "%s%s\n%s" % [def["label"], cost_str,
			"Condition: " + def["condition"] if def["condition"] != "" else "Pas de condition"]

		btn.pressed.connect(_on_skill_button.bind(skill_id))
		btn_hbox.add_child(btn)
		_skill_buttons.append(btn)

	_ui.add_child(_skill_panel)
	_skill_panel.visible = false


func _on_skill_button(skill_id: String) -> void:
	if _my_horse == null or _my_finished or not _race_started:
		return
	if _my_horse.skill_manager == null:
		return
	var ok: bool = _my_horse.skill_manager.activate_skill(skill_id)
	if ok:
		print("[Race] Skill '%s' activé !" % skill_id)


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
		var skill_ids: Array = GameData.get_skill_ids()
		if skill_ids.is_empty():
			skill_ids = ["speed_boost", "accel_boost", "endurance_recovery"]
		if i < skill_ids.size():
			var sid: String = skill_ids[i]
			if SkillData.ACTIVE_SKILLS.has(sid):
				var cost: float = SkillData.ACTIVE_SKILLS[sid]["endurance_cost"]
				if sm.character_id == "maruzenski":
					cost += 1.0
				btn.disabled = end_val < cost


# ─── Fin de course ───────────────────────────────────────────────────────────

func _show_results() -> void:
	_skip_btn.visible = false

	var my_rank := _finish_order.find(_my_horse) + 1

	match my_rank:
		1:
			_win_title.text = "VICTOIRE !"
			_win_title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		2, 3:
			_win_title.text = "BIEN JOUE !"
			_win_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		_:
			_win_title.text = "COURSE TERMINEE"
			_win_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	_win_name.text = "%s termine %s" % [_finish_order[0].horse_name, _ordinal(1)]

	var lines := ""
	for i in _finish_order.size():
		var h: HorseRacer = _finish_order[i]
		var medal := ""
		match i:
			0: medal = "  [OR]"
			1: medal = "  [ARGENT]"
			2: medal = "  [BRONZE]"
		var marker := "  >>  " if h == _my_horse else "      "
		lines += "%s%s%s%s\n" % [_ordinal(i + 1), marker, h.horse_name, medal]
	_rankings.text = lines

	_end_overlay.modulate.a = 0.0
	_end_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_end_overlay, "modulate:a", 1.0, 0.6)

	print("[Race] Course terminee ! Gagnant: %s" % _finish_order[0].horse_name)
