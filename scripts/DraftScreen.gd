extends CanvasLayer
# Between-wave perk draft overlay

signal perk_chosen(perk_id: String)
signal draft_skipped

var _perks: Array = []
var _card_rects: Array = []   # Rect2 in screen space
var _hovered: int = -1

const CARD_W    := 240
const CARD_H    := 320
const CARD_GAP  := 30
const START_Y   := 180

func _ready() -> void:
	layer = 20
	_perks = PerkPool.get_random_draft(3)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hovered = _card_index_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _card_index_at(event.position)
		if idx >= 0:
			RunState.add_perk(_perks[idx]["id"])
			emit_signal("perk_chosen", _perks[idx]["id"])
			queue_free()
		# Check skip button
		var skip_rect := _skip_rect()
		if skip_rect.has_point(event.position):
			emit_signal("draft_skipped")
			queue_free()

func _card_index_at(pos: Vector2) -> int:
	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(pos):
			return i
	return -1

func _skip_rect() -> Rect2:
	return Rect2(540, 560, 200, 44)

func _draw() -> void:
	# Dim background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))

	# Title
	_draw_text_centered("Choose an Upgrade!", Vector2(640, 90), 44, Color(1.0, 0.9, 0.1))
	_draw_text_centered("Wave complete  •  Pick 1 of 3", Vector2(640, 142), 20, Color(0.85, 0.85, 0.85))

	_card_rects.clear()
	var total_w := _perks.size() * CARD_W + (_perks.size() - 1) * CARD_GAP
	var start_x := int((1280 - total_w) / 2)

	for i in range(_perks.size()):
		var perk: Dictionary = _perks[i]
		var x := start_x + i * (CARD_W + CARD_GAP)
		var rect := Rect2(x, START_Y, CARD_W, CARD_H)
		_card_rects.append(rect)
		_draw_card(rect, perk, i == _hovered)

	# Skip button
	var sr := _skip_rect()
	draw_rect(sr, Color(0.3, 0.3, 0.3, 0.85))
	draw_rect(sr, Color(0.6, 0.6, 0.6), false, 1.5)
	_draw_text_centered("Skip", Vector2(sr.position.x + sr.size.x / 2, sr.position.y + 10), 22, Color(0.8, 0.8, 0.8))

func _draw_card(rect: Rect2, perk: Dictionary, hovered: bool) -> void:
	var color: Color = perk.get("color", Color(0.3, 0.6, 0.3))
	var bg_color := Color(0.12, 0.14, 0.12, 0.97)
	var border_color := color if hovered else color.darkened(0.3)
	var border_w := 4.0 if hovered else 2.0

	# Card bg
	draw_rect(rect, bg_color)
	# Color accent top strip
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8)), color)
	# Border
	draw_rect(rect, border_color, false, border_w)

	# Hover glow
	if hovered:
		draw_rect(rect.grow(4), Color(color.r, color.g, color.b, 0.18))

	# Icon
	var icon: String = perk.get("icon", "?")
	_draw_text_centered(icon, Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 22), 48, color)

	# Perk type badge
	var type_str := "GLOBAL" if perk.get("type") == "global" else perk.get("target", "").to_upper()
	var badge_color := Color(0.5, 0.5, 0.8) if perk.get("type") == "global" else color.darkened(0.1)
	draw_rect(Rect2(rect.position.x + 8, rect.position.y + 84, CARD_W - 16, 22), badge_color.darkened(0.3))
	_draw_text_centered(type_str, Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 87), 14, Color(1, 1, 1, 0.9))

	# Name
	_draw_text_centered(perk.get("name", ""), Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 118), 22, Color(1, 1, 1))

	# Description (word wrap manually)
	var desc: String = perk.get("desc", "")
	_draw_text_wrapped(desc, rect.position + Vector2(16, 152), CARD_W - 32, 17, Color(0.85, 0.95, 0.85))

	# Flavor text
	var flavor: String = perk.get("flavor", "")
	_draw_text_centered('"' + flavor + '"', Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 258), 14, Color(0.65, 0.65, 0.65, 0.9))

	# Stack indicator
	var stacks := RunState.stack_count(perk.get("id", ""))
	if stacks > 0:
		var stack_txt := "Lv " + str(stacks + 1)
		_draw_text_centered(stack_txt, Vector2(rect.position.x + rect.size.x / 2, rect.position.y + 294), 15, Color(1.0, 0.8, 0.3))

func _draw_text_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	# Approximate centering using char count
	var approx_w := text.length() * font_size * 0.55
	draw_string(ThemeDB.fallback_font, Vector2(center.x - approx_w / 2, center.y + font_size * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_text_wrapped(text: String, pos: Vector2, max_w: float, font_size: int, color: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	var char_w := font_size * 0.55
	for word in words:
		var test := (line + " " + word).strip_edges()
		if test.length() * char_w > max_w and line != "":
			draw_string(ThemeDB.fallback_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			y += font_size + 4
			line = word
		else:
			line = test
	if line != "":
		draw_string(ThemeDB.fallback_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
