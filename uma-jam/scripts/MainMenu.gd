extends Control

# ============================================================================
# MainMenu.gd - Menu principal du jeu
# ============================================================================
# Simple: juste un bouton "JOUER" qui va vers Matchmaking
# ============================================================================

func _ready():
	print("[MainMenu] Menu principal chargé")
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	print("[MainMenu] Clic sur JOUER → Matchmaking")
	GameManager.go_to_matchmaking()

func _on_quit_pressed():
	print("[MainMenu] Fermeture du jeu")
	get_tree().quit()
