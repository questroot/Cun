extends "res://scripts/scenes/world_atlas.gd"
const Chart = preload("res://scripts/scenes/sea_survey_chart.gd")
const Dive = preload("res://scripts/scenes/underwater_catalog.gd")
const SHEETS := ["water_activity", "shoal", "wreck", "trench"]
const NAMES := ["漂流浮台", "珊瑚浅滩", "沉船区", "深海沟"]
var sheet_buttons: Dictionary = {}
var chart: Chart
var caption: Label
var brief: Label
var legend: Label
var sheet := "water_activity"

func _ready() -> void:
	super._ready()
	# Keep the shared atlas API and its region/travel guards, not its land layout.
	get_child(1).hide()
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["top", "bottom", "left", "right"]: page.add_theme_constant_override("margin_" + side, 28)
	add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	page.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := UI.label("海域测绘簿", 32, Chart.BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.label("港务处   /   HYDROGRAPHIC OFFICE    ", 16, Chart.GLASS))
	head.add_child(UI.button("合图   M / Esc", close))
	column.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var index := VBoxContainer.new()
	index.custom_minimum_size.x = 196
	index.add_theme_constant_override("separation", 10)
	body.add_child(index)
	index.add_child(UI.label("图幅索引   /   04", 18, Chart.GLASS))
	for i in SHEETS.size():
		var id: String = SHEETS[i]
		var button := UI.button("%02d   %s" % [i, NAMES[i]], _sheet.bind(id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		index.add_child(button)
		sheet_buttons[id] = button
	index.add_child(HSeparator.new())
	legend = UI.label("", 17, Chart.GLASS)
	index.add_child(legend)
	var plate := VBoxContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(plate)
	caption = UI.label("", 23, Chart.BRASS)
	plate.add_child(caption)
	chart = Chart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.resized.connect(chart.queue_redraw)
	plate.add_child(chart)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plate.add_child(scroll)
	brief = UI.label("", 19)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(brief)
	scroll.name = "Soundings"
	column.add_child(UI.label("↑ ↓ 切图幅    ·    PgUp / PgDn 翻阅物资    ·    M / Esc 合图    |    此图只读，不提供传送。", 16, Chart.GLASS))

func open(region: String) -> void:
	if region != "water_activity": return
	super.open(region)
	_sheet(region)
	sheet_buttons[region].grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			var step := -1 if event.keycode in [KEY_UP, KEY_LEFT] else 1
			_sheet(SHEETS[posmod(SHEETS.find(sheet) + step, SHEETS.size())])
			sheet_buttons[sheet].grab_focus()
		KEY_PAGEUP, KEY_PAGEDOWN:
			var scroll := brief.get_parent() as ScrollContainer
			scroll.scroll_vertical += int(scroll.size.y) * (-1 if event.keycode == KEY_PAGEUP else 1)
		_:
			return
	get_viewport().set_input_as_handled()

func _sheet(id: String) -> void:
	sheet = id
	(brief.get_parent() as ScrollContainer).scroll_vertical = 0
	for key: String in sheet_buttons: sheet_buttons[key].set_pressed_no_signal(key == id)
	var i := SHEETS.find(id)
	caption.text = "图幅 %02d    /    %s" % [i, NAMES[i]]
	var base := id == "water_activity"
	legend.text = "图例\n\n●   当前漂材\n金框   自有甲板\n青块   设施站位" if base else "图例\n\n●   调查点 / 通路\n○   安全上浮范围\n▪   打捞箱位\n▧   不可通行地形"
	chart.place = id
	chart.queue_redraw()
	if base:
		var sea = get_parent().get_parent()
		chart.tiles = sea.raft_tiles
		chart.drift = sea.debris.duplicate()
		chart.harbor = sea.SEA
		caption.text += "    ·    港区甲板与近岸漂材"
		var rows := PackedStringArray(["港站补给   /   海面物资来源"])
		var supplies: Dictionary = Catalog.REGIONS[id].resources
		for key: String in supplies: rows.append("%s　 %s" % [Catalog.ITEMS[key].name, supplies[key]])
		brief.text = "\n".join(rows)
	else:
		var items := PackedStringArray()
		for item in Dive.POOLS[id]: items.append(Dive.item_name(item))
		brief.text = "测区记录   /   %d 处箱位　 ·　%s\n基础耗氧倍率   ×%s　　绿色圆圈内可向上浮光柱撤离。" % [Dive.NODES[id].size(), "、".join(items), str(Dive.RATES[id])]
	# Give most of the sheet to its plan, keeping the station manifest scrollable.
	chart.size_flags_stretch_ratio = 2.6 if base else 5.0
