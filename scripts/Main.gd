extends Node2D

# === Main Menu ===

var title_label: Label
var start_button: Button
var bg: ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Sky background
	bg = ColorRect.new()
	bg.color = Color(0.2, 0.6, 0.1)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Dark overlay panel
	var panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.size = Vector2(600, 400)
	panel.position = Vector2(340, 160)
	add_child(panel)

	# Title
	title_label = Label.new()
	title_label.text = "PLANTS vs ZOMBIES"
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size = Vector2(600, 80)
	title_label.position = Vector2(340, 210)
	add_child(title_label)

	var subtitle = Label.new()
	subtitle.text = "Godot 4 Clone"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(600, 40)
	subtitle.position = Vector2(340, 290)
	add_child(subtitle)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Click plant cards to select, then click lawn to place.\nCollect sun by clicking it. Defend your home!"
	instructions.add_theme_font_size_override("font_size", 17)
	instructions.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.size = Vector2(560, 80)
	instructions.position = Vector2(360, 360)
	add_child(instructions)

	# Start button
	start_button = Button.new()
	start_button.text = "START GAME"
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.size = Vector2(260, 60)
	start_button.position = Vector2(510, 460)
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	# Decorative plants drawn on the side
	queue_redraw()

func _draw() -> void:
	# Draw some decorative sunflowers on the sides
	_draw_sunflower(Vector2(80, 360), 40)
	_draw_sunflower(Vector2(1200, 360), 40)
	_draw_sunflower(Vector2(130, 500), 30)
	_draw_sunflower(Vector2(1150, 500), 30)

func _draw_sunflower(pos: Vector2, size: float) -> void:
	# Stem
	draw_line(pos + Vector2(0, size), pos + Vector2(0, size * 3), Color(0.2, 0.6, 0.1), 5)
	# Petals
	for i in range(8):
		var angle = i * PI / 4
		var petal_pos = pos + Vector2(cos(angle), sin(angle)) * size * 0.85
		draw_circle(petal_pos, size * 0.32, Color(1.0, 0.85, 0.0))
	# Center
	draw_circle(pos, size * 0.45, Color(0.5, 0.25, 0.0))
	# Face
	draw_circle(pos + Vector2(-size * 0.15, -size * 0.1), size * 0.1, Color(1, 1, 1))
	draw_circle(pos + Vector2(size * 0.15, -size * 0.1), size * 0.1, Color(1, 1, 1))

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
