extends SceneTree
const Catalog = preload("res://scripts/scenes/trap_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var checks := 0
var failures := 0
var game
var traps

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

func frames() -> void:
	for index in range(3):
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://traps_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图: " + label)
	print("TRAPS_CAPTURE: " + ProjectSettings.globalize_path(path))

func load_game() -> void:
	if current_scene != null:
		current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	traps = game.get_node("Traps")
	traps.rng.seed = 7283401

func test_point(id: String) -> Vector2:
	for y in range(500, int(Maps.MAPS[id].size.y) - 200, 150):
		for x in range(600, int(Maps.MAPS[id].size.x) - 200, 150):
			if traps.valid_point(id, Vector2(x, y), 85):
				return Vector2(x, y)
	return Vector2.INF

func prepare(id: String) -> Vector2:
	traps.hazards.clear()
	game.enter_region(id)
	game.player_foot = test_point(id)
	game._update_camera()
	game.health = 100
	game.hurt_timer = 0
	traps.grace = 0
	traps.slow_left = 0
	traps.timers[id] = 10.0
	return game.player_foot

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Traps-"):
		printerr("Trap checks require an isolated Cun-Traps-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	var progress: Dictionary = data.save_data.duplicate(true)
	await load_game()
	check(traps.initialized and traps.records.size() == Maps.IDS.size() and traps.grace == 3, "十域陷阱模块与入场保护初始化")
	check(traps.hazards.is_empty() and not traps.spawn("thorns", test_point("grove")), "保护期间不生成陷阱")
	for id: String in Maps.IDS:
		var point := prepare(id)
		check(point != Vector2.INF and Catalog.REGIONS[id].size() == 2, "每张地图有两类陷阱和可放置区域: " + id)
		var map: Dictionary = Maps.MAPS[id]
		var protected_points: Array[Vector2] = [map.spawn * map.size]
		for site: Array in map.sites:
			protected_points.append(site[1] * map.size)
		for exit: Array in map.exits:
			protected_points.append(exit[1] * map.size)
		var protected := true
		for safe: Vector2 in protected_points:
			protected = protected and not traps.valid_point(id, safe, 80)
		check(protected and not traps.valid_point(id, Maps.obstacles(id)[0].get_center(), 60) and not traps.valid_point(id, Vector2(15, 15), 60), "出生点、全部地标/出口、障碍与边界不放置危险: " + id)
		for kind: String in Catalog.REGIONS[id]:
			var config: Dictionary = Catalog.TRAPS[kind]
			traps.hazards.clear()
			game.health = 100
			game.hurt_timer = 0
			game.player_foot = point
			check(traps.spawn(kind, point), "生成当地陷阱: " + kind)
			var damage: int = traps.hazards[0].damage
			traps.tick(float(config.warning) - 0.05)
			check(game.health == 100 and not traps.hazards[0].hit, "完整预警期无伤害: " + kind)
			await capture(kind + "_warning")
			traps.tick(0.06)
			check(game.health == 100 - damage and traps.hazards[0].hit, "范围内爆发伤害与预警一致: " + kind)
			check(Maps.walkable(id, game.player_foot), "陷阱击退不穿地形或边界: " + kind)
			await capture(kind + "_active")
			game.hurt_timer = 0
			game.player_foot = point
			traps.tick(0.1)
			check(game.health == 100 - damage, "同一次爆发最多命中一次: " + kind)
			traps.tick(float(config.active) + 0.1)
			check(traps.hazards.is_empty(), "爆发结束移除危险: " + kind)
		# Seeded selection is reproducible, remains local and favors matching weather.
		var first: String = Catalog.REGIONS[id][0]
		game.states[id].weather = Catalog.TRAPS[first].weather[0]
		var counts := {Catalog.REGIONS[id][0]: 0, Catalog.REGIONS[id][1]: 0}
		for roll in range(300):
			var chosen: String = traps.choose_kind(id)
			counts[chosen] += 1
		check(int(counts[first]) > 160 and int(counts[Catalog.REGIONS[id][1]]) > 30, "天气权重提高当地对应陷阱概率，另一种仍可触发: " + id)

	var point := prepare("grove")
	check(not traps.spawn("surge", point), "其他地图的陷阱不能在灶街生成")
	game.states.grove.weather = "rain"
	traps.spawn("thorns", point)
	check(traps.hazards[0].boosted and traps.hazards[0].damage == 10, "润雨增强蔓刺，预警明确显示10伤害")
	key(KEY_D, true)
	for frame in range(5):
		game._process(0.1)
		traps.tick(0.1)
	key(KEY_D, false)
	traps.tick(1.0)
	check(game.player_foot.distance_to(point) > 64 and game.health == 100, "真实WASD按键走出预警圈可闪避")
	traps.tick(2)
	check(traps.records.grove.dodged > 0, "未命中的爆发记为闪避")
	prepare("grove")
	traps.spawn("thorns", point)
	traps.tick(1.5)
	var start: Vector2 = game.player_foot
	key(KEY_D, true)
	game._process(0.1)
	key(KEY_D, false)
	check(is_equal_approx(start.distance_to(game.player_foot), game.SPEED * 0.65 * 0.1), "陷阱减速实际影响WASD移动")
	traps.tick(3)
	start = game.player_foot
	key(KEY_D, true)
	game._process(0.1)
	key(KEY_D, false)
	check(is_equal_approx(start.distance_to(game.player_foot), game.SPEED * 0.1), "减速到期恢复原速度")
	prepare("grove")
	traps.spawn("thorns", point)
	game.hurt_timer = 1.0
	traps.tick(1.5)
	check(game.health == 100 and not traps.hazards[0].hit, "与怪物共享受伤保护，保护期间不扣血")
	game.hurt_timer = 0
	traps.tick(0.1)
	check(game.health == 90, "受伤保护结束后仍在危险区会命中")
	prepare("grove")
	traps.spawn("thorns", point)
	for modal: String in ["map", "dialogue", "journal", "confirm"]:
		match modal:
			"map": game.tools.open_map()
			"dialogue": game.dialogue.show()
			"journal": game.open_journal()
			"confirm": game.tools.confirm.show()
		var before: Dictionary = traps.hazards[0].duplicate(true)
		var timer: float = traps.timers.grove
		var slow: float = traps.slow_left
		traps.tick(10)
		check(traps.hazards[0] == before and traps.timers.grove == timer and traps.slow_left == slow and game.health == 100, "模态界面暂停预警、触发和效果计时: " + modal)
		game.tools.atlas.close()
		game.dialogue.hide()
		game.journal.hide()
		game.tools.confirm.hide()
	game.tools.open_map()
	await capture("atlas")
	game.tools.atlas.close()
	traps.slow_left = 2
	traps.slow_scale = 0.65
	var grove_timer: float = traps.timers.grove
	game.enter_region("post")
	traps.tick(1)
	check(traps.hazards.is_empty() and traps.grace == 2 and traps.movement_scale() == 1, "转图清除旧预警与减速，保留新图保护期")
	check(traps.timers.grove == grove_timer, "非当前地图的触发倒计时冻结")
	game.enter_region("grove")
	check(traps.grace == 3 and traps.timers.grove == grove_timer, "返回地图不重抽倒计时，重新给予入场保护")
	prepare("grove")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game._update_camera()
	traps.timers.grove = 0
	traps.tick(0.1)
	check(traps.hazards.is_empty() and traps.timers.grove == 2, "安全区触发检查失败后延迟重试，无凭空伤害")
	prepare("grove")
	var positions: Array[Vector2] = []
	var kinds: Dictionary = {}
	var intervals: Dictionary = {}
	var valid := true
	for roll in range(25):
		traps.hazards.clear()
		traps.timers.grove = 0
		traps.tick(0.1)
		if traps.hazards.is_empty():
			valid = false
			continue
		var hazard: Dictionary = traps.hazards[0]
		positions.append(hazard.position)
		kinds[hazard.kind] = true
		intervals[int(float(traps.timers.grove) * 100)] = true
		valid = valid and traps.valid_point("grove", hazard.position, Catalog.TRAPS[hazard.kind].radius) and Rect2(game.camera_origin, game.ARENA.size).has_point(hazard.position) and float(traps.timers.grove) >= 8 and float(traps.timers.grove) <= 14
	check(valid and positions.size() == 25 and positions[0] != positions[1] and kinds.size() == 2 and intervals.size() > 5, "实际随机调度生成不同类型、坐标与8–14秒间隔，且位于可见合法区域")
	prepare("grove")
	traps.spawn("thorns", point)
	game._end_round(true)
	traps.tick(5)
	check(traps.hazards[0].age == 0 and game.health == 100, "胜利结算暂停陷阱")
	game.resume_exploration()
	game.hurt_timer = 0
	traps.tick(0.2)
	check(is_equal_approx(traps.hazards[0].age, 0.2), "胜利后继续探索恢复陷阱计时")
	game.health = 5
	traps.tick(1.3)
	check(game.finished and game.health == 0 and game.outcome.visible and not game.continue_button.visible, "陷阱致命伤立即进入失败结算")
	var age: float = traps.hazards[0].age
	traps.tick(5)
	check(traps.hazards[0].age == age, "死亡结算期间陷阱冻结")
	await capture("defeat")
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	traps = game.get_node("Traps")
	check(game.health == 100 and traps.hazards.is_empty() and traps.records.grove.spawned == 0 and traps.grace > 0 and traps.movement_scale() == 1, "真实重开重置生命、陷阱记录、保护和减速")
	prepare("grove")
	traps.timers.grove = 0
	game.set_process(true)
	await frames()
	game.set_process(false)
	check(traps.hazards.size() == 1 and game.health == 100, "真实逐帧自动随机触发预警，无需手动生成")
	check(data.save_data == progress and FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "陷阱、伤害、转图与重开均不修改灵伴存档")
	print("TRAPS_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
