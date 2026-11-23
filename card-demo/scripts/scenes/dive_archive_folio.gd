extends RefCounted
## Field notebook presentation. All labels are projections of the host's retained records.
const Art = preload("res://scripts/scenes/dive_art_chart.gd")
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const Icons = preload("res://scripts/scenes/sea_station_icons.gd")
const REGIONS := ["珊瑚浅滩", "侧倾沉船", "发光海沟", "浮台归档"]
const INKS := [Color("#80d4bb"), Color("#e8b988"), Color("#b8b1e9"), Color("#e4c78a")]
var clue_cards: Array = []
var slips: Array = []
var voyage_rows: Array = []
var order_status: Label
var voyage_status: Label

static func label(parent: Control, value: String, font_size: int, color: Color = Color("#e5efea")) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

static func block(parent: Control, fill: String, edge: Color, padding: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill)
	box.border_color = edge
	box.border_width_top = 3
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	return body

func build_clues(parent: Control) -> void:
	label(parent, "调查路径    /    从浅滩到浮台", 21, Art.AMBER)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	for i in 4:
		var col := block(row, "#183640", INKS[i])
		label(col, "勘查  %02d  /  04" % [i+1], 15, INKS[i])
		var plate := Control.new()
		plate.custom_minimum_size.y = 125
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.draw.connect(draw_plate.bind(plate, i))
		col.add_child(plate)
		label(col, REGIONS[i], 25)
		var state := label(col, "", 17, INKS[i])
		var copy := label(col, "", 18)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clue_cards.append([state, copy])

static func draw_plate(p: Control, i: int) -> void:
	var w := p.size.x
	p.draw_rect(Rect2(0, 0, w, 125), Color("#102631"))
	for k in range(0, int(w), 16): p.draw_line(Vector2(k, 0), Vector2(k, 125), Color("#1e3944"))
	for k in range(0, 125, 16): p.draw_line(Vector2(0, k), Vector2(w, k), Color("#1e3944"))
	match i:
		0: Art.barrier(p, Rect2(w/2-30, 40, 88, 83), "shoal")
		1: Art.hull(p, Vector2((w-233)/2, 75))
		2: Art.barrier(p, Rect2(6, 16, w-12, 110), "trench")
		3:
			var center := Vector2(w/2, 62)
			for r in [17, 33, 46]: p.draw_arc(center, r, 0, TAU, 64, INKS[i], 1.2, true)
			p.draw_line(center, center+Vector2(35,-30), INKS[i], 3, true)
			p.draw_circle(center+Vector2(19,-15), 4, Art.GLASS)

# Equipment milestones are a reading aid, not buttons or recipe transactions.
var milestones: Array[Label] = []

func build_species_header(parent: Control) -> Label:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	parent.add_child(strip)
	var count := label(strip, "", 18, Art.GLASS)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in [[3, "捕网"], [5, "护腕"], [7, "捕网 II"], [9, "护腕 II"]]:
		var tile := block(strip, "#16333f", Color("#40616b"), 8)
		milestones.append(label(tile, "%d 种 · %s" % item, 15))
	return count

func update_milestones(safe_count: int) -> void:
	for i in milestones.size():
		var reached := safe_count >= 3 + i * 2
		milestones[i].add_theme_color_override("font_color", Art.GLASS if reached else Color("#a3b3bb"))
		milestones[i].tooltip_text = "安全记录已达门槛" if reached else "尚需 %d 种安全记录" % (3 + i * 2 - safe_count)

func build_orders(parent: Control) -> void:
	var board := block(parent, "#19373e", Art.AMBER)
	var logbook := block(parent, "#132f3b", Art.GLASS)
	board.size_flags_stretch_ratio = 0.95
	var title := HBoxContainer.new()
	board.add_child(title)
	title.add_child(Icons.make("pack", 46))
	label(title, "阿汐的委托板", 24, Art.AMBER)
	order_status = label(board, "", 16)
	for i in 3:
		var slip := block(board, "#0f2731", Color("#4e7172"), 10)
		slips.append([label(slip, "", 18), label(slip, "", 16, Art.GLASS)])
	label(board, "成功入库统一交付；新单从下次归档起结算。", 16)
	title = HBoxContainer.new()
	logbook.add_child(title)
	title.add_child(Icons.make("research", 46))
	label(title, "安全航程日志", 24, Art.GLASS)
	voyage_status = label(logbook, "", 17, Art.AMBER)
	for i in 10: voyage_rows.append(label(logbook, "", 16))

func refresh(host) -> void:
	var flags := [host.dive_shoal, host.dive_sonar, host.dive_core, host.dive_archived]
	var known := ["船舷金属片，光迹指向船尾。", "声呐台记录间歇光带与海沟方向。", "唯一回声核心已带回。", "浅滩 → 船尾声呐 → 海沟核心；深处信号仍未解。"]
	var blank := ["尚未调查", "尚未调查", "尚未发现", "待取得核心并在浮台归档"]
	for i in 4:
		clue_cards[i][0].text = (["已调查", "已调查", "已带回", "已归档"][i] if flags[i] else "未结案")
		clue_cards[i][1].text = known[i] if flags[i] else blank[i]
	var orders: Array = host.dive_archive.orders
	order_status.text = "在办委托  %02d / 03" % orders.size() if host.tide_table else "未开放  ·  建成潮测台后开放三单"
	for i in 3:
		if i >= orders.size():
			slips[i][0].text = "席位  %02d" % (i+1)
			slips[i][1].text = "暂无委托" if host.tide_table else "等待潮测台建成"
			continue
		var order: Dictionary = orders[i]
		var config: Dictionary = Catalog.ORDER_POOL[int(order.kind)]
		var request: String = ("观察" + String(Catalog.species()[config.observe].name)) if config.has("observe") else (Catalog.item_name(config.item) + " ×%d" % int(config.amount))
		slips[i][0].text = "#%03d   %s" % [order.id, request]
		slips[i][1].text = "报酬   %s ×%d" % [{"wood":"木", "scrap":"废", "fiber":"纤维", "water":"清水", "salt":"盐"}[config.reward], config.count]
	var n := int(host.dive_archive.voyages)
	var found := mini(10, n / 5)
	voyage_status.text = "安全航程 %d 次   ·   线索 %02d / 10   ·   每 5 次一条" % [n, found]
	for i in 10:
		voyage_rows[i].visible = i < found or (i == found and found < 10)
		voyage_rows[i].text = "%02d   /   %s" % [i+1, Catalog.VOYAGE_CLUES[i]] if i < found else "—   距下一条航程线索还需 %d 次安全航程" % (5-n%5)
