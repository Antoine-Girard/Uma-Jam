extends Control

# ============================================================================
# Build.gd - Sélection de personnage et construction de deck
# ============================================================================

const MAX_DECK_SIZE = 5

# ─── Données de référence (à remplacer par GameData plus tard) ───
const CHARACTERS = [
	{ "id": "agnestachyon_icon",   "name": "Agnes Tachyon",   "type": "Endurance",   "skill": "Gagne de la vitesse en activant un skill d'endurance (+3; 4s)" },
	{ "id": "elcondorpasa_icon",   "name": "El Condor Pasa",   "type": "Puissance", "skill": "Gagne de l'accélération durant le last spurt quand elle est entre 2ème et 4ème (+2, perm)" },
	{ "id": "goldship_icon",       "name": "Gold Ship",        "type": "Overtake", "skill": "Gagne de la vitesse quand elle double (+2; 5s)" },
	{ "id": "maruzensky_icon",     "name": "Maruzensky",       "type": "Vitesse",   "skill": "Gagne de la vitesse si pas 1ère (+1, perm. mais +1 consommation d'endurance dans les skills)" },
	{ "id": "oguricap_icon",       "name": "Oguri Cap",        "type": "All in", "skill": "Gagne de la vitesse dans la dernière ligne droite (+4 accélération et vitesse)" },
	{ "id": "sakurabakushino_icon","name": "Sakura Bakushin",  "type": "Sprint",    "skill": "Gagne de la vitesse dans le T2 si pas première (+1, +10s)" },
	{ "id": "specialweek_icon",    "name": "Special Week",     "type": "Puissance", "skill": "Gagne de l'accélération durant le last spurt quand elle est entre 4ème et 6ème (+3, perm)" },
	{ "id": "symbolirudolf_icon",  "name": "Symboli Rudolf",   "type": "Debuf",  "skill": "Débuff la personne devant sur la même ligne (-2, 3s)" },
]

const CARDS = [
	# ── Actifs polyvalents ──
	{ "id": "vitesse_active",      "name": "Vitesse",          "category": "Actif",     "img": "tex_support_card_30011", "desc": "Gagne de la vitesse (+2, 4s, -2 endurance)" },
	{ "id": "acceleration_active", "name": "Accélération",     "category": "Actif",     "img": "tex_support_card_30014", "desc": "Gagne de l'accélération (+2, 3s, -2 endurance)" },
	{ "id": "endurance_active",    "name": "Récup. Endurance",  "category": "Actif",     "img": "tex_support_card_30028", "desc": "Récupération d'endurance (+2, 25s, -4 endurance)" },
	# ── Sous condition ──
	{ "id": "vitesse_doublement",   "name": "Vitesse Doublant", "category": "Condition", "img": "tex_support_card_30043", "desc": "Gagne de la vitesse en doublant (+3, 5s, -3 endurance)" },
	{ "id": "acceleration_t1",     "name": "Accél. Départ",    "category": "Condition", "img": "tex_support_card_30076", "desc": "Accélération dès le début de course (+2, 5s, -2) — T1 uniquement" },
]

# ─── État ───
var selected_character: Dictionary = {}
var deck: Array = []         # max 5 cartes (dictionnaires)

# ─── Nœuds ───
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

# ─── Init ───
func _ready():
	print("[Build] Chargé")
	back_btn.pressed.connect(_on_back_pressed)
	_populate_characters()
	_populate_cards()
	# Connecte les slots une seule fois
	for i in range(MAX_DECK_SIZE):
		var slot: Panel = deck_slots.get_node("Slot%d" % (i + 1))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
	_refresh_deck_ui()

# ─── Remplissage de la liste de personnages ───
func _populate_characters():
	for child in char_list.get_children():
		child.queue_free()

	for char_data in CHARACTERS:
		# Bouton carré image uniquement
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 90)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_contents = true
		btn.text = ""
		btn.tooltip_text = "%s  [ %s ]\n%s" % [char_data["name"], char_data["type"], char_data.get("skill", "")]

		# TextureRect — charge l'image du personnage
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

# ─── Sélection d'un personnage ───
func _on_character_selected(char_data: Dictionary, btn: Button):
	selected_character = char_data
	print("[Build] Personnage sélectionné: %s" % char_data["name"])

	# Highlight visuel — reset tous, puis marque le sélectionné
	for child in char_list.get_children():
		if child is Button:
			child.button_pressed = false
			child.modulate = Color(1, 1, 1, 0.7)
	btn.button_pressed = true
	btn.modulate = Color(1, 1, 1, 1)

	# Met à jour le panneau central
	var tex = load("res://assets/characters/" + char_data["id"] + ".png")
	portrait_texture.texture = tex
	portrait_label.visible = tex == null
	selected_name_lb.text  = char_data["name"]
	selected_type_lb.text  = "[ %s ]" % char_data["type"]
	selected_skill_lb.text = char_data.get("skill", "")

# ─── Couleur de fond selon la catégorie de carte ───
func _card_color(category: String) -> Color:
	match category:
		"Actif":     return Color(0.18, 0.35, 0.65, 0.45)  # bleu sombre
		"Condition": return Color(0.65, 0.38, 0.10, 0.45)  # orange sombre
		_:           return Color(0.25, 0.25, 0.3, 0.45)

# ─── Remplissage de la grille de cartes ───
func _populate_cards():
	for child in card_grid.get_children():
		child.queue_free()

	for card_data in CARDS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 170)
		btn.clip_contents = true
		btn.text = ""

		# Fond coloré (placeholder ou fond derrière l'image)
		var bg = ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = _card_color(card_data["category"])
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)

		# Image de la carte — chargement brut (bypasse l'import Godot)
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

		# Tooltip au survol (bulle) — remplace le texte sur la carte
		btn.tooltip_text = "%s  [%s]\n%s" % [card_data["name"], card_data["category"], card_data["desc"]]

		btn.pressed.connect(_on_card_selected.bind(card_data))
		card_grid.add_child(btn)

# ─── Ajout d'une carte dans le deck ───
func _on_card_selected(card_data: Dictionary):
	if deck.size() >= MAX_DECK_SIZE:
		print("[Build] Deck plein !")
		return

	# Eviter les doublons
	for c in deck:
		if c["id"] == card_data["id"]:
			print("[Build] Carte déjà dans le deck: %s" % card_data["name"])
			return

	deck.append(card_data)
	print("[Build] Carte ajoutée: %s (%d/%d)" % [card_data["name"], deck.size(), MAX_DECK_SIZE])
	_refresh_deck_ui()
	_refresh_card_grid()

# ─── Retrait d'une carte (clic sur un slot occupé) ───
func _on_slot_pressed(index: int):
	if index < deck.size():
		print("[Build] Carte retirée: %s" % deck[index]["name"])
		deck.remove_at(index)
		_refresh_deck_ui()
		_refresh_card_grid()

# ─── Grisage des cartes déjà dans le deck ───
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

# ─── Mise à jour de l'affichage du deck ───
func _refresh_deck_ui():
	deck_title.text = "MON DECK  (%d / %d)" % [deck.size(), MAX_DECK_SIZE]

	for i in range(MAX_DECK_SIZE):
		var slot: Panel = deck_slots.get_node("Slot%d" % (i + 1))
		var label: Label = slot.get_node("SlotLabel")

		# Supprime l'ancienne image s'il y en avait une
		if slot.has_node("SlotTex"):
			var old_tex = slot.get_node("SlotTex")
			slot.remove_child(old_tex)
			old_tex.queue_free()

		if i < deck.size():
			label.text = ""  # cache le texte VIDE

			# Style occupé — bordure lumineuse
			var occupied_style = StyleBoxFlat.new()
			occupied_style.bg_color = Color(0.1, 0.12, 0.2, 1)
			occupied_style.border_color = Color(0.45, 0.6, 1.0, 0.7)
			occupied_style.set_border_width_all(2)
			occupied_style.set_corner_radius_all(8)
			slot.add_theme_stylebox_override("panel", occupied_style)

			# Charge et affiche l'image de la carte dans le slot
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

			# Tooltip sur le slot aussi
			slot.tooltip_text = "%s  [%s]\n%s" % [deck[i]["name"], deck[i]["category"], deck[i]["desc"]]
		else:
			label.text = "VIDE"
			slot.tooltip_text = ""

			# Style vide — bordure discrète
			var empty_style = StyleBoxFlat.new()
			empty_style.bg_color = Color(0.08, 0.08, 0.12, 1)
			empty_style.border_color = Color(0.25, 0.25, 0.35, 0.5)
			empty_style.set_border_width_all(2)
			empty_style.set_corner_radius_all(8)
			slot.add_theme_stylebox_override("panel", empty_style)

func _on_slot_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_pressed(index)

# ─── Retour ───
func _on_back_pressed():
	print("[Build] Retour au menu principal")
	GameManager.go_to_main_menu()
