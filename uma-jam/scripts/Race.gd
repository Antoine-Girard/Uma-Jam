extends Control

@onready var status_label = $StatusLabel

func _ready():
	print("[Race] Course chargée!")
	
	# TODO:
	# 1. Spawner les chevaux pour chaque joueur
	# 2. Synchroniser les positions via MultiplayerSynchronizer
	# 3. Afficher les skills activables
	# 4. Gérer l'endurance
	# 5. Déterminer le gagnant quand quelqu'un finit x tours
