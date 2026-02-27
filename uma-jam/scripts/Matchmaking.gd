extends Control

@onready var ip_input = $VBoxContainer/IPInput
@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	print("[Matchmaking] Écran de matchmaking chargé")

	$VBoxContainer/CreateButton.pressed.connect(_on_create_pressed)
	$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)

func _on_create_pressed():
	print("[Matchmaking] Création d'une partie...")
	status_label.text = "Démarrage du serveur..."
	NetworkManager.start_server()
	GameManager.go_to_race()

func _on_join_pressed():
	var ip = ip_input.text.strip_edges()

	if ip.is_empty():
		status_label.text = "Erreur: Rentre une IP!"
		return

	print("[Matchmaking] Tentative de connexion à %s" % ip)
	status_label.text = "Connexion à %s..." % ip
	NetworkManager.start_client(ip)
	GameManager.go_to_race()

func _on_server_started() -> void:
	print("[Matchmaking] Serveur lancé! En attente des clients...")
	GameManager.go_to_lobby()

func _on_client_connected() -> void:
	print("[Matchmaking] Connecté au serveur!")
	GameManager.go_to_lobby()
