extends Node2D
class_name Plant

# Base class for all plants

var hp: int = 300
var max_hp: int = 300
var cost: int = 100
var plant_name: String = "Plant"
var dead: bool = false
var grid_row: int = 0
var grid_col: int = 0

func _ready() -> void:
	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0
		dead = true
		queue_free()
	queue_redraw()

func _draw_health_bar() -> void:
	var bar_w := 70.0
	var bar_h := 7.0
	var bar_x := -bar_w / 2
	var bar_y := -52.0
	var ratio := float(hp) / float(max_hp)
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.0, 0.0, 0.8))
	# Health fill
	var fill_color := Color(0.1, 0.9, 0.1) if ratio > 0.5 else (Color(1.0, 0.8, 0.0) if ratio > 0.25 else Color(1.0, 0.1, 0.1))
	draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), fill_color)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0, 0, 0, 0.8), false, 1.5)
