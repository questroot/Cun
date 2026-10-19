extends Node
## Optional round-owned encounters, isolated from weather guards and map bosses.
const Rules = preload("res://scripts/scenes/chest_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Bosses = preload("res://scripts/scenes/boss_catalog.gd")
const ENEMY_ART = preload("res://assets/characters/pet_enemy_stone.png")
var game
var rng := RandomNumberGenerator.new()
var regions: Dictionary = {}
var initialized := false

func _ready() -> void:
	game = get_parent()
	rng.randomize()
	for id: String in Maps.IDS:
		regions[id] = []
		for i in range(Rules.NORMAL_PER_REGION):
			_add_chest(id, false)
		if rng.randf() < Rules.MUTATION_CHANCE:
			_add_chest(id, true)
	var has_mutation := false
	for chests: Array in regions.values():
		for chest: Dictionary in chests:
			has_mutation = has_mutation or chest.mutated
	if not has_mutation:
		_add_chest(Maps.IDS[rng.randi_range(0, Maps.IDS.size() - 1)], true)
	game.world_canvas.draw.connect(draw_world)
	game.minimap.draw.connect(draw_minimap)
	game.tools.atlas.set_meta("chest_provider", summary)
	initialized = true

func _add_chest(id: String, mutated: bool) -> void:
	var occupied: Array = game.states[id].pickups.duplicate()
	occupied.append_array(game.states[id].enemies)
	occupied.append_array(regions[id])
	var point: Vector2 = game._free_point(id, rng, occupied)
	# Prefer roomy ground so the initial encounter has safe, reachable spawn positions.
	for attempt in range(200):
		var separated := true
		for other: Dictionary in regions[id]:
			separated = separated and point.distance_to(other.position) >= 240
		if Maps.walkable(id, point, 150) and separated:
			break
		point = game._free_point(id, rng, occupied)
	regions[id].append({"position": point, "mutated": mutated, "state": "sealed", "mobs": [], "boss": {}, "warning": 0.0, "rewarded": false})

func interaction_target() -> Dictionary:
	if not initialized:
		return {}
	var closest: Dictionary = {}
	var distance := 105.0
	for chest: Dictionary in regions[game.region]:
		var current: float = game.player_foot.distance_to(chest.position)
		if chest.state == "opened" or current > distance:
			continue
		distance = current
		var name := "异变宝箱 · 触发守卫战" if chest.mutated else "开启普通宝箱"
		if chest.state == "guarding":
			name = "异变宝箱 · 先击败全部守卫"
		elif chest.state == "cleared":
			name = "异变宝箱 · 领取战利品"
		closest = {"kind": "chest", "chest": chest, "name": name}
	return closest

func interact(chest: Dictionary) -> void:
	if game.finished or game._paused() or not regions[game.region].has(chest) or game.player_foot.distance_to(chest.position) > 105:
		return
	if chest.state == "opened" or chest.state == "guarding":
		return
	if chest.mutated and chest.state == "sealed":
		_start_encounter(chest)
	else:
		_pay_chest(chest)
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()

func _path_clear(id: String, start: Vector2, end: Vector2) -> bool:
	var steps := maxi(1, ceili(start.distance_to(end) / 16))
	for i in range(steps + 1):
		if not Maps.walkable(id, start.lerp(end, float(i) / steps), 28):
			return false
	return true

func _spawn_points(chest: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var phase := rng.randf_range(0, TAU)
	for i in range(120):
		var angle := phase + i * TAU / 24.0
		var point: Vector2 = chest.position + Vector2.from_angle(angle) * (160.0 + (i / 24) * 28.0)
		if point.distance_to(game.player_foot) < 125 or not _path_clear(game.region, chest.position, point):
			continue
		var clear := true
		for other: Vector2 in result:
			clear = clear and point.distance_to(other) > 75
		if clear:
			result.append(point)
		if result.size() == Rules.GUARD_COUNT + 1:
			break
	if result.size() == Rules.GUARD_COUNT + 1:
		# Keep the tall boss near the player's horizontal line so its warning and bar are visible.
		var best := 0
		for i in range(1, result.size()):
			if absf(result[i].y - chest.position.y) < absf(result[best].y - chest.position.y):
				best = i
		var boss_point := result[best]
		result[best] = result[-1]
		result[-1] = boss_point
	return result

func _start_encounter(chest: Dictionary) -> void:
	var points := _spawn_points(chest)
	if points.size() < Rules.GUARD_COUNT + 1:
		return # Remain sealed and retryable; never lock a chest without its guards.
	var art_id: String = Rules.REGION_BOSS[game.region]
	var base: Dictionary = Bosses.DEFINITIONS[art_id]
	for i in range(Rules.GUARD_COUNT):
		chest.mobs.append({"position": points[i], "home": points[i], "hp": 36, "max_hp": 36, "damage": 6, "speed": 72.0, "flash": 0.0, "paid": false})
	var hp := ceili(float(base.hp) * Rules.BOSS_HP_SCALE)
	chest.boss = {"position": points[-1], "home": chest.position, "hp": hp, "max_hp": hp, "damage": ceili(float(base.damage) * Rules.BOSS_DAMAGE_SCALE), "flash": 0.0, "cooldown": 2.0, "windup": 0.0, "target": points[-1], "art": art_id, "paid": false, "hit_radius": 38.0, "hit_height": 45.0}
	chest.state = "guarding"
	chest.warning = 1.2

func _pay_chest(chest: Dictionary) -> void:
	if chest.rewarded:
		return
	chest.rewarded = true
	chest.state = "opened"
	var choices := Loot.pool(Loot.REGIONS[game.region])
	game._spawn_equipment(game.region, choices[rng.randi_range(0, choices.size() - 1)], chest.position, "chest_drop")
	var materials: Array = Items.REGIONS[game.region].resources.keys()
	for i in range(3):
		game.states[game.region].pickups.append({"item": materials[rng.randi_range(0, materials.size() - 1)], "position": chest.position + Vector2(i * 16, 0), "chest_drop": true})

func targets(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not initialized:
		return result
	for chest: Dictionary in regions[id]:
		if chest.state != "guarding":
			continue
		for mob: Dictionary in chest.mobs:
			if int(mob.hp) > 0:
				result.append(mob)
		if int(chest.boss.hp) > 0:
			result.append(chest.boss)
	return result

func remaining() -> int:
	var count := 0
	for id: String in regions:
		count += targets(id).size()
	return count

func collect_defeated() -> void:
	if not initialized:
		return
	for id: String in regions:
		for chest: Dictionary in regions[id]:
			if chest.state != "guarding":
				continue
			var boss: Dictionary = chest.boss
			if int(boss.hp) <= 0 and not boss.paid:
				boss.paid = true
				if rng.randf() < Rules.BOSS_DROP_CHANCE:
					var choices := Loot.pool(Loot.REGIONS[id])
					var item: String = choices[rng.randi_range(0, choices.size() - 1)] + "@mutated"
					game._spawn_equipment(id, item, boss.position, "chest_boss_drop")
			var living := int(int(boss.hp) > 0)
			for mob: Dictionary in chest.mobs:
				living += int(int(mob.hp) > 0)
				if int(mob.hp) <= 0 and not mob.paid:
					mob.paid = true
					var item := Loot.roll_monster(id, rng)
					if not item.is_empty():
						game._spawn_equipment(id, item, mob.position, "chest_guard_drop")
			if living == 0:
				chest.state = "cleared"
				chest.warning = 0.0

func enter_region() -> void:
	for chests: Array in regions.values():
		for chest: Dictionary in chests:
			if chest.state == "guarding":
				chest.boss.windup = 0.0
				chest.boss.cooldown = maxf(1.8, float(chest.boss.cooldown))

func _process(delta: float) -> void:
	if initialized and game.is_processing() and not game.finished and not game._paused():
		tick(minf(delta, 0.1))

func tick(delta: float) -> void:
	if not initialized or game.finished or game._paused() or delta <= 0:
		return
	collect_defeated()
	for chest: Dictionary in regions[game.region]:
		if chest.state != "guarding":
			continue
		if float(chest.warning) > 0:
			chest.warning = maxf(0, float(chest.warning) - delta)
			continue
		for mob: Dictionary in chest.mobs:
			if int(mob.hp) <= 0:
				continue
			mob.flash = maxf(0, float(mob.flash) - delta)
			var offset: Vector2 = game.player_foot - mob.position
			if offset.length() > 32 and offset.length() < 600:
				var slow: float = game.equipment.effects.enemy_speed_scale(mob)
				mob.position = game.move_world(mob.position, offset.normalized() * minf(float(mob.speed) * slow * delta, offset.length() - 32))
			elif offset.length() <= 32:
				_hurt(int(mob.damage))
		_tick_boss(chest.boss, delta)
	if game.health <= 0:
		game._end_round(false)
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()

func _hurt(amount: int) -> void:
	if game.hurt_timer > 0:
		return
	game.health = maxi(0, game.health - game.incoming_damage(amount))
	game.hurt_timer = 1.0

func _tick_boss(boss: Dictionary, delta: float) -> void:
	if int(boss.hp) <= 0:
		return
	boss.flash = maxf(0, float(boss.flash) - delta)
	if float(boss.windup) > 0:
		boss.windup = maxf(0, float(boss.windup) - delta)
		if float(boss.windup) == 0:
			if game.player_foot.distance_to(boss.target) <= 105:
				_hurt(int(boss.damage))
			boss.cooldown = 3.4
		return
	boss.cooldown = maxf(0, float(boss.cooldown) - delta)
	var offset: Vector2 = game.player_foot - boss.position
	if game.player_foot.distance_to(boss.home) > 650:
		boss.position = game.move_world(boss.position, boss.position.direction_to(boss.home) * minf(55 * delta, boss.position.distance_to(boss.home)))
	elif offset.length() <= 240 and float(boss.cooldown) <= 0 and _path_clear(game.region, boss.position, game.player_foot):
		boss.target = game.player_foot
		boss.windup = 1.25
	elif offset.length() > 65:
		var slow: float = game.equipment.effects.enemy_speed_scale(boss)
		boss.position = game.move_world(boss.position, offset.normalized() * minf(55 * slow * delta, offset.length() - 65))

func summary(id: String) -> String:
	var normal := 0
	var mutated := 0
	var active := 0
	for chest: Dictionary in regions.get(id, []):
		if chest.state == "opened":
			continue
		if chest.mutated:
			mutated += 1
		else:
			normal += 1
		active += int(chest.state == "guarding")
	return "普通%d / 异变%d未领取，守卫战%d场。%s" % [normal, mutated, active, Rules.rules()]

func draw_world() -> void:
	if not initialized:
		return
	var canvas: Control = game.world_canvas
	var font := ThemeDB.fallback_font
	for chest: Dictionary in regions[game.region]:
		var point: Vector2 = chest.position
		var color := Color("#c38bff") if chest.mutated else Color("#e7c076")
		if chest.state == "opened":
			color = Color("#7b8c88")
		canvas.draw_circle(point, 29, Color(color, 0.18))
		canvas.draw_style_box(_box(Color("#46334e") if chest.mutated else Color("#513d29"), color), Rect2(point - Vector2(23, 22), Vector2(46, 34)))
		canvas.draw_rect(Rect2(point - Vector2(24, 25 if chest.state == "opened" else 22), Vector2(48, 9)), color)
		canvas.draw_rect(Rect2(point - Vector2(4, 13), Vector2(8, 12)), Color("#fff0bc"))
		var label := "异变宝箱" if chest.mutated else "普通宝箱"
		match chest.state:
			"guarding": label += " · 守卫中"
			"cleared": label += " · E领奖"
			"opened": label += " · 已领取"
			_: label += " · E开启"
		canvas.draw_string(font, point + Vector2(-70, 39), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
		if chest.state != "guarding":
			continue
		for mob: Dictionary in chest.mobs:
			if int(mob.hp) <= 0:
				continue
			_draw_guard(canvas, mob, ENEMY_ART, Vector2(66, 66), "异变守卫", 25)
		var boss: Dictionary = chest.boss
		if int(boss.hp) > 0:
			if float(boss.windup) > 0:
				canvas.draw_circle(boss.target, 105, Color(0.85, 0.25, 0.65, 0.24))
				canvas.draw_arc(boss.target, 105, 0, TAU, 48, Color("#ffabd5"), 3, true)
			var art: Texture2D = Bosses.ART[boss.art]
			var extent := Vector2(art.get_width(), art.get_height()) * 0.72
			_draw_guard(canvas, boss, art, extent, "守箱·" + str(Bosses.DEFINITIONS[boss.art].name), 56)
		if float(chest.warning) > 0:
			canvas.draw_arc(point, 135, 0, TAU, 48, Color("#e3a3ff"), 4, true)
			canvas.draw_string(font, point + Vector2(55, -55), "异变惊醒！准备迎战", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e8c4ff"))

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _draw_guard(canvas: Control, guard: Dictionary, art: Texture2D, extent: Vector2, name: String, width: float) -> void:
	var point: Vector2 = guard.position
	canvas.draw_texture_rect(art, Rect2(point - Vector2(extent.x / 2, extent.y), extent), false, Color("#ffaaaa") if float(guard.flash) > 0 else Color("#dfb8ef"))
	var top := point - Vector2(width, extent.y + 10)
	canvas.draw_rect(Rect2(top, Vector2(width * 2, 5)), Color("#28212f"))
	canvas.draw_rect(Rect2(top, Vector2(width * 2 * float(guard.hp) / float(guard.max_hp), 5)), Color("#cc9dee"))
	canvas.draw_string(ThemeDB.fallback_font, top + Vector2(-10, -7), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e4c3f5"))

func draw_minimap() -> void:
	if not initialized:
		return
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for chest: Dictionary in regions[game.region]:
		if chest.state == "opened":
			continue
		var point: Vector2 = rect.position + chest.position / Maps.MAPS[game.region].size * rect.size
		game.minimap.draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color("#cf9bff") if chest.mutated else Color("#e8c076"))
