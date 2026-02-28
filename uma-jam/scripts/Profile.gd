extends Control

# ============================================================================
# Profile.gd - Écran de profil du joueur
# ============================================================================

@onready var _name_input: LineEdit = $Center/VBox/NameInput
@onready var _save_label: Label = $Center/VBox/SaveLabel

func _ready():
	print("[Profile] Écran Profil chargé")
	$BackButton.pressed.connect(_on_back_pressed)
	$Center/VBox/SaveBtn.pressed.connect(_on_save_pressed)

	# Pré-remplir avec le pseudo actuel
	_name_input.text = GameData.player_name
	_save_label.text = ""


func _on_save_pressed():
	var new_name: String = _name_input.text.strip_edges()
	if new_name == "":
		new_name = "Joueur"
	GameData.player_name = new_name
	_save_label.text = "Pseudo sauvegarde : %s" % new_name
	print("[Profile] Pseudo changé: %s" % new_name)

	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): _save_label.text = "")


func _on_back_pressed():
	print("[Profile] Retour au menu principal")
	GameManager.go_to_main_menu()
