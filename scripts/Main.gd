extends Node2D

# Main menu with meta-progression stats

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.6, 0.1); bg.size = Vector2(1280, 720)
	add_child(bg)

	# Dark panel
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55); panel.size = Vector2(620, 460)
	panel.position = Vector2(330, 130)
	add_child(panel)

	# Title
	var title := Label.new()
	title.text = "PLANTS vs ZOMBIES"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(620, 80); title.position = Vector2(330, 158)
	add_child(title)

	var sub := Label.new(); sub.text = "Roguelike Edition"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(620, 36); sub.position = Vector2(330, 222)
	add_child(sub)

	# Meta stats
	var stats_txt := "Seeds: %d  |  Prestige: %d  |  Wins: %d  |  Runs: %d" % [
		MetaProgress.seeds, MetaProgress.prestige_count,
		MetaProgress.wins, MetaProgress.total_runs]
	var stats_lbl := Label.new(); stats_lbl.text = stats_txt
	stats_lbl.add_theme_font_size_override("font_size", 17)
	stats_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.size = Vector2(620, 30); stats_lbl.position = Vector2(330, 275)
	add_child(stats_lbl)

	# Unlocked plants
	var unlocked_txt := "Plants: " + ", ".join(MetaProgress.unlocked_plants)
	var unlocked_lbl := Label.new(); unlocked_lbl.text = unlocked_txt
	unlocked_lbl.add_theme_font_size_override("font_size", 16)
	unlocked_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	unlocked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlocked_lbl.size = Vector2(620, 28); unlocked_lbl.position = Vector2(330, 308)
	add_child(unlocked_lbl)

	# Hint
	var hint := Label.new()
	hint.text = "Pick upgrades between waves.\nEarn seeds to permanently upgrade plants."
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(580, 56); hint.position = Vector2(350, 348)
	add_child(hint)

	# Start button
	var start := Button.new(); start.text = "▶  START GAME"
	start.add_theme_font_size_override("font_size", 28)
	start.size = Vector2(240, 58); start.position = Vector2(400, 424)
	start.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	add_child(start)

	# Upgrades button
	var upgrades := Button.new(); upgrades.text = "🌱 UPGRADES"
	upgrades.add_theme_font_size_override("font_size", 20)
	upgrades.size = Vector2(200, 46); upgrades.position = Vector2(176, 432)
	upgrades.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MetaScreen.tscn"))
	add_child(upgrades)

	queue_redraw()

func _draw() -> void:
	_draw_deco_sunflower(Vector2(80, 360), 40)
	_draw_deco_sunflower(Vector2(1200, 360), 40)
	_draw_deco_sunflower(Vector2(130, 510), 28)
	_draw_deco_sunflower(Vector2(1150, 510), 28)

func _draw_deco_sunflower(pos: Vector2, size: float) -> void:
	draw_line(pos + Vector2(0, size), pos + Vector2(0, size * 3), Color(0.2, 0.6, 0.1), 5)
	for i in range(8):
		var a := i * PI / 4
		draw_circle(pos + Vector2(cos(a), sin(a)) * size * 0.85, size * 0.32, Color(1.0, 0.85, 0.0))
	draw_circle(pos, size * 0.45, Color(0.5, 0.25, 0.0))
	draw_circle(pos + Vector2(-size * 0.15, -size * 0.1), size * 0.1, Color(1, 1, 1))
	draw_circle(pos + Vector2(size * 0.15, -size * 0.1), size * 0.1, Color(1, 1, 1))
