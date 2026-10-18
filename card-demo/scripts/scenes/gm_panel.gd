extends Control
## 原型调试入口：操作会保存到当前单机存档。
var panel: PanelContainer
var pet_picker: OptionButton
var level_input: SpinBox
var stage_picker: OptionButton
var feedback: Label
var raise_button: Button
var raise_all_button: Button
var jump_button: Button

func _ready() -> void:
	name = "GMPanel"
	z_index = 2100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.05, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#123436")
	style.border_color = Color("#dbcc93")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("GM 工具", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "关闭 ×", hide)
	box.add_child(_label("调试操作会立即保存到当前存档。宠物只升不降，保留已有经验。"))
	box.add_child(_label("宠物快速升级", 21))
	pet_picker = OptionButton.new()
	pet_picker.custom_minimum_size.y = 40
	box.add_child(pet_picker)
	var level_row := HBoxContainer.new()
	box.add_child(level_row)
	var level_label := _label("目标等级")
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	level_label.custom_minimum_size.x = 80
	level_row.add_child(level_label)
	level_input = SpinBox.new()
	level_input.min_value = 1
	level_input.max_value = 999
	level_input.value = 10
	level_input.step = 1
	level_input.custom_minimum_size = Vector2(130, 40)
	level_row.add_child(level_input)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	raise_button = _button(actions, "提升选中宠物", _raise_pets.bind(false))
	raise_all_button = _button(actions, "全部已拥有宠物升至目标等级", _raise_pets.bind(true))
	box.add_child(HSeparator.new())
	box.add_child(_label("关卡跳转", 21))
	box.add_child(_label("解锁至所选关卡，跳转到该关编队页，确认阵容后开战。"))
	stage_picker = OptionButton.new()
	stage_picker.custom_minimum_size.y = 40
	box.add_child(stage_picker)
	jump_button = _button(box, "跳转至所选关卡 →", _jump_stage)
	feedback = _label("")
	feedback.custom_minimum_size.y = 32
	box.add_child(feedback)
	resized.connect(_layout)
	_layout()
	hide()

func _label(text: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff0cf"))
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _layout() -> void:
	panel.size = Vector2(minf(720, size.x - 32), minf(640, size.y - 32))
	panel.position = (size - panel.size) * 0.5

func open_for_pet(pet_id: String = "") -> void:
	feedback.text = ""
	_refresh_pets(pet_id)
	stage_picker.clear()
	var stages: Dictionary = DataManager.tables.get("stages", {})
	var ids: Array = stages.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for id: String in ids:
		if not id.begins_with("stage_") or not id.trim_prefix("stage_").is_valid_int() or int(id.trim_prefix("stage_")) < 1:
			continue
		var stage: Dictionary = DataManager.get_entry("stages", id)
		if stage.is_empty():
			continue
		stage_picker.add_item("第 %s 关 · %s" % [id.trim_prefix("stage_"), str(stage.get("name", id))])
		stage_picker.set_item_metadata(stage_picker.item_count - 1, id)
		if id == GameManager.current_stage:
			stage_picker.select(stage_picker.item_count - 1)
	jump_button.disabled = stage_picker.item_count == 0
	show()

func _refresh_pets(preferred: String) -> void:
	pet_picker.clear()
	for id: String in DataManager.owned_pets():
		pet_picker.add_item("%s · Lv.%d" % [str(DataManager.get_entry("units", id).get("name", id)), int(DataManager.save_data["levels"].get(id, 1))])
		pet_picker.set_item_metadata(pet_picker.item_count - 1, id)
		if id == preferred:
			pet_picker.select(pet_picker.item_count - 1)
	var empty := pet_picker.item_count == 0
	if empty:
		pet_picker.add_item("暂无已拥有宠物")
	pet_picker.disabled = empty
	raise_button.disabled = empty
	raise_all_button.disabled = empty

func _raise_pets(all_owned: bool) -> void:
	if pet_picker.disabled or pet_picker.selected < 0:
		return
	# 应用尚未失去焦点的手输数值，避免点击按钮时读取上一次的等级。
	level_input.apply()
	var target := int(level_input.value)
	var selected: String = str(pet_picker.get_item_metadata(pet_picker.selected))
	var pets: Array[String] = []
	if all_owned:
		pets = DataManager.owned_pets()
	else:
		pets.append(selected)
	var changed := DataManager.gm_raise_pet_levels(pets, target)
	_refresh_pets(selected)
	if changed < 0:
		feedback.text = "升级失败：请检查宠物、目标等级或存档写入权限。"
	elif changed == 0:
		feedback.text = "所选宠物已达到或超过 Lv.%d，无需提升。" % target
	else:
		feedback.text = "已将 %d 只宠物提升至 Lv.%d，进度已保存。" % [changed, target]

func _jump_stage() -> void:
	if stage_picker.selected < 0:
		return
	if not GameManager.gm_jump_to_stage(str(stage_picker.get_item_metadata(stage_picker.selected))):
		feedback.text = "跳转失败：关卡配置无效或存档无法写入。"
