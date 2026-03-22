extends Node2D
class_name Pea

const SPEED := 400.0
const RADIUS := 10.0
const DAMAGE := 20

var dead: bool = false

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	position.x += SPEED * delta
	if position.x > 1400:
		dead = true
		queue_free()

func _draw() -> void:
	# Outer glow
	draw_circle(Vector2.ZERO, RADIUS + 3, Color(0.2, 0.8, 0.2, 0.4))
	# Main pea
	draw_circle(Vector2.ZERO, RADIUS, Color(0.15, 0.75, 0.1))
	# Highlight
	draw_circle(Vector2(-3, -3), 3, Color(0.5, 1.0, 0.4, 0.8))
