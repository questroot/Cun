extends Control
## 三行三列阵位：左列前排，右列后排；从左侧名单拖入格子或点击交换。
const AtlasScript = preload("res://scripts/battle/sprite_atlas.gd")
const ROW_NAMES := ["上", "中", "下"]
const COLUMN_NAMES := ["前", "中", "后"]
var formation: Array = []
var team: Array = []
var grid_buttons: Array[Button] = []
var roster_buttons: Array[Button] = []
var reserve_buttons: Array[Button] = []
var selected_id := ""
var skill_picker: OptionButton
var skill_description: Label
var status_label: Label

func _ready() -> void:
	formation = (DataManager.save_data.get("formation", []) as Array).duplicate()
	team = (DataManager.save_data.get("team", []) as Array).duplicate()
	if not DataManager.valid_team(team, formation):
		team = DataManager.DEFAULT_TEAM.duplicate()
		formation = ["sprout", "", "mist", "pebble", "hero", "", "", "ember", ""]
	var background := TextureRect.new()
	background.texture = load("res://assets/backgrounds/menu_pet_garden.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.16, 0.16, 0.5)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var title := Label.new()
	title.text = "阵容配置  /  三乘三阵位"
	title.position = Vector2(65, 27)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(title)
	var hint := Label.new()
	hint.text = "主角始终上阵 · 从五只宠物选四只 · 点击候选宠物再点击上阵宠物替换 · 拖拽或点击调整阵位"
	hint.position = Vector2(65, 80)
	hint.add_theme_color_override("font_color", Color("#e5f3e7"))
	add_child(hint)
	var roster_title := Label.new()
	roster_title.text = "当前队伍  5 / 9"
	roster_title.position = Vector2(75, 146)
	roster_title.add_theme_font_size_override("font_size", 24)
	roster_title.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(roster_title)
	for i in range(team.size()):
		var id := str(team[i])
		var button := Button.new()
		button.position = Vector2(65, 190 + i * 67)
		button.size = Vector2(300, 60)
		button.icon = AtlasScript.texture_for(id)
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", card_style(Color(0.04, 0.18, 0.18, 0.9)))
		button.set_drag_forwarding(roster_drag_slot.bind(i, button), roster_can_drop, roster_drop)
		button.pressed.connect(select_team_slot.bind(i))
		add_child(button)
		roster_buttons.append(button)
	for col in range(3):
		var col_label := Label.new()
		col_label.text = COLUMN_NAMES[col] + "排"
		col_label.position = Vector2(460 + col * 225, 142)
		col_label.add_theme_font_size_override("font_size", 21)
		col_label.add_theme_color_override("font_color", Color("#fff0c9"))
		add_child(col_label)
	for row in range(3):
		var row_label := Label.new()
		row_label.text = ROW_NAMES[row]
		row_label.position = Vector2(410, 210 + row * 133)
		row_label.add_theme_color_override("font_color", Color("#fff0c9"))
		add_child(row_label)
		for col in range(3):
			var index := row * 3 + col
			var cell := Button.new()
			cell.position = Vector2(455 + col * 225, 184 + row * 133)
			cell.size = Vector2(200, 111)
			cell.expand_icon = true
			cell.add_theme_stylebox_override("normal", card_style(Color(0.025, 0.12, 0.14, 0.82)))
			cell.set_drag_forwarding(cell_drag.bind(index, cell), cell_can_drop.bind(index), cell_drop.bind(index))
			cell.pressed.connect(func() -> void: place_selected(index))
			add_child(cell)
			grid_buttons.append(cell)
	var skill_label := Label.new()
	skill_label.text = "主角奥义："
	skill_label.position = Vector2(65, 632)
	skill_label.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(skill_label)
	skill_picker = OptionButton.new()
	skill_picker.position = Vector2(155, 620)
	skill_picker.size = Vector2(210, 43)
	var hero_config: Dictionary = DataManager.get_entry("units", "hero")
	for skill_value: Variant in hero_config.get("skills", []):
		var id: String = str(skill_value)
		skill_picker.add_item(str(DataManager.get_entry("skills", id).get("name", id)))
		skill_picker.set_item_metadata(skill_picker.item_count - 1, id)
	for i in range(skill_picker.item_count):
		if skill_picker.get_item_metadata(i) == DataManager.save_data["hero_skill"]:
			skill_picker.select(i)
	add_child(skill_picker)
	skill_description = Label.new()
	skill_description.name = "HeroSkillDescription"
	skill_description.position = Vector2(65, 665)
	skill_description.size = Vector2(1125, 42)
	skill_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_description.add_theme_font_size_override("font_size", 15)
	skill_description.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(skill_description)
	skill_picker.item_selected.connect(func(_index: int) -> void: update_skill_description())
	update_skill_description()
	status_label = Label.new()
	status_label.position = Vector2(455, 584)
	status_label.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(status_label)
	var save := Button.new()
	save.text = "保存并进入战斗" if GameManager.stage_pending else "保存阵容"
	save.position = Vector2(800, 620)
	save.size = Vector2(215, 54)
	save.add_theme_stylebox_override("normal", card_style(Color("#27817a")))
	save.pressed.connect(func() -> void: save_team(true))
	add_child(save)
	var back := Button.new()
	back.text = "返回主城"
	back.position = Vector2(1030, 620)
	back.size = Vector2(170, 54)
	back.add_theme_stylebox_override("normal", card_style(Color("#455d68")))
	back.pressed.connect(func() -> void: save_team(false))
	add_child(back)
	refresh()

func update_skill_description() -> void:
	var skill: Dictionary = DataManager.get_entry("skills", str(skill_picker.get_item_metadata(skill_picker.selected)))
	var target: String = str(skill.get("target", "enemy"))
	var target_text: String = "自身" if target == "self" else "友方单体" if target == "ally" else "敌方任意存活目标" if bool(skill.get("free_target", false)) else "敌方最前排存活目标"
	var effects: Array[String] = []
	if float(skill.get("power", 0)) > 0:
		effects.append("威力系数 %.2f" % float(skill.get("power", 0)))
	var duration: int = int(skill.get("duration", 0))
	var value: float = float(skill.get("value", 0))
	match str(skill.get("apply", "")):
		"air": effects.append("浮空 %d 轮" % duration)
		"down": effects.append("倒地 %d 轮" % duration)
		"shield": effects.append("护盾 %d · 持续 %d 轮" % [roundi(value), duration])
		"heal": effects.append("治疗 %d 生命" % roundi(value))
		"cleanse": effects.append("净化友方负面状态")
	skill_description.text = "%s｜目标：%s｜效果：%s｜消耗：%d 能量 · 冷却：%d 轮" % [str(skill.get("name", "")), target_text, "、".join(effects), int(skill.get("cost", 0)), int(skill.get("cooldown", 0))]

func card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#d9c38a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func refresh() -> void:
	for index in range(9):
		var id := str(formation[index])
		var button := grid_buttons[index]
		button.icon = AtlasScript.texture_for(id) if id != "" else null
		button.text = (str(DataManager.get_entry("units", id).get("name", id)) + "\n" if id != "" else "+ 空位\n") + ROW_NAMES[int(index / 3)] + "路 · " + COLUMN_NAMES[index % 3] + "排"
		button.modulate = Color("#fff4bf") if id == selected_id and id != "" else Color.WHITE
	for i in range(roster_buttons.size()):
		var id := str(team[i])
		roster_buttons[i].icon = AtlasScript.texture_for(id)
		roster_buttons[i].text = str(DataManager.get_entry("units", id).get("name", id)) + ("  [已选]" if selected_id == id else "")
	for button in reserve_buttons:
		button.queue_free()
	reserve_buttons.clear()
	for id: String in DataManager.available_pets():
		if team.has(id):
			continue
		var reserve := Button.new()
		reserve.position = Vector2(65, 530 + reserve_buttons.size() * 37)
		reserve.size = Vector2(300, 36)
		reserve.icon = AtlasScript.texture_for(id)
		reserve.expand_icon = true
		var pet_data: Dictionary = DataManager.get_entry("units", id)
		reserve.text = "候选：%s%s%s" % [str(pet_data.get("name", id)), " · " + str(pet_data.get("species")) if pet_data.has("species") else "", " [已选]" if selected_id == id else ""]
		reserve.pressed.connect(select_reserve.bind(id))
		add_child(reserve)
		reserve_buttons.append(reserve)
	status_label.text = "已上阵 %d / 5" % occupied_count()

func select_reserve(id: String) -> void:
	selected_id = id
	refresh()

func select_team_slot(slot: int) -> void:
	var id: String = str(team[slot])
	if selected_id != "" and not formation.has(selected_id) and id != "hero":
		replace_pet(id)
	else:
		selected_id = id
	refresh()

func roster_drag_slot(_at: Vector2, slot: int, source: Button) -> Variant:
	return roster_drag(Vector2.ZERO, str(team[slot]), source)

func occupied_count() -> int:
	var count := 0
	for id in formation:
		if str(id) != "": count += 1
	return count

## 选择角色后点击目标格；已有角色则互换，空格则直接移动。
func place_selected(index: int) -> void:
	if selected_id == "":
		selected_id = str(formation[index])
	elif not formation.has(selected_id):
		if str(formation[index]) != "" and str(formation[index]) != "hero":
			replace_pet(str(formation[index]))
	else:
		move_unit(selected_id, index)
		selected_id = ""
	refresh()

## 候选宠物替换指定上阵宠物，继承九宫格位置而不改变其他队员。
func replace_pet(outgoing: String) -> void:
	if outgoing == "hero" or not team.has(outgoing) or not DataManager.available_pets().has(selected_id) or team.has(selected_id):
		return
	var slot: int = team.find(outgoing)
	var cell: int = formation.find(outgoing)
	if cell < 0:
		return
	team[slot] = selected_id
	formation[cell] = selected_id
	selected_id = ""

func move_unit(id: String, index: int) -> void:
	if id == "": return
	var original: int = formation.find(id)
	if original < 0: return
	if original == index:
		return
	var displaced: String = str(formation[index])
	formation[index] = id
	formation[original] = displaced

func roster_drag(_at: Vector2, id: String, source: Button) -> Variant:
	var preview := Label.new()
	preview.text = str(DataManager.get_entry("units", id).get("name", id))
	source.set_drag_preview(preview)
	return id

func roster_can_drop(_at: Vector2, _data: Variant) -> bool:
	return false

func roster_drop(_at: Vector2, _data: Variant) -> void:
	pass

func cell_drag(_at: Vector2, index: int, source: Button) -> Variant:
	var id := str(formation[index])
	if id == "": return null
	return roster_drag(Vector2.ZERO, id, source)

func cell_can_drop(_at: Vector2, data: Variant, _index: int) -> bool:
	return data is String and formation.has(data)

func cell_drop(_at: Vector2, data: Variant, index: int) -> void:
	move_unit(str(data), index)
	refresh()

## 将九宫格索引写入存档；队伍成员始终保留，主角无法下阵。
func save_team(go_battle: bool) -> void:
	if not DataManager.valid_team(team, formation):
		status_label.text = "队伍必须是主角和四只不同宠物，且阵位不能重复"
		return
	DataManager.save_data["team"] = team.duplicate()
	DataManager.save_data["formation"] = formation.duplicate()
	DataManager.save_data["hero_skill"] = skill_picker.get_item_metadata(skill_picker.selected)
	DataManager.write_save()
	var begin_battle: bool = go_battle and GameManager.stage_pending
	GameManager.stage_pending = false
	GameManager.goto_scene("battle" if begin_battle else "city")
