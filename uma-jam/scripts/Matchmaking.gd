extends Control

# ============================================================================
# Matchmaking.gd - Écran pour créer ou rejoindre une partie
# ============================================================================
# Ce que tu dois faire avec ce script:
# 1. Créer une UI (boutons + champ de texte)
# 2. Quand joueur clique "Créer Partie" → start_server()
# 3. Quand joueur clique "Rejoindre" + IP → join_server(ip)
#
# NOTES:
# - Pour test LOCAL: utilise "localhost" ou "127.0.0.1"
# - Pour test réseau: utilise l'IP réelle du serveur (ex: "192.168.1.100")
# ============================================================================

@onready var ip_input = $VBoxContainer/IPInput  # À créer dans l'UI
@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	print("[Matchmaking] Écran de matchmaking chargé")
	
	# S'écouter aux signaux du réseau
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.client_connected.connect(_on_client_connected)
	
	# Boutons
	$VBoxContainer/CreateButton.pressed.connect(_on_create_pressed)
	$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)

# ─────────────────────────────────────────────────────────────────────────
# QUAND: Boton "Créer Partie" cliqué
# CE QUE CA FAIT: Démarrer un serveur
# ─────────────────────────────────────────────────────────────────────────
func _on_create_pressed():
	print("[Matchmaking] Création d'une partie...")
	status_label.text = "Démarrage du serveur..."
	NetworkManager.start_server()

# ─────────────────────────────────────────────────────────────────────────
# QUAND: Boton "Rejoindre" cliqué
# CE QUE CA FAIT: Se connecter à un serveur avec l'IP entrée
# ─────────────────────────────────────────────────────────────────────────
func _on_join_pressed():
	var ip = ip_input.text.strip_edges()
	
	if ip.is_empty():
		status_label.text = "Erreur: Rentre une IP!"
		return
	
	print("[Matchmaking] Tentative de connexion à %s" % ip)
	status_label.text = "Connexion à %s..." % ip
	NetworkManager.join_server(ip)

# ─────────────────────────────────────────────────────────────────────────
# CALLBACK: Serveur est lancé
# ─────────────────────────────────────────────────────────────────────────
func _on_server_started() -> void:
	print("[Matchmaking] Serveur lancé! En attente des clients...")
	status_label.text = "Serveur lancé! Adresse IP: " + _get_local_ip()
	# TODO: Afficher l'IP locale pour que d'autres joueurs s'y connectent
	
	# Aller au Lobby après un court délai
	await get_tree().create_timer(1.0).timeout
	GameManager.go_to_lobby()

# ─────────────────────────────────────────────────────────────────────────
# CALLBACK: Connecté au serveur
# ─────────────────────────────────────────────────────────────────────────
func _on_client_connected() -> void:
	print("[Matchmaking] Connecté au serveur!")
	status_label.text = "Connecté! En attente du Lobby..."
	
	# Aller au Lobby
	await get_tree().create_timer(0.5).timeout
	GameManager.go_to_lobby()

# ─────────────────────────────────────────────────────────────────────────
# FONCTION: Obtenir l'IP locale (pour l'afficher)
# ─────────────────────────────────────────────────────────────────────────
func _get_local_ip() -> String:
	# En local, généralement 127.0.0.1 ou 192.168.x.x
	# TODO: Lire l'IP depuis la config système
	return "127.0.0.1"
