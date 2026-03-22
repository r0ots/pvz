extends Node
# Persistent meta-progression (survives between runs)

const SAVE_PATH := "user://meta_progress.save"

var seeds: int = 0
var lifetime_seeds: int = 0
var prestige_count: int = 0
var total_runs: int = 0
var wins: int = 0

# Plants unlocked for use
var unlocked_plants: Array = ["Sunflower", "Peashooter", "WallNut"]

# Permanent upgrade levels: { plant_name: { stat: level } }
var plant_upgrades: Dictionary = {}

# Upgrade definitions: max 3 levels each
const UPGRADE_COSTS: Dictionary = {
	"power":    [10, 25, 50],
	"speed":    [10, 25, 50],
	"hp":       [10, 25, 50],
	"cost_red": [15, 35, 70],
}

const UPGRADE_MAX := 3

# Unlock shop entries
const UNLOCK_SHOP: Dictionary = {
	"SnowPea": {"cost": 50, "desc": "Slows zombies it hits"},
}

# Bonus per prestige level
const PRESTIGE_SEED_BONUS := 0.25   # +25% seeds per prestige
const PRESTIGE_ZOMBIE_HP  := 0.20   # +20% zombie HP per prestige

func _ready() -> void:
	_init_upgrades()
	load_data()

func _init_upgrades() -> void:
	for p in ["Sunflower", "Peashooter", "WallNut", "SnowPea"]:
		if not plant_upgrades.has(p):
			plant_upgrades[p] = {"power": 0, "speed": 0, "hp": 0, "cost_red": 0}

# ---- Prestige ----
func prestige_seed_multiplier() -> float:
	return 1.0 + prestige_count * PRESTIGE_SEED_BONUS

func prestige_zombie_hp_multiplier() -> float:
	return 1.0 + prestige_count * PRESTIGE_ZOMBIE_HP

func do_prestige() -> void:
	prestige_count += 1
	save_data()

# ---- Seeds ----
func earn_seeds(amount: int) -> void:
	var earned := int(amount * prestige_seed_multiplier())
	seeds += earned
	lifetime_seeds += earned
	save_data()

func spend_seeds(amount: int) -> bool:
	if seeds < amount:
		return false
	seeds -= amount
	save_data()
	return true

# ---- Upgrades ----
func get_level(plant: String, stat: String) -> int:
	return plant_upgrades.get(plant, {}).get(stat, 0)

func upgrade_cost(plant: String, stat: String) -> int:
	var lvl := get_level(plant, stat)
	if lvl >= UPGRADE_MAX:
		return -1
	return UPGRADE_COSTS[stat][lvl]

func buy_upgrade(plant: String, stat: String) -> bool:
	var cost := upgrade_cost(plant, stat)
	if cost < 0 or not spend_seeds(cost):
		return false
	plant_upgrades[plant][stat] += 1
	save_data()
	return true

# ---- Unlocks ----
func is_unlocked(plant: String) -> bool:
	return plant in unlocked_plants

func unlock_plant(plant: String) -> bool:
	var info := UNLOCK_SHOP.get(plant, {})
	if info.is_empty() or is_unlocked(plant):
		return false
	if not spend_seeds(info["cost"]):
		return false
	unlocked_plants.append(plant)
	save_data()
	return true

# ---- Persistence ----
func save_data() -> void:
	var data := {
		"seeds": seeds,
		"lifetime_seeds": lifetime_seeds,
		"prestige_count": prestige_count,
		"total_runs": total_runs,
		"wins": wins,
		"unlocked_plants": unlocked_plants,
		"plant_upgrades": plant_upgrades,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return
	seeds            = parsed.get("seeds", 0)
	lifetime_seeds   = parsed.get("lifetime_seeds", 0)
	prestige_count   = parsed.get("prestige_count", 0)
	total_runs       = parsed.get("total_runs", 0)
	wins             = parsed.get("wins", 0)
	unlocked_plants  = parsed.get("unlocked_plants", ["Sunflower", "Peashooter", "WallNut"])
	var saved_upgrades = parsed.get("plant_upgrades", {})
	for p in saved_upgrades:
		plant_upgrades[p] = saved_upgrades[p]
	_init_upgrades()

func reset_save() -> void:
	seeds = 0; lifetime_seeds = 0; prestige_count = 0
	total_runs = 0; wins = 0
	unlocked_plants = ["Sunflower", "Peashooter", "WallNut"]
	plant_upgrades = {}
	_init_upgrades()
	save_data()
