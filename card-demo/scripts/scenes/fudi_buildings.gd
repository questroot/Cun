extends Node
## Round-local rolls and two timed status slots. No loot or equipment state is mutated.
const Catalog = preload("res://scripts/scenes/building_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Art = preload("res://scripts/scenes/fudi_material_art.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const RIPPLE_PERIOD := 2.4
var game
var rng := RandomNumberGenerator.new()
var states: Dictionary = {}
var active: Dictionary = {}
var region := ""
var banner: Label
var ripple_time := 0.0

func play_visible() -> Dictionary:
	if game == null or game._paused() or game.finished: return {}
	var door: Vector2 = game.world_to_screen(Catalog.entrance(game.region))
	if not game.ARENA.has_point(door): return {}
	var result := {"entrance":{"x":door.x,"y":door.y},"activation_radius":Catalog.RADIUS*game.WORLD_ZOOM,"appearance":"建筑入口光圈，走入自动生效"}
	var rect := Catalog.footprint(game.region)
	var label_origin: Vector2 = door+Vector2(-rect.size.x*0.45,-132)*game.WORLD_ZOOM
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
	ripple_time = fmod(ripple_time + delta, RIPPLE_PERIOD)
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
	var distance: float = game.player_foot.distance_to(Catalog.entrance(game.region))
	return lerpf(0.90, 0.65, smoothstep(220.0, 480.0, distance))

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
	var rect := Art.building_rect(id, Catalog.entrance(id))
	var door := Catalog.entrance(id)
	var view: Rect2 = game.visible_world()
	if not view.intersects(rect) and not view.intersects(Rect2(door - Vector2(360, 190), Vector2(720, 290))):
		return
	var canvas: Control = game.world_canvas
	canvas.draw_texture_rect(Art.BUILDINGS[id], rect, false)
	_draw_entrance(canvas, id, door, Catalog.footprint(id).size.x, Color(Maps.MAPS[id].accent), Catalog.color(states[id].effect))

func _draw_entrance(canvas: Control, id: String, door: Vector2, w: float, trim: Color, tint: Color) -> void:
	var data: Dictionary = Catalog.REGIONS[id]
	# The steady rim marks the activation boundary while the waves fade inside it.
	canvas.draw_circle(door, Catalog.RADIUS, Color(tint, 0.055))
	canvas.draw_arc(door, Catalog.RADIUS - 3.0, 0, TAU, 64, Color(tint, 0.12), 7.0, true)
	canvas.draw_arc(door, Catalog.RADIUS, 0, TAU, 64, Color(tint, 0.68), 2.0, true)
	var crest := tint.lerp(Color.WHITE, 0.3)
	for wave in range(3):
		var progress := fposmod(ripple_time / RIPPLE_PERIOD + float(wave) / 3.0, 1.0)
		var radius := lerpf(15.0, Catalog.RADIUS - 4.0, progress)
		var strength := sin(progress * PI) * (1.0 - 0.35 * progress)
		canvas.draw_arc(door, radius, 0, TAU, 48, Color(tint, 0.16 * strength), 5.0, true)
		canvas.draw_arc(door, radius, 0, TAU, 48, Color(crest, 0.65 * strength), 1.6, true)
	var marker := PackedVector2Array([door + Vector2(0, -11), door + Vector2(11, 0), door + Vector2(0, 11), door + Vector2(-11, 0)])
	canvas.draw_colored_polygon(marker, Color(crest, 0.68))
	var effect: Dictionary = Catalog.EFFECTS[states[id].effect]
	var description := "%s【%s】%s · 走进光圈获得60秒" % ["增益" if effect.positive else "减益", effect.name, effect.description]
	var font := ThemeDB.fallback_font
	var label_width := maxf(font.get_string_size(data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x, font.get_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	canvas.draw_style_box(UI.hud_panel(Color(0.04, 0.10, 0.12, 0.9)), Rect2(door + Vector2(-w * 0.45 - 10, -186), Vector2(label_width + 20, 66)))
	canvas.draw_string(ThemeDB.fallback_font, door + Vector2(-w * 0.45, -160), data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, trim)
	canvas.draw_string(font, door + Vector2(-w * 0.45, -132), description, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
