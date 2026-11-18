extends RefCounted

const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const TECHS := {
	"T0": {"name": "基础解析", "pre": "", "cost": {}, "effect": "解锁三个科技分支；任意海底材料共2件，由你选料。"},
	"T1": {"name": "浅海打捞", "pre": "T0", "cost": {"coral": 1, "shell": 1}, "effect": "解锁单台打捞器、浅滩作业与普通维护包。"},
	"T2": {"name": "沉船机械臂", "pre": "T1", "cost": {"timber": 2, "copper": 1}, "effect": "解锁船料或铜件作业，45秒/件。", "region": "wreck"},
	"T3": {"name": "缓冲货仓", "pre": "T1", "cost": {"timber": 2, "coral": 2}, "effect": "设备货仓8→16件，不改变潜水网袋。"},
	"T4": {"name": "海沟照明", "pre": "T2", "cost": {"algae": 2, "pearl": 1}, "effect": "解锁发光藻作业，60秒/件；不产珍珠。", "region": "trench"},
	"T5": {"name": "节能传动", "pre": "T2", "cost": {"copper": 2, "algae": 1}, "effect": "解锁进阶维护包，12次额度/包；不缩短周期。"},
	"T6": {"name": "回声辅助", "pre": "T0", "cost": {"copper": 2, "pearl": 1}, "effect": "手动精良箱3→2秒、稀有箱6→4秒；不改掉落、氧气与恢复。"}
}
# 仅有效海面时间：普通包浅滩3分钟/沉船4.5分钟，保留手动打捞的爆发收益。
const TARGETS := {"coral": ["T1", 30.0], "shell": ["T1", 30.0], "timber": ["T2", 45.0], "copper": ["T2", 45.0], "algae": ["T4", 60.0]}
const BUILD_COSTS := {"research": {"wood": 2, "scrap": 2}, "machine": {"wood": 3, "scrap": 2, "rope": 1, "coral": 1}}
const REGIONS := {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "深水海沟"}

var host
var state: Dictionary = defaults()
var dialog: AcceptDialog
var confirmation: ConfirmationDialog
var _contents: VBoxContainer
var _page := "tech"
var _selection: Dictionary = {}
var _expanded := {"设备与海域": true, "经营能力": true, "主动探索": true}
var _message := ""
var _settlement_failed := false

static func defaults() -> Dictionary:
	return {
		"research_built": false, "machine_built": false,
		"researched": {"T0": false, "T1": false, "T2": false, "T3": false, "T4": false, "T5": false, "T6": false},
		"manual": {"shoal": false, "wreck": false, "trench": false},
		"packs": {"normal": 0, "advanced": 0}, "credits": 0,
		"cargo": {"coral": 0, "shell": 0, "timber": 0, "copper": 0, "algae": 0},
		"paused": true, "target": "coral", "current": "", "remaining": 0.0, "tracked": ""
	}

static func migrate(resources: Dictionary) -> Dictionary:
	var result := defaults()
	for region in Catalog.POOLS:
		for id in Catalog.POOLS[region]:
			if Catalog.integer(resources.get(id, 0), Catalog.RESOURCE_LIMIT) and resources.get(id, 0) > 0:
				result.manual[region] = true
	return result

static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

static func migrate_v7(s: Variant) -> Dictionary:
	# 先按v7上限严格验证，再按比例保留已经完成的进度；不退额度、不重发货。
	if not valid(s, true): return {}
	var result: Dictionary = s.duplicate(true)
	if result.current != "": result.remaining = float(result.remaining) * 0.5
	return result

static func valid(s: Variant, legacy_v7: bool = false) -> bool:
	if not _keys(s, defaults().keys()): return false
	for key in ["research_built", "machine_built", "paused"]:
		if not s[key] is bool: return false
	if not _keys(s.researched, TECHS.keys()) or not _keys(s.manual, REGIONS.keys()): return false
	for region in REGIONS:
		if not s.manual[region] is bool: return false
	for id in TECHS:
		if not s.researched[id] is bool: return false
		if s.researched[id]:
			if not s.research_built: return false
			var pre: String = TECHS[id].pre
			if pre != "" and not s.researched[pre]: return false
			if TECHS[id].has("region") and not s.manual[TECHS[id].region]: return false
	if s.researched.T0 and not (s.manual.shoal or s.manual.wreck or s.manual.trench): return false
	if s.machine_built and not s.researched.T1: return false
	if not _keys(s.packs, ["normal", "advanced"]) or not _keys(s.cargo, TARGETS.keys()): return false
	for key in s.packs:
		if not Catalog.integer(s.packs[key], Catalog.RESOURCE_LIMIT): return false
	if s.packs.normal > 0 and not s.researched.T1: return false
	if s.packs.advanced > 0 and not s.researched.T5: return false
	if not Catalog.integer(s.credits, 24): return false
	if not s.target is String or not TARGETS.has(s.target): return false
	if not s.current is String or (s.current != "" and not TARGETS.has(s.current)): return false
	if not s.tracked is String or (s.tracked != "" and not TECHS.has(s.tracked)): return false
	if not (s.remaining is float or s.remaining is int) or not is_finite(float(s.remaining)) or s.remaining < 0: return false
	var total := 0
	for id in TARGETS:
		if not Catalog.integer(s.cargo[id], 16): return false
		if s.cargo[id] > 0 and not s.researched[TARGETS[id][0]]: return false
		total += int(s.cargo[id])
	var cap := 16 if s.researched.T3 else 8
	if total > cap: return false
	if not s.machine_built:
		if total > 0 or s.credits > 0 or s.current != "" or s.remaining != 0 or not s.paused or s.target != "coral": return false
	elif not s.researched[TARGETS[s.target][0]]: return false
	if s.current == "":
		if s.remaining != 0: return false
	else:
		if not s.machine_built or not s.researched[TARGETS[s.current][0]]: return false
		if s.remaining > TARGETS[s.current][1] * (2.0 if legacy_v7 else 1.0) or total >= cap: return false
	return true

func researched(id: String) -> bool:
	return state.researched.get(id, false)

func record_manual(items: Array) -> void:
	for region in Catalog.POOLS:
		for id in items:
			if id in Catalog.POOLS[region]: state.manual[region] = true

func capacity() -> int:
	return 16 if researched("T3") else 8

func _cargo_count() -> int:
	var total := 0
	for n in state.cargo.values(): total += int(n)
	return total

func _surface() -> bool:
	return is_instance_valid(host) and not host.at_salt and not host.at_wreck and not host.sailing and not is_instance_valid(host.dive_layer)

func _allowed() -> bool:
	if not _surface(): return false
	if is_instance_valid(host.exploration_tools) and host.exploration_tools.is_open(): return false
	for child in host.get_children():
		if child is Window and child.visible and child != dialog and child != confirmation: return false
	return true

func _say(text: String) -> void:
	_message = text.left(300)
	if is_instance_valid(host) and is_instance_valid(host.result_label): host.result_label.text = _message

func _snapshot() -> Dictionary:
	return {"round": host._round_state().duplicate(true), "technology": state.duplicate(true)}

func _save(before: Dictionary, success: String) -> bool:
	_say(success)
	if not host._cache_round():
		var error: String = host.result_label.text
		host._restore_round(before.round)
		state = before.technology.duplicate(true)
		_say("科技操作保存失败，已恢复操作前状态；可重试。" + error)
		return false
	_say(success)
	host._refresh_ui()
	return true

func _count(id: String) -> int:
	return int(host.resources[id]) if Catalog.ITEMS.has(id) else int(host.get(id))

func _name(id: String) -> String:
	return Catalog.ITEMS[id][0] if Catalog.ITEMS.has(id) else {"wood": "木料", "scrap": "废料", "fiber": "纤维", "rope": "绳索"}.get(id, id)

func _missing(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in cost:
		if _count(id) < int(cost[id]): parts.append("%s%d" % [_name(id), int(cost[id]) - _count(id)])
	return "还缺：" + "、".join(parts) if not parts.is_empty() else ""

func _spend(cost: Dictionary) -> void:
	for id in cost:
		if Catalog.ITEMS.has(id): host.resources[id] = int(host.resources[id]) - int(cost[id])
		else: host.set(id, _count(id) - int(cost[id]))

func _research_reason(id: String) -> String:
	if not state.research_built: return "先建研究台；不需要核心或居民。"
	if researched(id): return "已研究，不可重复购买。"
	var tech: Dictionary = TECHS[id]
	if tech.pre != "" and not researched(tech.pre): return "前置未完成：" + TECHS[tech.pre].name
	if id == "T0" and not (state.manual.shoal or state.manual.wreck or state.manual.trench): return "需手动安全带回任意海底材料；自动领取不计。"
	if tech.has("region") and not state.manual[tech.region]: return "需亲自从%s安全带回任意对应材料；自动产出不计。" % REGIONS[tech.region]
	return ""

func research(id: String, selection: Dictionary = {}) -> bool:
	if not _allowed() or not TECHS.has(id): return false
	var reason := _research_reason(id)
	if reason != "":
		_say(reason)
		return false
	var cost: Dictionary = TECHS[id].cost.duplicate(true)
	if id == "T0":
		var total := 0
		for material in selection:
			if not Catalog.ITEMS.has(material) or not Catalog.integer(selection[material], 2):
				_say("请选择任意海底材料合计2件。")
				return false
			total += int(selection[material])
		if total != 2:
			_say("请选择任意海底材料合计2件，不默认消耗珍珠。")
			return false
		cost = selection.duplicate(true)
	if _missing(cost) != "":
		_say(_missing(cost))
		return false
	var before := _snapshot()
	_spend(cost)
	state.researched[id] = true
	return _save(before, TECHS[id].name + "研究完成。" + TECHS[id].effect)

func build(kind: String) -> bool:
	if not _allowed() or not BUILD_COSTS.has(kind): return false
	var key := "research_built" if kind == "research" else "machine_built"
	if state[key]:
		_say("该设施已建造，上限一座。")
		return false
	if kind == "machine" and not researched("T1"):
		_say("先研究浅海打捞T1。")
		return false
	var cost: Dictionary = BUILD_COSTS[kind]
	if _missing(cost) != "":
		_say(_missing(cost))
		return false
	var before := _snapshot()
	_spend(cost)
	state[key] = true
	return _save(before, ("研究台" if kind == "research" else "打捞器") + "已建成，使用专用附属位，不占旧建筑槽。")

func craft_pack(advanced: bool, count: int = 1) -> bool:
	if not _allowed() or count < 1 or count > Catalog.RESOURCE_LIMIT: return false
	var key := "advanced" if advanced else "normal"
	if not researched("T5" if advanced else "T1"):
		_say("维护包配方尚未解锁。")
		return false
	if int(state.packs[key]) + count > Catalog.RESOURCE_LIMIT:
		_say("维护包库存上限1000000，整批未制作。")
		return false
	var cost := {"shell": count, "rope": count}
	if advanced: cost.algae = count
	if _missing(cost) != "":
		_say(_missing(cost))
		return false
	var before := _snapshot()
	_spend(cost)
	state.packs[key] = int(state.packs[key]) + count
	return _save(before, "已制作%s维护包%d包。" % ["进阶" if advanced else "普通", count])

func _start() -> void:
	if state.paused or state.current != "" or not state.machine_built: return
	if _cargo_count() >= capacity() or int(state.credits) < 1: return
	if not researched(TARGETS[state.target][0]): return
	state.credits = int(state.credits) - 1
	state.current = state.target
	state.remaining = TARGETS[state.current][1]

func refuel(advanced: bool, count: int = 1) -> bool:
	if not _allowed() or not state.machine_built or count < 1 or count > 4: return false
	var key := "advanced" if advanced else "normal"
	var quota := 12 if advanced else 6
	if int(state.packs[key]) < count:
		_say("维护包不足，请先制作。")
		return false
	if int(state.credits) + quota * count > 24:
		_say("整包额度放不下：上限24，未消耗维护包。")
		return false
	var before := _snapshot()
	state.packs[key] = int(state.packs[key]) - count
	state.credits = int(state.credits) + quota * count
	_start()
	var saved := _save(before, "投入%d包，增加%d次额度；主动暂停时须手动继续。" % [count, quota * count])
	if saved and not (state.current != "" and float(state.remaining) <= 0): _settlement_failed = false
	return saved

func select_target(id: String) -> bool:
	if not _allowed() or not state.machine_built or not TARGETS.has(id): return false
	if not researched(TARGETS[id][0]):
		_say("目标作业许可尚未研究。")
		return false
	var before := _snapshot()
	state.target = id
	return _save(before, "已预约" + _name(id) + "；当前已投入周期的目标、进度不变。")

func pause() -> bool:
	if not is_instance_valid(host): return false
	if state.paused: return true
	var before := _snapshot()
	state.paused = true
	return _save(before, "已暂停；进度与本周期投入保留，不退款。")

func resume() -> bool:
	if not _allowed() or not state.machine_built: return false
	var before := _snapshot()
	state.paused = false
	if state.current != "" and float(state.remaining) <= 0:
		_complete()
	_start()
	_settlement_failed = false
	var saved := _save(before, "已继续。" + status_text())
	_settlement_failed = not saved
	return saved

func _complete() -> void:
	state.cargo[state.current] = int(state.cargo[state.current]) + 1
	state.current = ""
	state.remaining = 0.0

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or not _surface() or state.paused or _settlement_failed: return
	if host._sea_modal(): return
	if DisplayServer.get_name() != "headless" and not host.get_window().has_focus(): return
	if not state.machine_built: return
	if state.current == "":
		if _cargo_count() >= capacity() or int(state.credits) < 1: return
		var before_start := _snapshot()
		_start()
		if not _save(before_start, "新周期已启动，扣1次额度。聚焦海面且无窗口时计时。"):
			_settlement_failed = true
		return
	state.remaining = maxf(0.0, float(state.remaining) - delta)
	if float(state.remaining) > 0: return
	# 完工前的快照保留已耗尽的当前周期；写失败可原样重试，不重复发货。
	var before := _snapshot()
	_complete()
	_start()
	if not _save(before, "本周期产物已入设备货仓。" + status_text()): _settlement_failed = true

func claim() -> bool:
	if not _allowed() or not state.machine_built or _cargo_count() == 0: return false
	for id in state.cargo:
		if _count(id) + int(state.cargo[id]) > Catalog.RESOURCE_LIMIT:
			_say(_name(id) + "仓库达上限，整批未领取；先消耗库存。")
			return false
	var before := _snapshot()
	var amount := _cargo_count()
	for id in state.cargo:
		host.resources[id] = int(host.resources[id]) + int(state.cargo[id])
		state.cargo[id] = 0
	_start()
	var saved := _save(before, "已领取%d件；自动产出不增加手动发现记录。" % amount)
	if saved and not (state.current != "" and float(state.remaining) <= 0): _settlement_failed = false
	return saved

func status_text() -> String:
	if not state.machine_built: return "未建打捞器：研究T1后前往建造。"
	if state.paused or not _surface(): return "已暂停，保留进度；返回浮台后点击继续。"
	if state.current != "" and float(state.remaining) <= 0: return "完工待结算：点击继续/重试，不会重复扣额度或发奖。"
	if _settlement_failed: return "启动保存失败：点击继续/重试。"
	if _cargo_count() >= capacity(): return "满仓，未扣下一轮额度；领取可自动恢复。"
	if state.current == "" and int(state.credits) == 0: return "无额度；投包可自动恢复。"
	return "作业中" if state.current != "" else "待启动"

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in cost: parts.append("%s%d（库存%d，缺%d）" % [_name(id), int(cost[id]), _count(id), maxi(0, int(cost[id]) - _count(id))])
	return " / ".join(parts)

func _equipment_warning(cost: Dictionary) -> String:
	var conflicts := PackedStringArray()
	for slot in Catalog.RECIPES:
		var level: int = int(host.net_expansion) if slot == "net_expansion" else int(host.equipment[slot].level)
		if level >= 2: continue
		var recipe: Dictionary = Catalog.RECIPES[slot][level]
		var can_before := true
		var can_after := true
		for id in recipe:
			if _count(id) < int(recipe[id]): can_before = false
			if _count(id) - int(cost.get(id, 0)) < int(recipe[id]): can_after = false
		if can_before and not can_after: conflicts.append(("网袋扩容" if slot == "net_expansion" else Catalog.EQUIPMENT[slot]) + " L%d" % (level + 1))
	return "警告：本次会使当前材料已足够的装备配方变为不足：" + "、".join(conflicts) + "。仍可继续，不会替你锁料。" if not conflicts.is_empty() else "未影响当前已足料的下一等级装备配方。"

func show_page(page: String = "tech") -> void:
	if not _surface():
		_say("请先返回浮台，再使用科技与设备。")
		return
	if is_instance_valid(host.management) and host.management.visible: host._close_management()
	if not _allowed(): return
	if is_instance_valid(confirmation) and confirmation.visible: return
	_page = page if page in ["tech", "device", "build", "production", "machine"] else "tech"
	if _page in ["production", "machine"]: _page = "device"
	host.moving = false
	if not is_instance_valid(dialog):
		dialog = AcceptDialog.new()
		dialog.name = "TechnologyDialog"
		dialog.title = "浮台 · 科技与打捞设备"
		dialog.get_ok_button().text = "关闭"
		var scroll := ScrollContainer.new()
		scroll.name = "TechnologyScroll"
		scroll.custom_minimum_size = Vector2(760, 470)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		dialog.add_child(scroll)
		_contents = VBoxContainer.new()
		_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_contents.add_theme_constant_override("separation", 12)
		scroll.add_child(_contents)
		host.add_child(dialog)
		# 窗口由宿主持有；关闭只隐藏，避免信号闭包引用已释放窗口。
		dialog.confirmed.connect(dialog.hide)
		dialog.canceled.connect(dialog.hide)
	_redraw()
	dialog.popup_centered(Vector2i(800, 550))

func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = disabled
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _action(action: Callable) -> void:
	action.call()
	_redraw()

func _redraw() -> void:
	if not is_instance_valid(_contents): return
	for child in _contents.get_children():
		_contents.remove_child(child)
		child.queue_free()
	var tabs := HBoxContainer.new()
	_contents.add_child(tabs)
	for pair in [["tech", "科技研究"], ["device", "设备与维护包"], ["build", "专用设施建造"]]:
		var page: String = pair[0]
		_button(tabs, pair[1], func() -> void:
			_page = page
			_redraw(), _page == page)
	if _message != "": _label(_contents, _message)
	_label(_contents, "跟踪目标：" + (TECHS[state.tracked].name if state.tracked != "" else "无") + "（仅标记，不预扣、不锁定材料）")
	if state.tracked != "":
		var tracked: String = state.tracked
		_label(_contents, _research_reason(tracked) + " " + ("任意海底材料共2件" if tracked == "T0" else _cost_text(TECHS[tracked].cost)))
	if _page == "build": _build_ui()
	elif _page == "device": _device_ui()
	else: _tech_ui()

func _build_ui() -> void:
	_label(_contents, "设施各限一座，使用独立附属位，不挤占原建筑槽；不拆除、不出售。")
	for kind in BUILD_COSTS:
		var id: String = kind
		var built: bool = state.research_built if id == "research" else state.machine_built
		_label(_contents, ("研究台：" if id == "research" else "打捞器：") + _cost_text(BUILD_COSTS[id]))
		_button(_contents, "已建成" if built else ("建研究台" if id == "research" else "建打捞器（需T1）"), func() -> void:
			_confirm("建造确认", _cost_text(BUILD_COSTS[id]) + "\n" + _equipment_warning(BUILD_COSTS[id]), func() -> bool: return build(id)), built)

func _track(id: String) -> bool:
	if not _allowed() or not TECHS.has(id): return false
	var before := _snapshot()
	state.tracked = "" if state.tracked == id else id
	return _save(before, "跟踪已更新；未预扣材料。")

func _tech_ui() -> void:
	_label(_contents, "研究台：" + ("已建" if state.research_built else "未建（木2废2，无核心前置）") + "\n旧档仅按现有对应材料补手动区域记录；已花光的历史材料无法追溯，需再次安全带回。")
	var found := PackedStringArray()
	for region in REGIONS: found.append(REGIONS[region] + ("：已手动发现" if state.manual[region] else "：待手动带回"))
	_label(_contents, " / ".join(found))
	if not state.research_built:
		_button(_contents, "前往建造研究台", func() -> void:
			_page = "build"
			_redraw())
	_tech_card("T0", _contents)
	var branches := {"设备与海域": ["T1", "T2", "T4"], "经营能力": ["T3", "T5"], "主动探索": ["T6"]}
	for branch in branches:
		var key: String = branch
		_button(_contents, ("▼ " if _expanded[key] else "▶ ") + key, func() -> void:
			_expanded[key] = not _expanded[key]
			_redraw())
		if _expanded[key]:
			for id in branches[key]: _tech_card(id, _contents)
	_button(_contents, "快捷：前往设施建造", func() -> void:
		_page = "build"
		_redraw())
	_button(_contents, "快捷：查看打捞器与维护包", func() -> void:
		_page = "device"
		_redraw())

func _tech_card(id: String, parent: Control) -> void:
	var tech: Dictionary = TECHS[id]
	_label(parent, "%s · %s%s\n%s\n前置：%s\n%s" % [id, tech.name, " · 已研究" if researched(id) else "", tech.effect, "研究台＋手动安全带回任意材料" if id == "T0" else tech.pre, _research_reason(id)])
	if id == "T0" and not researched(id):
		_label(parent, "任意选2件（初始全为0；不会默认消耗珍珠）：")
		for material in Catalog.ITEMS:
			var item: String = material
			var row := HBoxContainer.new()
			parent.add_child(row)
			_label(row, "%s 库存%d · 装备用途：%s" % [_name(item), _count(item), Catalog.USES[item]])
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = 2
			spin.step = 1
			spin.value = int(_selection.get(item, 0))
			spin.custom_minimum_size = Vector2(100, 42)
			spin.value_changed.connect(func(value: float) -> void: _selection[item] = int(value))
			row.add_child(spin)
	else:
		_label(parent, "费用：" + ("任意2件" if id == "T0" else _cost_text(tech.cost)))
		for material in tech.cost:
			_label(parent, _name(material) + "装备用途：" + Catalog.USES[material])
	_button(parent, "取消跟踪" if state.tracked == id else "跟踪此目标（不预扣）", func() -> void: _action(func() -> bool: return _track(id)))
	_button(parent, "查看扣费确认", func() -> void: _confirm_research(id), researched(id))

func _confirm_research(id: String) -> void:
	var cost: Dictionary = _selection.duplicate(true) if id == "T0" else TECHS[id].cost.duplicate(true)
	var lines := PackedStringArray([TECHS[id].name + "；不可撤销。", _research_reason(id)])
	var total := 0
	for material in cost:
		if int(cost[material]) == 0: continue
		total += int(cost[material])
		lines.append("%s：当前%d / 消耗%d / 剩余%d" % [_name(material), _count(material), int(cost[material]), _count(material) - int(cost[material])])
	if id == "T0": lines.append("本次选料合计%d件，必须正好2件。" % total)
	lines.append(_equipment_warning(cost))
	_confirm("研究扣费确认", "\n".join(lines), func() -> bool: return research(id, cost))

func _confirm(title: String, text: String, action: Callable) -> void:
	if is_instance_valid(confirmation): return
	dialog.hide()
	confirmation = ConfirmationDialog.new()
	confirmation.title = title
	confirmation.get_ok_button().text = "确认扣料"
	confirmation.get_cancel_button().text = "取消，保留选料"
	confirmation.dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(690, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	confirmation.add_child(scroll)
	_label(scroll, text)
	host.add_child(confirmation)
	confirmation.confirmed.connect(func() -> void:
		var success: bool = action.call()
		if success: _selection.clear()
		_finish_confirm())
	confirmation.canceled.connect(_finish_confirm)
	confirmation.popup_centered(Vector2i(730, 420))

func _finish_confirm() -> void:
	if is_instance_valid(confirmation):
		confirmation.hide()
		confirmation.queue_free()
	confirmation = null
	_redraw()
	if is_instance_valid(dialog): dialog.popup_centered(Vector2i(800, 550))

func _device_ui() -> void:
	var cargo := PackedStringArray()
	for id in state.cargo: cargo.append("%s%d" % [_name(id), int(state.cargo[id])])
	_label(_contents, "%s\n当前：%s · 剩余%.1f秒 / 预约：%s\n货仓%d/%d件：%s\n可用额度%d/24（不含当前已投入1次） · 普通包%d / 进阶包%d" % [status_text(), _name(state.current) if state.current != "" else "无", float(state.remaining), _name(state.target), _cargo_count(), capacity(), " / ".join(cargo), int(state.credits), int(state.packs.normal), int(state.packs.advanced)])
	_label(_contents, "仅在线海面经营且无模态时推进；下潜、后台、关闭不补算。主动暂停须手动继续；无额度/满仓不扣下一轮。目标选择只预约，当前周期不变。不产珍珠/核心，不消耗海底箱存量。")
	if not state.machine_built:
		_label(_contents, "打捞器费用：" + _cost_text(BUILD_COSTS.machine))
		_button(_contents, "前往建造打捞器", func() -> void:
			_page = "build"
			_redraw())
	for id in TARGETS:
		var target: String = id
		_button(_contents, "预约%s · %.0f秒/件 · %s" % [_name(target), TARGETS[target][1], "已许可" if researched(TARGETS[target][0]) else "需" + TARGETS[target][0]], func() -> void: _action(func() -> bool: return select_target(target)), not state.machine_built or not researched(TARGETS[target][0]))
	_button(_contents, "启动 / 继续 / 重试结算", func() -> void: _action(resume), not state.machine_built)
	_button(_contents, "主动暂停（保留本周期投入）", func() -> void: _action(pause), not state.machine_built or state.paused)
	_button(_contents, "一键领取全部货仓", func() -> void: _action(claim), _cargo_count() == 0)
	var space := Catalog.resources()
	var needs_space := false
	for id in state.cargo:
		space[id] = maxi(0, int(host.resources[id]) + int(state.cargo[id]) - Catalog.RESOURCE_LIMIT)
		if space[id] > 0: needs_space = true
	if host.public_project.pending_bag != null or needs_space:
		var reasons := PackedStringArray()
		for id in space:
			if space[id] > 0: reasons.append("%s%d" % [_name(id), space[id]])
		_label(_contents, "有手动返航袋，请先解决待袋。" if host.public_project.pending_bag != null else "整批领取还需腾出：" + " / ".join(reasons))
		_button(_contents, "前往公共工程腾仓（不自动领取）", func() -> void:
			dialog.hide()
			host.open_public_project_editor("", space))
	_button(_contents, ("▼ " if _expanded.get("维护包", true) else "▶ ") + "维护包批量制作 / 投入", func() -> void:
		_expanded["维护包"] = not _expanded.get("维护包", true)
		_redraw())
	if not _expanded.get("维护包", true): return
	_label(_contents, "维护耗材用绳索：早期可在经营→生产用纤维1搓绳1，工坊自动加工后直接供应。普通包6轮中留1轮补贝群，净余5件；进阶包12轮中留2轮补贝群与藻，净余10件（另耗绳索1）。库存上限1000000；整包换额度，上限24，超出整批拒绝。")
	for advanced in [false, true]:
		var is_advanced: bool = advanced
		var cost := {"shell": 1, "rope": 1}
		if is_advanced: cost.algae = 1
		_label(_contents, ("进阶包（12次，需T5）：" if is_advanced else "普通包（6次，需T1）：") + _cost_text(cost))
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = Catalog.RESOURCE_LIMIT
		quantity.step = 1
		quantity.value = 1
		_contents.add_child(quantity)
		_button(_contents, "制作所选数量" + ("进阶包" if is_advanced else "普通包"), func() -> void:
			var n := int(quantity.value)
			_action(func() -> bool: return craft_pack(is_advanced, n)), not researched("T5" if is_advanced else "T1"))
		var fill := SpinBox.new()
		fill.min_value = 1
		fill.max_value = 2 if is_advanced else 4
		fill.step = 1
		fill.value = 1
		_contents.add_child(fill)
		_button(_contents, "投入所选数量" + ("进阶包" if is_advanced else "普通包"), func() -> void:
			var n := int(fill.value)
			_action(func() -> bool: return refuel(is_advanced, n)), not state.machine_built)
