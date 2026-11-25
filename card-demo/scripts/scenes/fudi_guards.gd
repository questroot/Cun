extends Node
## Three readable attacks. Warnings lock their aim; travel cancels attacks and shots.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const PixelVFX = preload("res://scripts/scenes/pixel_vfx.gd")
const NAMES := {"melee": "蓄力守卫", "ranged": "投石守卫", "charger": "冲锋守卫"}
const KINDS := ["melee", "ranged", "charger"]
const SHOT_SPEED := 310.0
const SHOT_LIFE := 1.6
const HIT_AILMENTS := {"heat": "status-burn", "snow": "status-freeze", "storm": "status-stun"}
var game
var shots: Array[Dictionary] = []

static func create(point: Vector2, behavior: String) -> Dictionary:
	var enemy := {"position": point, "home": point, "hp": 60, "max_hp": 60, "flash": 0.0, "behavior": behavior, "speed": 76.0, "damage": 10, "weather": "clear", "name": "石灵"}
	reset(enemy)
	return enemy

func _ready() -> void:
	game = get_parent()
	game.world_canvas.draw.connect(draw_world)

static func reset(enemy: Dictionary) -> void:
	enemy.merge({"guard_phase": "idle", "guard_left": 1.0, "guard_target": enemy.position, "guard_direction": Vector2.RIGHT, "guard_hit": false}, true)

func enter_region() -> void:
	shots.clear()
	for enemy: Dictionary in game.states[game.region].enemies: reset(enemy)

func tick(delta: float) -> void:
	if game._paused() or game.finished or delta <= 0: return
	for enemy: Dictionary in game.states[game.region].enemies:
		if enemy.hp <= 0: continue
		enemy.flash = maxf(0, float(enemy.flash) - delta)
		enemy["attack_fx"] = maxf(0, float(enemy.get("attack_fx", 0.0)) - delta)
		var attack_step := minf(delta, float(enemy.guard_left))
		enemy.guard_left = maxf(0, float(enemy.guard_left) - delta)
		var offset: Vector2 = game.player_foot - enemy.position
		var slow: float = game.equipment.effects.enemy_speed_scale(enemy)
		match enemy.guard_phase:
			"windup":
				if enemy.guard_left == 0: release(enemy)
			"charge":
				var start: Vector2 = enemy.position
				enemy.position = game.move_world(start, enemy.guard_direction * 620.0 * slow * attack_step)
				var nearest := Geometry2D.get_closest_point_to_segment(game.player_foot, start, enemy.position)
				if not enemy.guard_hit and nearest.distance_to(game.player_foot) <= 32:
					hit(enemy.damage, enemy.weather, enemy.guard_direction)
					enemy.guard_hit = true
				if enemy.guard_left == 0 or enemy.position.distance_to(start) < 1: recover(enemy)
			"recover":
				if enemy.guard_left == 0: enemy.guard_phase = "idle"
			"idle":
				if offset.length() > 420 or not game.get_node("Bosses").visible_path(enemy.position, game.player_foot): continue
				var reach: float = {"melee": 95.0, "ranged": 340.0, "charger": 260.0}[enemy.behavior]
				if offset.length() <= reach and enemy.guard_left == 0:
					enemy.guard_phase = "windup"
					enemy.guard_left = 0.9 if enemy.behavior == "charger" else 0.65
					enemy.guard_direction = offset.normalized() if offset.length() > 0 else Vector2.RIGHT
					enemy.guard_target = enemy.position + enemy.guard_direction * (45.0 if enemy.behavior == "melee" else 220.0)
				elif offset.length() > reach * 0.8:
					enemy.position = game.move_world(enemy.position, offset.normalized() * float(enemy.speed) * slow * delta)
				elif enemy.behavior == "ranged" and offset.length() < 140:
					enemy.position = game.move_world(enemy.position, -offset.normalized() * float(enemy.speed) * slow * delta)
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		if shot.owner.hp <= 0:
			shots.remove_at(i)
			continue
		var start: Vector2 = shot.position
		var end: Vector2 = start + shot.velocity * minf(delta, shot.life)
		var distance: float = start.distance_to(end)
		# Sweep in order: a wall before the player absorbs the shot.
		var stopped := false
		for sample in range(1, maxi(1, ceili(distance / 8.0)) + 1):
			shot.position = start.lerp(end, float(sample) / maxi(1, ceili(distance / 8.0)))
			if not Maps.walkable(game.region, shot.position, 0):
				stopped = true
				break
			if shot.position.distance_to(game.player_foot) <= 22:
				hit(shot.damage, shot.weather, shot.velocity.normalized())
				stopped = true
				break
		shot.life -= delta
		if stopped or shot.life <= 0: shots.remove_at(i)
	if game.health <= 0: game._end_round(false)

func release(enemy: Dictionary) -> void:
	enemy["attack_fx"] = PixelVFX.LIFETIME
	enemy["attack_weather"] = enemy.weather
	enemy["attack_point"] = enemy.guard_target
	match enemy.behavior:
		"melee":
			if game.player_foot.distance_to(enemy.guard_target) <= 66 and game.get_node("Bosses").visible_path(enemy.position, game.player_foot): hit(enemy.damage, enemy.weather, enemy.guard_direction)
			recover(enemy)
		"ranged":
			shots.append({"owner": enemy, "position": enemy.position, "velocity": enemy.guard_direction * SHOT_SPEED, "damage": enemy.damage, "life": SHOT_LIFE, "weather": enemy.weather})
			recover(enemy)
		"charger":
			enemy.guard_phase = "charge"
			enemy.guard_left = 0.36

func recover(enemy: Dictionary) -> void:
	enemy.guard_phase = "recover"
	enemy.guard_left = 1.3

func hit(amount: int, weather: String, direction: Vector2) -> void:
	game.take_enemy_hit(amount, HIT_AILMENTS.get(weather, ""), direction)

func play_visible() -> Array:
	var warnings: Array = []
	for enemy: Dictionary in game.states[game.region].enemies:
		if enemy.hp <= 0 or enemy.guard_phase != "windup": continue
		var bounds: Rect2
		if enemy.behavior == "melee":
			bounds = Rect2(enemy.guard_target - Vector2(66, 66), Vector2(132, 132))
		else:
			var side: Vector2 = enemy.guard_direction.orthogonal() * (32 if enemy.behavior == "charger" else 22)
			var end: Vector2 = enemy.position + enemy.guard_direction * (225 if enemy.behavior == "charger" else SHOT_SPEED * SHOT_LIFE)
			bounds = Rect2(enemy.position + side, Vector2.ZERO).expand(enemy.position - side).expand(end + side).expand(end - side)
			bounds = bounds.grow(32 if enemy.behavior == "charger" else 22)
		var clipped: Rect2 = game.ARENA.intersection(Rect2(game.world_to_screen(bounds.position), bounds.size * game.WORLD_ZOOM))
		if clipped.has_area(): warnings.append({"appearance": NAMES[enemy.behavior] + "的黄色攻击预警", "visible_bounds": {"x": clipped.position.x, "y": clipped.position.y, "width": clipped.size.x, "height": clipped.size.y}})
	return warnings

func draw_world() -> void:
	var canvas: Control = game.world_canvas
	for enemy: Dictionary in game.states[game.region].enemies:
		if enemy.hp <= 0: continue
		var color := Color("#ffd389") if enemy.guard_phase == "windup" else Color("#b5cfcc")
		canvas.draw_string(ThemeDB.fallback_font, enemy.position + Vector2(-90, -96), enemy.name + " · " + NAMES[enemy.behavior], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		if enemy.guard_phase != "windup": continue
		if enemy.behavior == "melee":
			PixelVFX.cue_circle(canvas, enemy.guard_target, 66.0, Color(1, 0.55, 0.2, 0.25))
			PixelVFX.cue_arc(canvas, enemy.guard_target, 66.0, 0.0, TAU, 4.0, color)
		else:
			var side: Vector2 = enemy.guard_direction.orthogonal() * (32 if enemy.behavior == "charger" else 22)
			var end: Vector2 = enemy.position + enemy.guard_direction * (225 if enemy.behavior == "charger" else SHOT_SPEED * SHOT_LIFE)
			PixelVFX.cue_fill(canvas, PackedVector2Array([enemy.position + side, end + side, end - side, enemy.position - side]), Color(1, 0.55, 0.2, 0.26))
			PixelVFX.cue_circle(canvas, end, side.length(), Color(1, 0.55, 0.2, 0.26))
			PixelVFX.cue_segment(canvas, enemy.position, end, 4.0, color)
	for shot: Dictionary in shots:
		PixelVFX.draw(canvas, "guard-stone", shot.position - Vector2(0, 18), (SHOT_LIFE - float(shot.life)) * 2.0, Vector2.ONE, shot.velocity.angle(), Color.WHITE, true)
