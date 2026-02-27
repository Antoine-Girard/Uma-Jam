extends Control

@onready var players_container = $VBoxContainer/PlayersList
@onready var ready_button = $VBoxContainer/ReadyButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var ip_label = $VBoxContainer/IPLabel

var is_ready_pressed = false

func _ready():
	print("[Lobby] Lobby chargé")
	
	ip_label.text = NetworkManager._get_local_ip()
	_refresh_player_list()

func _on_ready_pressed():
	if not is_ready_pressed:
		is_ready_pressed = true
		ready_button.modulate = Color.GREEN
		status_label.text = "Tu es PRÊT! En attente des autres..."
		NetworkManager.player_ready()
	else:
		is_ready_pressed = false
		ready_button.modulate = Color.WHITE
		status_label.text = ""
		NetworkManager.player_unready()

func _on_players_updated(players: Dictionary) -> void:
	print("[Lobby] Liste des joueurs mise à jour: %d joueur(s)" % players.size())
#	_refresh_player_list()

func _on_peer_connected(id: int, name: String) -> void:
	print("[Lobby] %s a rejoint! (ID: %d)" % [name, id])
#	_refresh_player_list()

func _on_peer_disconnected(id: int) -> void:
	print("[Lobby] Un joueur a quitté")
#	_refresh_player_list()
	is_ready_pressed = false
	ready_button.disabled = false
	ready_button.modulate = Color.WHITE

func _refresh_player_list() -> void:
	for child in players_container.get_children():
		child.queue_free()
#	var player_count = NetworkManager.get_player_count()
#	print("[Lobby] Affichage de %d joueur(s)" % player_count)
#	for peer_id in NetworkManager.players_connected.keys():
#		var player_data = NetworkManager.players_connected[peer_id]
#		var player_name = player_data.get("name", "Inconnu")
#		var is_ready = player_data.get("ready", false)
#		var player_label = Label.new()
#		if is_ready:
#			player_label.text = "✓ %s (Prêt)" % player_name
#			player_label.add_theme_color_override("font_color", Color.GREEN)
#		else:
#			player_label.text = "○ %s (En attente...)" % player_name
#			player_label.add_theme_color_override("font_color", Color.YELLOW)
#		players_container.add_child(player_label)
#	status_label.text = "%d / %d joueur(s) connectés" % [player_count, 6]

func am_ready() -> bool:
	return is_ready_pressed
