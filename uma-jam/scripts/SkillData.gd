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
		"label":           "Boost de vitesse",
		"speed_bonus":     12.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  0.0,
		"duration":        4.0,
		"endurance_cost":  2.0,
		"condition":       "",
	},
	"accel_boost": {
		"label":           "Boost d'accélération",
		"speed_bonus":     0.0,
		"accel_bonus":     8.0,
		"recovery_bonus":  0.0,
		"duration":        3.0,
		"endurance_cost":  2.0,
		"condition":       "",
	},
	"endurance_recovery": {
		"label":           "Récupération d'endurance",
		"speed_bonus":     0.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  1.0,
		"duration":        30.0,
		"endurance_cost":  3.0,
		"condition":       "",
	},
	"speed_while_overtaking": {
		"label":           "Vitesse en doublant",
		"speed_bonus":     12.0,
		"accel_bonus":     0.0,
		"recovery_bonus":  0.0,
		"duration":        5.0,
		"endurance_cost":  3.0,
		"condition":       "overtaking",
	},
	"groundwork": {
		"label":           "Groundwork (départ)",
		"speed_bonus":     8.0,
		"accel_bonus":     8.0,
		"recovery_bonus":  0.0,
		"duration":        5.0,
		"endurance_cost":  2.0,
		"condition":       "phase_t1",
	},
}

const CHARACTER_PASSIVES: Dictionary = {
	"tachyon":        { "label": "Endurance Rush",       "desc": "Gagne de la vitesse en activant un skill d'endurance (+3 vitesse, 4s)" },
	"el_condor_passa": { "label": "Last Spurt Condor",    "desc": "Gagne de l'accélération en last spurt entre 2e et 4e (+2 accél, conditionnel permanent)" },
	"gold_ship":       { "label": "Overtaking Rush",      "desc": "Gagne de la vitesse en doublant (+2 vitesse, 5s)" },
	"maruzenski":      { "label": "Chasing Glory",        "desc": "Gagne de la vitesse si pas 1ère (+1 vitesse permanent), mais +1 coût d'endurance sur tous les skills" },
	"oguri_cap":       { "label": "Final Stretch",        "desc": "Vitesse et accélération augmentées dans la dernière ligne droite (+4 vitesse/accél, conditionnel permanent)" },
	"sakura":          { "label": "Mid-Race Surge",       "desc": "Gagne de la vitesse en T2 si pas 1ère (+1 vitesse, 10s, déclenche une seule fois)" },
	"spe_chan":         { "label": "Underdog Sprint",      "desc": "Gagne de l'accélération en last spurt entre 4e et 6e (+3 accél, conditionnel permanent)" },
	"rudolf":          { "label": "Pressure from Behind", "desc": "Débuff le cheval directement devant sur le même couloir (-2 vitesse, 3s)" },
}
