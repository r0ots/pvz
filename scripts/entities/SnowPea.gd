extends Plant
class_name SnowPea

const BASE_SHOOT_INTERVAL := 1.5

var shoot_timer: float = BASE_SHOOT_INTERVAL
var shoot_anim: float  = 0.0
var bob_timer: float   = 0.0

signal shoot_pea(row: int, x: float, y: float, frozen: bool)

func _init() -> void:
	hp   = 300
	max_hp = 300
	cost = 175
	plant_name = "SnowPea"

func _ready() -> void:
	# Meta upgrades
	var spd_lvl := MetaProgress.get_level("SnowPea", "speed")
	shoot_timer = BASE_SHOOT_INTERVAL * RunState.sunflower_interval_mult  # reuse — or just hardcode
	shoot_timer = BASE_SHOOT_INTERVAL - spd_lvl * 0.15

	var hp_lvl := MetaProgress.get_level("SnowPea", "hp")
	hp     = int(hp * (1.0 + hp_lvl * 0.2) * RunState.plant_hp_mult)
	max_hp = hp

	queue_redraw()

func _process(delta: float) -> void:
	bob_timer  += delta
	shoot_anim  = max(0.0, shoot_anim - delta * 4.0)
	shoot_timer -= delta
	queue_redraw()

func try_shoot() -> bool:
	if shoot_timer <= 0:
		shoot_timer = BASE_SHOOT_INTERVAL
		shoot_anim  = 1.0
		return true
	return false

func _draw() -> void:
	var bob    := sin(bob_timer * 2.0) * 2.0
	var recoil := shoot_anim * 5.0

	# Ice-blue body
	draw_circle(Vector2(0, 10 + bob), 28.0, Color(0.1, 0.4, 0.7))
	draw_circle(Vector2(0, 5 + bob), 22.0, Color(0.2, 0.55, 0.9))
	var head_pos := Vector2(0, -8 + bob)
	draw_circle(head_pos, 22.0, Color(0.15, 0.5, 0.85))

	# Snowflake / frost details
	for i in range(6):
		var a := i * PI / 3.0
		draw_line(head_pos, head_pos + Vector2(cos(a), sin(a)) * 10, Color(0.7, 0.9, 1.0, 0.5), 1)

	# Eyes
	draw_circle(head_pos + Vector2(-7, -4), 5.0, Color(1, 1, 1))
	draw_circle(head_pos + Vector2(7, -4), 5.0, Color(1, 1, 1))
	draw_circle(head_pos + Vector2(-7, -4), 2.5, Color(0.05, 0.1, 0.4))
	draw_circle(head_pos + Vector2(7, -4), 2.5, Color(0.05, 0.1, 0.4))

	# Ice barrel
	var b_start := head_pos + Vector2(18 - recoil, 2)
	var b_end   := head_pos + Vector2(48 - recoil, 2)
	draw_line(b_start, b_end, Color(0.1, 0.3, 0.6), 10)
	draw_circle(b_end, 6.0, Color(0.3, 0.6, 0.9))
	if shoot_anim > 0.5:
		draw_circle(b_end, 10.0, Color(0.5, 0.8, 1.0, shoot_anim - 0.5))

	_draw_health_bar()

	var ratio := 1.0 - (shoot_timer / BASE_SHOOT_INTERVAL)
	if ratio > 0.0 and ratio < 1.0:
		draw_arc(head_pos, 26.0, -PI / 2, -PI / 2 + TAU * ratio, 24, Color(0.4, 0.7, 1.0, 0.6), 3)
