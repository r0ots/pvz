extends Plant
class_name Peashooter

const SHOOT_INTERVAL := 1.5

var shoot_timer: float = SHOOT_INTERVAL
var shoot_anim: float = 0.0
var bob_timer: float = 0.0

signal shoot_pea(row: int, x: float, y: float)

func _init() -> void:
	hp = 300
	max_hp = 300
	cost = 100
	plant_name = "Peashooter"

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	bob_timer += delta
	if shoot_anim > 0:
		shoot_anim -= delta * 4.0

	shoot_timer -= delta
	queue_redraw()

func try_shoot() -> bool:
	if shoot_timer <= 0:
		shoot_timer = SHOOT_INTERVAL
		shoot_anim = 1.0
		return true
	return false

func _draw() -> void:
	var bob := sin(bob_timer * 2.0) * 2.0
	var recoil := shoot_anim * 5.0

	# Body (green mound)
	draw_circle(Vector2(0, 10 + bob), 28.0, Color(0.15, 0.65, 0.1))
	draw_circle(Vector2(0, 5 + bob), 22.0, Color(0.2, 0.75, 0.15))

	# Head
	var head_pos := Vector2(0, -8 + bob)
	draw_circle(head_pos, 22.0, Color(0.18, 0.70, 0.12))

	# Eyes
	draw_circle(head_pos + Vector2(-7, -4), 5.0, Color(1, 1, 1))
	draw_circle(head_pos + Vector2(7, -4), 5.0, Color(1, 1, 1))
	draw_circle(head_pos + Vector2(-7, -4), 2.5, Color(0.1, 0.1, 0.1))
	draw_circle(head_pos + Vector2(7, -4), 2.5, Color(0.1, 0.1, 0.1))

	# Barrel / mouth tube
	var barrel_start := head_pos + Vector2(18 - recoil, 2)
	var barrel_end := head_pos + Vector2(48 - recoil, 2)
	draw_line(barrel_start, barrel_end, Color(0.1, 0.45, 0.05), 10)
	draw_circle(barrel_end, 6.0, Color(0.08, 0.35, 0.04))

	# Mouth opening glow when shooting
	if shoot_anim > 0.5:
		draw_circle(barrel_end, 8.0, Color(0.3, 1.0, 0.2, shoot_anim - 0.5))

	_draw_health_bar()

	# Shoot cooldown arc
	var ratio := 1.0 - (shoot_timer / SHOOT_INTERVAL)
	if ratio > 0.0 and ratio < 1.0:
		draw_arc(head_pos, 26.0, -PI / 2, -PI / 2 + TAU * ratio, 24, Color(0.5, 1.0, 0.3, 0.5), 3)
