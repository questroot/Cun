extends Node
## Scene-owned ecology. Existing wild pickups remain; six renewable plots grow per map.
const Ecology = preload("res://scripts/scenes/weather_ecology.gd")
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game: Control
var elapsed := 0.0
var climates: Dictionary = {}
var plots: Dictionary = {}
var overlay: Control
var garden: Control
var weather_label: Label
var initialized := false

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
	overlay.size = game.ARENA.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_weather)
	game.world_view.add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 8)
	panel.add_theme_stylebox_override("panel", UI.panel(Color(0.04, 0.09, 0.12, 0.87)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)
	weather_label = UI.label("", 16)
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
	weather_label.text = "%s  |  小地图绿点：再生药圃 · 成熟后靠近采集  |  B 生态" % Ecology.describe(game.region, elapsed)
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
	var area := overlay.size
	var weather: String = climates[game.region]
	var color := Color(Ecology.WEATHER[weather].color)
	var clock := elapsed
	if weather == "fog":
		overlay.draw_rect(Rect2(Vector2.ZERO, area), Color(color, 0.09))
		for i in range(8):
			var x := fposmod(i * 193.0 + clock * 13, area.x + 200) - 100
			overlay.draw_circle(Vector2(x, 110 + sin(i * 2.4 + clock * 0.15) * 120), 125, Color(color, 0.035))
	elif weather == "heat":
		overlay.draw_rect(Rect2(Vector2.ZERO, area), Color(color, 0.045))
		for i in range(20):
			var point := Vector2(fposmod(i * 127.0 + sin(clock + i) * 12, area.x), area.y - fposmod(i * 53 + clock * 20, area.y))
			overlay.draw_circle(point, 2, Color(color, 0.5))
	elif weather in ["rain", "storm", "snow", "wind"]:
		for i in range(65 if weather != "wind" else 24):
			var point := Vector2(fposmod(i * 137.0 + clock * (35 if weather == "snow" else 90), area.x), fposmod(i * 73.0 + clock * (24 if weather == "snow" else 290), area.y))
			if weather == "snow":
				overlay.draw_circle(point, 2 + i % 2, Color(color, 0.7))
			else:
				overlay.draw_line(point, point + (Vector2(28, -4) if weather == "wind" else Vector2(-7, 16)), Color(color, 0.45), 1, true)
		if weather == "storm" and fmod(clock, 8) < 0.10:
			overlay.draw_rect(Rect2(Vector2.ZERO, area), Color(color, 0.07))
	else:
		for i in range(16):
			var point := Vector2(fposmod(i * 173.0 + clock * 9, area.x), 80 + fposmod(i * 61.0 + sin(clock * 0.8 + i) * 12, area.y - 80))
			overlay.draw_circle(point, 2, Color(color, 0.55))
