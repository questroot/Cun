extends VBoxContainer
## 只编辑意图；库存和提交令牌由宿主服务核对。
signal preview_requested(amounts: Dictionary, pearl_selected: bool)
signal confirm_requested(token: String, pearl_confirmed: bool)
signal close_requested

const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
var context: Dictionary = {}
var inputs: Dictionary = {}
var pearl_choice: CheckBox
var pearl_confirmation: CheckBox
var message: Label
var preview_text: Label
var preview_button: Button
var confirm_button: Button
var _token := ""
var _focus_resource := ""

func configure(data: Dictionary, focused_resource: String = "") -> void:
	context = data.duplicate(true)
	_focus_resource = focused_resource
	_token = ""
	if is_node_ready(): _build()

func _ready() -> void:
	_build()

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	inputs.clear()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(self, "公共工程 · 投料腾仓").theme_type_variation = &"HarborHeading"
	_label(self, "投料永久消耗，不发放奖励。仅使用已入库资源；关闭后不保留草稿。").theme_type_variation = &"HarborCaption"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for id: String in Catalog.ITEMS:
		var stock := int(context.get("balances", {}).get(id, 0))
		var bag := int(context.get("bag_items", {}).get(id, 0))
		var deficit := int(context.get("deficits", {}).get(id, 0))
		_label(body, "%s · 库存 %d · 待袋 %d · 缺口 %d" % [Catalog.ITEMS[id][0], stock, bag, deficit])
		if id == "pearl":
			pearl_choice = CheckBox.new()
			pearl_choice.text = "主动选择深水珍珠（不会自动填入）"
			body.add_child(pearl_choice)
			pearl_choice.toggled.connect(_pearl_toggled)
		var row := HBoxContainer.new()
		body.add_child(row)
		_button(row, "−1", _step.bind(id, -1))
		var input := LineEdit.new()
		input.text = "0"
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.custom_minimum_size.x = 80
		input.tooltip_text = String(Catalog.ITEMS[id][0]) + "投料数量"
		row.add_child(input)
		inputs[id] = input
		input.text_changed.connect(func(_value: String) -> void: _invalidate())
		input.editable = id != "pearl"
		_button(row, "+1", _step.bind(id, 1))
		_button(row, "清零", _clear.bind(id))
	_button(body, "按缺口填入普通资源", _fill_deficits)
	preview_text = _label(body, "")
	pearl_confirmation = CheckBox.new()
	pearl_confirmation.text = "我确认捐出所列深水珍珠，无法撤回"
	pearl_confirmation.visible = false
	body.add_child(pearl_confirmation)
	message = _label(self, "")
	preview_button = _button(self, "预览投料", _preview)
	confirm_button = _button(self, "确认永久投料", _confirm)
	preview_button.theme_type_variation = &"HarborPrimary"
	confirm_button.theme_type_variation = &"HarborLaunch"
	confirm_button.disabled = true
	_button(self, "取消并返回基地", func() -> void: close_requested.emit())
	if inputs.has(_focus_resource): inputs[_focus_resource].grab_focus.call_deferred()

func _invalidate() -> void:
	_token = ""
	if is_instance_valid(confirm_button): confirm_button.disabled = true
	if is_instance_valid(pearl_confirmation):
		pearl_confirmation.button_pressed = false
		pearl_confirmation.hide()
	if is_instance_valid(preview_text): preview_text.text = "选料已变化，请重新预览。"

func _pearl_toggled(selected: bool) -> void:
	inputs.pearl.editable = selected
	if not selected: inputs.pearl.text = "0"
	_invalidate()

func _clear(id: String) -> void:
	inputs[id].text = "0"
	_invalidate()

func _step(id: String, amount: int) -> void:
	if id == "pearl" and not pearl_choice.button_pressed:
		show_error("请先主动选择深水珍珠。")
		return
	var text: String = inputs[id].text
	if not text.is_valid_int():
		show_error("请先输入有效整数。")
		return
	var value := int(text) + amount
	if value < 0 or value > int(context.get("balances", {}).get(id, 0)):
		show_error("数量不可为负数或超过当前库存。")
		return
	inputs[id].text = str(value)
	_invalidate()

func _fill_deficits() -> void:
	for id: String in inputs:
		if id == "pearl": continue
		inputs[id].text = str(mini(int(context.get("balances", {}).get(id, 0)), int(context.get("deficits", {}).get(id, 0))))
	_invalidate()

func _preview() -> void:
	var amounts := {}
	var total := 0
	for id: String in inputs:
		var text: String = inputs[id].text
		if text.is_empty() or not text.is_valid_int() or text.begins_with("+") or text.length() > 7:
			show_error("%s请输入非负整数，不接受空白或小数。" % Catalog.ITEMS[id][0])
			return
		var value := int(text)
		if value < 0 or value > int(context.get("balances", {}).get(id, 0)):
			show_error("%s数量不可为负数或超过当前库存。" % Catalog.ITEMS[id][0])
			return
		amounts[id] = value
		total += value
	if total == 0:
		show_error("请至少选择一种资源。")
		return
	if amounts.pearl > 0 and not pearl_choice.button_pressed:
		show_error("深水珍珠需要主动选择。")
		return
	message.text = ""
	preview_requested.emit(amounts, pearl_choice.button_pressed)

func show_preview(preview: Dictionary) -> void:
	_token = String(preview.get("token", ""))
	var lines := PackedStringArray(["请核对：以下资源将永久消耗，无法撤回。"])
	var amounts: Dictionary = preview.get("amounts", {})
	for id: String in amounts:
		if int(amounts[id]) <= 0: continue
		var deficit := int(context.get("deficits", {}).get(id, 0))
		lines.append("%s：投料 %d，余额 %d → %d；仍缺 %d，额外消耗 %d" % [Catalog.ITEMS[id][0], int(amounts[id]), int(preview.get("before", {}).get(id, 0)), int(preview.get("after", {}).get(id, 0)), maxi(0, deficit - int(amounts[id])), maxi(0, int(amounts[id]) - deficit)])
	preview_text.text = "\n".join(lines)
	pearl_confirmation.button_pressed = false
	pearl_confirmation.visible = int(amounts.get("pearl", 0)) > 0
	confirm_button.disabled = _token.is_empty()
	message.text = ""
	confirm_button.grab_focus()

func _confirm() -> void:
	if _token.is_empty(): return
	if pearl_confirmation.visible and not pearl_confirmation.button_pressed:
		show_error("请额外确认深水珍珠不可撤回。")
		return
	confirm_button.disabled = true
	confirm_requested.emit(_token, pearl_confirmation.button_pressed)

func show_error(text: String) -> void:
	message.text = text
	_token = ""
	confirm_button.disabled = true
