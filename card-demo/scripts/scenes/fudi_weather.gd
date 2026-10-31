extends Node
## Scene-owned ecology. Existing wild pickups remain; six renewable plots grow per map.
const Ecology = preload("res://scripts/scenes/weather_ecology.gd")
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const PixelVFX = preload("res://scripts/scenes/pixel_vfx.gd")
const MaterialArt = preload("res://scripts/scenes/fudi_material_art.gd")
var game: Control
var elapsed := 0.0
var climates: Dictionary = {}
var plots: Dictionary = {}
var overlay: Control
var garden: Control
var weather_label: Label
var initialized := false

func play_visible() -> Array:
	var result: Array = []
	if not initialized or game._paused() or game.finished: return result
	for plot: Dictionary in plots[game.region]:
		var point: Vector2 = game.world_to_screen(plot.position)
		if not game.ARENA.has_point(point): continue
		var entry := {"x":point.x,"y":point.y,"appearance":"圆形药圃与生长弧"}
		# Match the draw-time proximity rule and require the complete label to fit.
		if game.player_foot.distance_to(plot.position)<200:
			var progress := float(plot.growth)/float(Ecology.PLANTS[plot.item].time)
			var stage := "成熟 · 靠近采集" if plot.ripe else ("生长 %d%%" % int(progress*100) if Ecology.compatible(plot.item,climates[game.region]) else "待候 %d%%" % int(progress*100))
			var label := "%s · %s" % [Catalog.ITEMS[plot.item].name,stage]
			var font := ThemeDB.fallback_font
			var label_bounds := Rect2(point+Vector2(-50,42-font.get_ascent(16))*game.WORLD_ZOOM,font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16)*game.WORLD_ZOOM)
			if game.ARENA.encloses(label_bounds): entry["visible_label"] = label
		result.append(entry)
	return result

func _ready() -> void:
	process_priority = 10 # Run after collection/combat, so harvest and kill events are visible.
	call_deferred("initialize")

func initialize() -> void:
	game = get_parent()
	for id: String in Maps.IDS:
		climates[id] = Ecology.weather_at(id, 0)
		plots[id] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 93001 + Maps.IDS.find(id) * 97
		for item: String in Ecology.CLIMATES[id].plants:
			for n in range(2):
				var occupied: Array = game.states[id].pickups.duplicate()
				occupied.append_array(plots[id])
				plots[id].append({"item": item, "position": game._free_point(id, rng, occupied), "growth": 0.0, "ripe": false, "pickup": {}, "harvests": 0})
		adapt_enemies(id)
		game.states[id]["weather"] = climates[id]
		game.states[id]["weather_plots"] = plots[id]
	garden = Control.new()
	garden.size = game.world_canvas.size
	garden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garden.z_index = 2
	garden.draw.connect(_draw_garden)
	game.world_canvas.add_child(garden)
	game.minimap.draw.connect(_draw_garden_map)
	overlay = Control.new()
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.size = game.ARENA.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_weather)
	game.world_view.add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", UI.hud_panel(Color(0.04, 0.09, 0.12, 0.82)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)
	weather_label = UI.label("", 14)
	panel.add_child(weather_label)
	game.tools.atlas.set_meta("weather_provider", summary)
	initialized = true
	_refresh()

func summary(id: String) -> String:
	if not Ecology.CLIMATES.has(id):
		return ""
	var ripe := 0
	var growing := 0
	for plot: Dictionary in plots[id]:
		if plot.ripe:
			ripe += 1
		elif Ecology.compatible(plot.item, climates[id]):
			growing += 1
	var monster: Dictionary = Ecology.WEATHER[climates[id]]
	return "%s\n再生药圃：成熟 %d · 生长 %d · 等待天气 %d\n%s：生命%d · 伤害%d · 移速%.0f\n掉落%s；转天气保留受伤比例，不复活守卫。" % [Ecology.describe(id, elapsed), ripe, growing, plots[id].size() - ripe - growing, monster.monster, monster.hp, monster.damage, monster.speed, Catalog.ITEMS[monster.drop].name]

func _process(delta: float) -> void:
	if not initialized:
		return
	# Honors the parent scene being intentionally suspended by a test or future menu.
	if game.is_processing() and not game.finished and not game._paused():
		tick(delta)
	_refresh()

func tick(delta: float) -> void:
	if not initialized or game.finished or game._paused() or delta <= 0:
		return
	# Split at weather boundaries: a long frame must not give plants the wrong climate.
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(remaining, Ecology.PERIOD - fmod(elapsed, Ecology.PERIOD))
		for id: String in Maps.IDS:
			_grow(id, step)
		elapsed += step
		remaining -= step
		for id: String in Maps.IDS:
			var next := Ecology.weather_at(id, elapsed)
			if next != climates[id]:
				climates[id] = next
				game.states[id].weather = next
				adapt_enemies(id)

func _grow(id: String, delta: float) -> void:
	for plot: Dictionary in plots[id]:
		if plot.ripe:
			if game.states[id].pickups.has(plot.pickup):
				continue
			plot.ripe = false
			plot.growth = 0.0
			plot.harvests += 1
		if not Ecology.compatible(plot.item, climates[id]):
			continue
		plot.growth = minf(float(Ecology.PLANTS[plot.item].time), float(plot.growth) + delta)
		if float(plot.growth) >= float(Ecology.PLANTS[plot.item].time):
			plot.ripe = true
			plot.pickup = {"item": plot.item, "position": plot.position, "weather_growth": true}
			game.states[id].pickups.append(plot.pickup)

func adapt_enemies(id: String) -> void:
	var weather: Dictionary = Ecology.WEATHER[climates[id]]
	for enemy: Dictionary in game.states[id].enemies:
		var ratio := clampf(float(enemy.hp) / float(enemy.get("max_hp", 60)), 0, 1)
		enemy["max_hp"] = int(weather.hp)
		enemy.hp = ceili(ratio * float(weather.hp)) if ratio > 0 else 0
		enemy["weather"] = climates[id]
		enemy["name"] = weather.monster
		enemy["speed"] = weather.speed
		enemy["damage"] = weather.damage
		enemy["tint"] = Color(weather.color)
		enemy["drop"] = weather.drop

func _refresh() -> void:
	garden.size = game.world_canvas.size
	var climate: Dictionary = Ecology.WEATHER[climates[game.region]]
	weather_label.text = "%s · %s属性" % [climate.name, climate.attribute]
	overlay.queue_redraw()
	garden.queue_redraw()

func _draw_garden() -> void:
	if not initialized:
		return
	var font := ThemeDB.fallback_font
	for plot: Dictionary in plots[game.region]:
		var color := Color(Catalog.ITEMS[plot.item].color)
		var progress := float(plot.growth) / float(Ecology.PLANTS[plot.item].time)
		var point: Vector2 = plot.position
		garden.draw_circle(point, 22, Color(0.12, 0.18, 0.1, 0.8))
		garden.draw_arc(point, 22, -PI / 2, -PI / 2 + maxf(0.04, progress * TAU), 28, color, 3, true)
		if plot.ripe:
			garden.draw_circle(point - Vector2(0, 28), 30, Color(color, 0.14))
		if not MaterialArt.draw_plant(garden, plot.item, point, progress, plot.ripe, Vector2(78, 78)):
			garden.draw_line(point, point - Vector2(0, 12 + progress * 16), color, 3, true)
			for side in [-1, 1]:
				var leaf := point + Vector2(side * (7 + progress * 5), -8 - progress * 10)
				garden.draw_circle(leaf, 4 + progress * 3, color)
		if game.player_foot.distance_to(point) < 200:
			var stage := "成熟 · 靠近采集" if plot.ripe else ("生长 %d%%" % int(progress * 100) if Ecology.compatible(plot.item, climates[game.region]) else "待候 %d%%" % int(progress * 100))
			garden.draw_string(font, point + Vector2(-50, 42), "%s · %s" % [Catalog.ITEMS[plot.item].name, stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	for enemy: Dictionary in game.states[game.region].enemies:
		if enemy.has("name"):
			garden.draw_string(font, enemy.position + Vector2(-55, -96), enemy.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, enemy.tint)

func _draw_garden_map() -> void:
	if not initialized:
		return
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for plot: Dictionary in plots[game.region]:
		var point: Vector2 = rect.position + plot.position / Maps.MAPS[game.region].size * rect.size
		game.minimap.draw_circle(point, 3.5, Color("#bce7ad") if plot.ripe else Color("#669b6e"))

func _draw_weather() -> void:
	if not initialized:
		return
	var weather: String = climates[game.region]
	PixelVFX.draw_weather(overlay,weather,overlay.size,elapsed)
