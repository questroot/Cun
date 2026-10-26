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
			check(child.dialog_text.contains("珊瑚枝") and child.dialog_text.contains("绳索"), "仓库并列新旧资源")
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
	view.interact()
	stock = sea.node_states.shoal.s1.stock
	sea.dive_layer.queue_free()
	sea.dive_layer = null
	sea.dive_view = null
	await process_frame
	game.load_sea_save()
	check(game.water_activity_state.node_states.shoal.s1.stock == stock, "放弃下潜不回滚库存")
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
	check(view.settlement_text.text.contains("未入库") and not view.settlement_close.visible and root.gui_get_focus_owner() == view.settlement_retry, "失败仅重试且聚焦不丢袋")
	sea._dismiss_dive()
	check(sea.dive_view == view, "失败不可绕过关闭丢袋")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_SPACE, false, true)
	check(view.settlement_saved and view.settlement_panel == panel and sea.resources.coral == 2 and sea.resources.pearl == 1 and view.bag.is_empty(), "空格重试成功更新同一面板准确入库")
	check(view.settlement_text.text.contains("珊瑚枝 × 2") and view.settlement_text.text.contains("深水珍珠 × 1") and view.settlement_text.text.contains("待归档") and not sea.dive_archived, "中文数量核心待归档且不自动领奖")
	sea._close_dive()
	check(sea.resources.coral == 2, "成功重复请求不重复入库")
	view.settlement_records.grab_focus()
	await key(KEY_ENTER, false, true)
	check(sea.dive_view.read_only and root.gui_get_focus_owner() == sea.dive_view.archive_button, "结算记录入口沿既有显式归档路径")
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
	check(sea.equipment.size() == 4 and sea.equipment.wrist == {"id": "wrist", "level": 0}, "四槽默认保留未开放护腕")
	check(sea._build_cost("dive_workshop") == catalog.WORKSHOP_COST and sea._build_reason("dive_workshop").contains("已建成"), "潜水工坊接入既有建造成本与门禁")
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
		if child is AcceptDialog:
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

func run() -> void:
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
	sea._open_dive(true)
	check(root.gui_get_focus_owner() == sea.dive_view.close_button and sea.dive_view.archive_button.disabled, "无核心记录聚焦关闭")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == sea.dive_view.close_button, "不可归档时Tab不穿透浮台")
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
	check(root.gui_get_focus_owner() == view.archive_button, "记录打开聚焦可用归档")
	check(view.feedback.text.contains("待归档") and not view.feedback.text.contains("设施生产"), "记录概况独立于海上消息")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == view.close_button, "真实Tab在记录内导航")
	await key(KEY_TAB, true)
	check(root.gui_get_focus_owner() == view.archive_button, "真实ShiftTab返回归档")
	for code in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
		await key(code)
		check(root.gui_get_focus_owner() in [view.archive_button, view.close_button], "记录方向导航不穿透 " + str(code))
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
	await key(KEY_SPACE)
	check(sea.dive_archived, "真实空格归档")
	var archived: Dictionary = sea._round_state()
	sea.dive_view.archive_button.pressed.emit()
	check(sea._round_state() == archived, "重复归档无奖励")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(game.SEA_SAVE)).version) == 6, "写入v6")
	game.load_sea_save()
	check(game.water_activity_state.dive_archived, "v6重读")
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
	check(root.gui_get_focus_owner() == sea.dive_view.close_button and sea.dive_view.feedback.text.contains("工坊"), "已完成记录聚焦关闭与独立概况")
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
	await key(KEY_ENTER)
	check(not sea.dive_archived and game.water_activity_state == before and sea.dive_view.feedback.text.contains("失败"), "真实Enter归档失败回滚且记录明确提示")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE)
	check(sea.result_label.get_rect().position.y >= sea.records_button.get_rect().end.y and sea.goal_label.get_rect().end.y <= sea.records_button.position.y, "结果与目标布局不重叠按钮")
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
	await chest_checks()
	sea._start_round()
	check(sea._cache_round(), "专项退出恢复新局供经营回归使用")
	sea.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("UNDERWATER RESULT: ", checks, " checks, ", failures, " failed")
	quit(1 if failures else 0)
