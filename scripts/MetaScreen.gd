extends Node2D
# Meta-progression screen: upgrade tree, unlocks, prestige, stats

var _hovered_btn: String = ""
var _buttons: Array = []   # Array of {rect, action, label, cost, disabled}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Back button
	var back = Button.new()
	back.text = "← Back"
	back.size = Vector2(120, 40)
	back.position = Vector2(20, 20)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	add_child(back)

	# Reset save button (small, bottom corner)
	var reset_btn = Button.new()
	reset_btn.text = "Reset Save"
	reset_btn.size = Vector2(110, 30)
	reset_btn.position = Vector2(1150, 680)
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.pressed.connect(_on_reset_save)
	add_child(reset_btn)

func _on_reset_save() -> void:
	MetaProgress.reset_save()
	queue_redraw()
	_buttons.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hovered_btn = ""
		for btn in _buttons:
			if btn["rect"].has_point(event.position):
				_hovered_btn = btn["action"]
				break
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for btn in _buttons:
			if btn["rect"].has_point(event.position) and not btn.get("disabled", false):
				_handle_action(btn["action"])
				return

func _handle_action(action: String) -> void:
	if action == "prestige":
		MetaProgress.do_prestige()
	elif action.begins_with("unlock:"):
		var plant := action.substr(7)
		MetaProgress.unlock_plant(plant)
	elif action.begins_with("upgrade:"):
		var parts := action.substr(8).split(":")
		if parts.size() == 2:
			MetaProgress.buy_upgrade(parts[0], parts[1])
	queue_redraw()
	_buttons.clear()

func _draw() -> void:
	_buttons.clear()

	# Background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.12, 0.06))

	# ---- Header ----
	_txt("META PROGRESSION", Vector2(640, 52), 38, Color(1.0, 0.9, 0.1), true)
	_txt("Seeds: %d  |  Lifetime: %d  |  Prestige: %d  |  Runs: %d  |  Wins: %d" %
		[MetaProgress.seeds, MetaProgress.lifetime_seeds,
		 MetaProgress.prestige_count, MetaProgress.total_runs, MetaProgress.wins],
		Vector2(640, 92), 18, Color(0.85, 0.85, 0.85), true)

	# Seed multiplier info
	var mult_pct := int(MetaProgress.prestige_seed_multiplier() * 100)
	_txt("Seed multiplier: %d%%  |  Zombie HP multiplier: %d%%" %
		[mult_pct, int(MetaProgress.prestige_zombie_hp_multiplier() * 100)],
		Vector2(640, 118), 16, Color(0.7, 0.9, 0.7), true)

	var y_start := 150.0

	# ---- Plant Upgrade Grid ----
	_txt("PLANT UPGRADES", Vector2(40, y_start), 22, Color(0.6, 1.0, 0.6))
	_draw_upgrade_table(y_start + 34)

	# ---- Unlock Shop ----
	_txt("UNLOCK SHOP", Vector2(40, 480), 22, Color(0.9, 0.7, 1.0))
	_draw_unlock_shop(510)

	# ---- Prestige ----
	_draw_prestige_section(480)

func _draw_upgrade_table(y: float) -> void:
	var plants_to_show := MetaProgress.unlocked_plants.duplicate()
	# Include locked plants greyed out
	for p in MetaProgress.UNLOCK_SHOP.keys():
		if p not in plants_to_show:
			plants_to_show.append(p)

	var stats  := ["power", "speed", "hp", "cost_red"]
	var labels := ["Power", "Speed", "HP", "Cost↓"]
	var col_w  := 130.0
	var row_h  := 54.0
	var ox     := 40.0

	# Header row
	_txt("Plant", Vector2(ox, y), 15, Color(0.7, 0.7, 0.7))
	for si in range(stats.size()):
		_txt(labels[si], Vector2(ox + 120 + si * col_w + 40, y), 15, Color(0.7, 0.7, 0.7), true)

	for pi in range(plants_to_show.size()):
		var plant: String = plants_to_show[pi]
		var locked := not MetaProgress.is_unlocked(plant)
		var ry := y + 24 + pi * row_h
		var pc := Color(0.7, 0.7, 0.7) if locked else Color(1, 1, 1)
		_txt(plant, Vector2(ox, ry + 14), 16, pc)

		if locked:
			_txt("(locked)", Vector2(ox + 100, ry + 14), 13, Color(0.5, 0.5, 0.5))
			continue

		for si in range(stats.size()):
			var stat: String  = stats[si]
			var level: int    = MetaProgress.get_level(plant, stat)
			var cost: int     = MetaProgress.upgrade_cost(plant, stat)
			var bx := ox + 120 + si * col_w
			var br := Rect2(bx, ry, col_w - 10, row_h - 8)

			# Level dots
			for lv in range(MetaProgress.UPGRADE_MAX):
				var dot_color := Color(0.3, 0.9, 0.3) if lv < level else Color(0.3, 0.3, 0.3)
				draw_circle(Vector2(bx + 8 + lv * 14, ry + 10), 5, dot_color)

			if cost < 0:
				_txt("MAX", Vector2(bx + 10, ry + 26), 14, Color(0.4, 1.0, 0.4))
			else:
				var can_buy := MetaProgress.seeds >= cost
				var btn_color := Color(0.25, 0.45, 0.15) if can_buy else Color(0.2, 0.2, 0.2)
				if _hovered_btn == ("upgrade:%s:%s" % [plant, stat]) and can_buy:
					btn_color = Color(0.4, 0.7, 0.2)
				draw_rect(br, btn_color)
				draw_rect(br, Color(0.5, 0.5, 0.5, 0.5), false, 1)
				_txt("%d☀" % cost, Vector2(br.position.x + br.size.x / 2, br.position.y + 8), 15,
					Color(1.0, 0.9, 0.0) if can_buy else Color(0.5, 0.5, 0.5), true)
				_buttons.append({
					"rect":     br,
					"action":   "upgrade:%s:%s" % [plant, stat],
					"disabled": not can_buy,
				})

func _draw_unlock_shop(y: float) -> void:
	var ox := 40.0
	var xi := 0
	for plant in MetaProgress.UNLOCK_SHOP.keys():
		var info: Dictionary = MetaProgress.UNLOCK_SHOP[plant]
		var cost: int        = info["cost"]
		var desc: String     = info["desc"]
		var already: bool    = MetaProgress.is_unlocked(plant)
		var can_buy: bool    = MetaProgress.seeds >= cost and not already

		var bx := ox + xi * 240.0
		var br := Rect2(bx, y, 220, 70)

		var bg := Color(0.25, 0.15, 0.35) if not already else Color(0.15, 0.35, 0.15)
		if _hovered_btn == ("unlock:" + plant) and can_buy:
			bg = Color(0.4, 0.25, 0.55)
		draw_rect(br, bg)
		draw_rect(br, Color(0.6, 0.4, 0.8, 0.7), false, 1.5)

		_txt(plant, Vector2(bx + 10, y + 8), 18, Color(1, 1, 1))
		_txt(desc,  Vector2(bx + 10, y + 30), 13, Color(0.85, 0.85, 0.85))
		if already:
			_txt("✓ Unlocked", Vector2(bx + 10, y + 50), 14, Color(0.3, 1.0, 0.3))
		else:
			_txt("%d seeds" % cost, Vector2(bx + 10, y + 50), 14,
				Color(1.0, 0.9, 0.0) if can_buy else Color(0.5, 0.5, 0.5))
			_buttons.append({
				"rect":     br,
				"action":   "unlock:" + plant,
				"disabled": not can_buy,
			})
		xi += 1

func _draw_prestige_section(y: float) -> void:
	var ox := 820.0
	_txt("PRESTIGE", Vector2(ox, y), 22, Color(1.0, 0.6, 0.2))
	_txt("Reset run progress for a permanent seed bonus.", Vector2(ox, y + 28), 15, Color(0.85, 0.85, 0.85))
	_txt("Each prestige: +25% seeds, +20% zombie HP.", Vector2(ox, y + 46), 15, Color(0.85, 0.85, 0.85))
	_txt("Current prestige: %d  (×%.2f seeds)" % [MetaProgress.prestige_count, MetaProgress.prestige_seed_multiplier()],
		Vector2(ox, y + 66), 16, Color(1.0, 0.8, 0.4))

	var br := Rect2(ox, y + 100, 200, 50)
	var wins_needed := MetaProgress.prestige_count + 1
	var can_prestige := MetaProgress.wins >= wins_needed
	var bg := Color(0.5, 0.3, 0.05) if can_prestige else Color(0.2, 0.2, 0.2)
	if _hovered_btn == "prestige" and can_prestige:
		bg = Color(0.75, 0.45, 0.1)
	draw_rect(br, bg)
	draw_rect(br, Color(0.85, 0.55, 0.15), false, 2)
	_txt("PRESTIGE", Vector2(ox + 100, y + 116), 20, Color(1.0, 0.85, 0.3), true)
	if not can_prestige:
		_txt("Win %d run(s) first" % wins_needed, Vector2(ox, y + 158), 14, Color(0.6, 0.6, 0.6))
	_buttons.append({
		"rect":     br,
		"action":   "prestige",
		"disabled": not can_prestige,
	})

# ---- Text helper ----
func _txt(text: String, pos: Vector2, size: int, color: Color, centered: bool = false) -> void:
	var draw_pos := pos
	if centered:
		var approx_w := text.length() * size * 0.55
		draw_pos.x -= approx_w / 2
	draw_string(ThemeDB.fallback_font, draw_pos + Vector2(0, size * 0.7),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
