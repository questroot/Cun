extends SceneTree
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)
	await frames()

func click(button: Control) -> void:
	await frames()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		button.get_viewport().push_input(event, true)
		await frames()

func open_fudi() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await frames()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()

func run_checks() -> void:
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Fudi-GM-"):
		printerr("Fudi GM tests require an isolated project and Cun-Fudi-GM-* test saves.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var original_save: String = FileAccess.get_file_as_string(data.SAVE_PATH)
	var original_progress: Dictionary = data.save_data.duplicate(true)
	await open_fudi()
	var gm = game.gm
	check(gm != null and gm.entry_button.visible and not gm.is_open() and gm.speed_multiplier() == 1.0, "福地 GM 入口默认关闭且移速为正常值")
	await click(game.menu_button)
	await click(gm.entry_button)
	check(gm.is_open() and game._paused(), "实际鼠标打开 GM 并暂停世界")
	check(gm.map_picker.item_count == Maps.IDS.size() and gm.quest_picker.item_count == 5, "面板列出十张地图和五个人物任务线")
	check(game.play_visible().get("world_occluded", false), "GM 遮挡时不输出世界观察目标")
	check(gm.get_meta("cun_play_blocked", false) and gm.entry_button.get_meta("cun_play_blocked", false), "GM 标记为玩家桥禁用控件")
	var frozen: Vector2 = game.player_foot
	game.cooldowns.j = 1.0
	key(KEY_D, true)
	game._process(0.1)
	key(KEY_D, false)
	check(game.player_foot == frozen and game.cooldowns.j == 1.0, "GM 打开时移动与战斗冷却暂停")
	await tap(KEY_M)
	await tap(KEY_C)
	await tap(KEY_B)
	await tap(KEY_J)
	check(not game.tools.is_open() and not game.equipment.is_open() and not game.journal.visible and game.cooldowns.j == 1.0, "GM 模态阻止地图、装备、行囊和攻击穿透")
	await frames()
	check(gm.panel.get_global_rect().encloses(gm.complete_all_button.get_global_rect()), "任务线操作在默认窗口内完整可见")
	await click(gm.close_button)
	check(not gm.is_open() and not game._paused(), "实际关闭按钮恢复探索")
	await tap(KEY_F8)
	check(gm.is_open(), "F8 打开 GM 面板")
	await tap(KEY_ESCAPE)
	check(not gm.is_open(), "Esc 关闭 GM 面板")
	game.tools.open_map()
	await tap(KEY_F8)
	check(not gm.is_open() and game.tools.atlas.visible, "地图模态期间不叠开 GM")
	game.tools.atlas.close()
	check(not gm.set_speed_multiplier(0) and not gm.set_speed_multiplier(20) and gm.speed_multiplier() == 1, "非法移速倍率不生效")
	check(gm.teleport("snowridge"), "可传送至霜脊瞭望岭")
	var spawn: Vector2 = game.player_foot
	key(KEY_D, true)
	game._process(0.05)
	key(KEY_D, false)
	var normal_distance: float = game.player_foot.distance_to(spawn)
	gm.teleport("snowridge")
	gm.set_speed_multiplier(5)
	key(KEY_D, true)
	game._process(0.05)
	key(KEY_D, false)
	check(normal_distance > 0 and is_equal_approx(game.player_foot.distance_to(spawn), normal_distance * 5), "物理 D 键实际位移提升为五倍")
	check(Engine.time_scale == 1.0 and gm.entry_button.text.contains("×5"), "加速不改变游戏时钟且入口显示当前倍率")
	gm.set_speed_multiplier(10)
	var obstacle: Rect2 = Maps.obstacles("snowridge")[0]
	game.player_foot = Vector2(obstacle.position.x - 28, obstacle.get_center().y)
	key(KEY_D, true)
	game._process(0.1)
	key(KEY_D, false)
	check(game.player_foot.x < obstacle.position.x and Maps.walkable("snowridge", game.player_foot), "十倍移速仍遵守障碍碰撞")
	gm.set_speed_multiplier(1)
	check(gm.speed_multiplier() == 1, "可恢复正常移动速度")
	var inventory: Dictionary = game.inventory.duplicate(true)
	var health: int = game.health
	var enemy_counts: Array[int] = []
	for id: String in Maps.IDS:
		enemy_counts.append(game.states[id].enemies.size())
	for id: String in Maps.IDS:
		check(gm.teleport(id) and game.region == id and game.tools.region == id and game.player_foot.is_equal_approx(Maps.MAPS[id].spawn * Maps.MAPS[id].size) and game.model.position == game.player_foot and Maps.walkable(id, game.player_foot), "指定地图传送使用安全出生点并更新模型: " + id)
	var previous_region: String = game.region
	var previous_foot: Vector2 = game.player_foot
	check(not gm.teleport("city") and not gm.teleport("missing") and game.region == previous_region and game.player_foot == previous_foot, "无效或其他游戏地图不能传送")
	game.projectiles.append({"position": game.player_foot, "velocity": Vector2.RIGHT, "life": 1.0})
	game.effects.append({"position": game.player_foot, "life": 0.2})
	gm.teleport("grove")
	check(game.projectiles.is_empty() and game.effects.is_empty() and game.hurt_timer >= 1.0, "传送复用切图清理攻击与抵达缓冲")
	gm.open()
	gm.map_picker.select(Maps.IDS.find("archive"))
	await click(gm.travel_button)
	check(game.region == "archive" and not gm.is_open() and not game._paused(), "实际传送按钮前往所选地图并关闭 GM")
	var before: Dictionary = game.states.duplicate(true)
	check(gm.complete_questline("不存在的人物") == -1 and game.states == before, "无效任务线不写入任何进度")
	game.states.grove.visited[0] = true
	gm.open()
	for i in range(gm.quest_picker.item_count):
		if gm.quest_picker.get_item_metadata(i) == "祝婶":
			gm.quest_picker.select(i)
	await click(gm.complete_button)
	check(game.states.grove.visited == [true, true, true] and game.states.wetland.visited == [true, true, true] and game._visited_total() == 6, "完成所选人物包含两张地图的六处线索并保留已读进度")
	check(gm.complete_questline("祝婶") == 0 and game._visited_total() == 6, "已完成任务线重复操作不重复增加进度")
	await click(gm.complete_all_button)
	check(game._visited_total() == Maps.site_total() and gm.progress.text.contains("30 / 30"), "一键完成全部三十处人物线索并刷新进度")
	check(gm.complete_questline("", true) == 0, "全部完成操作可安全重复")
	for i in range(Maps.IDS.size()):
		check(game.states[Maps.IDS[i]].enemies.size() == enemy_counts[i], "完成人物任务线保留区域战斗目标: " + Maps.IDS[i])
	check(game.inventory == inventory and game.health == health and not game.round_cleared, "传送和任务完成保留背包、生命与战斗结算")
	if DisplayServer.get_name() != "headless":
		await frames()
		await RenderingServer.frame_post_draw
		var path := "user://fudi_gm_preview.png"
		check(root.get_texture().get_image().save_png(path) == OK, "真实窗口渲染 GM 面板截图")
		print("FUDI_GM_CAPTURE: " + ProjectSettings.globalize_path(path))
	gm.close()
	game.open_journal()
	check(game.journal_text.text.contains("30 / 30") and game.journal_text.text.contains(str(Maps.MAPS.archive.sites[2][2])), "完成的任务线可在行囊见闻回看正文")
	game.journal.hide()
	check(data.save_data == original_progress and FileAccess.get_file_as_string(data.SAVE_PATH) == original_save, "全部 GM 操作不修改灵伴存档")
	await open_fudi()
	gm = game.gm
	check(gm.speed_multiplier() == 1.0 and game.region == "grove" and game._visited_total() == 0, "重新开局重置倍率、地图和任务线进度")
	OS.set_environment("CUN_PLAY_TOKEN", "fudi-gm-player-bridge-test-token-000000")
	gm.open()
	check(not gm.is_open() and not gm.set_speed_multiplier(5) and not gm.teleport("archive") and gm.complete_questline("", true) == -1 and gm.speed_multiplier() == 1.0 and game._visited_total() == 0, "玩家 MCP 会话拒绝全部 GM 操作")
	OS.unset_environment("CUN_PLAY_TOKEN")
	game.finished = true
	gm.open()
	check(not gm.is_open() and not gm.teleport("archive") and gm.complete_questline("", true) == -1, "结束状态不能绕过结算操作")
	game.queue_free()
	current_scene = null
	await create_timer(0.5).timeout
	print("FUDI_GM_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
