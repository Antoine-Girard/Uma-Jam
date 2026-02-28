extends Control

# ============================================================================
# Profile.gd - Écran de profil du joueur
# ============================================================================

func _ready():
	print("[Profile] Écran Profil chargé")
	$BackButton.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	print("[Profile] Retour au menu principal")
	GameManager.go_to_main_menu()
