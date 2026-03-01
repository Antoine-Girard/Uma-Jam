extends Node

const CHARACTER_MAP: Dictionary = {
	"agnestachyon_icon":   "tachyon",
	"elcondorpasa_icon":   "el_condor_passa",
	"goldship_icon":       "gold_ship",
	"maruzensky_icon":     "maruzenski",
	"oguricap_icon":       "oguri_cap",
	"sakurabakushino_icon": "sakura",
	"specialweek_icon":    "spe_chan",
	"symbolirudolf_icon":  "rudolf",
}

const CHAR_ID_TO_ICON: Dictionary = {
	"tachyon":         "agnestachyon_icon",
	"el_condor_passa": "elcondorpasa_icon",
	"gold_ship":       "goldship_icon",
	"maruzenski":      "maruzensky_icon",
	"oguri_cap":       "oguricap_icon",
	"sakura":          "sakurabakushino_icon",
	"spe_chan":         "specialweek_icon",
	"rudolf":          "symbolirudolf_icon",
}

const CARD_MAP: Dictionary = {
	"vitesse_active":      "speed_boost",
	"acceleration_active": "accel_boost",
	"endurance_active":    "endurance_recovery",
	"vitesse_doublement":  "speed_while_overtaking",
	"acceleration_t1":     "groundwork",
	"leader_t3":           "leader_t3_boost",
	"last_place_t3":       "last_place_t3_boost",
	"drafting_speed":      "drafting_boost",
}

var selected_character: String = ""
var selected_icon_id: String = ""
var character_id: String = ""
var character_passive: String = ""

var selected_deck: Array = []
var selected_skill_ids: Array = []

var player_id: int = 0
var player_name: String = "Player"

var current_match_players: Array = []

func _ready():
	print("[GameData] Initialized")

func select_character(char_name: String, build_icon_id: String) -> void:
	selected_character = char_name
	selected_icon_id = build_icon_id
	character_id = CHARACTER_MAP.get(build_icon_id, "")
	character_passive = SkillData.CHARACTER_PASSIVES.get(character_id, {}).get("label", "")
	print("[GameData] Character: %s | id: %s | passive: %s" % [char_name, character_id, character_passive])

func set_deck(cards: Array) -> void:
	selected_deck = cards.duplicate()
	selected_skill_ids = []
	for card in cards:
		var skill_id: String = CARD_MAP.get(card.get("id", ""), "")
		if skill_id != "":
			selected_skill_ids.append(skill_id)
	print("[GameData] Deck (%d cards) | skills: %s" % [selected_deck.size(), str(selected_skill_ids)])

func get_character_info() -> Dictionary:
	return {
		"name": selected_character,
		"character_id": character_id,
		"passive": character_passive,
	}

func get_deck() -> Array:
	return selected_deck.duplicate()

func get_skill_ids() -> Array:
	return selected_skill_ids.duplicate()

func reset() -> void:
	selected_character = ""
	selected_icon_id = ""
	character_id = ""
	character_passive = ""
	selected_deck = []
	selected_skill_ids = []
	current_match_players = []
	print("[GameData] Data reset")
