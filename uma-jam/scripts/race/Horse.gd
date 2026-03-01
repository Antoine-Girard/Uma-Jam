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
var char_id: String    = ""
var skill_manager: SkillManager = null

var all_horses: Array  = []
var is_blocked: bool   = false
var blocked_by: Node2D = null
var is_remote: bool    = false  # Remote player: position controlled by network updates only

const BLOCK_PX := 38.0  # pixel distance for blocking (portrait ~36px)

var _label: Label
var _sprite: Sprite2D

func _ready() -> void:
	# Label du nom au-dessus
	_label = Label.new()
	_label.text = horse_name
	_label.position = Vector2(-28.0, -38.0)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)

	# Portrait du personnage
	_sprite = Sprite2D.new()
	var icon_id: String = GameData.CHAR_ID_TO_ICON.get(char_id, "")
	if icon_id != "":
		var tex := load("res://assets/characters/%s.png" % icon_id) as Texture2D
		if tex:
			_sprite.texture = tex
			# Redimensionner pour que le portrait fasse ~32x32
			var tex_size := tex.get_size()
			_sprite.scale = Vector2(32.0 / tex_size.x, 32.0 / tex_size.y)
	_sprite.position = Vector2.ZERO
	add_child(_sprite)

	# Bordure colorée autour du portrait
	queue_redraw()

	# Set initial position so blocking checks work before first _process
	if track:
		position = track.get_horse_pos(lane_idx, progress)
		rotation = track.get_horse_rot(lane_idx, progress)

func _process(delta: float) -> void:
	if track == null:
		return

	# Remote players: simple prediction using last known speed, no blocking logic
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

	# Check if blocked by a horse directly ahead on the same lane
	_update_blocking()
	if is_blocked and blocked_by != null:
		var blocker_speed: float = blocked_by.current_speed
		# Immediately cap current speed too, not just max
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
	var progress_delta: float = (current_speed * delta) / lane_length
	progress += progress_delta

	# Hard clamp: never go past the blocker's progress
	if is_blocked and blocked_by != null:
		var blocker_score: float = blocked_by.laps_completed + blocked_by.progress
		var my_score: float = laps_completed + progress
		# Only clamp if we're not too far ahead (prevents glitches at finish)
		if my_score > blocker_score - 0.001 and my_score < blocker_score + 0.5:
			progress = blocked_by.progress - 0.001
			laps_completed = blocked_by.laps_completed
			if progress < 0.0:
				progress += 1.0
				laps_completed -= 1

	while progress >= 1.0:
		progress -= 1.0
		laps_completed += 1

	position = track.get_horse_pos(lane_idx, progress)
	rotation = track.get_horse_rot(lane_idx, progress)

func _update_blocking() -> void:
	is_blocked = false
	blocked_by = null
	var my_score: float = laps_completed + progress
	for h in all_horses:
		if h == self:
			continue
		if h.lane_idx != lane_idx:
			continue
		# Ignore finished horses (they're parked at the finish line)
		if not h.is_processing():
			continue
		# Must be ahead of us
		var h_score: float = h.laps_completed + h.progress
		if h_score <= my_score:
			continue
		# Check visual distance (pixel)
		var dist_px: float = position.distance_to(h.position)
		if dist_px < BLOCK_PX:
			is_blocked = true
			blocked_by = h
			break

func is_lane_blocked_by_neighbor(target_lane: int) -> bool:
	# Calculate where we WOULD be on the target lane
	var target_progress: float = track.convert_progress(lane_idx, target_lane, progress)
	var my_target_pos: Vector2 = track.get_horse_pos(target_lane, target_progress)
	for h in all_horses:
		if h == self:
			continue
		if h.lane_idx != target_lane:
			continue
		# Ignore finished horses
		if not h.is_processing():
			continue
		var dist_px: float = my_target_pos.distance_to(h.position)
		if dist_px < BLOCK_PX:
			return true
	return false

func _draw() -> void:
	var c: Color = HORSE_COLORS[color_idx % HORSE_COLORS.size()]
	# Bordure colorée autour du portrait
	draw_rect(Rect2(-18.0, -18.0, 36.0, 36.0), c, false, 2.5)

func move_inner() -> bool:
	if lane_idx <= 0:
		return false
	if is_lane_blocked_by_neighbor(lane_idx - 1):
		return false
	_switch_lane(lane_idx - 1)
	return true

func move_outer() -> bool:
	if lane_idx >= 5:
		return false
	if is_lane_blocked_by_neighbor(lane_idx + 1):
		return false
	_switch_lane(lane_idx + 1)
	return true

func _switch_lane(new_lane: int) -> void:
	# Convert progress segment by segment to preserve perpendicular position
	progress = track.convert_progress(lane_idx, new_lane, progress)
	lane_idx = new_lane
