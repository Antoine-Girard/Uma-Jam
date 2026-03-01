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

const HITBOX_HALF_W := 18.0
const HITBOX_HALF_H := 14.0

var track: Node2D      = null
var lane_idx: int      = 0
var progress: float    = 0.0
var current_speed: float = 0.0
var max_speed: float   = 55.0
var acceleration: float = 5.5
var laps_completed: int = 0
var horse_name: String = "?"
var color_idx: int     = 0
var char_id: String    = ""
var skill_manager: SkillManager = null

var all_horses: Array  = []
var is_blocked: bool   = false
var blocked_by: Node2D = null
var is_remote: bool    = false
var finished: bool     = false

var _hitbox_area: Area2D = null
var _overlapping: Array  = []

var _label: Label
var _sprite: Sprite2D

func _ready() -> void:
	_label = Label.new()
	_label.text = horse_name
	_label.position = Vector2(-28.0, -38.0)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)

	_sprite = Sprite2D.new()
	var icon_id: String = GameData.CHAR_ID_TO_ICON.get(char_id, "")
	if icon_id != "":
		var tex := load("res://assets/characters/%s.png" % icon_id) as Texture2D
		if tex:
			_sprite.texture = tex
			var tex_size := tex.get_size()
			_sprite.scale = Vector2(32.0 / tex_size.x, 32.0 / tex_size.y)
	_sprite.position = Vector2.ZERO
	add_child(_sprite)

	_setup_hitbox()
	queue_redraw()

	if track:
		position = track.get_horse_pos(lane_idx, progress)
		rotation = track.get_horse_rot(lane_idx, progress)

func _setup_hitbox() -> void:
	_hitbox_area = Area2D.new()
	_hitbox_area.name = "Hitbox"
	_hitbox_area.collision_layer = 1
	_hitbox_area.collision_mask = 1
	_hitbox_area.monitorable = true
	_hitbox_area.monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HITBOX_HALF_W * 2.0, HITBOX_HALF_H * 2.0)
	shape.shape = rect
	_hitbox_area.add_child(shape)
	add_child(_hitbox_area)

	_hitbox_area.area_entered.connect(_on_area_entered)
	_hitbox_area.area_exited.connect(_on_area_exited)

func _on_area_entered(other_area: Area2D) -> void:
	var other_horse := other_area.get_parent()
	if other_horse is HorseRacer and other_horse != self:
		if other_horse not in _overlapping:
			_overlapping.append(other_horse)

func _on_area_exited(other_area: Area2D) -> void:
	var other_horse := other_area.get_parent()
	if other_horse is HorseRacer:
		_overlapping.erase(other_horse)

func get_score() -> float:
	return float(laps_completed) + progress

func _process(delta: float) -> void:
	if track == null:
		return

	if is_remote:
		var lane_length: float = track.get_lane_length(lane_idx)
		if current_speed > 0.0 and lane_length > 0.0:
			progress += (current_speed * delta) / lane_length
			while progress >= 1.0:
				progress -= 1.0
				laps_completed += 1
		position = track.get_horse_pos(lane_idx, progress)
		rotation = track.get_horse_rot(lane_idx, progress)
		return

	var effective_max := max_speed
	var effective_accel := acceleration
	if skill_manager != null:
		var speed_bonus: float = skill_manager.get_speed_bonus()
		var accel_bonus: float = skill_manager.get_accel_bonus()
		effective_max = max_speed + (speed_bonus / SkillData.BASE_SPEED) * max_speed
		effective_accel = acceleration + (accel_bonus / SkillData.BASE_ACCEL) * acceleration

	if is_blocked and blocked_by != null:
		var blocker_speed: float = blocked_by.current_speed
		effective_max = minf(effective_max, blocker_speed)
		if current_speed > blocker_speed:
			current_speed = blocker_speed

	if current_speed <= effective_max:
		current_speed += effective_accel * delta
		if current_speed > effective_max:
			current_speed = effective_max
	else:
		current_speed = move_toward(current_speed, effective_max, effective_accel * delta)

	var lane_length: float = track.get_lane_length(lane_idx)
	progress += (current_speed * delta) / lane_length

	while progress >= 1.0:
		progress -= 1.0
		laps_completed += 1

	position = track.get_horse_pos(lane_idx, progress)
	rotation = track.get_horse_rot(lane_idx, progress)

func resolve_collisions() -> void:
	is_blocked = false
	blocked_by = null
	if finished or is_remote:
		return

	var my_score: float = get_score()

	for other in _overlapping:
		var h: HorseRacer = other as HorseRacer
		if h == null or h == self:
			continue
		if h.finished:
			continue

		var h_score: float = h.get_score()
		if h_score <= my_score:
			continue

		if h.lane_idx != lane_idx:
			continue

		is_blocked = true
		if blocked_by == null or h_score < (blocked_by as HorseRacer).get_score():
			blocked_by = h

	if is_blocked and blocked_by != null:
		var blocker: HorseRacer = blocked_by as HorseRacer
		if current_speed > blocker.current_speed:
			current_speed = blocker.current_speed

		var safe_score: float = blocker.get_score() - 0.002
		if safe_score < 0.0:
			safe_score = 0.0
		if my_score > safe_score:
			laps_completed = int(safe_score)
			progress = safe_score - float(laps_completed)
			if progress < 0.0:
				progress = 0.0

		position = track.get_horse_pos(lane_idx, progress)
		rotation = track.get_horse_rot(lane_idx, progress)

func is_lane_blocked_ahead(target_lane: int) -> bool:
	if track == null:
		return false
	var target_pos: Vector2 = track.get_horse_pos(target_lane,
		track.convert_progress(lane_idx, target_lane, progress))
	for h in all_horses:
		if h == self or h.finished:
			continue
		if h.lane_idx != target_lane:
			continue
		var dist: float = target_pos.distance_to(h.position)
		if dist < (HITBOX_HALF_W + HITBOX_HALF_H) * 1.2:
			return true
	return false

func _draw() -> void:
	var c: Color = HORSE_COLORS[color_idx % HORSE_COLORS.size()]
	draw_rect(Rect2(-18.0, -18.0, 36.0, 36.0), c, false, 2.5)

func move_inner() -> bool:
	if lane_idx <= 0:
		return false
	if is_lane_blocked_ahead(lane_idx - 1):
		return false
	_switch_lane(lane_idx - 1)
	return true

func move_outer() -> bool:
	if lane_idx >= 5:
		return false
	if is_lane_blocked_ahead(lane_idx + 1):
		return false
	_switch_lane(lane_idx + 1)
	return true

func _switch_lane(new_lane: int) -> void:
	progress = track.convert_progress(lane_idx, new_lane, progress)
	lane_idx = new_lane
