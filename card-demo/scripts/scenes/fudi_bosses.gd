extends Node
## Boss state is separate from weather-adapted guards and lasts only for this round.
const Catalog = preload("res://scripts/scenes/boss_catalog.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const Skills = preload("res://scripts/scenes/boss_skills.gd")
const VFX = preload("res://scripts/scenes/pixel_vfx.gd")
const HealthBar = preload("res://scripts/scenes/fudi_boss_health_bar.gd")
const EnemyFeedback = preload("res://scripts/scenes/fudi_enemy_feedback.gd")
var game: Control
var bosses: Dictionary = {}
var banner: Label
var casts: Array[Dictionary] = []

func enter_region() -> void:
	# Cancel warnings during travel; returning always leaves time to react.
	casts.clear()
	for boss: Dictionary in bosses.values():
		boss.windup = 0.0
		boss.flash = 0.0
		boss.erase("hp_trail")
		boss["attack_pose"] = 0.0
		boss.cooldown = maxf(1.8, float(boss.cooldown))
	refresh()

func play_visible() -> Dictionary:
	if game == null or game._paused() or game.finished: return {}
	var visible: Array = []
	var warnings: Array = []
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var point: Vector2 = game.world_to_screen(boss.position)
		if game.ARENA.has_point(point): visible.append({"title":str(config.name),"x":point.x,"y":point.y,"kind":"boss"})
		if float(boss.windup) > 0:
			var bounds := Skills.bounds(boss)
			var clipped: Rect2 = game.ARENA.intersection(Rect2(game.world_to_screen(bounds.position),bounds.size*game.WORLD_ZOOM))
			if clipped.has_area(): warnings.append({"appearance":"红色%s攻击预警" % Skills.SHAPE_NAMES[Skills.current(boss).shape],"visible_bounds":{"x":clipped.position.x,"y":clipped.position.y,"width":clipped.size.x,"height":clipped.size.y}})
	return {"visible_bosses":visible,"visible_warnings":warnings}

func _ready() -> void:
	game = get_parent()
	for id: String in Catalog.DEFINITIONS:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		var home: Vector2 = config.point * Maps.MAPS[config.region].size
		bosses[id] = {"id": id, "position": home, "home": home, "hp": config.hp, "max_hp": config.hp, "hit_radius": 42.0, "hit_height": 45.0, "flash": 0.0, "cooldown": 1.8, "windup": 0.0, "attack_pose": 0.0, "target": home, "paid": false, "skill_index": 0}
	game.world_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game.world_canvas.draw.connect(draw_world)
	game.minimap.draw.connect(draw_minimap)
	var panel := PanelContainer.new()
	panel.position = Vector2(420, game.ARENA.size.y - 46)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.hud_panel(Color(0.11, 0.045, 0.04, 0.9)))
	game.world_view.add_child(panel)
	banner = UI.label("", 15, Color("#f3c997"))
	panel.add_child(banner)
	game.tools.atlas.set_meta("boss_provider", summary)
	refresh()

func targets(region: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in bosses:
		if Catalog.DEFINITIONS[id].region == region and int(bosses[id].hp) > 0:
			result.append(bosses[id])
	return result

func remaining() -> int:
	var count := 0
	for boss: Dictionary in bosses.values():
		if int(boss.hp) > 0:
			count += 1
	return count

func collect_defeated() -> void:
	for id: String in bosses:
		var boss: Dictionary = bosses[id]
		if int(boss.hp) > 0 or boss.paid:
			continue
		boss.paid = true
		boss.windup = 0.0
		for i in range(casts.size()-1,-1,-1):
			if casts[i].boss_id == id: casts.remove_at(i)
		var config: Dictionary = Catalog.DEFINITIONS[id]
		for i in range(int(config.count)):
			game.states[config.region].pickups.append({"item": config.drop, "position": boss.position, "boss_drop": true})
	refresh()

func summary(region: String) -> String:
	var lines: Array[String] = []
	for id: String in bosses:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		if config.region != region:
			continue
		var boss: Dictionary = bosses[id]
		lines.append("%s · %s · 坐标%d,%d · 掉落%s×%d" % [config.name, "已击败" if int(boss.hp) <= 0 else "生命%d/%d" % [boss.hp, boss.max_hp], int(boss.home.x), int(boss.home.y), Items.ITEMS[config.drop].name, config.count])
		for skill: Dictionary in Skills.MOVES[id]:
			lines.append("  %s · %.2f秒预警 · 伤害%d · %s" % [skill.name,skill.windup,skill.damage,skill.hint])
	return "本区暂无首领" if lines.is_empty() else "\n".join(lines)

func _process(delta: float) -> void:
	if game.is_processing() and not game.finished and not game._paused():
		tick(minf(delta, 0.1))
	refresh()

func tick(delta: float) -> void:
	if game.finished or game._paused() or delta <= 0:
		return
	for i in range(casts.size()-1,-1,-1):
		casts[i].life -= delta
		if float(casts[i].life) <= 0: casts.remove_at(i)
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var skill := Skills.current(boss)
		var slow: float = game.equipment.effects.enemy_speed_scale(boss) if game.equipment != null else 1.0
		boss.flash = maxf(0, float(boss.flash) - delta)
		HealthBar.tick(boss, delta)
		boss.attack_pose = maxf(0, float(boss.attack_pose) - delta)
		var offset: Vector2 = game.player_foot - boss.position
		if float(boss.windup) > 0:
			boss.windup = maxf(0, float(boss.windup) - delta)
			if float(boss.windup) == 0:
				boss.attack_pose = 0.28
				# Lock geometry at cast time. Each cast resolves once, even across multi zones.
				casts.append({"boss_id":boss.id,"skill":skill,"target":boss.target,"origin":boss.get("cast_origin",boss.position),"direction":boss.get("direction",Vector2.RIGHT),"zones":boss.get("zones",[boss.target]).duplicate(),"life":VFX.LIFETIME})
				if Skills.hits(boss,game.player_foot):
					game.take_enemy_hit(int(skill.damage), Skills.HIT_AILMENTS.get(boss.id, ""), Vector2(boss.cast_origin).direction_to(game.player_foot))
				boss.cooldown = skill.cooldown
				boss.skill_index = (int(boss.skill_index)+1)%5
			continue
		boss.cooldown = maxf(0, float(boss.cooldown) - delta)
		if offset.length() > Catalog.SIGHT_RANGE or game.player_foot.distance_to(boss.home) > Catalog.LEASH_RANGE:
			boss.position = game.move_world(boss.position, boss.position.direction_to(boss.home) * minf(float(config.speed) * slow * delta, boss.position.distance_to(boss.home)))
			continue
		if offset.length() <= float(skill.reach) and float(boss.cooldown) <= 0 and visible_path(boss.position, game.player_foot):
			Skills.lock(boss,game.player_foot)
			boss.windup = skill.windup
		elif offset.length() > 65:
			boss.position = game.move_world(boss.position, offset.normalized() * minf(float(config.speed) * slow * delta, offset.length() - 65))
	if game.health <= 0:
		game._end_round(false)
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()

func visible_path(start: Vector2, end: Vector2) -> bool:
	var steps := maxi(1, ceili(start.distance_to(end) / 16.0))
	for i in range(steps + 1):
		if not Maps.walkable(game.region, start.lerp(end, float(i) / steps), 0):
			return false
	return true

func refresh() -> void:
	var active := targets(game.region)
	var text := ""
	var nearby := false
	if not active.is_empty():
		var boss: Dictionary = active[0]
		for candidate: Dictionary in active:
			if game.player_foot.distance_to(candidate.position) < game.player_foot.distance_to(boss.position):
				boss = candidate
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		nearby = game.visible_world().has_point(boss.position) and game.player_foot.distance_to(boss.position) <= Catalog.SIGHT_RANGE
		text = "%s  %d / %d" % [config.name, boss.hp, boss.max_hp]
		if float(boss.windup) > 0:
			var skill := Skills.current(boss)
			text = "%s · %.1f秒后 %s · %s" % [config.name, boss.windup, skill.name, skill.hint]
	banner.text = text
	banner.get_parent().visible = nearby

func draw_world() -> void:
	var canvas: Control = game.world_canvas
	var font := ThemeDB.fallback_font
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var color := Color(config.color)
		var point: Vector2 = boss.position
		if float(boss.windup) > 0:
			Skills.draw_warning(canvas,boss)
		canvas.draw_set_transform(point, 0, Vector2(1, 0.28))
		canvas.draw_circle(Vector2.ZERO, 48, Color(0.01, 0.02, 0.03, 0.55))
		canvas.draw_set_transform(Vector2.ZERO)
		var art: Texture2D = Catalog.ART[boss.id]
		var extent := art.get_size() * EnemyFeedback.BOSS_SCALE
		# Keep the feet planted while the existing art compresses, strikes and recoils.
		var scale := Vector2(1.10, 0.90) if boss.windup > 0 else Vector2(0.94, 1.06) if boss.attack_pose > 0 else Vector2.ONE
		var lean := 0.07 if boss.attack_pose > 0 else -0.04 if boss.windup > 0 else 0.0
		EnemyFeedback.draw_actor(canvas, boss, art, extent, Color.WHITE, lean, scale)
		var top := point - Vector2(68, extent.y + 16)
		HealthBar.draw(canvas, Rect2(top, Vector2(136, 8)), boss, color)
		canvas.draw_string(font, top + Vector2(-8, -9), config.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
	for cast: Dictionary in casts:
		VFX.draw_cast(canvas,cast)

func draw_minimap() -> void:
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for boss: Dictionary in targets(game.region):
		var p: Vector2 = rect.position + boss.position / Maps.MAPS[game.region].size * rect.size
		game.minimap.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), Color("#ff7d6b"))
