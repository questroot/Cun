extends Node
## Round-local rolls and two timed status slots. No loot or equipment state is mutated.
const Catalog = preload("res://scripts/scenes/building_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game
var rng := RandomNumberGenerator.new()
var states: Dictionary = {}
var active: Dictionary = {}
var region := ""
var banner: Label

func play_visible() -> Dictionary:
	if game == null or game._paused() or game.finished: return {}
	var door: Vector2 = game.world_to_screen(Catalog.entrance(game.region))
	if not game.ARENA.has_point(door): return {}
	var result := {"entrance":{"x":door.x,"y":door.y},"activation_radius":Catalog.RADIUS*game.WORLD_ZOOM,"appearance":"建筑入口光圈，走入自动生效"}
	var rect := Catalog.footprint(game.region)
	var label_origin: Vector2 = door+Vector2(-rect.size.x*0.45,-62)*game.WORLD_ZOOM
	var effect: Dictionary = Catalog.EFFECTS[states[game.region].effect]
	var text := "%s【%s】%s · 走进光圈获得60秒" % ["增益" if effect.positive else "减益",effect.name,effect.description]
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17)
	var bounds := Rect2(label_origin-Vector2(0,font.get_ascent(17))*game.WORLD_ZOOM,text_size*game.WORLD_ZOOM)
	if game.ARENA.encloses(bounds): result["visible_label"] = text
	return result

func _ready() -> void:
	game = get_parent()
	rng.randomize()
	for id: String in Maps.IDS:
		var choices: Array = Catalog.REGIONS[id].pool
		states[id] = {"effect": choices[rng.randi_range(0, choices.size() - 1)], "inside": false, "visits": 0}
	region = game.region
	game.world_canvas.draw.connect(draw_world)
	game.minimap.draw.connect(draw_minimap)
	game.tools.atlas.set_meta("building_provider", summary)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 50)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := UI.hud_panel(Color(0.04, 0.10, 0.12, 0.84))
	panel.add_theme_stylebox_override("panel", skin)
	banner = UI.label("", 14, Color("#d5e9d5"))
	panel.add_child(banner)
	game.world_view.add_child(panel)
	refresh()

func _process(delta: float) -> void:
	if game.is_processing():
		tick(delta)
	refresh()

func tick(delta: float) -> void:
	if delta <= 0 or game.finished or game._paused():
		return
	if game.region != region:
		states[region].inside = false
		region = game.region
		states[region].inside = false
	var state: Dictionary = states[region]
	var inside: bool = game.player_foot.distance_to(Catalog.entrance(region)) <= Catalog.RADIUS
	if inside and not state.inside:
		activate(region)
	state.inside = inside
	for slot: String in active.keys():
		var status: Dictionary = active[slot]
		var time := minf(delta, float(status.left))
		var config: Dictionary = Catalog.EFFECTS[status.effect]
		if config.has("healing"):
			status.healing += float(config.healing) * time
			var restored := floori(float(status.healing) + 0.000001)
			status.healing -= restored
			game.health = mini(100, game.health + restored)
		status.left = maxf(0, float(status.left) - delta)
		if float(status.left) <= 0:
			active.erase(slot)
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()

func activate(id: String) -> void:
	var effect: String = states[id].effect
	var slot := "buff" if Catalog.EFFECTS[effect].positive else "debuff"
	active[slot] = {"effect": effect, "source": id, "left": Catalog.DURATION, "healing": 0.0}
	states[id].visits += 1
	refresh()

func multiplier(stat: String) -> float:
	var value := 1.0
	for status: Dictionary in active.values():
		value *= float(Catalog.EFFECTS[status.effect].get(stat, 1.0))
	return value

func camera_height() -> float:
	return 0.82 if game.player_foot.distance_to(Catalog.entrance(game.region)) < 350 else 0.65

func summary(id: String) -> String:
	if not states.has(id):
		return ""
	var data: Dictionary = Catalog.REGIONS[id]
	var effect: String = states[id].effect
	var config: Dictionary = Catalog.EFFECTS[effect]
	var door := Catalog.entrance(id)
	return "%s · %s【%s】%s\n入口%d,%d；进入光圈获得60秒效果。同类替换，增益/减益各保留一种；本轮已触发%d次。" % [data.name, "增益" if config.positive else "减益", config.name, config.description, int(door.x), int(door.y), states[id].visits]

func status_text() -> String:
	var lines: Array[String] = []
	for slot: String in ["buff", "debuff"]:
		if active.has(slot):
			var status: Dictionary = active[slot]
			var data: Dictionary = Catalog.EFFECTS[status.effect]
			lines.append("%s %s · %s · %d秒" % ["增益" if data.positive else "减益", data.name, data.description, ceili(status.left)])
	return "\n".join(lines) if not lines.is_empty() else "建筑：绿光增益 / 紫光减益\n走进入口光圈获得60秒效果；M / B查看"

func refresh() -> void:
	if banner != null:
		var lines: Array[String] = []
		for slot: String in ["buff", "debuff"]:
			if active.has(slot):
				var state: Dictionary = active[slot]
				var effect: Dictionary = Catalog.EFFECTS[state.effect]
				lines.append("%s %s · %s · %ds" % ["增益" if effect.positive else "减益", effect.name, effect.description, ceili(state.left)])
		banner.text = "\n".join(lines)
		banner.get_parent().visible = not lines.is_empty()

func draw_minimap() -> void:
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	var point: Vector2 = rect.position + Catalog.entrance(game.region) / Maps.MAPS[game.region].size * rect.size
	var color := Catalog.color(states[game.region].effect)
	game.minimap.draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), color)
	game.minimap.draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("#17383c"))

func draw_world() -> void:
	var id: String = game.region
	var rect := Catalog.footprint(id)
	var door := Catalog.entrance(id)
	var view: Rect2 = game.visible_world().grow(250)
	if not view.intersects(rect) and not view.has_point(door):
		return
	var canvas: Control = game.world_canvas
	var data: Dictionary = Catalog.REGIONS[id]
	var tint := Catalog.color(states[id].effect)
	var wall := Color(data.wall)
	var roof := Color(data.roof)
	var trim := Color(Maps.MAPS[id].accent)
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var bottom := rect.end.y
	var center := rect.get_center().x
	if Maps.Art.has_art(id):
		_draw_entrance(canvas, id, door, w, trim, tint)
		return
	# Broad terraces, side walls and multiple roof planes give a readable large silhouette.
	canvas.draw_rect(Rect2(rect.position + Vector2(18, 20), rect.size), Color(0.01, 0.025, 0.03, 0.5))
	canvas.draw_rect(rect, wall.darkened(0.28))
	canvas.draw_rect(Rect2(x + 12, y + 6, w - 24, rect.size.y - 6), wall)
	for i in range(4):
		canvas.draw_rect(Rect2(center - 80 - i * 10, bottom + i * 9, 160 + i * 20, 10), wall.lightened(0.12 - i * 0.04))
	# Lit colonnade, tall central door and window grids.
	for i in range(8):
		var column_x := x + 25 + i * (w - 50) / 7
		canvas.draw_rect(Rect2(column_x - 6, y + 18, 12, rect.size.y - 24), wall.lightened(0.22))
		canvas.draw_rect(Rect2(column_x - 10, bottom - 10, 20, 10), trim.darkened(0.35))
		if i < 7 and absf(column_x + (w - 50) / 14 - center) > 42:
			var win := Rect2(column_x + 12, y + 36, (w - 50) / 7 - 24, 42)
			canvas.draw_rect(win, Color("#1e343b"))
			canvas.draw_rect(win.grow(-5), Color(trim, 0.6))
			canvas.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), wall.darkened(0.3), 3)
	canvas.draw_rect(Rect2(center - 36, bottom - 80, 72, 80), Color("#152c30"))
	canvas.draw_arc(Vector2(center, bottom - 76), 36, PI, TAU, 24, trim, 5, true)
	canvas.draw_rect(Rect2(center - 29, bottom - 74, 58, 74), roof.darkened(0.35))
	canvas.draw_circle(Vector2(center + 15, bottom - 32), 3, trim)
	_roof(canvas, Vector2(x - 22, y + 25), w + 44, 85, roof, trim)
	_roof(canvas, Vector2(center - w * 0.30, y - 40), w * 0.60, 75, roof.lightened(0.09), trim)
	var ornament := Vector2(center, y - 92)
	match data.kind:
		"forge", "kiln":
			for side in [-1, 1]:
				var chimney := Vector2(center + side * w * 0.34, y - 78)
				canvas.draw_rect(Rect2(chimney, Vector2(30, 90)), wall.darkened(0.22))
				canvas.draw_rect(Rect2(chimney - Vector2(5, 6), Vector2(40, 12)), trim.darkened(0.25))
				for i in range(3):
					canvas.draw_circle(chimney + Vector2(15 + i * side * 8, -20 - i * 16), 10 + i * 4, Color("#a5a28c", 0.23))
			canvas.draw_circle(ornament + Vector2(0, 15), 22, Color("#e7a16b"))
			canvas.draw_colored_polygon(PackedVector2Array([ornament + Vector2(-11, 24), ornament + Vector2(1, -4), ornament + Vector2(13, 24)]), Color("#ffe2a1"))
		"sanctum", "archive", "observatory":
			canvas.draw_circle(ornament + Vector2(0, 35), 57, roof.lightened(0.13))
			canvas.draw_arc(ornament + Vector2(0, 35), 57, PI, TAU, 32, trim, 4, true)
			canvas.draw_rect(Rect2(ornament + Vector2(-62, 35), Vector2(124, 16)), roof)
			canvas.draw_line(ornament + Vector2(0, -38), ornament + Vector2(0, 8), trim, 4, true)
			canvas.draw_arc(ornament + Vector2(0, -14), 20, 0, TAU, 32, trim, 3, true)
			canvas.draw_line(ornament + Vector2(-28, -22), ornament + Vector2(28, -6), trim, 3, true)
		"gate":
			for side in [-1, 1]:
				var tower := Vector2(center + side * w * 0.36, y - 100)
				canvas.draw_rect(Rect2(tower - Vector2(32, 0), Vector2(64, 145)), wall.darkened(0.08))
				_roof(canvas, tower + Vector2(-48, 4), 96, 44, roof, trim)
				canvas.draw_rect(Rect2(tower + Vector2(-12, 25), Vector2(24, 34)), trim)
		"clinic":
			canvas.draw_rect(Rect2(ornament + Vector2(-28, 0), Vector2(56, 56)), Color("#254f4e"))
			canvas.draw_rect(Rect2(ornament + Vector2(-6, 6), Vector2(12, 44)), trim)
			canvas.draw_rect(Rect2(ornament + Vector2(-22, 22), Vector2(44, 12)), trim)
		"dock":
			for i in range(9):
				var post := Vector2(x + i * w / 8, bottom)
				canvas.draw_line(post, post + Vector2(0, 35), wall.darkened(0.35), 8, true)
			for side in [-1, 1]:
				var lantern := Vector2(center + side * w * 0.4, y + 18)
				canvas.draw_circle(lantern, 14, trim)
				canvas.draw_line(lantern + Vector2(0, 14), lantern + Vector2(0, 28), trim, 3)
		_:
			canvas.draw_rect(Rect2(ornament + Vector2(-46, 8), Vector2(92, 36)), roof.darkened(0.25))
			canvas.draw_string(ThemeDB.fallback_font, ornament + Vector2(-22, 35), "百味", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, trim)
	_draw_entrance(canvas, id, door, w, trim, tint)

func _draw_entrance(canvas: Control, id: String, door: Vector2, w: float, trim: Color, tint: Color) -> void:
	var data: Dictionary = Catalog.REGIONS[id]
	# Entrance clearly advertises both polarity and the precise activation boundary.
	canvas.draw_circle(door, Catalog.RADIUS, Color(tint, 0.08))
	canvas.draw_arc(door, Catalog.RADIUS, 0, TAU, 64, Color(tint, 0.7), 3, true)
	canvas.draw_colored_polygon(PackedVector2Array([door + Vector2(0, -19), door + Vector2(19, 0), door + Vector2(0, 19), door + Vector2(-19, 0)]), Color(tint, 0.8))
	var effect: Dictionary = Catalog.EFFECTS[states[id].effect]
	canvas.draw_string(ThemeDB.fallback_font, door + Vector2(-w * 0.45, -90), data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, trim)
	canvas.draw_string(ThemeDB.fallback_font, door + Vector2(-w * 0.45, -62), "%s【%s】%s · 走进光圈获得60秒" % ["增益" if effect.positive else "减益", effect.name, effect.description], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)

func _roof(canvas: Control, base: Vector2, width: float, height: float, roof: Color, trim: Color) -> void:
	var points := PackedVector2Array([base + Vector2(-8, 0), base + Vector2(width * 0.22, -height * 0.75), base + Vector2(width * 0.50, -height), base + Vector2(width * 0.78, -height * 0.75), base + Vector2(width + 8, 0)])
	canvas.draw_colored_polygon(points, roof)
	canvas.draw_polyline(points, trim.darkened(0.15), 4, true)
	canvas.draw_line(base - Vector2(12, 0), base + Vector2(width + 12, 0), trim, 6, true)
	for i in range(1, 12):
		var t := i / 12.0
		canvas.draw_line(base + Vector2(width * 0.5, -height + 8), base + Vector2(width * t, -4), Color(trim, 0.18), 2, true)
