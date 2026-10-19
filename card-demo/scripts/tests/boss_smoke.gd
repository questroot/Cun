extends SceneTree
const Catalog = preload("res://scripts/scenes/boss_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var game
var bosses
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func frames() -> void:
	for i in range(3):
		await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func open_fudi() -> void:
	if current_scene != null:
		current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	bosses = game.get_node("Bosses")

func reachable_cells(id: String) -> Dictionary:
	var start := Vector2i((Maps.MAPS[id].spawn * Maps.MAPS[id].size / 64.0).floor())
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if not seen.has(next) and Maps.walkable(id, (Vector2(next) + Vector2(0.5, 0.5)) * 64, 28):
				seen[next] = true
				frontier.append(next)
	return seen

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://boss_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图 " + label)
	print("BOSS_CAPTURE: " + ProjectSettings.globalize_path(path))

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Boss-"):
		printerr("Boss checks require an isolated Cun-Boss-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	await open_fudi()
	check(bosses.remaining() == 6, "六张当前美术各生成一只首领，排除旧版H01")
	var occupied := {}
	var inner_count := 0
	var outer_count := 0
	for config: Dictionary in Catalog.DEFINITIONS.values():
		occupied[config.region] = true
		inner_count += 1 if config.region in Maps.INNER_RING else 0
		outer_count += 1 if config.region in Maps.OUTER_RING else 0
	check(occupied.size() == 6 and inner_count == 3 and outer_count == 3, "六首领分驻六地，内外环各三只")
	check(bosses.targets("causeway").size() == 1 and bosses.targets("snowridge").size() == 1 and bosses.targets("archive").size() == 1 and bosses.targets("refuge").size() == 1, "新增三地驻守首领，救援营只留一只")
	for id: String in Catalog.DEFINITIONS:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		var boss: Dictionary = bosses.bosses[id]
		game.enter_region(config.region)
		var reachable := reachable_cells(config.region)
		check(Maps.walkable(config.region, boss.home, 65) and reachable.has(Vector2i((boss.home / 64).floor())), "首领出生可达且不在障碍内 " + id)
		check(boss.home.distance_to(Maps.MAPS[config.region].spawn * Maps.MAPS[config.region].size) > 650, "远离玩家出生点 " + id)
		var art: Texture2D = Catalog.ART[id]
		check(art.get_image().get_pixel(0, 0).a == 0 and art.get_height() > 150, "透明原图与尺寸 " + id)
		game.player_foot = boss.home + Vector2(-180, 0)
		await capture(id)
		game.player_foot = boss.home + Vector2(65, 0)
		game.health = 100
		game.hurt_timer = 0
		boss.cooldown = 0.0
		bosses.tick(0.01)
		check(float(boss.windup) > 0 and game.health == 100, "攻击先预警，无立即伤害 " + id)
		if id == "H06":
			await capture("telegraph")
		var windup: float = boss.windup
		game.journal.show()
		bosses.tick(3)
		check(boss.windup == windup and game.health == 100, "行囊暂停首领预警 " + id)
		game.journal.hide()
		game.player_foot = boss.home + Vector2(220, 0)
		bosses.tick(float(config.windup) + 0.01)
		check(game.health == 100, "离开锁定预警圈成功闪避 " + id)
		boss.cooldown = 0.0
		game.player_foot = boss.home + Vector2(65, 0)
		bosses.tick(0.01)
		bosses.tick(float(config.windup) + 0.01)
		check(game.health == 100 - int(config.damage), "预警结束圈内按本首领伤害命中 " + id)
		boss.cooldown = 0.0
		bosses.tick(0.01)
		game.hurt_timer = 1
		bosses.tick(float(config.windup) + 0.01)
		check(game.health == 100 - int(config.damage), "共享无敌时间防重叠伤害 " + id)
		boss.hp -= 17
		var hurt_hp: int = boss.hp
		game.get_node("Weather").tick(76)
		check(boss.hp == hurt_hp and boss.max_hp == config.hp, "天气不能覆盖首领美术和受伤血量 " + id)
		boss.cooldown = 0.0
		bosses.tick(0.01)
		var other := "post" if config.region != "post" else "grove"
		game.enter_region(other)
		game.enter_region(config.region)
		check(boss.hp == hurt_hp and boss.windup == 0 and boss.cooldown >= 1.8, "跨图保留伤势、取消旧预警并留缓冲 " + id)
	# Real action input reaches the same boss dictionary as the draw and attack systems.
	game.enter_region("grove")
	game.states.grove.enemies.clear()
	var target: Dictionary = bosses.bosses.H02
	target.position = target.home
	game.player_foot = target.position + Vector2(-75, 0)
	game.facing = Vector2.RIGHT
	var before: int = target.hp
	key(KEY_J)
	check(target.hp == before - 26, "真实J键斩击首领")
	key(KEY_L)
	check(target.hp == before - 68, "真实L键震荡首领")
	key(KEY_K)
	game._tick_projectiles(0.2)
	check(target.hp == before - 88 and game.projectiles.is_empty(), "真实K键灵弹沿轨迹命中首领")
	var foot: Vector2 = target.position
	game.player_foot = foot + Vector2(-400, 0)
	target.cooldown = 2.0
	bosses.tick(0.1)
	check(target.position.distance_to(game.player_foot) < foot.distance_to(game.player_foot), "感知范围内追踪玩家")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	var home_distance: float = target.position.distance_to(target.home)
	bosses.tick(0.1)
	check(target.position.distance_to(target.home) < home_distance, "脱战回到领地且不恢复血量")
	game.player_foot = target.position + Vector2(-300, 0)
	game.health = 100
	game.hurt_timer = 1
	var before_frame: Vector2 = target.position
	game.set_process(true)
	await create_timer(0.3).timeout
	game.set_process(false)
	check(target.position != before_frame and game.health == 100, "真实逐帧运行推进首领追踪")
	game.tools.atlas.open("grove")
	var paused_position: Vector2 = target.position
	bosses.tick(5)
	check(target.position == paused_position, "地图暂停首领推进")
	await capture("atlas")
	game.tools.atlas.close()
	game.open_journal()
	check(game.journal_text.get_parsed_text().contains("荆冠鹿骑") and game.journal_text.get_parsed_text().contains("灰翼审判者"), "行囊展示全部首领与坐标掉落")
	game.journal.hide()
	for region: String in Maps.IDS:
		game.states[region].enemies.clear()
	game._remove_dead()
	check(not game.finished, "只清普通守卫不能提前获胜")
	game.enter_region("grove")
	var pickup_count: int = game.states.grove.pickups.size()
	target.hp = 1
	game._damage(target, 26)
	game._remove_dead()
	check(bosses.targets("grove").is_empty() and game.states.grove.pickups.size() == pickup_count + 4, "首领死亡掉落三份材料和一件装备")
	game._remove_dead()
	check(game.states.grove.pickups.size() == pickup_count + 4, "反复清理不会重复发奖")
	game.player_foot = target.position
	var resin: int = game.inventory.resin
	game._collect_nearby()
	check(game.inventory.resin >= resin + 3, "首领奖励实际进入行囊")
	game.enter_region("post")
	game.enter_region("grove")
	game.get_node("Weather").tick(76)
	check(bosses.targets("grove").is_empty(), "旅行与天气不会复活已击败首领")
	for boss: Dictionary in bosses.bosses.values():
		boss.hp = 0
	game._remove_dead()
	check(game.finished and game.round_cleared and bosses.remaining() == 0, "全部守卫与六首领击败后胜利")
	await capture("victory")
	game.resume_exploration()
	check(not game.finished and bosses.remaining() == 0, "胜后继续自由探索，首领保持死亡")
	await open_fudi()
	check(bosses.remaining() == 6 and bosses.bosses.H02.hp == 220, "重开重置六首领与血量")
	game.enter_region("grove")
	target = bosses.bosses.H02
	game.player_foot = target.home + Vector2(65, 0)
	game.health = 1
	game.hurt_timer = 0
	target.cooldown = 0.0
	bosses.tick(0.01)
	bosses.tick(2)
	check(game.health == 0 and game.finished and not game.continue_button.visible, "首领致死进入失败结算")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "灵伴实际隔离存档逐字不变")
	print("BOSS_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
