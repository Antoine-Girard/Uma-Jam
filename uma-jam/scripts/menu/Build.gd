extends Control

const MAX_DECK_SIZE = 5

const CHARACTERS = [
	{ "id": "agnestachyon_icon",   "name": "Agnes Tachyon",   "type": "Endurance",   "skill": "Gains speed when activating an endurance skill (+3; 4s)" },
	{ "id": "elcondorpasa_icon",   "name": "El Condor Pasa",   "type": "Power", "skill": "Gains acceleration during last spurt when between 2nd and 4th (+2, perm)" },
	{ "id": "goldship_icon",       "name": "Gold Ship",        "type": "Overtake", "skill": "Gains speed when overtaking (+2; 5s)" },
	{ "id": "maruzensky_icon",     "name": "Maruzensky",       "type": "Speed",   "skill": "Gains speed if not 1st (+1, perm but +1 endurance cost on skills)" },
	{ "id": "oguricap_icon",       "name": "Oguri Cap",        "type": "All in", "skill": "Gains speed in the final straight (+4 acceleration and speed)" },
	{ "id": "sakurabakushino_icon","name": "Sakura Bakushin",  "type": "Sprint",    "skill": "Gains speed in T2 if not first (+1, +10s)" },
	{ "id": "specialweek_icon",    "name": "Special Week",     "type": "Power", "skill": "Gains acceleration during last spurt when between 4th and 6th (+3, perm)" },
	{ "id": "symbolirudolf_icon",  "name": "Symboli Rudolf",   "type": "Debuff",  "skill": "Debuffs the horse ahead in the same lane (-2, 3s)" },
]

const CARDS = [
	{ "id": "vitesse_active",      "name": "Speed",          "category": "Active",     "img": "tex_support_card_30011", "desc": "Gains speed (+2, 4s, -2 endurance)" },
	{ "id": "acceleration_active", "name": "Acceleration",     "category": "Active",     "img": "tex_support_card_30014", "desc": "Gains acceleration (+2, 3s, -2 endurance)" },
	{ "id": "endurance_active",    "name": "Endurance Recovery",  "category": "Active",     "img": "tex_support_card_30028", "desc": "Endurance recovery (+2, 25s, -4 endurance)" },
	{ "id": "vitesse_doublement",   "name": "Overtaking Speed", "category": "Condition", "img": "tex_support_card_30043", "desc": "Gains speed when overtaking (+3, 5s, -3 endurance)" },
	{ "id": "acceleration_t1",     "name": "Starting Accel",    "category": "Condition", "img": "tex_support_card_30076", "desc": "Acceleration from race start (+2, 5s, -2) — T1 only" },
	{ "id": "leader_t3",           "name": "Leader's T3 Surge", "category": "Condition", "img": "tex_support_card_30265", "desc": "Gains speed and accel if 1st at T3 (+4, +3, 10s, -2 endurance)" },
	{ "id": "last_place_t3",       "name": "Comeback Sprint",   "category": "Condition", "img": "tex_support_card_30256", "desc": "Gains speed and accel if last at T3 (+5, +4, 10s, -2 endurance)" },
	{ "id": "drafting_speed",      "name": "Drafting Burst",    "category": "Condition", "img": "tex_support_card_30057", "desc": "Gains speed when close behind a horse in same lane (+3, 4s, -1 endurance)" },
]

var selected_character: Dictionary = {}
var deck: Array = []

@onready var char_list        = $MainLayout/LeftPanel/CharScroll/CharList
@onready var card_grid        = $MainLayout/RightPanel/CardScroll/CardGrid
@onready var deck_title       = $MainLayout/RightPanel/DeckTitlePanel/DeckTitle
@onready var deck_slots       = $MainLayout/RightPanel/DeckSlots
@onready var back_btn         = $TopBar/BackButton
@onready var portrait_label   = $MainLayout/MiddlePanel/SelectedPortrait/PortraitLabel
@onready var portrait_texture = $MainLayout/MiddlePanel/SelectedPortrait/PortraitTexture
@onready var selected_name_lb  = $MainLayout/MiddlePanel/SelectedName
@onready var selected_type_lb  = $MainLayout/MiddlePanel/SelectedType
@onready var selected_skill_lb = $MainLayout/MiddlePanel/SelectedSkill

func _ready():
	print("[Build] Loaded")
	back_btn.pressed.connect(_on_back_pressed)
	_populate_characters()
	_populate_cards()
	for i in range(MAX_DECK_SIZE):
		var slot: Panel = deck_slots.get_node("Slot%d" % (i + 1))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
	_restore_from_gamedata()
	_refresh_deck_ui()
	_refresh_card_grid()

func _restore_from_gamedata():
	if GameData.selected_icon_id != "":
		for char_data in CHARACTERS:
			if char_data["id"] == GameData.selected_icon_id:
				selected_character = char_data
				var tex = load("res://assets/characters/" + char_data["id"] + ".png")
				portrait_texture.texture = tex
				portrait_label.visible = tex == null
				selected_name_lb.text  = char_data["name"]
				selected_type_lb.text  = "[ %s ]" % char_data["type"]
				selected_skill_lb.text = char_data.get("skill", "")
				var idx := 0
				for child in char_list.get_children():
					if child is Button:
						if CHARACTERS[idx]["id"] == char_data["id"]:
							child.button_pressed = true
							child.modulate = Color(1, 1, 1, 1)
						else:
							child.modulate = Color(1, 1, 1, 0.7)
						idx += 1
				print("[Build] Character restored: %s" % char_data["name"])
				break

	var saved_deck: Array = GameData.get_deck()
	if saved_deck.size() > 0:
		deck = saved_deck.duplicate()
		print("[Build] Deck restored: %d cards" % deck.size())

func _populate_characters():
	for child in char_list.get_children():
		child.queue_free()

	for char_data in CHARACTERS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 90)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_contents = true
		btn.text = ""
		btn.tooltip_text = "%s  [ %s ]\n%s" % [char_data["name"], char_data["type"], char_data.get("skill", "")]

		var tex = TextureRect.new()
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.texture = load("res://assets/characters/" + char_data["id"] + ".png")
		btn.add_child(tex)

		btn.pressed.connect(_on_character_selected.bind(char_data, btn))
		char_list.add_child(btn)

func _on_character_selected(char_data: Dictionary, btn: Button):
	selected_character = char_data
	print("[Build] Character selected: %s" % char_data["name"])

	for child in char_list.get_children():
		if child is Button:
			child.button_pressed = false
			child.modulate = Color(1, 1, 1, 0.7)
	btn.button_pressed = true
	btn.modulate = Color(1, 1, 1, 1)

	var tex = load("res://assets/characters/" + char_data["id"] + ".png")
	portrait_texture.texture = tex
	portrait_label.visible = tex == null
	selected_name_lb.text  = char_data["name"]
	selected_type_lb.text  = "[ %s ]" % char_data["type"]
	selected_skill_lb.text = char_data.get("skill", "")

func _card_color(category: String) -> Color:
	match category:
		"Active":     return Color(0.18, 0.35, 0.65, 0.45)
		"Condition": return Color(0.65, 0.38, 0.10, 0.45)
		_:           return Color(0.25, 0.25, 0.3, 0.45)

func _populate_cards():
	for child in card_grid.get_children():
		child.queue_free()

	for card_data in CARDS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 170)
		btn.clip_contents = true
		btn.text = ""

		var bg = ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = _card_color(card_data["category"])
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)

		var img_path = "res://assets/cards/" + card_data["img"] + ".png"
		var img = Image.load_from_file(ProjectSettings.globalize_path(img_path))
		if img:
			var tex = TextureRect.new()
			tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex.texture = ImageTexture.create_from_image(img)
			btn.add_child(tex)

		btn.tooltip_text = "%s  [%s]\n%s" % [card_data["name"], card_data["category"], card_data["desc"]]

		btn.pressed.connect(_on_card_selected.bind(card_data))
		card_grid.add_child(btn)

func _on_card_selected(card_data: Dictionary):
	if deck.size() >= MAX_DECK_SIZE:
		print("[Build] Deck full!")
		return

	for c in deck:
		if c["id"] == card_data["id"]:
			print("[Build] Card already in deck: %s" % card_data["name"])
			return

	deck.append(card_data)
	print("[Build] Card added: %s (%d/%d)" % [card_data["name"], deck.size(), MAX_DECK_SIZE])
	_refresh_deck_ui()
	_refresh_card_grid()

func _on_slot_pressed(index: int):
	if index < deck.size():
		print("[Build] Card removed: %s" % deck[index]["name"])
		deck.remove_at(index)
		_refresh_deck_ui()
		_refresh_card_grid()

func _refresh_card_grid():
	var deck_ids = []
	for c in deck:
		deck_ids.append(c["id"])
	var idx = 0
	for card_data in CARDS:
		if idx < card_grid.get_child_count():
			var btn = card_grid.get_child(idx)
			if card_data["id"] in deck_ids:
				btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
				btn.disabled = true
			else:
				btn.modulate = Color(1, 1, 1, 1)
				btn.disabled = false
		idx += 1

func _refresh_deck_ui():
	deck_title.text = "MY DECK  (%d / %d)" % [deck.size(), MAX_DECK_SIZE]

	for i in range(MAX_DECK_SIZE):
		var slot: Panel = deck_slots.get_node("Slot%d" % (i + 1))
		var label: Label = slot.get_node("SlotLabel")

		if slot.has_node("SlotTex"):
			var old_tex = slot.get_node("SlotTex")
			slot.remove_child(old_tex)
			old_tex.queue_free()

		if i < deck.size():
			label.text = ""

			var occupied_style = StyleBoxFlat.new()
			occupied_style.bg_color = Color(0.1, 0.12, 0.2, 1)
			occupied_style.border_color = Color(0.45, 0.6, 1.0, 0.7)
			occupied_style.set_border_width_all(2)
			occupied_style.set_corner_radius_all(8)
			slot.add_theme_stylebox_override("panel", occupied_style)

			var img_path = "res://assets/cards/" + deck[i]["img"] + ".png"
			var img = Image.load_from_file(ProjectSettings.globalize_path(img_path))
			if img:
				var tex_rect = TextureRect.new()
				tex_rect.name = "SlotTex"
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tex_rect.texture = ImageTexture.create_from_image(img)
				slot.add_child(tex_rect)

			slot.tooltip_text = "%s  [%s]\n%s" % [deck[i]["name"], deck[i]["category"], deck[i]["desc"]]
		else:
			label.text = "EMPTY"
			slot.tooltip_text = ""

			var empty_style = StyleBoxFlat.new()
			empty_style.bg_color = Color(0.08, 0.08, 0.12, 1)
			empty_style.border_color = Color(0.25, 0.25, 0.35, 0.5)
			empty_style.set_border_width_all(2)
			empty_style.set_corner_radius_all(8)
			slot.add_theme_stylebox_override("panel", empty_style)

func _on_slot_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_pressed(index)

func _on_back_pressed():
	if selected_character.size() > 0:
		GameData.select_character(selected_character["name"], selected_character["id"])
	if deck.size() > 0:
		GameData.set_deck(deck)
	print("[Build] Saving -> character: %s | deck: %d cards" % [
		selected_character.get("name", "aucun"), deck.size()])
	GameManager.go_to_main_menu()
