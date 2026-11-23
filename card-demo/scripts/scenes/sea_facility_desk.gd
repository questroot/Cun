extends AcceptDialog
## Point-of-use panels for the two fixtures on the raft; all transactions stay in Technology.
const Icons := preload("res://scripts/scenes/sea_station_icons.gd")
var tech
var kind: String

func open(technology, id: String) -> void:
	tech = technology
	kind = id
	var lab := kind == "research"
	var title_text := "浮台研究台" if lab else "自动打捞器"
	var built: bool = tech.state.research_built if lab else tech.state.machine_built
	name = "ResearchBench" if lab else "SalvageConsole"
	title = title_text
	theme = tech.host.theme
	exclusive = true
	get_label().hide()
	get_ok_button().text = "返回浮台  /  Esc"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var frame := Control.new()
	add_child(frame)
	var wrap := HBoxContainer.new()
	frame.add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("separation", 16)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 200
	wrap.add_child(left)
	var plaque := VBoxContainer.new()
	left.add_child(plaque)
	plaque.add_theme_constant_override("separation", 7)
	_label(plaque, "R—01   /   LAB" if lab else "S—02   /   WINCH", 15, Color("#a9d3c8"))
	_label(plaque, title_text, 26, Color("#f2d8a3"))
	var drawing := Control.new()
	drawing.custom_minimum_size = Vector2(176, 112)
	plaque.add_child(drawing)
	drawing.draw.connect(_schematic.bind(drawing, lab))
	_label(plaque, "设施已建成" if built else "规划席位 · 尚未建造", 17, Color("#efd295"))
	_label(plaque, "海底样本分析\n研究许可签发" if lab else "目标预约与打捞\n货仓及维护补给", 15, Color("#bdd5d0"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	wrap.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)
	if lab: _lab(body)
	else: _winch(body)
	if not built:
		_label(body, "建造用料　/　" + tech._cost_text(tech.BUILD_COSTS[kind]), 15)
		_go(body, "查看建造方案", "build", kind, true)
	var bounds: Vector2i = tech.host.get_window().size.min(Vector2i(tech.host.get_viewport_rect().size))
	popup_centered(Vector2i(822, 490).min(bounds - Vector2i(48, 66)))
	get_ok_button().grab_focus()

## The raft's crafting tile is separate from the automatic salvage winch.
func open_crafter(sea) -> void:
	name = "CraftingBench"
	title = "简易工坊 · 加工台"
	theme = sea.theme
	exclusive = true
	get_label().hide()
	get_ok_button().text = "返回浮台  /  Esc"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var frame := Control.new()
	add_child(frame)
	var content := VBoxContainer.new()
	frame.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	content.add_child(header)
	header.add_child(Icons.make("build",56))
	_label(header,"简易工坊   /   绳索加工",25,Color("#f4d9a2"))
	var plate := PanelContainer.new()
	content.add_child(plate)
	var rows := VBoxContainer.new()
	plate.add_child(rows)
	_label(rows,"生产配方　/　单次加工",15,Color("#a4d5c8"))
	_label(rows,"纤维 × 1     →     绳索 × 1",23)
	var inventory := _label(rows,"",17)
	var feedback := _label(content,"工坊也会加工站点自动收取的纤维。",16)
	var button := Button.new()
	button.theme_type_variation = &"HarborPrimary"
	button.text = "加工一份绳索"
	button.custom_minimum_size.y = 42
	content.add_child(button)
	var refresh := func() -> void:
		inventory.text = "现有纤维 %d　·　库存绳索 %d" % [sea.fiber,sea.rope]
		button.disabled = sea.fiber < 1 or sea.rope >= sea.DiveCatalog.RESOURCE_LIMIT
	button.pressed.connect(func() -> void:
		var saved: bool = sea._process_fiber()
		feedback.text = sea.result_label.text if not saved else "已制成绳索 × 1，库存已更新。"
		refresh.call())
	refresh.call()
	popup_centered(Vector2i(560,360))
	get_ok_button().grab_focus()

func _lab(box: Control) -> void:
	var done: int = tech.state.researched.values().count(true)
	_label(box, "科研进度   /   %02d · 07" % done, 22, Color("#f6dfb4"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 7
	bar.value = done
	bar.custom_minimum_size.y = 8
	box.add_child(bar)
	var id: String = tech.state.tracked
	if id == "":
		for key in tech.TECHS:
			if not tech.researched(key) and (tech.TECHS[key].pre == "" or tech.researched(tech.TECHS[key].pre)):
				id = key
				break
	if id != "":
		_label(box, ("跟踪中的课题" if tech.state.tracked != "" else "建议查看") + "   /   " + id, 15, Color("#95d8c9"))
		_label(box, tech.TECHS[id].name + "　·　" + tech.TECHS[id].effect, 18)
		_go(box, "查看该课题与材料", "tech", id, true)
	else:
		_label(box, "七项研究均已完成，可以回查项目与效果。", 18)
		_go(box, "查阅研究档案", "tech", "T0", true)
	_label(box, "样本来源  /  安全带回记录", 16, Color("#95d8c9"))
	for region in tech.REGIONS:
		_label(box, "%s　·　%s" % [tech.REGIONS[region], "已带回" if tech.state.manual[region] else "尚无记录"], 15)

func _winch(box: Control) -> void:
	_label(box, "作业状态   /   " + tech.status_text(), 21, Color("#f6dfb4"))
	var current: String = tech.state.current
	_label(box, "当前作业　%s　　剩余 %.1f 秒" % [tech._name(current) if current != "" else "无", float(tech.state.remaining)], 17)
	if current != "" and tech.TARGETS.has(current):
		var cycle := ProgressBar.new()
		cycle.max_value = float(tech.TARGETS[current][1])
		cycle.value = cycle.max_value - float(tech.state.remaining)
		cycle.show_percentage = false
		cycle.custom_minimum_size.y = 8
		box.add_child(cycle)
	_label(box, "下轮预约　" + tech._name(tech.state.target) + "　·　可用额度 %d / 24" % int(tech.state.credits), 17)
	var n: int = tech._cargo_count()
	_label(box, "设备货仓   /   %02d · %02d 格" % [n, tech.capacity()], 19, Color("#95d8c9"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = tech.capacity()
	bar.value = n
	bar.custom_minimum_size.y = 9
	box.add_child(bar)
	var row := HBoxContainer.new()
	box.add_child(row)
	_go(row, "作业控制", "device", "运行面板", true)
	_go(row, "预约目标", "device", "目标预约")
	var storage := HBoxContainer.new()
	box.add_child(storage)
	_go(storage, "查看货仓", "device", "设备货仓")
	_go(storage, "维护补给", "maintenance", "普通维护包")

func _label(parent: Control, value: String, px: int, color := Color("#e0ede8")) -> Label:
	var l := Label.new()
	l.text = value
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _go(parent: Control, caption: String, page: String, entry: String, primary := false) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 39
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary: b.theme_type_variation = &"HarborPrimary"
	parent.add_child(b)
	b.pressed.connect(func() -> void:
		hide()
		tech.open_item(page, entry)
		queue_free())

func _schematic(c: Control, lab: bool) -> void:
	var aqua := Color("#71aaa5")
	c.draw_rect(Rect2(Vector2.ZERO,c.size), Color("#122f3b"))
	for x in range(0,int(c.size.x),16): c.draw_line(Vector2(x,0),Vector2(x,c.size.y),Color("#21444e"))
	for y in range(0,int(c.size.y),16): c.draw_line(Vector2(0,y),Vector2(c.size.x,y),Color("#21444e"))
	var center := c.size * 0.5
	if lab: c.draw_arc(center,46,0,TAU,60,aqua,1,true)
	else:
		c.draw_line(center+Vector2(-72,36),center+Vector2(72,36),aqua,1)
		c.draw_line(center+Vector2(-60,-35),center+Vector2(-60,36),aqua,1)
	var atlas = Icons.PLATES
	var cell := atlas.get_width() / float(Icons.ORDER.size())
	c.draw_texture_rect_region(atlas,Rect2(center - Vector2(48,48),Vector2(96,96)),Rect2(cell*(6 if lab else 7),0,cell,atlas.get_height()))
