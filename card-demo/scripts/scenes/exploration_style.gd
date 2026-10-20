extends RefCounted

static func panel(color: Color = Color("#142d32")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#6c9187")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	return style

static func label(text: String, font_size: int = 18, color: Color = Color("#dfebe3")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

static func hud_panel(color: Color) -> StyleBoxFlat:
	var skin := panel(color)
	skin.border_color = Color(0.55, 0.7, 0.65, 0.3)
	skin.set_corner_radius_all(8)
	skin.content_margin_left = 10
	skin.content_margin_right = 10
	skin.content_margin_top = 6
	skin.content_margin_bottom = 6
	return skin

static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	for state: String in ["normal", "hover", "pressed"]:
		var color: Color = {"normal": Color("#254b4b"), "hover": Color("#356361"), "pressed": Color("#3c7167")}[state]
		var skin := panel(color)
		skin.content_margin_top = 8
		skin.content_margin_bottom = 8
		node.add_theme_stylebox_override(state, skin)
	node.add_theme_font_size_override("font_size", 18)
	node.pressed.connect(action)
	return node
