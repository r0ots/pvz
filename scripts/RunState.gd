extends Node
# Per-run state — resets when a new run starts

var active_perks: Array = []         # list of perk IDs chosen
var perk_stacks: Dictionary = {}     # perk_id -> stack count
var seeds_earned: int = 0

# ---- Computed bonuses (recalculated whenever a perk is added) ----
var sun_cost_mult:          float = 1.0
var plant_hp_mult:          float = 1.0
var sun_value_bonus:        int   = 0
var sky_sun_interval_mult:  float = 1.0
var proj_speed_bonus:       float = 0.0

var peashooter_double_shot: bool  = false
var peashooter_rapid_fire:  bool  = false
var peashooter_freeze:      bool  = false

var sunflower_interval_mult: float = 1.0
var sunflower_double_sun:    bool  = false

var wallnut_thorns:     bool  = false
var wallnut_hp_mult:    float = 1.0

func reset() -> void:
	active_perks  = []
	perk_stacks   = {}
	seeds_earned  = 0
	_recompute()

func add_perk(perk_id: String) -> void:
	if perk_id not in active_perks:
		active_perks.append(perk_id)
	perk_stacks[perk_id] = perk_stacks.get(perk_id, 0) + 1
	_recompute()

func has_perk(perk_id: String) -> bool:
	return perk_id in active_perks

func stack_count(perk_id: String) -> int:
	return perk_stacks.get(perk_id, 0)

func earn_seeds(amount: int) -> void:
	seeds_earned += amount
	MetaProgress.earn_seeds(amount)

func _recompute() -> void:
	sun_cost_mult           = 1.0
	plant_hp_mult           = 1.0
	sun_value_bonus         = 0
	sky_sun_interval_mult   = 1.0
	proj_speed_bonus        = 0.0
	peashooter_double_shot  = false
	peashooter_rapid_fire   = false
	peashooter_freeze       = false
	sunflower_interval_mult = 1.0
	sunflower_double_sun    = false
	wallnut_thorns          = false
	wallnut_hp_mult         = 1.0

	for pid in active_perks:
		var n := perk_stacks.get(pid, 1)
		match pid:
			"cheap_plants":   sun_cost_mult          *= pow(0.80, n)
			"hardy_plants":   plant_hp_mult           *= pow(1.25, n)
			"rich_sun":       sun_value_bonus         += 10 * n
			"fast_sun":       sky_sun_interval_mult   *= pow(0.75, n)
			"swift_peas":     proj_speed_bonus        += 120.0 * n
			"double_shot":    peashooter_double_shot   = true
			"rapid_fire":     peashooter_rapid_fire    = true
			"frozen_peas":    peashooter_freeze        = true
			"solar_flare":    sunflower_interval_mult  *= pow(0.70, n)
			"twin_sun":       sunflower_double_sun      = true
			"iron_nut":       wallnut_hp_mult           *= pow(1.50, n)
			"thorns":         wallnut_thorns             = true
