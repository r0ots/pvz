extends Plant
class_name Sunflower

const BASE_SUN_INTERVAL := 24.0
const BASE_SUN_VALUE    := 25

var sun_interval: float = BASE_SUN_INTERVAL
var sun_value:    int   = BASE_SUN_VALUE
var sun_timer:    float = 0.0
var double_sun:   bool  = false
var bob_timer:    float = 0.0

func _init() -> void:
	hp     = 300
	max_hp = 300
	cost   = 50
	plant_name = "Sunflower"

func _ready() -> void:
	# Meta upgrades
	var spd_lvl := MetaProgress.get_level("Sunflower", "speed")
	var pwr_lvl := MetaProgress.get_level("Sunflower", "power")
	var hp_lvl  := MetaProgress.get_level("Sunflower", "hp")

	sun_interval = (BASE_SUN_INTERVAL - spd_lvl * 3.0) * RunState.sunflower_interval_mult
	sun_value    = BASE_SUN_VALUE + pwr_lvl * 5
	hp           = int(hp * (1.0 + hp_lvl * 0.2) * RunState.plant_hp_mult)
	max_hp       = hp
	sun_timer    = sun_interval * 0.5  # first sun sooner

	double_sun = RunState.sunflower_double_sun
	queue_redraw()

func _process(delta: float) -> void:
	bob_timer += delta
	sun_timer -= delta
	queue_redraw()

func should_produce_sun() -> bool:
	if sun_timer <= 0:
		sun_timer = sun_interval
		return true
	return false

func _draw() -> void:
	var bob := sin(bob_timer * 1.8) * 3.0

	# Stem
	draw_line(Vector2(0, 10 + bob), Vector2(0, 45), Color(0.15, 0.55, 0.05), 6)
	# Leaves
	draw_circle(Vector2(-18, 28), 10, Color(0.2, 0.65, 0.1))
	draw_circle(Vector2(18, 35),   9, Color(0.2, 0.65, 0.1))

	# Petals
	var fc := Vector2(0, bob)
	for i in range(8):
		var angle := i * PI / 4.0 + bob_timer * 0.3
		draw_circle(fc + Vector2(cos(angle), sin(angle)) * 22.0, 9.0, Color(1.0, 0.85, 0.0))

	# Center
	draw_circle(fc, 16.0, Color(0.45, 0.22, 0.02))

	# Eyes
	draw_circle(fc + Vector2(-5, -3), 4.0, Color(1, 1, 1))
	draw_circle(fc + Vector2(5, -3),  4.0, Color(1, 1, 1))
	draw_circle(fc + Vector2(-5, -3), 2.0, Color(0.1, 0.05, 0.0))
	draw_circle(fc + Vector2(5, -3),  2.0, Color(0.1, 0.05, 0.0))
	draw_arc(fc + Vector2(0, 3), 5.0, 0.2, PI - 0.2, 10, Color(0.1, 0.05, 0.0), 2)

	# Twin sun indicator
	if double_sun:
		draw_circle(fc + Vector2(28, -28), 8, Color(1.0, 0.9, 0.0, 0.8))
		draw_circle(fc + Vector2(38, -28), 8, Color(1.0, 0.9, 0.0, 0.8))

	_draw_health_bar()

	# Production timer arc
	var ratio := 1.0 - (sun_timer / sun_interval)
	if ratio > 0.0:
		draw_arc(fc, 20.0, -PI / 2, -PI / 2 + TAU * ratio, 24, Color(1.0, 0.9, 0.0, 0.6), 3)
