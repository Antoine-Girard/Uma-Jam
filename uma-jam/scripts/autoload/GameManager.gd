extends Node

signal scene_changed(scene_name: String)

func _ready():
	print("[GameManager] Initialized")

func go_to_main_menu() -> void:
	_change_scene("res://scenes/menu/Main_Menu.tscn", "Main Menu")

func go_to_character_select() -> void:
	_change_scene("res://scenes/menu/CharacterSelect.tscn", "Character Select")

func go_to_deck_select() -> void:
	_change_scene("res://scenes/menu/DeckSelect.tscn", "Deck Select")

func go_to_build() -> void:
	_change_scene("res://scenes/menu/Build.tscn", "Build")

func go_to_profile() -> void:
	_change_scene("res://scenes/menu/Profile.tscn", "Profile")

func go_to_matchmaking() -> void:
	_change_scene("res://scenes/lobby/Matchmaking.tscn", "Matchmaking")

func go_to_race() -> void:
	_change_scene("res://scenes/race/Race.tscn", "Race")

func go_to_results() -> void:
	_change_scene("res://scenes/race/Results.tscn", "Results")

func _change_scene(path: String, name: String) -> void:
	print("[GameManager] Changing to: %s" % name)
	scene_changed.emit(name)
	get_tree().change_scene_to_file(path)
