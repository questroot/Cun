extends Control
## 主菜单：创建按钮并进入主城。
func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/menu_pet_garden.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# The dormant menu uses the same illustrated world as the active city and team UI.
	var artwork := TextureRect.new()
	artwork.name = "FullMenuArtwork"
	artwork.texture = load("res://assets/backgrounds/menu_pet_garden.png")
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	var panel_back := ColorRect.new()
	panel_back.color = Color(0.025, 0.12, 0.13, 0.78)
	panel_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel_back.offset_left = -260
	panel_back.offset_top = -294
	panel_back.offset_right = 260
	panel_back.offset_bottom = -30
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_back)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -220
	panel.offset_top = -274
	panel.offset_right = 220
	panel.offset_bottom = -50
	panel.custom_minimum_size = Vector2(440, 224)
	panel.add_theme_constant_override("separation", 16)
	add_child(panel)
	var title := Label.new()
	title.text = "灵伴回合冒险"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#fff2cd"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "单机 · 九宫布阵 · 先手回合制"
	subtitle.add_theme_color_override("font_color", Color("#e2f6e6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var button := Button.new()
	button.text = "开始游戏"
	button.custom_minimum_size.y = 55
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#26817b")
	button_style.border_color = Color("#f5d68d")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(13)
	button.add_theme_stylebox_override("normal", button_style)
	panel.add_child(button)
	panel.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(panel, "modulate:a", 1.0, 0.55)
	intro.parallel().tween_property(panel, "offset_top", panel.offset_top, 0.55).from(panel.offset_top + 20).set_trans(Tween.TRANS_BACK)
	button.pressed.connect(func() -> void: GameManager.goto_scene("city"))
