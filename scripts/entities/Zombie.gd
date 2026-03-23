extends Node2D
class_name Zombie

var hp:               int   = 200
var max_hp:           int   = 200
var base_speed:       float = 50.0
var speed:            float = 50.0
var damage_per_sec:   float = 100.0
var dead:             bool  = false
var zombie_name:      String = "Zombie"
var grid_row:         int   = 0

var walk_timer:  float = 0.0
var eating:      bool  = false
var target_plant: Plant = null

var freeze_timer: float = 0.0   # seconds remaining frozen/slowed

signal reached_home

func _ready() -> void:
	# Prestige HP scaling
	hp     = int(hp * MetaProgress.prestige_zombie_hp_multiplier())
	max_hp = hp
	queue_redraw()

func _process(delta: float) -> void:
	walk_timer += delta

	# Handle freeze slow
	if freeze_timer > 0:
		freeze_timer -= delta
		speed = base_speed * 0.4
	else:
		speed = base_speed

	if eating and target_plant != null and not target_plant.dead:
		# Wall-nut thorns damage back
		if target_plant is WallNut:
			var thorn := target_plant.get_thorn_dps()
			if thorn > 0:
				take_damage(int(thorn * delta))
		target_plant.take_damage(int(damage_per_sec * delta))
	else:
		eating = false
		target_plant = null
		position.x -= speed * delta

	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp   = 0
		dead = true
		queue_free()
	queue_redraw()

func apply_freeze(duration: float = 3.0) -> void:
	freeze_timer = max(freeze_timer, duration)

func start_eating(plant: Plant) -> void:
	eating       = true
	target_plant = plant

func stop_eating() -> void:
	eating       = false
	target_plant = null

func _draw() -> void:
	_draw_body()
	_draw_health_bar()

func _draw_body() -> void:
	var walk_offset := 0.0
	if not eating:
		walk_offset = sin(walk_timer * 3.0) * 4.0

	var skin  := Color(0.65, 0.78, 0.55)
	var shirt := Color(0.55, 0.45, 0.35)

	# Freeze tint overlay
	var tint := Color(0.6, 0.8, 1.0, 0.35) if freeze_timer > 0 else Color(0, 0, 0, 0)

	draw_ellipse_approx(Vector2(walk_offset * 0.3, 44), Vector2(20, 6), Color(0, 0, 0, 0.2))

	var leg_sway := sin(walk_timer * 3.0) * 8.0 if not eating else 0.0
	draw_line(Vector2(-6 + walk_offset, 25), Vector2(-10 + leg_sway * 0.5 + walk_offset, 45), Color(0.3, 0.3, 0.3), 7)
	draw_line(Vector2(6 + walk_offset, 25),  Vector2(10 - leg_sway * 0.5 + walk_offset, 45), Color(0.3, 0.3, 0.3), 7)
	draw_rect(Rect2(-16 + leg_sway * 0.5 + walk_offset, 42, 16, 6), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(4 - leg_sway * 0.5 + walk_offset, 42, 16, 6),   Color(0.2, 0.2, 0.2))

	draw_rect(Rect2(-14 + walk_offset, 0, 28, 28), shirt.lerp(Color(0.5, 0.6, 0.9), tint.a))
	draw_line(Vector2(-14 + walk_offset, 20), Vector2(-8 + walk_offset, 28), Color(0.35, 0.28, 0.22), 2)
	draw_line(Vector2(5 + walk_offset, 18),   Vector2(14 + walk_offset, 24), Color(0.35, 0.28, 0.22), 2)

	var arm_y := -2 + sin(walk_timer * 5.0) * 3.0 if eating else 10.0
	draw_line(Vector2(-14 + walk_offset, 10), Vector2(-32 + walk_offset, arm_y),      skin, 7)
	draw_line(Vector2(-32 + walk_offset, arm_y), Vector2(-48 + walk_offset, arm_y - 5), skin, 6)
	draw_line(Vector2(14 + walk_offset, 10),  Vector2(26 + walk_offset, 18), skin, 6)

	draw_rect(Rect2(-5 + walk_offset, -14, 10, 16), skin.lerp(Color(0.6, 0.8, 1.0), tint.a))

	var head_pos := Vector2(walk_offset, -28)
	draw_rect(Rect2(head_pos.x - 16, head_pos.y - 16, 32, 32), skin.lerp(Color(0.6, 0.8, 1.0), tint.a))
	draw_rect(Rect2(head_pos.x - 16, head_pos.y - 18, 32, 8), Color(0.25, 0.15, 0.05))
	draw_rect(Rect2(head_pos.x - 14, head_pos.y - 22, 8, 8),  Color(0.25, 0.15, 0.05))
	draw_rect(Rect2(head_pos.x + 2,  head_pos.y - 24, 6, 8),  Color(0.25, 0.15, 0.05))

	draw_rect(Rect2(head_pos.x - 12, head_pos.y - 10, 8, 6), Color(0.9, 0.8, 0.8))
	draw_rect(Rect2(head_pos.x + 4,  head_pos.y - 10, 8, 6), Color(0.9, 0.8, 0.8))
	draw_circle(head_pos + Vector2(-8, -7), 2.5, Color(0.8, 0.1, 0.1))
	draw_circle(head_pos + Vector2(8, -7),  2.5, Color(0.8, 0.1, 0.1))

	var mouth_open := abs(sin(walk_timer * 4.0)) * 4.0 if eating else 2.0
	draw_rect(Rect2(head_pos.x - 8, head_pos.y + 2, 16, 4 + mouth_open), Color(0.2, 0.05, 0.05))
	for i in range(3):
		draw_rect(Rect2(head_pos.x - 6 + i * 5, head_pos.y + 2, 4, 3), Color(0.95, 0.95, 0.9))

	# Ice crystals when frozen
	if freeze_timer > 0:
		for i in range(5):
			var a := i * TAU / 5.0
			var cr := Vector2(walk_offset + cos(a) * 22, -10 + sin(a) * 28)
			draw_circle(cr, 5, Color(0.6, 0.85, 1.0, 0.65))

func _draw_health_bar() -> void:
	var bw := 50.0; var bh := 6.0
	var bx := -bw / 2; var by := -62.0
	var r  := float(hp) / float(max_hp)
	draw_rect(Rect2(bx, by, bw, bh), Color(0.2, 0.0, 0.0, 0.8))
	var fc := Color(0.1, 0.9, 0.1) if r > 0.5 else (Color(1.0, 0.8, 0.0) if r > 0.25 else Color(1.0, 0.1, 0.1))
	draw_rect(Rect2(bx, by, bw * r, bh), fc)
	draw_rect(Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.8), false, 1.5)

func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := i * TAU / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
