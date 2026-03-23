extends RefCounted
# Static perk definitions — not a singleton, just data helpers

const ALL_PERKS: Array = [
	# --- GLOBAL ---
	{
		"id":          "cheap_plants",
		"name":        "Budget Gardening",
		"desc":        "All plants cost 20% less sun.",
		"flavor":      "Work smarter, not harder.",
		"type":        "global",
		"max_stacks":  2,
		"color":       Color(0.95, 0.85, 0.2),
		"icon":        "💰",
	},
	{
		"id":          "hardy_plants",
		"name":        "Reinforced Roots",
		"desc":        "All plants have 25% more HP.",
		"flavor":      "What doesn't kill them makes them stronger.",
		"type":        "global",
		"max_stacks":  2,
		"color":       Color(0.3, 0.8, 0.3),
		"icon":        "🛡",
	},
	{
		"id":          "rich_sun",
		"name":        "Golden Sun",
		"desc":        "Each sun collected gives +10 bonus sun.",
		"flavor":      "Every ray counts.",
		"type":        "global",
		"max_stacks":  3,
		"color":       Color(1.0, 0.75, 0.0),
		"icon":        "☀",
	},
	{
		"id":          "fast_sun",
		"name":        "Solar Wind",
		"desc":        "Sky sun drops 25% more often.",
		"flavor":      "The sun shines brighter today.",
		"type":        "global",
		"max_stacks":  2,
		"color":       Color(1.0, 0.92, 0.4),
		"icon":        "⚡",
	},
	{
		"id":          "swift_peas",
		"name":        "Bullet Train",
		"desc":        "Projectiles move 30% faster.",
		"flavor":      "Peas of lightning.",
		"type":        "global",
		"max_stacks":  2,
		"color":       Color(0.4, 0.9, 0.4),
		"icon":        "💨",
	},
	# --- PEASHOOTER ---
	{
		"id":          "double_shot",
		"name":        "Double Barrel",
		"desc":        "Peashooter fires 2 peas at once.",
		"flavor":      "Two is better than one.",
		"type":        "plant",
		"target":      "Peashooter",
		"max_stacks":  1,
		"color":       Color(0.2, 0.75, 0.2),
		"icon":        "🌿",
	},
	{
		"id":          "rapid_fire",
		"name":        "Rapid Fire",
		"desc":        "Peashooter fires 35% faster.",
		"flavor":      "Who needs a cool-down?",
		"type":        "plant",
		"target":      "Peashooter",
		"max_stacks":  1,
		"color":       Color(0.3, 0.9, 0.3),
		"icon":        "🔫",
	},
	{
		"id":          "frozen_peas",
		"name":        "Ice Peas",
		"desc":        "Peashooter peas slow zombies by 50%.",
		"flavor":      "Chilling.",
		"type":        "plant",
		"target":      "Peashooter",
		"max_stacks":  1,
		"color":       Color(0.4, 0.7, 1.0),
		"icon":        "❄",
	},
	# --- SUNFLOWER ---
	{
		"id":          "solar_flare",
		"name":        "Solar Flare",
		"desc":        "Sunflower produces sun 30% faster.",
		"flavor":      "Maximum photosynthesis.",
		"type":        "plant",
		"target":      "Sunflower",
		"max_stacks":  1,
		"color":       Color(1.0, 0.85, 0.0),
		"icon":        "🌻",
	},
	{
		"id":          "twin_sun",
		"name":        "Twin Sunflower",
		"desc":        "Sunflower produces 2 suns at a time.",
		"flavor":      "Double the sunshine.",
		"type":        "plant",
		"target":      "Sunflower",
		"max_stacks":  1,
		"color":       Color(1.0, 0.9, 0.2),
		"icon":        "🌞",
	},
	# --- WALL-NUT ---
	{
		"id":          "iron_nut",
		"name":        "Iron Nut",
		"desc":        "Wall-nut has 50% more HP.",
		"flavor":      "Almost indestructible.",
		"type":        "plant",
		"target":      "WallNut",
		"max_stacks":  2,
		"color":       Color(0.7, 0.5, 0.2),
		"icon":        "🥜",
	},
	{
		"id":          "thorns",
		"name":        "Thorny Shell",
		"desc":        "Wall-nut damages zombies that eat it (15 dmg/s).",
		"flavor":      "Bite back.",
		"type":        "plant",
		"target":      "WallNut",
		"max_stacks":  1,
		"color":       Color(0.6, 0.35, 0.1),
		"icon":        "🌵",
	},
]

static func get_available(exclude_maxed: bool = true) -> Array:
	var result := []
	for perk in ALL_PERKS:
		var pid: String = perk["id"]
		var max_s: int  = perk["max_stacks"]
		if exclude_maxed and RunState.stack_count(pid) >= max_s:
			continue
		# Hide plant-specific perks if that plant type isn't unlocked
		if perk["type"] == "plant":
			if not MetaProgress.is_unlocked(perk["target"]):
				continue
		result.append(perk)
	return result

static func get_random_draft(count: int = 3) -> Array:
	var pool := get_available()
	pool.shuffle()
	var picks := []
	for i in range(min(count, pool.size())):
		picks.append(pool[i])
	# Pad with random repeats if pool is small
	while picks.size() < count and not ALL_PERKS.is_empty():
		picks.append(ALL_PERKS[randi() % ALL_PERKS.size()])
	return picks
