extends Control

const Hero = preload("res://scripts/scenes/hero_walk_sprite.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const STONE_BRICK := preload("res://assets/stone-court/stone-brick-guofeng.png")
const TIDE_SHEET := preload("res://assets/stone-court/stone-court-tide.png")
const PHOENIX_SHEET := preload("res://assets/stone-court/stone-court-phoenix.png")
const MAP_SIZE := Vector2(2352, 1334)
const HALF_TILE := Vector2(105, 68)
const TOP_HALF := Vector2(86, 46)
const BRICK_SCALE := 0.24
const BRICK_ANCHOR := Vector2(373, 203)
const SPEED := 245.0
const MAX_SINK := 6.0
const TIDE_FPS := 12.0
const TIDE_PERIOD := 4.0
const PHOENIX_DURATION := 3.95
const PHOENIX_FPS := 20.0
const PHOENIX_SEA_ORIGIN := Vector2(620, 884)
const PHOENIX_PIVOT := Vector2(46, 176)
const PHOENIX_SCALE := 3.0

var world := Node2D.new()
var tide := Sprite2D.new()
var phoenix := Sprite2D.new()
var hero_shadow := Node2D.new()
var starlight := Node2D.new()
var hero := Hero.new()
var foot := MAP_SIZE * 0.5 - Vector2(16, 0)
var pressed: Dictionary[Vector2i, float] = {}
var tiles: Dictionary[Vector2i, Sprite2D] = {}
var foot_sink := 0.0
var star_time := 0.0
var tide_time := 0.0
var tide_cycle := 0

func _ready() -> void:
	DisplayServer.window_set_title("福地 · 星纹石庭")
	clip_contents = true
	add_child(world)
	world.draw.connect(func() -> void: world.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#2b373a")))
	tide.texture = TIDE_SHEET
	tide.hframes = 8
	tide.vframes = 6
	tide.centered = false
	tide.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tide.scale = Vector2.ONE * 4.0
	world.add_child(tide)
	_build_tiles()
	world.add_child(hero_shadow)
	hero_shadow.draw.connect(_draw_shadow)
	world.add_child(hero)
	world.add_child(starlight)
	starlight.draw.connect(_draw_starlight)
	phoenix.texture = PHOENIX_SHEET
	phoenix.hframes = 8
	phoenix.vframes = 10
	phoenix.centered = false
	phoenix.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	phoenix.scale = Vector2.ONE * PHOENIX_SCALE
	phoenix.position = PHOENIX_SEA_ORIGIN - PHOENIX_PIVOT * PHOENIX_SCALE
	phoenix.hide()
	world.add_child(phoenix)
	hero.position = foot
	world.position = _camera_target()

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.hud_panel(Color("#15232ee8")))
	add_child(panel)
	var labels := VBoxContainer.new()
	panel.add_child(labels)
	labels.add_child(UI.label("星纹石庭", 22, Color("#eee0bf")))
	labels.add_child(UI.label("WASD / 方向键移动", 14, Color("#b9ccc8")))
	var back := UI.button("返回  Esc", _leave)
	back.name = "Back"
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -159
	back.offset_right = -20
	back.offset_top = 20
	back.offset_bottom = 64

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_leave()
		get_viewport().set_input_as_handled()

func _leave() -> void:
	get_node("/root/GameManager").goto_scene("menu")

func _process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	).normalized()
	advance(direction, minf(delta, 0.05))

func advance(direction: Vector2, delta: float) -> void:
	var previous := foot
	foot = (foot + direction * SPEED * delta).clamp(Vector2(42, 42), MAP_SIZE - Vector2(42, 42))
	var cell := cell_at(foot)
	var on_brick := tiles.has(cell) and is_brick_top(foot, cell)
	for old_cell: Vector2i in pressed.keys():
		if old_cell == cell and on_brick:
			continue
		var lift := move_toward(pressed[old_cell], 0.0, 24.0 * delta)
		tiles[old_cell].position.y = center_of(old_cell).y + lift
		if lift == 0.0:
			pressed.erase(old_cell)
		else:
			pressed[old_cell] = lift
	foot_sink = 0.0
	if on_brick:
		foot_sink = move_toward(pressed.get(cell, 0.0), MAX_SINK, 42.0 * delta)
		pressed[cell] = foot_sink
		tiles[cell].position.y = center_of(cell).y + foot_sink
	hero.position = foot + Vector2(0, foot_sink)
	hero.update_movement(foot - previous, delta)
	world.position = world.position.lerp(_camera_target(), 1.0 - exp(-10.0 * delta))
	star_time = fmod(star_time + delta, 8.0)
	var tide_elapsed := tide_time + delta
	tide_cycle = (tide_cycle + floori(tide_elapsed / TIDE_PERIOD)) % 3
	tide_time = fmod(tide_elapsed, TIDE_PERIOD)
	tide.frame = floori(tide_time * TIDE_FPS)
	phoenix.visible = tide_cycle == 2 and tide_time < PHOENIX_DURATION
	if phoenix.visible:
		phoenix.frame = floori(tide_time * PHOENIX_FPS)
	hero_shadow.queue_redraw()
	starlight.queue_redraw()

func _camera_target() -> Vector2:
	return -(foot - size * 0.5).clamp(Vector2.ZERO, (MAP_SIZE - size).max(Vector2.ZERO))

static func _to_grid(point: Vector2) -> Vector2:
	return Vector2(point.x / HALF_TILE.x + point.y / HALF_TILE.y, point.y / HALF_TILE.y - point.x / HALF_TILE.x) * 0.5

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((_to_grid(point) + Vector2.ONE * 0.5).floor())

static func center_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x - cell.y, cell.x + cell.y) * HALF_TILE

static func is_brick_top(point: Vector2, cell: Vector2i) -> bool:
	var local := (point - center_of(cell)).abs() / TOP_HALF
	return local.x + local.y <= 1.0

static func _diamond(point: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([point + Vector2(0, -half.y), point + Vector2(half.x, 0), point + Vector2(0, half.y), point + Vector2(-half.x, 0)])

func _build_tiles() -> void:
	# Draw back rows first so the original front faces layer naturally.
	var columns := ceili(MAP_SIZE.x / HALF_TILE.x)
	var rows := ceili(MAP_SIZE.y / HALF_TILE.y)
	for row in range(-2, rows + 2):
		for column in range(-2 + posmod(row, 2), columns + 3, 2):
			var center := Vector2(column, row) * HALF_TILE
			if center.x < MAP_SIZE.x * 0.5:
				continue
			var tile := Sprite2D.new()
			tile.texture = STONE_BRICK
			tile.centered = false
			tile.offset = -BRICK_ANCHOR
			tile.scale = Vector2.ONE * BRICK_SCALE
			tile.position = center
			world.add_child(tile)
			tiles[cell_at(center)] = tile

func _draw_shadow() -> void:
	var ground := hero.position
	hero_shadow.draw_set_transform(ground + Vector2(0, -1), 0.0, Vector2(1, 0.35))
	hero_shadow.draw_circle(Vector2.ZERO, 27, Color("#111a2690"))
	hero_shadow.draw_set_transform(Vector2.ZERO)

func _draw_starlight() -> void:
	var opacity := foot_sink / MAX_SINK
	var light := Color("#ddf8ff")
	var stems := PackedVector2Array([Vector2(-7, 4), Vector2(-34, 1), Vector2(-20, 13), Vector2(16, 16), Vector2(34, 5)])
	for i in range(stems.size()):
		var phase := TAU * (star_time * 0.75 + float(i) / stems.size())
		var alpha := (0.20 + 0.80 * pow(0.5 + 0.5 * sin(phase), 2)) * opacity
		var point := hero.position + stems[i] + Vector2(2.0 * cos(phase), -5.0 * alpha)
		starlight.draw_circle(point, 6.0, Color("#9bdbf4", 0.14 * alpha))
		starlight.draw_colored_polygon(_diamond(point, Vector2(2.0, 5.0)), Color(light, 0.82 * alpha))
		starlight.draw_colored_polygon(_diamond(point, Vector2(5.0, 1.35)), Color(light, 0.68 * alpha))
