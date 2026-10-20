extends RefCounted
## Finished map paintings. Navigation follows the visible roads, never image color guesses.
const TEXTURES := {
	"grove": preload("res://assets/backgrounds/fudi/grove.webp"),
	"post": preload("res://assets/backgrounds/fudi/post.webp"),
	"quarry": preload("res://assets/backgrounds/fudi/quarry.webp"),
	"ruins": preload("res://assets/backgrounds/fudi/ruins.webp"),
	"refuge": preload("res://assets/backgrounds/fudi/refuge.webp"),
	"wetland": preload("res://assets/backgrounds/fudi/wetland.webp"),
	"causeway": preload("res://assets/backgrounds/fudi/causeway.webp"),
	"kilnwood": preload("res://assets/backgrounds/fudi/kilnwood.webp"),
	"archive": preload("res://assets/backgrounds/fudi/archive.webp"),
}
static var layouts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/backgrounds/fudi/manifest.json")).maps

static func has_art(id: String) -> bool:
	return TEXTURES.has(id)

static func apply_layouts(original: Dictionary) -> Dictionary:
	var result := original.duplicate(true)
	for id: String in layouts:
		var config: Dictionary = layouts[id]
		var data: Dictionary = result[id]
		data.spawn = Vector2(config.spawn[0], config.spawn[1])
		data.roads = []
		for lane: Array in config.roads:
			var points := []
			for point: Array in lane:
				points.append(Vector2(point[0], point[1]))
			data.roads.append(points)
		data.obstacles = []
		for block: Array in config.obstacles:
			data.obstacles.append(Rect2(block[0], block[1], block[2], block[3]))
		for i in range(data.sites.size()):
			data.sites[i][1] = Vector2(config.sites[i][0], config.sites[i][1])
		data.exits[0][1] = data.roads[0][0]
		data.exits[1][1] = data.roads[0][-1]
		data.exits[2][1] = data.roads[1][-1]
		data.art_radius = float(config.half_width)
	return result

static func on_ground(data: Dictionary, point: Vector2, margin: float) -> bool:
	var radius := float(data.art_radius) - margin
	if radius < 0:
		return false
	var extent: Vector2 = data.size
	for road: Array in data.roads:
		for i in range(road.size() - 1):
			if Geometry2D.get_closest_point_to_segment(point, road[i] * extent, road[i + 1] * extent).distance_squared_to(point) <= radius * radius:
				return true
	return false
