extends Zombie
class_name ConeheadZombie

func _init() -> void:
	hp = 560
	max_hp = 560
	speed = 50.0
	damage_per_second = 100.0
	zombie_name = "Conehead Zombie"

func _draw_body() -> void:
	super._draw_body()

	# Draw traffic cone on head
	var walk_offset := 0.0
	if not eating:
		walk_offset = sin(walk_timer * 3.0) * 4.0
	var head_top := Vector2(walk_offset, -44)

	# Cone (triangle)
	var cone_points := PackedVector2Array([
		head_top + Vector2(-14, 0),
		head_top + Vector2(14, 0),
		head_top + Vector2(0, -30),
	])
	draw_colored_polygon(cone_points, Color(0.95, 0.45, 0.05))
	# Cone stripes
	draw_line(head_top + Vector2(-10, -6), head_top + Vector2(10, -6), Color(0.9, 0.9, 0.9, 0.6), 3)
	draw_line(head_top + Vector2(-6, -16), head_top + Vector2(6, -16), Color(0.9, 0.9, 0.9, 0.6), 2)
