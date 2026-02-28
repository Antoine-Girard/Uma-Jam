extends Control

# ============================================================================
# MainMenu.gd - Menu principal du jeu
# ============================================================================

func _ready():
	print("[MainMenu] Menu principal chargé")
	$BottomBar/BuildButton.pressed.connect(_on_build_pressed)
	$BottomBar/ProfileButton.pressed.connect(_on_profile_pressed)
	$MatchmakingBtn.pressed.connect(_on_matchmaking_pressed)
	$TopLeft/RaceBtn.pressed.connect(_on_race_pressed)
	$TopRight/QuitBtn.pressed.connect(_on_quit_pressed)

	# Réveiller le serveur relay en fond dès le lancement du jeu
	# Comme ça quand le joueur clique "Matchmaking", le serveur est déjà prêt
	NetworkManager.wake_up_server()


func _on_build_pressed():
	print("[MainMenu] Clic sur BUILD")
	GameManager.go_to_build()

func _on_race_pressed():
	if not _check_build_ready():
		return
	print("[MainMenu] Clic sur RACE → Test solo")
	NetworkManager.solo_mode = true
	NetworkManager.players_connected.clear()
	GameManager.go_to_race()

func _on_profile_pressed():
	print("[MainMenu] Clic sur PROFILE")
	GameManager.go_to_profile()

func _on_matchmaking_pressed():
	if not _check_build_ready():
		return
	print("[MainMenu] Clic sur MATCHMAKING")
	NetworkManager.solo_mode = false
	GameManager.go_to_matchmaking()


func _check_build_ready() -> bool:
	if GameData.character_id == "" or GameData.selected_skill_ids.is_empty():
		# Flash le bouton BUILD pour indiquer qu'il faut d'abord construire
		var build_btn: Button = $BottomBar/BuildButton
		var original_text: String = build_btn.text
		build_btn.text = "BUILD D'ABORD !"
		build_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var tw := create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(func():
			build_btn.text = original_text
			build_btn.remove_theme_color_override("font_color")
		)
		return false
	return true

func _on_quit_pressed():
	print("[MainMenu] Fermeture du jeu")
	get_tree().quit()
