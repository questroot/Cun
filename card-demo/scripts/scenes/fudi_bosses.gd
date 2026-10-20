extends Node
## Boss state is separate from weather-adapted guards and lasts only for this round.
const Catalog = preload("res://scripts/scenes/boss_catalog.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game: Control
var bosses: Dictionary = {}
var banner: Label

func enter_region() -> void:
	# Cancel warnings during travel; returning always leaves time to react.
	for boss: Dictionary in bosses.values():
		boss.windup = 0.0
		boss.cooldown = maxf(1.8, float(boss.cooldown))
	refresh()

func play_visible() -> Dictionary:
	if game == null or game._paused() or game.finished: return {}
	var visible: Array = []
	var warnings: Array = []
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var point: Vector2 = game.ARENA.position+boss.position-game.camera_origin
		if game.ARENA.has_point(point): visible.append({"title":str(config.name),"x":point.x,"y":point.y,"kind":"boss"})
		if float(boss.windup) > 0:
			var center: Vector2 = game.ARENA.position+boss.target-game.camera_origin
			var radius := float(config.radius)
			var clipped: Rect2 = game.ARENA.intersection(Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2))
			if clipped.has_area(): warnings.append({"appearance":"红色攻击预警圈","visible_bounds":{"x":clipped.position.x,"y":clipped.position.y,"width":clipped.size.x,"height":clipped.size.y}})
	return {"visible_bosses":visible,"visible_warnings":warnings}

func _ready() -> void:
	game = get_parent()
	for id: String in Catalog.DEFINITIONS:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		var home: Vector2 = config.point * Maps.MAPS[config.region].size
		bosses[id] = {"id": id, "position": home, "home": home, "hp": config.hp, "max_hp": config.hp, "hit_radius": 42.0, "hit_height": 45.0, "flash": 0.0, "cooldown": 1.8, "windup": 0.0, "target": home, "paid": false}
	game.world_canvas.draw.connect(draw_world)
	game.minimap.draw.connect(draw_minimap)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, game.ARENA.size.y - 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.panel(Color(0.11, 0.045, 0.04, 0.9)))
	game.world_view.add_child(panel)
	banner = UI.label("", 16, Color("#f3c997"))
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
		lines.append("%s · %s · 坐标%d,%d · %s · 掉落%s×%d" % [config.name, "已击败" if int(boss.hp) <= 0 else "生命%d/%d" % [boss.hp, boss.max_hp], int(boss.home.x), int(boss.home.y), config.skill, Items.ITEMS[config.drop].name, config.count])
	return "本区暂无首领" if lines.is_empty() else "\n".join(lines)

func _process(delta: float) -> void:
	if game.is_processing() and not game.finished and not game._paused():
		tick(minf(delta, 0.1))
	refresh()

func tick(delta: float) -> void:
	if game.finished or game._paused() or delta <= 0:
		return
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var slow: float = game.equipment.effects.enemy_speed_scale(boss) if game.equipment != null else 1.0
		boss.flash = maxf(0, float(boss.flash) - delta)
		var offset: Vector2 = game.player_foot - boss.position
		if float(boss.windup) > 0:
			boss.windup = maxf(0, float(boss.windup) - delta)
			if float(boss.windup) == 0:
				# The circle is locked at cast time: walking out always avoids this hit.
				if game.player_foot.distance_to(boss.target) <= float(config.radius) and game.hurt_timer <= 0:
					game.health = maxi(0, game.health - game.incoming_damage(int(config.damage)))
					game.hurt_timer = 1.0
				boss.cooldown = config.cooldown
			continue
		boss.cooldown = maxf(0, float(boss.cooldown) - delta)
		if offset.length() > 520 or game.player_foot.distance_to(boss.home) > 650:
			boss.position = game.move_world(boss.position, boss.position.direction_to(boss.home) * minf(float(config.speed) * slow * delta, boss.position.distance_to(boss.home)))
			continue
		if offset.length() <= float(config.reach) and float(boss.cooldown) <= 0 and visible_path(boss.position, game.player_foot):
			boss.target = game.player_foot if float(config.reach) >= 250 else boss.position
			boss.windup = config.windup
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
	var configured := false
	for config: Dictionary in Catalog.DEFINITIONS.values():
		configured = configured or config.region == game.region
	var text := "%s · 首领进度 %d / 6" % ["本地首领已击败" if configured else "本区暂无首领", 6 - remaining()]
	if not active.is_empty():
		var boss: Dictionary = active[0]
		for candidate: Dictionary in active:
			if game.player_foot.distance_to(candidate.position) < game.player_foot.distance_to(boss.position):
				boss = candidate
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		text = "首领：%s  %d/%d · 小地图红菱形 · 首领进度 %d/6" % [config.name, boss.hp, boss.max_hp, 6 - remaining()]
		if float(boss.windup) > 0:
			text = "%s · %.1f秒后 %s！离开红圈" % [config.name, boss.windup, config.skill]
	banner.text = text

func draw_world() -> void:
	var canvas: Control = game.world_canvas
	var font := ThemeDB.fallback_font
	for boss: Dictionary in targets(game.region):
		var config: Dictionary = Catalog.DEFINITIONS[boss.id]
		var color := Color(config.color)
		var point: Vector2 = boss.position
		if float(boss.windup) > 0:
			canvas.draw_circle(boss.target, float(config.radius), Color(0.95, 0.20, 0.14, 0.22))
			canvas.draw_arc(boss.target, float(config.radius), 0, TAU, 64, Color("#ff8b61"), 3, true)
			canvas.draw_arc(boss.target, float(config.radius) * (1.0 - float(boss.windup) / float(config.windup)), 0, TAU, 64, Color("#ffd3a1"), 3, true)
		canvas.draw_set_transform(point, 0, Vector2(1, 0.28))
		canvas.draw_circle(Vector2.ZERO, 48, Color(0.01, 0.02, 0.03, 0.55))
		canvas.draw_set_transform(Vector2.ZERO)
		var art: Texture2D = Catalog.ART[boss.id]
		var extent := Vector2(art.get_width(), art.get_height()) * 1.08
		canvas.draw_texture_rect(art, Rect2(point - Vector2(extent.x * 0.5, extent.y), extent), false, Color("#ffb19d") if float(boss.flash) > 0 else Color.WHITE)
		var top := point - Vector2(68, extent.y + 16)
		canvas.draw_rect(Rect2(top, Vector2(136, 7)), Color("#221f29"))
		canvas.draw_rect(Rect2(top, Vector2(136.0 * float(boss.hp) / float(boss.max_hp), 7)), color)
		canvas.draw_string(font, top + Vector2(-8, -9), config.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)

func draw_minimap() -> void:
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for boss: Dictionary in targets(game.region):
		var p: Vector2 = rect.position + boss.position / Maps.MAPS[game.region].size * rect.size
		game.minimap.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), Color("#ff7d6b"))
