extends Node
## 全局弹窗层级；场景切换时随原场景一起销毁。
var popup: Control

func show_popup(title: String, message: String, action_text: String = "确定", on_accept: Callable = Callable()) -> void:
	close_popup()
	popup = ColorRect.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.color = Color(0.08, 0.13, 0.22, 0.7)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(popup)
	var panel := PanelContainer.new()
	panel.position = (get_viewport().get_visible_rect().size - Vector2(410, 230)) * 0.5
	panel.size = Vector2(410, 230)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#143c41")
	style.border_color = Color("#e5c986")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	popup.add_child(panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.93, 0.93)
	panel.pivot_offset = Vector2(205, 115)
	var entrance := get_tree().create_tween()
	entrance.tween_property(panel, "modulate:a", 1.0, 0.22)
	entrance.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("#ffe5a8"))
	box.add_child(heading)
	var body := Label.new()
	body.custom_minimum_size.y = 100
	body.text = message
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color("#eaf5e8"))
	box.add_child(body)
	var button := Button.new()
	button.text = action_text
	box.add_child(button)
	button.pressed.connect(func() -> void:
		close_popup()
		if on_accept.is_valid():
			on_accept.call()
	)

func close_popup() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = null
