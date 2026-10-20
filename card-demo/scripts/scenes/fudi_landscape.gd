extends RefCounted
## Nine finished map paintings; the remaining snowridge keeps its procedural scenery.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")

static func paint(canvas: CanvasItem, id: String, visible: Rect2) -> void:
	var data: Dictionary = Maps.MAPS[id]
	var extent: Vector2 = data.size
	var ground := Color(data.ground)
	var accent := Color(data.accent)
	if Maps.Art.has_art(id):
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		canvas.draw_texture_rect(Maps.Art.TEXTURES[id], Rect2(Vector2.ZERO, extent), false)
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, extent), ground)
	# Stable terrain patches make distant screens distinct without imported bitmap assets.
	var rng := RandomNumberGenerator.new()
	rng.seed = 431 + Maps.IDS.find(id) * 177
	for i in range(260):
		var point := Vector2(rng.randf_range(50, extent.x - 50), rng.randf_range(50, extent.y - 50))
		var radius := rng.randf_range(22, 100)
		if visible.grow(110).has_point(point):
			canvas.draw_circle(point, radius, Color(ground.lightened(0.13), 0.18))
			canvas.draw_line(point, point + Vector2(18, -8), Color(accent, 0.15), 2, true)
	for road: Array in data.roads:
		var points := PackedVector2Array()
		for point: Vector2 in road:
			points.append(point * extent)
		canvas.draw_polyline(points, Color("#182a2b"), 90, true)
		canvas.draw_polyline(points, Color(data.road), 74, true)
		canvas.draw_polyline(points, Color(accent, 0.23), 3, true)
	for rect: Rect2 in Maps.obstacles(id):
		if not visible.grow(200).intersects(rect):
			continue
		if data.terrain == "garden":
			canvas.draw_style_box(_box(Color("#203e37"), Color("#739276")), rect)
			for x in range(int(rect.position.x) + 30, int(rect.end.x), 45):
				canvas.draw_line(Vector2(x, rect.position.y + 20), Vector2(x, rect.end.y - 20), Color("#516d4a"), 12, true)
		elif data.terrain == "wetland" or data.terrain == "causeway":
			canvas.draw_style_box(_box(Color("#1d414f"), Color("#76a6ab")), rect)
			for n in range(5):
				var y := rect.position.y + (n + 1) * rect.size.y / 6
				canvas.draw_line(Vector2(rect.position.x + 15, y), Vector2(rect.end.x - 15, y - 8), Color("#80c7d0", 0.28), 3, true)
			if data.terrain == "wetland":
				for n in range(6):
					var point := rect.position + Vector2(16 + n * rect.size.x / 7, rect.size.y - 8)
					canvas.draw_line(point, point - Vector2(7, 30), Color("#a5c488"), 3, true)
		elif data.terrain == "quarry" or data.terrain == "snowridge":
			canvas.draw_style_box(_box(Color("#55483e"), Color("#ab9068")), rect)
			for n in range(4):
				var p := rect.position + rect.size * Vector2((n + 0.5) / 4.0, 0.55)
				canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-32, 18), p + Vector2(-20, -34), p + Vector2(22, -45), p + Vector2(44, 10)]), Color("#cedcda") if data.terrain == "snowridge" else Color("#8a7b65"))
		else:
			building(canvas, rect, Color("#46565a") if data.terrain == "archive" else Color("#746855"), accent)
	# Small scenery remains outside the clear roads and authored collision volumes.
	for i in range(85):
		var point := Vector2(rng.randf_range(80, extent.x - 80), rng.randf_range(90, extent.y - 60))
		if not visible.grow(100).has_point(point) or not Maps.walkable(id, point, 45):
			continue
		var on_road := false
		for road: Array in data.roads:
			for n in range(road.size() - 1):
				if Geometry2D.get_closest_point_to_segment(point, road[n] * extent, road[n + 1] * extent).distance_to(point) < 125:
					on_road = true
		if on_road:
			continue
		canvas.draw_circle(point, 27, Color(0.02, 0.04, 0.04, 0.25))
		if data.terrain in ["garden", "camp", "kilnwood"]:
			canvas.draw_line(point, point + Vector2(0, -48), Color("#7d6c50"), 8, true)
			canvas.draw_circle(point + Vector2(0, -57), 36, Color("#484c36") if data.terrain == "kilnwood" else Color("#365948"))
			canvas.draw_circle(point + Vector2(-13, -67), 22, Color("#757b47") if data.terrain == "kilnwood" else Color("#527257"))
		else:
			canvas.draw_style_box(_box(Color("#65716b"), Color("#8c9a8e")), Rect2(point - Vector2(22, 40), Vector2(44, 40)))
	# The boundary is visible and shares the exact movement bounds.
	canvas.draw_rect(Rect2(Vector2(20, 20), extent - Vector2(40, 40)), Color(accent, 0.50), false, 8)

static func _box(color: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	return box

static func building(canvas: CanvasItem, rect: Rect2, wall: Color, accent: Color) -> void:
	canvas.draw_style_box(_box(Color(0.02, 0.03, 0.04, 0.35), Color.TRANSPARENT), Rect2(rect.position + Vector2(16, 20), rect.size))
	canvas.draw_style_box(_box(wall.darkened(0.22), accent.darkened(0.3)), rect)
	var roof := Rect2(rect.position - Vector2(12, 32), Vector2(rect.size.x + 24, rect.size.y * 0.52))
	canvas.draw_style_box(_box(wall.lightened(0.1), accent), roof)
	canvas.draw_line(roof.position + Vector2(12, 12), Vector2(roof.end.x - 12, roof.position.y + 12), Color(accent, 0.6), 4)
	for n in range(3):
		var point := Vector2(rect.position.x + rect.size.x * (n + 1) / 4, rect.end.y - 35)
		canvas.draw_rect(Rect2(point - Vector2(9, 18), Vector2(18, 24)), Color(accent, 0.4))

static func landmark(canvas: CanvasItem, point: Vector2, kind: String, accent: Color, baked: bool = false) -> void:
	canvas.draw_circle(point, 65, Color(accent, 0.08))
	canvas.draw_arc(point, 56, 0, TAU, 48, Color(accent, 0.55), 2, true)
	if baked:
		return # Keep the painted structure visible; only the interaction ring is added.
	match kind:
		"stove", "table", "workshop", "post", "archive", "camp":
			building(canvas, Rect2(point - Vector2(48, 76), Vector2(96, 76)), Color("#675e4f"), accent)
			if kind == "stove":
				canvas.draw_circle(point - Vector2(0, 18), 14, Color("#f7c178"))
			if kind == "post":
				canvas.draw_rect(Rect2(point - Vector2(22, 65), Vector2(44, 28)), Color("#e4d9b1"))
				canvas.draw_line(point - Vector2(22, 65), point - Vector2(0, 47), Color("#897a5e"), 2)
		"tower", "beacon", "terminal":
			canvas.draw_rect(Rect2(point - Vector2(20, 110), Vector2(40, 108)), Color("#647a7b"))
			canvas.draw_circle(point - Vector2(0, 108), 28, accent)
			canvas.draw_circle(point - Vector2(0, 108), 19, Color("#253c43"))
			canvas.draw_line(point - Vector2(0, 108), point - Vector2(-11, 117), accent, 3, true)
			canvas.draw_arc(point - Vector2(0, 108), 38, 0, TAU, 32, Color(accent, 0.2), 3, true)
		"statue":
			canvas.draw_rect(Rect2(point - Vector2(33, 12), Vector2(66, 18)), Color("#758485"))
			canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(-24, -12), point + Vector2(-14, -68), point + Vector2(14, -68), point + Vector2(24, -12)]), Color("#9fa9a4"))
			canvas.draw_circle(point - Vector2(0, 84), 17, Color("#b7bdb2"))
		"garden":
			for n in range(5):
				canvas.draw_circle(point + Vector2((n - 2) * 22, -25), 12, Color("#a4c58a"))
		"letters":
			canvas.draw_rect(Rect2(point - Vector2(58, 78), Vector2(116, 66)), Color("#756b56"))
			for n in range(5):
				canvas.draw_rect(Rect2(point + Vector2(-48 + n * 20, -66 + n % 2 * 16), Vector2(15, 26)), Color("#e3d6b2"))
