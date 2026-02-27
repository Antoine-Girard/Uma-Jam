extends Node

# ============================================================================
# GameData.gd - Stocke les données du joueur LOCAL
# ============================================================================
# Ce script AUTOLOAD sera disponible partout dans le jeu
# Il mémorise: le personnage choisi, le deck de cartes, les préférences
#
# Utilisation: GameData.selected_character, GameData.selected_deck, etc.
# ============================================================================

# ─── DONNÉES DU PERSONNAGE ───
var selected_character: String = ""  # Nom du perso choisi (ex: "Uma")
var character_ultimate: String = ""  # Son ulti unique
var character_passive: String = ""   # Son passif unique

# ─── DONNÉES DU DECK ───
var selected_deck: Array = []  # Liste de 5 cartes (skills)
# Exemple: ["Sprint", "Dash", "Barrier", "Heal", "Boost"]

# ─── DONNÉES MULTIJOUEUR ───
var player_id: int = 0  # Mon ID unique dans le réseau
var player_name: String = "Joueur"  # Mon nom

# ─── DONNÉES DE SESSION ───
var current_match_players: Array = []  # Liste des joueurs dans ce match (max 6)

func _ready():
	# Cet autoload est chargé UNE FOIS au démarrage
	print("[GameData] Initialisé")

# ─── FONCTION: Choisir un personnage ───
# Paramètres:
#   - char_name (String): Le nom du personnage
#   - ultimate (String): Son ulti
#   - passive (String): Son passif
#
# Retour: rien
#
# Exemple d'utilisation:
#   GameData.select_character("Uma", "Final Spurt", "Natural Born Runner")
func select_character(char_name: String, ultimate: String, passive: String) -> void:
	selected_character = char_name
	character_ultimate = ultimate
	character_passive = passive
	print("[GameData] Personnage sélectionné: %s (Ulti: %s, Passif: %s)" % [char_name, ultimate, passive])

# ─── FONCTION: Définir le deck (5 cartes) ───
# Paramètres:
#   - cards (Array): Tableau de 5 noms de cartes
#
# Retour: true si valide, false sinon
#
# Exemple:
#   if GameData.set_deck(["Sprint", "Dash", "Barrier", "Heal", "Boost"]):
#       print("Deck validé!")
func set_deck(cards: Array) -> bool:
	# Vérifier qu'il y a exactement 5 cartes
	if cards.size() != 5:
		print("[GameData] ERREUR: Le deck doit avoir 5 cartes, pas %d" % cards.size())
		return false
	
	selected_deck = cards
	print("[GameData] Deck défini: %s" % str(selected_deck))
	return true

# ─── FONCTION: Obtenir les infos du perso ───
# Retour: Dictionnaire avec les infos du perso
#
# Exemple:
#   var info = GameData.get_character_info()
#   print(info["name"])  → "Uma"
func get_character_info() -> Dictionary:
	return {
		"name": selected_character,
		"ultimate": character_ultimate,
		"passive": character_passive
	}

# ─── FONCTION: Obtenir le deck ───
# Retour: Array des 5 cartes
func get_deck() -> Array:
	return selected_deck.duplicate()  # Copie pour éviter modifications accidentelles

# ─── FONCTION: Réinitialiser (une fois connecté, créer new joueur) ───
func reset() -> void:
	selected_character = ""
	character_ultimate = ""
	character_passive = ""
	selected_deck = []
	current_match_players = []
	print("[GameData] Données réinitialisées")
