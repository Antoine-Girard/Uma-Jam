extends Node2D
class_name HorseRacer

const HORSE_COLORS := [
	Color(0.90, 0.20, 0.20),  # rouge
	Color(0.20, 0.45, 0.90),  # bleu
	Color(0.20, 0.75, 0.25),  # vert
	Color(0.90, 0.80, 0.10),  # jaune
	Color(0.80, 0.20, 0.80),  # violet
	Color(0.10, 0.80, 0.80),  # cyan
]

## À définir avant d'ajouter le nœud à la scène
var track: Node2D      = null
var lane_idx: int      = 0       # couloir 0-5 (0 = intérieur)
var progress: float    = 0.0     # fraction d'un tour, 0-1, sens horaire
var speed: float       = 0.040   # tours par seconde (~25 s par tour)
var laps_completed: int = 0
var horse_name: String = "?"
var color_idx: int     = 0

var _label: Label


func _ready() -> void:
	# Label du nom au-dessus du cheval
	_label = Label.new()
	_label.text = horse_name
	_label.position = Vector2(-28.0, -32.0)
	_label.add_theme_font_size_override("font_size", 11)
	add_child(_label)
	queue_redraw()


func _process(delta: float) -> void:
	if track == null:
		return

	progress += speed * delta
	while progress >= 1.0:
		progress -= 1.0
		laps_completed += 1

	position = track.get_horse_pos(lane_idx, progress)
	rotation = track.get_horse_rot(lane_idx, progress)


func _draw() -> void:
	var c:  Color = HORSE_COLORS[color_idx % HORSE_COLORS.size()]
	var cd: Color = c.darkened(0.40)

	# Corps (rectangle allongé)
	draw_rect(Rect2(-18.0, -7.0, 34.0, 14.0), c)

	# Cou + tête (cercle à l'avant, direction +X en espace local)
	draw_circle(Vector2(20.0, -5.0), 9.0, cd)
	draw_circle(Vector2(20.0, -5.0), 6.0, c)

	# Œil
	draw_circle(Vector2(24.0, -7.0), 2.0, Color.BLACK)

	# Queue (à l'arrière)
	draw_line(Vector2(-18.0,  1.0), Vector2(-27.0, -7.0), cd, 3.0)
	draw_line(Vector2(-18.0,  1.0), Vector2(-27.0,  5.0), cd, 3.0)

	# Jambes (4 lignes sous le corps)
	for x: float in [-11.0, -3.0, 5.0, 13.0]:
		draw_line(Vector2(x, 7.0), Vector2(x, 16.0), cd, 2.5)


# ─── Contrôle joueur ──────────────────────────────────────────────────────────

## Se déplacer vers le couloir intérieur
func move_inner() -> void:
	lane_idx = max(0, lane_idx - 1)


## Se déplacer vers le couloir extérieur
func move_outer() -> void:
	lane_idx = min(5, lane_idx + 1)
