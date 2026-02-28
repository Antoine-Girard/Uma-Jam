extends Control

# ============================================================================
# Build.gd - Sélection de personnage et construction de deck
# ============================================================================

const MAX_DECK_SIZE = 5

# ─── Données de référence (à remplacer par GameData plus tard) ───
const CHARACTERS = [
	{ "id": "agnestachyon_icon",   "name": "Agnes Tachyon",   "type": "Vitesse"   },
	{ "id": "elcondorpasa_icon",   "name": "El Condor Pasa",   "type": "Puissance" },
	{ "id": "goldship_icon",       "name": "Gold Ship",        "type": "Endurance" },
	{ "id": "maruzensky_icon",     "name": "Maruzensky",       "type": "Vitesse"   },
	{ "id": "oguricap_icon",       "name": "Oguri Cap",        "type": "Équilibre" },
	{ "id": "sakurabakushino_icon","name": "Sakura Bakushin",  "type": "Sprint"    },
	{ "id": "specialweek_icon",    "name": "Special Week",     "type": "Endurance" },
	{ "id": "symbolirudolf_icon",  "name": "Symboli Rudolf",   "type": "Tactique"  },
]

const CARDS = [
	{ "id": "c01", "name": "Accélération",  "type": "Vitesse"    },
	{ "id": "c02", "name": "Coup de boost", "type": "Vitesse"    },
	{ "id": "c03", "name": "Charge lourde", "type": "Puissance"  },
	{ "id": "c04", "name": "Bouclier",      "type": "Défense"    },
	{ "id": "c05", "name": "Sprint final",  "type": "Sprint"     },
	{ "id": "c06", "name": "Récupération",  "type": "Endurance"  },
	{ "id": "c07", "name": "Fausse piste",  "type": "Tactique"   },
	{ "id": "c08", "name": "Poussée",       "type": "Puissance"  },
	{ "id": "c09", "name": "Élan naturel",  "type": "Vitesse"    },
	{ "id": "c10", "name": "Focus",         "type": "Tactique"   },
	{ "id": "c11", "name": "Mur de vent",   "type": "Défense"    },
	{ "id": "c12", "name": "Dernier tour",  "type": "Sprint"     },
]

# ─── État ───
var selected_character: Dictionary = {}
var deck: Array = []         # max 5 cartes (dictionnaires)

# ─── Nœuds ───
@onready var char_list        = $MainLayout/LeftPanel/CharScroll/CharList
@onready var card_grid        = $MainLayout/RightPanel/CardScroll/CardGrid
@onready var deck_title       = $MainLayout/RightPanel/DeckTitle
@onready var deck_slots       = $MainLayout/RightPanel/DeckSlots
@onready var back_btn         = $TopBar/BackButton
@onready var portrait_label   = $MainLayout/MiddlePanel/SelectedPortrait/PortraitLabel
@onready var portrait_texture = $MainLayout/MiddlePanel/SelectedPortrait/PortraitTexture
@onready var selected_name_lb = $MainLayout/MiddlePanel/SelectedName
@onready var selected_type_lb = $MainLayout/MiddlePanel/SelectedType

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
		# Bouton carré image uniquement (pas de texte)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_contents = true
		btn.text = ""

		# TextureRect — charge l'image du personnage
		var tex = TextureRect.new()
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.texture = load("res://assets/characters/" + char_data["id"] + ".png")
		btn.add_child(tex)

		btn.pressed.connect(_on_character_selected.bind(char_data, btn))
		char_list.add_child(btn)

# ─── Sélection d'un personnage ───
func _on_character_selected(char_data: Dictionary, btn: Button):
	selected_character = char_data
	print("[Build] Personnage sélectionné: %s" % char_data["name"])

	# Highlight visuel
	for child in char_list.get_children():
		if child is Button:
			child.button_pressed = false
	btn.button_pressed = true

	# Met à jour le panneau central
	var tex = load("res://assets/characters/" + char_data["id"] + ".png")
	portrait_texture.texture = tex
	portrait_label.visible = tex == null
	selected_name_lb.text = char_data["name"]
	selected_type_lb.text = "[ %s ]" % char_data["type"]

# ─── Remplissage de la grille de cartes ───
func _populate_cards():
	for child in card_grid.get_children():
		child.queue_free()

	for card_data in CARDS:
		var btn = Button.new()
		btn.text = "%s\n%s" % [card_data["name"], card_data["type"]]
		btn.custom_minimum_size = Vector2(110, 90)
		btn.add_theme_font_size_override("font_size", 13)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

# ─── Retrait d'une carte (clic sur un slot occupé) ───
func _on_slot_pressed(index: int):
	if index < deck.size():
		print("[Build] Carte retirée: %s" % deck[index]["name"])
		deck.remove_at(index)
		_refresh_deck_ui()

# ─── Mise à jour de l'affichage du deck ───
func _refresh_deck_ui():
	deck_title.text = "MON DECK  (%d / %d)" % [deck.size(), MAX_DECK_SIZE]

	for i in range(MAX_DECK_SIZE):
		var slot: Panel = deck_slots.get_node("Slot%d" % (i + 1))
		var label: Label = slot.get_node("SlotLabel")

		if i < deck.size():
			label.text = deck[i]["name"] + "\n[" + deck[i]["type"] + "]"
		else:
			label.text = "VIDE"

func _on_slot_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_pressed(index)

# ─── Retour ───
func _on_back_pressed():
	print("[Build] Retour au menu principal")
	GameManager.go_to_main_menu()
