extends Control
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Ecology = preload("res://scripts/scenes/weather_ecology.gd")
const Traps = preload("res://scripts/scenes/trap_catalog.gd")
const Bosses = preload("res://scripts/scenes/boss_catalog.gd")
signal travel_requested(region: String)
signal closed
var current_region := "city"
var selected_region := "city"
var resource_provider: Callable
var can_travel := false
var map_surface: Control
var detail: VBoxContainer
var region_buttons: Dictionary = {}
var travel_button: Button

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
		node.custom_minimum_size = Vector2(104, 28)
		node.add_theme_font_size_override("font_size", 14 if id in Maps.IDS else 16)
		for state: String in ["normal", "hover", "pressed"]:
			var skin: StyleBoxFlat = node.get_theme_stylebox(state).duplicate()
			skin.content_margin_left = 8
			skin.content_margin_right = 8
			skin.content_margin_top = 2
			skin.content_margin_bottom = 2
			if not _boss_names(id).is_empty():
				skin.border_color = Color("#d69b7d")
			node.add_theme_stylebox_override(state, skin)
		node.tooltip_text = str(data.name) + ("\n首领：" + _boss_names(id) if not _boss_names(id).is_empty() else "")
		map_surface.add_child(node)
		node.size = Vector2(104, 28) if id in Maps.IDS else Vector2(132, 32)
		region_buttons[id] = node
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size.x = 410
	detail_panel.add_theme_stylebox_override("panel", UI.panel())
	columns.add_child(detail_panel)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 14)
	scroll.add_child(detail)
	travel_button = UI.button("前往此地", _request_travel)
	travel_button.name = "TravelButton"
	detail_column.add_child(travel_button)
	travel_button.hide()
	layout.add_child(UI.label("福地按本轮剩余份数分级：1 极稀缺 · 2–3 稀缺 · 4–6 适中 · 7+ 丰富。", 16, Color("#9db7af")))
	_place_regions()
	hide()

func _place_regions() -> void:
	for id: String in region_buttons:
		region_buttons[id].position = _map_position(id) - region_buttons[id].size * 0.5
	map_surface.queue_redraw()

func _ring_center() -> Vector2:
	return Vector2(map_surface.size.x * 0.5, (88.0 + map_surface.size.y - 12.0) * 0.5)

func _outer_radius() -> float:
	return maxf(1.0, minf((map_surface.size.y - 100.0) * 0.5, (map_surface.size.x - 128.0) * 0.5))

func _map_position(id: String) -> Vector2:
	if current_region == "water_activity" and id == "water_activity":
		return map_surface.size * 0.5
	var inner := id in Maps.INNER_RING
	var ring: Array = Maps.INNER_RING if inner else Maps.OUTER_RING
	var index := ring.find(id)
	if index >= 0:
		var angle := -PI * 0.5 + TAU * float(index) / ring.size()
		return _ring_center() + Vector2.from_angle(angle) * _outer_radius() * (0.5 if inner else 1.0)
	return Vector2(Catalog.REGIONS[id].point.x * map_surface.size.x, 30)

func _boss_names(id: String) -> String:
	var names := PackedStringArray()
	for config: Dictionary in Bosses.DEFINITIONS.values():
		if config.region == id:
			names.append(config.name)
	return " / ".join(names)

func _draw_map() -> void:
	if current_region == "water_activity":
		map_surface.draw_string(ThemeDB.fallback_font, Vector2(24, 90), "海底水世界 · 海面浮台", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#d7c18b"))
		return
	for pair: Array in [["city", "outskirts"]]:
		map_surface.draw_line(_map_position(pair[0]), _map_position(pair[1]), Color("#557e75"), 2, true)
	var center := _ring_center()
	var radius := _outer_radius()
	map_surface.draw_circle(center, radius, Color(0.49, 0.65, 0.60, 0.045))
	map_surface.draw_circle(center, radius * 0.5, Color(0.86, 0.72, 0.43, 0.065))
	map_surface.draw_arc(center, radius, 0, TAU, 128, Color("#79aaa0"), 3, true)
	map_surface.draw_arc(center, radius * 0.5, 0, TAU, 96, Color("#c2ac73"), 3, true)
	for i in range(Maps.INNER_RING.size()):
		map_surface.draw_line(_map_position(Maps.INNER_RING[i]), _map_position(Maps.OUTER_RING[i]), Color("#557e75"), 2, true)
	for id: String in Maps.IDS:
		if not _boss_names(id).is_empty():
			var marker := _map_position(id) + Vector2(region_buttons[id].size.x * 0.5 + 9, 0)
			map_surface.draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -5), marker + Vector2(5, 0), marker + Vector2(0, 5), marker + Vector2(-5, 0)]), Color("#eeaa86"))
	var font := ThemeDB.fallback_font
	map_surface.draw_string(font, Vector2(8, 72), "福地 · 大环套小环", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d7c18b"))
	map_surface.draw_string(font, Vector2(8, map_surface.size.y - 12), "◆ 首领驻地", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#eeaa86"))
	map_surface.draw_string(font, center + Vector2(-28, 5), "内环", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d7c18b"))
	map_surface.draw_string(font, Vector2(center.x + radius + 18, center.y + 5), "外环", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#9cbdb3"))

func open(region: String) -> void:
	current_region = region
	for id: String in region_buttons:
		region_buttons[id].visible = _region_available(id)
	_place_regions()
	show()
	select_region(region)

func _region_available(id: String) -> bool:
	return (id == "water_activity") == (current_region == "water_activity")

func _request_travel() -> void:
	if not can_travel or not _region_available(selected_region) or selected_region not in Maps.IDS:
		return
	travel_requested.emit(selected_region)
	close()

func close() -> void:
	hide()
	closed.emit()

func _line(text: String, font_size: int = 18, color: Color = Color("#dfebe3")) -> void:
	var node := UI.label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(node)

func select_region(id: String) -> void:
	if not Catalog.REGIONS.has(id) or not _region_available(id):
		return
	selected_region = id
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	for key: String in region_buttons:
		region_buttons[key].modulate = Color("#ffe3a1") if key == id else Color.WHITE
	var data: Dictionary = Catalog.REGIONS[id]
	travel_button.visible = can_travel and data.game == "福地"
	travel_button.text = "继续探索" if id == current_region else "前往此地"
	_line(str(data.name), 28, Color("#f0d69a"))
	_line(str(data.game) + ("  ·  当前位置" if id == current_region else "  ·  资源概览"), 16)
	if id in Maps.IDS:
		_line(("内环" if id in Maps.INNER_RING else "外环") + " · 环路可双向行走，辐射通道连接内外环", 16, Color("#d7c18b"))
	_line(str(data.note))
	var building_provider: Callable = get_meta("building_provider", Callable())
	if building_provider.is_valid() and data.game == "福地":
		_line("大型建筑：" + str(building_provider.call(id)), 17, Color("#b9dfc9"))
	var chest_provider: Callable = get_meta("chest_provider", Callable())
	if chest_provider.is_valid() and data.game == "福地":
		_line("宝箱：" + str(chest_provider.call(id)), 17, Color("#d6b0ed"))
	var loot_provider: Callable = get_meta("loot_provider", Callable())
	if loot_provider.is_valid() and data.game == "福地":
		_line("装备掉落：" + str(loot_provider.call(id)), 17, Color("#ebd3a1"))
	var boss_provider: Callable = get_meta("boss_provider", Callable())
	if boss_provider.is_valid() and data.game == "福地":
		_line("首领：" + str(boss_provider.call(id)), 17, Color("#f1ba94"))
	if Traps.REGIONS.has(id):
		_line(Traps.describe(id), 16, Color("#eac591"))
	if Ecology.CLIMATES.has(id):
		var provider: Callable = get_meta("weather_provider", Callable())
		_line("天气：" + (str(provider.call(id)) if provider.is_valid() else Ecology.describe(id) + "（开局预览）"), 17, Color("#b8d8eb"))
		_line("气候轮换：" + Ecology.weather_names(Ecology.CLIMATES[id].cycle), 16)
		for item: String in Ecology.CLIMATES[id].plants:
			_line("再生%s：%s · %.0f秒成熟" % [Catalog.ITEMS[item].name, Ecology.weather_names(Ecology.PLANTS[item].weather), Ecology.PLANTS[item].time], 16)
		if not provider.is_valid():
			var weather: Dictionary = Ecology.WEATHER[Ecology.weather_at(id, 0)]
			_line("开局怪物：%s · 生命%d · 接触伤害%d · 掉落%s" % [weather.monster, weather.hp, weather.damage, Catalog.ITEMS[weather.drop].name], 16)
	var resources: Dictionary = data.resources
	if resources.is_empty():
		_line("物品种类：0\n稀缺程度：不适用（无采集点）", 19)
	elif data.game == "福地":
		var area: Dictionary = Maps.MAPS[id]
		_line("活动范围 %d × %d  ·  %s" % [int(area.size.x), int(area.size.y), area.npc], 17)
		_line("地标：" + " → ".join(PackedStringArray([area.sites[0][0], area.sites[1][0], area.sites[2][0]])), 16)
		var exits := PackedStringArray()
		for exit: Array in area.exits:
			exits.append(Catalog.REGIONS[exit[0]].name)
		_line("出口：" + " / ".join(exits), 16)
		var remaining: Dictionary = resource_provider.call(id) if resource_provider.is_valid() else resources.duplicate()
		_line("野生物品种类：%d  /  %s" % [resources.size(), "本轮剩余 / 开局野生份数（含再生与掉落，可超出开局）" if resource_provider.is_valid() else "初始配置份数"], 17)
		for item: String in resources:
			var count := int(remaining.get(item, 0))
			_line("%s   %d / %d   ·   %s" % [Catalog.ITEMS[item].name, count, int(resources[item]), Catalog.scarcity(count)], 20, Color(Catalog.ITEMS[item].color))
		for item: String in remaining:
			if not resources.has(item) and int(remaining[item]) > 0:
				_line("%s   %d 份 · 生长 / 怪物掉落" % [Catalog.ITEMS[item].name, int(remaining[item])], 18, Color(Catalog.ITEMS[item].color))
		if not can_travel:
			_line("在游戏入口选择“福地”即可探索。", 16)
	else:
		_line("物品种类：%d  ·  可再生 / 加工产物" % resources.size(), 17)
		for item: String in resources:
			_line("%s：%s" % [Catalog.ITEMS[item].name, resources[item]], 18, Color(Catalog.ITEMS[item].color))
