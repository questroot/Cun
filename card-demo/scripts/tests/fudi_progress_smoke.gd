extends SceneTree
const Save = preload("res://scripts/scenes/fudi_save.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Armor = preload("res://scripts/scenes/equipment_effects.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", description])

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)

func click(button: Button) -> void:
	await frames()
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
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://fudi_progress_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "窗口截图 " + label)
	print("FUDI_PROGRESS_CAPTURE: " + ProjectSettings.globalize_path(path))

func open_game() -> void:
	if current_scene != null: current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Fudi-Progress-"):
		quit(2)
		return
	await frames()
	var spirit_path: String = root.get_node("DataManager").SAVE_PATH
	root.get_node("DataManager").write_save()
	var spirit_before := FileAccess.get_file_as_string(spirit_path)
	var sea_before := FileAccess.get_file_as_string("user://sea_chapter_v1.json") if FileAccess.file_exists("user://sea_chapter_v1.json") else ""
	await open_game()
	check(game.persistence.ready_to_save and not game.persistence.blocked, "真实场景完成独立存档初始化")
	if "--save-on-close" in OS.get_cmdline_user_args():
		game.health = 82
		game.inventory.wood = 6
		game.persistence.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		check(game.persistence.read_save().health == 82, "关闭窗口通知先保存完整进度")
	elif "--verify-close" in OS.get_cmdline_user_args():
		check(game.health == 82 and game.inventory.wood == 6, "关闭窗口后新进程恢复最新进度")
	elif "--verify-relaunch" in OS.get_cmdline_user_args():
		await verify_relaunch()
	else:
		await check_story()
		await check_storage()
	check(FileAccess.get_file_as_string(spirit_path) == spirit_before, "福地存读、任务及强化保持灵伴档逐字不变")
	var sea_after := FileAccess.get_file_as_string("user://sea_chapter_v1.json") if FileAccess.file_exists("user://sea_chapter_v1.json") else ""
	check(sea_before == sea_after, "福地保持海上档逐字不变")
	print("FUDI_PROGRESS_RESULT: %d checks, %d failures" % [checks, failures])
	if current_scene != null:
		current_scene.free()
		current_scene = null
	if "--save-on-close" in OS.get_cmdline_user_args():
		# The close notification already queued quit; do not suspend a coroutine past exit.
		quit(1 if failures else 0)
		return
	await frames()
	quit(1 if failures else 0)

func check_story() -> void:
	check(Armor.armor_damage(20, 0) == 20 and Armor.armor_damage(20, 20) == 14 and Armor.armor_damage(20, 40) == 10 and Armor.armor_damage(20, 80) == 7, "防御0/20/40/80的独立数值表为20/14/10/7伤害")
	check(Armor.armor_damage(20, 100000) == 6 and Armor.armor_damage(1, 100000) == 1, "防御70%上限与至少1点伤害")
	for id: String in ["s3-top", "s3-legs", "s3-boots", "s3-necklace", "s3-ring"]:
		var upgraded: String = game.equipment.fusion.register_item(id, 3)
		game.inventory[upgraded] = 1
		game.equipment.equip_item(upgraded)
	check(game.equipment.bonuses().defense == 28 and game.incoming_damage(16) == 8 and game.incoming_damage(25) == 12, "镜潮五件+3仍承受首领8–12点伤害")
	game.equipment.equipped.clear()
	game.player_foot = Maps.site_position("grove", 0)
	game.model.position = game.player_foot
	game._update_camera()
	await tap(KEY_E)
	check(game.dialogue.visible and game.story.action.visible and game.states.grove.visited[0], "真实E调查旧灶台并显示祝婶接取入口")
	await click(game.story.action)
	check(game.story.state.stage == 1 and game.story.action.disabled, "真实按钮接取，缺材料时不允许交付")
	game.story.perform()
	check(game.story.state.stage == 1 and game.inventory.herb == 0 and game.inventory.wood == 0, "直接重复请求也无法跳过材料检查")
	game.inventory.herb = 3
	game.inventory.wood = 2
	game.story.perform()
	check(game.story.state.stage == 1 and game.inventory.herb == 3, "未核对药圃不能交付")
	game.dialogue.hide()
	game.player_foot = Maps.site_position("grove", 1)
	await tap(KEY_E)
	check(game.states.grove.visited[1], "真实E完成药圃前序调查")
	game.dialogue.hide()
	game.player_foot = Maps.site_position("grove", 0)
	game._update_camera()
	await tap(KEY_E)
	await click(game.story.action)
	check(game.story.state.stage == 2 and game.inventory.herb == 1 and game.inventory.wood == 0, "明确交付只扣灵草2木料2并推进安灶")
	game.story.perform()
	check(game.story.state.stage == 2 and game.inventory.crystal == 0, "危险未清除不允许修灶领奖")
	# Fixture clears enemies through normal damage/death settlement; this is not a player playthrough.
	game.dialogue.hide()
	for enemy: Dictionary in game.states.grove.enemies: game._damage(enemy, 1000)
	game._damage(game.get_node("Bosses").bosses.H02, 1000)
	game._remove_dead()
	game.player_foot = Maps.site_position("grove", 2)
	await tap(KEY_E)
	game.dialogue.hide()
	game.player_foot = Maps.site_position("grove", 0)
	game._update_camera()
	await tap(KEY_E)
	await click(game.story.action)
	check(game.story.state.stage == 3 and game.inventory.crystal == 3 and game.inventory["s1-top"] == 1, "修灶实际发放灵晶3及追归上衣1")
	game.story.perform()
	check(game.inventory.crystal == 3 and game.inventory["s1-top"] == 1 and game.inventory.herb == 1, "完成后重复请求不重发奖励，满血不耗药")
	game.health = 75
	game.story.present()
	await click(game.story.action)
	check(game.health == 100 and game.inventory.herb == 0 and game.story.state.meals == 1, "热汤消耗实际灵草并恢复生命，封顶100")
	await capture("stove-dialogue")
	game.dialogue.hide()
	await capture("restored-stove")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.story.perform()
	check(game.story.state.meals == 1, "远程不能使用灶台")
	game.open_journal()
	game.book.select_page(1)
	check(game.journal_text.text.contains("灶火已恢复"), "见闻显示完成结果及补给用途")
	game.journal.hide()

func check_storage() -> void:
	var storage = game.persistence
	var fused: String = game.equipment.fusion.register_item("w02-ruinsplitter@mutated", 10)
	game.inventory[fused] = 1
	game.inventory.crystal = 17
	game.equipment.equip_item(fused)
	game.npc_exchange.stock["lu-yan"].wood = 1
	game.npcs.tasks["ye-ting"] = "active"
	game.get_node("Weather").tick(19.0)
	var chests = game.get_node("Chests")
	var ordinary: Dictionary = chests.regions.grove[0]
	game.player_foot = ordinary.position
	chests.interact(ordinary)
	check(ordinary.state == "opened" and ordinary.rewarded, "普通宝箱通过实际接口结算")
	var mutated_region := ""
	for id: String in Maps.IDS:
		for chest: Dictionary in chests.regions[id]:
			if chest.mutated:
				mutated_region = id
				game.enter_region(id)
				game.player_foot = chest.position
				chests.interact(chest)
				if chest.state == "guarding":
					game.equipment.unequip_slot("weapon")
					game._damage(chest.mobs[0], 10)
					game.equipment.equip_item(fused)
					break
		if mutated_region != "": break
	game.buildings.activate("grove")
	game.enter_region("post")
	game.player_foot = Maps.site_position("post", 0)
	game.states.post.foot = game.player_foot
	game.health = 63
	check(storage.valid(storage.capture()), "完整快照通过结构、坐标、库存与任务校验")
	check(storage.save_now(), "写入临时文件后替换主档并建立备份")
	var saved: Dictionary = storage.read_save()
	check(not saved.is_empty() and saved.region == "post" and saved.health == 63, "完整快照可读且保留位置与生命")
	if saved.is_empty(): return
	for mutation: String in ["health", "inventory", "equipment", "point", "quest", "shop", "boss", "plot", "rng", "actor-field", "section"]:
		var bad := saved.duplicate(true)
		match mutation:
			"health": bad.health = -1
			"inventory": bad.inventory["unknown-item"] = 1
			"equipment": bad.equipped.weapon = "s1-top"
			"point": bad.regions.post.foot = Vector2.INF
			"quest": bad.quest.meals = -1
			"shop": bad.stock["lu-yan"].wood = 999
			"boss": bad.bosses.H02.hp = 999999
			"plot": bad.regions.post.plots[0].growth = -2
			"rng": bad.rng.loot = "not-a-number"
			"actor-field": bad.bosses.H02["id"] = "unknown-boss"
			"section": bad.bosses["unknown-boss"] = bad.bosses.H02
		check(not storage.valid(bad), "损坏快照整体拒绝 " + mutation)
	check(Save.decode({"$point": ["bad", 0]}) == null and not Save.item_valid("s1-top@fusion11"), "非法向量与融合等级被拒绝")
	# Bring the backup to the same state, corrupt primary, then restore from backup.
	check(storage.save_now(), "重复保存保持完整状态")
	game.set_process(true)
	storage.elapsed = 29.9
	storage._process(0.2)
	game.set_process(false)
	check(storage.elapsed == 0 and storage.read_save().health == 63, "探索时间达到30秒触发自动保存")
	var file := FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(not storage.read_save().is_empty() and storage.status.contains("备份"), "主档截断时从完整备份恢复")
	check(storage.save_now(), "恢复后可重新保存，不把损坏主档覆盖有效备份")
	var before := FileAccess.get_file_as_string(Save.PATH)
	DirAccess.make_dir_absolute(Save.PATH + ".tmp")
	check(not storage.save_now() and FileAccess.get_file_as_string(Save.PATH) == before, "临时路径不可写时保留原存档并报告失败")
	storage.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(game.menu.visible and game.menu_info.text.contains("重试") and FileAccess.get_file_as_string(Save.PATH) == before, "关闭时保存失败保留窗口与原档，允许重试")
	game.leave_expedition()
	check(current_scene == game and game.menu.visible and game.menu_info.text.contains("失败"), "保存失败时保留当前窗口并允许重试")
	DirAccess.remove_absolute(Save.PATH + ".tmp")
	game.close_menu()
	file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string('{"version":999,"data":{}}')
	file.close()
	check(storage.read_save().is_empty(), "未来版本主档不静默回退并覆盖")
	file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string(before)
	file.close()
	game.toggle_menu()
	check(game.menu.visible and game.menu_info.text.contains("已保存"), "真实菜单显示保存结果")
	await capture("save-menu")
	game.request_restart()
	check(game.restart_confirm.visible and game._paused(), "重新开始先确认并暂停探索")
	game.restart_confirm.hide()
	check(FileAccess.get_file_as_string(Save.PATH) == before, "取消重新开始保留原存档")
	game.close_menu()
	check(storage.save_now(), "保留跨进程重启验证档")
	print("FUDI_PROGRESS_ENCOUNTER_REGION: " + mutated_region)

func verify_relaunch() -> void:
	check(game.region == "post" and game.health == 63 and game.player_foot == Maps.site_position("post", 0), "新进程继续上次地点、位置与生命")
	check(game.inventory.crystal == 17 and game.equipment.equipped.weapon == "w02-ruinsplitter@mutated@fusion10", "新进程保留货币和异变融合+10穿戴")
	check(game.equipment.Catalog.stats(game.equipment.equipped.weapon).attack == 54, "动态融合装备重建后属性正确")
	check(game.story.state == {"stage": 3, "meals": 1} and game.npc_exchange.stock["lu-yan"].wood == 1 and game.npcs.tasks["ye-ting"] == "active", "新进程保留灶台后果、商店库存与人物委托")
	check(game.states.grove.enemies.is_empty() and game.get_node("Bosses").bosses.H02.hp == 0, "守卫与首领不因重启复活")
	check(game.get_node("Weather").elapsed == 19.0 and not game.buildings.active.is_empty(), "天气时间、药圃与建筑效果保留")
	check(game.get_node("Chests").regions.grove[0].state == "opened", "已领奖宝箱不因重启补货")
	var restored_fight := false
	for boxes: Array in game.get_node("Chests").regions.values():
		for chest: Dictionary in boxes:
			if chest.state == "guarding":
				restored_fight = chest.mobs[0].hp == 26 and chest.boss.windup == 0 and chest.boss.cooldown >= 1.8
	check(restored_fight, "进行中的守箱战保留伤害，取消旧预警并留反应时间")
	check(game.persistence.valid(game.persistence.capture()), "恢复后的状态再次通过校验")
	await capture("continued")
	var weather = game.get_node("Weather")
	var plot: Dictionary = weather.plots.grove[0]
	check(plot.ripe, "成熟药圃跨进程保留成熟状态")
	game.enter_region("grove")
	game.player_foot = plot.position
	var herbs: int = game.inventory[plot.item]
	game._collect_nearby()
	weather._grow("grove", 0.001)
	check(game.inventory[plot.item] == herbs + 1 and not plot.ripe and plot.harvests == 1, "读档后药圃只领取一次并继续再生")
	game.leave_expedition()
	await frames()
	check(current_scene.name == "MainMenu" and current_scene.find_child("EnterFudi", true, false).text.contains("继续"), "保存返回大厅后入口显示继续探索")
	await click(current_scene.find_child("EnterFudi", true, false))
	game = current_scene
	game.set_process(false)
	game.request_restart()
	game.restart_confirm.get_ok_button().grab_focus()
	await tap(KEY_ENTER)
	await frames()
	game = current_scene
	game.set_process(false)
	await frames()
	check(game.health == 100 and game.equipment.equipped.is_empty() and game.story.state.stage == 0 and game.get_node("Bosses").remaining() == 6, "确认重新开始后实际重置装备、故事、首领与生命")
	var file := FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("{broken-primary")
	file.close()
	file = FileAccess.open(Save.PATH + ".bak", FileAccess.WRITE)
	file.store_string("{broken-backup")
	file.close()
	await open_game()
	check(game.persistence.blocked and game.menu.visible and game._paused(), "主档和备份均损坏时暂停并提示，不冒充新局覆盖")
	check(not game.persistence.save_now() and FileAccess.get_file_as_string(Save.PATH) == "{broken-primary" and FileAccess.get_file_as_string(Save.PATH + ".bak") == "{broken-backup", "损坏文件原样保留等待玩家选择")
	game.leave_expedition()
	await frames()
	check(current_scene.name == "MainMenu" and FileAccess.get_file_as_string(Save.PATH) == "{broken-primary", "存档不可用时仍能返回大厅且保留原文件")
	await click(current_scene.find_child("EnterFudi", true, false))
	game = current_scene
	game.set_process(false)
	game.request_restart()
	game.restart_confirm.get_ok_button().grab_focus()
	await tap(KEY_ENTER)
	await frames()
	game = current_scene
	game.set_process(false)
	var backup: Variant = Save.parse_text(FileAccess.get_file_as_string(Save.PATH + ".bak"))
	check(not game.persistence.blocked and game.story.state.stage == 0 and backup is Dictionary and game.persistence.valid(Save.decode(backup.get("data"))), "损坏存档确认新开后同时建立有效主档与备份")
	game.health = 0
	game._end_round(false)
	check(game.persistence.save_now(), "失败结算可完整保存")
	await open_game()
	check(game.health == 0 and game.finished and game.outcome.visible and not game.continue_button.visible, "读档恢复失败面板，不能通过重启复活")
