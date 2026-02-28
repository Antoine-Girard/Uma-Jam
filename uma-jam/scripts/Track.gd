extends Node2D

## Dimensions du circuit – forme hippodrome (2 droites + 2 virages)
const CENTER        := Vector2(640.0, 360.0)
const HALF_STRAIGHT := 260.0      # demi-longueur de chaque ligne droite
const INNER_R       := 110.0      # rayon intérieur des virages
const LANE_WIDTH    := 28.0
const LANE_COUNT    := 6
const TURN_SEGS     := 32

## Couleurs
const C_GRASS   := Color(0.18, 0.50, 0.12)
const C_INFIELD := Color(0.13, 0.42, 0.08)
const C_TRACK   := Color(0.72, 0.58, 0.42)
const C_DIVIDER := Color(1.0, 1.0, 1.0, 0.30)
const C_BORDER  := Color(1.0, 1.0, 1.0, 0.90)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var outer_r := INNER_R + LANE_COUNT * LANE_WIDTH

	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), C_GRASS)
	draw_colored_polygon(_stadium_pts(HALF_STRAIGHT, outer_r), C_TRACK)
	draw_colored_polygon(_stadium_pts(HALF_STRAIGHT, INNER_R), C_INFIELD)

	for i in range(1, LANE_COUNT):
		var r := INNER_R + i * LANE_WIDTH
		draw_polyline(_stadium_pts(HALF_STRAIGHT, r, true), C_DIVIDER, 1.0, true)

	draw_polyline(_stadium_pts(HALF_STRAIGHT, outer_r, true), C_BORDER, 2.5, true)
	draw_polyline(_stadium_pts(HALF_STRAIGHT, INNER_R, true), C_BORDER, 2.5, true)

	_draw_finish_line()


# ─── Helpers dessin ──────────────────────────────────────────────────────────

func _stadium_pts(hs: float, r: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()

	# Demi-cercle droit (haut → bas)
	for i in range(TURN_SEGS + 1):
		var angle := -PI / 2.0 + float(i) / TURN_SEGS * PI
		pts.append(CENTER + Vector2(hs + r * cos(angle), r * sin(angle)))

	# Demi-cercle gauche (bas → haut)
	for i in range(TURN_SEGS + 1):
		var angle := PI / 2.0 + float(i) / TURN_SEGS * PI
		pts.append(CENTER + Vector2(-hs + r * cos(angle), r * sin(angle)))

	if closed:
		pts.append(pts[0])
	return pts


func _draw_finish_line() -> void:
	## Damier au début de la ligne droite du bas (côté gauche, sens horaire)
	var x := CENTER.x - HALF_STRAIGHT
	var checker := LANE_WIDTH / 4.0
	for lane in LANE_COUNT:
		var y_top := CENTER.y + INNER_R + lane * LANE_WIDTH
		var y_bot := CENTER.y + INNER_R + (lane + 1) * LANE_WIDTH
		var rows := int(LANE_WIDTH / checker)
		for row in rows:
			for col in 2:
				var color := Color.WHITE if (lane + row + col) % 2 == 0 else Color.BLACK
				var y0 := lerpf(y_top, y_bot, float(row) / rows)
				var y1 := lerpf(y_top, y_bot, float(row + 1) / rows)
				var x0 := x - checker + col * checker
				draw_rect(Rect2(x0, y0, checker, y1 - y0), color)


# ─── API publique (sens HORAIRE) ─────────────────────────────────────────────
# Segments : bas (gauche→droite) → virage droit → haut (droite→gauche) → virage gauche

func get_horse_pos(lane_idx: int, progress: float) -> Vector2:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	var L_total := 2.0 * L_str + 2.0 * L_turn
	var s := fmod(progress, 1.0) * L_total

	# Segment 1 : ligne droite du bas (gauche → droite)
	if s < L_str:
		var f := s / L_str
		return CENTER + Vector2(lerpf(-HALF_STRAIGHT, HALF_STRAIGHT, f), r)
	s -= L_str

	# Segment 2 : virage droit (bas → haut)
	if s < L_turn:
		var f := s / L_turn
		var a := PI / 2.0 - f * PI
		return CENTER + Vector2(HALF_STRAIGHT + r * cos(a), r * sin(a))
	s -= L_turn

	# Segment 3 : ligne droite du haut (droite → gauche)
	if s < L_str:
		var f := s / L_str
		return CENTER + Vector2(lerpf(HALF_STRAIGHT, -HALF_STRAIGHT, f), -r)
	s -= L_str

	# Segment 4 : virage gauche (haut → bas)
	var f := clampf(s / L_turn, 0.0, 1.0)
	var a := -PI / 2.0 - f * PI
	return CENTER + Vector2(-HALF_STRAIGHT + r * cos(a), r * sin(a))


func get_horse_rot(lane_idx: int, progress: float) -> float:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	var L_total := 2.0 * L_str + 2.0 * L_turn
	var s := fmod(progress, 1.0) * L_total

	# Segment 1 : droite du bas → direction droite
	if s < L_str:
		return 0.0
	s -= L_str

	# Segment 2 : virage droit
	if s < L_turn:
		var f := s / L_turn
		var a := PI / 2.0 - f * PI
		return atan2(-cos(a), sin(a))
	s -= L_turn

	# Segment 3 : droite du haut → direction gauche
	if s < L_str:
		return PI
	s -= L_str

	# Segment 4 : virage gauche
	var f := clampf(s / L_turn, 0.0, 1.0)
	var a := -PI / 2.0 - f * PI
	return atan2(-cos(a), sin(a))


func get_lane_length(lane_idx: int) -> float:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	return 2.0 * L_str + 2.0 * L_turn
