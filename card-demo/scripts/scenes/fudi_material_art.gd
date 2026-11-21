extends RefCounted
## Transparent runtime art from the approved Fudi paintings.

const BUILDINGS := {
	"grove": preload("res://assets/fudi/fine/buildings/grove.png"),
	"post": preload("res://assets/fudi/fine/buildings/post.png"),
	"quarry": preload("res://assets/fudi/fine/buildings/quarry.png"),
	"ruins": preload("res://assets/fudi/fine/buildings/ruins.png"),
	"refuge": preload("res://assets/fudi/fine/buildings/refuge.png"),
	"wetland": preload("res://assets/fudi/fine/buildings/wetland.png"),
	"causeway": preload("res://assets/fudi/fine/buildings/causeway.png"),
	"kilnwood": preload("res://assets/fudi/fine/buildings/kilnwood.png"),
	"archive": preload("res://assets/fudi/fine/buildings/archive.png"),
	"snowridge": preload("res://assets/fudi/fine/buildings/snowridge.png"),
}

const SCENERY := {
	"camphor": preload("res://assets/fudi/fine/scenery/camphor.png"),
	"pine": preload("res://assets/fudi/fine/scenery/pine.png"),
	"charred_pine": preload("res://assets/fudi/fine/scenery/charred_pine.png"),
	"snow_pine": preload("res://assets/fudi/fine/scenery/snow_pine.png"),
	"reeds": preload("res://assets/fudi/fine/scenery/reeds.png"),
	"lotus": preload("res://assets/fudi/fine/scenery/lotus.png"),
	"shrub": preload("res://assets/fudi/fine/scenery/shrub.png"),
}

static func building_rect(id: String, door: Vector2) -> Rect2:
	# Keep the full sprite outside the existing painted travel lanes.
	const LAYOUT := {
		"grove": [Vector2(0, -135), 720.0], "post": [Vector2(0, -135), 720.0],
		"quarry": [Vector2(0, -175), 720.0], "ruins": [Vector2(0, -175), 720.0],
		"refuge": [Vector2(0, -135), 720.0], "wetland": [Vector2(280, -215), 640.0],
		"causeway": [Vector2(-480, -135), 600.0], "kilnwood": [Vector2(40, -135), 720.0],
		"archive": [Vector2(0, -175), 720.0], "snowridge": [Vector2(0, -135), 720.0],
	}
	var size: Vector2 = BUILDINGS[id].get_size()
	size *= minf(LAYOUT[id][1] / size.x, 440.0 / size.y)
	return Rect2(door + LAYOUT[id][0] - Vector2(size.x * 0.5, size.y), size)

const CHESTS := {
	"normal_closed": preload("res://assets/fudi/fine/chests/normal_closed.png"),
	"normal_open": preload("res://assets/fudi/fine/chests/normal_open.png"),
	"mutated_closed": preload("res://assets/fudi/fine/chests/mutated_closed.png"),
	"mutated_guarding": preload("res://assets/fudi/fine/chests/mutated_guarding.png"),
	"mutated_cleared": preload("res://assets/fudi/fine/chests/mutated_cleared.png"),
	"mutated_open": preload("res://assets/fudi/fine/chests/mutated_open.png"),
}

const HERBS := {
	"bloodgrass": preload("res://assets/fudi/fine/herbs/bloodgrass.png"),
	"dewleaf": preload("res://assets/fudi/fine/herbs/dewleaf.png"),
	"berry": preload("res://assets/fudi/fine/herbs/berry.png"),
	"wakeleaf": preload("res://assets/fudi/fine/herbs/wakeleaf.png"),
	"restflower": preload("res://assets/fudi/fine/herbs/restflower.png"),
	"herb": preload("res://assets/fudi/fine/herbs/herb.png"),
	"warmflower": preload("res://assets/fudi/fine/herbs/warmflower.png"),
	"moss": preload("res://assets/fudi/fine/herbs/moss.png"),
	"mint": preload("res://assets/fudi/fine/herbs/mint.png"),
	"rush": preload("res://assets/fudi/fine/herbs/rush.png"),
	"bitterroot": preload("res://assets/fudi/fine/herbs/bitterroot.png"),
}

const PLANTS := {
	"bloodgrass": preload("res://assets/fudi/fine/plants/bloodgrass.png"),
	"dewleaf": preload("res://assets/fudi/fine/plants/dewleaf.png"),
	"berry": preload("res://assets/fudi/fine/plants/berry.png"),
	"wakeleaf": preload("res://assets/fudi/fine/plants/wakeleaf.png"),
	"restflower": preload("res://assets/fudi/fine/plants/restflower.png"),
	"herb": preload("res://assets/fudi/fine/plants/herb.png"),
	"warmflower": preload("res://assets/fudi/fine/plants/warmflower.png"),
	"moss": preload("res://assets/fudi/fine/plants/moss.png"),
	"mint": preload("res://assets/fudi/fine/plants/mint.png"),
	"rush": preload("res://assets/fudi/fine/plants/rush.png"),
}

static func chest_texture(mutated: bool, state: String) -> Texture2D:
	if not mutated:
		return CHESTS.normal_open if state == "opened" else CHESTS.normal_closed
	match state:
		"guarding":
			return CHESTS.mutated_guarding
		"cleared":
			return CHESTS.mutated_cleared
		"opened":
			return CHESTS.mutated_open
		_:
			return CHESTS.mutated_closed

static func herb_icon(item: String) -> Texture2D:
	return HERBS.get(item) as Texture2D

static func has_plant(item: String) -> bool:
	return PLANTS.has(item)

static func draw_chest(canvas: CanvasItem, art: Texture2D, point: Vector2, extent: float, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect(art, Rect2(point - Vector2(extent * 0.5, extent), Vector2.ONE * extent), false, tint)

static func draw_plant(canvas: CanvasItem, item: String, point: Vector2, progress: float, ripe: bool, extent: Vector2 = Vector2(78, 78)) -> bool:
	var atlas: Texture2D = PLANTS.get(item) as Texture2D
	if atlas == null:
		var icon := herb_icon(item)
		if icon == null:
			return false
		var grow := 0.45 + clampf(progress, 0.0, 1.0) * 0.55
		var size := extent * grow
		canvas.draw_texture_rect(icon, Rect2(point - Vector2(size.x * 0.5, size.y), size), false)
		return true
	var stage := 2 if ripe else clampi(int(floor(clampf(progress, 0.0, 0.999) * 3.0)), 0, 2)
	var cell := atlas.get_width() / 3.0
	canvas.draw_texture_rect_region(atlas, Rect2(point - Vector2(extent.x * 0.5, extent.y), extent), Rect2(stage * cell, 0, cell, atlas.get_height()))
	return true
