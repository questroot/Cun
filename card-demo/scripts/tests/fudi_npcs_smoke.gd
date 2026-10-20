extends SceneTree
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const NPCs = preload("res://scripts/scenes/fudi_npcs.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + filename + ".png"))

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Fudi-NPC-"):
		printerr("NPC checks require isolated test saves.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var save_before := FileAccess.get_file_as_string(data.SAVE_PATH)
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	var npcs = game.npcs
	check(npcs != null and npcs.actors.size() == 10, "十位人物各一个实例")
	var residents := 0
	for id: String in NPCs.DEFINITIONS:
		if id == "changdaozhe": continue
		residents += 1
		var config: Dictionary = NPCs.DEFINITIONS[id]
		var foot := NPCs.fixed_position(id)
		check(Maps.walkable(config.region, foot, 32), id + "脚底位于可走道路")
		check(not NPCs.reserved(config.region, Maps.MAPS[config.region].spawn * Maps.MAPS[config.region].size), id + "不占出生休息点")
		var clear := true
		for site: Array in Maps.MAPS[config.region].sites:
			if foot.distance_to(site[1] * Maps.MAPS[config.region].size) < 160: clear = false
		check(clear, id + "与既有调查交互分开")
		for enemy: Dictionary in game.states[config.region].enemies:
			check(enemy.home.distance_to(foot) >= 230, id + "初始守卫不压在人物身上")
		game.enter_region(config.region)
		game.player_foot = foot + Vector2(0, 45)
		game.model.position = game.player_foot
		game._update_camera()
		npcs.refresh()
		check(game.interaction_target().get("npc_id", "") == id, id + "附近E优先正确交谈")
		check(npcs.actors[id].visible and npcs.actors[id].get_node("QuestMarker").visible, id + "本地图人物和头顶标记可见")
		check(npcs.task_state(id) == "available" and npcs.marker_kind(id) == "exclamation", id + "未接任务为感叹号")
		await tap(KEY_E)
		check(game.dialogue.visible and npcs.tasks[id] == "active", id + "真实E接取并打开对白")
		check(npcs.task_state(id) == "active" and npcs.marker_kind(id) == "question", id + "接取后暗问号")
		check(game._paused() and game.play_visible().get("world_occluded", false), id + "对白暂停并遮挡观察")
		await tap(KEY_ESCAPE)
		check(not game.dialogue.visible, id + "真实Esc关闭对白")
		if id in ["shen-heng", "ye-ting", "cen-chi"]:
			game.player_foot = foot + Vector2(82, 14)
			game.model.position = game.player_foot
			game._update_camera()
			npcs.refresh()
			await capture("npc-active-" + id)
		for need: Array in config.needs:
			# Test fixture supplies existing investigation progress; no gameplay shortcut added.
			game.states[need[0]].visited[int(need[1])] = true
		npcs.refresh()
		check(npcs.task_state(id) == "ready" and npcs.actors[id].get_node("QuestMarker").modulate == Color.WHITE, id + "调查达成后亮问号")
		if id in ["shen-heng", "ye-ting", "cen-chi"]:
			await capture("npc-ready-" + id)
		game.player_foot = foot + Vector2(0, 45)
		game.model.position = game.player_foot
		await tap(KEY_E)
		check(npcs.tasks[id] == "complete" and not npcs.actors[id].get_node("QuestMarker").visible, id + "真实E回报后隐藏标记")
		await tap(KEY_ESCAPE)
		# Reset only fixtures to capture an available quest on the actual painted map.
		npcs.tasks[id] = "available"
		for map_id: String in Maps.IDS: game.states[map_id].visited = [false, false, false]
		npcs.refresh()
		game.player_foot = foot + Vector2(82, 14)
		game.model.position = game.player_foot
		game._update_camera()
		npcs.refresh()
		game.world_canvas.queue_redraw()
		await capture("npc-" + id)
	check(residents == 9, "九位固定人物按剧情分驻九地")
	# Complete lifecycle also applies to the unique roaming quest giver.
	game.enter_region(npcs.wander_region)
	game.player_foot = npcs.wander_foot
	game._update_camera()
	npcs.refresh()
	check(game.interaction_target().get("npc_id", "") == "changdaozhe", "巡游人物可交谈")
	var stay: Vector2 = npcs.wander_foot
	npcs.tick(0.1)
	check(npcs.wander_foot == stay, "玩家靠近时停步等候")
	await tap(KEY_E)
	check(game.dialogue.visible and npcs.tasks.changdaozhe == "active", "长祷者E接取探索委托")
	var frozen_region: String = npcs.wander_region
	var frozen_wait: float = npcs.wander_wait
	npcs.tick(0.1)
	check(npcs.wander_foot == stay and npcs.wander_region == frozen_region and npcs.wander_wait == frozen_wait, "对白暂停巡游与停留计时")
	await tap(KEY_ESCAPE)
	for need: Array in NPCs.DEFINITIONS.changdaozhe.needs:
		game.states[need[0]].visited[int(need[1])] = true
	check(npcs.task_state("changdaozhe") == "ready", "巡游者达成条件后可回报")
	await tap(KEY_E)
	check(npcs.tasks.changdaozhe == "complete", "巡游者交谈完成一次记录")
	await tap(KEY_ESCAPE)
	game.player_foot = npcs.wander_foot + Vector2(82, 14)
	game.model.position = game.player_foot
	game._update_camera()
	npcs.refresh()
	await capture("npc-changdaozhe")
	# Route simulation uses the production tick and speed. Every step stays on terrain.
	game.player_foot = Vector2(-9999, -9999)
	npcs.rng.seed = 54121
	var walked := 0.0
	var safe := true
	var connected := true
	var transitions := 0
	for iteration in range(160000):
		var before: Vector2 = npcs.wander_foot
		var previous: String = npcs.wander_region
		npcs.tick(0.1)
		if previous == npcs.wander_region:
			walked += before.distance_to(npcs.wander_foot)
			if not Maps.walkable(npcs.wander_region, npcs.wander_foot, 20): safe = false
		else:
			transitions += 1
			var linked := false
			for gate: Array in Maps.MAPS[previous].exits:
				if gate[0] == npcs.wander_region and before.distance_to(gate[1] * Maps.MAPS[previous].size) < 160: linked = true
			connected = connected and linked
		if npcs.visited_regions.size() == 10: break
	check(walked > 1000 and transitions >= 9, "真实巡游tick连续行走并多次过图")
	check(safe and connected, "巡游所有采样不穿墙且仅从相连出口过图")
	check(npcs.visited_regions.size() == 10, "固定随机种子巡游可达全部十图")
	check(npcs.tasks.changdaozhe == "complete", "任务状态随唯一巡游实体跨地图保留")
	print("NPC_TRAVEL: maps=", npcs.visited_regions, " transitions=", transitions, " walked=", walked)
	# Menu / atlas / journal / equipment pause independent NPC simulation.
	for kind: String in ["menu", "map", "journal", "equipment", "gm"]:
		match kind:
			"menu": game.toggle_menu()
			"map": game.tools.open_map()
			"journal": game.open_journal()
			"equipment": game.equipment.open()
			"gm": game.gm.open()
		var foot: Vector2 = npcs.wander_foot
		var time: float = npcs.clock
		npcs.tick(0.1)
		check(game._paused() and npcs.wander_foot == foot and npcs.clock == time, kind + "模态暂停巡游")
		check(npcs.play_visible().is_empty(), kind + "模态不泄漏人物信息")
		match kind:
			"menu": game.close_menu()
			"map": game.tools.atlas.close()
			"journal": game.journal.hide()
			"equipment": game.equipment.close()
			"gm": game.gm.close()
	game.enter_region("grove")
	game.player_foot = NPCs.fixed_position("ye-ting") + Vector2(0, 45)
	game._update_camera()
	npcs.refresh()
	var visible: Array = npcs.play_visible()
	check(visible.any(func(item: Dictionary) -> bool: return item.name == "叶汀"), "实际屏内人物进入公开观察")
	check(not visible.any(func(item: Dictionary) -> bool: return item.name == "沈衡"), "其他地图人物不泄漏")
	for item: Dictionary in visible:
		check(not item.has("needs") and not item.has("route") and not item.has("quest"), "公开观察仅画面人物及标记")
	game.camera_origin = Vector2.ZERO
	check(npcs.play_visible().is_empty(), "屏外人物不进入观察")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == save_before, "NPC位置/任务不写实际灵伴存档")
	game.queue_free()
	await frames()
	print("NPC_RESULT: checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
