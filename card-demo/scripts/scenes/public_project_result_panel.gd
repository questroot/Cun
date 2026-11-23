extends PanelContainer
## Read-only result UI. Transactions and persistence belong to the host.

signal action_requested(operation_id: String, action_id: String, request_id: String, revision: int)
signal close_requested(operation_id: String)

const DONATION_STATES: Array[String] = ["processing", "completed", "ineffective", "uncertain"]
const BAG_STATES: Array[String] = ["not_applicable", "waiting_donation", "capacity_short", "processing", "uncertain", "ineffective", "completed"]
const PRODUCTION_STATES: Array[String] = ["not_applicable", "waiting_bag", "awaiting_claim", "claim_uncertain", "space_short", "working", "resumed", "blocked"]
const ACTION_LABELS: Dictionary = {
	"check_donation": "核对投料结果", "recheck_edit": "重新核对", "check_bag": "核对入库结果",
	"retry_bag": "重试入库", "continue_space": "继续腾仓", "check_claim": "核对领取结果",
	"claim": "前往领取", "dispatch": "前往派遣设置", "region": "查看区域", "details": "查看说明",
	"return_base": "返回基地", "processing": "处理中"
}

var snapshot: Dictionary = {}
var main_action: String = "return_base"
var main_button: Button
var title_label: Label
var summary_label: Label
var scroll: ScrollContainer

var _body: VBoxContainer
var _cards: Dictionary = {}
var _rows: Dictionary = {}
var _expanded: Dictionary = {"donation": false, "bag": false}
var _feedback: Dictionary = {}
var _lock: Dictionary = {}
var _request_sequence: int = 0
var _session_nonce: String = ""
var _valid: bool = false
var _updated: bool = false
var _return_button: Button
var _persistence_note: Label
var _action_note: Label
var _jump_button: Button
var _pressed: Dictionary = {}
var _scroll_generation: int = 0
var _restore_scroll: Dictionary = {}

func _init() -> void:
	_session_nonce = "%s-%s" % [str(Time.get_ticks_usec()), str(get_instance_id())]

func _ready() -> void:
	_build()
	_render()
	if not _restore_scroll.is_empty():
		_restore_anchor.call_deferred(_restore_scroll, _scroll_generation)

func _label(parent: Node, value: String = "") -> Label:
	var control: Label = Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 18)
	parent.add_child(control)
	return control

func _button(parent: Node, value: String) -> Button:
	var control: Button = Button.new()
	control.text = value
	control.custom_minimum_size.y = 44
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", 18)
	parent.add_child(control)
	return control

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	layout.add_child(header)
	title_label = _label(header, "公共工程 · 投料结果")
	title_label.remove_theme_font_size_override("font_size")
	title_label.theme_type_variation = &"HarborHeading"
	title_label.focus_mode = Control.FOCUS_ALL
	var close_button: Button = _button(header, "关闭")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_close)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	summary_label = _label(_body)
	summary_label.focus_mode = Control.FOCUS_ALL
	_jump_button = _button(_body, "查看待处理项")
	_jump_button.pressed.connect(_jump_pending)
	for key: String in ["donation", "bag", "production"]:
		var card: VBoxContainer = VBoxContainer.new()
		card.name = key
		_body.add_child(card)
		var heading: Label = _label(card)
		heading.theme_type_variation = &"HarborCaption"
		heading.focus_mode = Control.FOCUS_ALL
		var facts: Label = _label(card)
		var deficits: Label = _label(card)
		var toggle: Button = _button(card, "展开明细")
		toggle.visible = key != "production"
		toggle.pressed.connect(_toggle.bind(key))
		var list: VBoxContainer = VBoxContainer.new()
		card.add_child(list)
		var note: Label = _label(card)
		_cards[key] = {"root": card, "heading": heading, "facts": facts, "deficits": deficits, "toggle": toggle, "list": list, "note": note}
		_rows[key] = {}
	_persistence_note = _label(layout)
	_action_note = _label(layout)
	main_button = _button(layout, "返回基地")
	main_button.theme_type_variation = &"HarborPrimary"
	main_button.button_down.connect(_capture_press)
	main_button.pressed.connect(_activate_main)
	main_button.button_up.connect(_clear_press_later)
	_return_button = _button(layout, "返回基地")
	_return_button.pressed.connect(_close)

func _is_count(value: Variant) -> bool:
	return value == null or (typeof(value) == TYPE_INT and int(value) >= 0)

func _nonempty(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not String(value).strip_edges().is_empty()

func _validate_rows(value: Variant, fields: Array, confirmed: bool) -> bool:
	if not value is Array:
		return false
	var ids: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary:
			return false
		var row: Dictionary = item
		if not _nonempty(row.get("id")) or not _nonempty(row.get("name")) or ids.has(row.id):
			return false
		ids[row.id] = true
		for field: String in fields:
			if not row.has(field) or not _is_count(row[field]) or (confirmed and row[field] == null):
				return false
	return true

func _is_v2(data: Dictionary) -> bool:
	return data.get("contract_version", 1) == 2

func _validate(data: Dictionary) -> bool:
	if typeof(data.get("contract_version", 1)) != TYPE_INT or data.get("contract_version", 1) not in [1, 2]:
		return false
	var v2: bool = _is_v2(data)
	if not _nonempty(data.get("operation_id")) or typeof(data.get("revision")) != TYPE_INT or int(data.revision) < 0:
		return false
	if data.get("purpose") not in ["donation", "bag", "production"]:
		return false
	for key: String in ["donation", "bag", "production", "latest_balances", "available_actions"]:
		if not data.get(key) is Dictionary:
			return false
	var donation: Dictionary = data.donation
	var bag: Dictionary = data.bag
	var production: Dictionary = data.production
	if donation.get("status") not in DONATION_STATES and not (v2 and donation.get("status") == "not_applicable"):
		return false
	if bag.get("status") not in BAG_STATES and not (v2 and bag.get("status") == "save_failed"):
		return false
	if production.get("status") not in PRODUCTION_STATES:
		return false
	if v2 and bag.has("independent") and typeof(bag.independent) != TYPE_BOOL:
		return false
	var independent: bool = v2 and bag.get("independent", false) == true
	if donation.get("status") == "not_applicable" and donation.get("rows") != []:
		return false
	if not _validate_rows(donation.get("rows"), ["requested", "before", "actual", "after"], donation.status in ["completed", "ineffective"]):
		return false
	if donation.status == "completed" and donation.rows.is_empty():
		return false
	if data.purpose == "donation" and production.status != "not_applicable":
		return false
	for row: Dictionary in donation.rows:
		if donation.status == "completed" and (int(row.requested) <= 0 or row.actual != row.requested):
			return false
		if row.actual != null and row.requested != null and int(row.actual) > int(row.requested):
			return false
		if donation.status in ["completed", "ineffective"]:
			if int(row.before) - int(row.actual) != int(row.after) or (donation.status == "ineffective" and int(row.actual) != 0):
				return false
	if not _validate_rows(bag.get("rows"), ["amount", "actual", "after"], bag.status in ["completed", "ineffective"]):
		return false
	if not _validate_rows(bag.get("deficits"), ["amount"], true) or not bag.has("core"):
		return false
	for deficit: Dictionary in bag.deficits:
		if int(deficit.amount) <= 0: return false
	if bag.core != null:
		if not bag.core is Dictionary or not _nonempty(bag.core.get("id")) or not _nonempty(bag.core.get("name")) or not bag.core.has("amount") or not _is_count(bag.core.amount) or bag.core.amount == null:
			return false
	for row: Dictionary in bag.rows:
		if v2 and row.amount == null:
			return false
		if bag.status == "completed" and row.actual != row.amount:
			return false
		if row.actual != null and row.amount != null and int(row.actual) > int(row.amount):
			return false
		if bag.status == "ineffective" and int(row.actual) != 0:
			return false
	if bag.status not in ["not_applicable", "waiting_donation"] and (not _nonempty(bag.get("bag_id")) or not _nonempty(bag.get("operation_id"))):
		return false
	if bag.status == "capacity_short" and bag.deficits.is_empty():
		return false
	if bag.status == "completed" and not bag.deficits.is_empty():
		return false
	if bag.status == "waiting_donation" and donation.status == "completed":
		return false
	if production.status == "waiting_bag" and donation.status == "completed" and bag.status in ["not_applicable", "completed"]:
		return false
	if not independent and donation.status != "completed" and bag.status not in ["not_applicable", "waiting_donation"]:
		return false
	if production.status not in ["not_applicable", "waiting_bag"] and (donation.status != "completed" or bag.status not in ["not_applicable", "completed"]):
		return false
	for field: String in ["claimable", "space_needed"]:
		if not production.has(field) or not _is_count(production[field]):
			return false
	if not production.has("progress") or (production.progress != null and typeof(production.progress) != TYPE_STRING):
		return false
	if production.status in ["working", "resumed"] and not _nonempty(production.progress):
		return false
	if not production.get("reasons") is Array:
		return false
	for reason: Variant in production.reasons:
		if not _nonempty(reason):
			return false
	if production.status == "blocked" and production.reasons.is_empty():
		return false
	if production.status == "awaiting_claim" and (production.claimable == null or int(production.claimable) <= 0 or not _nonempty(production.get("claim_id"))):
		return false
	if production.status == "claim_uncertain" and not _nonempty(production.get("claim_id")):
		return false
	if production.status == "space_short":
		if production.claimable == null or production.space_needed == null or int(production.space_needed) <= 0:
			return false
		if int(production.claimable) > 0 and not _nonempty(production.get("claim_id")):
			return false
	for id: Variant in data.latest_balances:
		if not _nonempty(id) or not _is_count(data.latest_balances[id]):
			return false
	for action: Variant in data.available_actions:
		var availability: Variant = data.available_actions[action]
		if action not in ACTION_LABELS or action == "processing" or (typeof(availability) != TYPE_BOOL and not _nonempty(availability)):
			return false
	return true

func _history_unchanged(data: Dictionary) -> bool:
	if data.get("contract_version", 1) != snapshot.get("contract_version", 1): return false
	if _is_v2(snapshot) and snapshot.bag.status != "not_applicable":
		if data.bag.get("independent", false) != snapshot.bag.get("independent", false): return false
		if data.bag.core != snapshot.bag.core or data.bag.rows.size() != snapshot.bag.rows.size(): return false
		var amounts: Dictionary = {}
		for row: Dictionary in snapshot.bag.rows: amounts[row.id] = row.amount
		for row: Dictionary in data.bag.rows:
			if not amounts.has(row.id) or amounts[row.id] != row.amount: return false
		if snapshot.bag.status == "completed" and data.bag != snapshot.bag: return false
	for key: String in ["donation", "bag"]:
		var previous: Dictionary = snapshot[key]
		var incoming: Dictionary = data[key]
		if key == "donation":
			if incoming.rows.size() != previous.rows.size(): return false
			for index: int in range(previous.rows.size()):
				var old_row: Dictionary = previous.rows[index]
				var new_row: Dictionary = incoming.rows[index]
				for field: String in ["id", "name", "requested", "before"]:
					if old_row[field] != null and new_row[field] != old_row[field]: return false
		if key == "bag" and previous.status != "not_applicable":
			for field: String in ["bag_id", "operation_id"]:
				if _nonempty(previous.get(field)) and incoming.get(field) != previous.get(field): return false
		if previous.status in ["completed", "ineffective"]:
			if incoming.status != previous.status or incoming.rows != previous.rows:
				return false
			if key == "bag" and (incoming.get("bag_id") != previous.get("bag_id") or incoming.get("operation_id") != previous.get("operation_id") or incoming.core != previous.core):
				return false
	return true

func set_snapshot(data: Dictionary, new_operation: bool = false) -> bool:
	var same: bool = not snapshot.is_empty() and data.get("operation_id") == snapshot.get("operation_id")
	if not snapshot.is_empty():
		if not same and not new_operation:
			return false
		if same and typeof(data.get("revision")) == TYPE_INT and int(data.revision) <= int(snapshot.revision):
			return false
	if not _validate(data) or (same and not _history_unchanged(data)):
		_valid = false
		_render()
		return false
	var anchor: Dictionary = _capture_anchor()
	if not same:
		_lock.clear()
		_feedback.clear()
		_expanded = {"donation": false, "bag": false}
		_clear_rows()
		anchor = {"value": 0}
	_updated = same
	snapshot = data.duplicate(true)
	_valid = true
	_scroll_generation += 1
	_render()
	if is_node_ready():
		_restore_anchor.call_deferred(anchor, _scroll_generation)
	return true

func _clear_rows() -> void:
	for key: Variant in _rows:
		var controls: Dictionary = _rows[key]
		for id: Variant in controls:
			var control: Label = controls[id]
			control.get_parent().remove_child(control)
			control.queue_free()
		controls.clear()

func _number(value: Variant) -> String:
	if value == null:
		return "待确认"
	var text: String = str(value)
	var result: String = ""
	for index: int in range(text.length()):
		if index > 0 and (text.length() - index) % 3 == 0:
			result += ","
		result += text[index]
	return result

func _choose_action() -> String:
	if not _valid or snapshot.is_empty():
		return "return_base"
	var donation: String = snapshot.donation.status
	if donation == "processing": return "processing"
	if donation == "uncertain": return "check_donation"
	if donation == "ineffective": return "recheck_edit"
	var bag: String = snapshot.bag.status
	match bag:
		"processing", "waiting_donation": return "processing"
		"uncertain": return "check_bag"
		"ineffective", "save_failed": return "retry_bag"
		"capacity_short": return "continue_space"
	var production: Dictionary = snapshot.production
	match production.status:
		"waiting_bag": return "processing"
		"claim_uncertain": return "check_claim"
		"awaiting_claim": return "claim"
		"space_short": return "claim" if int(production.claimable) > 0 else "continue_space"
		"blocked":
			if "dispatch_off" in production.reasons: return "dispatch"
			if "region_unavailable" in production.reasons: return "region"
			return "details"
	return "return_base"

func _availability(action: String) -> String:
	if action == "return_base": return ""
	if action == "processing": return "正在等待确认结果"
	var value: Variant = snapshot.get("available_actions", {}).get(action, false)
	if value is bool:
		return "" if value else "功能待接入"
	return String(value)

func _processing_text() -> String:
	if not _lock.is_empty():
		var action: String = _lock.action_id
		if action.begins_with("check_") or action == "recheck_edit": return "正在核对"
		if action == "retry_bag": return "正在重试入库"
		return "正在处理请求"
	if snapshot.get("donation", {}).get("status") == "processing": return "投料处理中"
	if snapshot.get("bag", {}).get("status") == "processing": return "入库处理中"
	return "等待上游结果"

func _reason_text(reason: String) -> String:
	var known: Dictionary = {"dispatch_off": "续派已关闭", "region_unavailable": "区域不可用", "configuration_error": "配置异常，请查看说明或联系支持"}
	if known.has(reason): return String(known[reason])
	if "configuration_error" in snapshot.production.reasons: return "其他阻塞原因，请查看说明"
	return reason

func _next_step() -> String:
	var action: String = _choose_action()
	var explanation: String = String({
		"check_donation": "投料结果尚未确认，请核对原笔结果，不要重复投料。",
		"recheck_edit": "本次投料未生效；请重新核对，再由外部处理器打开全零新草稿确认。",
		"check_bag": "入库结果尚未确认，请核对原袋，避免重复入库。",
		"retry_bag": "本袋入库未生效，可请求重试入库。",
		"continue_space": "空间不足；请继续腾仓，再由外部处理器重新评估全零新草稿。",
		"check_claim": "领取结果尚未确认，请核对原笔领取。",
		"claim": "有待领取物品，请前往领取后再确认生产状态。",
		"dispatch": "续派已关闭，请前往派遣设置。",
		"region": "当前区域不可用，请查看区域。",
		"details": "生产受阻，请查看说明；本页不执行生产事务。",
		"return_base": "没有待处理操作，可返回基地。",
		"processing": "正在等待上游确认，暂不开放后续操作。"
	}.get(action, ""))
	if _is_v2(snapshot):
		match action:
			"recheck_edit": explanation = "本次投料未生效；重新核对将打开全零新草稿，不会自动重扣。"
			"retry_bag": explanation = "本次入库未提交，原袋及核心仍封存；可重试整袋入库，不会重扣投料。"
			"continue_space": explanation = "仓容不足，原袋仍封存；继续腾仓将打开全零新草稿，不会自动投料。"
			"return_base": explanation = "没有待处理操作，可返回基地；已提交的结果已持久保存。"
	if snapshot.production.status == "blocked":
		var reasons: PackedStringArray = []
		for reason: String in snapshot.production.reasons: reasons.append(_reason_text(reason))
		explanation = "原因：" + "、".join(reasons) + "\n" + explanation
	return "下一步：" + explanation

func _render() -> void:
	if not is_node_ready(): return
	var v2: bool = _is_v2(snapshot)
	_persistence_note.text = "关闭不会撤销已提交操作；投料永久消耗、无奖励。已封存返航袋及已提交回执随存档恢复，保存失败未生效；重开不恢复未提交草稿或确认授权。" if v2 else "关闭不会撤销操作；本宿主会话内可恢复阅读与在途请求。核对及后续处理依赖外部接入，未接入功能不会自动执行。"
	title_label.text = "返航袋 · 入库结果" if v2 and snapshot.get("purpose") == "bag" else "公共工程 · 投料结果"
	var previous_action: String = main_action
	main_action = "processing" if not _lock.is_empty() else _choose_action()
	if previous_action != main_action and main_button.has_focus():
		summary_label.grab_focus()
	main_button.text = _processing_text() if main_action == "processing" else String(ACTION_LABELS[main_action])
	main_button.disabled = main_action == "processing" or not _availability(main_action).is_empty()
	_return_button.visible = main_action != "return_base"
	_action_note.text = "状态数据异常，暂不可操作" if not _valid else _availability(main_action)
	if not _lock.is_empty():
		_action_note.text = "请求已发出，等待匹配反馈；关闭不会取消。"
	if snapshot.is_empty():
		summary_label.text = "状态数据异常，暂不可操作"
		for card: Dictionary in _cards.values(): card.root.hide()
		_jump_button.hide()
		return
	summary_label.text = ("结果已更新\n" if _updated else "") + ("状态数据异常，暂不可操作" if not _valid else "投料：%s\n返航袋：%s\n自动生产：%s" % [_state_text(snapshot.donation.status), _state_text(snapshot.bag.status), _state_text(snapshot.production.status)])
	if _valid: summary_label.text += "\n" + _next_step()
	_jump_button.visible = not pending_task().is_empty() and _valid
	for key: String in ["donation", "bag", "production"]:
		var card: Dictionary = _cards[key]
		var data: Dictionary = snapshot[key]
		card.root.visible = (key == "donation" and not v2) or data.status != "not_applicable"
		card.heading.text = {"donation": "本次投料", "bag": "相关返航袋", "production": "相关自动生产"}[key] + " · " + _state_text(data.status)
		card.note.text = String(_feedback.get(key, ""))
		if key == "production":
			card.facts.text = "实际可领取：%s\n还需暂存空位：%s\n进度：%s" % [_number(data.claimable), _number(data.space_needed), "待确认" if data.progress == null else String(data.progress)]
			var reasons: PackedStringArray = []
			for reason: String in data.reasons:
				reasons.append(_reason_text(reason))
			card.deficits.text = "阻塞原因：" + "、".join(reasons) if not reasons.is_empty() else ""
			continue
		card.toggle.text = ("收起" if _expanded[key] else "展开") + ("余额过程" if key == "donation" else "完整物品清单")
		card.facts.text = "历史结算余额不代表当前余额。" if key == "donation" else "仅展示本笔返航袋的真实结果。"
		if key == "bag":
			if data.status == "save_failed":
				card.facts.text += "\n本次保存失败，材料及核心均未入库；原袋保留，可重试。"
			var deficits: PackedStringArray = []
			for row: Dictionary in data.deficits:
				deficits.append("%s：缺 %s" % [row.name, _number(row.amount)])
			card.deficits.text = "\n".join(deficits)
			if data.core != null:
				var core_status: String = "封存中"
				if data.status in ["processing", "uncertain"]: core_status = "入库待确认"
				elif data.status == "completed": core_status = "已入库"
				card.facts.text += "\n核心：%s × %s · %s" % [data.core.name, _number(data.core.amount), core_status]
		else:
			card.deficits.text = ""
		_update_rows(key, data.rows)

func _state_text(state: String) -> String:
	return String({"processing": "处理中", "completed": "已确认完成", "ineffective": "未生效", "save_failed": "保存失败，可重试", "uncertain": "结果待确认", "not_applicable": "无需处理", "waiting_donation": "等待投料结果", "capacity_short": "仓容不足", "waiting_bag": "等待返航袋结果", "awaiting_claim": "等待领取", "claim_uncertain": "领取待确认", "space_short": "暂存空间不足", "working": "生产中", "resumed": "已恢复生产", "blocked": "生产受阻"}.get(state, state))

func _update_rows(key: String, data: Array) -> void:
	var controls: Dictionary = _rows[key]
	var current: Dictionary = {}
	var card: Dictionary = _cards[key]
	for row: Dictionary in data:
		var id: String = row.id
		current[id] = true
		if not controls.has(id):
			controls[id] = _label(card.list)
		var control: Label = controls[id]
		var name_text: String = String(row.name) + ("〔稀有〕" if id in ["pearl", "pearls"] or "珍珠" in String(row.name) else "")
		var confirmed: bool = snapshot[key].status in ["completed", "ineffective"]
		if key == "donation":
			control.visible = true
			control.text = "%s\n申请投出：%s · 实际投出：%s" % [name_text, _number(row.requested), _number(row.actual) if confirmed else "待确认"]
			if _expanded[key]:
				control.text += "\n投料前：%s → 投料后：%s\n最新余额：%s" % [_number(row.before), _number(row.after) if confirmed else "待确认", _number(snapshot.latest_balances.get(id))]
		else:
			control.visible = bool(_expanded[key])
			control.text = "%s\n袋内数量：%s · 实际入库：%s\n袋结算后：%s · 最新余额：%s" % [name_text, _number(row.amount), _number(row.actual) if confirmed else "待确认", _number(row.after) if confirmed else "待确认", _number(snapshot.latest_balances.get(id))]
	for id: Variant in controls:
		if not current.has(id):
			var control: Label = controls[id]
			control.hide()

func _toggle(key: String) -> void:
	var anchor: Dictionary = _capture_anchor()
	_expanded[key] = not bool(_expanded[key])
	_render()
	_scroll_generation += 1
	_restore_anchor.call_deferred(anchor, _scroll_generation)

func _capture_press() -> void:
	_pressed = {"action": main_action, "revision": snapshot.get("revision", -1), "operation_id": snapshot.get("operation_id", "")}

func _clear_press_later() -> void:
	_clear_press.call_deferred()

func _clear_press() -> void:
	_pressed.clear()

func _activate_main() -> void:
	if _pressed.is_empty() or _pressed.action != main_action or _pressed.revision != snapshot.get("revision", -1) or _pressed.operation_id != snapshot.get("operation_id", ""):
		return
	_pressed.clear()
	if main_action == "return_base":
		_close()
		return
	if not _valid or not _lock.is_empty() or main_action == "processing" or not _availability(main_action).is_empty():
		return
	var action: String = main_action
	var operation: String = snapshot.operation_id
	var revision: int = snapshot.revision
	_request_sequence += 1
	var request: String = "%s:%d" % [_session_nonce, _request_sequence]
	_lock = {"operation_id": operation, "request_id": request, "action_id": action, "revision": revision}
	_render()
	action_requested.emit(operation, action, request, revision)

func finish_action(operation_id: String, request_id: String, feedback: String) -> bool:
	if _lock.is_empty() or _lock.operation_id != operation_id or _lock.request_id != request_id or feedback not in ["inconclusive", "done", "not_connected"]:
		return false
	var action: String = _lock.action_id
	var key: String = "donation" if action in ["check_donation", "recheck_edit"] else ("bag" if action in ["check_bag", "retry_bag", "continue_space"] else "production")
	_feedback[key] = {"inconclusive": "核对暂无结论，请稍后再次核对。", "done": "操作反馈已收到，业务结果以确认快照为准。", "not_connected": "功能待接入"}[feedback]
	_lock.clear()
	_render()
	return true

func _close() -> void:
	close_requested.emit(String(snapshot.get("operation_id", "")))

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_BACK)):
		_close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		_close()

func focus_initial() -> void:
	if is_node_ready(): title_label.grab_focus()

func pending_task() -> String:
	if snapshot.is_empty(): return ""
	if not _valid or (snapshot.donation.status != "completed" and not (_is_v2(snapshot) and snapshot.donation.status == "not_applicable")): return "投料结果待确认"
	if snapshot.bag.status not in ["not_applicable", "completed"]: return "返航袋待处理"
	if snapshot.production.status not in ["not_applicable", "working", "resumed"]: return "自动生产待处理"
	return ""

func _jump_pending() -> void:
	var key: String = "donation"
	if snapshot.donation.status == "completed" or (_is_v2(snapshot) and snapshot.donation.status == "not_applicable"):
		key = "bag" if snapshot.bag.status not in ["not_applicable", "completed"] else "production"
	var heading: Label = _cards[key].heading
	heading.grab_focus()
	scroll.ensure_control_visible(heading)

func _capture_anchor() -> Dictionary:
	if not is_node_ready(): return _restore_scroll.duplicate(true)
	var result: Dictionary = {"value": scroll.scroll_vertical}
	for key: String in ["donation", "bag", "production"]:
		var controls: Dictionary = _rows[key]
		for id: Variant in controls:
			var control: Label = controls[id]
			if control.is_visible_in_tree() and control.global_position.y + control.size.y >= scroll.global_position.y:
				result["key"] = key
				result["id"] = id
				result["offset"] = control.global_position.y - scroll.global_position.y
				return result
	return result

func _restore_anchor(anchor: Dictionary, generation: int) -> void:
	if not is_node_ready() or generation != _scroll_generation: return
	scroll.scroll_vertical = int(anchor.get("value", 0))
	var key: String = String(anchor.get("key", ""))
	if _rows.has(key) and _rows[key].has(anchor.get("id")):
		var control: Label = _rows[key][anchor.id]
		if control.is_visible_in_tree():
			scroll.scroll_vertical += int(control.global_position.y - scroll.global_position.y - float(anchor.get("offset", 0.0)))

func export_session() -> Dictionary:
	return {"snapshot": snapshot.duplicate(true), "expanded": _expanded.duplicate(true), "scroll": _capture_anchor(), "lock": _lock.duplicate(true), "request_sequence": _request_sequence, "session_nonce": _session_nonce, "feedback": _feedback.duplicate(true), "valid": _valid}

func import_session(data: Dictionary) -> void:
	if not data.get("snapshot") is Dictionary or not _validate(data.snapshot): return
	if not data.get("expanded", {}) is Dictionary or not data.get("scroll", {}) is Dictionary or not data.get("lock", {}) is Dictionary or not data.get("feedback", {}) is Dictionary: return
	if typeof(data.get("request_sequence", 0)) != TYPE_INT or int(data.get("request_sequence", 0)) < 0: return
	var lock_data: Dictionary = data.get("lock", {})
	if not lock_data.is_empty():
		if lock_data.get("operation_id") != data.snapshot.operation_id or not _nonempty(lock_data.get("request_id")) or lock_data.get("action_id") not in ACTION_LABELS or typeof(lock_data.get("revision")) != TYPE_INT: return
	if not snapshot.is_empty() and (snapshot.operation_id != data.snapshot.operation_id or int(snapshot.revision) > int(data.snapshot.revision)): return
	if not snapshot.is_empty() and not _history_unchanged(data.snapshot): return
	snapshot = data.snapshot.duplicate(true)
	_expanded = {"donation": data.get("expanded", {}).get("donation", false) == true, "bag": data.get("expanded", {}).get("bag", false) == true}
	_lock = lock_data.duplicate(true)
	_request_sequence = maxi(_request_sequence, int(data.get("request_sequence", 0)))
	if _nonempty(data.get("session_nonce")): _session_nonce = data.session_nonce
	_feedback = data.get("feedback", {}).duplicate(true)
	_valid = data.get("valid", true) == true
	_restore_scroll = data.get("scroll", {}).duplicate(true)
	_scroll_generation += 1
	_render()
	if is_node_ready(): _restore_anchor.call_deferred(_restore_scroll, _scroll_generation)
