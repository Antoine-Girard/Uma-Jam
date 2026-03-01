extends Node2D

const CENTER        := Vector2(640.0, 300.0)
const HALF_STRAIGHT := 260.0
const INNER_R       := 110.0
const LANE_WIDTH    := 28.0
const LANE_COUNT    := 6
const TURN_SEGS     := 32

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

	_draw_start_line()
	_draw_finish_line()

func _stadium_pts(hs: float, r: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()

	for i in range(TURN_SEGS + 1):
		var angle := -PI / 2.0 + float(i) / TURN_SEGS * PI
		pts.append(CENTER + Vector2(hs + r * cos(angle), r * sin(angle)))

	for i in range(TURN_SEGS + 1):
		var angle := PI / 2.0 + float(i) / TURN_SEGS * PI
		pts.append(CENTER + Vector2(-hs + r * cos(angle), r * sin(angle)))

	if closed:
		pts.append(pts[0])
	return pts

func _draw_start_line() -> void:
	# Thin white start line on the left side of the bottom straight
	var x := CENTER.x - HALF_STRAIGHT
	for lane in LANE_COUNT:
		var y_top := CENTER.y + INNER_R + lane * LANE_WIDTH
		var y_bot := CENTER.y + INNER_R + (lane + 1) * LANE_WIDTH
		draw_line(Vector2(x, y_top), Vector2(x, y_bot), Color(1.0, 1.0, 1.0, 0.5), 2.0)

func _draw_finish_line() -> void:
	# Checkered finish line on the right side of the bottom straight
	var x := CENTER.x + HALF_STRAIGHT
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

func get_horse_pos(lane_idx: int, progress: float) -> Vector2:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	var L_total := 2.0 * L_str + 2.0 * L_turn
	var s := fmod(progress, 1.0) * L_total

	if s < L_str:
		var f := s / L_str
		return CENTER + Vector2(lerpf(-HALF_STRAIGHT, HALF_STRAIGHT, f), r)
	s -= L_str

	if s < L_turn:
		var f := s / L_turn
		var a := PI / 2.0 - f * PI
		return CENTER + Vector2(HALF_STRAIGHT + r * cos(a), r * sin(a))
	s -= L_turn

	if s < L_str:
		var f := s / L_str
		return CENTER + Vector2(lerpf(HALF_STRAIGHT, -HALF_STRAIGHT, f), -r)
	s -= L_str

	var f := clampf(s / L_turn, 0.0, 1.0)
	var a := -PI / 2.0 - f * PI
	return CENTER + Vector2(-HALF_STRAIGHT + r * cos(a), r * sin(a))

func get_horse_rot(lane_idx: int, progress: float) -> float:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	var L_total := 2.0 * L_str + 2.0 * L_turn
	var s := fmod(progress, 1.0) * L_total

	if s < L_str:
		return 0.0
	s -= L_str

	if s < L_turn:
		var f := s / L_turn
		var a := PI / 2.0 - f * PI
		return atan2(-cos(a), sin(a))
	s -= L_turn

	if s < L_str:
		return PI
	s -= L_str

	var f := clampf(s / L_turn, 0.0, 1.0)
	var a := -PI / 2.0 - f * PI
	return atan2(-cos(a), sin(a))

func get_lane_length(lane_idx: int) -> float:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	return 2.0 * L_str + 2.0 * L_turn

## Returns the progress value (0-1) at the end of the bottom straight for a given lane.
## This is where the finish line is drawn.
func get_finish_progress(lane_idx: int) -> float:
	var r := INNER_R + (lane_idx + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var L_turn := PI * r
	var L_total := 2.0 * L_str + 2.0 * L_turn
	return L_str / L_total

func convert_progress(old_lane: int, new_lane: int, prog: float) -> float:
	var old_r := INNER_R + (old_lane + 0.5) * LANE_WIDTH
	var new_r := INNER_R + (new_lane + 0.5) * LANE_WIDTH
	var L_str := 2.0 * HALF_STRAIGHT
	var old_turn := PI * old_r
	var new_turn := PI * new_r
	var old_total := 2.0 * L_str + 2.0 * old_turn
	var new_total := 2.0 * L_str + 2.0 * new_turn

	var s := fmod(prog, 1.0) * old_total
	var new_s: float

	if s < L_str:
		# Bottom straight — same distance
		new_s = s
	elif s < L_str + old_turn:
		# Right turn — preserve angle
		var angle := (s - L_str) / old_r
		new_s = L_str + angle * new_r
	elif s < 2.0 * L_str + old_turn:
		# Top straight — same offset from turn end
		var straight_dist := s - (L_str + old_turn)
		new_s = L_str + new_turn + straight_dist
	else:
		# Left turn — preserve angle
		var angle := (s - 2.0 * L_str - old_turn) / old_r
		new_s = 2.0 * L_str + new_turn + angle * new_r

	return new_s / new_total
