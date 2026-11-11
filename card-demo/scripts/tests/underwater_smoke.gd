extends SceneTree
# Purpose: underwater loop, collision, migration and transaction regression.
# Godot 4.7; run only in the isolated copy created by underwater.tests.ps1.
var failures := 0
var checks := 0
var sea: Control
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func json_state_equal(actual: Dictionary, expected: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(actual, "", true, true)) == JSON.parse_string(JSON.stringify(expected, "", true, true))

func key(code: Key, shift := false, keep_settlement := false) -> void:
	var event := InputEventKey.new()
	event.shift_pressed = shift
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
	if not keep_settlement and is_instance_valid(sea.dive_view) and sea.dive_view.settlement_saved:
		sea.dive_view.settlement_close.pressed.emit()
		await process_frame

func walk(view: Control, destination: Vector2) -> void:
	for i in 500:
		if view.foot.distance_to(destination) < 3: break
		view.move_step((destination - view.foot).limit_length(5))
	check(view.foot.distance_to(destination) < 3, "通行路线可达 " + str(destination))

func v2_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	check(sea._cache_round(), "V2准备基线")
	var base: Dictionary = sea._round_state()
	for version in [1, 2, 3, 4, 5]:
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": base}))
		check(not migrated.is_empty() and migrated.resources == catalog.resources() and migrated.node_states.size() == 3 and migrated.net_expansion == 0, "v%d完整V2默认" % version)
	for invalid in [true, -1, 1.5, 1000001, "2"]:
		var bad := base.duplicate(true)
		bad.resources.coral = invalid
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "v6拒绝非法资源 " + str(invalid))
	for invalid in [-1, 4, 0.5, true, "1"]:
		var bad := base.duplicate(true)
		bad.node_states.shoal.s1.stock = invalid
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "v6拒绝非法stock " + str(invalid))
	for invalid in [0, -1, "now", true, 253402300800.0]:
		var bad := base.duplicate(true)
		bad.node_states.shoal.s1.timestamp = invalid
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "v6拒绝坏时钟 " + str(invalid))
	var entry := {"stock": 0, "timestamp": 1000.0}
	catalog.recover(entry, 1179.0)
	check(entry.stock == 0, "恢复不足180秒")
	catalog.recover(entry, 1180.0)
	check(entry.stock == 1, "180秒恢复一份")
	catalog.recover(entry, 1000000.0)
	check(entry.stock == 3 and entry.timestamp == 1000000.0, "离线封顶不囤多余恢复")
	entry = {"stock": 0, "timestamp": 2000.0}
	catalog.recover(entry, 1000.0)
	check(entry.stock == 0 and entry.timestamp == 1000.0, "未来时钟重锚不奖励")
	catalog.recover(entry, NAN)
	check(entry.stock == 0 and entry.timestamp == 1000.0, "无效当前时间不恢复")
	for expansion in [0, 1, 2]:
		var valid := base.duplicate(true)
		valid.net_expansion = expansion
		check(not game._read_sea_text(JSON.stringify({"version": 6, "state": valid})).is_empty(), "合法扩容占位%d" % expansion)
	for field in ["resources", "node_states"]:
		var bad := base.duplicate(true)
		bad[field]["unknown"] = 0
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "拒绝白名单外字段 " + field)
	check(not sea.gather_node("shoal", "s1", NAN), "无效当前时间禁止采集")
	await key(KEY_B)
	check(sea._sea_window_open(), "真实海面B仓库")
	for child in sea.get_children():
		if child is AcceptDialog and child.visible:
			var text := ""
			for section in child.get_node("InventoryScroll").get_child(0).get_children():
				if section is Button: continue
				for row in section.get_children(): text += row.text
			check(text.contains("珊瑚枝") and text.contains("绳索"), "仓库并列新旧资源")
			child.hide()
			child.queue_free()
	await process_frame
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	for map in catalog.RATES:
		view.enter(map)
		view.oxygen = 90
		view._process(10)
		check(is_equal_approx(view.oxygen, 90 - 10 * catalog.RATES[map]), "真实delta倍率 " + map)
		for node in catalog.NODES[map]:
			check(view.can_stand(node[2]), "采集点可站立 " + node[0])
			view.foot = Vector2(225, 410 if map == "trench" else 490)
			if map == "shoal":
				walk(view, Vector2(350, 390))
				if node[2].x > 495: walk(view, Vector2(650, 390))
			elif map == "wreck" and node[2].x > 480: walk(view, Vector2(540, 490))
			walk(view, node[2])
			view.bag.clear()
			var before_entry: Dictionary = sea.node_states[map][node[0]].duplicate()
			check(view.interact(), "各箱实际可启动 " + node[0])
			view._process(float(catalog.CHESTS[catalog.chest_quality(map, node[0])].seconds))
			check(view.bag == catalog.chest_loot(map, node[0], int(before_entry.stock), float(before_entry.timestamp)), "各箱成功仅抽一次且符合地点池 " + node[0])
	view.enter("shoal")
	for remaining in [3, 2, 1, 0]:
		sea.node_states.shoal.s1 = {"stock": remaining, "timestamp": Time.get_unix_time_from_system()}
		check(view.stock_text("s1").contains(str(remaining)), "库存四态%d" % remaining)
	sea.node_states.shoal.s1.stock = 3
	check(sea._cache_round(), "保存四态测试基线")
	view.bag = ["pearl", "timber", "copper", "coral"]
	check(view.used_slots() == 8 and not view.fits("shell"), "按件多格容量满袋")
	view.foot = Vector2(270, 300)
	var stock: int = sea.node_states.shoal.s1.stock
	view.interact()
	check(view.bag.size() == 4 and sea.node_states.shoal.s1.stock == stock, "满袋不扣资源")
	await key(KEY_B)
	check(view.bag_open, "真实B网袋")
	view.oxygen = 60
	view._process(5)
	check(view.oxygen == 55, "B内真实delta耗氧")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(355, 345)
	Input.parse_input_event(mouse)
	await process_frame
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(200, 550)
	Input.parse_input_event(mouse)
	await process_frame
	check(view.bag.size() == 3 and view.used_slots() == 5 and view.drops.size() == 1, "真实鼠标拖出三格珍珠按件丢弃")
	await key(KEY_B)
	view.interact()
	check(view.bag.size() == 4 and view.drops.is_empty(), "原地E捡回优先于重叠资源")
	view.bag.clear()
	view.foot = Vector2(270, 300)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	stock = sea.node_states.shoal.s1.stock
	view.interact()
	check(view.bag.is_empty() and sea.node_states.shoal.s1.stock == stock, "采集写失败库存与袋回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	view.interact()
	check(view.bag.size() == 1 and view.bag[0] in catalog.POOLS.shoal and sea.node_states.shoal.s1.stock == stock - 1, "先事务扣库存再入袋")
	view.bag = ["coral"] # 后续结算夹具固定物品，不依赖随机结果。
	var persisted: Dictionary = game.water_activity_state.duplicate(true)
	check(not persisted.has("bag") and not persisted.has("oxygen"), "氧气网袋不落盘")
	view.foot = view.safety_position()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE)
	check(is_instance_valid(sea.dive_view) and view.settling and view.bag == ["coral"] and sea.resources.coral == 0, "结算失败保袋不入库")
	sea._open_dive()
	check(sea.dive_view == view and not view.interact(), "待结算禁止覆盖及采集")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_view) and sea.resources.coral == 1, "结算重试一次入库")
	sea._close_dive()
	check(sea.resources.coral == 1, "重复关闭不重复奖励")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(view.oxygen == 90 and view.place == "shoal" and view.bag.is_empty(), "下一潜全部重置")
	view.bag = ["pearl", "timber", "coral"]
	view.oxygen = 28
	view.tick_oxygen(2)
	view.tick_oxygen(2)
	check(view.warning_count == 1, "30%预警单次")
	view.tick_oxygen(24)
	check(view.ascending == 1.5 and view.lost_count == 3 and view.lost_items.size() == 3 and not view.interact(), "逐件耗尽掉落一次且禁止采集")
	view.tick_oxygen(1)
	check(is_instance_valid(sea.dive_view) and view.lost_count == 3, "1.5秒前不结算或重抽")
	view.tick_oxygen(0.5)
	check(view.settlement_saved and view.settlement_text.text.contains("耗尽救援"), "耗尽自动打开结算面板")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_view) and sea.recoverable_drops.is_empty(), "1.5秒自动救援但无可回收掉落")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(view.drops.is_empty(), "下一潜不能回收失败收获")
	await key(KEY_ESCAPE)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(view.drops.is_empty(), "再下一潜清除旧掉落")
	view.bag = ["coral"]
	view.tick_oxygen(90)
	check(view.bag.is_empty() and view.lost_count == 1, "耗尽确定全部损失，无随机保留")
	view.tick_oxygen(1.5)
	await key(KEY_ESCAPE)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.foot = Vector2(270, 300)
	var abandoned_nodes: Dictionary = sea.node_states.duplicate(true)
	view.interact()
	check(sea.node_states.shoal.s1.stock == int(abandoned_nodes.shoal.s1.stock) - 1, "放弃前确实扣除宝箱库存")
	sea.dive_layer.queue_free()
	sea.dive_layer = null
	sea.dive_view = null
	await process_frame
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, abandoned_nodes) and sea.node_states == abandoned_nodes, "放弃下潜恢复本潜库存与时钟且实际落盘")
	for map in catalog.RATES:
		sea._open_dive()
		view = sea.dive_view
		view.set_process(false)
		view.enter(map)
		for site in view.sites():
			if site[0] == "上浮出口":
				check(view.can_stand(site[1]), "上浮光柱可站立 " + map)
				view.foot = site[1]
				await key(KEY_E)
				check(not is_instance_valid(sea.dive_view), "真实E光柱安全上浮 " + map)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.bag = ["pearl", "coral", "timber"]
	view.discard(0)
	view.tick_oxygen(90)
	check(view.lost_count == 2 and view.bag.is_empty() and view.drops.is_empty(), "耗尽清空整袋及本潜手动丢弃物")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	view.tick_oxygen(1.5)
	view.tick_oxygen(100)
	check(view.settling and view.settlement_saved and view.lost_count == 2 and view.bag.is_empty() and not view.settlement_text.text.contains("入库成功"), "救援不依赖写盘且明确失败零收益")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	var stored: int = sea.resources.coral
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_view) and sea.resources.coral == stored, "耗尽确认关闭不入库任何收获")

func rollback_chest(view: Control, map: String, index := 0) -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	view.enter(map)
	var node: Array = catalog.NODES[map][index]
	view.foot = node[2]
	var before: int = sea.node_states[map][node[0]].stock
	view.start_chest(node)
	view.tick_opening(float(catalog.CHESTS[catalog.chest_quality(map, node[0])].seconds))
	check(sea.node_states[map][node[0]].stock == before - 1, "回滚专项实际完成开箱 " + map + "/" + node[0])

func stock_rollback_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	sea.node_states = catalog.defaults(floorf(Time.get_unix_time_from_system()) - 30.0 + 0.1234567)
	check(sea._cache_round(), "V2.3独立全地点存量基线")
	var baseline: Dictionary = sea.node_states.duplicate(true)
	var warehouse: Dictionary = sea.resources.duplicate(true)
	var expected_loot: Array = catalog.chest_loot("shoal", "s1", int(baseline.shoal.s1.stock), float(baseline.shoal.s1.timestamp))
	game.load_sea_save()
	var reloaded_entry: Dictionary = game.water_activity_state.node_states.shoal.s1
	check(reloaded_entry.stock == baseline.shoal.s1.stock and reloaded_entry.timestamp == baseline.shoal.s1.timestamp and catalog.chest_loot("shoal", "s1", int(reloaded_entry.stock), float(reloaded_entry.timestamp)) == expected_loot, "保存重读精确保留stock与小数timestamp且chest_loot种子不变")
	sea._open_dive(true)
	check(sea.dive_node_snapshot.is_empty() and not sea.dive_stock_changed, "记录只读不建立下潜存量快照")
	sea._close_dive()
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	check(sea.dive_node_snapshot == baseline, "开潜快照包含所有地点和时钟")
	rollback_chest(view, "shoal")
	var first_loot: Array = view.bag.duplicate()
	check(first_loot == expected_loot, "真实开箱符合保存前后相同种子loot")
	rollback_chest(view, "shoal")
	rollback_chest(view, "shoal")
	rollback_chest(view, "wreck")
	rollback_chest(view, "trench")
	check(sea.node_states.shoal.s1.stock == 0 and sea.node_states.shoal.s1.timestamp != baseline.shoal.s1.timestamp and sea.dive_node_snapshot == baseline and sea.dive_stock_changed, "多地点多次扣至空箱且快照深拷贝不随库存时钟变化")
	var spent: Dictionary = sea.node_states.duplicate(true)
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, spent), "耗尽前各次实际扣箱已写盘")
	var losses: Array = view.bag.duplicate()
	view.tick_oxygen(1000)
	check(view.settlement_saved and view.settlement.rescue and view.settlement.items.is_empty() and view.lost_items == losses and view.bag.is_empty(), "多地点收获耗尽后整袋损失且零入库")
	check(sea.node_states == baseline and sea.resources == warehouse and sea.dive_node_snapshot.is_empty() and not sea.dive_stock_changed, "耗尽恢复全地点stock与timestamp并清快照")
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, baseline) and json_state_equal(game.water_activity_state.resources, warehouse), "耗尽回滚实际重读库存时钟与历史仓库一致")
	var saved_text := FileAccess.get_file_as_string(game.SEA_SAVE)
	check(sea.rollback_dive_stock() and sea.rollback_dive_stock() and sea.node_states == baseline and FileAccess.get_file_as_string(game.SEA_SAVE) == saved_text, "重复回滚无副作用且不重复写档")
	await key(KEY_ESCAPE)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	rollback_chest(view, "shoal")
	check(view.bag == first_loot, "失败后下一潜同节点同代次实际loot一致不重抽")
	var safe_nodes: Dictionary = sea.node_states.duplicate(true)
	var safe_resources := warehouse.duplicate(true)
	for id in view.bag: safe_resources[id] += 1
	view.foot = view.safety_position()
	sea._close_dive()
	check(view.settlement_saved and sea.public_project.pending_bag != null and sea.resources == warehouse, "安全返航先真实封存而不提前入库")
	await process_frame
	check(view.settlement_saved and sea.node_states == safe_nodes and sea.resources == safe_resources and sea.dive_node_snapshot.is_empty(), "安全入库保留已扣箱且清快照")
	check(sea.rollback_dive_stock() and sea.node_states == safe_nodes and sea.resources == safe_resources, "安全结算后回滚不能恢复已入库宝箱")
	await key(KEY_ESCAPE)
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, safe_nodes) and json_state_equal(game.water_activity_state.resources, safe_resources), "安全关闭view后实际重读仍保留入库和扣箱")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(sea.dive_node_snapshot == safe_nodes, "下一潜以安全入库后的库存建立新快照")
	rollback_chest(view, "shoal")
	rollback_chest(view, "wreck")
	view.tick_oxygen(1000)
	game.load_sea_save()
	check(view.settlement_saved and sea.node_states == safe_nodes and sea.resources == safe_resources and json_state_equal(game.water_activity_state.node_states, safe_nodes) and json_state_equal(game.water_activity_state.resources, safe_resources), "下一潜失败只回滚下一潜扣箱不撤销上一潜安全成果")
	await key(KEY_ESCAPE)

	sea._start_round()
	check(sea._cache_round(), "回滚写失败独立基线")
	baseline = sea.node_states.duplicate(true)
	warehouse = sea.resources.duplicate(true)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	rollback_chest(view, "shoal")
	spent = sea.node_states.duplicate(true)
	losses = view.bag.duplicate()
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "建立SEA_TEMP目录注入回滚写失败")
	view.tick_oxygen(1000)
	check(view.settling and not view.settlement_saved and view.settlement.rescue and view.lost_items == losses and view.bag.is_empty() and sea.resources == warehouse, "回滚写失败冻结救援且不入库不假成功")
	check(view.settlement_text.text.contains("回滚保存失败") and view.settlement_text.text.contains("探索冻结") and not view.settlement_text.text.contains("入库成功") and not view.settlement_close.visible and view.settlement_retry.visible, "失败面板明确存量回滚失败且仅允许重试")
	check(sea.dive_node_snapshot == baseline and sea.dive_stock_changed and sea.node_states == spent, "失败保留原始快照与重试标记且内存回到已扣存量")
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, spent) and json_state_equal(game.water_activity_state.resources, warehouse), "回滚失败实际重读仍为已扣存量无收益")
	var panel: Control = view.settlement_panel
	var settlement: Dictionary = view.settlement.duplicate(true)
	var oxygen: float = view.oxygen
	view._process(10)
	check(not view.interact() and view.oxygen == oxygen, "失败面板自然逻辑不耗氧不可继续采集")
	sea._dismiss_dive()
	sea._open_dive()
	check(sea.dive_view == view, "失败回滚不可关闭或覆盖本潜")
	await key(KEY_ESCAPE, false, true)
	check(not view.settlement_saved and view.settlement_panel == panel and view.settlement == settlement and sea.dive_node_snapshot == baseline and json_state_equal(sea.node_states, spent) and json_state_equal(sea.resources, warehouse), "故障未移除反复重试保持同一失败面板与快照")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "移除SEA_TEMP回滚故障")
	await key(KEY_SPACE, false, true)
	check(view.settlement_saved and view.settlement_panel == panel and view.settlement == settlement and sea.node_states == baseline and json_state_equal(sea.resources, warehouse) and sea.dive_node_snapshot.is_empty() and not sea.dive_stock_changed, "移除故障后重试同一面板恢复全部存量而不入库")
	check(view.settlement_text.text.contains("存量已回滚") and not view.settlement_text.text.contains("入库成功"), "回滚重试成功仍明确失败零收益")
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.node_states, baseline) and json_state_equal(game.water_activity_state.resources, warehouse), "回滚重试实际落盘且无收益")
	sea._close_dive()
	check(sea.rollback_dive_stock() and json_state_equal(sea.resources, warehouse), "重试成功后重复结算回滚不入库")
	await key(KEY_ESCAPE)

	for destroy_host in [false, true]:
		sea._start_round()
		check(sea._cache_round(), "中退独立基线 host=%s" % destroy_host)
		baseline = sea.node_states.duplicate(true)
		warehouse = sea.resources.duplicate(true)
		sea._open_dive()
		view = sea.dive_view
		view.set_process(false)
		rollback_chest(view, "shoal")
		rollback_chest(view, "wreck")
		spent = sea.node_states.duplicate(true)
		game.load_sea_save()
		check(json_state_equal(game.water_activity_state.node_states, spent), "中退前多地点扣箱确实落盘 host=%s" % destroy_host)
		if destroy_host:
			sea.queue_free()
		else:
			sea.dive_layer.queue_free()
			sea.dive_layer = null
			sea.dive_view = null
		await process_frame
		check(not is_instance_valid(view), "真实场景销毁触发退出 host=%s" % destroy_host)
		game.load_sea_save()
		check(json_state_equal(game.water_activity_state.node_states, baseline) and json_state_equal(game.water_activity_state.resources, warehouse), "view/host中退实际重读恢复本潜库存时钟且不入库 host=%s" % destroy_host)
		if destroy_host:
			check(not is_instance_valid(sea), "host场景实际销毁")
			sea = load("res://scenes/WaterActivity.tscn").instantiate()
			root.add_child(sea)
			sea.set_process(false)
			await process_frame
		var host_restored: bool = json_state_equal(sea.node_states, baseline) and json_state_equal(sea.resources, warehouse) if destroy_host else sea.node_states == baseline and sea.resources == warehouse
		check(host_restored and sea.rollback_dive_stock(), "中退后宿主状态恢复且再次回滚幂等 host=%s" % destroy_host)

func settlement_checks() -> void:
	sea._start_round()
	sea.dive_shoal = true
	sea.dive_sonar = true
	check(sea._cache_round(), "核心失败测试前置保存")
	sea._open_dive()
	var failed_view: Control = sea.dive_view
	failed_view.set_process(false)
	check(sea._commit_dive("dive_core") and failed_view.pending_core and not sea.dive_core, "新核心仅暂存本潜")
	failed_view.bag = ["coral", "pearl"]
	check(sea._cache_round() and not game.water_activity_state.dive_core, "其他保存不能提前持久化新核心")
	failed_view.tick_oxygen(91.5)
	check(not sea.dive_core and not failed_view.pending_core and sea.resources.coral == 0 and sea.resources.pearl == 0, "新核心与整袋在耗尽后全部丢失")
	check(failed_view.settlement_text.text.contains("失败零收益") and not failed_view.settlement_text.text.contains("入库成功"), "失败面板不假显示成功")
	await key(KEY_ESCAPE)
	sea._open_dive(true)
	check(sea.dive_view.archive_button.disabled and not sea._commit_dive("dive_archived") and not sea.core_reward_claimed, "救援后显式归档也不能领取新核心奖励")
	sea._close_dive()
	game.load_sea_save()
	check(not game.water_activity_state.dive_core, "救援后重读不能恢复失败核心")
	sea._open_dive()
	failed_view = sea.dive_view
	failed_view.set_process(false)
	check(failed_view.drops.is_empty() and sea._commit_dive("dive_core"), "下一潜无失败收获但核心可以重新取得")
	failed_view.foot = failed_view.safety_position()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	sea._close_dive()
	check(not sea.dive_core and failed_view.pending_core and not failed_view.settlement_saved, "安全结算写失败核心回滚但保留本潜重试")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	sea._close_dive()
	check(failed_view.settlement_saved and sea.public_project.pending_bag.new_core and not sea.dive_core, "安全空袋核心重试先持久化封存")
	await process_frame
	check(sea.dive_core and game.water_activity_state.dive_core, "安全空袋重试也可真实保存核心")
	await key(KEY_ESCAPE)
	sea._open_dive()
	failed_view = sea.dive_view
	failed_view.set_process(false)
	failed_view.tick_oxygen(91.5)
	check(sea.dive_core and game.water_activity_state.dive_core, "后续耗尽不清除此前安全核心")
	await key(KEY_ESCAPE)
	sea._start_round()
	check(sea._cache_round(), "结算面板隔离基线")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	await key(KEY_ESCAPE, false, true)
	check(view.settlement_saved and view.settlement_text.text.contains("空袋") and view.settlement_text.text.contains("安全光柱"), "空袋安全上浮真实面板")
	check(root.gui_get_focus_owner() == view.settlement_close, "成功结算聚焦确认")
	view._process(1.0)
	check(not view.oxygen_label.visible and view.oxygen == view.oxygen_max(), "结算自然帧刷新不露出氧气HUD且不耗氧")
	check(view.settlement_text.text.contains("共0件") and view.settlement_text.text.contains("本次无收获") and view.settlement_text.text.contains("核心尚未取得"), "空袋件数与线索下一步真实显示")
	await key(KEY_TAB, false, true)
	check(root.gui_get_focus_owner() == view.settlement_records, "结算Tab限定记录入口")
	await key(KEY_TAB, true, true)
	check(root.gui_get_focus_owner() == view.settlement_close, "结算ShiftTab返回确认")
	var before: Dictionary = gameplay_state()
	var point: Vector2 = sea.player_foot
	for code in [KEY_M, KEY_B, KEY_C, KEY_D]: await key(code, false, true)
	sea._process(10)
	sea.exploration_tools.open_map()
	sea.get_node("ReturnButton").pressed.emit()
	check(gameplay_state() == before and sea.player_foot == point and not sea.exploration_tools.is_open() and not sea._sea_window_open(), "结算阻挡移动经营地图仓库工坊返回")
	var click := InputEventMouseButton.new()
	click.position = Vector2(300, 520)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	check(not view.moving and not sea.moving, "结算底层点击不穿透")
	check(view.settlement_panel.get_rect() == Rect2(180, 70, 920, 580) and view.settlement_text.scroll_active, "720p结算边距与滚动")
	await key(KEY_ENTER, false, true)
	check(not is_instance_valid(sea.dive_view), "真实Enter只关闭结算")
	sea.dive_shoal = true
	sea.dive_sonar = true
	sea.dive_core = true
	check(sea._cache_round(), "核心待归档结算基线")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(sea.last_dive_summary.is_empty() and view.settlement.is_empty(), "新潜清空旧摘要快照")
	view.bag = ["coral", "coral", "pearl"]
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE, false, true)
	var panel: Control = view.settlement_panel
	var snapshot: Dictionary = view.settlement.duplicate(true)
	for i in 2:
		await key(KEY_ESCAPE, false, true)
		check(not view.settlement_saved and view.settlement == snapshot and sea.resources.coral == 0 and view.bag.size() == 3, "多次失败保持快照不累计%d" % i)
	check(view.settlement_text.text.contains("封存保存失败") and view.settlement_text.text.contains("尚未安全保存") and not view.settlement_close.visible and root.gui_get_focus_owner() == view.settlement_retry, "失败仅重试且聚焦不丢袋")
	sea._dismiss_dive()
	check(sea.dive_view == view, "失败不可绕过关闭丢袋")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_SPACE, false, true)
	await process_frame
	await process_frame
	check(view.settlement_saved and view.settlement_panel == panel and sea.resources.coral == 2 and sea.resources.pearl == 1 and view.bag.is_empty(), "空格重试成功更新同一面板准确入库")
	check(view.settlement_text.text.contains("珊瑚枝 × 2") and view.settlement_text.text.contains("深水珍珠 × 1") and view.settlement_text.text.contains("待归档") and not sea.dive_archived, "中文数量核心待归档且不自动领奖")
	sea._close_dive()
	check(sea.resources.coral == 2, "成功重复请求不重复入库")
	view.settlement_records.grab_focus()
	await key(KEY_ENTER, false, true)
	check(sea.dive_view.read_only and root.gui_get_focus_owner() == sea.dive_view.clues_tab, "结算记录入口聚焦线索页签")
	sea.dive_view.archive_button.grab_focus()
	await key(KEY_SPACE)
	check(sea.dive_archived and sea.core_reward_claimed, "结算进入记录后显式归档领奖")
	await key(KEY_ESCAPE)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.bag = ["shell", "coral"]
	view.tick_oxygen(91.5)
	check(view.settlement_saved and view.settlement.losses.size() == 2 and view.settlement_text.text.contains("贝群 × 1") and view.settlement_text.text.contains("核心已归档") and not view.settlement_text.text.contains("待归档"), "耗尽损失明细与已归档不误提示")
	await key(KEY_ESCAPE, false, true)
	check(not is_instance_valid(sea.dive_layer) and sea.resources.coral == 2, "成功Esc关闭不重复奖励")
	check(root.gui_get_focus_owner() == sea.dive_button, "关闭结算恢复浮台焦点")
	await key(KEY_C)
	check(sea._sea_window_open(), "关闭结算后真实C恢复工坊输入")
	await key(KEY_ESCAPE)
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	await key(KEY_ESCAPE, false, true)
	check(view.settlement_saved and view.settlement.items.is_empty() and view.settlement.losses.is_empty() and view.settlement_text.text.contains("本次无收获") and not view.settlement_text.text.contains("珊瑚枝 ×"), "上一潜有收获和损失后空袋不沿用明细")
	check(view.settlement_text.text.contains("按C建造"), "已解锁工坊明确C建造下一步")
	await key(KEY_ESCAPE, false, true)
	check(sea.build_dive_workshop(), "结算关闭后建成真实工坊")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	await key(KEY_ESCAPE, false, true)
	check(view.settlement_text.text.contains("按C制作"), "已建工坊明确C制作下一步")
	await key(KEY_ESCAPE, false, true)
	sea.dive_workshop_built = false
	sea.dive_workshop_unlocked = false
	sea.core_reward_claimed = false
	check(sea._cache_round(), "旧已归档未领奖隔离基线")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	await key(KEY_ESCAPE, false, true)
	check(view.settlement_text.text.contains("奖励待补领") and not sea.core_reward_claimed, "旧归档明确补领但结算不自动发奖")
	await key(KEY_ESCAPE, false, true)

func pending_return_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	sea.dive_shoal = true
	sea.dive_sonar = true
	sea.dive_core = true
	sea.dive_archived = true
	sea.core_reward_claimed = true
	sea.dive_workshop_unlocked = true
	sea.dive_workshop_built = true
	sea.wood = 10
	sea.fiber = 10
	for id in sea.resources: sea.resources[id] = catalog.RESOURCE_LIMIT
	check(sea._cache_round(), "真实满仓返航隔离基线")
	var warehouse: Dictionary = sea.resources.duplicate(true)
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	for node in [catalog.NODES.shoal[0], catalog.NODES.shoal[1]]:
		view.foot = node[2]
		check(view.interact(), "满仓仍可真实交互开启宝箱 " + node[0])
		view.tick_opening(float(catalog.CHESTS[catalog.chest_quality("shoal", node[0])].seconds))
	check(view.bag.size() == 2, "满仓不影响本潜两件真实随机收获")
	var incoming: Dictionary = catalog.resources()
	for id in view.bag: incoming[id] += 1
	var spent: Dictionary = sea.node_states.duplicate(true)
	view.foot = view.safety_position()
	await key(KEY_ESCAPE, false, true)
	check(view.settlement_saved and view.return_secured and view.bag.is_empty() and sea.resources == warehouse and sea.public_project.pending_bag != null, "真实满仓安全返航封存成功而非丢袋或部分入库")
	var pending: Dictionary = sea.public_project.pending_bag.duplicate(true)
	check(pending.items == incoming and sea.dive_node_snapshot.is_empty() and sea.node_states == spent and view.settlement_text.text.contains("安全封存"), "封存完整保留真实收获并提交本潜扣箱")
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.public_project.pending_bag, pending) and json_state_equal(game.water_activity_state.resources, warehouse), "满仓封存待袋与原仓库实际写盘")
	sea.open_public_project_editor()
	check(not is_instance_valid(sea._public_project_editor), "潜水结算内禁止绕过基地门禁打开投料")
	await key(KEY_ESCAPE, false, true)
	sea._open_dive()
	check(not is_instance_valid(sea.dive_view) and sea.dive_button.disabled, "真实待袋禁止再次下潜")
	sea._open_dive(true)
	check(is_instance_valid(sea.dive_view) and sea.dive_view.read_only, "待袋仍可打开只读探索记录")
	sea._close_dive()
	sea.queue_free()
	await process_frame
	game.load_sea_save()
	sea = load("res://scenes/WaterActivity.tscn").instantiate()
	root.add_child(sea)
	sea.set_process(false)
	await process_frame
	check(json_state_equal(sea.public_project.pending_bag, pending) and json_state_equal(sea.resources, warehouse) and json_state_equal(sea.node_states, spent), "真实销毁重建场景后满仓待袋及扣箱不丢失不重复入库")
	for area in ["at_salt", "at_wreck", "sailing"]:
		sea.set(area, true)
		sea.open_public_project_editor()
		check(not is_instance_valid(sea._public_project_editor), "非基地禁止投料入口 " + area)
		sea.set(area, false)
	sea.open_public_project_editor()
	check(is_instance_valid(sea._public_project_editor) and sea._public_project_window.visible, "回到基地允许打开真实投料编辑器")
	sea._close_public_project_result("editor")
	for id in ["coral", "shell"]:
		if incoming[id] == 0: continue
		var recipe: String = "mask" if id == "coral" else "fins"
		check(sea.craft_equipment(recipe), "基地真实制作装备扣料腾仓 " + recipe)
		await process_frame
	var expected := warehouse.duplicate(true)
	for id in incoming: expected[id] += incoming[id]
	if incoming.coral > 0: expected.coral -= 3
	if incoming.shell > 0: expected.shell -= 3
	check(sea.public_project.pending_bag == null and sea.resources == expected and sea.public_project.last_bag.bag_id == pending.bag_id, "真实制作扣料触发整袋自动入库并关联原袋回执")
	game.load_sea_save()
	check(game.water_activity_state.public_project.pending_bag == null and json_state_equal(game.water_activity_state.resources, expected) and json_state_equal(game.water_activity_state.node_states, spent), "扣料后自动入库与原扣箱实际落盘")
	var receipt: Dictionary = sea.public_project.last_bag.duplicate(true)
	sea.public_project_service.queue_recheck()
	await process_frame
	check(sea.resources == expected and sea.public_project.last_bag == receipt, "后续自动重检不重复入库或改写回执")
	sea._open_dive()
	check(is_instance_valid(sea.dive_view) and not sea.dive_view.read_only, "整袋入库后恢复真实下潜")
	await key(KEY_ESCAPE)

func timed_walk(view: Control, destination: Vector2) -> void:
	view.target = destination
	view.moving = true
	for i in 500:
		if view.foot.distance_to(destination) < 5: break
		view._process(0.05)
	check(view.foot.distance_to(destination) < 5 and view.oxygen > 0, "真实耗氧路线可达 " + str(destination))

func gameplay_state() -> Dictionary:
	var state: Dictionary = sea._round_state()
	state.erase("result")
	return state

func workshop_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	var locked := gameplay_state()
	check(not sea.build_dive_workshop() and not sea.craft_equipment("mask") and gameplay_state() == locked, "未归档不能建造或制造且无扣费")
	check(not sea._commit_dive("dive_archived"), "未取得核心不能归档领奖")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	timed_walk(view, Vector2(350, 390))
	timed_walk(view, Vector2(650, 390))
	check(view.interact(), "首潜真实路线调查浅滩")
	view._process(2)
	timed_walk(view, Vector2(1080, 490))
	check(view.interact() and view.place == "wreck", "首潜进入沉船")
	timed_walk(view, Vector2(540, 490))
	timed_walk(view, Vector2(720, 375))
	check(view.interact(), "首潜调查声呐")
	view._process(2)
	timed_walk(view, Vector2(1080, 480))
	check(view.interact() and view.place == "trench", "首潜进入海沟")
	timed_walk(view, Vector2(875, 410))
	check(view.interact() and view.pending_core and not sea.dive_core, "无装备首潜核心可达但暂不持久")
	view._process(2)
	for node in catalog.NODES.trench:
		if node[1] == "pearl":
			timed_walk(view, node[2])
			check(view.interact(), "无装备首潜启动海沟稀有箱")
			view._process(6)
			check(view.bag.size() == 2 and view.bag[0] in catalog.POOLS.trench and view.bag[1] in catalog.POOLS.trench, "稀有箱随机海沟资源两件")
			check(view.message.contains("用途") and view.message.contains("安全上浮"), "随机宝箱反馈说明用途及安全入库")
			break
	timed_walk(view, view.safety_position())
	print("ROUTE: base oxygen remaining=", view.oxygen)
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_view) and sea.resources.pearl + sea.resources.algae == 2, "首潜核心宝箱收获安全撤离")
	var wood_before: int = sea.wood
	var scrap_before: int = sea.scrap
	sea._open_dive(true)
	check(sea._commit_dive("dive_archived"), "首次归档奖励事务")
	check(sea.core_reward_claimed and sea.dive_workshop_unlocked and sea.wood == wood_before + 2 and sea.scrap == scrap_before + 2, "首次木废各2及工坊解锁")
	check(sea._commit_dive("dive_archived") and sea.wood == wood_before + 2, "再次归档不重复给奖")
	sea._close_dive()
	sea.core_reward_claimed = false
	sea.dive_workshop_unlocked = false
	check(sea._cache_round(), "旧档已归档未领奖夹具")
	sea._refresh_dive_ui()
	check(sea.records_button.text.contains("补领"), "旧档显式补领入口")
	sea._open_dive(true)
	var before: Dictionary = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not sea._commit_dive("dive_archived") and gameplay_state() == before, "旧档补领失败全部回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(sea._commit_dive("dive_archived"), "旧档补领奖可重试")
	sea._close_dive()
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not sea.build_dive_workshop() and gameplay_state() == before, "工坊建造失败事务回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	before = gameplay_state()
	sea._open_build("dive_workshop")
	check(sea.build_dialog.visible and not sea.slot_picker.visible and not sea.build_dialog.get_ok_button().disabled and gameplay_state() == before, "潜水工坊建造预览使用附属位且确认前不扣费")
	sea.build_dialog.hide()
	var slots: Array = sea.building_slots.duplicate()
	wood_before = sea.wood
	scrap_before = sea.scrap
	check(sea.build_dive_workshop() and sea.wood == wood_before - 2 and sea.scrap == scrap_before - 2 and sea.building_slots == slots, "附属工坊木2废2且不改旧槽")
	check(not sea.build_dive_workshop(), "工坊不能重复建造")
	check(sea.equipment.size() == 5 and sea.equipment.wrist == {"id": "wrist", "level": 0}, "五槽默认护腕及捕网零级")
	check(sea._build_cost("dive_workshop") == catalog.WORKSHOP_COST and sea._build_reason("dive_workshop").contains("已建成"), "潜水工坊接入既有建造成本与门禁")
	for species_id in sea.dive_archive.safe: sea.dive_archive.safe[species_id] = true
	for id in catalog.RECIPES:
		for level in 2:
			for missing in catalog.RECIPES[id][level]:
				for material in catalog.RECIPES[id][level]:
					if sea.resources.has(material): sea.resources[material] = 20
					else: sea.set(material, 20)
				if sea.resources.has(missing): sea.resources[missing] = 0
				else: sea.set(missing, 0)
				check(sea._cache_round(), "缺单项材料基线 " + id + missing)
				before = gameplay_state()
				check(not sea.craft_equipment(id) and gameplay_state() == before, "每项配方不足不扣料 " + id + missing)
			for material in catalog.RECIPES[id][level]:
				if sea.resources.has(material): sea.resources[material] = 20
				else: sea.set(material, 20)
			check(sea._cache_round(), "升级材料基线 " + id)
			before = gameplay_state()
			DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
			check(not sea.craft_equipment(id) and gameplay_state() == before, "升级保存失败完整回滚 " + id)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
			check(sea.craft_equipment(id), "设备升至%d " % (level + 1) + id)
			for material in catalog.RECIPES[id][level]:
				check(sea.material_count(material) == 20 - catalog.RECIPES[id][level][material], "精确下一等级扣料 " + id + material)
			sea._open_dive()
			view = sea.dive_view
			view.set_process(false)
			check(view.oxygen_max() == 90 + sea.equipment_level("tank") * 30 and view.swim_speed() == [230.0, 280.0, 320.0][sea.equipment_level("fins")] and view.light_radius() == [120.0, 200.0, 260.0][sea.equipment_level("mask")] and view.capacity() == 8 + sea.net_expansion * 4, "装备真实效果 " + id)
			check(not sea.craft_equipment(id), "海底禁止隔空制造 " + id)
			await key(KEY_C)
			check(view.message.contains("只读") and not sea._sea_window_open(), "海底真实C只读")
			view.foot = view.safety_position()
			sea._close_dive()
			await key(KEY_ESCAPE)
		before = sea._round_state()
		check(not sea.craft_equipment(id) and sea._round_state() == before, "满级不重复收费 " + id)
	game.load_sea_save()
	check(game.water_activity_state.equipment == JSON.parse_string(JSON.stringify(sea.equipment)) and game.water_activity_state.net_expansion == 2 and game.water_activity_state.dive_workshop_built, "设备工坊重载持久")
	var valid: Dictionary = sea._round_state()
	var legacy := valid.duplicate(true)
	for field in ["equipment", "core_reward_claimed", "dive_workshop_unlocked", "dive_workshop_built"]: legacy.erase(field)
	for version in [1, 2, 3, 4, 5, 6]:
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": legacy}))
		check(not migrated.is_empty() and migrated.equipment == catalog.equipment() and not migrated.core_reward_claimed, "v%d设备迁移默认且可补领" % version)
	for invalid in [true, -1, 1.5, 3, "1"]:
		var bad := valid.duplicate(true)
		bad.equipment.mask.level = invalid
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "严格拒绝设备等级 " + str(invalid))
	for mode in 11:
		var bad := valid.duplicate(true)
		match mode:
			0: bad.equipment.mask.id = "tank"
			1: bad.equipment.unknown = {"id": "unknown", "level": 0}
			2: bad.equipment.erase("fins")
			3: bad.core_reward_claimed = 1
			4: bad.dive_workshop_built = false
			5: bad.core_reward_claimed = "true"
			6: bad.equipment = []
			7: bad.erase("core_reward_claimed")
			8: bad.dive_workshop_unlocked = 1
			9: bad.equipment.wrist.level = 1
			10: bad.equipment.erase("wrist")
		check(game._read_sea_text(JSON.stringify({"version": 6, "state": bad})).is_empty(), "严格拒绝装备结构与前置%d" % mode)
	await key(KEY_C)
	check(sea._sea_window_open(), "海面真实C工坊")
	for child in sea.get_children():
		if child is AcceptDialog and child.visible:
			child.hide()
			child.queue_free()
	await process_frame
	sea.equipment.mask.level = 0
	sea.resources.coral = 0
	check(sea._cache_round(), "缺料夹具")
	before = gameplay_state()
	check(not sea.craft_equipment("mask") and gameplay_state() == before and sea.result_label.text.contains("缺"), "缺料拒绝且不扣费")

func chest_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	check(sea.dive_summary_label.text.contains("耗尽零收益") and view.rules_label.text.contains("安全上浮入库"), "下潜前及水下常驻规则")
	view.foot = Vector2(340, 560)
	var stock: int = sea.node_states.shoal.s2.stock
	await key(KEY_E)
	check(view.opening_left == 3 and view.bag.is_empty(), "真实E按一次启动精良三秒")
	view._process(1)
	check(view.opening_left == 2 and view.prompt.text.contains("剩余2.0") and view.oxygen == 89, "计时进度及耗氧")
	await key(KEY_E)
	check(view.opening_left == 2 and view.bag.is_empty(), "重复E不重置计时不提前发奖")
	view.tick_opening(NAN)
	view.tick_opening(-1)
	check(view.opening_left == 2, "无效计时不提前开箱")
	await key(KEY_D)
	check(view.opening.is_empty() and view.message.contains("取消") and sea.node_states.shoal.s2.stock == stock, "真实移动键取消不扣次数")
	await key(KEY_E)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(350, 550)
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	check(view.opening.is_empty() and sea.node_states.shoal.s2.stock == stock, "真实点击移动取消")
	view.moving = false
	await key(KEY_E)
	await key(KEY_B)
	view._process(3)
	check(view.bag_open and view.bag.size() == 1 and sea.node_states.shoal.s2.stock == stock - 1 and view.oxygen == 86, "B不暂停开箱及耗氧且只给一次")
	view._process(3)
	check(view.bag.size() == 1, "完成不重复发奖")
	await key(KEY_B)
	view.bag.clear()
	view.foot = Vector2(740, 520)
	await key(KEY_E)
	check(view.opening_left == 6, "稀有六秒启动")
	view.foot += Vector2(60, 0)
	view._process(1)
	check(view.opening.is_empty() and view.bag.is_empty(), "离开范围取消")
	view.foot = Vector2(740, 520)
	await key(KEY_E)
	view.enter("wreck")
	check(view.opening.is_empty(), "切图取消")
	view.enter("shoal")
	view.foot = Vector2(340, 560)
	await key(KEY_E)
	view.close_button.pressed.emit()
	check(view.opening.is_empty() and is_instance_valid(sea.dive_view) and view.feedback.text.contains("距离"), "关闭入口取消且远离光柱不退出")
	var entry: Dictionary = sea.node_states.shoal.s2.duplicate()
	var expected: Array = catalog.chest_loot("shoal", "s2", int(entry.stock), float(entry.timestamp))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_E)
	view._process(3)
	check(view.bag.is_empty() and sea.node_states.shoal.s2.stock == entry.stock, "高级箱保存失败不消耗不发奖")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_E)
	view._process(3)
	check(view.bag == expected, "保存失败重试同代次随机固定防重抽")
	view.bag = ["pearl", "pearl", "coral", "shell"]
	await key(KEY_E)
	check(view.opening.is_empty() and view.message.contains("空间不足"), "随机前最大占格检查")
	view.bag.clear()
	await key(KEY_E)
	view.oxygen = 1
	view._process(3)
	check(view.opening.is_empty() and view.bag.is_empty() and view.settlement_saved, "完成同帧耗尽优先取消零奖励")
	await key(KEY_ESCAPE)
	check(catalog.CHESTS[0].rare < catalog.CHESTS[1].rare and catalog.CHESTS[1].rare < catalog.CHESTS[2].rare, "候选品质稀有概率递增")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.oxygen = 26
	view._process(0.1)
	check(view.oxygen_label.text.contains("低氧警告") and view.oxygen_label.text.contains("整袋丢失"), "低氧规则持续可见")
	view.enter("trench")
	view.foot = Vector2(580, 370)
	view.bag = ["pearl"]
	view.interact()
	check(view.opening.is_empty() and view.message.contains("预留6格"), "稀有箱按最大六格预留不先抽奖")
	view.bag.clear()
	view.interact()
	check(view.opening_left == 6, "海沟稀有箱启动")
	view._exit_tree()
	check(view.opening.is_empty() and view.bag.is_empty(), "关闭场景取消不发奖")
	view.foot = view.safety_position()
	await key(KEY_ESCAPE)
	for map in catalog.POOLS:
		for node in catalog.NODES[map]:
			for seed_stock in [1, 2, 3]:
				var loot: Array = catalog.chest_loot(map, node[0], seed_stock, 1000.0)
				check(loot.size() == catalog.CHESTS[catalog.chest_quality(map, node[0])].count and loot.all(func(id: String) -> bool: return id in catalog.POOLS[map]), "品质件数及地点随机池边界 " + node[0])

func technology_checks() -> void:
	var module = load("res://scripts/scenes/water_technology.gd")
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	var tech = sea.technology
	check(tech.state == module.defaults() and module.valid(tech.state), "科技新局严格默认且无自动研究")
	var costs := {"T1": {"coral": 1, "shell": 1}, "T2": {"timber": 2, "copper": 1}, "T3": {"timber": 2, "coral": 2}, "T4": {"algae": 2, "pearl": 1}, "T5": {"copper": 2, "algae": 1}, "T6": {"copper": 2, "pearl": 1}}
	for id in costs:
		check(module.TECHS[id].cost == costs[id], "科技配方固定数值 " + id)
	check(module.TECHS.T0.cost == {} and module.BUILD_COSTS.research == {"wood": 2, "scrap": 2} and module.BUILD_COSTS.machine == {"wood": 3, "scrap": 2, "rope": 1, "coral": 1}, "T0选料、研究台及机器固定配方")
	for id in ["coral", "shell", "timber", "copper", "algae"]:
		check(module.TARGETS[id][1] == {"coral": 30.0, "shell": 30.0, "timber": 45.0, "copper": 45.0, "algae": 60.0}[id], "各目标周期固定30/45/60秒 " + id)
	for id in sea.resources: sea.resources[id] = 100
	for id in ["wood", "scrap", "fiber", "rope"]: sea.set(id, 100)
	check(sea._cache_round(), "科技充足材料隔离基线")
	var before := gameplay_state()
	for material in module.BUILD_COSTS.research:
		sea.set(material, 0)
		check(sea._cache_round(), "研究台单项缺料基线 " + material)
		var missing := gameplay_state()
		check(not tech.build("research") and gameplay_state() == missing, "研究台每项材料不足不扣费 " + material)
		sea.set(material, 100)
	check(sea._cache_round(), "研究台恢复充足材料")
	before = gameplay_state()
	check(not tech.research("T0", {"coral": 2}) and gameplay_state() == before, "无研究台不能研究")
	check(not tech.build("machine") and gameplay_state() == before, "未T1不能建打捞器")
	var slots: Array = sea.building_slots.duplicate()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not tech.build("research") and gameplay_state() == before, "研究台写失败全回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.build("research") and sea.wood == 98 and sea.scrap == 98 and sea.building_slots == slots and not sea.dive_core and not sea.resident, "研究台木2废2独立位且无核心居民前置")
	before = gameplay_state()
	check(not tech.build("research") and gameplay_state() == before, "研究台限一座不重复扣费")
	check(not tech.research("T0", {"coral": 2}) and gameplay_state() == before, "仅仓库有材料不冒充手动带回")
	tech.record_manual(["coral"])
	check(tech.state.manual == {"shoal": true, "wreck": false, "trench": false}, "手动材料仅标记对应浅滩")
	check(sea._cache_round(), "手动发现基线保存")
	for selection in [{}, {"coral": 1}, {"coral": 2, "shell": 1}, {"wood": 2}, {"coral": true}, {"coral": -1, "shell": 3}, {"coral": 1.5, "shell": 0.5}, {"coral": "2"}]:
		before = gameplay_state()
		check(not tech.research("T0", selection) and gameplay_state() == before, "T0拒绝非法选料且不扣费 " + str(selection))
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not tech.research("T0", {"coral": 1, "shell": 1}) and gameplay_state() == before, "T0选料写失败精确回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.research("T0", {"coral": 1, "shell": 1}) and sea.resources.coral == 99 and sea.resources.shell == 99 and sea.resources.pearl == 100, "T0只扣所选两件不默认珍珠")
	before = gameplay_state()
	check(not tech.research("T0", {"pearl": 2}) and gameplay_state() == before, "重复T0不扣珍珠")
	check(not tech.research("T4") and gameplay_state() == before, "跨级研究拒绝且不扣料")
	check(not tech.select_target("pearl") and not tech.research("unknown"), "珍珠不是自动目标且未知科技拒绝")
	for id in ["T1", "T2", "T3", "T4", "T5", "T6"]:
		if id in ["T2", "T4"]:
			before = gameplay_state()
			check(not tech.research(id) and gameplay_state() == before, "区域手动发现前置拒绝 " + id)
			tech.record_manual(["timber" if id == "T2" else "algae"])
		for material in module.TECHS[id].cost:
			var count: int = sea.resources[material]
			sea.resources[material] = 0
			check(sea._cache_round(), "研究逐项缺料基线 " + id + material)
			before = gameplay_state()
			check(not tech.research(id) and gameplay_state() == before, "研究每项费用不足整笔拒绝 " + id + material)
			sea.resources[material] = count
		check(sea._cache_round(), "研究写失败基线 " + id)
		before = gameplay_state()
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
		check(not tech.research(id) and gameplay_state() == before, "研究保存失败完整回滚 " + id)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
		check(tech.research(id), "研究成功 " + id)
		for material in module.TECHS[id].cost:
			check(sea.resources[material] == before.resources[material] - module.TECHS[id].cost[material], "研究精确扣费 " + id + material)
		before = gameplay_state()
		check(not tech.research(id) and gameplay_state() == before, "研究不可重复 " + id)
	check(tech.capacity() == 16 and sea.net_expansion == 0, "T3仅扩设备仓不扩潜水网袋")
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not tech.build("machine") and gameplay_state() == before, "设备建造写失败回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.build("machine") and sea.wood == before.wood - 3 and sea.scrap == before.scrap - 2 and sea.rope == before.rope - 1 and sea.resources.coral == before.resources.coral - 1 and sea.building_slots == slots, "打捞器木3废2绳1珊瑚1独立位")
	before = gameplay_state()
	check(not tech.build("machine") and gameplay_state() == before, "设备限一台")
	for advanced in [false, true]:
		var pack: String = "advanced" if advanced else "normal"
		before = gameplay_state()
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
		check(not tech.craft_pack(advanced, 3) and gameplay_state() == before, "批量维护包写失败全回滚 " + pack)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
		check(tech.craft_pack(advanced, 3) and tech.state.packs[pack] == 3 and sea.resources.shell == before.resources.shell - 3 and sea.rope == before.rope - 3 and sea.fiber == before.fiber and sea.resources.algae == before.resources.algae - (3 if advanced else 0), "批量维护包精确扣费 " + pack)
		before = gameplay_state()
		check(not tech.craft_pack(advanced, 0) and not tech.craft_pack(advanced, -1) and not tech.craft_pack(advanced, 1000001) and gameplay_state() == before, "非法维护包批量拒绝 " + pack)
	for advanced in [false, true]:
		var pack: String = "advanced" if advanced else "normal"
		var previous: int = tech.state.packs[pack]
		tech.state.packs[pack] = catalog.RESOURCE_LIMIT
		check(sea._cache_round(), "维护包库存上限基线 " + pack)
		before = gameplay_state()
		check(not tech.craft_pack(advanced, 1) and gameplay_state() == before, "维护包库存上限整批拒绝 " + pack)
		tech.state.packs[pack] = previous
	check(sea._cache_round(), "投包写失败基线")
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not tech.refuel(false, 2) and gameplay_state() == before, "投包写失败整包额度全部回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.refuel(false, 2) and tech.state.credits == 12 and tech.state.paused and tech.state.current == "", "主动暂停投普通包每包6但不自启")
	check(tech.refuel(true) and tech.state.credits == 24 and tech.state.packs.advanced == 2, "进阶整包12额度到24")
	before = gameplay_state()
	check(not tech.refuel(false) and not tech.refuel(true) and gameplay_state() == before, "24额度超出整包拒绝不扣包")
	check(tech.resume() and tech.state.credits == 23 and tech.state.current == "coral" and tech.state.remaining == 30, "启动周期只扣1额度且T5不缩周期")
	tech.tick(10)
	check(tech.state.remaining == 20 and tech.state.credits == 23, "周期中不重复扣额度")
	for delta in [NAN, INF, -INF, -1.0, 0.0]:
		var snapshot: Dictionary = tech.state.duplicate(true)
		tech.tick(delta)
		check(tech.state == snapshot, "设备拒绝失效delta " + str(delta))
	check(tech.pause() and tech.state.remaining == 20 and tech.state.credits == 23, "暂停保留已投入及进度不退款")
	tech.tick(1000)
	check(tech.state.remaining == 20 and tech.state.cargo.coral == 0, "暂停大delta不补算")
	check(tech.select_target("timber") and tech.state.current == "coral" and tech.state.remaining == 20, "预约不替换当前周期")
	check(tech.resume() and tech.state.credits == 23 and tech.state.remaining == 20, "继续已有周期不再扣1")
	var nodes: Dictionary = sea.node_states.duplicate(true)
	tech.tick(20)
	check(tech.state.cargo.coral == 1 and tech.state.current == "timber" and tech.state.remaining == 45 and tech.state.credits == 22 and sea.node_states == nodes, "完工一件并按预约启动45秒且不扣海底库存")
	for modal in ["management", "technology", "warehouse", "map"]:
		if modal == "management": sea._show_management()
		elif modal == "technology": tech.show_page()
		elif modal == "warehouse": sea._show_warehouse()
		else: sea.exploration_tools.open_map()
		var snapshot: Dictionary = tech.state.duplicate(true)
		tech.tick(20)
		sea._process(20)
		check(tech.state == snapshot, "模态暂停设备计时 " + modal)
		if modal == "management": sea._close_management()
		elif modal == "technology": tech.dialog.hide()
		elif modal == "map": sea.exploration_tools.atlas.close()
		else:
			for child in sea.get_children():
				if child is AcceptDialog and child.visible:
					child.hide()
					child.queue_free()
		await process_frame
	check(tech.pause(), "满仓测试前暂停")
	tech.state.current = ""
	tech.state.remaining = 0.0
	tech.state.cargo = {"coral": 16, "shell": 0, "timber": 0, "copper": 0, "algae": 0}
	check(sea._cache_round(), "设备满仓合法基线")
	var credits: int = tech.state.credits
	check(tech.resume() and tech.state.current == "" and tech.state.credits == credits, "满仓继续不扣下一周期")
	tech.tick(1000)
	check(tech.state.cargo.coral == 16 and tech.state.credits == credits, "满仓大delta不产货不扣额度")
	sea.resources.coral = catalog.RESOURCE_LIMIT - 15
	check(sea._cache_round(), "领取仓上限基线")
	before = gameplay_state()
	check(not tech.claim() and gameplay_state() == before, "仓库仅差1也整批拒绝不部分入库")
	sea.resources.coral = 100
	tech.state.manual = {"shoal": true, "wreck": true, "trench": true}
	check(sea._cache_round(), "领取事务基线")
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(not tech.claim() and gameplay_state() == before, "领取写失败仓库货仓额度进度全部回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.claim() and sea.resources.coral == 116 and tech._cargo_count() == 0 and tech.state.current == "timber" and tech.state.credits == credits - 1, "满仓领取后自动恢复且只扣新周期1")
	tech.tick(12.5)
	check(sea._cache_round(), "读档进度小数基线")
	var saved: Dictionary = tech.state.duplicate(true)
	game.load_sea_save()
	check(json_state_equal(game.water_activity_state.technology, saved), "v8重读保留科技货仓额度与小数进度")
	sea.queue_free()
	await process_frame
	game.load_sea_save()
	sea = load("res://scenes/WaterActivity.tscn").instantiate()
	root.add_child(sea)
	sea.set_process(false)
	await process_frame
	tech = sea.technology
	check(tech.state.paused and tech.state.current == "timber" and tech.state.remaining == 32.5 and tech.state.credits == saved.credits, "真实重建场景读档保进度且必须手动继续")
	tech.tick(10000)
	check(tech.state.remaining == 32.5, "读档不补离线时间")
	check(tech.resume() and tech.state.remaining == 32.5 and tech.state.credits == saved.credits, "读档手动继续不重复扣已投入")
	before = gameplay_state()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	tech.tick(32.5)
	check(tech._settlement_failed and tech.state.current == "timber" and tech.state.remaining == 0 and tech._cargo_count() == 0 and tech.state.credits == before.technology.credits, "完工写失败保待结算不发货不重复扣")
	tech.tick(10000)
	check(tech._cargo_count() == 0 and tech.state.remaining == 0, "完工失败冻结自然计时")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	check(tech.resume() and tech.state.cargo.timber == 1 and tech.state.current == "timber" and tech.state.remaining == 45 and tech.state.credits == before.technology.credits - 1, "完工重试仅发一件并扣下一周期1")
	check(tech.pause(), "T6开箱前暂停设备")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	for index in [1, 2]:
		view.bag.clear()
		var node: Array = catalog.NODES.shoal[index]
		view.foot = node[2]
		var entry: Dictionary = sea.node_states.shoal[node[0]].duplicate()
		var seconds := 2.0 if index == 1 else 4.0
		view.start_chest(node)
		check(is_equal_approx(view.opening_left, seconds), "T6精良2秒稀有4秒 " + node[0])
		view.tick_opening(seconds - 0.5)
		check(view.bag.is_empty() and sea.node_states.shoal[node[0]].stock == entry.stock, "T6完成前不扣库存不给物品 " + node[0])
		view.tick_opening(0.5)
		check(view.bag == catalog.chest_loot("shoal", node[0], int(entry.stock), float(entry.timestamp)) and view.oxygen == 90 and view.capacity() == 8, "T6不改随机掉落氧气网袋 " + node[0])
	view.foot = view.safety_position()
	sea._close_dive()
	await key(KEY_ESCAPE)
	technology_economy_checks()
	await technology_schema_checks()

func technology_economy_checks() -> void:
	var baseline: Dictionary = sea._round_state().duplicate(true)
	for advanced in [false, true]:
		sea._restore_round(baseline)
		var tech = sea.technology
		tech.state.current = ""
		tech.state.remaining = 0.0
		tech.state.credits = 0
		tech.state.paused = true
		for id in tech.state.cargo: tech.state.cargo[id] = 0
		tech.state.packs = {"normal": 0, "advanced": 0}
		sea.core_level = 2
		sea.raft_tiles = 3
		sea.building_slots = ["core", "collector", "workshop"]
		sea.collectors = 1
		sea.automated_collecting = true
		sea.workshop_built = true
		sea.orders_completed = 2
		sea.production_elapsed = 0.0
		sea.fiber = 0
		sea.rope = 0
		check(sea._cache_round(), "成熟海面自动绳索经济合法基线 " + str(advanced))
		sea.fiber = 10
		var before_rope := gameplay_state()
		check(not tech.craft_pack(advanced) and gameplay_state() == before_rope, "有纤维无绳索不能冒充维护包耗材 " + str(advanced))
		sea.fiber = 0
		sea._tick_production(4.0)
		check(sea.rope == 1 and sea.fiber == 0, "成熟海面真实生产自动加工绳索且无纤维 " + str(advanced))
		var resources: Dictionary = sea.resources.duplicate(true)
		check(tech.craft_pack(advanced) and sea.rope == 0 and sea.fiber == 0 and sea.resources.shell == resources.shell - 1 and sea.resources.algae == resources.algae - (1 if advanced else 0), "自动产绳可直接制作维护包且不需要纤维 " + str(advanced))
		var rounds := 12 if advanced else 6
		var targets: Array = ["shell", "algae"] if advanced else ["shell"]
		while targets.size() < rounds: targets.append("coral")
		check(tech.select_target(targets[0]) and tech.refuel(advanced) and tech.state.credits == rounds and tech.resume(), "单包完整6/12轮额度 " + str(advanced))
		for index in rounds:
			var target: String = targets[index]
			var seconds := 60.0 if target == "algae" else 30.0
			check(tech.state.current == target and tech.state.remaining == seconds and tech.state.credits == rounds - index - 1, "补耗材轮周期及扣额准确 %s/%d" % [str(advanced), index])
			if index + 1 < rounds:
				check(tech.select_target(targets[index + 1]), "预约下一经济循环目标%d" % index)
			tech.tick(seconds - 0.5)
			check(tech._cargo_count() == index and tech.state.remaining == 0.5, "完整周期前不提前发货%d" % index)
			tech.tick(0.5)
		check(tech._cargo_count() == rounds and tech.state.credits == 0 and tech.state.current == "", "单包恰好完成6/12轮不透支 " + str(advanced))
		check(tech.claim() and sea.resources.shell == resources.shell and sea.resources.algae == resources.algae and sea.resources.coral == resources.coral + (10 if advanced else 5), "普通6轮含贝群1轮净5；进阶12轮含贝群与藻共2轮净10 " + str(advanced))
	sea._restore_round(baseline)

func technology_schema_checks() -> void:
	var module = load("res://scripts/scenes/water_technology.gd")
	sea._start_round()
	var base: Dictionary = sea._round_state()
	base.resources.coral = 2
	base.resources.timber = 1
	base.resources.pearl = 1
	base.erase("technology")
	for version in [1, 2, 3, 4, 5, 6]:
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": base}))
		var expected: Dictionary = module.migrate(base.resources) if version == 6 else module.defaults()
		check(not migrated.is_empty() and json_state_equal(migrated.technology, expected), "v%d科技迁移按真实保留资源补区域且不赠研究设备" % version)
	check(module.migrate({}).manual == module.defaults().manual, "旧档已花光材料不伪造历史手动记录")
	var tech = sea.technology
	check(sea.settle_net(["coral"], 0) and sea.public_project_service.deposit_bag() and tech.state.manual.shoal and not tech.state.manual.wreck, "真实安全封存后入库桥接手动区域")
	sea._start_round()
	tech.state.research_built = true
	tech.state.researched.T0 = true
	tech.state.researched.T1 = true
	tech.state.machine_built = true
	tech.state.manual.shoal = true
	tech.state.cargo.coral = 1
	check(sea._cache_round(), "自动领取手动标记隔离基线")
	tech.state.manual.shoal = false
	tech.state.manual.wreck = true
	check(tech.claim() and not tech.state.manual.shoal and tech.state.manual.wreck, "自动领取不补手动发现")
	var valid: Dictionary = sea._round_state()
	check(not game._read_sea_text(JSON.stringify({"version": 8, "state": valid})).is_empty(), "合法v8科技完整结构可读取")
	for target in {"coral": 60.0, "timber": 90.0, "algae": 120.0}:
		var old_seconds: float = {"coral": 60.0, "timber": 90.0, "algae": 120.0}[target]
		for remaining in [0.0, old_seconds * 0.375, old_seconds]:
			var legacy: Dictionary = valid.duplicate(true)
			for id in legacy.technology.researched: legacy.technology.researched[id] = true
			for region in legacy.technology.manual: legacy.technology.manual[region] = true
			legacy.technology.target = target
			legacy.technology.current = target
			legacy.technology.remaining = remaining
			legacy.technology.credits = 5
			legacy.technology.packs = {"normal": 2, "advanced": 1}
			var expected: Dictionary = legacy.duplicate(true)
			expected.public_project = load("res://scripts/scenes/public_project_service.gd").defaults()
			expected.technology.remaining = remaining * 0.5
			var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": 7, "state": legacy}, "", true, true))
			check(not migrated.is_empty() and json_state_equal(migrated, expected), "v7三周期零/中间/满额仅剩余秒减半 %s/%s" % [target, str(remaining)])
			var reread: Dictionary = game._read_sea_text(JSON.stringify({"version": 8, "state": expected}, "", true, true))
			check(not reread.is_empty() and json_state_equal(reread, expected), "v8重读不得再次减半且保留全部状态 %s/%s" % [target, str(remaining)])
			if not migrated.is_empty():
				var migrated_reread: Dictionary = game._read_sea_text(JSON.stringify({"version": 8, "state": migrated}, "", true, true))
				check(json_state_equal(migrated_reread, migrated), "v7迁移结果以v8重读幂等 %s/%s" % [target, str(remaining)])
			legacy.technology.remaining = old_seconds + 0.5
			check(game._read_sea_text(JSON.stringify({"version": 7, "state": legacy})).is_empty(), "v7超过旧周期上限严格拒绝 " + target)
			legacy.technology.remaining = old_seconds * 0.5 + 0.5
			check(game._read_sea_text(JSON.stringify({"version": 8, "state": legacy})).is_empty(), "v8超过新周期上限严格拒绝 " + target)
	for mode in 42:
		var bad := valid.duplicate(true)
		var s: Dictionary = bad.technology
		match mode:
			0: bad.erase("technology")
			1: bad.technology = []
			2: s.unknown = 0
			3: s.erase("paused")
			4: s.research_built = 1
			5: s.machine_built = "true"
			6: s.paused = 0
			7: s.researched.T0 = 1
			8: s.researched.T4 = true
			9: s.researched.unknown = false
			10: s.researched.erase("T6")
			11: s.manual.shoal = 1
			12: s.manual.unknown = false
			13: s.manual.erase("trench")
			14: s.packs.normal = -1
			15: s.packs.advanced = 1
			16: s.packs.normal = 1000001
			17: s.packs.normal = true
			18: s.packs.normal = 0.5
			19: s.packs.unknown = 0
			20: s.credits = 25
			21: s.credits = -1
			22: s.credits = true
			23: s.credits = 1.5
			24: s.target = "pearl"
			25: s.target = "timber"
			26: s.current = "pearl"
			27: s.current = "coral"; s.remaining = 31
			28: s.remaining = -1
			29: s.remaining = "1"
			30: s.remaining = true
			31: s.remaining = 1
			32: s.tracked = "T7"
			33: s.cargo.coral = 9
			34: s.cargo.pearl = 1
			35: s.cargo.timber = 1
			36: s.cargo.coral = true
			37: s.cargo.coral = -1
			38: s.machine_built = false; s.credits = 1
			39: s.research_built = false
			40: s.manual = {"shoal": false, "wreck": false, "trench": false}
			41: s.current = "coral"; s.remaining = 20; s.cargo.coral = 8
		check(not module.valid(bad.get("technology")), "科技schema拒绝恶意结构%d" % mode)
		check(game._read_sea_text(JSON.stringify({"version": 8, "state": bad})).is_empty(), "v8真实入口拒绝恶意科技%d" % mode)
	for invalid in [NAN, INF, -INF]:
		var bad: Dictionary = valid.technology.duplicate(true)
		bad.remaining = invalid
		check(not module.valid(bad), "科技schema拒绝非有限进度 " + str(invalid))

func species_route(view: Control, destination: Vector2) -> bool:
	var origin: Vector2 = view.foot
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var parents := {Vector2i.ZERO: Vector2i.ZERO}
	var cursor := 0
	var found := false
	var end := Vector2i.ZERO
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		var point := origin + Vector2(cell) * 10.0
		if point.distance_to(destination) <= 10.0:
			end = cell
			found = true
			break
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if parents.has(next): continue
			var next_point := origin + Vector2(next) * 10.0
			if not view.can_stand(next_point) or not view.can_stand((point + next_point) / 2.0): continue
			parents[next] = cell
			queue.append(next)
	if not found: return false
	var route: Array[Vector2] = [destination]
	while end != Vector2i.ZERO:
		route.push_front(origin + Vector2(end) * 10.0)
		end = parents[end]
	for point in route:
		view.move_step(point - view.foot)
		if view.foot.distance_to(point) > 0.01: return false
	return view.foot.distance_to(destination) < 0.01

func species_checks() -> void:
	var starting_checks := checks
	var starting_failures := failures
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	check(ProjectSettings.get_setting("application/config/use_custom_user_dir", false) and str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Underwater-"), "生态专项仅允许隔离用户目录")
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Underwater-"): return
	sea._start_round()
	check(sea._cache_round(), "生态专项保存空图鉴基线")
	var entries: Dictionary = catalog.species()
	var expected := {
		"shoal": ["shoal_glowfish", "shoal_blue_hermit_crab", "shoal_spotted_flatfish"],
		"wreck": ["wreck_lanternfish", "wreck_rust_crab", "wreck_cabin_eel"],
		"trench": ["trench_blind_eel", "trench_glowing_jellyfish", "trench_glass_snail"]}
	check(entries.size() == 9 and catalog.species_records().size() == 9 and catalog.OBSERVE_RADIUS == 48.0 and catalog.OBSERVE_SECONDS == 2.0, "九物种与48像素2秒配置")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	for region in expected:
		if region != "shoal": view.enter(region)
		var entrance: Vector2 = Vector2(145, 520) if region == "shoal" else Vector2(225, 410 if region == "trench" else 490)
		check(view.foot == entrance and view.can_stand(entrance), "实际入口安全落点 " + region)
		for id in expected[region]:
			check(entries.has(id), "固定物种ID存在 " + id)
			if not entries.has(id): continue
			var entry: Dictionary = entries[id]
			check(entry.place == region and entry.pos is Vector2 and not entry.name.is_empty() and not entry.description.is_empty() and entry.color is Color and entry.shape in ["fish", "crab", "flatfish", "angler", "eel", "jellyfish", "snail"] and not sea.species_records[id], "物种配置完整且默认未记录 " + id)
			view.foot = entrance
			check(species_route(view, entry.pos), "从实际入口BFS并逐段行走可达 " + id)
			check(view.nearest_species() == id, "到达后最近物种匹配 " + id)
	view.enter("shoal")
	var id := "shoal_glowfish"
	var position: Vector2 = entries[id].pos
	view.foot = position + Vector2(48, 0)
	check(view.nearest_species() == id, "48像素边界包含在观察圈")
	view.tick_observation(1.0)
	check(view.observing_id == id and view.observation_elapsed == 1.0 and not sea.species_records[id], "边界累计1秒未点亮")
	view.move_step(Vector2(-8, 0))
	view.tick_observation(0.5)
	check(view.observation_elapsed == 1.5, "圈内实际移动继续累计")
	view.foot = position + Vector2(48.01, 0)
	check(view.nearest_species().is_empty(), "48像素外不选中")
	view.tick_observation(0.5)
	check(view.observing_id.is_empty() and view.observation_elapsed == 0 and not sea.species_records[id], "离圈清零不拼接两段时间")
	view.foot = position
	for delta in [0.0, -1.0, NAN, INF]:
		view.tick_observation(delta)
		check(view.observation_elapsed == 0 and not sea.species_records[id], "无效观察delta不累计 " + str(delta))
	view.tick_observation(1.0)
	view.reset_observation()
	check(view.observing_id.is_empty() and view.observation_elapsed == 0, "显式重置观察")
	view.tick_observation(1.0)
	view.enter("wreck")
	check(view.observation_elapsed == 0 and view.observing_id.is_empty(), "切图立即清零观察")
	view.enter("shoal")
	view.foot = position
	view.tick_observation(1.0)
	await key(KEY_B)
	check(view.bag_open and view.observation_elapsed == 0, "真实B开网袋立即清零")
	view._process(2.0)
	check(not sea.species_records[id] and view.observation_elapsed == 0, "网袋开启不观察")
	await key(KEY_B)
	view.tick_observation(1.0)
	view.start_chest(catalog.NODES.shoal[1])
	check(not view.opening.is_empty() and view.observation_elapsed == 0, "启动精良箱立即清零观察")
	view.tick_observation(2.0)
	check(not sea.species_records[id] and view.observation_elapsed == 0, "开箱期间不观察")
	view.cancel_opening("生态专项")
	position = view.species_position(id)
	view.foot = position
	var before: Dictionary = sea._round_state().duplicate(true)
	var memory: Dictionary = game.water_activity_state.duplicate(true)
	var disk := FileAccess.get_file_as_string(game.SEA_SAVE)
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "生态保存失败注入SEA_TEMP目录")
	view.tick_observation(1.99)
	check(not sea.species_records[id] and is_equal_approx(view.observation_elapsed, 1.99), "不足2秒不提交")
	view.tick_observation(0.01)
	check(view.observation_blocked.has(id) and view.observing_id.is_empty() and view.observation_elapsed == 0 and view.message.contains("失败"), "2秒保存失败明确提示且阻断自动重试")
	check(sea.result_label.text.contains("失败"), "观察事务失败更新海面错误反馈")
	before.result = sea.result_label.text
	check(json_state_equal(sea._round_state(), before) and json_state_equal(game.water_activity_state, memory) and FileAccess.get_file_as_string(game.SEA_SAVE) == disk, "观察失败主机内存管理器磁盘均不点亮且无奖励")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "移除生态保存故障")
	view.tick_observation(100.0)
	check(not sea.species_records[id] and view.observation_blocked.has(id) and FileAccess.get_file_as_string(game.SEA_SAVE) == disk, "恢复磁盘后留圈仍不自动重试")
	view.foot = position + Vector2(48, 0)
	view.tick_observation(0.1)
	check(view.observation_blocked.has(id), "失败后48边界仍阻断")
	view.foot = position + Vector2(49, 0)
	view.tick_observation(0.1)
	check(view.observation_blocked.is_empty(), "真正离圈解除失败阻断")
	view.foot = position
	view.tick_observation(1.0)
	check(not sea.species_records[id] and view.observation_elapsed == 1.0, "重入圈从零重新计时")
	view.foot = position + Vector2(48, 0)
	view.tick_observation(1.0)
	check(sea.species_records[id] and game.water_activity_state.species_records[id] and view.message.contains("已保存"), "重新观察满2秒真事务点亮")
	var recorded: Dictionary = sea._round_state().duplicate(true)
	var expected_state := before.duplicate(true)
	expected_state.species_records[id] = true
	check(json_state_equal(recorded, expected_state), "生态成功只改变对应图鉴位，无材料核心奖励")
	game.load_sea_save()
	check(game.water_activity_state.species_records[id] and int(JSON.parse_string(FileAccess.get_file_as_string(game.SEA_SAVE)).version) == 11, "成功后立即从v11磁盘重载保留")
	disk = FileAccess.get_file_as_string(game.SEA_SAVE)
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "幂等提交注入写故障")
	check(sea._commit_species(id), "已记录物种重复真事务幂等且无需写盘")
	view.tick_observation(20.0)
	check(view.nearest_species().is_empty() and sea._round_state() == recorded and FileAccess.get_file_as_string(game.SEA_SAVE) == disk, "重复观察不重复提交或奖励")
	check(not sea._commit_species("unknown_species"), "未知物种提交拒绝")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP)) == OK, "移除幂等提交写故障")
	var second := "shoal_blue_hermit_crab"
	view.foot = entries[second].pos
	view.tick_observation(1.5)
	view.bag = ["coral"]
	view.oxygen = 0.5
	view._process(0.5)
	check(view.oxygen == 0 and view.ascending > 0 and view.observation_elapsed == 0 and not sea.species_records[second] and view.bag.is_empty(), "同帧耗氧优先于满2秒观察，未记录且整袋丢失")
	view.tick_observation(2.0)
	check(not sea.species_records[second], "救援上浮期间禁止观察")
	view.tick_oxygen(catalog.ASCENT_SECONDS)
	check(view.settlement_saved and sea.species_records[id] and not sea.species_records[second], "救援保留已成功图鉴，不补记中断物种")
	game.load_sea_save()
	check(game.water_activity_state.species_records[id] and not game.water_activity_state.species_records[second], "救援后立即重载已存图鉴仍保留")
	await key(KEY_ESCAPE)
	sea._open_dive(true)
	view = sea.dive_view
	view.set_process(false)
	view.show_records_page("species")
	check(view.read_only and view.species_content.visible and not view.clues_content.visible and view.species_cards.size() == 9 and view.species_regions.size() == 3, "只读图鉴分页与九张物种卡")
	check(view.species_count.text.contains("1/9") and view.species_regions.shoal.text.contains("1/3") and view.species_regions.wreck.text.contains("0/3") and view.species_regions.trench.text.contains("0/3"), "只读图鉴总数与三地计数")
	for species_id in entries:
		var card: Dictionary = view.species_cards[species_id]
		check(is_instance_valid(card.icon) and card.icon.is_visible_in_tree() and not card.icon.get_signal_connection_list("draw").is_empty(), "剪影或点亮图形接入真实绘制 " + species_id)
		if species_id == id:
			check(card.text.text.contains(entries[species_id].name) and card.text.text.contains(entries[species_id].description) and card.text.text.contains("已记录") and not card.text.text.contains("未知生物"), "已点亮卡显示名称与描述")
		else:
			check(card.text.text.contains("未知生物") and card.text.text.contains("未记录") and not card.text.text.contains(entries[species_id].name) and not card.text.text.contains(entries[species_id].description), "未点亮剪影卡隐藏身份 " + species_id)
	before = sea._round_state().duplicate(true)
	disk = FileAccess.get_file_as_string(game.SEA_SAVE)
	view.foot = entries[second].pos
	view.tick_observation(20.0)
	check(not sea._commit_species(second) and sea._round_state() == before and FileAccess.get_file_as_string(game.SEA_SAVE) == disk, "只读图鉴不能观察提交且无落盘")
	view.show_records_page("clues")
	check(view.clues_content.visible and not view.species_content.visible, "图鉴可切回探索线索")
	view.show_records_page("species")
	check(view.species_count.text.contains("1/9"), "分页往返保持点亮与计数")
	sea._close_dive()
	var base: Dictionary = sea._round_state().duplicate(true)
	for version in range(1, 10):
		var legacy := base.duplicate(true)
		legacy.erase("species_records")
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": legacy}))
		check(not migrated.is_empty() and migrated.species_records == catalog.species_records(), "v%d缺失图鉴迁移为空九项" % version)
		legacy.species_records = {"injected": true}
		migrated = game._read_sea_text(JSON.stringify({"version": version, "state": legacy}))
		check(not migrated.is_empty() and migrated.species_records == catalog.species_records(), "v%d迁移不信任旧版伪造点亮" % version)
	check(not game._read_sea_text(JSON.stringify({"version": 10, "state": base})).is_empty(), "v10合法混合布尔图鉴可重读")
	for invalid in [null, true, 1, "records", [], {}]:
		var bad := base.duplicate(true)
		bad.species_records = invalid
		check(game._read_sea_text(JSON.stringify({"version": 10, "state": bad})).is_empty(), "v10拒绝非法图鉴容器 " + str(invalid))
	for invalid in [null, 0, 1, -1, 0.5, "true", [], {}]:
		var bad := base.duplicate(true)
		bad.species_records[id] = invalid
		check(game._read_sea_text(JSON.stringify({"version": 10, "state": bad})).is_empty(), "v10拒绝非布尔记录 " + str(invalid))
	for mode in ["missing", "extra", "replace", "absent"]:
		var bad := base.duplicate(true)
		if mode == "absent": bad.erase("species_records")
		else:
			if mode in ["missing", "replace"]: bad.species_records.erase(id)
			if mode in ["extra", "replace"]: bad.species_records.unknown_species = false
		check(game._read_sea_text(JSON.stringify({"version": 10, "state": bad})).is_empty(), "v10拒绝非法键集合 " + mode)
	print("SPECIES RESULT: ", checks - starting_checks, " checks, ", failures - starting_failures, " failed")

func additions_checks() -> void:
	var catalog = load("res://scripts/scenes/underwater_catalog.gd")
	sea._start_round()
	check(sea._cache_round(), "增量功能基线")
	var service = sea.public_project_service
	check(service.seal_bag(["coral"], false, "shoal", 0, ["shoal_glowfish"]), "观察凭据封存")
	check(not sea.dive_archive.safe.shoal_glowfish and sea.dive_archive.voyages == 0, "封存不授安全记录航程")
	check(service.deposit_bag() and sea.dive_archive.safe.shoal_glowfish and sea.dive_archive.voyages == 1, "入库安全记录及航程")
	check(service.deposit_bag() and sea.dive_archive.voyages == 1, "重复入库不重复航程")
	check(service.seal_bag(["live:shoal_blue_hermit_crab"], false, "shoal", 0), "活体独立封存")
	check(service.deposit_bag() and sea.dive_archive.captured.shoal_blue_hermit_crab and sea.dive_archive.safe.shoal_blue_hermit_crab, "活捕认证同时安全记录")
	check(service.seal_bag([], false, "shoal", 0) and sea.public_project.pending_bag == null and sea.dive_archive.voyages == 3, "空袋直接归档")
	check(not catalog.recipe_unlocked("capture_net", 0, sea.dive_archive), "两种安全记录未解锁捕网")
	sea.dive_archive.safe.shoal_spotted_flatfish = true
	check(catalog.recipe_unlocked("capture_net", 0, sea.dive_archive), "三种安全记录解锁捕网")
	sea.tide_table = true
	sea.core_level = 3
	sea.building_slots.append("tide")
	sea.raft_tiles = sea.building_slots.size()
	check(service.refresh_orders() and sea.dive_archive.orders.size() == 3, "潮测台三单")
	sea.resources.coral = 20
	sea.resources.shell = 20
	sea.resources.timber = 20
	check(service.seal_bag([], false, "shoal", 0), "旧委托结算")
	check(sea.dive_archive.completed.size() == 3 and sea.dive_archive.orders.size() == 3, "三槽完成后补单")
	for order in sea.dive_archive.orders: check(not order.done and order.id > 3, "新单不消费同批成果")
	sea.dive_archive.refreshed = Time.get_unix_time_from_system() - 86401
	var completed: int = sea.dive_archive.completed.size()
	check(service.seal_bag([], false, "shoal", 0) and sea.dive_archive.completed.size() == completed, "过期旧单不奖励")
	var orders: Array = sea.dive_archive.orders.duplicate(true)
	check(service.refresh_orders(Time.get_unix_time_from_system() - 100) and sea.dive_archive.orders == orders, "时间倒拨不刷新")
	sea.core_reward_claimed = true
	sea.dive_workshop_unlocked = true
	sea.dive_workshop_built = true
	sea.dive_archived = true
	sea.dive_core = true
	sea.dive_sonar = true
	sea.dive_shoal = true
	sea.equipment.capture_net.level = 1
	sea._cache_round()
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	sea.tide_clock = 100
	check(view.tide().rising, "涨潮相位")
	view.tick_ecology(0.01)
	var state: Dictionary = sea.creature_states.shoal_glowfish
	view.foot = state.pos - Vector2(25, 0)
	view.facing = Vector2.RIGHT
	check(view.push() and state.stun > 0, "扇形推开硬直")
	check(not view.push(), "推开冷却")
	view.bag = ["coral", "coral", "coral", "coral", "coral", "coral", "coral"]
	check(view.capture() and view.bag.size() == 7 and state.respawn == 0, "活捕满袋不移除")
	view.bag.clear()
	check(view.capture() and view.bag == ["live:shoal_glowfish"] and state.respawn == 180, "活捕成功及共享重生")
	check(view.used_slots() == 2, "活体两格")
	view.discard(0)
	check(view.bag.is_empty(), "活体可丢弃")
	sea.tide_clock = 240
	check(view.tidal_shells().size() == 2, "落潮两处贝群")
	sea.tide_shells[view.tidal_shells()[0][0]] = true
	check(view.tidal_shells().size() == 1, "临时贝群防重")
	view.tick_ecology(180)
	check(state.respawn == 0, "生物180秒重生")
	view.place = "wreck"
	sea.tide_clock = 0
	var crab: Dictionary = sea.creature_states.wreck_rust_crab
	for level in 3:
		sea.equipment.wrist.level = level
		crab.pos = Vector2(590, 400)
		crab.stun = 0.0
		view.foot = crab.pos
		view.oxygen = 90
		view.hit_cooldown = 0.0
		view.tick_ecology(0.001)
		check(is_equal_approx(view.oxygen, [84.0, 87.0, 90.0][level]), "护腕轻击减伤等级%d" % level)
	view.place = "shoal"
	view.foot = Vector2(340, 560)
	view.start_chest(catalog.NODES.shoal[1])
	view.move_step(Vector2(100, 0))
	view.tick_opening(1)
	check(view.opening.is_empty(), "被动位移离开半径取消开箱")
	sea._start_round()
	check(sea.tide_clock == 0 and sea.creature_states.is_empty() and sea.tide_shells.is_empty(), "重开清运行态")

func run() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Underwater-"):
		printerr("拒绝运行：水下回归必须使用 underwater.tests.ps1 创建的隔离用户目录。")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	await process_frame
	game = root.get_node("GameManager")
	game.water_activity_state = {}
	sea = load("res://scenes/WaterActivity.tscn").instantiate()
	root.add_child(sea)
	await process_frame
	sea.set_process(false)
	var base: Dictionary = sea._round_state()
	check(sea.dive_summary_label.text.contains("浅滩"), "浮台初始浅滩阶段")
	check(sea.action_tabs.get_tab_count() == 5, "海面保留原四类操作页并新增第五科技页")
	var entries := [sea.guide_button, sea.dive_button, sea.records_button, sea.dive_workshop_button, sea.technology_button, sea.settings_button, sea.management_button, sea.backpack_button, sea.navigation_button, sea.get_node("ReturnButton"), sea.exploration_tools.get_child(0).get_child(0)]
	check(sea.management_button.size == sea.backpack_button.size and sea.backpack_button.position.x - sea.management_button.get_rect().end.x >= 16, "经营背包统一尺寸且独立间隔至少16像素")
	check(sea.management.min_size.x >= 620 and sea.action_tabs.custom_minimum_size.x >= 600, "经营面板加宽留出条件说明空间")
	for entry in entries:
		check(entry.get_global_rect().end.y <= sea.SEA_VIEW.position.y and not sea.goal_label.get_global_rect().intersects(entry.get_global_rect()), "双行导航与目标地图不占海面且不重叠")
	for i in entries.size():
		check(entries[i].size.y >= 40, "常用入口至少40像素高")
		for j in range(i + 1, entries.size()):
			check(not entries[i].get_global_rect().intersects(entries[j].get_global_rect()), "任务板下潜记录工坊入口不重叠")
	check(sea.water_resolution == Vector2i(1280, 720), "默认窗口不再随桌面放大")
	sea.settings_button.pressed.emit()
	await process_frame
	check(sea.display_settings.visible and sea.resolution_picker.item_count == 5, "设置入口显示五档窗口分辨率")
	check(sea._sea_modal() and not sea.moving, "显示设置暂停海面并阻挡底层操作")
	sea.exploration_tools.open_map()
	check(not sea.exploration_tools.is_open(), "设置中地图不穿透")
	sea.resolution_picker.select(0)
	sea.display_settings.confirmed.emit()
	sea.display_settings.hide()
	check(sea.water_resolution == Vector2i(960, 540), "应用最小分辨率")
	var display_config := ConfigFile.new()
	check(display_config.load(sea.DISPLAY_SETTINGS_PATH) == OK and display_config.get_value("display", "resolution") == Vector2i(960, 540), "显示偏好独立持久化")
	check(json_state_equal(sea._round_state(), base), "调整显示设置不改变游戏进度")
	sea._apply_water_display(Vector2i(1280, 720), false)
	sea._save_water_display(false)
	check(not sea.management.visible and not sea.status_label.visible and not sea.dive_summary_label.visible, "主屏收起经营与材料明细")
	check(sea.SEA_VIEW.get_area() > 1280 * 720 * 0.7, "海域占逻辑画布七成以上")
	for point in [sea.SEA.position, sea.SEA.end, sea.player_foot, Vector2(500, 500)]:
		check(sea.screen_to_world(sea.world_to_screen(point)).is_equal_approx(point), "世界映射可逆且兼容旧坐标")
	check(sea.model.position.is_equal_approx(sea.world_to_screen(sea.player_foot)), "角色与世界统一映射")
	var surface_click := InputEventMouseButton.new()
	surface_click.button_index = MOUSE_BUTTON_LEFT
	surface_click.pressed = true
	surface_click.position = sea.world_to_screen(Vector2(600, 550))
	sea._unhandled_input(surface_click)
	check(sea.target.is_equal_approx(Vector2(600, 550)), "扩大海面点击反变换")
	for foot in [Vector2(130, 550), Vector2(720, 550)]:
		for offset in [Vector2(0, -32), Vector2(0, 38)]:
			surface_click.position = sea.world_to_screen(foot + offset)
			sea._unhandled_input(surface_click)
			check(sea.management.visible and sea.action_tabs.current_tab == 2 and not sea.moving, "点击NPC人物或提示直达居民页且停止移动")
			check(not sea.resident and not sea.partner and sea.water == base.water, "点击NPC只开入口不自动招募扣费")
			sea._close_management()
	check(sea.resident_hint.text.contains("建集水站") and sea.resident_hint.text.contains("清水1"), "阿汐显示建站及缺水条件")
	check(sea.partner_hint.text.contains("集水岗位") and sea.partner_hint.text.contains("清水2、绳索2"), "岚显示岗位及首单条件")
	sea.collectors = 1
	sea.water = 1
	sea._refresh_ui()
	check(not sea.resident_button.disabled and sea.resident_hint.text.contains("可接纳"), "条件满足提示可接纳")
	sea.resident = true
	sea._refresh_ui()
	check(not sea.job_button.disabled and sea.resident_hint.text.contains("安排集水岗位"), "入住提示安排岗位")
	sea.resident_working = true
	sea.orders_completed = 1
	sea._refresh_ui()
	check(not sea.partner_button.disabled and sea.partner_hint.text.contains("可邀请"), "条件满足提示可邀请")
	sea.partner = true
	sea._refresh_ui()
	check(sea.resident_hint.text.contains("每批") and sea.partner_hint.text.contains("航行页"), "已招募提示实际用途及下一步")
	sea.collectors = base.collectors
	sea.water = base.water
	sea.resident = base.resident
	sea.resident_working = base.resident_working
	sea.orders_completed = base.orders_completed
	sea.partner = base.partner
	sea._refresh_ui()
	surface_click.position = sea.world_to_screen(Vector2(600, 550))
	sea.management_button.pressed.emit()
	var sea_clock: float = sea.wave_elapsed
	sea._process(5)
	sea.backpack_button.pressed.emit()
	sea.exploration_tools.open_map()
	sea.dive_button.pressed.emit()
	check(sea.management.visible and sea.wave_elapsed == sea_clock and not sea.moving and not sea.exploration_tools.is_open() and not is_instance_valid(sea.dive_layer), "经营模态暂停世界并隔离外部入口")
	sea.core_button.pressed.emit()
	check(sea.build_dialog.visible, "经营内部业务按钮可打开建造预览")
	sea.build_dialog.hide()
	sea._show_management()
	for page in range(4):
		sea.action_tabs.current_tab = page
		await process_frame
		await process_frame
		check(sea.action_pages[page].is_visible_in_tree(), "当前操作页可见%d" % page)
		for other in range(4):
			check(sea.action_pages[other].is_visible_in_tree() == (other == page), "操作页互斥%d/%d" % [page, other])
		var bottom := 0.0
		for child in sea.action_pages[page].get_children():
			if not child.visible: continue
			check(child.position.y >= bottom, "容器操作和提示互不覆盖%d" % page)
			bottom = child.get_rect().end.y
			if child is Button: check(child.size.y >= 40, "经营操作至少40像素高")
		check(sea.action_pages[page].get_parent().get_parent().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "长提示限宽换行%d" % page)
	sea.action_tabs.current_tab = 0
	await key(KEY_ESCAPE)
	check(not sea.management.visible and root.gui_get_focus_owner() == sea.management_button, "Esc关闭经营并恢复入口焦点")
	sea.backpack_button.pressed.emit()
	await process_frame
	await process_frame
	var warehouse_found := false
	for child in sea.get_children():
		if child is AcceptDialog and child.visible:
			var inventory: ScrollContainer = child.get_node("InventoryScroll")
			check(inventory.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and inventory.size.y <= 430 and child.size.y < 650, "背包内容限高可纵向滚动且不超画布")
			var sections: VBoxContainer = inventory.get_child(0)
			var groups := 0
			var donation_buttons := 0
			var displayed := PackedStringArray()
			for section in sections.get_children():
				if section is Button:
					donation_buttons += 1
					check(section.text.contains("投入公共工程（永久消耗）"), "背包材料投料入口明确永久消耗")
				else:
					groups += 1
					for row in section.get_children(): displayed.append(row.text)
			check(groups == 4 and donation_buttons == sea.resources.size(), "背包保留四组库存配方且六种材料各有投料入口")
			var full_text := "\n".join(displayed)
			warehouse_found = full_text.contains("待领产出") and full_text.contains("珊瑚枝")
			for line in child.dialog_text.split("\n"):
				if line.is_empty(): continue
				var parts: PackedStringArray = line.split("：", true, 1)
				check(full_text.contains(line) or (parts.size() == 2 and full_text.contains(parts[0]) and full_text.contains(parts[1])), "分组背包完整保留库存用途与配方：" + line)
			var foot_before: Vector2 = sea.player_foot
			var target_before: Vector2 = sea.target
			sea._unhandled_input(surface_click)
			sea._process(5)
			sea.management_button.pressed.emit()
			sea._show_guide()
			check(sea.player_foot == foot_before and sea.target == target_before and not sea.management.visible and sea.wave_elapsed == sea_clock, "背包模态阻止移动点击与经营任务板穿透")
			child.hide()
			child.queue_free()
	check(warehouse_found, "背包按钮包含全部材料与待领明细")
	await process_frame
	surface_click.position = sea.world_to_screen(Vector2(390, 400))
	sea._unhandled_input(surface_click)
	check(sea.build_dialog.visible and sea.build_kind == "core", "映射后核心建筑点击命中")
	sea.build_dialog.hide()
	var unlocked_before: bool = sea.dive_workshop_unlocked
	sea.dive_workshop_unlocked = true
	surface_click.position = sea.world_to_screen(Vector2(155, 410))
	sea._unhandled_input(surface_click)
	check(sea._sea_window_open(), "潜水工坊视觉位置与点击命中同步")
	for child in sea.get_children():
		if child is AcceptDialog and child.visible:
			child.hide()
			child.queue_free()
	sea.dive_workshop_unlocked = unlocked_before
	await process_frame
	var original_feedback: String = sea.result_label.text
	sea.result_label.text = "完整反馈滚动查看，不覆盖场景。".repeat(100)
	await process_frame
	await process_frame
	check(sea.feedback_scroll.size.y == 48 and sea.result_label.size.y > 48 and sea.feedback_scroll.position.y >= sea.SEA_VIEW.end.y and sea.feedback_scroll.get_rect().end.y <= 720, "超长反馈在独立滚动区域保留全文")
	sea.result_label.text = original_feedback
	check(sea.SEA == Rect2(72, 238, 744, 414), "海面原场地碰撞不变")
	sea._open_dive(true)
	check(root.gui_get_focus_owner() == sea.dive_view.clues_tab and sea.dive_view.archive_button.disabled, "无核心记录聚焦线索页签")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == sea.dive_view.species_tab, "不可归档时Tab进入生态页签不穿透浮台")
	await key(KEY_ESCAPE)
	base = sea._round_state()
	for version in [1, 2, 3, 4]:
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": base}))
		check(not migrated.is_empty() and not migrated.dive_shoal and not migrated.dive_sonar and not migrated.dive_core and not migrated.dive_archived, "v%d默认初始化所有海底字段" % version)
	check(not sea._commit_dive("dive_core") and not sea._commit_dive("dive_sonar"), "线索前置")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	view.foot = Vector2(250, 520)
	check(view.place == "shoal" and not view.interact(), "起点调查距离受限")
	for code in [KEY_D, KEY_RIGHT, KEY_W, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_A, KEY_S]:
		view.foot = Vector2(250, 520)
		var focus := root.gui_get_focus_owner()
		var start: Vector2 = view.foot
		var press := InputEventKey.new()
		press.keycode = code
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		view._process(0.05)
		check(view.foot != start and root.gui_get_focus_owner() == focus, "真实移动键且不切焦点 " + str(code))
		press = InputEventKey.new()
		press.keycode = code
		Input.parse_input_event(press)
		await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300, 520)
	Input.parse_input_event(click)
	await process_frame
	var click_start: Vector2 = view.foot
	view._process(0.05)
	check(view.moving and view.foot != click_start, "真实点击移动")
	view.moving = false
	view.foot = Vector2(400, 250)
	click.position = Vector2(600, 250)
	Input.parse_input_event(click)
	await process_frame
	check(view.moving and view.target == click.position, "点击目标标记状态")
	for i in 30: view._process(0.05)
	check(not view.moving and view.can_stand(view.foot) and view.message.contains("受阻"), "目标受阻停止并提示绕路")
	var clock: float = sea.wave_elapsed
	var position: Vector2 = sea.player_foot
	sea._process(20)
	check(sea.wave_elapsed == clock and sea.player_foot == position and sea._round_state() == base, "海上计时移动及产出暂停")
	sea.exploration_tools.open_map()
	sea.exploration_tools.switch_game()
	sea.get_node("ReturnButton").pressed.emit()
	await key(KEY_M)
	check(not sea.exploration_tools.is_open() and is_instance_valid(sea.dive_view), "地图切换返回被阻挡")
	view.foot = Vector2(1080, 490)
	await key(KEY_E)
	check(view.place == "shoal" and view.message.contains("先调查"), "未调查不能进入沉船")
	view.foot = Vector2(350, 250)
	view.move_step(Vector2(250, 0))
	check(view.foot.x < 420, "珊瑚阻挡且高速不穿墙")
	view.foot = Vector2(145, 520)
	walk(view, Vector2(350, 390))
	walk(view, Vector2(650, 390))
	await key(KEY_E)
	check(sea.dive_shoal and view.message.contains("首次") and view.message.contains("船舷金属片"), "真实E调查光迹且叙事一致")
	await key(KEY_E)
	check(view.message.contains("回看") and view.site_text("光迹").contains("已记录"), "重复浅滩回看")
	await key(KEY_ESCAPE)
	check(is_instance_valid(sea.dive_view) and view.message.contains("距离"), "远处真实Esc受限并提示方向距离")
	view.close_button.pressed.emit()
	sea._close_dive()
	check(is_instance_valid(sea.dive_view), "按钮与宿主close无远程旁路")
	await key(KEY_B)
	await key(KEY_ESCAPE)
	check(not view.bag_open and is_instance_valid(sea.dive_view), "B内Esc先关闭背包不瞬移")
	walk(view, Vector2(350, 390))
	walk(view, view.safety_position())
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_layer) and sea.dive_shoal, "提前返航保留线索")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(view.place == "shoal", "重进从浅滩开始")
	view.foot = Vector2(1080, 490)
	await key(KEY_E)
	check(view.place == "wreck" and view.can_stand(view.foot), "船尾航路解锁安全落点")
	await key(KEY_E)
	check(view.place == "wreck", "前进后E不即刻折返")
	view.foot = Vector2(145, 490)
	await key(KEY_E)
	check(view.place == "shoal" and view.can_stand(view.foot) and view.foot.distance_to(Vector2(1080, 490)) == 80, "沉船反向返回浅滩对应出口")
	await key(KEY_E)
	check(view.place == "shoal", "反向落点E不立即折返")
	view.foot = Vector2(1080, 490)
	await key(KEY_E)
	view.foot = Vector2(1080, 480)
	await key(KEY_E)
	check(view.place == "wreck", "无声呐方向不能进海沟")
	view.foot = Vector2(300, 300)
	view.move_step(Vector2(300, 0))
	check(view.foot.x < 380, "船头堵死")
	view.foot = Vector2(145, 490)
	walk(view, Vector2(540, 490))
	walk(view, Vector2(720, 375))
	await key(KEY_E)
	check(sea.dive_sonar, "船尾可进入声呐台")
	walk(view, Vector2(1080, 480))
	await key(KEY_E)
	check(view.place == "trench" and view.can_stand(view.foot), "声呐解锁海沟安全落点")
	await key(KEY_E)
	check(view.place == "trench", "海沟前进不即刻折返")
	view.foot = Vector2(145, 410)
	await key(KEY_E)
	check(view.place == "wreck" and view.can_stand(view.foot) and view.foot.distance_to(Vector2(1080, 480)) == 80, "海沟返回沉船对应出口")
	await key(KEY_E)
	check(view.place == "wreck", "海沟反向E不立即折返")
	view.foot = Vector2(1080, 480)
	await key(KEY_E)
	view.foot = Vector2(145, 410)
	walk(view, Vector2(875, 410))
	await key(KEY_E)
	check(view.pending_core and not sea.dive_core and not sea.dive_archived, "唯一核心本潜暂存，安全上浮前不能归档")
	var unique: Dictionary = sea._round_state()
	await key(KEY_E)
	check(sea._round_state() == unique and view.message.contains("无重复奖励") and view.site_text("回声核心").contains("遗址"), "重复核心不发奖且变为遗址")
	view.move_step(Vector2(400, 0))
	check(view.foot.x < 950, "断崖深处信号不可达")
	walk(view, view.safety_position())
	await key(KEY_ESCAPE)
	check(sea.records_button.text.contains("待归档") and sea.dive_summary_label.text.contains("待归档"), "返航突出核心归档")
	sea.result_label.text = "设施生产消息，不属于探索记录"
	sea._open_dive(true)
	view = sea.dive_view
	check(root.gui_get_focus_owner() == view.clues_tab, "记录打开聚焦线索页签")
	check(view.feedback.text.contains("待归档") and not view.feedback.text.contains("设施生产"), "记录概况独立于海上消息")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == view.species_tab, "真实Tab在记录内导航生态页签")
	await key(KEY_TAB, true)
	check(root.gui_get_focus_owner() == view.clues_tab, "真实ShiftTab返回线索页签")
	for code in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
		await key(code)
		check(root.gui_get_focus_owner() in [view.clues_tab, view.species_tab, view.archive_button, view.close_button], "记录方向导航不穿透 " + str(code))
	view.archive_button.grab_focus()
	await key(KEY_M)
	check(not sea.exploration_tools.is_open(), "记录中地图快捷键不穿透")
	await key(KEY_ENTER)
	check(sea.dive_archived and view.archive_button.disabled, "真实Enter归档")
	await key(KEY_SPACE)
	check(not is_instance_valid(sea.dive_layer), "真实空格确认关闭")
	sea.dive_archived = false
	sea.core_reward_claimed = false
	sea.dive_workshop_unlocked = false
	check(sea._cache_round(), "隔离夹具恢复待归档以验证空格")
	sea._open_dive(true)
	sea.dive_view.archive_button.grab_focus()
	await key(KEY_SPACE)
	check(sea.dive_archived, "真实空格归档")
	var archived: Dictionary = sea._round_state()
	sea.dive_view.archive_button.pressed.emit()
	check(sea._round_state() == archived, "重复归档无奖励")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(game.SEA_SAVE)).version) == 11, "写入v11")
	game.load_sea_save()
	check(game.water_activity_state.dive_archived, "v8重读保留归档")
	for field in ["dive_shoal", "dive_sonar", "dive_core", "dive_archived"]:
		var invalid: Dictionary = archived.duplicate(true)
		invalid[field] = 1
		check(game._read_sea_text(JSON.stringify({"version": 5, "state": invalid})).is_empty(), "拒绝非布尔 " + field)
	for field in ["dive_shoal", "dive_sonar", "dive_core"]:
		var invalid: Dictionary = archived.duplicate(true)
		invalid[field] = false
		check(game._read_sea_text(JSON.stringify({"version": 5, "state": invalid})).is_empty(), "拒绝破坏前置 " + field)
	sea._close_dive()
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.enter("trench")
	view.foot = Vector2(875, 410)
	await key(KEY_E)
	check(view.message.contains("已归档") and not view.message.contains("请返航"), "已归档核心只回看不要求再归档")
	view.foot = view.safety_position()
	sea._close_dive()
	await key(KEY_ESCAPE)
	sea._open_dive(true)
	check(root.gui_get_focus_owner() == sea.dive_view.clues_tab and sea.dive_view.feedback.text.contains("工坊"), "已完成记录聚焦关闭与独立概况")
	sea._close_dive()
	sea._start_round()
	var before: Dictionary = game.water_activity_state.duplicate(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.foot = Vector2(650, 390)
	await key(KEY_E)
	check(not sea.dive_shoal and game.water_activity_state == before and view.message.contains("失败"), "写失败回滚线索及内存")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	view.foot = view.safety_position()
	await key(KEY_ESCAPE)
	sea.dive_shoal = true
	sea.dive_sonar = true
	sea.dive_core = true
	check(sea._cache_round(), "准备隔离归档失败夹具")
	before = game.water_activity_state.duplicate(true)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	sea._open_dive(true)
	sea.dive_view.archive_button.grab_focus()
	await key(KEY_ENTER)
	check(not sea.dive_archived and game.water_activity_state == before and sea.dive_view.feedback.text.contains("失败"), "真实Enter归档失败回滚且记录明确提示")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE)
	check(sea.feedback_scroll.get_rect().position.y >= sea.records_button.get_rect().end.y and not sea.goal_label.get_rect().intersects(sea.records_button.get_rect()), "结果与目标布局不重叠按钮")
	sea.exploration_tools.open_map()
	sea._open_dive()
	check(not is_instance_valid(sea.dive_layer), "地图打开不能下潜")
	sea.exploration_tools.atlas.close()
	sea._open_dive()
	sea._start_round()
	check(not is_instance_valid(sea.dive_layer) and not sea.dive_core, "重开清理overlay及进度")
	await v2_checks()
	await workshop_checks()
	await settlement_checks()
	await pending_return_checks()
	await chest_checks()
	await stock_rollback_checks()
	await technology_checks()
	await species_checks()
	await additions_checks()
	sea._start_round()
	check(sea._cache_round(), "专项退出恢复新局供经营回归使用")
	sea.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("UNDERWATER RESULT: ", checks, " checks, ", failures, " failed")
	quit(1 if failures else 0)
