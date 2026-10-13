extends Node2D
## Original top-down 2.5D city. Every solid footprint is shared by art, physics and pathfinding.
const BOUNDS := Rect2(64, 300, 1952, 530)
# The painted avenue begins around y=450; the gate has its own northbound approach.
const WALKABLE_AREA := Rect2(70, 450, 1940, 365)
const GATE_APPROACH := Rect2(1880, 430, 100, 180)
const WORLD_SIZE := Vector2(2080, 940)
const CITY_ART := preload("res://assets/backgrounds/city_pet_panorama.png")
const PLAYER_RADIUS := 16.0
const CELL := 20.0
# The illustrated gate is at the upper-right of the panorama, not at the road's far-right edge.
const EXIT_REGIONS := [{"id": "outskirts", "area": Rect2(1919, 447, 40, 27), "arrival": Vector2(140, 576)}]
# Solid ground-contact cores only. Roofs, shadows and the surrounding painted paving
# are not collision: the former broad boxes blocked roads shown in the screenshot.
const OBSTACLES := [
	Rect2(149, 329, 145, 91), # west hall base
	Rect2(449, 338, 112, 78), # covered market base
	Rect2(1022, 328, 144, 90), # east hall base
	Rect2(671, 566, 48, 48), # fountain basin
	Rect2(201, 574, 44, 35), # flower bed
	Rect2(1084, 574, 45, 37), # garden bed
	Rect2(1360, 338, 179, 86), # archives base
	Rect2(1748, 337, 119, 85), # tower base
	Rect2(1514, 677, 43, 37), # east garden bed
	Rect2(1858, 579, 48, 35), # east garden bed
]
var bodies: Array[StaticBody2D] = []

func _ready() -> void:
	for index in range(OBSTACLES.size()):
		var rect: Rect2 = OBSTACLES[index]
		var body := StaticBody2D.new()
		body.name = "Obstacle%d" % index
		body.position = rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		bodies.append(body)
	queue_redraw()

func is_walkable(point: Vector2, radius: float = PLAYER_RADIUS) -> bool:
	var avenue := WALKABLE_AREA.grow(-radius)
	var approach := GATE_APPROACH.grow(-radius)
	if not _inside(point, avenue) and not _inside(point, approach):
		return false
	for rect: Rect2 in OBSTACLES:
		if rect.grow(radius).has_point(point):
			return false
	return true

func _inside(point: Vector2, area: Rect2) -> bool:
	return point.x >= area.position.x and point.x <= area.end.x and point.y >= area.position.y and point.y <= area.end.y

func nearest_walkable(point: Vector2) -> Vector2:
	if is_walkable(point):
		return point
	var avenue := WALKABLE_AREA.grow(-PLAYER_RADIUS)
	var approach := GATE_APPROACH.grow(-PLAYER_RADIUS)
	var on_avenue := Vector2(clampf(point.x, avenue.position.x, avenue.end.x), clampf(point.y, avenue.position.y, avenue.end.y))
	var on_approach := Vector2(clampf(point.x, approach.position.x, approach.end.x), clampf(point.y, approach.position.y, approach.end.y))
	var clamped := on_approach if point.distance_squared_to(on_approach) < point.distance_squared_to(on_avenue) else on_avenue
	if is_walkable(clamped):
		return clamped
	for ring in range(1, 30):
		for sample in range(32):
			var candidate := clamped + Vector2.RIGHT.rotated(TAU * sample / 32.0) * ring * 12.0
			if is_walkable(candidate):
				return candidate
	return Vector2(350, 560)

func find_path(start: Vector2, target: Vector2) -> Array[Vector2]:
	var goal := nearest_walkable(target)
	var origin := nearest_walkable(start)
	var a := _cell(origin)
	var b := _cell(goal)
	if _clear_segment(origin, goal):
		return [goal]
	if a == b:
		return []
	var queue: Array[Vector2i] = [a]
	var previous: Dictionary = {a: a}
	var cursor := 0
	var steps := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	while cursor < queue.size() and queue.size() < 6500:
		var current := queue[cursor]
		cursor += 1
		if current == b:
			break
		for step: Vector2i in steps:
			var next := current + step
			if previous.has(next) or not is_walkable(_center(next)):
				continue
			var from_point := origin if current == a else _center(current)
			if not _clear_segment(from_point, _center(next)):
				continue
			previous[next] = current
			queue.append(next)
	var route: Array[Vector2] = []
	if not previous.has(b):
		return route
	var cell := b
	while cell != a:
		route.push_front(_center(cell))
		cell = previous[cell]
	if _clear_segment(route.back() if not route.is_empty() else origin, goal):
		route.append(goal)
	else:
		# A cell center near a collision corner may not connect to the exact clicked point.
		# Never advertise an incomplete route as reaching the destination.
		return []
	return route

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5) * CELL

func _clear_segment(start: Vector2, target: Vector2) -> bool:
	var count := maxi(1, ceili(start.distance_to(target) / 6.0))
	for i in range(count + 1):
		if not is_walkable(start.lerp(target, float(i) / count)):
			return false
	return true

func _draw() -> void:
	# New illustrated 2.5D city artwork; collision and A* walkability still use the exact OBSTACLES rectangles above.
	var panorama := CITY_ART as Texture2D
	if panorama != null:
		draw_texture_rect(panorama, Rect2(Vector2.ZERO, WORLD_SIZE), false)
		# Keep the painted map unobstructed; walkability and the gate are defined from its landmarks.
		return
	# Fallback when the generated panorama is unavailable.
	# Ground is visibly ABOVE the buildings in a top-down composition; no horizon or pasted backdrop.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#497d69"))
	draw_rect(Rect2(0, 0, 2080, 278), Color("#315d55"))
	for x in range(18, 2100, 72):
		for y in range(20, 940, 69):
			var offset := float((x * 37 + y * 11) % 23)
			draw_circle(Vector2(x + offset, y), 26, Color("#578a70", 0.54))
			draw_circle(Vector2(x + offset - 13, y - 7), 14, Color("#77a67b", 0.37))
	# Walkable broad stone avenue and connected public plazas.
	draw_rect(Rect2(70, 460, 1940, 355), Color("#6e8773"))
	draw_rect(Rect2(82, 473, 1915, 329), Color("#c9b894"))
	draw_rect(Rect2(94, 485, 1890, 306), Color("#dbc9a5"))
	_draw_plaza(Rect2(762, 494, 221, 279))
	_draw_plaza(Rect2(1599, 498, 183, 270))
	for y in range(491, 798, 40):
		for x in range(108 + (24 if int(y / 40) % 2 == 1 else 0), 1970, 65):
			var tile := Rect2(x, y, 47, 25)
			if is_walkable(tile.get_center(), 5.0):
				draw_rect(tile, Color("#f0dfba", 0.26))
				draw_line(tile.position + Vector2(0, 25), tile.end - Vector2(0, 0), Color("#9b8c73", 0.25), 1)
	for x in range(92, 2000, 80):
		draw_line(Vector2(x, 471), Vector2(x + 31, 471), Color("#eee2c1", 0.7), 2)
	# Buildings are drawn from footprint: roof, wall, stair and shadow match their blockers.
	_draw_building(OBSTACLES[0], Color("#3a6a69"), Color("#9cc5b3"), true)
	_draw_building(OBSTACLES[1], Color("#755d52"), Color("#b8aa8a"), false)
	_draw_building(OBSTACLES[2], Color("#476a70"), Color("#abc9ba"), true)
	_draw_building(OBSTACLES[6], Color("#355e68"), Color("#9dc1b8"), true)
	_draw_building(OBSTACLES[7], Color("#536a76"), Color("#a8c4b9"), true)
	_draw_garden(OBSTACLES[3], true)
	for index in [4, 5, 8, 9]:
		_draw_garden(OBSTACLES[index], false)
	# The fallback illustration also exposes the northbound gate approach.
	draw_rect(GATE_APPROACH, Color("#c9b894"))
	var gate: Rect2 = EXIT_REGIONS[0]["area"]
	draw_rect(gate, Color("#e9ca81", 0.46))
	draw_rect(gate, Color("#376b69"), false, 4)
	draw_colored_polygon(PackedVector2Array([gate.get_center() + Vector2(16, 0), gate.get_center() + Vector2(-7, -14), gate.get_center() + Vector2(-7, 14)]), Color("#fff1bf"))
	for x in range(115, 2000, 147):
		_draw_tree(Vector2(x, 864 + sin(x * 0.013) * 14.0))
	for x in [361, 615, 1236, 1630, 1926]:
		_draw_lantern(Vector2(x, 456))

func _draw_plaza(area: Rect2) -> void:
	draw_rect(area, Color("#eee0be"))
	draw_rect(area.grow(-8), Color("#b2ab88"), false, 2)
	for x in range(int(area.position.x) + 18, int(area.end.x) - 8, 42):
		for y in range(int(area.position.y) + 18, int(area.end.y) - 10, 39):
			if is_walkable(Vector2(x, y), 6.0):
				draw_rect(Rect2(x, y, 23, 13), Color("#c6b48f", 0.3))
	var c := area.get_center()
	draw_arc(c, 34, 0, TAU, 48, Color("#659487", 0.7), 4)
	draw_arc(c, 22, 0, TAU, 48, Color("#d6b976"), 3)

func _draw_building(foot: Rect2, roof: Color, trim: Color, grand: bool) -> void:
	var shadow := foot.grow(12)
	shadow.position += Vector2(10, 13)
	draw_rect(shadow, Color("#203d3c", 0.32))
	var wall := Rect2(foot.position + Vector2(3, 23), foot.size - Vector2(6, 25))
	draw_rect(wall, Color("#e3d4b1"))
	draw_rect(Rect2(wall.position.x, foot.end.y - 21, wall.size.x, 18), Color("#bb9e78"))
	for x in range(int(wall.position.x) + 15, int(wall.end.x) - 9, 44):
		draw_rect(Rect2(x, foot.end.y - 19, 8, 17), Color("#806e58"))
	var roof_area := Rect2(foot.position.x - 12, foot.position.y - (14 if grand else 8), foot.size.x + 24, foot.size.y * 0.69)
	draw_colored_polygon(PackedVector2Array([Vector2(roof_area.position.x, roof_area.end.y), Vector2(roof_area.position.x + 22, roof_area.position.y + 8), Vector2(roof_area.get_center().x, roof_area.position.y - 8), Vector2(roof_area.end.x - 22, roof_area.position.y + 8), Vector2(roof_area.end.x, roof_area.end.y)]), roof)
	draw_line(Vector2(roof_area.position.x, roof_area.end.y), Vector2(roof_area.end.x, roof_area.end.y), Color("#223f44"), 5)
	for x in range(int(roof_area.position.x) + 10, int(roof_area.end.x) - 5, 15):
		var t := absf(x - roof_area.get_center().x) / (roof_area.size.x * 0.5)
		var top := roof_area.position.y + 8.0 - (1.0 - t) * 12.0
		draw_line(Vector2(x, top + 9), Vector2(x - 5, roof_area.end.y - 5), trim.darkened(0.22), 1)
	draw_rect(Rect2(roof_area.position.x + 7, roof_area.end.y - 13, roof_area.size.x - 14, 7), trim)
	var entrance := Vector2(foot.get_center().x, foot.end.y)
	draw_rect(Rect2(entrance.x - 25, foot.end.y - 29, 50, 28), Color("#544d41"))
	draw_rect(Rect2(entrance.x - 34, foot.end.y + 1, 68, 9), Color("#d1bd96"))
	draw_rect(Rect2(entrance.x - 42, foot.end.y + 10, 84, 8), Color("#ab9778"))
	for side in [-1, 1]:
		var center := Vector2(entrance.x + side * minf(foot.size.x * 0.33, 77), foot.end.y - 15)
		draw_rect(Rect2(center - Vector2(14, 13), Vector2(28, 25)), Color("#416875"))
		draw_rect(Rect2(center - Vector2(10, 9), Vector2(20, 17)), Color("#a5d5c6"))

func _draw_garden(foot: Rect2, fountain: bool) -> void:
	draw_rect(foot.grow(5), Color("#355a51"))
	draw_rect(foot, Color("#88a478"))
	draw_rect(foot, Color("#d8c499"), false, 6)
	if fountain:
		draw_circle(foot.get_center(), 35, Color("#486d72"))
		draw_circle(foot.get_center(), 29, Color("#81b8b8"))
		draw_circle(foot.get_center(), 15, Color("#cfe3d0"))
		draw_circle(foot.get_center() + Vector2(-7, -8), 4, Color("#eff5df"))
	else:
		for delta in [Vector2(22, 21), Vector2(55, 28), Vector2(40, 52), Vector2(72, 55)]:
			draw_circle(foot.position + delta, 11, Color("#4e8762"))
			draw_circle(foot.position + delta + Vector2(-3, -3), 3, Color("#e6c987"))

func _draw_tree(at: Vector2) -> void:
	draw_circle(at + Vector2(7, 12), 25, Color("#284a44", 0.45))
	draw_circle(at, 24, Color("#326f58"))
	draw_circle(at + Vector2(-9, -8), 17, Color("#5f9d70"))
	draw_circle(at + Vector2(9, -13), 11, Color("#83b481"))

func _draw_lantern(at: Vector2) -> void:
	draw_line(at, at + Vector2(0, -42), Color("#294e50"), 5)
	draw_rect(Rect2(at.x - 11, at.y - 50, 22, 18), Color("#eed49a"))
	draw_circle(at + Vector2(0, -43), 5, Color("#fff1c4"))
	draw_line(at + Vector2(-15, -50), at + Vector2(15, -50), Color("#355d60"), 4)
