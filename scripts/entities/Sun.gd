extends Node2D
class_name Sun

signal collected(amount: int)

const RADIUS := 22.0
const VALUE := 25
const FALL_SPEED := 80.0
const LIFETIME := 10.0  # disappears after this many seconds

var target_y: float = 0.0
var falling: bool = true
var lifetime_timer: float = LIFETIME
var bob_timer: float = 0.0
var collected: bool = false

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if collected:
		return

	if falling:
		position.y += FALL_SPEED * delta
		if position.y >= target_y:
			position.y = target_y
			falling = false
	else:
		lifetime_timer -= delta
		bob_timer += delta
		# Gentle bobbing
		position.y = target_y + sin(bob_timer * 2.0) * 3.0
		if lifetime_timer <= 0:
			queue_free()

	queue_redraw()

func _draw() -> void:
	# Glow
	draw_circle(Vector2.ZERO, RADIUS + 6, Color(1.0, 1.0, 0.0, 0.25))
	# Rays
	for i in range(8):
		var angle = bob_timer * 1.5 + i * PI / 4
		var inner = Vector2(cos(angle), sin(angle)) * (RADIUS + 2)
		var outer = Vector2(cos(angle), sin(angle)) * (RADIUS + 12)
		draw_line(inner, outer, Color(1.0, 0.9, 0.0, 0.7), 3)
	# Main circle
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.85, 0.0))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(0.9, 0.6, 0.0), 2)
	# Face
	draw_circle(Vector2(-7, -5), 4, Color(0.3, 0.15, 0.0))
	draw_circle(Vector2(7, -5), 4, Color(0.3, 0.15, 0.0))
	# Smile
	draw_arc(Vector2(0, 2), 8, 0.2, PI - 0.2, 12, Color(0.3, 0.15, 0.0), 2)

func try_collect(click_pos: Vector2) -> bool:
	if collected:
		return false
	if global_position.distance_to(click_pos) <= RADIUS + 8:
		collected = true
		queue_free()
		return true
	return false
