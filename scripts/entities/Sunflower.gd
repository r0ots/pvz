extends Plant
class_name Sunflower

const SUN_INTERVAL := 24.0
const SUN_VALUE := 25

var sun_timer: float = SUN_INTERVAL * 0.5  # first sun sooner
var bob_timer: float = 0.0

func _init() -> void:
	hp = 300
	max_hp = 300
	cost = 50
	plant_name = "Sunflower"

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	bob_timer += delta
	sun_timer -= delta
	queue_redraw()

func should_produce_sun() -> bool:
	if sun_timer <= 0:
		sun_timer = SUN_INTERVAL
		return true
	return false

func _draw() -> void:
	var bob := sin(bob_timer * 1.8) * 3.0

	# Stem
	draw_line(Vector2(0, 10 + bob), Vector2(0, 45), Color(0.15, 0.55, 0.05), 6)

	# Leaves
	draw_circle(Vector2(-18, 28), 10, Color(0.2, 0.65, 0.1))
	draw_circle(Vector2(18, 35), 9, Color(0.2, 0.65, 0.1))

	# Petals (8 petals)
	var flower_center := Vector2(0, bob)
	for i in range(8):
		var angle := i * PI / 4.0 + bob_timer * 0.3
		var petal_pos := flower_center + Vector2(cos(angle), sin(angle)) * 22.0
		draw_circle(petal_pos, 9.0, Color(1.0, 0.85, 0.0))

	# Flower center (brown)
	draw_circle(flower_center, 16.0, Color(0.45, 0.22, 0.02))

	# Eyes
	draw_circle(flower_center + Vector2(-5, -3), 4.0, Color(1, 1, 1))
	draw_circle(flower_center + Vector2(5, -3), 4.0, Color(1, 1, 1))
	draw_circle(flower_center + Vector2(-5, -3), 2.0, Color(0.1, 0.05, 0.0))
	draw_circle(flower_center + Vector2(5, -3), 2.0, Color(0.1, 0.05, 0.0))

	# Smile
	draw_arc(flower_center + Vector2(0, 3), 5.0, 0.2, PI - 0.2, 10, Color(0.1, 0.05, 0.0), 2)

	_draw_health_bar()

	# Sun production indicator
	var ratio := 1.0 - (sun_timer / SUN_INTERVAL)
	if ratio > 0.0:
		draw_arc(flower_center, 20.0, -PI / 2, -PI / 2 + TAU * ratio, 24, Color(1.0, 0.9, 0.0, 0.6), 3)
