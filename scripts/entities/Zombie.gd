extends Node2D
class_name Zombie

var hp: int = 200
var max_hp: int = 200
var speed: float = 50.0
var damage_per_second: float = 100.0
var dead: bool = false
var zombie_name: String = "Zombie"
var grid_row: int = 0

var walk_timer: float = 0.0
var eating: bool = false
var target_plant: Plant = null
var groan_timer: float = 0.0

signal reached_home

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	walk_timer += delta
	groan_timer += delta

	if eating and target_plant != null and not target_plant.dead:
		# Eat the plant
		target_plant.take_damage(int(damage_per_second * delta))
	else:
		eating = false
		target_plant = null
		if not eating:
			position.x -= speed * delta

	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		dead = true
		queue_free()
	queue_redraw()

func start_eating(plant: Plant) -> void:
	eating = true
	target_plant = plant

func stop_eating() -> void:
	eating = false
	target_plant = null

func _draw() -> void:
	_draw_body()
	_draw_health_bar()

func _draw_body() -> void:
	var walk_offset := 0.0
	if not eating:
		walk_offset = sin(walk_timer * 3.0) * 4.0

	var skin_color := Color(0.65, 0.78, 0.55)
	var shirt_color := Color(0.55, 0.45, 0.35)

	# Shadow
	draw_ellipse_approx(Vector2(walk_offset * 0.3, 44), Vector2(20, 6), Color(0, 0, 0, 0.2))

	# Legs
	var leg_sway := sin(walk_timer * 3.0) * 8.0 if not eating else 0.0
	draw_line(Vector2(-6 + walk_offset, 25), Vector2(-10 + leg_sway * 0.5 + walk_offset, 45), Color(0.3, 0.3, 0.3), 7)
	draw_line(Vector2(6 + walk_offset, 25), Vector2(10 - leg_sway * 0.5 + walk_offset, 45), Color(0.3, 0.3, 0.3), 7)
	# Feet
	draw_rect(Rect2(-16 + leg_sway * 0.5 + walk_offset, 42, 16, 6), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(4 - leg_sway * 0.5 + walk_offset, 42, 16, 6), Color(0.2, 0.2, 0.2))

	# Body / torso
	draw_rect(Rect2(-14 + walk_offset, 0, 28, 28), shirt_color)
	# Torn shirt details
	draw_line(Vector2(-14 + walk_offset, 20), Vector2(-8 + walk_offset, 28), Color(0.35, 0.28, 0.22), 2)
	draw_line(Vector2(5 + walk_offset, 18), Vector2(14 + walk_offset, 24), Color(0.35, 0.28, 0.22), 2)

	# Outstretched arm (eating animation)
	var arm_y := -2 + sin(walk_timer * 5.0) * 3.0 if eating else 10.0
	draw_line(Vector2(-14 + walk_offset, 10), Vector2(-32 + walk_offset, arm_y), skin_color, 7)
	draw_line(Vector2(-32 + walk_offset, arm_y), Vector2(-48 + walk_offset, arm_y - 5), skin_color, 6)

	# Back arm
	draw_line(Vector2(14 + walk_offset, 10), Vector2(26 + walk_offset, 18), skin_color, 6)

	# Neck
	draw_rect(Rect2(-5 + walk_offset, -14, 10, 16), skin_color)

	# Head
	var head_pos := Vector2(walk_offset, -28)
	draw_rect(Rect2(head_pos.x - 16, head_pos.y - 16, 32, 32), skin_color)

	# Hair (messy)
	draw_rect(Rect2(head_pos.x - 16, head_pos.y - 18, 32, 8), Color(0.25, 0.15, 0.05))
	draw_rect(Rect2(head_pos.x - 14, head_pos.y - 22, 8, 8), Color(0.25, 0.15, 0.05))
	draw_rect(Rect2(head_pos.x + 2, head_pos.y - 24, 6, 8), Color(0.25, 0.15, 0.05))

	# Eyes (white with red)
	draw_rect(Rect2(head_pos.x - 12, head_pos.y - 10, 8, 6), Color(0.9, 0.8, 0.8))
	draw_rect(Rect2(head_pos.x + 4, head_pos.y - 10, 8, 6), Color(0.9, 0.8, 0.8))
	draw_circle(head_pos + Vector2(-8, -7), 2.5, Color(0.8, 0.1, 0.1))
	draw_circle(head_pos + Vector2(8, -7), 2.5, Color(0.8, 0.1, 0.1))

	# Mouth (gaping)
	var mouth_open := abs(sin(walk_timer * 4.0)) * 4.0 if eating else 2.0
	draw_rect(Rect2(head_pos.x - 8, head_pos.y + 2, 16, 4 + mouth_open), Color(0.2, 0.05, 0.05))
	# Teeth
	for i in range(3):
		draw_rect(Rect2(head_pos.x - 6 + i * 5, head_pos.y + 2, 4, 3), Color(0.95, 0.95, 0.9))

func _draw_health_bar() -> void:
	var bar_w := 50.0
	var bar_h := 6.0
	var bar_x := -bar_w / 2
	var bar_y := -52.0
	var ratio := float(hp) / float(max_hp)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.0, 0.0, 0.8))
	var fill_color := Color(0.1, 0.9, 0.1) if ratio > 0.5 else (Color(1.0, 0.8, 0.0) if ratio > 0.25 else Color(1.0, 0.1, 0.1))
	draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), fill_color)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0, 0, 0, 0.8), false, 1.5)

func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := i * TAU / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
