extends Plant
class_name WallNut

const BASE_HP     := 4000
const THORN_DPS   := 15.0

var wobble:  float = 0.0
var thorns:  bool  = false

func _init() -> void:
	hp     = BASE_HP
	max_hp = BASE_HP
	cost   = 50
	plant_name = "WallNut"

func _ready() -> void:
	var hp_lvl  := MetaProgress.get_level("WallNut", "hp")
	var thorn_active := RunState.wallnut_thorns

	hp = int(BASE_HP * (1.0 + hp_lvl * 0.2) * RunState.plant_hp_mult * RunState.wallnut_hp_mult)
	max_hp = hp
	thorns = thorn_active
	queue_redraw()

func _process(delta: float) -> void:
	wobble = max(0.0, wobble - delta * 3.0)
	queue_redraw()

func take_damage(amount: int) -> void:
	wobble = 1.0
	super.take_damage(amount)

func get_thorn_dps() -> float:
	if not thorns:
		return 0.0
	return THORN_DPS * (1.0 + MetaProgress.get_level("WallNut", "power") * 0.3)

func _draw() -> void:
	var ratio := float(hp) / float(max_hp)
	var w     := sin(wobble * PI) * 4.0

	draw_ellipse_approx(Vector2(w * 0.5, 38), Vector2(32, 10), Color(0, 0, 0, 0.25))

	var body_color: Color
	if   ratio > 0.66: body_color = Color(0.85, 0.65, 0.25)
	elif ratio > 0.33: body_color = Color(0.75, 0.50, 0.20)
	else:              body_color = Color(0.60, 0.35, 0.15)

	draw_circle(Vector2(w, 0), 36.0, Color(body_color.r * 0.7, body_color.g * 0.7, body_color.b * 0.7))
	draw_circle(Vector2(w, 0), 33.0, body_color)

	# Thorn spikes around edge
	if thorns:
		for i in range(10):
			var a := i * TAU / 10.0
			var inner := Vector2(w, 0) + Vector2(cos(a), sin(a)) * 33
			var outer := Vector2(w, 0) + Vector2(cos(a), sin(a)) * 42
			draw_line(inner, outer, Color(0.3, 0.6, 0.1), 3)

	draw_arc(Vector2(w, 0),     25.0, -PI * 0.8, PI * 0.8, 20, Color(0.6, 0.4, 0.15, 0.5), 2)
	draw_arc(Vector2(w + 8, -5), 18.0, -PI * 0.6, PI * 0.3, 12, Color(0.6, 0.4, 0.15, 0.4), 2)

	if ratio < 0.66:
		draw_line(Vector2(w - 5, -15), Vector2(w + 8, 5),   Color(0.35, 0.2, 0.05, 0.8), 2)
	if ratio < 0.33:
		draw_line(Vector2(w + 10, -20), Vector2(w + 15, 10), Color(0.25, 0.12, 0.02, 0.9), 2)
		draw_line(Vector2(w - 12, 0),   Vector2(w - 5, 20),  Color(0.25, 0.12, 0.02, 0.9), 2)

	var face_worry := 1.0 - ratio
	draw_circle(Vector2(w - 10, -5), 5.0, Color(0.9, 0.8, 0.6))
	draw_circle(Vector2(w + 10, -5), 5.0, Color(0.9, 0.8, 0.6))
	draw_circle(Vector2(w - 10, -5), 2.5, Color(0.15, 0.08, 0.02))
	draw_circle(Vector2(w + 10, -5), 2.5, Color(0.15, 0.08, 0.02))
	draw_line(Vector2(w - 14, -13), Vector2(w - 6, -10 - face_worry * 6), Color(0.15, 0.08, 0.02), 2)
	draw_line(Vector2(w + 14, -13), Vector2(w + 6, -10 - face_worry * 6), Color(0.15, 0.08, 0.02), 2)
	if ratio > 0.5:
		draw_arc(Vector2(w, 8),  7.0, 0.2, PI - 0.2, 10, Color(0.15, 0.08, 0.02), 2)
	else:
		draw_arc(Vector2(w, 12), 7.0, PI + 0.2, TAU - 0.2, 10, Color(0.15, 0.08, 0.02), 2)

	_draw_health_bar()

func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := i * TAU / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
