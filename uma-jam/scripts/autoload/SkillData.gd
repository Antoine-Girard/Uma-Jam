extends Node

const BASE_SPEED             := 30.0
const LAST_SPURT_SPEED       := 50.0
const BASE_ACCEL             := 3.0

const MAX_ENDURANCE          := 10.0
const BASE_RECOVERY_RATE     := 1.0
const BASE_RECOVERY_INTERVAL := 5.0

const PHASE_T1         := 0
const PHASE_T2         := 1
const PHASE_LAST_SPURT := 2

const ACTIVE_SKILLS: Dictionary = {
	"speed_boost": {
		"label":           "Speed Boost",
		"short":           "VIT",
		"icon":            "tex_support_card_30011",
		"desc":            "Increases speed by +12 for 4s",
		"speed_bonus":     12.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  0.0,
		"duration":        4.0,
		"endurance_cost":  2.0,
		"condition":       "",
	},
	"accel_boost": {
		"label":           "Accel Boost",
		"short":           "ACC",
		"icon":            "tex_support_card_30014",
		"desc":            "Increases acceleration by +8 for 3s",
		"speed_bonus":     0.0,
		"accel_bonus":     8.0,
		"recovery_bonus":  0.0,
		"duration":        3.0,
		"endurance_cost":  2.0,
		"condition":       "",
	},
	"endurance_recovery": {
		"label":           "Endurance Recovery",
		"short":           "END",
		"icon":            "tex_support_card_30028",
		"desc":            "Recovers endurance (+1/s for 30s)",
		"speed_bonus":     0.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  1.0,
		"duration":        30.0,
		"endurance_cost":  3.0,
		"condition":       "",
	},
	"speed_while_overtaking": {
		"label":           "Overtaking Speed",
		"short":           "OVT",
		"icon":            "tex_support_card_30043",
		"desc":            "Speed +12 for 5s\nCondition: overtaking",
		"speed_bonus":     12.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  0.0,
		"duration":        5.0,
		"endurance_cost":  3.0,
		"condition":       "overtaking",
	},
	"groundwork": {
		"label":           "Groundwork",
		"short":           "GND",
		"icon":            "tex_support_card_30076",
		"desc":            "Speed +8, Accel +8 for 5s\nCondition: Lap 1 only",
		"speed_bonus":     8.0,
		"accel_bonus":     8.0,
		"recovery_bonus":  0.0,
		"duration":        5.0,
		"endurance_cost":  2.0,
		"condition":       "phase_t1",
	},
	"leader_t3_boost": {
		"label":           "Leader's T3 Surge",
		"short":           "LDR",
		"icon":            "tex_support_card_30265",
		"desc":            "Speed +4, Accel +3 for 10s (1st place at T3)",
		"speed_bonus":     4.0,
		"accel_bonus":     3.0,
		"recovery_bonus":  0.0,
		"duration":        10.0,
		"endurance_cost":  2.0,
		"condition":       "first_at_t3",
	},
	"last_place_t3_boost": {
		"label":           "Comeback Sprint",
		"short":           "CMB",
		"icon":            "tex_support_card_30256",
		"desc":            "Speed +5, Accel +4 for 10s (last place at T3)",
		"speed_bonus":     5.0,
		"accel_bonus":     4.0,
		"recovery_bonus":  0.0,
		"duration":        10.0,
		"endurance_cost":  2.0,
		"condition":       "last_at_t3",
	},
	"drafting_boost": {
		"label":           "Drafting Burst",
		"short":           "DRF",
		"icon":            "tex_support_card_30057",
		"desc":            "Speed +3 for 4s (behind another horse)",
		"speed_bonus":     3.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  0.0,
		"duration":        4.0,
		"endurance_cost":  1.0,
		"condition":       "not_first",
	},
}

const CHARACTER_PASSIVES: Dictionary = {
	"tachyon":        { "label": "Endurance Rush",       "desc": "Gains speed when activating an endurance skill (+3 speed, 4s)" },
	"el_condor_passa": { "label": "Last Spurt Condor",    "desc": "Gains acceleration in last spurt between 2nd and 4th (+2 accel, conditional permanent)" },
	"gold_ship":       { "label": "Overtaking Rush",      "desc": "Gains speed when overtaking (+2 speed, 5s)" },
	"maruzenski":      { "label": "Chasing Glory",        "desc": "Gains speed if not 1st (+1 speed permanent), but +1 endurance cost on all skills" },
	"oguri_cap":       { "label": "Final Stretch",        "desc": "Speed and acceleration increased in the final straight (+4 speed/accel, conditional permanent)" },
	"sakura":          { "label": "Mid-Race Surge",       "desc": "Gains speed in T2 if not 1st (+1 speed, 10s, triggers once)" },
	"spe_chan":         { "label": "Underdog Sprint",      "desc": "Gains acceleration in last spurt between 4th and 6th (+3 accel, conditional permanent)" },
	"rudolf":          { "label": "Pressure from Behind", "desc": "Debuffs the horse directly ahead in the same lane (-2 speed, 3s)" },
}
