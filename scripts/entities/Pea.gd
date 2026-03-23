extends Node2D
class_name Pea

const BASE_SPEED := 400.0
const RADIUS     := 10.0
const BASE_DAMAGE := 20

var speed:  float = BASE_SPEED
var damage: int   = BASE_DAMAGE
var frozen: bool  = false   # if true, slows zombies on hit
var dead:   bool  = false

func _ready() -> void:
	speed  += RunState.proj_speed_bonus
	damage  = int(BASE_DAMAGE + MetaProgress.get_level("Peashooter", "power") * 5)
	queue_redraw()

func _process(delta: float) -> void:
	position.x += speed * delta
	if position.x > 1400:
		dead = true
		queue_free()

func _draw() -> void:
	if frozen:
		# Ice pea — blue/white
		draw_circle(Vector2.ZERO, RADIUS + 4, Color(0.5, 0.8, 1.0, 0.3))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.35, 0.65, 1.0))
		draw_circle(Vector2(-3, -3), 3, Color(0.8, 0.95, 1.0, 0.9))
		# Snowflake hint
		for i in range(4):
			var a := i * PI / 4.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * RADIUS * 0.7, Color(1, 1, 1, 0.5), 1)
	else:
		draw_circle(Vector2.ZERO, RADIUS + 3, Color(0.2, 0.8, 0.2, 0.4))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.15, 0.75, 0.1))
		draw_circle(Vector2(-3, -3), 3, Color(0.5, 1.0, 0.4, 0.8))
