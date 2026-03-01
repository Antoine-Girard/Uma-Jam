extends Node

const BASE_SPEED := 30.0
const LAST_SPURT_SPEED := 50.0
const BASE_ACCEL := 3.0

const MAX_ENDURANCE := 10.0
const BASE_RECOVERY_RATE := 1.0
const BASE_RECOVERY_INTERVAL := 5.0

const PHASE_T1 := 0
const PHASE_T2 := 1
const PHASE_LAST_SPURT := 2

const ACTIVE_SKILLS: Dictionary = {
	"speed_boost": {
		"label": "Speed Boost",
		"short": "VIT",
		"icon": "tex_support_card_30011",
		"desc": "Speed +12 for 4s, cost 2",
		"speed_bonus": 12.0,
		"accel_bonus": 0.0,
		"recovery_bonus": 0.0,
		"duration": 4.0,
		"endurance_cost": 2.0,
		"condition": "",
	},
	"accel_boost": {
		"label": "Accel Boost",
		"short": "ACC",
		"icon": "tex_support_card_30014",
		"desc": "Accel +8 for 3s, cost 2",
		"speed_bonus": 0.0,
		"accel_bonus": 8.0,
		"recovery_bonus": 0.0,
		"duration": 3.0,
		"endurance_cost": 2.0,
		"condition": "",
	},
	"endurance_recovery": {
		"label": "Endurance Recovery",
		"short": "END",
		"icon": "tex_support_card_30028",
		"desc": "Regen +1 endurance for 30s, cost 5",
		"speed_bonus": 0.0,
		"accel_bonus": 0.0,
		"recovery_bonus": 1,
		"duration": 35.0,
		"endurance_cost": 5.0,
		"condition": "",
	},
	"speed_while_overtaking": {
		"label": "Overtaking Speed",
		"short": "OVT",
		"icon": "tex_support_card_30043",
		"desc": "Speed +12 for 5s (while overtaking), cost 3",
		"speed_bonus": 12.0,
		"accel_bonus": 0.0,
		"recovery_bonus": 0.0,
		"duration": 5.0,
		"endurance_cost": 3.0,
		"condition": "overtaking",
	},
	"groundwork": {
		"label": "Groundwork",
		"short": "GND",
		"icon": "tex_support_card_30076",
		"desc": "Speed +5, Accel +20 for 5s, cost 3 (first lap only)",
		"speed_bonus": 5.0,
		"accel_bonus": 20.0,
		"recovery_bonus": 0.0,
		"duration": 5.0,
		"endurance_cost": 3.0,
		"condition": "phase_t1",
	},
	"leader_t3_boost": {
		"label": "Leader's phase 3 Surge",
		"short": "LDR",
		"icon": "tex_support_card_30265",
		"desc": "Speed +12, Accel +5 for 8s, cost 2 (1st place at phase 3)",
		"speed_bonus": 12.0,
		"accel_bonus": 5.0,
		"recovery_bonus": 0.0,
		"duration": 8.0,
		"endurance_cost": 2.0,
		"condition": "first_at_t3",
	},
	"last_place_t3_boost": {
		"label": "Comeback Sprint",
		"short": "CMB",
		"icon": "tex_support_card_30256",
		"desc": "Speed +30, Accel +15 for 10s, cost 10 (4th-6th place at phase 3)",
		"speed_bonus": 30.0,
		"accel_bonus": 15.0,
		"recovery_bonus": 0.0,
		"duration": 10.0,
		"endurance_cost": 5.0,
		"condition": "last_at_t3",
	},
	"drafting_boost": {
		"label": "Drafting Burst",
		"short": "DRF",
		"icon": "tex_support_card_30057",
		"desc": "Speed +3 for 15s, cost 1(close behind a horse in same lane)",
		"speed_bonus": 3.0,
		"accel_bonus": 0.0,
		"recovery_bonus": 0.0,
		"duration": 15.0,
		"endurance_cost": 1.0,
		"condition": "drafting",
	},
}

const CHARACTER_PASSIVES: Dictionary = {
	"tachyon": { "name": "Agnes Tachyon", "label": "Endurance Rush", "type": "Endurance", "desc": "Gains speed when activating an endurance skill (+6 speed, 5s)" },
	"el_condor_passa": { "name": "El Condor Pasa", "label": "Last Spurt Condor", "type": "Power", "desc": "Gains acceleration in last spurt between 2nd and 4th (+2 accel, conditional permanent)" },
	"gold_ship": { "name": "Gold Ship", "label": "Overtaking Rush", "type": "Overtake", "desc": "Gains speed when overtaking (+10 speed, 5s)" },
	"maruzenski": { "name": "Maruzensky", "label": "Chasing Glory", "type": "Speed", "desc": "Gains speed if not 1st (+9 speed permanent), but +1 endurance cost on all skills" },
	"oguri_cap": { "name": "Oguri Cap", "label": "Final Stretch", "type": "All in", "desc": "Speed and acceleration increased in last phase (+25 speed, +10 accel, conditional permanent)" },
	"sakura": { "name": "Sakura Bakushin O","label": "Mid-Race Surge", "type": "Speed", "desc": "Gains speed while not in 1st place (+10 speed, constant)" },
	"spe_chan": { "name": "Special Week", "label": "Underdog Sprint", "type": "Power", "desc": "Gains acceleration in last spurt between 4th and 6th (+3 accel, conditional permanent)" },
	"rudolf": { "name": "Symboli Rudolf", "label": "Pressure from Behind", "type": "Speed", "desc": "Gains speed when a horse is directly ahead in the same lane (+13 speed, 1s)" },
}
