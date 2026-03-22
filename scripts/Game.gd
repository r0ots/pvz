extends Node2D

# =========================================================
#  PLANTS vs ZOMBIES - Game Controller
# =========================================================

# --- Grid ---
const GRID_COLS     := 9
const GRID_ROWS     := 5
const CELL_W        := 100
const CELL_H        := 100
const GRID_X        := 170   # left edge of grid
const GRID_Y        := 130   # top edge of grid

# --- Gameplay ---
const INITIAL_SUN        := 150
const SUN_DROP_INTERVAL  := 10.0
const TOTAL_WAVES        := 5
const ZOMBIES_PER_WAVE   := 4

# Plant data [name, cost, color_hint]
const PLANT_TYPES := ["Sunflower", "Peashooter", "WallNut"]
const PLANT_COSTS := {"Sunflower": 50, "Peashooter": 100, "WallNut": 50}

# Row center Y positions
var ROW_Y: Array = []

# =========================================================
#  STATE
# =========================================================
var sun: int = INITIAL_SUN
var grid: Array = []            # grid[row][col] = Plant or null
var plants: Array = []
var zombies: Array = []
var projectiles: Array = []
var suns_on_field: Array = []

var selected_plant: String = ""
var selected_card_idx: int = -1
var game_active: bool = true
var victory: bool = false

var sun_drop_timer: float = 8.0
var wave_timer: float = 20.0
var waves_spawned: int = 0
var zombies_killed: int = 0
var total_zombies: int = 0

# =========================================================
#  NODE LAYERS
# =========================================================
var plant_layer:  Node2D
var zombie_layer: Node2D
var proj_layer:   Node2D
var sun_layer:    Node2D
var ui_layer:     CanvasLayer

# UI refs
var sun_label:    Label
var wave_label:   Label
var card_panels:  Array = []   # ColorRect per card
var hover_cell:   Vector2i = Vector2i(-1, -1)
var end_panel:    Control

# Scripts (loaded as resources)
var SunScript       = preload("res://scripts/entities/Sun.gd")
var PeaScript       = preload("res://scripts/entities/Pea.gd")
var SunflowerScript = preload("res://scripts/entities/Sunflower.gd")
var PeashooterScript= preload("res://scripts/entities/Peashooter.gd")
var WallNutScript   = preload("res://scripts/entities/WallNut.gd")
var ZombieScript    = preload("res://scripts/entities/Zombie.gd")
var ConeheadScript  = preload("res://scripts/entities/ConeheadZombie.gd")

# =========================================================
#  INIT
# =========================================================
func _ready() -> void:
	# Pre-compute row centers
	for row in range(GRID_ROWS):
		ROW_Y.append(GRID_Y + row * CELL_H + CELL_H / 2)

	# Init grid
	for row in range(GRID_ROWS):
		grid.append([])
		for _col in range(GRID_COLS):
			grid[row].append(null)

	_build_scene()

func _build_scene() -> void:
	# Layers (z-order)
	var bg_layer = Node2D.new()
	bg_layer.z_index = -20
	add_child(bg_layer)

	plant_layer = Node2D.new()
	plant_layer.z_index = 0
	add_child(plant_layer)

	zombie_layer = Node2D.new()
	zombie_layer.z_index = 5
	add_child(zombie_layer)

	proj_layer = Node2D.new()
	proj_layer.z_index = 10
	add_child(proj_layer)

	sun_layer = Node2D.new()
	sun_layer.z_index = 15
	add_child(sun_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	_build_ui()
	queue_redraw()

# =========================================================
#  UI
# =========================================================
func _build_ui() -> void:
	# Top bar background
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.12, 0.22, 0.05, 0.95)
	top_bar.size = Vector2(1280, 120)
	top_bar.position = Vector2(0, 0)
	ui_layer.add_child(top_bar)

	# Sun icon + counter
	var sun_icon_label = Label.new()
	sun_icon_label.text = "☀"
	sun_icon_label.add_theme_font_size_override("font_size", 42)
	sun_icon_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	sun_icon_label.position = Vector2(8, 36)
	ui_layer.add_child(sun_icon_label)

	sun_label = Label.new()
	sun_label.text = str(sun)
	sun_label.add_theme_font_size_override("font_size", 30)
	sun_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	sun_label.size = Vector2(80, 40)
	sun_label.position = Vector2(54, 44)
	ui_layer.add_child(sun_label)

	# Wave counter
	wave_label = Label.new()
	wave_label.text = "Wave: 0 / %d" % TOTAL_WAVES
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	wave_label.position = Vector2(1050, 48)
	wave_label.size = Vector2(220, 30)
	ui_layer.add_child(wave_label)

	# Plant cards
	var card_start_x := 140
	for i in range(PLANT_TYPES.size()):
		var ptype := PLANT_TYPES[i]
		var cost  := PLANT_COSTS[ptype]

		var card = ColorRect.new()
		card.size = Vector2(80, 100)
		card.position = Vector2(card_start_x + i * 92, 10)
		card.color = Color(0.25, 0.45, 0.15)
		ui_layer.add_child(card)
		card_panels.append(card)

		var name_lbl = Label.new()
		name_lbl.text = _short_name(ptype)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(80, 20)
		name_lbl.position = Vector2(card_start_x + i * 92, 12)
		ui_layer.add_child(name_lbl)

		var cost_lbl = Label.new()
		cost_lbl.text = str(cost) + "☀"
		cost_lbl.add_theme_font_size_override("font_size", 16)
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.size = Vector2(80, 24)
		cost_lbl.position = Vector2(card_start_x + i * 92, 84)
		ui_layer.add_child(cost_lbl)

	# Shovel (deselect) button
	var shovel = Button.new()
	shovel.text = "🌿 Deselect"
	shovel.size = Vector2(110, 40)
	shovel.position = Vector2(442, 40)
	shovel.add_theme_font_size_override("font_size", 14)
	shovel.pressed.connect(_deselect_plant)
	ui_layer.add_child(shovel)

	# End panel (hidden until game over/win)
	end_panel = Control.new()
	end_panel.visible = false
	end_panel.size = Vector2(600, 300)
	end_panel.position = Vector2(340, 210)
	ui_layer.add_child(end_panel)

	var end_bg = ColorRect.new()
	end_bg.color = Color(0, 0, 0, 0.8)
	end_bg.size = Vector2(600, 300)
	end_panel.add_child(end_bg)

	var end_label = Label.new()
	end_label.name = "EndLabel"
	end_label.text = ""
	end_label.add_theme_font_size_override("font_size", 56)
	end_label.add_theme_color_override("font_color", Color(1, 1, 0))
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.size = Vector2(600, 100)
	end_label.position = Vector2(0, 60)
	end_panel.add_child(end_label)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.size = Vector2(200, 55)
	menu_btn.position = Vector2(200, 200)
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.pressed.connect(_go_to_menu)
	end_panel.add_child(menu_btn)

# =========================================================
#  DRAW (background / grid)
# =========================================================
func _draw() -> void:
	_draw_sky()
	_draw_grid()
	_draw_hover()

func _draw_sky() -> void:
	# Sky gradient (sky -> horizon)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.53, 0.81, 0.98))
	# Ground strip
	draw_rect(Rect2(0, GRID_Y - 10, 1280, GRID_ROWS * CELL_H + 20), Color(0.55, 0.38, 0.18))
	# Home strip (left)
	draw_rect(Rect2(0, GRID_Y - 10, GRID_X, GRID_ROWS * CELL_H + 20), Color(0.45, 0.30, 0.12))
	# Right side (zombie approach)
	draw_rect(Rect2(GRID_X + GRID_COLS * CELL_W, GRID_Y - 10, 1280, GRID_ROWS * CELL_H + 20), Color(0.45, 0.30, 0.12))

func _draw_grid() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var x := GRID_X + col * CELL_W
			var y := GRID_Y + row * CELL_H
			var light := (row + col) % 2 == 0
			var grass_color := Color(0.38, 0.65, 0.18) if light else Color(0.32, 0.58, 0.14)
			draw_rect(Rect2(x, y, CELL_W, CELL_H), grass_color)
			# Grid lines
			draw_rect(Rect2(x, y, CELL_W, CELL_H), Color(0, 0, 0, 0.08), false, 1)

func _draw_hover() -> void:
	if hover_cell.x >= 0 and hover_cell.y >= 0 and selected_plant != "":
		var x := GRID_X + hover_cell.x * CELL_W
		var y := GRID_Y + hover_cell.y * CELL_H
		var can_place := grid[hover_cell.y][hover_cell.x] == null and sun >= PLANT_COSTS.get(selected_plant, 0)
		var hint_color := Color(0.2, 1.0, 0.2, 0.35) if can_place else Color(1.0, 0.2, 0.2, 0.35)
		draw_rect(Rect2(x, y, CELL_W, CELL_H), hint_color)

# =========================================================
#  INPUT
# =========================================================
func _input(event: InputEvent) -> void:
	if not game_active:
		return

	if event is InputEventMouseMotion:
		hover_cell = _world_to_grid(event.position)
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := event.position
		_handle_click(pos)

func _handle_click(pos: Vector2) -> void:
	# Check sun collection first
	for sun_node in suns_on_field.duplicate():
		if sun_node != null and not sun_node.collected:
			if sun_node.try_collect(pos):
				_add_sun(Sun.VALUE)
				suns_on_field.erase(sun_node)
				return

	# Check plant card click
	var card_start_x := 140
	for i in range(PLANT_TYPES.size()):
		var cx := card_start_x + i * 92
		var card_rect := Rect2(cx, 10, 80, 100)
		if card_rect.has_point(pos):
			_select_card(i)
			return

	# Click on grid
	var cell := _world_to_grid(pos)
	if cell.x >= 0:
		_try_place_plant(cell)

func _select_card(idx: int) -> void:
	if selected_card_idx == idx:
		_deselect_plant()
		return
	selected_card_idx = idx
	selected_plant = PLANT_TYPES[idx]
	_update_card_visuals()

func _deselect_plant() -> void:
	selected_card_idx = -1
	selected_plant = ""
	_update_card_visuals()

func _update_card_visuals() -> void:
	for i in range(card_panels.size()):
		var ptype := PLANT_TYPES[i]
		var cost  := PLANT_COSTS[ptype]
		var can_afford := sun >= cost
		if i == selected_card_idx:
			card_panels[i].color = Color(0.6, 0.85, 0.3)
		elif not can_afford:
			card_panels[i].color = Color(0.2, 0.2, 0.2)
		else:
			card_panels[i].color = Color(0.25, 0.45, 0.15)

# =========================================================
#  PLANT PLACEMENT
# =========================================================
func _try_place_plant(cell: Vector2i) -> void:
	if selected_plant == "":
		return
	var cost := PLANT_COSTS.get(selected_plant, 0)
	if sun < cost:
		return
	if grid[cell.y][cell.x] != null:
		return

	var plant := _create_plant(selected_plant)
	if plant == null:
		return

	plant.grid_row = cell.y
	plant.grid_col = cell.x
	plant.position = _grid_to_world(cell)
	plant_layer.add_child(plant)
	grid[cell.y][cell.x] = plant
	plants.append(plant)

	_spend_sun(cost)
	_deselect_plant()

func _create_plant(ptype: String) -> Plant:
	match ptype:
		"Sunflower":
			var p = Node2D.new()
			p.set_script(SunflowerScript)
			return p
		"Peashooter":
			var p = Node2D.new()
			p.set_script(PeashooterScript)
			return p
		"WallNut":
			var p = Node2D.new()
			p.set_script(WallNutScript)
			return p
	return null

# =========================================================
#  GAME LOOP
# =========================================================
func _process(delta: float) -> void:
	if not game_active:
		return

	_process_sun_drop(delta)
	_process_waves(delta)
	_process_plants(delta)
	_process_zombies(delta)
	_process_projectiles(delta)
	_check_collisions()
	_cleanup_dead()
	_check_game_over()
	_update_card_visuals()
	queue_redraw()

func _process_sun_drop(delta: float) -> void:
	sun_drop_timer -= delta
	if sun_drop_timer <= 0:
		sun_drop_timer = SUN_DROP_INTERVAL
		_spawn_sky_sun()

func _process_waves(delta: float) -> void:
	wave_timer -= delta
	if wave_timer <= 0 and waves_spawned < TOTAL_WAVES:
		wave_timer = 25.0
		_spawn_wave()

func _process_plants(delta: float) -> void:
	for plant in plants.duplicate():
		if not is_instance_valid(plant) or plant.dead:
			continue
		# Sunflower sun production
		if plant is Sunflower:
			if plant.should_produce_sun():
				_spawn_plant_sun(plant.global_position)
		# Peashooter shooting
		elif plant is Peashooter:
			var row := plant.grid_row
			if _zombie_in_row(row) and plant.try_shoot():
				_spawn_pea(row, plant.global_position.x + 55, plant.global_position.y - 6)

func _process_zombies(delta: float) -> void:
	for zombie in zombies.duplicate():
		if not is_instance_valid(zombie) or zombie.dead:
			continue
		# Check if zombie has reached home
		if zombie.position.x <= GRID_X - 20:
			_trigger_game_over()
			return
		# Check if zombie is eating a plant
		if not zombie.eating:
			var blocking := _plant_at_zombie(zombie)
			if blocking != null:
				zombie.start_eating(blocking)

func _process_projectiles(_delta: float) -> void:
	pass  # Peas move themselves

# =========================================================
#  COLLISION
# =========================================================
func _check_collisions() -> void:
	for pea in projectiles.duplicate():
		if not is_instance_valid(pea) or pea.dead:
			continue
		for zombie in zombies.duplicate():
			if not is_instance_valid(zombie) or zombie.dead:
				continue
			if _pea_hits_zombie(pea, zombie):
				zombie.take_damage(Pea.DAMAGE)
				if zombie.dead:
					zombies_killed += 1
				pea.dead = true
				pea.queue_free()
				break

func _pea_hits_zombie(pea: Pea, zombie: Zombie) -> bool:
	# Same row check (y proximity)
	if abs(pea.global_position.y - zombie.global_position.y) > 55:
		return false
	# X overlap
	if pea.global_position.x >= zombie.global_position.x - 30 and \
	   pea.global_position.x <= zombie.global_position.x + 30:
		return true
	return false

# =========================================================
#  HELPERS
# =========================================================
func _zombie_in_row(row: int) -> bool:
	for zombie in zombies:
		if not is_instance_valid(zombie) or zombie.dead:
			continue
		if zombie.grid_row == row and zombie.position.x < GRID_X + GRID_COLS * CELL_W + 50:
			return true
	return false

func _plant_at_zombie(zombie: Zombie) -> Plant:
	var zx := zombie.global_position.x
	var zy := zombie.global_position.y
	for plant in plants:
		if not is_instance_valid(plant) or plant.dead:
			continue
		var px := plant.global_position.x
		var py := plant.global_position.y
		if abs(py - zy) < 40 and zx <= px + 40 and zx >= px - 60:
			return plant
	return null

func _world_to_grid(pos: Vector2) -> Vector2i:
	var col := int((pos.x - GRID_X) / CELL_W)
	var row := int((pos.y - GRID_Y) / CELL_H)
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		GRID_X + cell.x * CELL_W + CELL_W / 2,
		GRID_Y + cell.y * CELL_H + CELL_H / 2
	)

func _short_name(ptype: String) -> String:
	match ptype:
		"Sunflower":  return "Sunflower"
		"Peashooter": return "Peashooter"
		"WallNut":    return "Wall-nut"
	return ptype

# =========================================================
#  SPAWNING
# =========================================================
func _spawn_sky_sun() -> void:
	var sun_node = Node2D.new()
	sun_node.set_script(SunScript)
	var rand_x := randf_range(GRID_X + 50, GRID_X + GRID_COLS * CELL_W - 50)
	sun_node.position = Vector2(rand_x, 130)
	sun_node.target_y = randf_range(160, 550)
	sun_node.falling = true
	sun_layer.add_child(sun_node)
	suns_on_field.append(sun_node)

func _spawn_plant_sun(from_pos: Vector2) -> void:
	var sun_node = Node2D.new()
	sun_node.set_script(SunScript)
	sun_node.position = from_pos + Vector2(randf_range(-20, 20), -30)
	sun_node.target_y = from_pos.y + randf_range(30, 80)
	sun_node.falling = true
	sun_layer.add_child(sun_node)
	suns_on_field.append(sun_node)

func _spawn_pea(row: int, x: float, y: float) -> void:
	var pea = Node2D.new()
	pea.set_script(PeaScript)
	pea.position = Vector2(x, y)
	proj_layer.add_child(pea)
	projectiles.append(pea)

func _spawn_wave() -> void:
	waves_spawned += 1
	wave_label.text = "Wave: %d / %d" % [waves_spawned, TOTAL_WAVES]

	var count := ZOMBIES_PER_WAVE + waves_spawned
	total_zombies += count

	# Shuffle rows for variety
	var rows := range(GRID_ROWS)
	rows.shuffle()

	for i in range(count):
		var row := rows[i % rows.size()]
		var use_conehead := waves_spawned >= 2 and randf() < 0.4

		var zombie_node = Node2D.new()
		if use_conehead:
			zombie_node.set_script(ConeheadScript)
		else:
			zombie_node.set_script(ZombieScript)

		zombie_node.position = Vector2(1340 + i * 80, ROW_Y[row])
		zombie_node.grid_row = row
		zombie_layer.add_child(zombie_node)
		zombies.append(zombie_node)

# =========================================================
#  SUN ECONOMY
# =========================================================
func _add_sun(amount: int) -> void:
	sun += amount
	sun_label.text = str(sun)

func _spend_sun(amount: int) -> void:
	sun -= amount
	sun_label.text = str(sun)

# =========================================================
#  CLEANUP
# =========================================================
func _cleanup_dead() -> void:
	plants = plants.filter(func(p): return is_instance_valid(p) and not p.dead)
	zombies = zombies.filter(func(z): return is_instance_valid(z) and not z.dead)
	projectiles = projectiles.filter(func(p): return is_instance_valid(p) and not p.dead)
	suns_on_field = suns_on_field.filter(func(s): return is_instance_valid(s) and not s.collected)

	# Sync grid
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var p = grid[row][col]
			if p != null and (not is_instance_valid(p) or p.dead):
				grid[row][col] = null

# =========================================================
#  WIN / LOSE
# =========================================================
func _check_game_over() -> void:
	if waves_spawned >= TOTAL_WAVES and zombies.filter(func(z): return is_instance_valid(z)).is_empty():
		_trigger_victory()

func _trigger_game_over() -> void:
	if not game_active:
		return
	game_active = false
	var lbl: Label = end_panel.get_node("EndLabel")
	lbl.text = "GAME OVER"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	end_panel.visible = true

func _trigger_victory() -> void:
	if not game_active:
		return
	game_active = false
	victory = true
	var lbl: Label = end_panel.get_node("EndLabel")
	lbl.text = "YOU WIN!"
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	end_panel.visible = true

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
