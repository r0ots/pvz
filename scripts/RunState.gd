extends Node
# Per-run state — resets each new game

var active_perks: Array  = []
var perk_stacks:  Dictionary = {}
var seeds_earned: int = 0

# ---- Flexible bonus/flag storage ----
var bonuses: Dictionary = {}   # String -> float
var flags:   Dictionary = {}   # String -> bool

func reset() -> void:
	active_perks = []
	perk_stacks  = {}
	seeds_earned = 0
	bonuses      = {}
	flags        = {}
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

# ---- Accessors ----
func b(key: String, default: float = 0.0) -> float:
	return bonuses.get(key, default)

func f(key: String) -> bool:
	return flags.get(key, false)

func bn(key: String, default: float = 1.0) -> float:
	# Multiplicative bonus: returns accumulated multiplier (default 1.0)
	return bonuses.get(key + "_mult", default)

# ---- Recompute all effects ----
func _recompute() -> void:
	bonuses = {}
	flags   = {}
	for pid in active_perks:
		var n := perk_stacks.get(pid, 1)
		_apply(pid, n)

func _apply(pid: String, n: int) -> void:
	match pid:
		# ============ GLOBAL ECONOMY ============
		"cheap_plants":      _mul("sun_cost", 0.80, n)
		"budget_seeds":      _mul("sun_cost", 0.85, n)
		"sun_hoard":         _add("sun_value", 10 * n)
		"golden_sun":        _add("sun_value", 18 * n)
		"sun_surge":         _add("sun_value", 30 * n)
		"rich_harvest":      _add("starting_sun", 50 * n)
		"fast_sun":          _mul("sky_sun_interval", 0.75, n)
		"solar_wind":        _mul("sky_sun_interval", 0.65, n)
		"sun_shower":        _flag("sky_sun_shower")
		"auto_collect":      _flag("auto_collect_sun")
		"sun_bank":          _add("sun_interest", 0.05 * n)
		"fertile_soil":      _mul("sun_cost", 0.90, n)
		"sun_magnet":        _flag("sun_magnet")
		"penny_saver":       _add("refund_pct", 0.20 * n)
		"free_placement":    _flag("first_plant_free")

		# ============ GLOBAL COMBAT ============
		"swift_peas":        _add("proj_speed", 120.0 * n)
		"supersonic":        _add("proj_speed", 200.0 * n)
		"hardy_plants":      _mul("plant_hp", 1.25, n)
		"iron_will":         _mul("plant_hp", 1.40, n)
		"war_machine":       _mul("all_firerate", 0.85, n)
		"overdrive":         _flag("overdrive_last_wave")
		"cascade_kill":      _flag("cascade_kill")
		"overkill":          _flag("overkill")
		"berserker":         _flag("berserker_low_hp")
		"solidarity":        _flag("solidarity_on_death")
		"domino_peas":       _flag("domino_peas")
		"escalation":        _add("escalation_per_wave", 0.05 * n)
		"emergency_barrage": _flag("emergency_barrage")
		"surge_start":       _flag("wave_start_surge")
		"death_blossom":     _flag("death_blossom")

		# ============ GLOBAL SYNERGY ============
		"best_buds":         _flag("syn_sunflower_peashooter")
		"freeze_squeeze":    _flag("syn_snowpea_chomper")
		"chain_explosion":   _flag("syn_cherrybomb_mine")
		"arctic_garden":     _flag("syn_arctic_garden")
		"shield_wall":       _flag("syn_shield_wall")
		"sun_army":          _flag("syn_sun_army")
		"pea_storm":         _flag("syn_pea_storm")
		"pesticide":         _flag("syn_all_plants")
		"overgrown":         _flag("syn_overgrown")
		"perfect_garden":    _flag("syn_perfect_garden")

		# ============ LEGENDARY ============
		"time_warp":         _flag("legendary_time_warp")
		"instant_garden":    _flag("legendary_instant_garden")
		"sun_god":           _mul("sky_sun_interval", 0.33, n); _add("sun_value", 50)
		"mega_pea":          _flag("legendary_mega_pea")
		"clone_army":        _flag("legendary_clone_army")
		"zombie_plague":     _flag("legendary_zombie_plague")
		"perfect_storm":     _flag("legendary_perfect_storm")
		"second_wind":       _flag("legendary_second_wind")
		"ultimate_power":    _mul("plant_hp", 2.0, n); _mul("all_firerate", 0.5, n); _add("proj_speed", 200); _add("sun_value", 50)
		"garden_of_eden":    _flag("legendary_garden_of_eden")

		# ============ CURSE / RISK ============
		"glass_cannon":      _flag("curse_glass_cannon"); _add("curse_dmg_mult", 3.0 * n)
		"all_or_nothing":    _flag("curse_all_or_nothing")
		"no_sunflowers":     _flag("curse_no_sunflowers"); _add("starting_sun", 300)
		"no_wallnuts":       _flag("curse_no_wallnuts"); _mul("all_firerate", 0.6, n)
		"zombie_rush":       _mul("zombie_speed", 1.5, n); _add("seed_mult_bonus", 3.0 * n)
		"glass_jaw":         _mul("zombie_hp", 0.5, n); _add("seed_mult_bonus", 2.0)
		"fast_track":        _mul("wave_interval", 0.5, n); _add("seed_mult_bonus", 2.0 * n)
		"bloodlust":         _flag("curse_bloodlust"); _add("starting_sun", 50)
		"scorched_earth":    _flag("curse_scorched_earth")
		"lone_wolf":         _flag("curse_lone_wolf"); _mul("all_firerate", 0.5, n)

		# ============ PEASHOOTER ============
		"pea_double_shot":   _flag("pea_double_shot")
		"pea_triple_shot":   _flag("pea_triple_shot")
		"pea_quad_shot":     _flag("pea_quad_shot")
		"pea_rapid":         _mul("pea_interval", 0.65, n)
		"pea_turbo":         _mul("pea_interval", 0.50, n)
		"pea_ice":           _flag("pea_ice")
		"pea_fire":          _flag("pea_fire")
		"pea_poison":        _flag("pea_poison")
		"pea_explosive":     _flag("pea_explosive")
		"pea_pierce":        _flag("pea_pierce")
		"pea_bounce":        _flag("pea_bounce")
		"pea_homing":        _flag("pea_homing")
		"pea_giant_5":       _flag("pea_giant_every5")
		"pea_crit_15":       _add("pea_crit_chance", 0.15 * n)
		"pea_crit_30":       _add("pea_crit_chance", 0.30 * n)
		"pea_stun":          _add("pea_stun_chance", 0.10 * n)
		"pea_vampire":       _flag("pea_vampire")
		"pea_multi_lane":    _flag("pea_multi_lane")
		"pea_damage_boost":  _add("pea_damage", 10.0 * n)
		"pea_snipe":         _flag("pea_snipe")
		"pea_barrage":       _flag("pea_barrage")
		"pea_overcharge":    _flag("pea_overcharge")
		"pea_armor_pierce":  _add("pea_armor_pierce", 0.50 * n)
		"pea_acid":          _flag("pea_acid")
		"pea_splitting":     _flag("pea_splitting")

		# ============ SUNFLOWER ============
		"sun_twin":          _flag("sun_twin")
		"sun_triple":        _flag("sun_triple")
		"sun_quad":          _flag("sun_quad")
		"sun_fast":          _mul("sun_interval", 0.70, n)
		"sun_ultra":         _mul("sun_interval", 0.50, n)
		"sun_golden":        _add("plant_sun_value", 15 * n)
		"sun_platinum":      _add("plant_sun_value", 30 * n)
		"sun_heal_aura":     _flag("sun_heal_aura")
		"sun_rain_burst":    _flag("sun_rain_burst")
		"sun_boost_adj":     _flag("sun_boost_adjacent")
		"sun_passive":       _flag("sun_passive_gen")
		"sun_luck":          _add("sun_luck_chance", 0.20 * n)
		"sun_eternal":       _flag("sun_eternal")
		"sun_magnet_plant":  _flag("sun_magnet_plant")
		"sun_harvest_moon":  _flag("sun_harvest_moon")
		"sun_pollen":        _flag("sun_pollen")
		"sun_symbiosis":     _flag("sun_symbiosis")
		"sun_solar_burst":   _flag("sun_solar_burst_on_hit")
		"sun_overgrowth":    _add("plant_sun_value", 50)
		"sun_double_bloom":  _flag("sun_double_bloom")

		# ============ WALL-NUT ============
		"nut_iron":          _mul("nut_hp", 1.50, n)
		"nut_steel":         _mul("nut_hp", 2.00, n)
		"nut_titanium":      _mul("nut_hp", 3.00, n)
		"nut_thorns":        _flag("nut_thorns"); _add("nut_thorn_dps", 15.0 * n)
		"nut_spike":         _add("nut_thorn_dps", 25.0 * n)
		"nut_explode":       _flag("nut_explode_on_death")
		"nut_regen":         _flag("nut_regen"); _add("nut_regen_rate", 20.0 * n)
		"nut_fast_regen":    _add("nut_regen_rate", 40.0 * n)
		"nut_mirror":        _add("nut_reflect_pct", 0.20 * n)
		"nut_sacrifice":     _flag("nut_sacrifice_sun")
		"nut_rally":         _flag("nut_rally")
		"nut_anchor":        _add("nut_eat_speed_reduction", 0.50 * n)
		"nut_spike_ball":    _flag("nut_spike_ball")
		"nut_last_stand":    _flag("nut_last_stand_thorns")
		"nut_shared_pain":   _add("nut_shared_pain_pct", 0.50 * n)
		"nut_respawn":       _flag("nut_respawn_once")
		"nut_magnetic":      _flag("nut_magnetic")
		"nut_crumble":       _flag("nut_crumble_slow")

		# ============ SNOW PEA ============
		"ice_blizzard":      _mul("ice_freeze_dur", 1.50, n)
		"ice_deep_freeze":   _mul("ice_freeze_dur", 2.00, n)
		"ice_shards":        _mul("ice_frozen_dmg", 1.50, n)
		"ice_shatter":       _flag("ice_shatter_instakill")
		"ice_chill_field":   _flag("ice_chill_field")
		"ice_hailstorm":     _flag("ice_hailstorm")
		"ice_arctic_armor":  _mul("ice_hp", 1.50, n)
		"ice_spread":        _flag("ice_freeze_spread")
		"ice_subzero":       _flag("ice_subzero")
		"ice_avalanche":     _flag("ice_avalanche_firstshot")
		"ice_permafrost":    _flag("ice_permafrost")
		"ice_shield":        _add("ice_absorb_shield", 500.0 * n)
		"ice_snowball":      _flag("ice_snowball_grow")
		"ice_winter_wind":   _flag("ice_passive_lane_slow")
		"ice_frost_nova":    _flag("ice_frost_nova_on_death")
		"ice_cold_snap":     _flag("ice_cold_snap")
		"ice_lance":         _flag("ice_periodic_lance")
		"ice_glacier":       _add("ice_lane_slow", 0.20 * n)

		# ============ REPEATER ============
		"rep_six_shooter":   _flag("rep_six_shooter")
		"rep_rapid":         _mul("rep_interval", 0.70, n)
		"rep_turbo":         _mul("rep_interval", 0.55, n)
		"rep_ice":           _flag("rep_ice")
		"rep_explosive":     _flag("rep_explosive")
		"rep_pierce":        _flag("rep_pierce")
		"rep_crit":          _add("rep_crit_chance", 0.20 * n)
		"rep_damage":        _add("rep_damage", 8.0 * n)
		"rep_overheat":      _flag("rep_overheat_burst")
		"rep_bounce":        _flag("rep_bounce")
		"rep_vampire":       _flag("rep_vampire")
		"rep_stagger":       _add("rep_stagger_chance", 0.15 * n)
		"rep_spread":        _flag("rep_spread_shot")
		"rep_suppression":   _flag("rep_suppression")
		"rep_gatling":       _flag("rep_gatling_mode")

		# ============ CHERRY BOMB ============
		"cb_bigger":         _mul("cb_radius", 1.50, n)
		"cb_massive":        _mul("cb_radius", 2.00, n)
		"cb_mega":           _mul("cb_damage", 2.00, n)
		"cb_ultra":          _mul("cb_damage", 3.00, n)
		"cb_chain":          _flag("cb_chain_reaction")
		"cb_fire":           _flag("cb_fire_after")
		"cb_cluster":        _flag("cb_cluster")
		"cb_fuse":           _mul("cb_fuse_time", 0.50, n)
		"cb_double":         _flag("cb_double_plant")
		"cb_emp":            _flag("cb_emp_stun")
		"cb_smoke":          _flag("cb_smoke_blind")
		"cb_shockwave":      _flag("cb_shockwave")
		"cb_ground_zero":    _flag("cb_guaranteed_center_kill")
		"cb_quick_reset":    _mul("cb_cooldown", 0.60, n)
		"cb_hot_pepper":     _flag("cb_persistent_fire")

		# ============ POTATO MINE ============
		"pm_boost":          _mul("pm_damage", 2.00, n)
		"pm_overkill":       _mul("pm_damage", 3.00, n)
		"pm_quick_arm":      _mul("pm_arm_time", 0.50, n)
		"pm_instant_arm":    _flag("pm_instant_arm")
		"pm_triple":         _flag("pm_triple_plant")
		"pm_line":           _flag("pm_landmine_line")
		"pm_frag":           _flag("pm_fragmentation")
		"pm_chain":          _flag("pm_chain_explode")
		"pm_acid":           _flag("pm_acid_pool")
		"pm_gravity":        _flag("pm_gravity_pull")
		"pm_indestructible": _flag("pm_cant_be_eaten")
		"pm_cluster":        _flag("pm_cluster_explode")

		# ============ CHOMPER ============
		"ch_fast_bite":      _mul("ch_eat_speed", 0.60, n)
		"ch_instant_bite":   _flag("ch_instant_eat")
		"ch_big_mouth":      _flag("ch_eat_boss")
		"ch_double_bite":    _flag("ch_double_eat")
		"ch_fast_digest":    _mul("ch_digest_time", 0.60, n)
		"ch_instant_digest": _flag("ch_instant_digest")
		"ch_regurgitate":    _flag("ch_launch_corpse")
		"ch_speed_boost":    _flag("ch_speed_after_eat")
		"ch_nutrient":       _add("ch_hp_per_eat", 50.0 * n)
		"ch_terror":         _add("ch_terror_slow", 0.20 * n)
		"ch_venom":          _flag("ch_venom_puddle")
		"ch_iron_stomach":   _flag("ch_immune_while_eating")
		"ch_rapid_strike":   _flag("ch_instakill_first_bite")
		"ch_pack":           _flag("ch_pack_hunter")
		"ch_frenzy":         _flag("ch_feeding_frenzy")
		"ch_camouflage":     _flag("ch_camouflage")
		"ch_alpha":          _flag("ch_alpha_buff")

func _add(key: String, val: float) -> void:
	bonuses[key] = bonuses.get(key, 0.0) + val

func _mul(key: String, factor: float, n: int) -> void:
	var current := bonuses.get(key + "_mult", 1.0)
	bonuses[key + "_mult"] = current * pow(factor, n)

func _flag(key: String) -> void:
	flags[key] = true
