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

const BLOCK_DIST_PX := 44.0

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

	_update_blocking()
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

	_clamp_to_nearest_ahead()

	while progress >= 1.0:
		progress -= 1.0
		laps_completed += 1

	position = track.get_horse_pos(lane_idx, progress)
	rotation = track.get_horse_rot(lane_idx, progress)

func _get_min_gap() -> float:
	if track == null:
		return 0.025
	var lane_len: float = track.get_lane_length(lane_idx)
	return BLOCK_DIST_PX / lane_len if lane_len > 0.0 else 0.025

func _update_blocking() -> void:
	is_blocked = false
	blocked_by = null
	var my_score: float = float(laps_completed) + progress
	var min_gap: float = _get_min_gap()
	var nearest_gap: float = INF
	for h in all_horses:
		if h == self:
			continue
		if h.lane_idx != lane_idx:
			continue
		if not h.is_processing() and not h.is_remote:
			continue
		var h_score: float = float(h.laps_completed) + h.progress
		var gap: float = h_score - my_score
		if gap <= 0.0 or gap > 0.5:
			continue
		if gap < nearest_gap:
			nearest_gap = gap
			blocked_by = h
	if blocked_by != null and nearest_gap < min_gap:
		is_blocked = true
	else:
		blocked_by = null

func _clamp_to_nearest_ahead() -> void:
	var my_score: float = float(laps_completed) + progress
	var min_gap: float = _get_min_gap()
	var nearest: Node2D = null
	var nearest_gap: float = INF
	for h in all_horses:
		if h == self:
			continue
		if h.lane_idx != lane_idx:
			continue
		if not h.is_processing() and not h.is_remote:
			continue
		var h_score: float = float(h.laps_completed) + h.progress
		var gap: float = h_score - my_score
		if gap > 0.0 and gap < nearest_gap:
			nearest_gap = gap
			nearest = h
	if nearest != null and nearest_gap < min_gap:
		var blocker_score: float = float(nearest.laps_completed) + nearest.progress
		var max_score: float = blocker_score - min_gap
		if max_score < 0.0:
			max_score = 0.0
		if my_score > max_score:
			laps_completed = int(max_score)
			progress = max_score - float(laps_completed)
			if progress < 0.0:
				progress = 0.0
			current_speed = minf(current_speed, nearest.current_speed)
		is_blocked = true
		blocked_by = nearest

func is_lane_blocked_by_neighbor(target_lane: int) -> bool:
	if track == null:
		return false
	var target_progress: float = track.convert_progress(lane_idx, target_lane, progress)
	var my_target_score: float = float(laps_completed) + target_progress
	var target_lane_len: float = track.get_lane_length(target_lane)
	var min_gap: float = BLOCK_DIST_PX / target_lane_len if target_lane_len > 0.0 else 0.025
	for h in all_horses:
		if h == self:
			continue
		if h.lane_idx != target_lane:
			continue
		if not h.is_processing() and not h.is_remote:
			continue
		var h_score: float = float(h.laps_completed) + h.progress
		if absf(h_score - my_target_score) < min_gap:
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
