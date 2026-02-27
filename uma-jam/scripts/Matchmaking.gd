extends Control

@onready var ip_input = $VBoxContainer/IPInput
@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	print("[Matchmaking] Écran de matchmaking chargé")

	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.client_connected.connect(_on_client_connected)

	$VBoxContainer/CreateButton.pressed.connect(_on_create_pressed)
	$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)

func _on_create_pressed():
	print("[Matchmaking] Création d'une partie...")
	status_label.text = "Démarrage du serveur..."
	NetworkManager.start_server()

func _on_join_pressed():
	var ip = ip_input.text.strip_edges()

	if ip.is_empty():
		status_label.text = "Erreur: Rentre une IP!"
		return

	print("[Matchmaking] Tentative de connexion à %s" % ip)
	status_label.text = "Connexion à %s..." % ip
	NetworkManager.join_server(ip)

func _on_server_started() -> void:
	print("[Matchmaking] Serveur lancé! En attente des clients...")
	var ip = _get_local_ip()
	status_label.text = "Serveur lancé! IP : %s (pour vos amis)" % ip
	print("[Matchmaking] Utilisez cette IP pour vous connecter : %s" % ip)
	await get_tree().create_timer(1.0).timeout
	GameManager.go_to_lobby()

func _on_client_connected() -> void:
	print("[Matchmaking] Connecté au serveur!")
	status_label.text = "Connecté! En attente du Lobby..."
	
	await get_tree().create_timer(0.5).timeout
	GameManager.go_to_lobby()

func _get_local_ip() -> String:
	var ips = IP.get_local_addresses()
	for ip in ips:
		if !ip.begins_with("127."):
			return ip
	return "127.0.0.1"
