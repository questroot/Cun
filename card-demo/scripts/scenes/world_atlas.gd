extends Control
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
signal travel_requested(region: String)
signal closed
var current_region := "city"
var selected_region := "city"
var resource_provider: Callable
var can_travel := false
var map_surface: Control
var detail: VBoxContainer
var region_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.05, 0.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := UI.label("山海舆图  /  资源分布", 30, Color("#f0d69a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(UI.button("关闭  M / Esc", close))
	layout.add_child(UI.label("点击地图上的区域，查看物品种类、数量与稀缺程度。", 18))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", UI.panel(Color("#162c31")))
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(map_panel)
	map_surface = Control.new()
	map_surface.custom_minimum_size = Vector2(480, 380)
	map_panel.add_child(map_surface)
	map_surface.draw.connect(_draw_map)
	map_surface.resized.connect(_place_regions)
	for id: String in Catalog.REGIONS:
		var data: Dictionary = Catalog.REGIONS[id]
		var node := UI.button(str(data.name), select_region.bind(id))
		node.name = "Region_" + id
		node.size = Vector2(148, 56)
		map_surface.add_child(node)
		region_buttons[id] = node
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size.x = 410
	detail_panel.add_theme_stylebox_override("panel", UI.panel())
	columns.add_child(detail_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 14)
	scroll.add_child(detail)
	layout.add_child(UI.label("福地按本轮剩余份数分级：1 极稀缺 · 2–3 稀缺 · 4–6 适中 · 7+ 丰富。", 16, Color("#9db7af")))
	_place_regions()
	hide()

func _place_regions() -> void:
	for id: String in region_buttons:
		var point: Vector2 = Catalog.REGIONS[id].point
		region_buttons[id].position = point * map_surface.size - region_buttons[id].size * 0.5
	map_surface.queue_redraw()

func _draw_map() -> void:
	var pairs := [["city", "outskirts"], ["outskirts", "water_activity"], ["grove", "quarry"], ["quarry", "ruins"]]
	for pair: Array in pairs:
		map_surface.draw_line(Catalog.REGIONS[pair[0]].point * map_surface.size, Catalog.REGIONS[pair[1]].point * map_surface.size, Color("#557e75"), 3, true)
	var font := ThemeDB.fallback_font
	map_surface.draw_string(font, Vector2(16, 34), "灵伴 · 云庭诸域", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#9cbdb3"))
	map_surface.draw_string(font, Vector2(16, map_surface.size.y * 0.49), "福地 · 三境探访", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d7c18b"))

func open(region: String) -> void:
	current_region = region
	show()
	select_region(region)

func close() -> void:
	hide()
	closed.emit()

func _line(text: String, font_size: int = 18, color: Color = Color("#dfebe3")) -> void:
	var node := UI.label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(node)

func select_region(id: String) -> void:
	if not Catalog.REGIONS.has(id):
		return
	selected_region = id
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	for key: String in region_buttons:
		region_buttons[key].modulate = Color("#ffe3a1") if key == id else Color.WHITE
	var data: Dictionary = Catalog.REGIONS[id]
	_line(str(data.name), 28, Color("#f0d69a"))
	_line(str(data.game) + ("  ·  当前位置" if id == current_region else "  ·  资源概览"), 16)
	_line(str(data.note))
	var resources: Dictionary = data.resources
	if resources.is_empty():
		_line("物品种类：0\n稀缺程度：不适用（无采集点）", 19)
	elif data.game == "福地":
		var remaining: Dictionary = resource_provider.call(id) if resource_provider.is_valid() else resources.duplicate()
		_line("物品种类：%d  /  %s" % [resources.size(), "本轮剩余 / 初始份数" if resource_provider.is_valid() else "初始配置份数"], 17)
		for item: String in resources:
			var count := int(remaining.get(item, 0))
			_line("%s   %d / %d   ·   %s" % [Catalog.ITEMS[item].name, count, int(resources[item]), Catalog.scarcity(count)], 20, Color(Catalog.ITEMS[item].color))
		if can_travel:
			var travel := UI.button("继续探索" if id == current_region else "前往此地", func() -> void: travel_requested.emit(id); close())
			detail.add_child(travel)
		else:
			_line("在游戏入口选择“福地”即可探索。", 16)
	else:
		_line("物品种类：%d  ·  可再生 / 加工产物" % resources.size(), 17)
		for item: String in resources:
			_line("%s：%s" % [Catalog.ITEMS[item].name, resources[item]], 18, Color(Catalog.ITEMS[item].color))
