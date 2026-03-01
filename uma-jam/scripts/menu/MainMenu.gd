extends Control

func _ready():
	print("[MainMenu] Main menu loaded")
	$BottomBar/BuildButton.pressed.connect(_on_build_pressed)
	$BottomBar/ProfileButton.pressed.connect(_on_profile_pressed)
	$BottomBar/TutorialButton.pressed.connect(_on_tutorial_pressed)
	$MatchmakingBtn.pressed.connect(_on_matchmaking_pressed)
	$TopLeft/RaceBtn.pressed.connect(_on_race_pressed)
	$TopRight/QuitBtn.pressed.connect(_on_quit_pressed)

	NetworkManager.wake_up_server()

func _on_build_pressed():
	print("[MainMenu] Click on BUILD")
	GameManager.go_to_build()

func _on_race_pressed():
	if not _check_build_ready():
		return
	print("[MainMenu] Click on RACE → Solo test")
	NetworkManager.solo_mode = true
	NetworkManager.players_connected.clear()
	GameManager.go_to_race()

func _on_profile_pressed():
	print("[MainMenu] Click on PROFILE")
	GameManager.go_to_profile()

func _on_tutorial_pressed():
	print("[MainMenu] Click on TUTORIAL")
	GameManager.go_to_tutorial()

func _on_matchmaking_pressed():
	if not _check_build_ready():
		return
	print("[MainMenu] Click on MATCHMAKING")
	NetworkManager.solo_mode = false
	GameManager.go_to_matchmaking()

func _check_build_ready() -> bool:
	if GameData.character_id == "" or GameData.selected_skill_ids.is_empty():
		var build_btn: Button = $BottomBar/BuildButton
		var original_text: String = build_btn.text
		build_btn.text = "BUILD FIRST!"
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
	print("[MainMenu] Closing game")
	get_tree().quit()
