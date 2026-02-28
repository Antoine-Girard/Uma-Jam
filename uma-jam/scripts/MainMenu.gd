extends Control

# ============================================================================
# MainMenu.gd - Menu principal du jeu
# ============================================================================

func _ready():
	print("[MainMenu] Menu principal chargé")
	$BottomBar/BuildButton.pressed.connect(_on_build_pressed)
	$BottomBar/RaceButton.pressed.connect(_on_race_pressed)
	$BottomBar/ProfileButton.pressed.connect(_on_profile_pressed)

func _on_build_pressed():
	print("[MainMenu] Clic sur BUILD")
	GameManager.go_to_build()

func _on_race_pressed():
	print("[MainMenu] Clic sur RACE → Matchmaking")
	GameManager.go_to_matchmaking()

func _on_profile_pressed():
	print("[MainMenu] Clic sur PROFILE")
	GameManager.go_to_profile()
