extends Node2D
class_name HorseRacer

const HORSE_COLORS := [
	Color(0.90, 0.20, 0.20),
	Color(0.20, 0.45, 0.90),
	Color(0.20, 0.75, 0.25),
	Color(0.90, 0.80, 0.10),
	Color(0.80, 0.20, 0.80),
	Color(0.10, 0.80, 0.80),
]

var track: Node2D      = null
var lane_idx: int      = 0
var progress: float    = 0.0
var current_speed: float = 0.0
var max_speed: float   = 55.0
var acceleration: float = 5.5
var laps_completed: int = 0
var horse_name: String = "?"
var color_idx: int     = 0
var skill_manager: SkillManager = null

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.text = horse_name
	_label.position = Vector2(-28.0, -32.0)
	_label.add_theme_font_size_override("font_size", 11)
	add_child(_label)
	queue_redraw()

func _process(delta: float) -> void:
	if track == null:
		return

	var effective_max := max_speed
	var effective_accel := acceleration
	if skill_manager != null:
		var speed_bonus: float = skill_manager.get_speed_bonus()
		var accel_bonus: float = skill_manager.get_accel_bonus()
		effective_max = max_speed + (speed_bonus / SkillData.BASE_SPEED) * max_speed
		effective_accel = acceleration + (accel_bonus / SkillData.BASE_ACCEL) * acceleration

	if current_speed <= effective_max:
		current_speed += effective_accel * delta
		if current_speed > effective_max:
			current_speed = effective_max
	else:
		current_speed = move_toward(current_speed, effective_max, effective_accel * delta)

	var lane_length: float = track.get_lane_length(lane_idx)
	var progress_delta: float = (current_speed * delta) / lane_length
	progress += progress_delta
	while progress >= 1.0:
		progress -= 1.0
		laps_completed += 1

	position = track.get_horse_pos(lane_idx, progress)
	rotation = track.get_horse_rot(lane_idx, progress)

func _draw() -> void:
	var c:  Color = HORSE_COLORS[color_idx % HORSE_COLORS.size()]
	var cd: Color = c.darkened(0.40)

	draw_rect(Rect2(-18.0, -7.0, 34.0, 14.0), c)

	draw_circle(Vector2(20.0, -5.0), 9.0, cd)
	draw_circle(Vector2(20.0, -5.0), 6.0, c)

	draw_circle(Vector2(24.0, -7.0), 2.0, Color.BLACK)

	draw_line(Vector2(-18.0,  1.0), Vector2(-27.0, -7.0), cd, 3.0)
	draw_line(Vector2(-18.0,  1.0), Vector2(-27.0,  5.0), cd, 3.0)

	for x: float in [-11.0, -3.0, 5.0, 13.0]:
		draw_line(Vector2(x, 7.0), Vector2(x, 16.0), cd, 2.5)

func move_inner() -> void:
	lane_idx = max(0, lane_idx - 1)

func move_outer() -> void:
	lane_idx = min(5, lane_idx + 1)
