extends Plant
class_name Peashooter

const BASE_INTERVAL := 1.5

var shoot_interval: float = BASE_INTERVAL
var shoot_timer:    float = BASE_INTERVAL
var shoot_anim:     float = 0.0
var bob_timer:      float = 0.0
var double_shot:    bool  = false
var freeze_peas:    bool  = false

func _init() -> void:
	hp     = 300
	max_hp = 300
	cost   = 100
	plant_name = "Peashooter"

func _ready() -> void:
	var spd_lvl := MetaProgress.get_level("Peashooter", "speed")
	var hp_lvl  := MetaProgress.get_level("Peashooter", "hp")
	var cost_lvl:= MetaProgress.get_level("Peashooter", "cost_red")

	shoot_interval = (BASE_INTERVAL - spd_lvl * 0.15)
	if RunState.peashooter_rapid_fire:
		shoot_interval *= 0.65
	shoot_timer = shoot_interval

	hp     = int(hp * (1.0 + hp_lvl * 0.2) * RunState.plant_hp_mult)
	max_hp = hp

	double_shot = RunState.peashooter_double_shot
	freeze_peas = RunState.peashooter_freeze

	queue_redraw()

func _process(delta: float) -> void:
	bob_timer  += delta
	shoot_anim  = max(0.0, shoot_anim - delta * 4.0)
	shoot_timer -= delta
	queue_redraw()

func try_shoot() -> bool:
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		shoot_anim  = 1.0
		return true
	return false

func _draw() -> void:
	var bob    := sin(bob_timer * 2.0) * 2.0
	var recoil := shoot_anim * 5.0

	draw_circle(Vector2(0, 10 + bob), 28.0, Color(0.15, 0.65, 0.1))
	draw_circle(Vector2(0, 5 + bob),  22.0, Color(0.2, 0.75, 0.15))
	var hp_pos := Vector2(0, -8 + bob)
	draw_circle(hp_pos, 22.0, Color(0.18, 0.70, 0.12))

	draw_circle(hp_pos + Vector2(-7, -4), 5.0, Color(1, 1, 1))
	draw_circle(hp_pos + Vector2(7, -4),  5.0, Color(1, 1, 1))
	draw_circle(hp_pos + Vector2(-7, -4), 2.5, Color(0.1, 0.1, 0.1))
	draw_circle(hp_pos + Vector2(7, -4),  2.5, Color(0.1, 0.1, 0.1))

	var barrel_color := Color(0.1, 0.3, 0.6) if freeze_peas else Color(0.1, 0.45, 0.05)
	var tip_color    := Color(0.3, 0.6, 0.9) if freeze_peas else Color(0.08, 0.35, 0.04)

	# Double shot: two barrels
	if double_shot:
		var b1s := hp_pos + Vector2(18 - recoil, -3)
		var b1e := hp_pos + Vector2(48 - recoil, -3)
		draw_line(b1s, b1e, barrel_color, 8)
		draw_circle(b1e, 5.0, tip_color)
		var b2s := hp_pos + Vector2(18 - recoil, 7)
		var b2e := hp_pos + Vector2(48 - recoil, 7)
		draw_line(b2s, b2e, barrel_color, 8)
		draw_circle(b2e, 5.0, tip_color)
	else:
		var b_start := hp_pos + Vector2(18 - recoil, 2)
		var b_end   := hp_pos + Vector2(48 - recoil, 2)
		draw_line(b_start, b_end, barrel_color, 10)
		draw_circle(b_end, 6.0, tip_color)
		if shoot_anim > 0.5:
			var glow_c := Color(0.5, 0.8, 1.0, shoot_anim - 0.5) if freeze_peas else Color(0.3, 1.0, 0.2, shoot_anim - 0.5)
			draw_circle(b_end, 8.0, glow_c)

	_draw_health_bar()

	var ratio := 1.0 - (shoot_timer / shoot_interval)
	if ratio > 0.0 and ratio < 1.0:
		draw_arc(hp_pos, 26.0, -PI / 2, -PI / 2 + TAU * ratio, 24, Color(0.5, 1.0, 0.3, 0.5), 3)
