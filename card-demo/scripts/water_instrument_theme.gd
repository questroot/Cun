extends RefCounted
## Local to the sea chapter. Fixed control footprints also serve as hit targets.

static func _plate(fill: String, rim: String, radius: int, x_pad: int = 5, y_pad: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill)
	box.border_color = Color(rim)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = x_pad
	box.content_margin_right = x_pad
	box.content_margin_top = y_pad
	box.content_margin_bottom = y_pad
	return box

static func build() -> Theme:
	var t := Theme.new()
	var normal := _plate("193844", "42636b", 5)
	var hover := _plate("24535c", "89cabb", 5)
	var active := _plate("16565b", "81d6c4", 5)
	var disabled := _plate("172c35", "30444a", 5)
	var focus := _plate("00000000", "f7cd85", 5)
	focus.draw_center = false
	focus.set_border_width_all(2)
	for kind in [&"Button", &"OptionButton", &"MenuButton"]:
		for pair in [[&"normal", normal], [&"hover", hover], [&"pressed", active], [&"hover_pressed", active], [&"disabled", disabled], [&"focus", focus]]:
			t.set_stylebox(pair[0], kind, pair[1])
		t.set_color(&"font_color", kind, Color("dfefeb"))
		t.set_color(&"font_hover_color", kind, Color("ffffff"))
		t.set_color(&"font_pressed_color", kind, Color("ffdfa2"))
		t.set_color(&"font_disabled_color", kind, Color("95aaa9"))
	# Use compact padding: several navigation buttons are intentionally only 72 px wide.
	t.set_type_variation(&"HarborPrimary", &"Button")
	t.set_stylebox(&"normal", &"HarborPrimary", _plate("23625f", "7cbba8", 5))
	t.set_stylebox(&"hover", &"HarborPrimary", _plate("31756d", "a3e1c7", 5))
	t.set_type_variation(&"HarborLaunch", &"Button")
	for pair in [[&"normal", "e9bc76"], [&"hover", "ffdaa0"], [&"pressed", "cda361"]]:
		t.set_stylebox(pair[0], &"HarborLaunch", _plate(pair[1], "ffe0a5", 5))
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		t.set_color(state, &"HarborLaunch", Color("202f32"))
	var panel := _plate("102832", "41636b", 6, 8, 6)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)
	t.set_stylebox(&"panel", &"AcceptDialog", _plate("102630", "46636b", 6, 10, 16))
	t.set_stylebox(&"panel", &"PopupMenu", _plate("112b35", "547981", 5, 6, 5))
	t.set_stylebox(&"hover", &"PopupMenu", hover)
	t.set_color(&"font_color", &"Label", Color("dceae6"))
	t.set_color(&"default_color", &"RichTextLabel", Color("dceae6"))
	var tab := _plate("1a3943", "36575e", 3)
	var selected := _plate("285450", "8ccfba", 3)
	selected.border_width_bottom = 3
	for kind in [&"TabBar", &"TabContainer"]:
		t.set_stylebox(&"tab_unselected", kind, tab)
		t.set_stylebox(&"tab_selected", kind, selected)
		t.set_stylebox(&"tab_hovered", kind, hover)
		t.set_stylebox(&"tab_focus", kind, focus)
		t.set_color(&"font_selected_color", kind, Color("fff1ca"))
	t.set_stylebox(&"panel", &"TabContainer", _plate("112b35", "42636b", 4, 3, 3))
	for kind in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", kind, _plate("112730", "23434b", 3, 4, 4))
		t.set_stylebox(&"grabber", kind, _plate("527b80", "6b9391", 3, 4, 4))
		t.set_stylebox(&"grabber_highlight", kind, _plate("719d99", "99c8be", 3, 4, 4))
		t.set_stylebox(&"grabber_pressed", kind, active)
	t.set_stylebox(&"normal", &"LineEdit", _plate("091e28", "3e6068", 4, 8, 4))
	t.set_stylebox(&"read_only", &"LineEdit", disabled)
	t.set_stylebox(&"focus", &"LineEdit", focus)
	t.set_color(&"caret_color", &"LineEdit", Color("92ddc5"))
	t.set_color(&"selection_color", &"LineEdit", Color("316265"))
	t.set_type_variation(&"HarborHeading", &"Label")
	t.set_font_size(&"font_size", &"HarborHeading", 22)
	t.set_color(&"font_color", &"HarborHeading", Color("f4dfb0"))
	t.set_type_variation(&"HarborCaption", &"Label")
	t.set_color(&"font_color", &"HarborCaption", Color("a4d0c6"))
	return t
