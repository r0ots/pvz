extends Node2D

# =========================================================
#  PLANTS vs ZOMBIES — Game Controller (Roguelike + Incremental)
# =========================================================

const GRID_COLS     := 9
const GRID_ROWS     := 5
const CELL_W        := 100
const CELL_H        := 100
const GRID_X        := 170
const GRID_Y        := 130

const INITIAL_SUN        := 150
const SUN_DROP_BASE      := 10.0
const TOTAL_WAVES        := 5
const ZOMBIES_PER_WAVE   := 4

# Seeds awarded
const SEEDS_PER_KILL  := 2
const SEEDS_PER_WAVE  := 10
const SEEDS_WIN_BONUS := 50

var ROW_Y: Array = []

# =========================================================
#  STATE
# =========================================================
var sun: int = INITIAL_SUN
var grid: Array = []
var plants: Array = []
var zombies: Array = []
var projectiles: Array = []
var suns_on_field: Array = []

var selected_plant: String = ""
var selected_card_idx: int = -1
var game_active: bool = true
var victory: bool = false
var drafting: bool = false

var sun_drop_timer: float = 8.0
var wave_timer: float = 20.0
var waves_spawned: int = 0
var zombies_killed: int = 0
var seeds_this_run: int = 0
var hover_cell: Vector2i = Vector2i(-1, -1)

# =========================================================
#  LAYERS / UI
# =========================================================
var plant_layer:  Node2D
var zombie_layer: Node2D
var proj_layer:   Node2D
var sun_layer:    Node2D
var ui_layer:     CanvasLayer

var sun_label:    Label
var wave_label:   Label
var seeds_label:  Label
var perks_label:  Label
var card_panels:  Array = []
var end_panel:    Control

# Preloaded scripts
var SunScript       = preload("res://scripts/entities/Sun.gd")
var PeaScript       = preload("res://scripts/entities/Pea.gd")
var SunflowerScript = preload("res://scripts/entities/Sunflower.gd")
var PeashooterScript= preload("res://scripts/entities/Peashooter.gd")
var WallNutScript   = preload("res://scripts/entities/WallNut.gd")
var SnowPeaScript   = preload("res://scripts/entities/SnowPea.gd")
var ZombieScript    = preload("res://scripts/entities/Zombie.gd")
var ConeheadScript  = preload("res://scripts/entities/ConeheadZombie.gd")
var DraftScript     = preload("res://scripts/DraftScreen.gd")

# =========================================================
#  INIT
# =========================================================
func _ready() -> void:
	RunState.reset()
	MetaProgress.total_runs += 1
	MetaProgress.save_data()

	for row in range(GRID_ROWS):
		ROW_Y.append(GRID_Y + row * CELL_H + CELL_H / 2)

	for row in range(GRID_ROWS):
		grid.append([])
		for _c in range(GRID_COLS):
			grid[row].append(null)

	_build_scene()

func _build_scene() -> void:
	var bg_layer := Node2D.new()
	bg_layer.z_index = -20
	add_child(bg_layer)

	plant_layer  = Node2D.new(); plant_layer.z_index  = 0;  add_child(plant_layer)
	zombie_layer = Node2D.new(); zombie_layer.z_index = 5;  add_child(zombie_layer)
	proj_layer   = Node2D.new(); proj_layer.z_index   = 10; add_child(proj_layer)
	sun_layer    = Node2D.new(); sun_layer.z_index     = 15; add_child(sun_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	_build_ui()
	queue_redraw()

# =========================================================
#  UI
# =========================================================
func _build_ui() -> void:
	var top_bar := ColorRect.new()
	top_bar.color    = Color(0.10, 0.18, 0.04, 0.96)
	top_bar.size     = Vector2(1280, 120)
	top_bar.position = Vector2.ZERO
	ui_layer.add_child(top_bar)

	# Sun icon + count
	var si := Label.new(); si.text = "☀"; si.add_theme_font_size_override("font_size", 42)
	si.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0)); si.position = Vector2(8, 36)
	ui_layer.add_child(si)

	sun_label = Label.new(); sun_label.text = str(sun)
	sun_label.add_theme_font_size_override("font_size", 30)
	sun_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	sun_label.size = Vector2(80, 40); sun_label.position = Vector2(54, 44)
	ui_layer.add_child(sun_label)

	# Seeds display
	seeds_label = Label.new(); seeds_label.text = "🌱 0"
	seeds_label.add_theme_font_size_override("font_size", 18)
	seeds_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	seeds_label.position = Vector2(8, 90)
	ui_layer.add_child(seeds_label)

	# Wave label
	wave_label = Label.new(); wave_label.text = "Wave: 0/%d" % TOTAL_WAVES
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	wave_label.position = Vector2(1040, 48); wave_label.size = Vector2(230, 30)
	ui_layer.add_child(wave_label)

	# Active perks mini-display
	perks_label = Label.new(); perks_label.text = ""
	perks_label.add_theme_font_size_override("font_size", 13)
	perks_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	perks_label.position = Vector2(1040, 76); perks_label.size = Vector2(230, 40)
	ui_layer.add_child(perks_label)

	# Plant cards
	var available := MetaProgress.unlocked_plants
	var cx := 140
	for i in range(available.size()):
		var ptype := available[i]
		var cost  := _get_plant_cost(ptype)

		var card := ColorRect.new()
		card.size     = Vector2(80, 100)
		card.position = Vector2(cx + i * 92, 10)
		card.color    = Color(0.25, 0.45, 0.15)
		ui_layer.add_child(card)
		card_panels.append(card)

		var nl := Label.new(); nl.text = _short_name(ptype)
		nl.add_theme_font_size_override("font_size", 12)
		nl.add_theme_color_override("font_color", Color(1, 1, 1))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.size = Vector2(80, 20); nl.position = Vector2(cx + i * 92, 12)
		ui_layer.add_child(nl)

		var cl := Label.new(); cl.text = "%d☀" % cost
		cl.add_theme_font_size_override("font_size", 16)
		cl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.size = Vector2(80, 24); cl.position = Vector2(cx + i * 92, 84)
		ui_layer.add_child(cl)

	# Deselect button
	var desel := Button.new(); desel.text = "✕ Cancel"
	desel.size = Vector2(100, 36); desel.position = Vector2(cx + available.size() * 92 + 8, 42)
	desel.add_theme_font_size_override("font_size", 14)
	desel.pressed.connect(_deselect_plant)
	ui_layer.add_child(desel)

	# End panel
	end_panel = Control.new(); end_panel.visible = false
	end_panel.size = Vector2(640, 340); end_panel.position = Vector2(320, 190)
	ui_layer.add_child(end_panel)

	var ep_bg := ColorRect.new(); ep_bg.color = Color(0, 0, 0, 0.85)
	ep_bg.size = Vector2(640, 340); end_panel.add_child(ep_bg)

	var ep_lbl := Label.new(); ep_lbl.name = "EndLabel"
	ep_lbl.add_theme_font_size_override("font_size", 58)
	ep_lbl.add_theme_color_override("font_color", Color(1, 1, 0))
	ep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ep_lbl.size = Vector2(640, 80); ep_lbl.position = Vector2(0, 40)
	end_panel.add_child(ep_lbl)

	var ep_sub := Label.new(); ep_sub.name = "SubLabel"
	ep_sub.add_theme_font_size_override("font_size", 20)
	ep_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	ep_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ep_sub.size = Vector2(640, 40); ep_sub.position = Vector2(0, 110)
	end_panel.add_child(ep_sub)

	var menu_btn := Button.new(); menu_btn.text = "Main Menu"
	menu_btn.size = Vector2(180, 50); menu_btn.position = Vector2(80, 270)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	end_panel.add_child(menu_btn)

	var retry_btn := Button.new(); retry_btn.text = "Play Again"
	retry_btn.size = Vector2(180, 50); retry_btn.position = Vector2(380, 270)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	end_panel.add_child(retry_btn)

	var meta_btn := Button.new(); meta_btn.text = "Upgrades 🌱"
	meta_btn.size = Vector2(180, 50); meta_btn.position = Vector2(230, 210)
	meta_btn.add_theme_font_size_override("font_size", 20)
	meta_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MetaScreen.tscn"))
	end_panel.add_child(meta_btn)

# =========================================================
#  DRAW
# =========================================================
func _draw() -> void:
	_draw_sky()
	_draw_grid()
	_draw_hover()

func _draw_sky() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.53, 0.81, 0.98))
	draw_rect(Rect2(0, GRID_Y - 10, 1280, GRID_ROWS * CELL_H + 20), Color(0.55, 0.38, 0.18))
	draw_rect(Rect2(0, GRID_Y - 10, GRID_X, GRID_ROWS * CELL_H + 20), Color(0.40, 0.27, 0.10))
	draw_rect(Rect2(GRID_X + GRID_COLS * CELL_W, GRID_Y - 10, 400, GRID_ROWS * CELL_H + 20), Color(0.45, 0.30, 0.12))

func _draw_grid() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var x := GRID_X + col * CELL_W
			var y := GRID_Y + row * CELL_H
			var light := (row + col) % 2 == 0
			draw_rect(Rect2(x, y, CELL_W, CELL_H),
				Color(0.38, 0.65, 0.18) if light else Color(0.32, 0.58, 0.14))
			draw_rect(Rect2(x, y, CELL_W, CELL_H), Color(0, 0, 0, 0.08), false, 1)

func _draw_hover() -> void:
	if hover_cell.x < 0 or selected_plant == "" or drafting:
		return
	var x := GRID_X + hover_cell.x * CELL_W
	var y := GRID_Y + hover_cell.y * CELL_H
	var ok := grid[hover_cell.y][hover_cell.x] == null and sun >= _get_plant_cost(selected_plant)
	draw_rect(Rect2(x, y, CELL_W, CELL_H),
		Color(0.2, 1.0, 0.2, 0.35) if ok else Color(1.0, 0.2, 0.2, 0.35))

# =========================================================
#  INPUT
# =========================================================
func _input(event: InputEvent) -> void:
	if drafting or not game_active:
		return

	if event is InputEventMouseMotion:
		hover_cell = _world_to_grid(event.position)
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	# Sun first
	for s in suns_on_field.duplicate():
		if is_instance_valid(s) and not s.collected and s.try_collect(pos):
			var val := Sun.VALUE + RunState.sun_value_bonus
			_add_sun(val)
			suns_on_field.erase(s)
			return

	# Card click
	var available := MetaProgress.unlocked_plants
	var cx := 140
	for i in range(available.size()):
		if Rect2(cx + i * 92, 10, 80, 100).has_point(pos):
			_select_card(i)
			return

	# Grid click
	var cell := _world_to_grid(pos)
	if cell.x >= 0:
		_try_place_plant(cell)

func _select_card(idx: int) -> void:
	if selected_card_idx == idx:
		_deselect_plant()
		return
	selected_card_idx = idx
	selected_plant    = MetaProgress.unlocked_plants[idx]
	_update_card_visuals()

func _deselect_plant() -> void:
	selected_card_idx = -1
	selected_plant    = ""
	_update_card_visuals()

func _update_card_visuals() -> void:
	for i in range(card_panels.size()):
		var ptype := MetaProgress.unlocked_plants[i]
		var cost  := _get_plant_cost(ptype)
		if i == selected_card_idx:
			card_panels[i].color = Color(0.55, 0.85, 0.28)
		elif sun < cost:
			card_panels[i].color = Color(0.18, 0.18, 0.18)
		else:
			card_panels[i].color = Color(0.25, 0.45, 0.15)

# =========================================================
#  PLANT PLACEMENT
# =========================================================
func _try_place_plant(cell: Vector2i) -> void:
	if selected_plant == "" or grid[cell.y][cell.x] != null:
		return
	var cost := _get_plant_cost(selected_plant)
	if sun < cost:
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
	var node := Node2D.new()
	match ptype:
		"Sunflower":  node.set_script(SunflowerScript)
		"Peashooter": node.set_script(PeashooterScript)
		"WallNut":    node.set_script(WallNutScript)
		"SnowPea":    node.set_script(SnowPeaScript)
		_: return null
	return node

# =========================================================
#  GAME LOOP
# =========================================================
func _process(delta: float) -> void:
	if not game_active or drafting:
		return

	_process_sun_drop(delta)
	_process_waves(delta)
	_process_plants(delta)
	_process_zombies(delta)
	_check_collisions()
	_cleanup_dead()
	_check_end_conditions()
	_update_card_visuals()
	_update_perks_label()
	queue_redraw()

func _process_sun_drop(delta: float) -> void:
	sun_drop_timer -= delta
	var interval := SUN_DROP_BASE * RunState.sky_sun_interval_mult
	if sun_drop_timer <= 0:
		sun_drop_timer = interval
		_spawn_sky_sun()

func _process_waves(delta: float) -> void:
	wave_timer -= delta
	if wave_timer <= 0 and waves_spawned < TOTAL_WAVES:
		wave_timer = 28.0
		_spawn_wave()

func _process_plants(delta: float) -> void:
	for plant in plants.duplicate():
		if not is_instance_valid(plant) or plant.dead:
			continue
		if plant is Sunflower:
			if plant.should_produce_sun():
				var count := 2 if RunState.sunflower_double_sun else 1
				for _i in range(count):
					_spawn_plant_sun(plant.global_position)
		elif plant is Peashooter:
			if _zombie_in_row(plant.grid_row) and plant.try_shoot():
				_fire_peashooter(plant)
		elif plant is SnowPea:
			if _zombie_in_row(plant.grid_row) and plant.try_shoot():
				_spawn_pea(plant.grid_row, plant.global_position.x + 55, plant.global_position.y - 6, true)

func _fire_peashooter(plant: Peashooter) -> void:
	var frozen := RunState.peashooter_freeze
	_spawn_pea(plant.grid_row, plant.global_position.x + 55, plant.global_position.y - 6, frozen)
	if RunState.peashooter_double_shot:
		_spawn_pea(plant.grid_row, plant.global_position.x + 55, plant.global_position.y - 14, frozen)

func _process_zombies(_delta: float) -> void:
	for zombie in zombies.duplicate():
		if not is_instance_valid(zombie) or zombie.dead:
			continue
		if zombie.position.x <= GRID_X - 20:
			_trigger_game_over()
			return
		if not zombie.eating:
			var blocker := _plant_at_zombie(zombie)
			if blocker != null:
				zombie.start_eating(blocker)

# =========================================================
#  COLLISIONS
# =========================================================
func _check_collisions() -> void:
	for pea in projectiles.duplicate():
		if not is_instance_valid(pea) or pea.dead:
			continue
		for zombie in zombies.duplicate():
			if not is_instance_valid(zombie) or zombie.dead:
				continue
			if _pea_hits_zombie(pea, zombie):
				zombie.take_damage(pea.damage)
				if pea.frozen:
					zombie.apply_freeze(3.0)
				if zombie.dead:
					_on_zombie_killed()
				pea.dead = true
				pea.queue_free()
				break

func _pea_hits_zombie(pea: Pea, zombie: Zombie) -> bool:
	if abs(pea.global_position.y - zombie.global_position.y) > 55:
		return false
	return pea.global_position.x >= zombie.global_position.x - 30 and \
	       pea.global_position.x <= zombie.global_position.x + 30

# =========================================================
#  WAVE SPAWNING
# =========================================================
func _spawn_wave() -> void:
	waves_spawned += 1
	wave_label.text = "Wave: %d/%d" % [waves_spawned, TOTAL_WAVES]

	var count := ZOMBIES_PER_WAVE + waves_spawned
	var rows  := range(GRID_ROWS)
	rows.shuffle()

	for i in range(count):
		var row := rows[i % rows.size()]
		var use_cone := waves_spawned >= 2 and randf() < 0.4 + waves_spawned * 0.05

		var node := Node2D.new()
		node.set_script(ConeheadScript if use_cone else ZombieScript)
		node.position  = Vector2(1360 + i * 90, ROW_Y[row])
		node.grid_row  = row
		zombie_layer.add_child(node)
		zombies.append(node)

# =========================================================
#  SPAWNING HELPERS
# =========================================================
func _spawn_sky_sun() -> void:
	var node := Node2D.new(); node.set_script(SunScript)
	node.position = Vector2(randf_range(GRID_X + 50, GRID_X + GRID_COLS * CELL_W - 50), 130)
	node.target_y = randf_range(160, 540)
	node.falling  = true
	sun_layer.add_child(node)
	suns_on_field.append(node)

func _spawn_plant_sun(from_pos: Vector2) -> void:
	var node := Node2D.new(); node.set_script(SunScript)
	node.position = from_pos + Vector2(randf_range(-20, 20), -30)
	node.target_y = from_pos.y + randf_range(30, 80)
	node.falling  = true
	sun_layer.add_child(node)
	suns_on_field.append(node)

func _spawn_pea(row: int, x: float, y: float, frozen: bool = false) -> void:
	var node := Node2D.new(); node.set_script(PeaScript)
	node.position = Vector2(x, y)
	node.frozen   = frozen
	proj_layer.add_child(node)
	projectiles.append(node)

# =========================================================
#  SUN
# =========================================================
func _add_sun(amount: int) -> void:
	sun += amount
	sun_label.text = str(sun)

func _spend_sun(amount: int) -> void:
	var actual := int(amount * RunState.sun_cost_mult)
	sun -= actual
	sun_label.text = str(sun)

# =========================================================
#  HELPERS
# =========================================================
func _zombie_in_row(row: int) -> bool:
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.grid_row == row \
		and z.position.x < GRID_X + GRID_COLS * CELL_W + 60:
			return true
	return false

func _plant_at_zombie(zombie: Zombie) -> Plant:
	var zx := zombie.global_position.x
	var zy := zombie.global_position.y
	for plant in plants:
		if not is_instance_valid(plant) or plant.dead:
			continue
		if abs(plant.global_position.y - zy) < 40 \
		and zx <= plant.global_position.x + 40 \
		and zx >= plant.global_position.x - 60:
			return plant
	return null

func _world_to_grid(pos: Vector2) -> Vector2i:
	var col := int((pos.x - GRID_X) / CELL_W)
	var row := int((pos.y - GRID_Y) / CELL_H)
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(GRID_X + cell.x * CELL_W + CELL_W / 2,
	               GRID_Y + cell.y * CELL_H + CELL_H / 2)

func _get_plant_cost(ptype: String) -> int:
	var base := {"Sunflower": 50, "Peashooter": 100, "WallNut": 50, "SnowPea": 175}
	var b := base.get(ptype, 100)
	var red_lvl := MetaProgress.get_level(ptype, "cost_red")
	b = int(b * (1.0 - red_lvl * 0.08) * RunState.sun_cost_mult)
	return max(10, b)

func _short_name(ptype: String) -> String:
	match ptype:
		"Sunflower":  return "Sunflower"
		"Peashooter": return "Peashooter"
		"WallNut":    return "Wall-nut"
		"SnowPea":    return "Snow Pea"
	return ptype

func _update_perks_label() -> void:
	if RunState.active_perks.is_empty():
		perks_label.text = "No perks yet"
		return
	var icons := ""
	for pid in RunState.active_perks:
		for perk in PerkPool.ALL_PERKS:
			if perk["id"] == pid:
				icons += perk.get("icon", "?") + " "
				break
	perks_label.text = icons.strip_edges()

# =========================================================
#  CLEANUP
# =========================================================
func _cleanup_dead() -> void:
	plants      = plants.filter(func(p): return is_instance_valid(p) and not p.dead)
	zombies     = zombies.filter(func(z): return is_instance_valid(z) and not z.dead)
	projectiles = projectiles.filter(func(p): return is_instance_valid(p) and not p.dead)
	suns_on_field = suns_on_field.filter(func(s): return is_instance_valid(s) and not s.collected)

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var p = grid[row][col]
			if p != null and (not is_instance_valid(p) or p.dead):
				grid[row][col] = null

# =========================================================
#  WAVE END DRAFT
# =========================================================
func _trigger_draft() -> void:
	drafting = true
	var draft := Node.new()
	draft.set_script(DraftScript)
	draft.perk_chosen.connect(_on_draft_chosen)
	draft.draft_skipped.connect(_on_draft_skipped)
	add_child(draft)

func _on_draft_chosen(perk_id: String) -> void:
	drafting = false
	_award_wave_seeds()

func _on_draft_skipped() -> void:
	drafting = false
	_award_wave_seeds()

func _award_wave_seeds() -> void:
	var earned := SEEDS_PER_WAVE * waves_spawned
	RunState.earn_seeds(earned)
	seeds_label.text = "🌱 %d" % MetaProgress.seeds

# =========================================================
#  KILL REWARD
# =========================================================
func _on_zombie_killed() -> void:
	zombies_killed += 1
	RunState.earn_seeds(SEEDS_PER_KILL)
	seeds_label.text = "🌱 %d" % MetaProgress.seeds

# =========================================================
#  WIN / LOSE
# =========================================================
func _check_end_conditions() -> void:
	# Trigger draft after each wave clears
	if not drafting and waves_spawned > 0 and waves_spawned < TOTAL_WAVES:
		var alive := zombies.filter(func(z): return is_instance_valid(z) and not z.dead)
		# Check if we've been waiting and all zombies for this wave are dead
		if alive.is_empty() and wave_timer < 20.0:
			wave_timer = 28.0  # reset wave timer THEN draft
			_trigger_draft()
			return

	if waves_spawned >= TOTAL_WAVES:
		var alive := zombies.filter(func(z): return is_instance_valid(z) and not z.dead)
		if alive.is_empty():
			_trigger_victory()

func _trigger_game_over() -> void:
	if not game_active:
		return
	game_active = false
	var lbl: Label = end_panel.get_node("EndLabel")
	lbl.text = "GAME OVER"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	var sub: Label = end_panel.get_node("SubLabel")
	sub.text = "Seeds earned: %d  |  Zombies killed: %d" % [RunState.seeds_earned, zombies_killed]
	end_panel.visible = true

func _trigger_victory() -> void:
	if not game_active:
		return
	game_active = false
	victory = true
	MetaProgress.wins += 1
	RunState.earn_seeds(SEEDS_WIN_BONUS)
	MetaProgress.save_data()

	var lbl: Label = end_panel.get_node("EndLabel")
	lbl.text = "YOU WIN!"
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	var sub: Label = end_panel.get_node("SubLabel")
	sub.text = "Seeds earned: %d  |  Total seeds: %d  |  Win #%d" % [
		RunState.seeds_earned, MetaProgress.seeds, MetaProgress.wins]
	end_panel.visible = true
