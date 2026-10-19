extends Control
const ExplorationTools = preload("res://scripts/scenes/exploration_tools.gd")
var exploration_tools: ExplorationTools
## 2.5D 主城：地面点击寻点 / WASD 行走，接近向导后对话开启独立关卡页。
const CityMapScript = preload("res://scripts/scenes/city_map.gd")
const HeroWalkScript = preload("res://scripts/scenes/hero_walk_sprite.gd")
const GUIDE_ART := preload("res://assets/characters/pet_guide.png")
const HudIconScript = preload("res://scripts/scenes/city_hud_icon.gd")
const GMPanelScript = preload("res://scripts/scenes/gm_panel.gd")
const AtlasScript = preload("res://scripts/battle/sprite_atlas.gd")
const ELEMENT_NAMES := {"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土"}
const EFFECT_NAMES := {"air": "小浮空", "down": "倒地", "stun": "眩晕", "shield": "护盾", "damage_up": "增伤", "damage_down": "减伤", "heal": "治疗"}
const TIMING_NAMES := {"enter": "入场时", "round_start": "每回合开始", "hit": "受到攻击时"}
const NPC_FOOT := Vector2(843.0, 562.0)
const TALK_DISTANCE := 105.0
var camera_offset := Vector2.ZERO
var exit_armed := true
var avatar: TextureRect
var npc: Control
var actor_layer: Control
var city_map: Node2D
var dialogue: PanelContainer
var path_points: Array[Vector2] = []
var player_foot := Vector2(334.0, 558.0)
var destination := Vector2.ZERO
var has_destination := false
var waiting_for_npc := false
var walk_speed := 270.0
var near_hint: Label
var header: PanelContainer
var status_panel: PanelContainer
var nav_panel: PanelContainer
var party_button: Button
var bag_button: Button
var gm_button: Button
var gm_panel: Control
var party_panel: PanelContainer
var pet_bag: PanelContainer
var pet_list: VBoxContainer
var pet_detail: VBoxContainer
var pet_bag_hint: Label
var selected_pet_id: String = ""
var status_label: Label
var nav_label: Label
var player_model: HeroWalkScript

func _ready() -> void:
	DisplayServer.window_set_title("灵伴回合冒险")
	city_map = CityMapScript.new()
	city_map.name = "CityMap"
	add_child(city_map)
	player_foot = city_map.nearest_walkable(GameManager.city_spawn)
	GameManager.city_spawn = Vector2(334, 558)
	actor_layer = Control.new()
	actor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actor_layer)
	npc = Control.new()
	npc.name = "StageGuide"
	npc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_layer.add_child(npc)
	# Each character draws its own ground shadow in the same palette.
	var npc_model := Sprite2D.new()
	npc_model.name = "VisibleNpcModel"
	npc_model.texture = GUIDE_ART
	npc_model.offset = Vector2(0, -128)
	npc_model.scale = Vector2(0.52, 0.52)
	npc.add_child(npc_model)
	var npc_button := Button.new()
	npc_button.name = "TalkButton"
	npc_button.text = "关卡向导 · 交谈"
	npc_button.position = Vector2(-70, -128)
	npc_button.size = Vector2(140, 33)
	npc_button.add_theme_stylebox_override("normal", card_style(Color(0.035, 0.18, 0.17, 0.91)))
	npc_button.pressed.connect(request_npc_conversation)
	npc.add_child(npc_button)
	var click_area := Button.new()
	click_area.name = "NpcClickArea"
	click_area.flat = true
	click_area.text = ""
	click_area.position = Vector2(-34, -94)
	click_area.size = Vector2(68, 90)
	click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_area.pressed.connect(request_npc_conversation)
	npc.add_child(click_area)
	avatar = TextureRect.new()
	avatar.name = "PlayerAvatar"
	avatar.visible = false
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_layer.add_child(avatar)
	player_model = HeroWalkScript.new()
	player_model.name = "VisiblePlayerModel"
	player_model.position = Vector2.ZERO
	actor_layer.add_child(player_model)
	player_model.set_meta("player_model", true)
	_build_hud()
	_build_pet_bag()
	_build_dialogue()
	gm_panel = GMPanelScript.new()
	add_child(gm_panel)
	_update_actors(0.0)
	_update_camera()
	resized.connect(_layout_hud)
	_layout_hud()
	DataManager.save_changed.connect(_refresh_status)
	exploration_tools = ExplorationTools.new()
	add_child(exploration_tools)

func card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#dbcc93")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.02, 0.07, 0.09, 0.36)
	style.shadow_size = 6
	style.set_content_margin_all(10)
	return style

func _make_icon(kind: String) -> Control:
	var icon := Control.new()
	icon.set_script(HudIconScript)
	icon.kind = kind
	icon.custom_minimum_size = Vector2(28, 28)
	return icon

func _make_hud_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", card_style(Color(0.025, 0.13, 0.15, 0.91)))
	add_child(panel)
	return panel

func _build_hud() -> void:
	header = _make_hud_panel("CityHeader")
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	header.add_child(title_row)
	title_row.add_child(_make_icon("compass"))
	var title := Label.new()
	title.text = "云庭主城  ·  漫游"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#fff0cf"))
	title_row.add_child(title)
	status_panel = _make_hud_panel("CityStatus")
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_panel.add_child(status_row)
	status_row.add_child(_make_icon("rank"))
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#e9f6ea"))
	status_label.add_theme_font_size_override("font_size", 16)
	status_row.add_child(status_label)
	party_panel = _make_hud_panel("CityParty")
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 4)
	party_panel.add_child(party_row)
	party_row.add_child(_make_icon("party"))
	party_button = Button.new()
	party_button.name = "PartyButton"
	party_button.text = "调整阵容"
	party_button.custom_minimum_size = Vector2(116, 38)
	party_button.add_theme_stylebox_override("normal", card_style(Color(0.04, 0.25, 0.26, 0.96)))
	party_button.pressed.connect(func() -> void: GameManager.goto_scene("team"))
	party_row.add_child(party_button)
	bag_button = Button.new()
	bag_button.name = "PetBagButton"
	bag_button.text = "宠物背包"
	bag_button.custom_minimum_size = Vector2(104, 38)
	bag_button.add_theme_stylebox_override("normal", card_style(Color(0.04, 0.25, 0.26, 0.96)))
	bag_button.pressed.connect(toggle_pet_bag)
	party_row.add_child(bag_button)
	gm_button = Button.new()
	gm_button.name = "GMButton"
	gm_button.text = "GM 工具"
	gm_button.size = Vector2(120, 44)
	gm_button.add_theme_stylebox_override("normal", card_style(Color(0.04, 0.25, 0.26, 0.96)))
	gm_button.pressed.connect(open_gm_panel)
	add_child(gm_button)
	nav_panel = _make_hud_panel("CityNavigation")
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	nav_panel.add_child(nav_row)
	nav_row.add_child(_make_icon("route"))
	nav_label = Label.new()
	nav_label.add_theme_color_override("font_color", Color("#e9f6ea"))
	nav_label.add_theme_font_size_override("font_size", 16)
	nav_row.add_child(nav_label)
	near_hint = Label.new()
	near_hint.name = "NpcHint"
	near_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_hint.add_theme_color_override("font_color", Color("#fff1d0"))
	near_hint.add_theme_color_override("font_shadow_color", Color("#173a40"))
	near_hint.add_theme_constant_override("shadow_offset_x", 1)
	near_hint.add_theme_constant_override("shadow_offset_y", 2)
	near_hint.add_theme_font_size_override("font_size", 18)
	add_child(near_hint)
	_refresh_status()

## 主城中的背包弹层复用现有背景、深青卡片及金色边框。
func _build_pet_bag() -> void:
	pet_bag = PanelContainer.new()
	pet_bag.name = "PetBag"
	# 角色按脚底 y 值设置 z_index；背包必须始终覆盖世界角色和 NPC。
	pet_bag.z_index = 2000
	pet_bag.add_theme_stylebox_override("panel", card_style(Color(0.02, 0.12, 0.14, 0.98)))
	pet_bag.visible = false
	pet_bag.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pet_bag)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	pet_bag.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "宠物背包  ·  已拥有的灵伴"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f3d591"))
	heading.add_child(title)
	var gm_upgrade := Button.new()
	gm_upgrade.text = "GM 升级"
	gm_upgrade.custom_minimum_size = Vector2(96, 42)
	gm_upgrade.pressed.connect(open_gm_panel)
	heading.add_child(gm_upgrade)
	var close := Button.new()
	close.text = "关闭 ×"
	close.custom_minimum_size = Vector2(86, 42)
	close.pressed.connect(toggle_pet_bag)
	heading.add_child(close)
	pet_bag_hint = Label.new()
	pet_bag_hint.add_theme_color_override("font_color", Color("#e9f6ea"))
	layout.add_child(pet_bag_hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var roster_panel := PanelContainer.new()
	roster_panel.add_theme_stylebox_override("panel", card_style(Color("#153b3c")))
	roster_panel.custom_minimum_size.x = 332
	columns.add_child(roster_panel)
	var roster_layout := VBoxContainer.new()
	roster_layout.add_theme_constant_override("separation", 8)
	roster_panel.add_child(roster_layout)
	var roster_label := Label.new()
	roster_label.text = "灵伴图鉴  /  已拥有"
	roster_label.add_theme_color_override("font_color", Color("#f3d591"))
	roster_label.add_theme_font_size_override("font_size", 18)
	roster_layout.add_child(roster_label)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_layout.add_child(list_scroll)
	pet_list = VBoxContainer.new()
	pet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_list.add_theme_constant_override("separation", 8)
	list_scroll.add_child(pet_list)
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", card_style(Color("#123436")))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	pet_detail = VBoxContainer.new()
	pet_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_detail.add_theme_constant_override("separation", 9)
	detail_scroll.add_child(pet_detail)

func toggle_pet_bag() -> void:
	pet_bag.visible = not pet_bag.visible
	if pet_bag.visible:
		if dialogue.visible:
			close_dialogue()
		has_destination = false
		path_points.clear()
		waiting_for_npc = false
		_refresh_pet_bag()

func open_gm_panel() -> void:
	pet_bag.hide()
	close_dialogue()
	has_destination = false
	path_points.clear()
	waiting_for_npc = false
	gm_panel.open_for_pet(selected_pet_id)

func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _refresh_pet_bag() -> void:
	_clear_container(pet_list)
	var pets: Array[String] = DataManager.owned_pets()
	pet_bag_hint.text = "已拥有 %d 只  ·  点击左侧宠物查看技能效果" % pets.size()
	if pets.is_empty():
		selected_pet_id = ""
		var empty := Label.new()
		empty.text = "暂无宠物。获得宠物后会显示在这里。"
		empty.add_theme_color_override("font_color", Color("#e9f6ea"))
		pet_list.add_child(empty)
		_show_pet_detail("")
		return
	if not pets.has(selected_pet_id):
		selected_pet_id = pets[0]
	for id: String in pets:
		var data: Dictionary = DataManager.get_entry("units", id)
		var button := Button.new()
		button.name = "PetCard_" + id
		button.custom_minimum_size = Vector2(298, 86)
		button.text = ""
		button.clip_contents = true
		button.add_theme_stylebox_override("normal", card_style(Color("#276361") if id == selected_pet_id else Color("#1c4a4b")))
		button.add_theme_stylebox_override("hover", card_style(Color("#326f69")))
		button.add_theme_stylebox_override("pressed", card_style(Color("#437c70")))
		button.pressed.connect(_select_pet.bind(id))
		pet_list.add_child(button)
		var row := HBoxContainer.new()
		row.name = "PetCardContent"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_right = -7
		row.offset_top = 6
		row.offset_bottom = -6
		row.add_theme_constant_override("separation", 10)
		button.add_child(row)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = AtlasScript.pet_texture(id)
		portrait.custom_minimum_size = Vector2(70, 70)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = "%s  ·  Lv.%d" % [str(data.get("name", id)), int((DataManager.save_data.get("levels", {}) as Dictionary).get(id, 1))]
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", Color("#fff0cf"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(name_label)
		var species_label := Label.new()
		var elements: Array = data.get("elements", [])
		var element_name: String = str(ELEMENT_NAMES.get(str(elements[0]), "未知")) if not elements.is_empty() else "未知"
		species_label.text = "%s属性  ·  %s" % [element_name, str(data.get("species", "灵伴"))]
		species_label.add_theme_color_override("font_color", Color("#d6e5d9"))
		species_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(species_label)
	_show_pet_detail(selected_pet_id)

func _select_pet(id: String) -> void:
	selected_pet_id = id
	_refresh_pet_bag()

func _detail_label(text: String, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#fff0cf"))
	pet_detail.add_child(label)

func _show_pet_detail(id: String) -> void:
	_clear_container(pet_detail)
	if id == "":
		_detail_label("选择一只宠物后，可在这里查看形象和技能。")
		return
	var data: Dictionary = DataManager.get_entry("units", id)
	var picture := TextureRect.new()
	picture.texture = AtlasScript.pet_texture(id)
	picture.custom_minimum_size = Vector2(0, 168)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pet_detail.add_child(picture)
	var element_ids: Array = data.get("elements", [])
	var element: String = str(ELEMENT_NAMES.get(str(element_ids[0]), "未知")) if not element_ids.is_empty() else "未知"
	_detail_label("%s  ·  %s属性" % [str(data.get("name", id)), element], 22)
	if data.has("species"):
		_detail_label("物种：%s" % str(data.get("species")))
	var count: int = 0
	for skill_id: Variant in data.get("skills", []):
		_add_skill(str(skill_id), "skills", "主动技能")
		count += 1
	for passive_id: Variant in data.get("passives", []):
		_add_skill(str(passive_id), "passives", "被动技能")
		count += 1
	var chase_id: String = str(data.get("chase", ""))
	if chase_id != "":
		_add_skill(chase_id, "skills", "追打技能")
		count += 1
	if count == 0:
		_detail_label("该宠物暂未拥有技能。")

func _add_skill(id: String, table: String, category: String) -> void:
	var skill: Dictionary = DataManager.get_entry(table, id)
	var detail: String = ""
	if skill.is_empty():
		detail = "技能配置缺失"
	else:
		if table == "skills":
			detail = "威力系数 %s · 能量 %s · 冷却 %s 回合" % [str(skill.get("power", 0)), str(skill.get("cost", 0)), str(skill.get("cooldown", 0))]
			var trigger: String = str(skill.get("trigger", ""))
			if trigger != "":
				detail += "\n追打条件：目标处于%s" % str(EFFECT_NAMES.get(trigger, trigger))
			var effect: String = str(skill.get("apply", ""))
			if effect != "":
				detail += "\n效果：%s" % str(EFFECT_NAMES.get(effect, effect))
		else:
			var timing: String = str(skill.get("trigger", ""))
			detail = "触发：%s · 效果：%s" % [str(TIMING_NAMES.get(timing, timing)), str(EFFECT_NAMES.get(str(skill.get("effect", "")), str(skill.get("effect", ""))))]
		if skill.has("value"):
			detail += " · 数值 %s" % str(skill["value"])
		if int(skill.get("duration", 0)) > 0:
			detail += " · 持续 %s 回合" % str(skill["duration"])
	var card := PanelContainer.new()
	card.name = "SkillCard_" + id
	var style := card_style(Color("#1b4445") if table == "skills" else Color("#17413c"))
	style.border_color = Color("#e5ca89") if table == "skills" else Color("#91bca8")
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_detail.add_child(card)
	var content := VBoxContainer.new()
	content.name = "SkillCardContent"
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	var heading := HBoxContainer.new()
	heading.name = "SkillCardHeading"
	heading.add_theme_constant_override("separation", 8)
	content.add_child(heading)
	var icon := _make_icon("passive" if table == "passives" else "chase" if category == "追打技能" else "active")
	icon.name = "SkillTypeIcon"
	heading.add_child(icon)
	var title := Label.new()
	title.name = "SkillName"
	title.text = "%s · %s" % [category, str(skill.get("name", id))]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#fff0cf"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var info := Label.new()
	info.name = "SkillInfo"
	info.text = detail
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color("#d9e9df"))
	content.add_child(info)

func _refresh_status() -> void:
	if status_label == null:
		return
	var level := int((DataManager.save_data.get("levels", {}) as Dictionary).get("hero", 1))
	var unlocked := int(DataManager.save_data.get("unlocked_stage", 1))
	status_label.text = "主角 Lv.%d   ·   历练 %d/%d   ·   队员 %d" % [level, unlocked, DataManager.tables["stages"].size(), (DataManager.save_data.get("team", []) as Array).size()]

func _layout_hud() -> void:
	if header == null:
		return
	var viewport := get_viewport_rect().size
	var width := viewport.x
	var height := viewport.y
	var margin := 16.0 if width < 1050 else 24.0
	var compact := width < 1100
	var narrow := width < 780
	header.position = Vector2(margin, margin)
	header.size = Vector2(273, 54)
	# Keep the central plaza and NPC fully visible; utility panels stay at screen edges.
	status_panel.position = Vector2(margin, margin + 62)
	status_panel.size = Vector2(minf(330.0 if compact else 393.0, width - 2.0 * margin), 48)
	party_panel.position = Vector2(margin, margin + 119) if narrow else Vector2(width - margin - 315, margin)
	party_panel.size = Vector2(315, 56)
	gm_button.position = Vector2(width - margin - 120, height - margin - 44)
	if pet_bag != null:
		pet_bag.position = Vector2(margin, margin + 174) if narrow else Vector2(maxf(margin, (width - minf(940.0, width - 2.0 * margin)) * 0.5), maxf(margin + 70.0, (height - minf(540.0, height - 2.0 * margin)) * 0.5))
		pet_bag.size = Vector2(minf(940.0, width - 2.0 * margin), minf(540.0, height - margin - 186.0) if narrow else minf(540.0, height - 2.0 * margin))
	nav_panel.position = Vector2(margin, height - margin - 53)
	nav_panel.size = Vector2(minf(555.0, width - 2.0 * margin), 53)
	var dialogue_width := minf(680.0, width - 2.0 * margin)
	dialogue.position = Vector2((width - dialogue_width) * 0.5, height - margin - 214)
	dialogue.size = Vector2(dialogue_width, 202)
	near_hint.size = Vector2(240, 34)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 14 if narrow else 16)
	_update_camera()

func _build_dialogue() -> void:
	dialogue = PanelContainer.new()
	dialogue.name = "GuideDialogue"
	dialogue.custom_minimum_size = Vector2(0, 202)
	dialogue.add_theme_stylebox_override("panel", card_style(Color(0.02, 0.12, 0.14, 0.96)))
	dialogue.visible = false
	add_child(dialogue)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	dialogue.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	box.add_child(heading)
	heading.add_child(_make_icon("guide"))
	var speaker := Label.new()
	speaker.text = "关卡向导"
	speaker.add_theme_color_override("font_color", Color("#f3d591"))
	speaker.add_theme_font_size_override("font_size", 21)
	heading.add_child(speaker)
	var speech := Label.new()
	speech.text = "历练之路已开放，要查看可挑战的副本吗？"
	speech.add_theme_color_override("font_color", Color("#fff0c9"))
	speech.add_theme_font_size_override("font_size", 18)
	box.add_child(speech)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var open := Button.new()
	open.name = "OpenStages"
	open.text = "查看关卡"
	open.custom_minimum_size = Vector2(130, 47)
	open.pressed.connect(func() -> void: GameManager.goto_scene("stages"))
	actions.add_child(open)
	var cancel := Button.new()
	cancel.name = "CloseDialogue"
	cancel.text = "稍后再说"
	cancel.custom_minimum_size = Vector2(130, 47)
	cancel.pressed.connect(close_dialogue)
	actions.add_child(cancel)

func _unhandled_input(event: InputEvent) -> void:
	if exploration_tools != null and exploration_tools.is_open():
		return
	if gm_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			gm_panel.hide()
		return
	if pet_bag.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			toggle_pet_bag()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not dialogue.visible:
		var click: Vector2 = (event as InputEventMouseButton).position
		if party_panel.get_global_rect().has_point(click):
			return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * click + camera_offset
		if city_map.WALKABLE_AREA.has_point(point) or city_map.GATE_APPROACH.has_point(point):
			set_destination(point)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not dialogue.visible:
		if player_foot.distance_to(NPC_FOOT) <= TALK_DISTANCE:
			open_dialogue()

func set_destination(point: Vector2) -> void:
	path_points = city_map.find_path(player_foot, point)
	destination = city_map.nearest_walkable(point)
	has_destination = not path_points.is_empty()
	waiting_for_npc = false

func request_npc_conversation() -> void:
	if dialogue.visible or gm_panel.visible:
		return
	if player_foot.distance_to(NPC_FOOT) <= TALK_DISTANCE:
		open_dialogue()
	else:
		set_destination(NPC_FOOT + (player_foot - NPC_FOOT).normalized() * (TALK_DISTANCE - 18.0))
		waiting_for_npc = has_destination

func open_dialogue() -> void:
	if player_foot.distance_to(NPC_FOOT) > TALK_DISTANCE:
		return
	has_destination = false
	path_points.clear()
	waiting_for_npc = false
	dialogue.show()

func close_dialogue() -> void:
	dialogue.hide()

func _process(delta: float) -> void:
	if exploration_tools != null and exploration_tools.is_open():
		player_model.update_movement(Vector2.ZERO, 0)
		return
	var previous_foot := player_foot
	var direction := Vector2.ZERO
	if not dialogue.visible and not pet_bag.visible and not gm_panel.visible:
		direction = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))).normalized()
		if direction != Vector2.ZERO:
			has_destination = false
			path_points.clear()
			waiting_for_npc = false
		elif has_destination and not path_points.is_empty():
			while not path_points.is_empty() and player_foot.distance_to(path_points[0]) <= 3.0:
				path_points.pop_front()
			if path_points.is_empty():
				has_destination = false
				if waiting_for_npc:
					open_dialogue()
			else:
				direction = (path_points[0] - player_foot).normalized()
	if direction != Vector2.ZERO:
		var step := direction * walk_speed * delta
		if has_destination and not path_points.is_empty() and step.length() > player_foot.distance_to(path_points[0]):
			step = path_points[0] - player_foot
		move_with_collision(step)
		if waiting_for_npc and player_foot.distance_to(NPC_FOOT) <= TALK_DISTANCE:
			open_dialogue()
	player_model.update_movement(player_foot - previous_foot, delta)
	_update_actors(delta)
	_update_camera()
	if exit_armed and not dialogue.visible and not pet_bag.visible and not gm_panel.visible:
		for exit_data: Dictionary in city_map.EXIT_REGIONS:
			if (exit_data["area"] as Rect2).has_point(player_foot):
				exit_armed = false
				GameManager.enter_region(str(exit_data["id"]), exit_data["arrival"])
				break

func _update_camera() -> void:
	var view: Vector2 = get_viewport_rect().size
	camera_offset = Vector2(clampf(player_foot.x - view.x * 0.5, 0.0, maxf(0.0, city_map.WORLD_SIZE.x - view.x)), clampf(player_foot.y - view.y * 0.66, 0.0, maxf(0.0, city_map.WORLD_SIZE.y - view.y)))
	city_map.position = -camera_offset
	actor_layer.position = -camera_offset
	var hint_point: Vector2 = NPC_FOOT - camera_offset + Vector2(-118, -168)
	near_hint.position = Vector2(clampf(hint_point.x, 12.0, maxf(12.0, get_viewport_rect().size.x - 250.0)), clampf(hint_point.y, 130.0, maxf(130.0, get_viewport_rect().size.y - 75.0)))
	if nav_label != null:
		nav_label.text = "WASD / 点击移动   ·   靠近向导按 E" if player_foot.x < 1400.0 else "沿东侧道路向北进入城门   ↑"

func move_with_collision(step: Vector2) -> void:
	# Swept axis test in small increments prevents tunnelling through narrow blockers.
	var count := maxi(1, ceili(step.length() / 5.0))
	var slice := step / count
	for index in range(count):
		var next_x := player_foot + Vector2(slice.x, 0)
		if city_map.is_walkable(next_x):
			player_foot.x = next_x.x
		var next_y := player_foot + Vector2(0, slice.y)
		if city_map.is_walkable(next_y):
			player_foot.y = next_y.y

func _update_actors(_delta: float) -> void:
	npc.position = NPC_FOOT
	var npc_scale := lerpf(0.68, 0.96, (NPC_FOOT.y - city_map.BOUNDS.position.y) / city_map.BOUNDS.size.y)
	npc.scale = Vector2.ONE * npc_scale
	var depth: float = (player_foot.y - city_map.BOUNDS.position.y) / city_map.BOUNDS.size.y
	var scale_factor := lerpf(0.68, 1.02, depth)
	avatar.position = player_foot
	avatar.visible = false
	for child in actor_layer.get_children():
		if child.has_meta("player_model"):
			child.position = player_foot
			child.scale = Vector2.ONE * scale_factor * HeroWalkScript.BASE_SCALE
			child.z_index = int(player_foot.y)
	# Foreground actors render over actors farther up the avenue.
	avatar.z_index = int(player_foot.y)
	npc.z_index = int(NPC_FOOT.y)
	near_hint.text = "按 E 与关卡向导交谈" if player_foot.distance_to(NPC_FOOT) <= TALK_DISTANCE and not dialogue.visible else ""
