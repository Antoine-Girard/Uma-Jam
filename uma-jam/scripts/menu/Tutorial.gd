extends Control

const PAGES := [
	{
		"title": "WHAT IS UMA MUSUME?",
		"content": [
			{ "type": "text", "value": "Uma Musume: Pretty Derby is a Japanese multimedia franchise where horse girls — characters inspired by real legendary racehorses — compete in thrilling races." },
			{ "type": "spacer" },
			{ "type": "text_accent", "value": "UMA-JAM-RACING is a fan game tribute to this universe." },
			{ "type": "spacer" },
			{ "type": "text", "value": "Each character has the spirit and legacy of a famous racehorse. Agnes Tachyon, Gold Ship, Oguri Cap... they all have unique abilities reflecting their real-life racing style." },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Game Jam Themes" },
			{ "type": "text_highlight", "value": "HORSE" },
			{ "type": "text", "value": "You race as horse girls on an oval track, competing for 1st place." },
			{ "type": "spacer" },
			{ "type": "text_highlight", "value": "ONE-HANDED GAMEPLAY" },
			{ "type": "text", "value": "Your horse runs automatically! You only control lane changes and skill activation — all with simple taps, playable with one hand." },
		]
	},
	{
		"title": "HOW TO PLAY",
		"content": [
			{ "type": "heading", "value": "The Race" },
			{ "type": "text", "value": "Your horse runs forward automatically on an oval track. The race lasts 3 laps and ends at the finish line on the right side of the bottom straight." },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Lane Controls" },
			{ "type": "diagram", "value": "lane_controls" },
			{ "type": "text", "value": "Use the INNER / OUTER buttons to switch between 6 lanes. Inner lanes are shorter in turns (faster!), but you might get blocked by someone ahead." },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Blocking & Overtaking" },
			{ "type": "text", "value": "If a horse is directly ahead in your lane, you're BLOCKED — your speed is capped to theirs. To overtake:" },
			{ "type": "text_accent", "value": "1. Change to an adjacent lane\n2. Accelerate past them\n3. Change back to the inner lane" },
			{ "type": "spacer" },
			{ "type": "text", "value": "You cannot change lane if another horse is blocking that lane." },
		]
	},
	{
		"title": "SKILLS & ENDURANCE",
		"content": [
			{ "type": "heading", "value": "Endurance" },
			{ "type": "text", "value": "You have an endurance bar (max 10). It regenerates slowly over time. Every skill costs endurance to activate — manage it wisely!" },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Skill Cards" },
			{ "type": "text", "value": "Before racing, you build a deck of 5 skill cards in the BUILD menu. During the race, tap a skill to activate it." },
			{ "type": "spacer" },
			{ "type": "skill_list" },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Conditions" },
			{ "type": "text", "value": "Some skills have activation conditions:" },
			{ "type": "text_accent", "value": "- 'While overtaking' — you must be passing someone\n- 'Lap 1 only' — only available in the first lap" },
			{ "type": "text", "value": "Greyed-out skills mean the condition isn't met or you lack endurance." },
		]
	},
	{
		"title": "CHARACTERS",
		"content": [
			{ "type": "heading", "value": "Choose Your Horse Girl" },
			{ "type": "text", "value": "Each character has a unique passive ability that activates automatically during the race." },
			{ "type": "spacer" },
			{ "type": "character_grid" },
		]
	},
	{
		"title": "STRATEGY TIPS",
		"content": [
			{ "type": "heading", "value": "Lane Strategy" },
			{ "type": "diagram", "value": "track_overview" },
			{ "type": "text", "value": "Inner lanes (1-2) are faster in turns because the path is shorter. Outer lanes (5-6) are longer but let you avoid traffic." },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Race Phases" },
			{ "type": "text_accent", "value": "Lap 1 — T1 (Opening)" },
			{ "type": "text", "value": "Conserve endurance. Use 'Groundwork' if you have it. Jockey for a good inner position." },
			{ "type": "spacer" },
			{ "type": "text_accent", "value": "Lap 2 — T2 (Mid-Race)" },
			{ "type": "text", "value": "Start using skills to gain advantages. Watch for blocking opportunities on inner lanes." },
			{ "type": "spacer" },
			{ "type": "text_accent", "value": "Lap 3 — Last Spurt!" },
			{ "type": "text", "value": "All-out sprint! Use remaining skills and fight for position in the final straight." },
			{ "type": "spacer" },
			{ "type": "heading", "value": "Key Tips" },
			{ "type": "text_accent", "value": "- Don't waste endurance early\n- Inner lane = shorter path in turns\n- Change lane to overtake, then go back inner\n- Save a speed boost for the final straight\n- Pick skills that match your character's passive" },
		]
	},
]

var _current_page: int = 0
var _page_container: VBoxContainer
var _title_label: Label
var _page_indicator: Label
var _prev_btn: Button
var _next_btn: Button
var _scroll: ScrollContainer

func _ready():
	_build_ui()
	_show_page(0)

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.06, 0.06, 0.1, 1.0)
	add_child(bg)

	# Title
	_title_label = Label.new()
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 1.0
	_title_label.offset_top = 25.0
	_title_label.offset_bottom = 85.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_title_label.add_theme_constant_override("outline_size", 4)
	add_child(_title_label)

	# Scroll container for content
	_scroll = ScrollContainer.new()
	_scroll.anchor_left = 0.0
	_scroll.anchor_right = 1.0
	_scroll.anchor_top = 0.0
	_scroll.anchor_bottom = 1.0
	_scroll.offset_left = 80.0
	_scroll.offset_right = -80.0
	_scroll.offset_top = 95.0
	_scroll.offset_bottom = -80.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_page_container = VBoxContainer.new()
	_page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_container.add_theme_constant_override("separation", 6)
	_scroll.add_child(_page_container)

	# Bottom navigation bar
	var nav := HBoxContainer.new()
	nav.anchor_left = 0.0
	nav.anchor_right = 1.0
	nav.anchor_top = 1.0
	nav.anchor_bottom = 1.0
	nav.offset_left = 20.0
	nav.offset_right = -20.0
	nav.offset_top = -65.0
	nav.offset_bottom = -15.0
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 20)
	add_child(nav)

	# Back button
	var back_btn := _make_nav_button("BACK", Color(0.4, 0.2, 0.15, 0.9))
	back_btn.pressed.connect(_on_back)
	nav.add_child(back_btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)

	# Prev
	_prev_btn = _make_nav_button("<  PREV", Color(0.15, 0.2, 0.35, 0.9))
	_prev_btn.pressed.connect(_on_prev)
	nav.add_child(_prev_btn)

	# Page indicator
	_page_indicator = Label.new()
	_page_indicator.add_theme_font_size_override("font_size", 18)
	_page_indicator.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	_page_indicator.custom_minimum_size = Vector2(80, 0)
	_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(_page_indicator)

	# Next
	_next_btn = _make_nav_button("NEXT  >", Color(0.15, 0.35, 0.2, 0.9))
	_next_btn.pressed.connect(_on_next)
	nav.add_child(_next_btn)

func _make_nav_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 42)
	btn.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	return btn

func _show_page(idx: int) -> void:
	_current_page = clampi(idx, 0, PAGES.size() - 1)

	# Clear old content
	for c in _page_container.get_children():
		c.queue_free()

	var page: Dictionary = PAGES[_current_page]
	_title_label.text = page["title"]
	_page_indicator.text = "%d / %d" % [_current_page + 1, PAGES.size()]
	_prev_btn.disabled = _current_page <= 0
	_prev_btn.modulate.a = 0.4 if _current_page <= 0 else 1.0
	_next_btn.disabled = _current_page >= PAGES.size() - 1
	_next_btn.modulate.a = 0.4 if _current_page >= PAGES.size() - 1 else 1.0

	# Build content
	for item in page["content"]:
		var type: String = item.get("type", "")
		match type:
			"text":
				_add_text(item["value"], 16, Color(0.82, 0.82, 0.88))
			"text_accent":
				_add_text(item["value"], 16, Color(0.55, 0.85, 1.0))
			"text_highlight":
				_add_highlight_badge(item["value"])
			"heading":
				_add_heading(item["value"])
			"spacer":
				_add_spacer(8)
			"diagram":
				_add_diagram(item["value"])
			"skill_list":
				_add_skill_list()
			"character_grid":
				_add_character_grid()

	_scroll.scroll_vertical = 0

func _add_text(txt: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = txt
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_container.add_child(label)

func _add_heading(txt: String) -> void:
	var label := Label.new()
	label.text = txt
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 2)
	_page_container.add_child(label)

func _add_spacer(height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	_page_container.add_child(s)

func _add_highlight_badge(txt: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.45, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = txt
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	panel.add_child(label)
	_page_container.add_child(panel)

func _add_diagram(diagram_id: String) -> void:
	match diagram_id:
		"lane_controls":
			_add_lane_diagram()
		"track_overview":
			_add_track_diagram()

func _add_lane_diagram() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	style.set_border_width_all(1)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var lines := [
		"  Lane 1 (innermost)  ----  Shortest path in turns",
		"  Lane 2              ----",
		"  Lane 3              ----       YOU -->  [INNER]  [OUTER]",
		"  Lane 4              ----",
		"  Lane 5              ----",
		"  Lane 6 (outermost)  ----  Longest path in turns",
	]
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
		vbox.add_child(l)

	_page_container.add_child(panel)

func _add_track_diagram() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	style.set_border_width_all(1)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var lines := [
		"           ___Top Straight (backstretch)___",
		"          /                                 \\",
		"  Left   |                                   |  Right",
		"  Turn   |         OVAL TRACK                |  Turn",
		"          \\__ __ __ __ __ __ __ __ __ __ __/",
		"    START ->  Bottom Straight (homestretch)  -> FINISH",
		"",
		"  Inner lanes (1-2): shorter turns = faster!",
		"  Outer lanes (5-6): longer turns but less traffic",
	]
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
		vbox.add_child(l)

	_page_container.add_child(panel)

func _add_skill_list() -> void:
	for skill_id in SkillData.ACTIVE_SKILLS.keys():
		var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.22, 0.85)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		panel.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		panel.add_child(hbox)

		# Skill icon
		var icon_path := "res://assets/cards/%s.png" % def.get("icon", "")
		var tex := load(icon_path) as Texture2D
		if tex:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(36, 36)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			hbox.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = "%s  [%s]  — Cost: %d" % [def["label"], def.get("short", "?"), int(def["endurance_cost"])]
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = def.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_label)

		_page_container.add_child(panel)

func _add_character_grid() -> void:
	for char_id in SkillData.CHARACTER_PASSIVES.keys():
		var passive: Dictionary = SkillData.CHARACTER_PASSIVES[char_id]
		var icon_id: String = GameData.CHAR_ID_TO_ICON.get(char_id, "")

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.22, 0.85)
		style.set_corner_radius_all(8)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		panel.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		panel.add_child(hbox)

		# Character portrait
		if icon_id != "":
			var tex := load("res://assets/characters/%s.png" % icon_id) as Texture2D
			if tex:
				var portrait := TextureRect.new()
				portrait.texture = tex
				portrait.custom_minimum_size = Vector2(52, 52)
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				hbox.add_child(portrait)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		# Name
		var name_label := Label.new()
		var display_name: String = char_id.replace("_", " ").capitalize()
		name_label.text = display_name
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		info.add_child(name_label)

		# Passive name
		var passive_name := Label.new()
		passive_name.text = passive["label"]
		passive_name.add_theme_font_size_override("font_size", 14)
		passive_name.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		info.add_child(passive_name)

		# Passive desc
		var passive_desc := Label.new()
		passive_desc.text = passive["desc"]
		passive_desc.add_theme_font_size_override("font_size", 13)
		passive_desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		passive_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(passive_desc)

		_page_container.add_child(panel)

func _on_prev() -> void:
	if _current_page > 0:
		_show_page(_current_page - 1)

func _on_next() -> void:
	if _current_page < PAGES.size() - 1:
		_show_page(_current_page + 1)

func _on_back() -> void:
	GameManager.go_to_main_menu()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	elif event.is_action_pressed("ui_left"):
		_on_prev()
	elif event.is_action_pressed("ui_right"):
		_on_next()
