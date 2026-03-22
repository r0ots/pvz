extends Plant
class_name WallNut

var wobble: float = 0.0

func _init() -> void:
	hp = 4000
	max_hp = 4000
	cost = 50
	plant_name = "Wall-nut"

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if wobble > 0:
		wobble -= delta * 3.0
	queue_redraw()

func take_damage(amount: int) -> void:
	wobble = 1.0
	super.take_damage(amount)

func _draw() -> void:
	var ratio := float(hp) / float(max_hp)
	var w := sin(wobble * PI) * 4.0

	# Shadow
	draw_ellipse_approx(Vector2(w * 0.5, 38), Vector2(32, 10), Color(0, 0, 0, 0.25))

	# Main nut body - color changes with damage
	var body_color: Color
	if ratio > 0.66:
		body_color = Color(0.85, 0.65, 0.25)
	elif ratio > 0.33:
		body_color = Color(0.75, 0.50, 0.20)
	else:
		body_color = Color(0.60, 0.35, 0.15)

	# Outer body
	draw_circle(Vector2(w, 0), 36.0, Color(body_color.r * 0.7, body_color.g * 0.7, body_color.b * 0.7))
	draw_circle(Vector2(w, 0), 33.0, body_color)

	# Shell texture lines
	draw_arc(Vector2(w, 0), 25.0, -PI * 0.8, PI * 0.8, 20, Color(0.6, 0.4, 0.15, 0.5), 2)
	draw_arc(Vector2(w + 8, -5), 18.0, -PI * 0.6, PI * 0.3, 12, Color(0.6, 0.4, 0.15, 0.4), 2)

	# Cracks based on damage
	if ratio < 0.66:
		draw_line(Vector2(w - 5, -15), Vector2(w + 8, 5), Color(0.35, 0.2, 0.05, 0.8), 2)
	if ratio < 0.33:
		draw_line(Vector2(w + 10, -20), Vector2(w + 15, 10), Color(0.25, 0.12, 0.02, 0.9), 2)
		draw_line(Vector2(w - 12, 0), Vector2(w - 5, 20), Color(0.25, 0.12, 0.02, 0.9), 2)

	# Face
	var face_worry := 1.0 - ratio
	# Eyes (worried)
	draw_circle(Vector2(w - 10, -5), 5.0, Color(0.9, 0.8, 0.6))
	draw_circle(Vector2(w + 10, -5), 5.0, Color(0.9, 0.8, 0.6))
	draw_circle(Vector2(w - 10, -5), 2.5, Color(0.15, 0.08, 0.02))
	draw_circle(Vector2(w + 10, -5), 2.5, Color(0.15, 0.08, 0.02))
	# Eyebrows (angle up in middle = worried)
	draw_line(Vector2(w - 14, -13), Vector2(w - 6, -10 - face_worry * 6), Color(0.15, 0.08, 0.02), 2)
	draw_line(Vector2(w + 14, -13), Vector2(w + 6, -10 - face_worry * 6), Color(0.15, 0.08, 0.02), 2)
	# Mouth
	if ratio > 0.5:
		draw_arc(Vector2(w, 8), 7.0, 0.2, PI - 0.2, 10, Color(0.15, 0.08, 0.02), 2)
	else:
		draw_arc(Vector2(w, 12), 7.0, PI + 0.2, TAU - 0.2, 10, Color(0.15, 0.08, 0.02), 2)

	_draw_health_bar()

# Helper to draw an ellipse approximation using polygon
func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := i * TAU / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
