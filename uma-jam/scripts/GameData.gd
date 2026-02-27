extends Node


var selected_character: String = ""
var character_ultimate: String = ""
var character_passive: String = ""

var selected_deck: Array = []

var player_id: int = 0
var player_name: String = "Joueur"

var current_match_players: Array = []

func _ready():
	print("[GameData] Initialisé")

func select_character(char_name: String, ultimate: String, passive: String) -> void:
	selected_character = char_name
	character_ultimate = ultimate
	character_passive = passive
	print("[GameData] Personnage sélectionné: %s (Ulti: %s, Passif: %s)" % [char_name, ultimate, passive])

func set_deck(cards: Array) -> bool:
	if cards.size() != 5:
		print("[GameData] ERREUR: Le deck doit avoir 5 cartes, pas %d" % cards.size())
		return false
	
	selected_deck = cards
	print("[GameData] Deck défini: %s" % str(selected_deck))
	return true

func get_character_info() -> Dictionary:
	return {
		"name": selected_character,
		"ultimate": character_ultimate,
		"passive": character_passive
	}

func get_deck() -> Array:
	return selected_deck.duplicate()

func reset() -> void:
	selected_character = ""
	character_ultimate = ""
	character_passive = ""
	selected_deck = []
	current_match_players = []
	print("[GameData] Données réinitialisées")
