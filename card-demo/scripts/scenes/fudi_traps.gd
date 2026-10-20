extends Node
## Local, visible, avoidable hazards. All state belongs to this exploration round.
const Catalog = preload("res://scripts/scenes/trap_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game: Control
var rng := RandomNumberGenerator.new()
var timers: Dictionary = {}
var records: Dictionary = {}
var hazards: Array[Dictionary] = []
var region := ""
var grace := Catalog.ENTRY_GRACE
var slow_left := 0.0
var slow_scale := 1.0
var notice := ""
var notice_left := 0.0
var canvas: Control
var status_label: Label
var initialized := false

func play_visible() -> Array:
	var result: Array = []
	if not initialized or game._paused() or game.finished: return result
	for hazard: Dictionary in hazards:
		var config: Dictionary = Catalog.TRAPS[hazard.kind]
		var center: Vector2 = game.world_to_screen(hazard.position)
		var radius: float = float(config.radius) * game.WORLD_ZOOM
		var bounds: Rect2 = game.ARENA.intersection(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2))
		if not bounds.has_area(): continue
		result.append({"appearance":"红色爆发圈" if float(hazard.age)>=float(config.warning) else "黄色预警圈","visible_bounds":{"x":bounds.position.x,"y":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y}})
	return result

func _ready() -> void:
	process_priority = 20
	call_deferred("initialize")

func initialize() -> void:
	game = get_parent()
	rng.randomize()
	for id: String in Maps.IDS:
		timers[id] = rng.randf_range(Catalog.MIN_INTERVAL, Catalog.MAX_INTERVAL)
		records[id] = {"spawned": 0, "hits": 0, "dodged": 0}
	region = game.region
	canvas = Control.new()
	canvas.size = game.world_canvas.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.z_index = 3
	canvas.draw.connect(_draw_hazards)
	game.world_canvas.add_child(canvas)
	game.minimap.draw.connect(_draw_minimap)
	var panel := PanelContainer.new()
	panel.position = Vector2(380, 12)
	panel.add_theme_stylebox_override("panel", UI.hud_panel(Color(0.09, 0.065, 0.035, 0.9)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.world_view.add_child(panel)
	status_label = UI.label("", 15, Color("#f4cf8b"))
	panel.add_child(status_label)
	initialized = true
	_refresh()

func enter_region(id: String) -> void:
	if not initialized or id == region:
		return
	# Cancel outgoing telegraphs so returning never causes an immediate offscreen hit.
	hazards.clear()
	region = id
	grace = Catalog.ENTRY_GRACE
	slow_left = 0.0
	slow_scale = 1.0
	notice_left = 0.0
	_refresh()

func movement_scale() -> float:
	return slow_scale if slow_left > 0 else 1.0

func summary(id: String) -> String:
	if not Catalog.ENABLED:
		return Catalog.describe(id)
	var record: Dictionary = records[id]
	return "%s\n本轮预警%d次 · 命中%d次 · 闪避%d次。转图取消正在发生的危险，保留本地倒计时。" % [Catalog.describe(id), record.spawned, record.hits, record.dodged]

func _process(delta: float) -> void:
	if not initialized:
		return
	if game.is_processing():
		# Match the movement time cap; a lag spike cannot consume an entire warning.
		tick(minf(delta, 0.1))
	_refresh()

func tick(delta: float) -> void:
	if not Catalog.ENABLED or not initialized or game.finished or game._paused() or delta <= 0:
		return
	if region != game.region:
		enter_region(game.region)
	slow_left = maxf(0, slow_left - delta)
	notice_left = maxf(0, notice_left - delta)
	if grace > 0:
		grace = maxf(0, grace - delta)
		return
	if not hazards.is_empty():
		_advance_hazards(delta)
		return
	timers[region] = maxf(0, float(timers[region]) - delta)
	if float(timers[region]) <= 0:
		var kind := choose_kind(region)
		var point := choose_point(region, float(Catalog.TRAPS[kind].radius))
		if point == Vector2.INF or not spawn(kind, point):
			timers[region] = 2.0 # Nothing safe and visible nearby; try again later.

func choose_kind(id: String) -> String:
	var choices: Array[String] = []
	var weather: String = game.states[id].get("weather", "")
	for kind: String in Catalog.REGIONS[id]:
		choices.append(kind)
		if weather in Catalog.TRAPS[kind].weather:
			choices.append(kind) # Matching climate has twice the selection weight.
	return choices[rng.randi_range(0, choices.size() - 1)]

func safe_zone(id: String, point: Vector2, radius: float = 0.0) -> bool:
	var data: Dictionary = Maps.MAPS[id]
	if point.distance_to(data.spawn * data.size) <= 220 + radius:
		return true
	for site: Array in data.sites:
		if point.distance_to(site[1] * data.size) <= 135 + radius:
			return true
	for exit: Array in data.exits:
		if point.distance_to(exit[1] * data.size) <= 150 + radius:
			return true
	return false

func valid_point(id: String, point: Vector2, radius: float) -> bool:
	return Maps.walkable(id, point, radius + 12) and not safe_zone(id, point, radius)

func choose_point(id: String, radius: float) -> Vector2:
	var visible: Rect2 = game.visible_world().grow(-radius - 10)
	for attempt in range(48):
		var angle := rng.randf_range(0, TAU)
		var distance := rng.randf_range(0, 40) if rng.randf() < 0.35 else rng.randf_range(65, 145)
		var point: Vector2 = game.player_foot + Vector2.from_angle(angle) * distance
		if visible.has_point(point) and valid_point(id, point, radius):
			return point
		if Maps.Art.has_art(id):
			# Narrow bridges need candidates on their visible lane, with the same safety checks.
			var nearest := Vector2.INF
			var nearest_distance := INF
			for road: Array in Maps.MAPS[id].roads:
				for i in range(road.size() - 1):
					var candidate := Geometry2D.get_closest_point_to_segment(point, road[i] * Maps.MAPS[id].size, road[i + 1] * Maps.MAPS[id].size)
					var lane_distance := point.distance_squared_to(candidate)
					if lane_distance < nearest_distance:
						nearest_distance = lane_distance
						nearest = candidate
			if nearest.distance_to(game.player_foot) <= 145 and visible.has_point(nearest) and valid_point(id, nearest, radius):
				return nearest
	return Vector2.INF

func spawn(kind: String, point: Vector2) -> bool:
	if not Catalog.ENABLED or not initialized or game.finished or game._paused() or not hazards.is_empty() or grace > 0:
		return false
	if not kind in Catalog.REGIONS[region] or not valid_point(region, point, float(Catalog.TRAPS[kind].radius)):
		return false
	var config: Dictionary = Catalog.TRAPS[kind]
	var boosted: bool = game.states[region].get("weather", "") in config.weather
	hazards.append({"kind": kind, "position": point, "age": 0.0, "hit": false, "boosted": boosted, "damage": int(config.damage) + (2 if boosted else 0)})
	records[region].spawned += 1
	timers[region] = rng.randf_range(Catalog.MIN_INTERVAL, Catalog.MAX_INTERVAL)
	return true

func _advance_hazards(delta: float) -> void:
	for index in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[index]
		var config: Dictionary = Catalog.TRAPS[hazard.kind]
		hazard.age += delta
		if float(hazard.age) >= float(config.warning):
			_try_hit(hazard, config)
		if float(hazard.age) >= float(config.warning) + float(config.active):
			if not hazard.hit:
				records[region].dodged += 1
			hazards.remove_at(index)

func _try_hit(hazard: Dictionary, config: Dictionary) -> void:
	if hazard.hit or game.hurt_timer > 0 or game.finished or safe_zone(region, game.player_foot):
		return
	if game.player_foot.distance_to(hazard.position) > float(config.radius):
		return
	hazard.hit = true
	records[region].hits += 1
	var damage: int = game.incoming_damage(int(hazard.damage))
	game.health = maxi(0, game.health - damage)
	game.hurt_timer = 1.0
	if float(config.duration) > 0:
		slow_left = maxf(slow_left, float(config.duration))
		slow_scale = float(config.slow)
	if float(config.push) > 0:
		var direction: Vector2 = (game.player_foot - Vector2(hazard.position)).normalized()
		if direction == Vector2.ZERO:
			direction = game.facing
		game.player_foot = game.move_world(game.player_foot, direction * float(config.push))
		game.model.position = game.player_foot
		game._update_camera()
	notice = "%s命中：-%d生命%s" % [config.name, damage, "，暂时减速" if float(config.duration) > 0 else "，被击退"]
	notice_left = 2.5
	if game.health <= 0:
		game._end_round(false)
	game._refresh_ui()

func _refresh() -> void:
	canvas.size = game.world_canvas.size
	if not hazards.is_empty():
		var hazard: Dictionary = hazards[0]
		var config: Dictionary = Catalog.TRAPS[hazard.kind]
		var countdown := maxf(0, float(config.warning) - float(hazard.age))
		status_label.text = "%s · %s" % [config.name, "%.1f秒后爆发，离开黄圈" % countdown if countdown > 0 else "危险！远离红圈"]
	elif notice_left > 0:
		status_label.text = notice
	else:
		status_label.text = ""
	if slow_left > 0:
		status_label.text += "  减速 %.1fs" % slow_left
	status_label.get_parent().visible = not hazards.is_empty() or notice_left > 0 or slow_left > 0
	canvas.queue_redraw()
	game.minimap.queue_redraw()

func _draw_hazards() -> void:
	if not initialized:
		return
	for hazard: Dictionary in hazards:
		var config: Dictionary = Catalog.TRAPS[hazard.kind]
		var point: Vector2 = hazard.position
		var active: bool = float(hazard.age) >= float(config.warning)
		var color := Color("#f27866") if active else Color("#f1cd70")
		var radius: float = config.radius
		canvas.draw_circle(point, radius, Color(color, 0.23 if active else 0.11))
		canvas.draw_arc(point, radius, 0, TAU, 48, color, 3, true)
		if not active:
			canvas.draw_arc(point, radius - 7, -PI / 2, -PI / 2 + TAU * float(hazard.age) / float(config.warning), 40, Color(config.color), 4, true)
			canvas.draw_line(point - Vector2(12, 12), point + Vector2(12, 12), color, 3, true)
			canvas.draw_line(point + Vector2(12, -12), point + Vector2(-12, 12), color, 3, true)
		else:
			_draw_effect(hazard.kind, point, radius, Color(config.color))
		canvas.draw_string(ThemeDB.fallback_font, point + Vector2(-52, radius + 23), "%s · %s" % [config.name, "爆发" if active else "%.1fs" % (float(config.warning) - float(hazard.age))], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)

func _draw_effect(kind: String, point: Vector2, radius: float, color: Color) -> void:
	match kind:
		"thorns", "frost":
			for index in range(8):
				var tip := point + Vector2.from_angle(index * TAU / 8) * radius * 0.8
				canvas.draw_line(point, tip, color, 4, true)
				canvas.draw_line(tip, tip + Vector2(-8, 14), color, 3, true)
		"spores":
			for index in range(12):
				canvas.draw_circle(point + Vector2.from_angle(index * 2.4) * (18 + index * 3), 7, Color(color, 0.75))
		"floor", "sign", "rockfall":
			for index in range(5):
				var offset := Vector2((index - 2) * 18, sin(index * 2) * 22)
				canvas.draw_style_box(UI.panel(Color(color, 0.8)), Rect2(point + offset - Vector2(9, 12), Vector2(18, 24)))
		"fissure", "surge":
			var points := PackedVector2Array()
			for index in range(7):
				points.append(point + Vector2((index - 3) * 17, -18 if index % 2 == 0 else 18))
			canvas.draw_polyline(points, color, 6, true)
		"geyser":
			for index in range(3):
				canvas.draw_arc(point, radius * (0.3 + index * 0.25), 0, TAU, 30, color, 4, true)
		"debris":
			for index in range(5):
				canvas.draw_line(point + Vector2(-45, (index - 2) * 17), point + Vector2(45, (index - 2) * 17 - 12), color, 4, true)

func _draw_minimap() -> void:
	if not initialized:
		return
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for hazard: Dictionary in hazards:
		var point: Vector2 = rect.position + hazard.position / Maps.MAPS[region].size * rect.size
		var color := Color("#f27866") if float(hazard.age) >= float(Catalog.TRAPS[hazard.kind].warning) else Color("#f1cd70")
		game.minimap.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 4), point + Vector2(-5, 4)]), color)
