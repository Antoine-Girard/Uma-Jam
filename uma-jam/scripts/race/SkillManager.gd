class_name SkillManager
extends Node

signal skill_activated(skill_id: String)

signal passive_triggered(char_id: String, passive_label: String, bonus_desc: String)

signal buff_expired(buff_id: String)

signal endurance_changed(new_val: float, old_val: float)

signal debuff_applied(target_horse: Node, speed_penalty: float, duration: float)

var horse_ref:       Node    = null
var race_ref:        Node2D  = null
var all_horses:      Array   = []
var character_id:    String  = ""
var is_local_player: bool    = false

var endurance:       float = SkillData.MAX_ENDURANCE

var _recovery_timer: float = 0.0

var _buffs: Array[Dictionary] = []
var _buff_counter: int = 0

# Bot AI
var is_bot: bool             = false
var bot_skill_ids: Array     = []
var _bot_next_skill: String  = ""
var _bot_cooldown: float     = 0.0

var _passive_state: Dictionary = {
	"prev_rank":        0,
	"overtaking":       false,
	"overtaking_timer": 0.0,
	"sakura_triggered": false,
	"rudolf_cooldown":  0.0,
}

func init(horse: Node, race: Node2D, horses: Array,
		char_id: String, local: bool) -> void:
	horse_ref       = horse
	race_ref        = race
	all_horses      = horses
	character_id    = char_id
	is_local_player = local
	endurance       = SkillData.MAX_ENDURANCE
	_passive_state["prev_rank"] = horses.size()
	print("[SkillManager] %s | character: %s | local: %s" % [
		horse_ref.horse_name if horse_ref else "?",
		character_id, str(is_local_player)])

func update(delta: float) -> void:
	if horse_ref == null:
		return
	_tick_buffs(delta)
	_tick_endurance_recovery(delta)
	_process_passives(delta)
	if is_bot:
		_bot_ai(delta)

func activate_skill(skill_id: String) -> bool:
	if not is_local_player and not is_bot:
		# Remote player skills are applied directly
		if not SkillData.ACTIVE_SKILLS.has(skill_id):
			return false
		var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]
		_apply_buff({
			"id":             skill_id,
			"speed_bonus":    def["speed_bonus"],
			"accel_bonus":    def["accel_bonus"],
			"recovery_bonus": def["recovery_bonus"],
			"duration":       def["duration"],
			"timer":          def["duration"],
			"is_conditional": false,
		})
		return true

	if not SkillData.ACTIVE_SKILLS.has(skill_id):
		push_warning("[SkillManager] Unknown skill: '%s'" % skill_id)
		return false

	var def: Dictionary = SkillData.ACTIVE_SKILLS[skill_id]

	if not check_skill_condition(def["condition"]):
		print("[SkillManager] Condition '%s' not met for: %s" % [def["condition"], skill_id])
		return false

	var cost: float = def["endurance_cost"]
	if character_id == "maruzenski":
		cost += 1.0

	if endurance < cost:
		print("[SkillManager] Insufficient endurance for %s (need %.1f, current %.1f)" % [
			skill_id, cost, endurance])
		return false

	_set_endurance(endurance - cost)

	_apply_buff({
		"id":             skill_id,
		"speed_bonus":    def["speed_bonus"],
		"accel_bonus":    def["accel_bonus"],
		"recovery_bonus": def["recovery_bonus"],
		"duration":       def["duration"],
		"timer":          def["duration"],
		"is_conditional": false,
	})

	skill_activated.emit(skill_id)
	print("[SkillManager] Skill activated: %s | remaining endurance: %.1f" % [skill_id, endurance])

	if character_id == "tachyon" and skill_id == "endurance_recovery":
		_apply_buff({
			"id":             "passive_tachyon",
			"speed_bonus":    12.0,
			"accel_bonus":    0.0,
			"recovery_bonus": 0.0,
			"duration":       4.0,
			"timer":          4.0,
			"is_conditional": false,
		})
		passive_triggered.emit("tachyon", "Endurance Rush", "+12 speed for 4s")

	return true

func get_speed_bonus() -> float:
	var total := 0.0
	for b: Dictionary in _buffs:
		total += b.get("speed_bonus", 0.0)
	return total

func get_accel_bonus() -> float:
	var total := 0.0
	for b: Dictionary in _buffs:
		total += b.get("accel_bonus", 0.0)
	return total

func get_effective_max_speed(race_phase: int) -> float:
	var base := SkillData.LAST_SPURT_SPEED \
		if race_phase == SkillData.PHASE_LAST_SPURT \
		else SkillData.BASE_SPEED
	return base + get_speed_bonus()

func get_effective_accel() -> float:
	return SkillData.BASE_ACCEL + get_accel_bonus()

func get_endurance() -> float:
	return endurance

func is_overtaking() -> bool:
	return _passive_state.get("overtaking", false)

func get_active_buff_ids() -> Array[String]:
	var ids: Array[String] = []
	for b: Dictionary in _buffs:
		ids.append(b["id"])
	return ids

func apply_debuff(buff_id: String, speed_penalty: float, duration: float) -> void:
	_apply_buff({
		"id":             buff_id,
		"speed_bonus":    -speed_penalty,
		"accel_bonus":    0.0,
		"recovery_bonus": 0.0,
		"duration":       duration,
		"timer":          duration,
		"is_conditional": false,
	})
	print("[SkillManager] Debuff '%s' applied on %s: -%.1f speed, %.1fs" % [
		buff_id,
		horse_ref.horse_name if horse_ref else "?",
		speed_penalty, duration])

func _tick_buffs(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in _buffs.size():
		var b: Dictionary = _buffs[i]
		if b["duration"] < 0.0:
			continue
		b["timer"] -= delta
		if b["timer"] <= 0.0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		var b: Dictionary = _buffs[to_remove[i]]
		print("[SkillManager] Buff expired: %s" % b["id"])
		buff_expired.emit(b["id"])
		_buffs.remove_at(to_remove[i])

func _tick_endurance_recovery(delta: float) -> void:
	if endurance >= SkillData.MAX_ENDURANCE:
		_recovery_timer = 0.0
		return
	_recovery_timer += delta
	if _recovery_timer >= SkillData.BASE_RECOVERY_INTERVAL:
		_recovery_timer -= SkillData.BASE_RECOVERY_INTERVAL
		var bonus := _get_recovery_bonus()
		_set_endurance(minf(endurance + SkillData.BASE_RECOVERY_RATE + bonus,
				SkillData.MAX_ENDURANCE))

func _get_recovery_bonus() -> float:
	var total := 0.0
	for b: Dictionary in _buffs:
		total += b.get("recovery_bonus", 0.0)
	return total

func _set_endurance(val: float) -> void:
	var prev := endurance
	endurance = clampf(val, 0.0, SkillData.MAX_ENDURANCE)
	if not is_equal_approx(endurance, prev):
		endurance_changed.emit(endurance, prev)

func _process_passives(delta: float) -> void:
	var rank  := _get_my_rank()
	var phase := _get_race_phase()

	var prev_rank: int = _passive_state["prev_rank"]
	if rank < prev_rank and prev_rank > 0:
		_passive_state["overtaking_timer"] = 4.0
	_passive_state["prev_rank"] = rank

	if _passive_state["overtaking_timer"] > 0.0:
		_passive_state["overtaking_timer"] -= delta
		_passive_state["overtaking"] = true
	else:
		_passive_state["overtaking"] = false

	match character_id:
		"el_condor_passa": _passive_el_condor(rank, phase)
		"gold_ship":       _passive_gold_ship()
		"maruzenski":      _passive_maruzenski(rank)
		"oguri_cap":       _passive_oguri_cap(phase)
		"sakura":          _passive_sakura(rank, phase)
		"spe_chan":         _passive_spe_chan(rank, phase)
		"rudolf":          _passive_rudolf(delta)

func _passive_el_condor(rank: int, phase: int) -> void:
	var cond := (phase == SkillData.PHASE_LAST_SPURT and rank >= 2 and rank <= 4)
	_set_conditional_buff("passive_el_condor",
		0.0, 8.0, 0.0, cond, "Last Spurt Condor", "+2 accel (last spurt, 2nd-4th)")

func _passive_gold_ship() -> void:
	if _passive_state["overtaking"] and not _has_buff("passive_gold_ship"):
		_apply_buff({
			"id":             "passive_gold_ship",
			"speed_bonus":    8.0,
			"accel_bonus":    0.0,
			"recovery_bonus": 0.0,
			"duration":       5.0,
			"timer":          5.0,
			"is_conditional": false,
		})
		passive_triggered.emit("gold_ship", "Overtaking Rush", "+2 speed for 5s")

func _passive_maruzenski(rank: int) -> void:
	var cond := rank > 1
	_set_conditional_buff("passive_maruzenski",
		4.0, 0.0, 0.0, cond,
		"Chasing Glory", "+4 speed (not 1st)")

func _passive_oguri_cap(phase: int) -> void:
	var cond := (phase == SkillData.PHASE_LAST_SPURT)
	_set_conditional_buff("passive_oguri_cap",
		4.0, 4.0, 0.0, cond,
		"Final Stretch", "+4 speed/accel (final straight)")

func _passive_sakura(rank: int, phase: int) -> void:
	if _passive_state["sakura_triggered"]:
		return
	if phase == SkillData.PHASE_T2 and rank > 1:
		_passive_state["sakura_triggered"] = true
		_apply_buff({
			"id":             "passive_sakura",
			"speed_bonus":    4.0,
			"accel_bonus":    0.0,
			"recovery_bonus": 0.0,
			"duration":       10.0,
			"timer":          10.0,
			"is_conditional": false,
		})
		passive_triggered.emit("sakura", "Mid-Race Surge", "+4 speed for 10s (T2, not 1st)")

func _passive_spe_chan(rank: int, phase: int) -> void:
	var cond := (phase == SkillData.PHASE_LAST_SPURT and rank >= 4 and rank <= 6)
	_set_conditional_buff("passive_spe_chan",
		0.0, 3.0, 0.0, cond, "Underdog Sprint", "+3 accel (last spurt, 4th-6th)")

const _RUDOLF_INTERVAL := 3.0

func _passive_rudolf(delta: float) -> void:
	_passive_state["rudolf_cooldown"] -= delta
	if _passive_state["rudolf_cooldown"] > 0.0:
		return

	var target := _find_horse_directly_ahead()
	if target == null:
		_passive_state["rudolf_cooldown"] = _RUDOLF_INTERVAL * 0.5
		return

	var target_sm: SkillManager = null
	for child in target.get_children():
		if child is SkillManager:
			target_sm = child
			break

	if target_sm != null:
		target_sm.apply_debuff("rudolf_debuff", 2.0, _RUDOLF_INTERVAL)
		debuff_applied.emit(target, 2.0, _RUDOLF_INTERVAL)
		passive_triggered.emit("rudolf", "Pressure from Behind",
			"Debuff %s: -2 speed for %.0fs" % [target.horse_name, _RUDOLF_INTERVAL])

	_passive_state["rudolf_cooldown"] = _RUDOLF_INTERVAL

func _apply_buff(buff: Dictionary) -> void:
	_buff_counter += 1
	buff["uid"] = _buff_counter
	if buff.get("is_conditional", false):
		for i in _buffs.size():
			if _buffs[i]["id"] == buff["id"]:
				_buffs.remove_at(i)
				break
	_buffs.append(buff)

func _has_buff(buff_id: String) -> bool:
	for b: Dictionary in _buffs:
		if b["id"] == buff_id:
			return true
	return false

func _set_conditional_buff(
		buff_id: String,
		speed_bonus: float, accel_bonus: float, recovery_bonus: float,
		is_active: bool,
		passive_label: String, bonus_desc: String) -> void:

	var had_buff := _has_buff(buff_id)
	if is_active and not had_buff:
		_apply_buff({
			"id":             buff_id,
			"speed_bonus":    speed_bonus,
			"accel_bonus":    accel_bonus,
			"recovery_bonus": recovery_bonus,
			"duration":       -1.0,
			"timer":          -1.0,
			"is_conditional": true,
		})
		passive_triggered.emit(character_id, passive_label, bonus_desc)
	elif not is_active and had_buff:
		for i in _buffs.size():
			if _buffs[i]["id"] == buff_id:
				_buffs.remove_at(i)
				buff_expired.emit(buff_id)
				break

func check_skill_condition(condition: String) -> bool:
	match condition:
		"":           return true
		"overtaking": return _passive_state.get("overtaking", false)
		"phase_t1":   return _get_race_phase() == SkillData.PHASE_T1
		"first_at_t3": return _get_race_phase() == SkillData.PHASE_LAST_SPURT and _get_my_rank() == 1
		"last_at_t3":  return _get_race_phase() == SkillData.PHASE_LAST_SPURT and _get_my_rank() == all_horses.size()
		"not_first":   return _get_my_rank() > 1
		_:            return true

func _get_my_rank() -> int:
	if horse_ref == null:
		return 1
	if race_ref != null and race_ref.has_method("get_horse_rank"):
		return race_ref.get_horse_rank(horse_ref)
	var my_score: float = horse_ref.laps_completed + horse_ref.progress
	var rank := 1
	for h in all_horses:
		if h == horse_ref:
			continue
		var s: float = h.laps_completed + h.progress
		if s > my_score:
			rank += 1
	return rank

func _get_race_phase() -> int:
	if horse_ref == null:
		return SkillData.PHASE_T1
	var total_laps := 3
	if race_ref != null and race_ref.has_method("get_total_laps"):
		total_laps = race_ref.get_total_laps()
	var progress: float = (horse_ref.laps_completed + horse_ref.progress) / float(total_laps)
	if progress >= 0.75:
		return SkillData.PHASE_LAST_SPURT
	elif progress >= 0.33:
		return SkillData.PHASE_T2
	else:
		return SkillData.PHASE_T1

func _find_horse_directly_ahead() -> Node:
	if horse_ref == null:
		return null
	var my_lane:  int   = horse_ref.lane_idx
	var my_score: float = horse_ref.laps_completed + horse_ref.progress
	var best:       Node  = null
	var best_score: float = INF
	for h in all_horses:
		if h == horse_ref:
			continue
		if h.lane_idx != my_lane:
			continue
		var s: float = h.laps_completed + h.progress
		if s > my_score and s < best_score:
			best_score = s
			best       = h
	return best


# ─── Bot AI ──────────────────────────────────────────────────────────────────

func init_bot(skill_ids: Array) -> void:
	is_bot = true
	is_local_player = true  # allow skill activation
	bot_skill_ids = skill_ids.duplicate()
	_bot_pick_next_skill()
	_bot_cooldown = randf_range(3.0, 8.0)  # wait before first skill


func _bot_pick_next_skill() -> void:
	if bot_skill_ids.is_empty():
		_bot_next_skill = ""
		return
	_bot_next_skill = bot_skill_ids[randi() % bot_skill_ids.size()]


func _bot_ai(delta: float) -> void:
	if _bot_next_skill == "":
		return
	_bot_cooldown -= delta
	if _bot_cooldown > 0.0:
		return

	# Try to use the skill
	var ok := activate_skill(_bot_next_skill)
	if ok:
		_bot_pick_next_skill()
		_bot_cooldown = randf_range(4.0, 10.0)
	else:
		# Condition not met or not enough endurance, try again soon
		_bot_cooldown = 1.0
