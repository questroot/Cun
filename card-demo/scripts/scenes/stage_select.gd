extends Control
## 独立副本选择页，入口仅由关卡向导的对话按钮触发。
var stage_buttons: Array[Button] = []

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/backgrounds/menu_pet_garden.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.12, 0.14, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var title := Label.new()
	title.text = "历练之路 / 副本关卡"
	title.position = Vector2(95, 68)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#fff0c9"))
	add_child(title)
	var hint := Label.new()
	hint.text = "由关卡向导指引 · 选择已解锁关卡，确认阵容后进入战斗"
	hint.position = Vector2(99, 134)
	hint.add_theme_color_override("font_color", Color("#e8f5e9"))
	add_child(hint)
	var stage_list := ScrollContainer.new()
	stage_list.position = Vector2(96, 202)
	stage_list.size = Vector2(1140, 392)
	add_child(stage_list)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	stage_list.add_child(grid)
	for i in range(1, DataManager.tables["stages"].size() + 1):
		var stage_id := "stage_%d" % i
		var stage: Dictionary = DataManager.get_entry("stages", stage_id)
		var unlocked := i <= int(DataManager.save_data["unlocked_stage"])
		var button := Button.new()
		button.name = "Stage%d" % i
		button.custom_minimum_size = Vector2(212, 170)
		button.text = "第 %d 关\n%s\n敌人 Lv.%d · 经验 +%d\n%s" % [i, str(stage.get("name", stage_id)), int(stage.get("enemy_level", 1)), int(stage.get("reward_exp", 0)), "进入编队 →" if unlocked else "尚未解锁"]
		button.add_theme_font_size_override("font_size", 17)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.31, 0.30, 0.95) if unlocked else Color(0.21, 0.26, 0.27, 0.92)
		style.border_color = Color("#dbc991")
		style.set_border_width_all(3)
		style.set_corner_radius_all(16)
		button.add_theme_stylebox_override("normal", style)
		var over := style.duplicate() as StyleBoxFlat
		over.bg_color = Color("#357973")
		over.border_color = Color("#ffe4a1")
		button.add_theme_stylebox_override("hover", over)
		var focus := style.duplicate() as StyleBoxFlat
		focus.border_color = Color("#fff2c6")
		focus.set_border_width_all(5)
		button.add_theme_stylebox_override("focus", focus)
		button.disabled = not unlocked
		button.pressed.connect(func() -> void: GameManager.select_stage(stage_id))
		grid.add_child(button)
		stage_buttons.append(button)
	var back := Button.new()
	back.text = "← 返回主城"
	back.position = Vector2(96, 611)
	back.size = Vector2(180, 54)
	back.pressed.connect(func() -> void: GameManager.goto_scene("city"))
	add_child(back)
