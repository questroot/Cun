extends SceneTree
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(button: Control) -> void:
	await frames()
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	button.get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	button.get_viewport().push_input(event, true)
	await frames()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://exploration_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图: " + label)
	print("EXPLORATION_CAPTURE: " + ProjectSettings.globalize_path(path))

func load_scene(path: String):
	if current_scene != null:
		current_scene.free()
	var instance = load(path).instantiate()
	root.add_child(instance)
	current_scene = instance
	instance.set_process(false)
	await frames()
	return instance

func run_checks() -> void:
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Exploration-"):
		printerr("Tests require an isolated Cun-Exploration-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	var progress: Dictionary = data.save_data.duplicate(true)
	var menu = await load_scene("res://scenes/MainMenu.tscn")
	check(str(ProjectSettings.get_setting("application/run/main_scene")).ends_with("MainMenu.tscn"), "默认入口为双游戏选择")
	await capture("menu")
	menu.atlas.open("city")
	await frames()
	await click(menu.atlas.region_buttons["grove"])
	check(menu.atlas.selected_region == "grove" and not menu.atlas.can_travel, "入口地图可点击福地区域查看初始资源")
	await capture("atlas_preview")
	menu.atlas.close()
	await click(menu.find_child("EnterFudi", true, false))
	await frames()
	game = current_scene
	game.set_process(false)
	check(game.name == "Fudi" and game.health == 100 and game.states.size() == 10, "通过实际入口按钮进入福地，初始十域与生命正确")
	for id: String in Maps.IDS:
		check(game.remaining_resources(id) == Catalog.REGIONS[id].resources, "地图配置与真实采集节点一致: " + id)
	check(Catalog.scarcity(0) == "已采尽" and Catalog.scarcity(1) == "极稀缺" and Catalog.scarcity(3) == "稀缺" and Catalog.scarcity(6) == "适中" and Catalog.scarcity(8) == "丰富", "稀缺度边界与已采尽正确")
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D]:
		game.player_foot = Vector2(640, 460)
		var before: Vector2 = game.player_foot
		key(code)
		game._process(0.1)
		key(code, false)
		var displacement: Vector2 = game.player_foot - before
		var expected: Vector2 = {KEY_W: Vector2.UP, KEY_A: Vector2.LEFT, KEY_S: Vector2.DOWN, KEY_D: Vector2.RIGHT}[code]
		check(displacement.normalized().is_equal_approx(expected) and game.model.walking, "WASD真实按键方向: " + OS.get_keycode_string(code))
	game.player_foot = Vector2(640, 460)
	key(KEY_W)
	key(KEY_D)
	game._process(0.1)
	key(KEY_W, false)
	key(KEY_D, false)
	check(is_equal_approx(game.player_foot.distance_to(Vector2(640, 460)), game.SPEED * 0.1), "斜向移动归一化，不额外加速")
	game.player_foot = Maps.MAPS[game.region].size - Vector2(24, 24)
	key(KEY_D)
	game._process(1)
	key(KEY_D, false)
	check(game.player_foot.x <= Maps.MAPS[game.region].size.x - 22, "地图边界阻止移出区域")
	game.player_foot = Vector2(640, 460)
	key(KEY_M)
	key(KEY_M, false)
	await frames()
	check(game.tools.atlas.visible, "M键打开地图")
	var before_pause: Vector2 = game.player_foot
	var enemy_before: Vector2 = game.states.grove.enemies[0].position
	key(KEY_D)
	key(KEY_J)
	game._process(1)
	key(KEY_D, false)
	key(KEY_J, false)
	check(game.player_foot == before_pause and game.states.grove.enemies[0].position == enemy_before and float(game.cooldowns.j) == 0, "地图阻止移动、攻击及敌人推进")
	await click(game.tools.atlas.region_buttons["quarry"])
	check(game.tools.atlas.selected_region == "quarry", "鼠标点击矿谷更新物品详情")
	await capture("atlas_quarry")
	var travel = game.tools.atlas.travel_button
	await click(travel)
	check(game.region == "quarry" and not game.tools.atlas.visible, "地图前往按钮切换实际区域并关闭地图")
	var pickup: Dictionary = game.states.quarry.pickups[0]
	game.player_foot = pickup.position
	game._collect_nearby()
	check(game.inventory.wood == 1 and game.remaining_resources("quarry").wood == 1, "采集入行囊且地图剩余数量减少")
	game.enter_region("grove")
	game.enter_region("quarry")
	check(game.remaining_resources("quarry").wood == 1 and game.inventory.wood == 1, "跨地图保留已采集进度，不重复刷新资源")
	game.tools.open_map()
	await frames()
	var detail_text := ""
	for child in game.tools.atlas.detail.get_children():
		if child is Label:
			detail_text += child.text
	check(detail_text.contains("木料   1 / 2   ·   极稀缺"), "地图按实时剩余数量显示稀缺等级")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	check(not game.tools.atlas.visible, "Esc关闭地图")
	await verify_large_maps()
	game.enter_region("quarry")
	# Controlled combat fixture, with real key events for each skill.
	game.player_foot = Vector2(600, 460)
	game.facing = Vector2.RIGHT
	var front := {"position": Vector2(660, 460), "hp": 60, "flash": 0.0}
	var behind := {"position": Vector2(540, 460), "hp": 60, "flash": 0.0}
	game.states.quarry.enemies = [front, behind]
	key(KEY_J)
	key(KEY_J, false)
	check(front.hp == 34 and behind.hp == 60, "J按朝向近战命中，背后敌人不受伤")
	key(KEY_J)
	key(KEY_J, false)
	check(front.hp == 34, "近战冷却阻止连续重复伤害")
	game.cooldowns.j = 0.0
	var echo := InputEventKey.new()
	echo.keycode = KEY_J
	echo.pressed = true
	echo.echo = true
	root.push_input(echo)
	check(front.hp == 34, "系统按键重复事件不重复触发技能")
	key(KEY_K)
	key(KEY_K, false)
	check(game.projectiles.size() == 1, "K按键生成朝向灵弹")
	game._tick_projectiles(0.1)
	check(front.hp == 14 and behind.hp == 60 and game.projectiles.is_empty(), "灵弹沿轨迹命中，命中后消失")
	key(KEY_L)
	key(KEY_L, false)
	check(game.states.quarry.enemies.size() == 1 and behind.hp == 18, "L范围攻击覆盖身后并移除死亡守卫")
	await capture("combat")
	check(not game.attack("l"), "范围攻击冷却有效")
	game.cooldowns.l = 0.0
	game.states.quarry.enemies = [{"position": Vector2(900, 460), "hp": 60, "flash": 0.0}]
	game.attack("l")
	check(game.states.quarry.enemies[0].hp == 60, "超出技能范围不受伤")
	game.states.quarry.enemies[0].position = game.player_foot
	game.hurt_timer = 0.0
	game._process(0.1)
	check(game.health == 90 and game.hurt_timer > 0, "接触守卫扣血并启用无敌间隔")
	game._process(0.1)
	check(game.health == 90, "无敌间隔防止每帧扣血")
	game.tools.switch_game()
	await frames()
	check(game.tools.confirm.visible, "切换福地前提示本轮进度重置")
	await capture("switch_confirm")
	var paused_health: int = game.health
	game._process(2)
	check(game.health == paused_health, "切换确认期间暂停战斗")
	game.tools.confirm.hide()
	game.enter_region("grove")
	await capture("fudi")
	game.health = 10
	game.hurt_timer = 0
	game.states.grove.enemies = [{"position": game.player_foot, "hp": 60, "flash": 0.0}]
	game._process(0.1)
	check(game.finished and game.outcome.visible and game.health == 0, "生命归零显示失败与重开入口")
	check(not game.attack("j"), "结算后禁止攻击")
	await capture("defeat")
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	check(game.health == 100 and game.inventory.wood == 0 and not game.finished and game.remaining_resources("quarry").wood == 2, "重新开始重置生命、资源及本轮状态")
	for id: String in game.states:
		game.states[id].enemies.clear()
	for boss: Dictionary in game.get_node("Bosses").bosses.values():
		boss.hp = 0
	game._remove_dead()
	check(game.finished and game.outcome.visible and game.result.text.contains("十域已肃清"), "清理全部十域显示胜利结算")
	await capture("victory")
	await click(game.continue_button)
	if not is_instance_valid(game):
		check(false, "继续探索保留当前福地场景")
		quit(1)
		return
	game._process(0.1)
	check(not game.finished and not game.outcome.visible and game.round_cleared, "胜利后可继续探索，不重复弹出结算")
	game.tools.switch_game()
	await frames()
	await click(game.tools.confirm_ok)
	check(current_scene.name == "MainMenu", "确认切换返回游戏选择大厅")
	await click(current_scene.find_child("EnterSpirit", true, false))
	check(current_scene.name == "MainCity" and data.save_data == progress, "从福地切换进入灵伴并保留原有成长")
	current_scene.exploration_tools.switch_game()
	await frames()
	check(current_scene.name == "MainMenu", "灵伴内切换按钮返回共同入口")
	for scene_name: String in ["MainCity", "Outskirts", "WaterActivity"]:
		var zone = await load_scene("res://scenes/%s.tscn" % scene_name)
		zone.exploration_tools.open_map()
		await frames()
		check(zone.exploration_tools.atlas.visible, "原有场景地图入口: " + scene_name)
		var foot: Vector2 = zone.player_foot
		zone._process(1)
		check(zone.player_foot == foot, "原有场景地图暂停移动: " + scene_name)
		await click(zone.exploration_tools.atlas.region_buttons["water_activity"])
		check(zone.exploration_tools.atlas.selected_region == "water_activity", "原有场景可点击查看浮台物品: " + scene_name)
		if scene_name == "WaterActivity":
			await capture("water_atlas")
		zone.exploration_tools.atlas.close()
		if scene_name == "MainCity":
			await capture("city_tools")
	check(data.save_data == progress and FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "双游戏、采集、地图及重开不修改灵伴存档")
	print("EXPLORATION_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func reachable_cells(id: String) -> Dictionary:
	var seen: Dictionary = {}
	var start: Vector2i = Vector2i((Maps.MAPS[id].spawn * Maps.MAPS[id].size / 64.0).floor())
	var frontier: Array[Vector2i] = [start]
	seen[start] = true
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if not seen.has(next) and Maps.walkable(id, (Vector2(next) + Vector2(0.5, 0.5)) * 64, 28):
				seen[next] = true
				frontier.append(next)
	return seen

func verify_large_maps() -> void:
	await verify_connections()
	for id: String in Maps.IDS:
		game.enter_region(id)
		var extent: Vector2 = Maps.MAPS[id].size
		check(extent.x >= 3600 and extent.y >= 2400, "实际世界尺寸扩大且超过单屏: " + id)
		var reachable := reachable_cells(id)
		var targets: Array[Vector2] = []
		for i in range(3):
			targets.append(Maps.site_position(id, i))
		for exit: Array in Maps.MAPS[id].exits:
			targets.append(exit[1] * extent)
		for pickup: Dictionary in game.states[id].pickups:
			targets.append(pickup.position)
		for enemy: Dictionary in game.states[id].enemies:
			targets.append(enemy.position)
		var accessible := true
		for point: Vector2 in targets:
			accessible = accessible and Maps.walkable(id, point) and reachable.has(Vector2i((point / 64.0).floor()))
		check(accessible, "全部地标、出口、资源、敌人从出生点连通: " + id)
		var roads_clear := true
		for road: Array in Maps.MAPS[id].roads:
			for n in range(road.size() - 1):
				var start: Vector2 = road[n] * extent
				var end: Vector2 = road[n + 1] * extent
				var steps := maxi(1, ceili(start.distance_to(end) / 24))
				for sample in range(steps + 1):
					roads_clear = roads_clear and Maps.walkable(id, start.lerp(end, float(sample) / steps), 46)
		check(roads_clear, "整段道路保留通行宽度，路线不穿过障碍: " + id)
		var obstacle: Rect2 = Maps.obstacles(id)[0]
		var before := Vector2(obstacle.position.x - 35, obstacle.get_center().y)
		var stopped: Vector2 = game.move_world(before, Vector2(obstacle.size.x + 100, 0))
		check(stopped.x < obstacle.position.x - 21, "大步移动不能穿过地形障碍: " + id)
		game.player_foot = Maps.site_position(id, 2)
		key(KEY_E)
		key(KEY_E, false)
		check(game.dialogue.visible and not game.states[id].visited[2], "后续线索要求先调查前序地标: " + id)
		key(KEY_ESCAPE)
		key(KEY_ESCAPE, false)
		for i in range(3):
			game.player_foot = Maps.site_position(id, i)
			game._process(0)
			key(KEY_E)
			key(KEY_E, false)
			check(game.states[id].visited[i] and game.dialogue.visible, "真实E键调查人物线索 %s/%d" % [id, i])
			var foot: Vector2 = game.player_foot
			var health: int = game.health
			key(KEY_D)
			key(KEY_J)
			key(KEY_J, false)
			game._process(1)
			key(KEY_D, false)
			check(game.player_foot == foot and game.health == health and not game.attack("k"), "读剧情时暂停移动与战斗: %s/%d" % [id, i])
			if i == 0:
				await capture("story_" + id)
			key(KEY_E)
			key(KEY_E, false)
		await capture("map_" + id)
		game.tools.open_map()
		await frames()
		check(game.tools.atlas.travel_button.get_global_rect().end.y < 680, "资源长列表不遮挡固定旅行按钮: " + id)
		await click(game.tools.atlas.region_buttons["grove"])
		await click(game.tools.atlas.travel_button)
		check(game.region == "grove" and not game.tools.atlas.visible and game.states[id].visited == [true, true, true], "跨区旅行保留人物线索与正确返回: " + id)
	check(game._visited_total() == 30 and Maps.site_total() == 30, "十张地图共30处见闻可以完成")
	game.enter_region("grove")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	var before_walk: Vector2 = game.player_foot
	key(KEY_S)
	for i in range(45):
		game._process(0.05)
	key(KEY_S, false)
	check(game.player_foot.y - before_walk.y > 500 and game.camera_origin.y > 1000 and game.model.walking, "真实连续WASD走出旧范围，镜头跟随且播放行走")
	game.player_foot = Maps.MAPS.grove.size - Vector2(30, 30)
	game._process(0)
	check(game.camera_origin.is_equal_approx(Maps.MAPS.grove.size - game.ARENA.size), "远端镜头限制在世界边界内")
	game.player_foot = Maps.MAPS.grove.exits[1][1] * Maps.MAPS.grove.size
	key(KEY_E)
	key(KEY_E, false)
	check(game.region == "post" and Maps.walkable("post", game.player_foot), "真实E键通过地图出口，抵达相邻区域安全位置")
	game.tools.switch_game()
	check(game.tools.confirm.visible, "新增邮驿切换游戏保留进度重置提醒")
	game.tools.confirm.hide()
	game.enter_region("refuge")
	game.tools.switch_game()
	check(game.tools.confirm.visible, "新增救援营切换游戏保留进度重置提醒")
	game.tools.confirm.hide()
	game.player_foot = Maps.MAPS.refuge.spawn * Maps.MAPS.refuge.size
	game.health = 40
	key(KEY_E)
	key(KEY_E, false)
	check(game.health == 100 and game.states.refuge.rested, "休息点按E恢复生命")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	game.health = 80
	key(KEY_E)
	key(KEY_E, false)
	check(game.health == 80, "休息物资不能重复领取")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	key(KEY_B)
	key(KEY_B, false)
	check(game.journal.visible and game.journal_text.get_parsed_text().contains("温砚") and game.journal_text.get_parsed_text().contains("30 / 30"), "B打开完整行囊和十域人物的已发现见闻")
	var foot: Vector2 = game.player_foot
	key(KEY_D)
	game._process(0.1)
	key(KEY_D, false)
	check(game.player_foot == foot, "行囊与见闻暂停游戏")
	await capture("journal")
	key(KEY_B)
	key(KEY_B, false)
	check(not game.journal.visible, "B关闭行囊")
	game.health = 100

func verify_connections() -> void:
	var reached := {"grove": true}
	var pending: Array[String] = ["grove"]
	var cursor := 0
	while cursor < pending.size():
		var id := pending[cursor]
		cursor += 1
		for exit: Array in Maps.MAPS[id].exits:
			if not reached.has(exit[0]):
				reached[exit[0]] = true
				pending.append(exit[0])
	check(reached.size() == 10 and Catalog.FUDI_REGIONS == Maps.IDS, "十地出口图连通，旅行白名单与实际地图一致")
	for id: String in Maps.IDS:
		for exit: Array in Maps.MAPS[id].exits:
			game.enter_region(id)
			game.player_foot = exit[1] * Maps.MAPS[id].size
			key(KEY_E)
			key(KEY_E, false)
			var safe_arrival := false
			for reverse: Array in Maps.MAPS[exit[0]].exits:
				if reverse[0] == id:
					var gate: Vector2 = reverse[1] * Maps.MAPS[exit[0]].size
					safe_arrival = Maps.walkable(exit[0], game.player_foot) and is_equal_approx(game.player_foot.distance_to(gate), 100.0)
			check(game.region == exit[0] and safe_arrival, "实际E键通行及双向安全落点：%s → %s" % [id, exit[0]])
	game.tools.open_map()
	await frames()
	var atlas = game.tools.atlas
	var buttons: Array = atlas.region_buttons.values()
	var visible := buttons.size() == 13
	var separated := true
	for i in range(buttons.size()):
		visible = visible and atlas.map_surface.get_global_rect().encloses(buttons[i].get_global_rect())
		for j in range(i + 1, buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):
				print("Overlapping atlas buttons: %s %s / %s %s" % [buttons[i].name, buttons[i].get_global_rect(), buttons[j].name, buttons[j].get_global_rect()])
			separated = separated and not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect())
	check(visible and separated, "三张灵伴区域与十张福地图标全部可见且不重叠")
	var center: Vector2 = atlas._ring_center()
	var outer_radius: float = atlas._outer_radius()
	var rings_valid := Maps.INNER_RING.size() == 5 and Maps.OUTER_RING.size() == 5
	for ring: Array in [Maps.INNER_RING, Maps.OUTER_RING]:
		for i in range(ring.size()):
			var id: String = ring[i]
			var node: Button = atlas.region_buttons[id]
			var distance := (node.position + node.size * 0.5).distance_to(center)
			var expected := outer_radius * (0.5 if ring == Maps.INNER_RING else 1.0)
			rings_valid = rings_valid and is_equal_approx(distance, expected)
			var destinations := []
			for exit: Array in Maps.MAPS[id].exits:
				destinations.append(exit[0])
			var other: Array = Maps.OUTER_RING if ring == Maps.INNER_RING else Maps.INNER_RING
			rings_valid = rings_valid and destinations.size() == 3 and destinations.has(ring[(i + 1) % 5]) and destinations.has(ring[(i + 4) % 5]) and destinations.has(other[i])
	check(rings_valid, "内外环同心且大圆半径为小圆两倍，真实出口对应双环与五条辐射通道")
	for id: String in Maps.IDS:
		await click(atlas.region_buttons[id])
		check(atlas.selected_region == id and atlas.travel_button.visible, "同心圆节点可实际点击并显示旅行入口：" + id)
	await capture("ten_regions")
	atlas.close()
