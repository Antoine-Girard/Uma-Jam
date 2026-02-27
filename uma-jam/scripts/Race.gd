extends Control

# ============================================================================
# Race.gd - Scène de la course (à développer plus tard)
# ============================================================================
# Pour maintenant: juste un écran qui affiche "Course en cours!"
# Plus tard tu y ajouteras:
#   - Les chevaux qui bougent
#   - La synchronisation multijoueur
#   - Les skills activables
#   - L'endurance
# ============================================================================

@onready var status_label = $StatusLabel

func _ready():
	print("[Race] Course chargée!")
	
	# Afficher les joueurs en course
	var players = NetworkManager.players_connected
	status_label.text = "🏁 COURSE EN COURS!\n\nJoueurs (%d):\n" % players.size()
	
	for peer_id in players.keys():
		var player_name = players[peer_id].get("name", "Inconnu")
		status_label.text += "  - %s\n" % player_name
	
	status_label.text += "\n(À développer...)"
	
	# TODO:
	# 1. Spawner les chevaux pour chaque joueur
	# 2. Synchroniser les positions via MultiplayerSynchronizer
	# 3. Afficher les skills activables
	# 4. Gérer l'endurance
	# 5. Déterminer le gagnant quand quelqu'un finit 3 tours
