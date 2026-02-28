extends Control

func _ready():
	print("[MainMenu] Menu principal chargé")
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/TestButton.pressed.connect(_on_test_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	print("[MainMenu] Clic sur JOUER → Matchmaking")
	GameManager.go_to_matchmaking()

func _on_test_pressed():
	print("[MainMenu] Clic sur TEST → Race directe")
	GameManager.go_to_race()

func _on_quit_pressed():
	print("[MainMenu] Fermeture du jeu")
	get_tree().quit()
