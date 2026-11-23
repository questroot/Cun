extends AcceptDialog
## Surface-only equipment bench. The scene owns all inventory changes and saves.
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const Icons = preload("res://scripts/scenes/sea_station_icons.gd")
const EFFECT := {
	"capture_net": "主动捕获　J 推开生物后，靠近按 E 活捕，占网袋 2 格。捕网将眩晕从 2 秒延长至 3.5 / 5 秒。",
	"wrist": "被动防护　减轻撞击耗氧。锈蟹：6 → 3 → 0；盲鳗冲撞：18 → 12 → 8。",
	"mask": "照明半径　120 → 200 → 260",
	"tank": "氧气上限　90 → 120 → 150",
	"fins": "游动速度　230 → 280 → 320",
	"net_expansion": "网袋容量　8 → 12 → 16 格",
}
const SURFACE := {"wood": "木料", "scrap": "废料", "fiber": "纤维", "rope": "绳索"}
var sea
var entries := {}
var feedback: Label

func open_station(host) -> void:
	sea = host
	title = "潜水工坊 · 浮台装备台"
	theme = sea.theme
	exclusive = true
	get_label().hide()
	get_ok_button().text = "返回浮台"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	# Wrapped labels have no useful width until AcceptDialog lays out its child.
	# A plain viewport host keeps their first-pass heights out of the window minimum.
	var frame := Control.new()
	add_child(frame)
	var root := VBoxContainer.new()
	frame.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(Icons.make("build", 48))
	var brief := VBoxContainer.new()
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brief)
	_label(brief, "潜水装备台", &"HarborHeading")
	var status := "核心附属位 · 已建成"
	var cost: Vector2i = Catalog.WORKSHOP_COST
	if not sea.dive_workshop_built:
		status = "核心附属位 · " + ("已解锁" if sea.dive_workshop_unlocked else "首次归档核心解锁，获建造用料")
		status += "\n建造：木料 %d、废料 %d" % [cost.x, cost.y]
		var gaps := PackedStringArray()
		if sea.wood < cost.x: gaps.append("木料 %d" % (cost.x - sea.wood))
		if sea.scrap < cost.y: gaps.append("废料 %d" % (cost.y - sea.scrap))
		status += "　·　" + ("材料齐备" if gaps.is_empty() else "缺 " + "、".join(gaps))
	_label(brief, status, &"HarborCaption")
	if not sea.dive_workshop_built:
		var build := _action(top, "建造预览", "建造潜水工坊")
		build.disabled = not sea.dive_workshop_unlocked or sea.wood < cost.x or sea.scrap < cost.y
		build.pressed.connect(func() -> void:
			hide()
			queue_free()
			sea._open_build("dive_workshop"))
	var tabs := TabContainer.new()
	tabs.name = "GearTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_page(tabs, "捕获与防护", ["capture_net", "wrist"])
	_page(tabs, "探索装备", ["mask", "tank", "fins", "net_expansion"])
	feedback = _label(root, "数值顺序：初始 → 一级 → 二级", &"HarborCaption")
	_refresh()
	var available: Vector2i = Vector2i(sea.get_viewport_rect().size).min(sea.get_window().size) - Vector2i(36, 64)
	popup_centered(Vector2i(mini(780, available.x), mini(560, available.y)))
	tabs.get_tab_bar().grab_focus()

func _page(tabs: TabContainer, caption: String, ids: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.accessibility_name = caption + "装备列表"
	scroll.tooltip_text = "滚轮或拖动滚动条；聚焦列表后也可用方向键、翻页键。"
	scroll.gui_input.connect(_scroll_key.bind(scroll))
	tabs.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	for id: String in ids:
		var card := PanelContainer.new()
		stack.add_child(card)
		var body := VBoxContainer.new()
		card.add_child(body)
		var row := HBoxContainer.new()
		body.add_child(row)
		row.add_child(Icons.make(id, 44))
		var heading := _label(row, "", &"HarborHeading")
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action := _action(row, "制作", _gear_name(id))
		action.name = "Craft_" + id
		action.pressed.connect(_craft.bind(id))
		_label(body, EFFECT[id])
		var gate := _label(body, "", &"HarborCaption")
		var bill := _label(body, "")
		entries[id] = {"heading": heading, "action": action, "gate": gate, "bill": bill}

func _scroll_key(event: InputEvent, scroll: ScrollContainer) -> void:
	if not scroll.has_focus() or not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_DOWN: scroll.scroll_vertical += 44
		KEY_UP: scroll.scroll_vertical -= 44
		KEY_PAGEDOWN: scroll.scroll_vertical += int(scroll.size.y)
		KEY_PAGEUP: scroll.scroll_vertical -= int(scroll.size.y)
		_: return
	scroll.accept_event()

func _gear_name(id: String) -> String:
	return "网袋扩容" if id == "net_expansion" else Catalog.EQUIPMENT[id]

func _refresh() -> void:
	var seen: int = sea.dive_archive.safe.values().count(true)
	for id: String in entries:
		var item: Dictionary = entries[id]
		var level: int = sea.net_expansion if id == "net_expansion" else sea.equipment_level(id)
		var recipes: Array = Catalog.RECIPES[id]
		var full := level >= recipes.size()
		var unlocked := Catalog.recipe_unlocked(id, level, sea.dive_archive)
		item.heading.text = "%s　%d / %d 级" % [_gear_name(id), level, recipes.size()]
		var gate := "解锁：工坊建成即可制作"
		if id in ["capture_net", "wrist"]:
			var thresholds := [3, 7] if id == "capture_net" else [5, 9]
			gate = "安全记录 %d 种　·　一级需 %d 种，二级需 %d 种" % [seen, thresholds[0], thresholds[1]]
		var costs := PackedStringArray()
		var gaps := PackedStringArray()
		if not full:
			for material: String in recipes[level]:
				var need: int = recipes[level][material]
				var missing: int = need - sea.material_count(material)
				var title_text: String = Catalog.ITEMS[material][0] if Catalog.ITEMS.has(material) else SURFACE[material]
				costs.append("%s %d" % [title_text, need])
				if missing > 0: gaps.append("%s %d" % [title_text, missing])
		item.gate.text = gate
		item.bill.text = "已达装备上限，无后续费用。" if full else "费用：%s　·　%s" % ["、".join(costs), "材料齐备" if gaps.is_empty() else "缺 " + "、".join(gaps)]
		var action: Button = item.action
		action.disabled = full or not sea.dive_workshop_built or not unlocked or not gaps.is_empty()
		if full: action.text = "已满级"
		elif not sea.dive_workshop_built: action.text = "待建工坊"
		elif not unlocked: action.text = "记录不足"
		elif not gaps.is_empty(): action.text = "待补料"
		else: action.text = "制作一级" if level == 0 else "升至二级"
		action.accessibility_name = _gear_name(id) + " · " + action.text
		action.tooltip_text = "%s\n%s\n%s" % [action.accessibility_name, gate, item.bill.text]

func _craft(id: String) -> void:
	if sea.craft_equipment(id):
		feedback.text = "%s已完成，材料与等级已更新。" % _gear_name(id)
	else:
		feedback.text = "制作未完成，请核对库存与保存状态。"
	_refresh()

func _action(parent: Control, caption: String, accessible: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.accessibility_name = accessible
	button.theme_type_variation = &"HarborPrimary"
	button.custom_minimum_size = Vector2(92, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button

func _label(parent: Control, caption: String, style: StringName = &"") -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = style
	parent.add_child(label)
	return label
