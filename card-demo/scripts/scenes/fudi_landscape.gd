extends RefCounted
## Map paintings and roadside props; snowridge retains its authored ground geometry.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Art = preload("res://scripts/scenes/fudi_material_art.gd")
const Buildings = preload("res://scripts/scenes/building_catalog.gd")
const SCENERY := {
	"grove": [["camphor", Vector2(0.19, 0.42)], ["shrub", Vector2(0.23, 0.35)], ["camphor", Vector2(0.60, 0.63)], ["shrub", Vector2(0.75, 0.55)]],
	"post": [["camphor", Vector2(0.35, 0.38)], ["shrub", Vector2(0.19, 0.39)], ["camphor", Vector2(0.60, 0.88)], ["shrub", Vector2(0.62, 0.43)]],
	"quarry": [["pine", Vector2(0.46, 0.45)], ["shrub", Vector2(0.56, 0.55)], ["pine", Vector2(0.70, 0.27)], ["shrub", Vector2(0.21, 0.30)]],
	"ruins": [["lotus", Vector2(0.22, 0.24)], ["reeds", Vector2(0.26, 0.37)], ["lotus", Vector2(0.56, 0.75)], ["reeds", Vector2(0.86, 0.44)]],
	"refuge": [["pine", Vector2(0.30, 0.24)], ["shrub", Vector2(0.19, 0.43)], ["pine", Vector2(0.66, 0.44)], ["shrub", Vector2(0.67, 0.77)]],
	"wetland": [["reeds", Vector2(0.24, 0.56)], ["lotus", Vector2(0.54, 0.44)], ["reeds", Vector2(0.74, 0.70)], ["lotus", Vector2(0.77, 0.33)]],
	"causeway": [["reeds", Vector2(0.20, 0.29)], ["lotus", Vector2(0.40, 0.53)], ["reeds", Vector2(0.60, 0.72)], ["lotus", Vector2(0.81, 0.36)]],
	"kilnwood": [["charred_pine", Vector2(0.20, 0.40)], ["pine", Vector2(0.70, 0.44)], ["charred_pine", Vector2(0.43, 0.85)], ["pine", Vector2(0.39, 0.20)]],
	"archive": [["lotus", Vector2(0.18, 0.45)], ["shrub", Vector2(0.70, 0.46)], ["camphor", Vector2(0.87, 0.61)], ["reeds", Vector2(0.42, 0.40)]],
	"snowridge": [["snow_pine", Vector2(0.17, 0.44)], ["snow_pine", Vector2(0.29, 0.58)], ["snow_pine", Vector2(0.53, 0.16)], ["snow_pine", Vector2(0.66, 0.68)]],
}

static func paint(canvas: CanvasItem, id: String, visible: Rect2) -> void:
	var data: Dictionary = Maps.MAPS[id]
	var extent: Vector2 = data.size
	var ground := Color(data.ground)
	var accent := Color(data.accent)
	if Maps.Art.has_art(id):
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		canvas.draw_texture_rect(Maps.Art.TEXTURES[id], Rect2(Vector2.ZERO, extent), false)
		draw_scenery(canvas, id, visible)
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
	var obstacles := Maps.obstacles(id)
	for index in range(obstacles.size()):
		if index == 2: continue # The independent building sprite supplies this silhouette.
		var rect: Rect2 = obstacles[index]
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
	draw_scenery(canvas, id, visible)
	# The boundary is visible and shares the exact movement bounds.
	canvas.draw_rect(Rect2(Vector2(20, 20), extent - Vector2(40, 40)), Color(accent, 0.50), false, 8)

static func draw_scenery(canvas: CanvasItem, id: String, visible: Rect2) -> void:
	var data: Dictionary = Maps.MAPS[id]
	var building := Art.building_rect(id, Buildings.entrance(id))
	# Authored ground/water placements avoid putting tree roots into painted rivers.
	for prop: Array in SCENERY[id]:
		var point: Vector2 = prop[1] * data.size
		var art: Texture2D = Art.SCENERY[prop[0]]
		var size: Vector2 = art.get_size()
		size *= (260.0 if prop[0] in ["camphor", "pine", "charred_pine", "snow_pine"] else 115.0) / size.y
		var rect := Rect2(point - Vector2(size.x * 0.5, size.y), size)
		if not visible.intersects(rect) or building.intersects(rect): continue
		canvas.draw_set_transform(point, 0, Vector2(1, 0.25))
		canvas.draw_circle(Vector2.ZERO, size.x * 0.25, Color(0.02, 0.04, 0.04, 0.23))
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_texture_rect(art, rect, false)

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
