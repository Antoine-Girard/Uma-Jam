extends Control

# ============================================================================
# Lobby.gd - Affiche la liste des joueurs et le bouton "Je suis prêt"
# ============================================================================
# Ce que ça fait:
# 1. Affiche tous les joueurs connectés
# 2. Affiche le compte à rebours avant le démarrage (si tous prêts)
# 3. Quand clique sur "Prêt" → notifie le serveur
# ============================================================================

@onready var players_container = $VBoxContainer/PlayersList
@onready var ready_button = $VBoxContainer/ReadyButton
@onready var status_label = $VBoxContainer/StatusLabel

var is_ready_pressed = false  # T'as cliqué "Prêt"?

func _ready():
	print("[Lobby] Lobby chargé")
	
	# S'écouter aux signaux du réseau
	NetworkManager.player_list_updated.connect(_on_players_updated)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	
	# Bouton "Je suis prêt"
	ready_button.pressed.connect(_on_ready_pressed)
	
	# Afficher les joueurs actuels
	_refresh_player_list()

# ─────────────────────────────────────────────────────────────────────────
# QUAND: Bouton "Je suis prêt" cliqué
# CE QUE CA FAIT:
#   1. Change la couleur du bouton
#   2. Notifie le serveur que tu es prêt
# ─────────────────────────────────────────────────────────────────────────
func _on_ready_pressed():
	is_ready_pressed = true
	ready_button.disabled = true
	ready_button.modulate = Color.GREEN  # Devient vert
	status_label.text = "Tu es marqué comme PRÊT! En attente des autres..."
	
	# Notifier le serveur
	NetworkManager.player_ready()

# ─────────────────────────────────────────────────────────────────────────
# CALLBACK: La liste des joueurs a été mise à jour
# ─────────────────────────────────────────────────────────────────────────
func _on_players_updated(players: Dictionary) -> void:
	print("[Lobby] Liste des joueurs mise à jour: %d joueur(s)" % players.size())
	_refresh_player_list()

# ─────────────────────────────────────────────────────────────────────────
# CALLBACK: Un nouveau joueur a rejoint
# ─────────────────────────────────────────────────────────────────────────
func _on_peer_connected(id: int, name: String) -> void:
	print("[Lobby] %s a rejoint! (ID: %d)" % [name, id])
	_refresh_player_list()

# ─────────────────────────────────────────────────────────────────────────
# CALLBACK: Un joueur a quitté
# ─────────────────────────────────────────────────────────────────────────
func _on_peer_disconnected(id: int) -> void:
	print("[Lobby] Un joueur a quitté")
	_refresh_player_list()
	
	# Réinitialiser le bouton "Prêt"
	is_ready_pressed = false
	ready_button.disabled = false
	ready_button.modulate = Color.WHITE

# ─────────────────────────────────────────────────────────────────────────
# FONCTION INTERNE: Mettre à jour l'affichage des joueurs
# ─────────────────────────────────────────────────────────────────────────
func _refresh_player_list() -> void:
	# Effacer tous les anciens éléments
	for child in players_container.get_children():
		child.queue_free()
	
	# Ajouter chaque joueur
	var player_count = NetworkManager.get_player_count()
	print("[Lobby] Affichage de %d joueur(s)" % player_count)
	
	for peer_id in NetworkManager.players_connected.keys():
		var player_data = NetworkManager.players_connected[peer_id]
		var player_name = player_data.get("name", "Inconnu")
		var is_ready = player_data.get("ready", false)
		
		# Créer un label pour afficher le joueur
		var player_label = Label.new()
		
		if is_ready:
			player_label.text = "✓ %s (Prêt)" % player_name
			player_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			player_label.text = "○ %s (En attente...)" % player_name
			player_label.add_theme_color_override("font_color", Color.YELLOW)
		
		players_container.add_child(player_label)
	
	# Afficher le nombre de joueurs
	status_label.text = "%d / %d joueur(s) connectés" % [player_count, 6]

# ─────────────────────────────────────────────────────────────────────────
# FONCTION: Est-ce que j'ai cliqué sur "Prêt"?
# ─────────────────────────────────────────────────────────────────────────
func am_ready() -> bool:
	return is_ready_pressed
