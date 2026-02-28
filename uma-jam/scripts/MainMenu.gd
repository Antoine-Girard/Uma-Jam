extends Control

# ============================================================================
# MainMenu.gd - Menu principal du jeu
# ============================================================================

func _ready():
	print("[MainMenu] Menu principal chargé")
	$BottomBar/BuildButton.pressed.connect(_on_build_pressed)
	$BottomBar/RaceButton.pressed.connect(_on_race_pressed)
	$BottomBar/ProfileButton.pressed.connect(_on_profile_pressed)
	$TopRight/MatchmakingBtn.pressed.connect(_on_matchmaking_pressed)
	$QuitBtn.pressed.connect(_on_quit_pressed)

	# Réveiller le serveur relay en fond dès le lancement du jeu
	# Comme ça quand le joueur clique "Matchmaking", le serveur est déjà prêt
	NetworkManager.wake_up_server()


func _on_build_pressed():
	print("[MainMenu] Clic sur BUILD")
	GameManager.go_to_build()

func _on_race_pressed():
	print("[MainMenu] Clic sur RACE → Test solo")
	NetworkManager.solo_mode = true
	NetworkManager.players_connected.clear()
	GameManager.go_to_race()

func _on_profile_pressed():
	print("[MainMenu] Clic sur PROFILE")
	GameManager.go_to_profile()

func _on_matchmaking_pressed():
	print("[MainMenu] Clic sur MATCHMAKING")
	NetworkManager.solo_mode = false
	GameManager.go_to_matchmaking()

func _on_quit_pressed():
	print("[MainMenu] Fermeture du jeu")
	get_tree().quit()
