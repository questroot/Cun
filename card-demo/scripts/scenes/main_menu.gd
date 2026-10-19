extends Control
## Shared game entry; individual game saves stay separate.
const Atlas = preload("res://scripts/scenes/world_atlas.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var atlas: Atlas
func _ready() -> void:
	DisplayServer.window_set_title("Cun · 游戏选择")
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
	panel_back.offset_top = -640
	panel_back.offset_right = 260
	panel_back.offset_bottom = -30
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_back)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -220
	panel.offset_top = -620
	panel.offset_right = 220
	panel.offset_bottom = -50
	panel.custom_minimum_size = Vector2(440, 224)
	panel.add_theme_constant_override("separation", 16)
	add_child(panel)
	var title := Label.new()
	title.text = "选择游戏"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#fff2cd"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "灵伴 · 回合冒险    /    福地 · 即时战斗"
	subtitle.add_theme_color_override("font_color", Color("#e2f6e6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)
	var button := Button.new()
	button.name = "EnterSpirit"
	button.text = "进入灵伴回合冒险"
	button.custom_minimum_size.y = 55
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#26817b")
	button_style.border_color = Color("#f5d68d")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(13)
	button.add_theme_stylebox_override("normal", button_style)
	panel.add_child(button)
	button.pressed.connect(func() -> void: GameManager.goto_scene("city"))
	var fudi := UI.button("进入福地  ·  动作试玩", func() -> void: GameManager.goto_scene("fudi"))
	fudi.name = "EnterFudi"
	panel.add_child(fudi)
	var controls := UI.label("WASD 移动 · J 斩击 · K 灵弹 · L 震荡\nM 地图 / 资源分布 / 区域切换\n福地进度仅保留在本次游玩。", 17)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(controls)
	panel.add_child(UI.button("查看地图与物品分布", func() -> void: atlas.open("city")))
	panel.add_child(UI.button("退出游戏", func() -> void: get_tree().quit()))
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	atlas = Atlas.new()
	layer.add_child(atlas)

func _unhandled_input(event: InputEvent) -> void:
	if atlas.visible and event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_M]:
		atlas.close()
