extends CanvasLayer
const Atlas = preload("res://scripts/scenes/world_atlas.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var region := "city"
var atlas: Atlas
var confirm: Control
var confirm_ok: Button
var modal_blocker: Callable

func _ready() -> void:
	layer = 90
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 158)
	if region == "water_activity":
		bar.position = Vector2(500, 23)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	bar.add_child(UI.button("地图  M", open_map))
	bar.add_child(UI.button("切换游戏", switch_game))
	if get_parent().has_method("configure_exploration_actions"):
		get_parent().configure_exploration_actions(bar)
	atlas = Atlas.new()
	add_child(atlas)
	confirm = Control.new()
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(confirm)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.06, 0.85)
	confirm.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -130
	panel.offset_bottom = 130
	panel.add_theme_stylebox_override("panel", UI.panel())
	confirm.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	layout.add_child(UI.label("返回游戏选择？", 26, Color("#f0d69a")))
	var message := UI.label("离开后，本次游玩的采集、战斗或水域活动进度将重置。", 19)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(message)
	confirm_ok = UI.button("返回游戏选择", func() -> void: GameManager.goto_scene("menu"))
	layout.add_child(confirm_ok)
	layout.add_child(UI.button("继续游玩  /  Esc", func() -> void: confirm.hide()))
	confirm.hide()

func is_open() -> bool:
	return atlas.visible or confirm.visible

func open_map() -> void:
	if not confirm.visible:
		atlas.open(region)

func switch_game() -> void:
	if region in Atlas.Catalog.FUDI_REGIONS or region == "water_activity":
		confirm.show()
	else:
		GameManager.goto_scene("menu")

func _input(event: InputEvent) -> void:
	if modal_blocker.is_valid() and modal_blocker.call():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if confirm.visible:
			if event.keycode == KEY_ESCAPE:
				confirm.hide()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M or (atlas.visible and event.keycode == KEY_ESCAPE):
			if atlas.visible:
				atlas.close()
			else:
				open_map()
			get_viewport().set_input_as_handled()
		elif atlas.visible:
			get_viewport().set_input_as_handled()
