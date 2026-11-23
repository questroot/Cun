extends RefCounted
## Visuals outlive defeated combat targets and use the scene's active time.
const HIT_FLASH := 0.14
const GUARD_SIZE := Vector2(76, 76)
const CHEST_GUARD_SIZE := Vector2(66, 66)
const BOSS_SCALE := 1.08
const CHEST_BOSS_SCALE := 0.72
const STONE := preload("res://assets/characters/pet_enemy_stone.png")
const Bosses := preload("res://scripts/scenes/boss_catalog.gd")
const PixelVFX := preload("res://scripts/scenes/pixel_vfx.gd")
var bursts: Array[Dictionary] = []

func record(enemy: Dictionary, direction: Vector2, ailment: String) -> void:
	var fallen: bool = enemy.hp == 0
	var boss := enemy.has("skill_index")
	var chest_guard := enemy.has("art") if boss else enemy.has("paid")
	var effect := {
		"point": enemy.position,
		"direction": direction,
		"boss": boss,
		"fallen": fallen,
		"age": 0.0,
		"duration": (0.80 if boss else 0.56) if fallen else 0.24,
		"color": Color("#efd3ff") if chest_guard else Color.WHITE,
	}
	if fallen:
		var art: Texture2D = STONE
		var extent := GUARD_SIZE
		var tint := Color("#dfb8ef") if chest_guard else Color(enemy.get("tint", Color.WHITE))
		if boss:
			art = Bosses.ART[enemy.id]
			extent = art.get_size() * (CHEST_BOSS_SCALE if chest_guard else BOSS_SCALE)
		elif chest_guard:
			extent = CHEST_GUARD_SIZE
		effect.merge({"art": art, "extent": extent, "tint": tint})
	if ailment != "":
		effect.merge({"ailment": ailment, "target": enemy})
	bursts.append(effect)

func tick(delta: float) -> void:
	for i in range(bursts.size() - 1, -1, -1):
		bursts[i].age += delta
		if bursts[i].age >= bursts[i].duration:
			bursts.remove_at(i)

static func draw_actor(canvas: Control, enemy: Dictionary, art: Texture2D, extent: Vector2, tint: Color, lean: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	var point: Vector2 = enemy.position
	var recoil := float(enemy.flash) / HIT_FLASH
	if recoil > 0.0:
		var direction: Vector2 = enemy.hit_direction
		point += direction * minf(extent.x * 0.10, 13.0) * recoil
		lean += direction.x * 0.19 * recoil
		scale *= Vector2(1.0 + 0.10 * recoil, 1.0 - 0.14 * recoil)
		tint = tint.lerp(Color(1.5, 0.86, 0.68), recoil)
	_draw_sprite(canvas, art, extent, point, lean, scale, tint)

static func _draw_sprite(canvas: Control, art: Texture2D, extent: Vector2, point: Vector2, lean: float, scale: Vector2, tint: Color) -> void:
	canvas.draw_set_transform(point, lean, scale)
	canvas.draw_texture_rect(art, Rect2(Vector2(-extent.x * 0.5, -extent.y), extent), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)

func draw(canvas: Control) -> void:
	for effect: Dictionary in bursts:
		var progress: float = effect.age / effect.duration
		var point: Vector2 = effect.point
		var direction: Vector2 = effect.direction
		var size := 2.0 if effect.boss else 1.0
		var center := point - Vector2(0, 34 * size)
		var color: Color = effect.color
		if effect.fallen:
			var collapse := ease(progress, 0.5)
			var recoil_distance := 33.0 if effect.boss else 20.0
			var tint: Color = effect.tint.lerp(Color(1.55, 1.30, 1.02), maxf(0, 1.0 - progress * 5.0))
			tint.a = 1.0 - smoothstep(0.12, 0.92, progress)
			_draw_sprite(canvas, effect.art, effect.extent, point + direction * recoil_distance * collapse,
				direction.x * 0.58 * collapse, Vector2(1.0 + 0.14 * collapse, 1.0 - 0.60 * collapse), tint)
			PixelVFX.draw(canvas, "impact-fallen", center, progress * PixelVFX.LIFETIME, Vector2.ONE * size, 0.0, color)
		else:
			PixelVFX.draw(canvas, "impact-enemy", center, progress * PixelVFX.LIFETIME, Vector2.ONE * size, direction.angle(), color)
		if effect.has("ailment"):
			var attached: Vector2 = effect.target.position - Vector2(0, 35 * size)
			PixelVFX.draw(canvas, effect.ailment, attached, effect.age, Vector2.ONE * size, 0.0, Color(1, 1, 1, 1.0 - progress))
