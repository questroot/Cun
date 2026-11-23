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
const StationIcons = preload("res://scripts/scenes/sea_station_icons.gd")
const BRANCHES := {"基础研究": ["T0"], "设备与海域": ["T1", "T2", "T4"], "经营能力": ["T3", "T5"], "主动探索": ["T6"]}
const PAGE_NAMES := {"tech": "研究", "device": "设备", "maintenance": "维护", "build": "建造"}
const PAGE_ICONS := {"tech": "research", "device": "machine", "maintenance": "pack", "build": "build"}
var _picked := {"tech": "T0", "device": "运行面板", "maintenance": "普通维护包", "build": "research"}
var _tabs: HBoxContainer
var _index: VBoxContainer
var _scroll: ScrollContainer
var _feedback: Label
var _focus_key := ""
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

func show_facility(id: String) -> void:
	if id not in ["research", "machine"] or not _surface() or host._sea_modal(): return
	var desk := preload("res://scripts/scenes/sea_facility_desk.gd").new()
	host.add_child(desk)
	host.moving = false
	desk.open(self, id)

func open_item(page: String, entry: String) -> void:
	_picked[page] = entry
	show_page(page)

func show_page(page: String = "tech") -> void:
	if not _surface():
		_say("请先返回浮台，再使用科技与设备。")
		return
	if is_instance_valid(host.management) and host.management.visible: host._close_management()
	if not _allowed() or (is_instance_valid(confirmation) and confirmation.visible): return
	_page = page if PAGE_NAMES.has(page) else ("device" if page in ["production", "machine"] else "tech")
	host.moving = false
	if not is_instance_valid(dialog): _make_station()
	_redraw()
	dialog.popup_centered(_station_size())
	_focus("page:" + _page)

func _station_size() -> Vector2i:
	var screen: Vector2i = host.get_window().size.min(Vector2i(host.get_viewport_rect().size))
	return Vector2i(976, 586).min(screen - Vector2i(64, 64)).max(Vector2i(768, 456))

func _make_station() -> void:
	dialog = AcceptDialog.new()
	dialog.name = "TechnologyDialog"
	dialog.title = "浮台港务   /   海事科技工作台"
	dialog.theme = host.theme
	dialog.get_ok_button().text = "返回浮台  Esc"
	host.add_child(dialog)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible and is_instance_valid(host.technology_button): host.technology_button.grab_focus())
	var desk := VBoxContainer.new()
	desk.custom_minimum_size = Vector2(744, 382)
	desk.add_theme_constant_override("separation", 8)
	dialog.add_child(desk)
	_tabs = HBoxContainer.new()
	desk.add_child(_tabs)
	for page in PAGE_NAMES:
		var key: String = page
		var tab := _button(_tabs, PAGE_NAMES[key], func() -> void: _open(key))
		_tag(tab, "page:" + key)
		tab.toggle_mode = true
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	desk.add_child(split)
	var rail := ScrollContainer.new()
	rail.custom_minimum_size.x = 212
	rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.follow_focus = true
	split.add_child(rail)
	_index = _stack(rail)
	_scroll = ScrollContainer.new()
	_scroll.name = "TechnologyScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	split.add_child(_scroll)
	_contents = _stack(_scroll)
	_feedback = _label(desk, "")
	_feedback.max_lines_visible = 2
	_feedback.add_theme_font_size_override("font_size", 15)

func _stack(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	parent.add_child(box)
	return box

func _card(parent: Control, caption: String) -> VBoxContainer:
	var plate := PanelContainer.new()
	parent.add_child(plate)
	var box := _stack(plate)
	_kicker(box, caption)
	return box

func _kicker(parent: Control, text: String) -> void:
	var label := _label(parent, text)
	label.theme_type_variation = &"HarborCaption"
	label.add_theme_font_size_override("font_size", 15)

func _hero(parent: Control, tag: String, title: String, detail: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	parent.add_child(head)
	head.add_child(StationIcons.make(PAGE_ICONS[_page], 54))
	var text := _stack(head)
	_kicker(text, tag)
	var label := _label(text, title)
	label.theme_type_variation = &"HarborHeading"
	label.add_theme_font_size_override("font_size", 25)
	if detail != "": _label(parent, detail)

func _tag(button: Button, key: String) -> void:
	button.set_meta("station_key", key)

func _focus(key: String) -> void:
	for node in dialog.find_children("*", "Button", true, false):
		if node.get_meta("station_key", "") == key and not node.disabled:
			node.grab_focus.call_deferred()
			return
	if key != "page:" + _page: _focus("page:" + _page)

func _open(page: String) -> void:
	_page = page
	_redraw()
	_scroll.scroll_vertical = 0
	_focus("page:" + page)

func _index_item(id: String, text: String) -> void:
	var key := "item:" + id
	var b := _button(_index, text, func() -> void:
		_picked[_page] = id
		_redraw()
		_scroll.scroll_vertical = 0
		_focus(key))
	_tag(b, key)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.set_pressed_no_signal(id == _picked[_page])

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
	_tag(button, "action:" + text)
	button.focus_entered.connect(func() -> void: _focus_key = button.get_meta("station_key"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _action(action: Callable) -> void:
	var origin := _focus_key
	action.call()
	_redraw()
	_focus(origin)

func _redraw() -> void:
	for box in [_index, _contents]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for tab in _tabs.get_children(): tab.set_pressed_no_signal(tab.get_meta("station_key") == "page:" + _page)
	_feedback.text = _message if _message != "" else "Tab 切换控件   ·   Enter 执行   ·   Esc 返回"
	_feedback.tooltip_text = _feedback.text
	var id: String = _picked[_page]
	match _page:
		"tech":
			for branch in BRANCHES:
				_kicker(_index, branch)
				for item in BRANCHES[branch]: _index_item(item, "%s   %s" % [item, TECHS[item].name])
			_tech_card(id, _contents)
		"build":
			_kicker(_index, "专用附属位")
			_index_item("research", "01   浮台研究台")
			_index_item("machine", "02   自动打捞器")
			_build_ui(id)
		"device":
			_kicker(_index, "打捞器控制台")
			for item in ["运行面板", "目标预约", "设备货仓"]: _index_item(item, item)
			_device_ui(id)
		"maintenance":
			_kicker(_index, "补给配方")
			for item in ["普通维护包", "进阶维护包"]: _index_item(item, item)
			_pack_ui(id == "进阶维护包")

func _primary(parent: Control, text: String, action: Callable, disabled: bool = false) -> Button:
	var b := _button(parent, text, action, disabled)
	b.theme_type_variation = &"HarborPrimary"
	return b

func _build_ui(id: String) -> void:
	var lab := id == "research"
	var built: bool = state.research_built if lab else state.machine_built
	var title := "浮台研究台" if lab else "自动打捞器"
	var cost: Dictionary = BUILD_COSTS[id]
	_hero(_contents, "设施建造   /   单座设施", title, "解锁海底材料研究。无需核心或居民。" if lab else "按预约目标生产材料；需先研究 T1 浅海打捞。")
	var bill := _card(_contents, "建造用料   /   一次性")
	_cost_rows(bill, cost)
	_primary(_contents, "已建成" if built else "核对建造费用", func() -> void:
		_confirm("建造确认", title, cost, "设施使用独立附属位，不占原建筑槽。", func() -> bool: return build(id)), built)
	_kicker(_contents, "每种设施限一座，不可拆除或出售。")

func _cost_rows(parent: Control, cost: Dictionary) -> void:
	for item in cost:
		var n := int(cost[item])
		if n <= 0: continue
		var owned := _count(item)
		var label := _label(parent, "%s × %d     /     库存 %d     ·     %s" % [_name(item), n, owned, "余 %d" % (owned - n) if owned >= n else "尚缺 %d" % (n - owned)])
		if owned < n: label.add_theme_color_override("font_color", Color("f7cd85"))

func _track(id: String) -> bool:
	if not _allowed() or not TECHS.has(id): return false
	var before := _snapshot()
	state.tracked = "" if state.tracked == id else id
	return _save(before, "跟踪已更新；未预扣材料。")

func _tech_card(id: String, parent: Control) -> void:
	var tech: Dictionary = TECHS[id]
	var reason := _research_reason(id)
	_hero(parent, "研究档案   /   " + id, tech.name + ("  ·  已完成" if researched(id) else ""), tech.effect)
	var bill := _card(parent, "研究费用   /   自选两件" if id == "T0" else "研究费用")
	if id == "T0" and not researched(id):
		var sum_label := _label(bill, "")
		var update := func() -> void:
			var n := 0
			for value in _selection.values(): n += int(value)
			sum_label.text = "已选 %d / 2 件   ·   不会自动使用珍珠" % n
		update.call()
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		bill.add_child(grid)
		for material in Catalog.ITEMS:
			var item: String = material
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(row)
			var caption := _label(row, "%s · 库存%d" % [_name(item), _count(item)])
			caption.tooltip_text = Catalog.USES[item]
			var spin := _quantity(row, 0, 2, int(_selection.get(item, 0)))
			spin.value_changed.connect(func(value: float) -> void:
				_selection[item] = int(value)
				update.call())
	elif id == "T0": _label(bill, "任意海底材料 × 2")
	else: _cost_rows(bill, tech.cost)
	var info := _card(parent, "办理条件   /   " + ("研究台" if tech.pre == "" else tech.pre + " " + TECHS[tech.pre].name))
	_label(info, reason if reason != "" else "前置条件已满足，确认时扣除材料。")
	var row := HBoxContainer.new()
	parent.add_child(row)
	_primary(row, "核对研究费用", func() -> void: _confirm_research(id), researched(id))
	_button(row, "取消跟踪" if state.tracked == id else "跟踪目标", func() -> void: _action(func() -> bool: return _track(id)))
	if not state.research_built: _button(parent, "前往建造研究台", func() -> void:
		_picked.build = "research"
		_open("build"))
	_kicker(parent, "跟踪：%s（不预扣材料）" % (TECHS[state.tracked].name if state.tracked != "" else "无"))
	var record := _card(parent, "手动发现记录")
	var found := PackedStringArray()
	for region in REGIONS: found.append(REGIONS[region] + ("：已发现" if state.manual[region] else "：待带回"))
	_label(record, "   /   ".join(found))
	_kicker(record, "旧档仅按现存材料补记录；历史材料已用尽时，需再次手动安全带回。")
	if not tech.cost.is_empty():
		var uses := _card(parent, "材料的其他用途")
		for material in tech.cost: _kicker(uses, _name(material) + "：" + Catalog.USES[material])

func _confirm_research(id: String) -> void:
	var cost: Dictionary = _selection.duplicate(true) if id == "T0" else TECHS[id].cost.duplicate(true)
	var condition := _research_reason(id)
	if id == "T0":
		var n := 0
		for value in cost.values(): n += int(value)
		condition += " 本次选料 %d / 2 件，必须正好两件。" % n
	_confirm("研究扣费确认", TECHS[id].name, cost, condition.strip_edges(), func() -> bool: return research(id, cost))

func _confirm(title: String, item: String, cost: Dictionary, condition: String, action: Callable) -> void:
	if is_instance_valid(confirmation): return
	dialog.hide()
	confirmation = ConfirmationDialog.new()
	confirmation.title = title
	confirmation.theme = host.theme
	confirmation.get_ok_button().text = "确认扣料"
	confirmation.get_ok_button().theme_type_variation = &"HarborPrimary"
	confirmation.get_cancel_button().text = "取消，保留选料"
	confirmation.dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(545, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	confirmation.add_child(scroll)
	var body := _stack(scroll)
	_hero(body, "港务签发   /   " + title, item, "核对后再扣料；成功后无法撤销。")
	var bill := _card(body, "本次材料清单")
	_cost_rows(bill, cost)
	if bill.get_child_count() == 1: _label(bill, "尚未选择材料。")
	if condition != "": _label(body, condition)
	_label(body, _equipment_warning(cost))
	host.add_child(confirmation)
	confirmation.confirmed.connect(func() -> void:
		var success: bool = action.call()
		if success: _selection.clear()
		_finish_confirm())
	confirmation.canceled.connect(_finish_confirm)
	confirmation.popup_centered(Vector2i(680, 440))
	confirmation.get_cancel_button().grab_focus()

func _finish_confirm() -> void:
	if is_instance_valid(confirmation):
		confirmation.hide()
		confirmation.queue_free()
	confirmation = null
	_redraw()
	dialog.popup_centered(_station_size())
	_focus(_focus_key)

func _device_ui(id: String) -> void:
	_hero(_contents, "自动打捞器   /   作业调度", id, status_text())
	if id == "运行面板":
		var board := _card(_contents, "当前周期")
		_label(board, "当前：%s     剩余 %.1f 秒" % [_name(state.current) if state.current != "" else "无作业", float(state.remaining)])
		_label(board, "下轮：%s     可用额度 %d / 24     货仓 %d / %d" % [_name(state.target), int(state.credits), _cargo_count(), capacity()])
		if not state.machine_built:
			_primary(_contents, "前往建造打捞器", func() -> void:
				_picked.build = "machine"
				_open("build"))
		else:
			_primary(_contents, "启动 / 继续 / 重试结算", func() -> void: _action(resume))
			_button(_contents, "主动暂停（保留本周期投入）", func() -> void: _action(pause), state.paused)
		_button(_contents, "前往维护补给", func() -> void: _open("maintenance"))
		_kicker(_contents, "每周期耗 1 额度。关闭面板、聚焦浮台才计时；下潜或离线不补算。")
	elif id == "目标预约":
		var board := _card(_contents, "下轮预约   /   " + _name(state.target))
		_label(board, "仅更改下一轮；本周期投入与进度不变。不生产珍珠或核心，不消耗手动宝箱存量。")
		for item in TARGETS:
			var target: String = item
			var permit: String = TARGETS[target][0]
			_button(_contents, "%s   ·   %.0f 秒/件   ·   %s" % [_name(target), TARGETS[target][1], "已许可" if researched(permit) else "需 " + permit], func() -> void: _action(func() -> bool: return select_target(target)), not state.machine_built or not researched(permit))
	else:
		var cargo := _card(_contents, "设备货仓   /   %d 格已用，共 %d 格" % [_cargo_count(), capacity()])
		for item in state.cargo: _label(cargo, "%s   × %d" % [_name(item), int(state.cargo[item])])
		_primary(_contents, "领取全部货仓", func() -> void: _action(claim), _cargo_count() == 0)
		_cargo_route()

func _cargo_route() -> void:
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

func _quantity(parent: Control, lo: int, hi: int, initial: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = 1
	spin.value = initial
	spin.custom_minimum_size = Vector2(92, 38)
	parent.add_child(spin)
	return spin

func _pack_ui(advanced: bool) -> void:
	var key := "advanced" if advanced else "normal"
	var permit := "T5" if advanced else "T1"
	var quota := 12 if advanced else 6
	var title := "进阶维护包" if advanced else "普通维护包"
	_hero(_contents, "维护补给   /   " + permit + (" 已许可" if researched(permit) else " 待解锁"), title, "每包含 %d 次额度   ·   现存 %d 包   ·   设备额度 %d / 24" % [quota, int(state.packs[key]), int(state.credits)])
	var cost := {"shell": 1, "rope": 1}
	if advanced: cost.algae = 1
	var make := _card(_contents, "01   制作维护包")
	var bill := _stack(make)
	_cost_rows(bill, cost)
	var maker := HBoxContainer.new()
	make.add_child(maker)
	var count := _quantity(maker, 1, Catalog.RESOURCE_LIMIT, 1)
	count.value_changed.connect(func(value: float) -> void:
		for child in bill.get_children():
			bill.remove_child(child)
			child.queue_free()
		var batch := {}
		for item in cost: batch[item] = int(value) * int(cost[item])
		_cost_rows(bill, batch))
	_primary(maker, "制作所选数量", func() -> void:
		var n := int(count.value)
		_action(func() -> bool: return craft_pack(advanced, n)), not researched(permit))
	var fuel := _card(_contents, "02   整包投入设备")
	var fuel_note := _label(fuel, "增加 %d 次额度   ·   超出上限 24 时整批不投入" % quota)
	var filler := HBoxContainer.new()
	fuel.add_child(filler)
	var fill := _quantity(filler, 1, 2 if advanced else 4, 1)
	fill.value_changed.connect(func(value: float) -> void: fuel_note.text = "增加 %d 次额度   ·   超出上限 24 时整批不投入" % (quota * int(value)))
	_primary(filler, "投入所选数量", func() -> void:
		var n := int(fill.value)
		_action(func() -> bool: return refuel(advanced, n)), not state.machine_built)
	_kicker(_contents, "早期可在经营 → 生产用纤维搓绳；工坊成熟后自动供应。普通包补贝群后净余 5 件，进阶包补贝群与藻后净余 10 件，另耗绳索 1。包库存上限 1000000。")
