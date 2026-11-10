extends SceneTree
# Memory-only fixtures. Run through tests/underwater.tests.ps1, never the player project.
const ResultPanel = preload("res://scripts/scenes/public_project_result_panel.gd")
var checks: int = 0
var failures: int = 0
var panel: PanelContainer
var stage: Control
var sessions: Dictionary = {}
var intents: Array = []
var late_request: Dictionary = {}
var fixtures: Array[Dictionary] = []
var selector: OptionButton
var preview_note: Label
var active_id: String = ""

# Compile after autoload initialization, without running the sea's _ready/save paths.
func memory_host_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends \"res://scripts/scenes/water_activity.gd\"\nfunc _ready() -> void:\n\tmodel = HeroWalkScript.new()\n\tadd_child(model)\n\tpublic_project_result_button = Button.new()\n\tadd_child(public_project_result_button)\n\tpublic_project_result_button.hide()\nfunc _process(_delta: float) -> void: pass\nfunc _draw() -> void: pass\nfunc _input(_event: InputEvent) -> void: pass\nfunc _unhandled_input(_event: InputEvent) -> void: pass\nfunc _notification(_what: int) -> void: pass\nfunc _exit_tree() -> void: pass\n"
	check(script.reload() == OK, "内存宿主适配脚本编译")
	return script

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func fixture(d: String = "completed", b: String = "not_applicable", p: String = "not_applicable", id: String = "example", revision: int = 1) -> Dictionary:
	var actual: Variant = 1 if d == "completed" else (0 if d == "ineffective" else null)
	var after: Variant = 999998 - int(actual) if actual != null else null
	var bag_actual: Variant = 3 if b == "completed" else (0 if b == "ineffective" else null)
	var bag_after: Variant = 1000000 if b == "completed" else (999997 if b == "ineffective" else null)
	var actions: Dictionary = {}
	for action: String in ResultPanel.ACTION_LABELS:
		if action != "processing": actions[action] = true
	return {
		"operation_id": id, "revision": revision, "purpose": "production" if p != "not_applicable" else ("bag" if b != "not_applicable" else "donation"),
		"donation": {"status": d, "rows": [{"id": "wood", "name": "船料", "requested": 1, "before": 999998, "actual": actual, "after": after}]},
		"bag": {"status": b, "bag_id": "bag-1", "operation_id": "deposit-1", "core": null,
			"rows": [] if b == "not_applicable" else [{"id": "wood", "name": "船料", "amount": 3, "actual": bag_actual, "after": bag_after}],
			"deficits": [{"id": "wood", "name": "船料", "amount": 3}] if b == "capacity_short" else []},
		"production": {"status": p, "claim_id": "claim-1", "claimable": 2 if p in ["awaiting_claim", "space_short"] else null,
			"space_needed": 3 if p == "space_short" else null, "progress": "12 / 20" if p in ["working", "resumed"] else null,
			"reasons": ["dispatch_off", "region_unavailable", "configuration_error", "其他真实原因"] if p == "blocked" else []},
		"latest_balances": {"wood": 1000000 if b == "completed" else null}, "available_actions": actions
	}

func valid_combination(d: String, b: String, p: String) -> bool:
	if b == "waiting_donation" and d == "completed": return false
	if d != "completed" and b not in ["not_applicable", "waiting_donation"]: return false
	if p == "waiting_bag" and d == "completed" and b in ["not_applicable", "completed"]: return false
	if p not in ["not_applicable", "waiting_bag"] and (d != "completed" or b not in ["not_applicable", "completed"]): return false
	return true

func expected_action(d: String, b: String, p: String) -> String:
	if d != "completed": return {"processing": "processing", "uncertain": "check_donation", "ineffective": "recheck_edit"}[d]
	if b not in ["not_applicable", "completed"]:
		return {"waiting_donation": "processing", "processing": "processing", "uncertain": "check_bag", "ineffective": "retry_bag", "capacity_short": "continue_space"}[b]
	return {"not_applicable": "return_base", "waiting_bag": "processing", "awaiting_claim": "claim", "claim_uncertain": "check_claim", "space_short": "claim", "working": "return_base", "resumed": "return_base", "blocked": "dispatch"}[p]

func new_panel(data: Dictionary) -> PanelContainer:
	var result: PanelContainer = ResultPanel.new()
	stage.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.set_snapshot(data, true)
	return result

func click(target: PanelContainer) -> void:
	target.main_button.button_down.emit()
	target.main_button.pressed.emit()
	target.main_button.button_up.emit()

func on_intent(operation: String, action: String, request: String, revision: int) -> void:
	late_request = {"operation_id": operation, "action_id": action, "request_id": request, "revision": revision}
	intents.append(late_request.duplicate())
	if is_instance_valid(preview_note): preview_note.text = "仅示例意图：" + action + "；点击反馈按钮手动结束。"

func open_memory(data: Dictionary) -> void:
	if is_instance_valid(panel):
		sessions[active_id] = panel.export_session()
		stage.remove_child(panel)
		panel.free()
	active_id = data.operation_id
	panel = ResultPanel.new()
	stage.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sessions.has(active_id): panel.import_session(sessions[active_id])
	else: panel.set_snapshot(data, true)
	panel.action_requested.connect(on_intent)
	panel.close_requested.connect(func(_id: String) -> void:
		sessions[active_id] = panel.export_session()
		panel.hide())
	panel.focus_initial()

func matrix_tests() -> void:
	for d: String in ResultPanel.DONATION_STATES:
		for b: String in ResultPanel.BAG_STATES:
			for p: String in ResultPanel.PRODUCTION_STATES:
				var data: Dictionary = fixture(d, b, p, "%s-%s-%s" % [d, b, p])
				var target: PanelContainer = ResultPanel.new()
				stage.add_child(target)
				var valid: bool = valid_combination(d, b, p)
				check(target.set_snapshot(data, true) == valid, "组合校验 " + data.operation_id)
				if valid:
					check(target.main_action == expected_action(d, b, p), "主按钮 " + data.operation_id)
					check(target._return_button.visible == (target.main_action != "return_base"), "不重复返回 " + data.operation_id)
					fixtures.append(data)
				else:
					check(target.main_action == "return_base" and target.summary_label.text.contains("状态数据异常"), "矛盾组合仅退出")
				target.free()
	for reasons: Array in [["region_unavailable", "configuration_error"], ["configuration_error"], ["自定义原因"]]:
		var data: Dictionary = fixture("completed", "not_applicable", "blocked")
		data.production.reasons = reasons
		var target: PanelContainer = new_panel(data)
		check(target.main_action == ("region" if "region_unavailable" in reasons else "details"), "阻塞原因优先级")
		var last_reason: String = {"configuration_error": "配置异常", "region_unavailable": "区域不可用"}.get(reasons[-1], reasons[-1])
		check(target._cards.production.deficits.text.contains(last_reason), "保留全部阻塞原因")
		target.free()
	var no_claim: Dictionary = fixture("completed", "not_applicable", "space_short")
	no_claim.production.claimable = 0
	var target: PanelContainer = new_panel(no_claim)
	check(target.main_action == "continue_space", "无可领额度仅请求新草稿")
	target.free()

func invalid_tests() -> void:
	var cases: Array[Dictionary] = []
	for key: String in ["operation_id", "revision", "purpose", "donation", "bag", "production", "latest_balances", "available_actions"]:
		var missing: Dictionary = fixture()
		missing.erase(key)
		cases.append(missing)
	for key: String in ["donation", "bag", "production"]:
		var bad: Dictionary = fixture()
		bad[key].status = "unknown"
		cases.append(bad)
	for value: Variant in [-1, true, 1.5, "1", null]:
		var bad: Dictionary = fixture()
		bad.donation.rows[0].actual = value
		cases.append(bad)
	var bad: Dictionary = fixture()
	bad.donation.rows[0].after = 7
	cases.append(bad)
	bad = fixture()
	bad.donation.rows.append(bad.donation.rows[0].duplicate())
	cases.append(bad)
	bad = fixture("completed", "completed")
	bad.bag.rows[0].actual = null
	cases.append(bad)
	bad = fixture("completed", "capacity_short")
	bad.bag.deficits = []
	cases.append(bad)
	bad = fixture("completed", "not_applicable", "awaiting_claim")
	bad.production.claim_id = ""
	cases.append(bad)
	bad = fixture("completed", "not_applicable", "blocked")
	bad.production.reasons = []
	cases.append(bad)
	bad = fixture()
	bad.available_actions.check_bag = 3
	cases.append(bad)
	for state: String in ["working", "resumed"]:
		for progress: Variant in [null, "", "   "]:
			bad = fixture("completed", "not_applicable", state)
			bad.production.progress = progress
			cases.append(bad)
	bad = fixture("completed", "not_applicable", "working")
	bad.purpose = "donation"
	cases.append(bad)
	for amount: int in [0, -1]:
		bad = fixture("completed", "capacity_short")
		bad.bag.deficits[0].amount = amount
		cases.append(bad)
	# Keep arithmetic internally consistent so these specifically reject partial completion.
	bad = fixture()
	bad.donation.rows[0].requested = 2
	cases.append(bad)
	bad = fixture("completed", "completed")
	bad.bag.rows[0].actual = 2
	bad.bag.rows[0].after = 999999
	cases.append(bad)
	for index: int in range(cases.size()):
		var target: PanelContainer = ResultPanel.new()
		stage.add_child(target)
		check(not target.set_snapshot(cases[index], true) and target.main_action == "return_base", "错误输入%d仅退出" % index)
		target.free()
	var unavailable: Dictionary = fixture("uncertain")
	unavailable.available_actions = {}
	var target: PanelContainer = new_panel(unavailable)
	check(target.main_button.disabled and target._action_note.text.contains("功能待接入"), "未接入不模拟业务")
	unavailable.revision = 2
	unavailable.available_actions.check_donation = "业务暂不可用"
	target.set_snapshot(unavailable)
	check(target.main_button.disabled and target._action_note.text == "业务暂不可用", "保留外部禁用原因")
	target.free()

func state_tests() -> void:
	var target: PanelContainer = new_panel(fixture("completed", "uncertain"))
	target._toggle("donation")
	target._toggle("bag")
	var text: String = target._rows.donation.wood.text
	check(text.contains("999,998") and text.contains("999,997") and text.contains("实际投出：1"), "999998投1历史999997")
	check(target._rows.bag.wood.text.contains("袋内数量：3") and target._rows.bag.wood.text.contains("袋结算后：待确认"), "袋3未确认绝不提前加余额")
	var next: Dictionary = fixture("completed", "completed", "not_applicable", "example", 2)
	check(target.set_snapshot(next), "匹配袋完成可更新")
	check(target._rows.bag.wood.text.contains("1,000,000") and target._rows.donation.wood.text.contains("投料后：999,997"), "1000000不覆盖历史")
	check(not target.set_snapshot(fixture("completed", "uncertain")) and target.snapshot.revision == 2, "旧版本忽略")
	check(not target.set_snapshot(fixture("completed", "completed", "not_applicable", "other", 99)) and target.snapshot.operation_id == "example", "错笔不能覆盖")
	for field: String in ["before", "requested", "actual", "after", "name"]:
		var changed: Dictionary = next.duplicate(true)
		changed.revision = 3
		changed.donation.rows[0][field] = "改名" if field == "name" else 0
		check(not target.set_snapshot(changed) and target.snapshot == next, "同笔历史保护 " + field)
	var changed: Dictionary = next.duplicate(true)
	changed.revision = 3
	changed.bag.operation_id = "other-deposit"
	check(not target.set_snapshot(changed), "同笔不能替换袋入库身份")
	target.free()
	open_memory(fixture("uncertain", "not_applicable", "not_applicable", "session-a"))
	var count: int = intents.size()
	panel._toggle("donation")
	check(intents.size() == count, "展开不发事务")
	click(panel)
	click(panel)
	check(intents.size() == count + 1 and panel.main_button.disabled, "同步锁防重复点击")
	var request: Dictionary = late_request.duplicate()
	check(not panel.finish_action("wrong", request.request_id, "done"), "错笔反馈拒绝")
	check(not panel.finish_action("session-a", "old-request", "done"), "迟到请求不解锁")
	check(not panel.finish_action("session-a", request.request_id, "invalid"), "无效反馈不解锁")
	panel._close()
	open_memory(fixture("uncertain", "not_applicable", "not_applicable", "session-a"))
	check(panel.main_button.disabled and panel._expanded.donation, "关闭重开保留锁及展开")
	open_memory(fixture("uncertain", "not_applicable", "not_applicable", "session-b"))
	check(not panel.finish_action("session-a", request.request_id, "done"), "切会话迟到反馈隔离")
	click(panel)
	check(late_request.request_id != request.request_id, "跨会话请求ID唯一")
	open_memory(fixture("uncertain", "not_applicable", "not_applicable", "session-a"))
	check(panel.main_button.disabled and panel.finish_action("session-a", request.request_id, "inconclusive"), "切回原会话匹配反馈解锁")
	check(panel.snapshot.donation.status == "uncertain" and panel._cards.donation.note.text.contains("暂无结论"), "无结论仅卡片提示不改状态")
	panel.main_button.grab_focus()
	panel._capture_press()
	var completed: Dictionary = fixture("completed", "uncertain", "not_applicable", "session-a", 2)
	panel.set_snapshot(completed)
	count = intents.size()
	panel._activate_main()
	check(intents.size() == count and panel.summary_label.has_focus(), "按下后换义不执行且焦点回摘要")
	click(panel)
	request = late_request.duplicate()
	completed.revision = 3
	completed.bag.status = "processing"
	panel.set_snapshot(completed)
	check(panel.main_button.disabled and panel._lock.request_id == request.request_id, "新快照不移交在途锁")
	check(panel.finish_action("session-a", request.request_id, "done") and panel.snapshot.bag.status == "processing", "反馈不伪造成功")
	check(not panel.finish_action("session-a", request.request_id, "done"), "重复反馈拒绝")

func v2_fixture(status: String = "save_failed", revision: int = 1) -> Dictionary:
	var data: Dictionary = fixture("processing", status, "not_applicable", "v2-bag", revision)
	data.contract_version = 2
	data.purpose = "bag"
	data.donation = {"status": "not_applicable", "rows": []}
	data.bag.independent = true
	data.bag.core = {"id": "core-1", "name": "新核心", "amount": 1}
	return data

func v2_tests() -> void:
	var target: PanelContainer = new_panel(v2_fixture())
	check(target._valid and target.main_action == "retry_bag", "v2无投料独立袋保存失败可重试")
	check(target.pending_task() == "返航袋待处理" and not target._cards.donation.root.visible, "v2无投料不伪造投料待办")
	target._jump_pending()
	check(target._cards.bag.heading.has_focus(), "v2待办定位返航袋")
	check(target.summary_label.text.contains("原袋及核心仍封存") and target._persistence_note.text.contains("随存档恢复"), "v2实际保存及失败提示")
	target.action_requested.connect(on_intent)
	var count: int = intents.size()
	click(target)
	click(target)
	var request: Dictionary = late_request.duplicate()
	check(intents.size() == count + 1 and target.main_button.disabled, "v2重试仍受请求锁保护")
	check(not target.finish_action("other", request.request_id, "done"), "v2错笔反馈不解锁")
	check(target.finish_action("v2-bag", request.request_id, "done") and target.snapshot.bag.status == "save_failed", "v2反馈done不伪造完成")
	for field: String in ["bag_id", "operation_id", "amount", "id", "core", "independent"]:
		var changed: Dictionary = v2_fixture("processing", 2)
		match field:
			"amount": changed.bag.rows[0].amount = 4
			"id": changed.bag.rows[0].id = "copper"
			"core": changed.bag.core.amount = 2
			"independent": changed.bag.independent = false
			_: changed.bag[field] = "other"
		check(not target.set_snapshot(changed) and target.snapshot.revision == 1, "v2同袋冻结 " + field)
	check(target.set_snapshot(v2_fixture("processing", 2)), "v2保存失败不是终态可进入处理中")
	check(target.set_snapshot(v2_fixture("save_failed", 3)), "v2处理中失败仍可重试")
	check(target.set_snapshot(v2_fixture("completed", 4)), "v2重试可完成")
	check(target.pending_task().is_empty() and target.main_action == "return_base", "v2完成无虚构生产待办")
	var latest: Dictionary = v2_fixture("completed", 5)
	latest.latest_balances.wood = 27
	check(target.set_snapshot(latest) and target.snapshot.latest_balances.wood == 27, "v2完成后独立刷新当前余额")
	for field: String in ["status", "core", "rows", "deficits"]:
		var changed: Dictionary = latest.duplicate(true)
		changed.revision = 6
		match field:
			"status": changed.bag.status = "save_failed"
			"core": changed.bag.core.name = "改名"
			"rows": changed.bag.rows[0].after = 42
			"deficits": changed.bag.deficits = [{"id": "wood", "name": "船料", "amount": 1}]
		check(not target.set_snapshot(changed), "v2完成历史冻结 " + field)
	target.free()
	var invalid: Array[Dictionary] = []
	var bad: Dictionary = v2_fixture()
	bad.erase("contract_version")
	invalid.append(bad)
	bad = v2_fixture()
	bad.bag.independent = false
	invalid.append(bad)
	bad = v2_fixture()
	bad.bag.independent = "true"
	invalid.append(bad)
	bad = v2_fixture()
	bad.donation.rows = fixture().donation.rows
	invalid.append(bad)
	bad = v2_fixture()
	bad.bag.rows[0].amount = null
	invalid.append(bad)
	for version: Variant in [0, 3, true, "2"]:
		bad = v2_fixture()
		bad.contract_version = version
		invalid.append(bad)
	for data: Dictionary in invalid:
		target = new_panel(data)
		check(not target._valid, "v2非法契约或依赖拒绝")
		target.free()
	for state: String in ["capacity_short", "completed", "ineffective"]:
		target = new_panel(v2_fixture(state))
		check(target._valid, "v2独立袋允许真实状态 " + state)
		if state == "ineffective":
			check(not target.set_snapshot(v2_fixture("processing", 2)), "v2原ineffective终态不放松")
		target.free()
	bad = v2_fixture("processing")
	bad.bag.rows = []
	target = new_panel(bad)
	check(target._valid and target._cards.bag.facts.text.contains("新核心"), "v2支持仅核心独立袋")
	target.free()
	bad = fixture("processing", "processing")
	bad.bag.independent = true
	target = new_panel(bad)
	check(not target._valid, "v1独立标记不能放松投料依赖")
	target.free()
	bad = v2_fixture("processing")
	bad.donation = fixture("processing").donation
	target = new_panel(bad)
	check(target._valid, "v2独立袋在投料未完成时允许实际袋状态")
	target.free()
	bad = fixture()
	bad.contract_version = 2
	target = new_panel(bad)
	check(target._valid and target.main_action == "return_base", "v2普通投料窗口无需返航袋")
	target.free()
	target = new_panel(fixture())
	check(target._persistence_note.text.contains("依赖外部接入"), "v1保留预览宿主说明")
	target.free()

func long_fixture(id: String) -> Dictionary:
	var data: Dictionary = fixture("completed", "uncertain", "not_applicable", id)
	for index: int in range(40):
		data.donation.rows.append({"id": "resource-%d" % index, "name": "长清单材料 %d" % index, "requested": 1, "before": 20, "actual": 1, "after": 19})
		data.bag.rows.append({"id": "resource-%d" % index, "name": "长清单材料 %d" % index, "amount": 3, "actual": null, "after": null})
	data.bag.rows.append({"id": "pearl", "name": "珍珠", "amount": 2, "actual": null, "after": null})
	return data

func reading_tests() -> void:
	open_memory(long_fixture("long"))
	panel._toggle("donation")
	panel._toggle("bag")
	await process_frame
	await process_frame
	panel.scroll.scroll_vertical = 600
	await process_frame
	var old_scroll: int = panel.scroll.scroll_vertical
	var old_row: Label = panel._rows.donation["resource-4"]
	var update: Dictionary = panel.snapshot.duplicate(true)
	update.revision += 1
	update.latest_balances.wood = 123
	panel.set_snapshot(update)
	await process_frame
	await process_frame
	check(panel._expanded.donation and panel._expanded.bag and panel._rows.donation["resource-4"] == old_row, "局部更新保持展开与控件身份")
	check(abs(panel.scroll.scroll_vertical - old_scroll) <= 2, "更新保持阅读滚动锚点")
	check(panel._rows.bag.pearl.text.contains("稀有") and not panel._cards.bag.facts.text.contains("核心："), "珍珠独立稀有且无核心不虚构")
	panel._close()
	open_memory(update)
	await process_frame
	await process_frame
	check(abs(panel.scroll.scroll_vertical - old_scroll) <= 2, "重开恢复滚动锚点")

func host_tests() -> void:
	var host: Control = memory_host_script().new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(not host.public_project_result_button.visible, "正式宿主无快照不显示演示入口")
	var data: Dictionary = fixture("uncertain", "not_applicable", "not_applicable", "host-a")
	check(host.show_public_project_result(data), "最小宿主打开真实适配窗口")
	var hosted: PanelContainer = host._public_project_panels["host-a"]
	check(hosted.main_button.disabled and hosted._action_note.text.contains("功能待接入"), "宿主无真实处理器禁用动作")
	host._close_public_project_result("host-a")
	check(host.public_project_result_button.visible, "关闭未完成任务保留基地提示")
	host.public_project_action_requested.connect(on_intent)
	var refreshes: Array = []
	host.public_project_refresh_requested.connect(func(id: String, rev: int) -> void: refreshes.append([id, rev]))
	check(host.show_public_project_result(data), "宿主同版本显式重开")
	var count: int = intents.size()
	click(hosted)
	var request: Dictionary = late_request.duplicate()
	host._close_public_project_result("host-a")
	host.show_public_project_result(data)
	check(hosted.main_button.disabled and intents.size() == count + 1 and refreshes.size() == 2, "宿主重开只刷新不重发在途意图")
	var other: Dictionary = fixture("uncertain", "not_applicable", "not_applicable", "host-b")
	check(host.show_public_project_result(other), "宿主显式切换会话")
	check(host.finish_public_project_action("host-a", request.request_id, "inconclusive"), "宿主迟到反馈路由原会话")
	check(host._public_project_operation == "host-b" and host._public_project_panels["host-b"].snapshot.donation.status == "uncertain", "迟到反馈不覆盖当前会话")
	check(not host.finish_public_project_action("host-b", request.request_id, "done"), "跨笔请求反馈拒绝")
	host._close_public_project_result("host-b")
	host.at_salt = true
	check(not host.show_public_project_result(data), "非基地禁止打开")
	host.at_salt = false
	var modal: Window = Window.new()
	host.add_child(modal)
	modal.show()
	check(not host.show_public_project_result(data), "其他模态存在时禁止打开")
	modal.hide()
	modal.free()
	for id: String in ["host-a", "host-b"]:
		var done: Dictionary = fixture("completed", "not_applicable", "not_applicable", id, 2)
		host.update_public_project_result(done)
	check(not host.public_project_result_button.visible, "全部任务确认完成隐藏基地提示")
	host.free()

func toolbar_button(parent: Node, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)

func preview() -> void:
	var shell: VBoxContainer = VBoxContainer.new()
	root.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var marker: Label = Label.new()
	marker.text = "UI预览 · 示例数据 · 未连接业务"
	marker.add_theme_font_size_override("font_size", 18)
	shell.add_child(marker)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 44
	shell.add_child(selector)
	fixtures.append(long_fixture("preview-long"))
	for data: Dictionary in fixtures:
		selector.add_item("%s / %s / %s" % [data.donation.status, data.bag.status, data.production.status])
	selector.set_item_text(fixtures.size() - 1, "长清单 · 珍珠 · 关闭重开与滚动保持")
	selector.item_selected.connect(func(index: int) -> void: open_memory(fixtures[index]))
	var toolbar: HFlowContainer = HFlowContainer.new()
	shell.add_child(toolbar)
	toolbar_button(toolbar, "反馈无结论", func() -> void: feedback("inconclusive"))
	toolbar_button(toolbar, "反馈已收到", func() -> void: feedback("done"))
	toolbar_button(toolbar, "注入迟到反馈", func() -> void:
		var accepted: bool = panel.finish_action("wrong-operation", String(late_request.get("request_id", "late")), "done")
		preview_note.text = "迟到反馈已拒绝：" + str(not accepted))
	toolbar_button(toolbar, "关闭 / 重开", func() -> void:
		if panel.visible: panel._close()
		else: open_memory(fixtures[selector.selected]))
	preview_note = Label.new()
	preview_note.text = "所有数据仅在内存；状态选择不会执行扣料、入库、领取或保存。"
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(preview_note)
	if is_instance_valid(panel): panel.free()
	stage.get_parent().remove_child(stage)
	shell.add_child(stage)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector.select(fixtures.size() - 1)
	open_memory(fixtures[-1])

func feedback(value: String) -> void:
	if not late_request.is_empty():
		var accepted: bool = panel.finish_action(late_request.operation_id, late_request.request_id, value)
		preview_note.text = "示例反馈匹配：" + str(accepted) + "；不改变业务快照。"

func capture_tests() -> void:
	panel._toggle("donation")
	panel._toggle("bag")
	await process_frame
	await process_frame
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(480, 720)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		await process_frame
		await process_frame
		await process_frame
		var rect: Rect2 = panel.get_global_rect()
		check(rect.end.x <= root.size.x + 1 and rect.end.y <= root.size.y + 1, "图形面板不越界 " + str(dimensions))
		check(panel.scroll.get_h_scroll_bar().max_value <= panel.scroll.size.x + 1, "图形无横向溢出 " + str(dimensions))
		check(panel.main_button.get_global_rect().end.y <= root.size.y + 1, "图形固定尾部可见 " + str(dimensions))
		panel.scroll.scroll_vertical = int(panel.scroll.get_v_scroll_bar().max_value)
		await process_frame
		await process_frame
		var last: Label = panel._rows.bag.pearl
		check(last.get_global_rect().end.y <= panel.scroll.get_global_rect().end.y + 2 and last.get_global_rect().position.y >= panel.scroll.get_global_rect().position.y - 2, "图形展开末行不遮挡 " + str(dimensions))
		await RenderingServer.frame_post_draw
		var path: String = "res://result-preview-%dx%d.png" % [dimensions.x, dimensions.y]
		check(root.get_texture().get_image().save_png(path) == OK, "图形截图 " + path)
		print("RESULT: screenshot ", ProjectSettings.globalize_path(path))

func run() -> void:
	# Refuse accidental execution against the formal project even though fixtures do not save.
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		print("FAIL: 必须从隔离项目与独立用户目录运行")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	stage = Control.new()
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	matrix_tests()
	invalid_tests()
	state_tests()
	v2_tests()
	await reading_tests()
	if "--result-panel-only" not in OS.get_cmdline_user_args(): host_tests()
	if DisplayServer.get_name() == "headless":
		print("RESULT: public_project_result checks=", checks, " failures=", failures)
		quit(1 if failures > 0 else 0)
		return
	preview()
	if "--result-capture" in OS.get_cmdline_user_args():
		await capture_tests()
		print("RESULT: public_project_result graphical checks=", checks, " failures=", failures)
		quit(1 if failures > 0 else 0)
	else:
		print("RESULT: memory preview ready; checks=", checks, " failures=", failures)
