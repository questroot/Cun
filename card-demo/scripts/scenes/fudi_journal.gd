extends Node
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const VFX := preload("res://scripts/scenes/pixel_vfx.gd")
var game
var tabs: TabContainer
var texts: Array[RichTextLabel] = []
var picker: OptionButton
var task_ids: Array[String] = []
var tracked := ""
var track_label: Label
var craft_buttons: Dictionary = {}
var use_buttons: Dictionary = {}
var repair_button: Button

func _ready() -> void:
	game = get_parent()
	game.journal.position = Vector2(100, 90)
	game.journal.size = Vector2(1080, 560)
	var layout: VBoxContainer = game.journal.get_child(0)
	game.journal_text.free()
	var close: Button = layout.get_child(0)
	layout.remove_child(close)
	layout.add_child(UI.label("行囊与见闻", 26, Color("#f0d69a")))
	tabs = TabContainer.new()
	tabs.focus_mode = Control.FOCUS_ALL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 20)
	layout.add_child(tabs)
	for title: String in ["物品", "委托", "见闻", "帮助"]:
		var row := HBoxContainer.new()
		row.name = title
		row.add_theme_constant_override("separation", 18)
		tabs.add_child(row)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.y = 355
		text.add_theme_font_size_override("normal_font_size", 19)
		row.add_child(text)
		texts.append(text)
	build_supplies(tabs.get_child(0))
	var tasks := VBoxContainer.new()
	tasks.custom_minimum_size.x = 310
	tabs.get_child(1).add_child(tasks)
	tasks.add_child(UI.label("选择一个委托追踪", 18))
	picker = OptionButton.new()
	picker.custom_minimum_size = Vector2(310, 44)
	picker.clip_text = true
	tasks.add_child(picker)
	tasks.add_child(UI.button("追踪选中委托", func() -> void: set_tracked(task_ids[picker.selected])))
	tasks.add_child(UI.button("取消追踪", func() -> void: set_tracked("")))
	var note := UI.label("金色圆环标出目标区域；\n同区域的小地图标出目标地点。\n目标随调查与交付自动更新。", 17)
	tasks.add_child(note)
	layout.add_child(close)
	tabs.tab_changed.connect(func(index: int) -> void: game.journal_text = texts[index])
	game.journal_text = texts[0]
	track_label = UI.label("", 16, Color("#ffe1a1"))
	track_label.position = Vector2(380, 653)
	track_label.size = Vector2(870, 26)
	track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	track_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(track_label)
	game.tools.atlas.set_meta("task_provider", target)
	game.minimap.draw.connect(draw_minimap)
	game.world_canvas.draw.connect(draw_world)

func build_supplies(row: HBoxContainer) -> void:
	var supplies := VBoxContainer.new()
	supplies.add_theme_constant_override("separation", 8)
	row.add_child(supplies)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 12)
	supplies.add_child(groups)
	for resource: String in Items.SUPPLY_LABELS:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 234
		groups.add_child(column)
		column.add_child(UI.label("回血补给" if resource == "health" else "回蓝药水", 18, Color("#f0d69a")))
		for id: String in Items.SUPPLIES:
			if Items.SUPPLIES[id].resource == resource:
				add_recipe(column, id)
	supplies.add_child(UI.label("修补休息点 · 木料3 ＋ 松脂1", 16))
	repair_button = UI.button("修补当前休息点", func() -> void: game.supplies.repair())
	supplies.add_child(repair_button)

func add_recipe(column: VBoxContainer, id: String) -> void:
	var recipe: Dictionary = Items.SUPPLIES[id]
	var costs: Array[String] = []
	for material: String in recipe.cost:
		costs.append("%s%d" % [Items.ITEMS[material].name, recipe.cost[material]])
	column.add_child(UI.label("%s · +%d%s\n%s" % [recipe.name, recipe.restore, Items.SUPPLY_LABELS[recipe.resource], " ＋ ".join(costs)], 15))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var craft := UI.button("制作1份", func() -> void: game.supplies.craft(id))
	var use := UI.button("使用", func() -> void: game.supplies.use(id))
	for button: Button in [craft, use]:
		game.style_hud_button(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	craft_buttons[id] = craft
	use_buttons[id] = use

func select_page(index: int) -> void:
	tabs.current_tab = index
	game.journal_text = texts[index]

func open() -> void:
	refresh()
	game.journal.show()
	game.journal_text.scroll_to_line(0)
	game.model.update_movement(Vector2.ZERO, 0)
	tabs.grab_focus()

func purpose(id: String) -> String:
	if Items.SUPPLIES.has(id):
		var recipe: Dictionary = Items.SUPPLIES[id]
		return "使用恢复%d%s" % [recipe.restore, Items.SUPPLY_LABELS[recipe.resource]]
	if Loot.ITEMS.has(id): return "C穿戴或融合"
	match id:
		"wood": return "修灶交付 / 修补休息点"
		"resin": return "修补休息点"
		"herb": return "药饮 / 灶台热汤"
		"ore", "iron", "copper": return "C装备融合"
		"crystal": return "人物商店购买"
		"bloodgrass", "fiber": return "制作止血绷带"
		"dewleaf": return "制作灵草药饮 / 青露灵液"
		"wakeleaf": return "制作醒神灵液"
		"mint": return "制作甘露薄荷饮 / 醒神灵液"
		"berry": return "制作甘露薄荷饮"
		_: return "采集材料 · 当前无制作配方"

func refresh() -> void:
	var inventory: Array[String] = ["物品 · 共%d份\n装备数量包含穿戴；按C比较属性。\n右侧可制作补给，对应数值满时不会消耗药品。" % game._inventory_total()]
	for id: String in game.inventory:
		if game.inventory[id] <= 0: continue
		var info: Dictionary = Items.ITEMS[id]
		var icon: String = "[img=36x36]%s[/img] " % info.icon.resource_path if info.has("icon") else ""
		inventory.append("%s%s × %d\n[color=#a9c5b7]%s[/color]" % [icon, info.name, game.inventory[id], purpose(id)])
	texts[0].text = "\n\n".join(inventory)
	texts[1].text = "祝婶 · 今天几个人吃饭\n" + game.story.summary() + "\n" + "\n\n".join(game.npcs.journal_lines())
	var previous := task_ids[picker.selected] if picker.item_count > 0 else "stove"
	picker.clear()
	task_ids.assign(["stove"])
	picker.add_item("祝婶 · 今天几个人吃饭")
	for id: String in game.npcs.tasks:
		if game.npcs.tasks[id] == "available": continue
		task_ids.append(id)
		picker.add_item(game.npcs.DEFINITIONS[id].name + " · " + game.npcs.DEFINITIONS[id].quest)
	picker.select(maxi(0, task_ids.find(previous)))
	var lore: Array[String] = ["已调查的见闻 · %d / %d\n未调查正文不会提前显示。" % [game._visited_total(), Maps.site_total()]]
	for id: String in Maps.IDS:
		var data: Dictionary = Maps.MAPS[id]
		for i in range(3):
			if game.states[id].visited[i]: lore.append("%s · %s · %s\n%s" % [Items.REGIONS[id].name, data.npc, data.sites[i][0], data.sites[i][2]])
	texts[2].text = "\n\n".join(lore)
	texts[3].text = game.journal_help()
	for id: String in Items.SUPPLIES:
		craft_buttons[id].disabled = game.finished or not game.supplies.can_craft(id)
		use_buttons[id].disabled = not game.supplies.can_use(id)
		use_buttons[id].text = "使用 ×%d" % game.inventory.get(id, 0)
	repair_button.disabled = game.finished or not game.supplies.can_repair()
	update_tracking()

func set_tracked(id: String) -> void:
	tracked = id
	update_tracking()
	game.persistence.request_save()

func target() -> Dictionary:
	if tracked == "": return {}
	if tracked == "stove":
		var site := 0
		var label := "旧灶台 · 与祝婶交谈"
		match int(game.story.state.stage):
			1:
				site = 1 if not game.states.grove.visited[1] else 0
				label = "核对街坊药圃" if site == 1 else "带灵草2、木料2回旧灶台交付"
			2:
				site = 2 if not game.states.grove.visited[2] or not game.story.safe_street() else 0
				label = "清除灶街守卫与鹿骑，核对迁灶落脚点" if site == 2 else "回旧灶台修灶"
			3: label = "灶火已恢复 · 旧灶台煮汤"
		return {"region": "grove", "point": Maps.site_position("grove", site), "label": label}
	var definition: Dictionary = game.npcs.DEFINITIONS[tracked]
	for need: Array in definition.needs:
		if not game.states[need[0]].visited[need[1]]:
			var site: int = game.states[need[0]].visited.find(false)
			return {"region": need[0], "point": Maps.site_position(need[0], site), "label": definition.name + " · 调查" + Maps.MAPS[need[0]].sites[site][0]}
	return {"region": game.npcs.region_of(tracked), "point": game.npcs.position_of(tracked), "label": "向" + definition.name + "回报" if game.npcs.tasks[tracked] != "complete" else definition.name + " · 委托已完成"}

func update_tracking() -> void:
	var goal := target()
	track_label.text = "追踪 · " + Items.REGIONS[goal.region].name + " · " + goal.label if not goal.is_empty() else ""
	track_label.tooltip_text = track_label.text
	game.minimap.queue_redraw()
	game.tools.atlas.map_surface.queue_redraw()

func draw_minimap() -> void:
	var goal := target()
	if goal.is_empty() or goal.region != game.region: return
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	var point: Vector2 = rect.position + goal.point / Maps.MAPS[game.region].size * rect.size
	game.minimap.draw_arc(point, 8, 0, TAU, 20, Color("#ffe1a1"), 3, true)

func draw_world() -> void:
	var goal := target()
	if goal.is_empty() or goal.region != game.region: return
	VFX.cue_arc(game.world_canvas, goal.point, 72.0, 0.0, TAU, 4.0, Color("#ffe1a1"))
	game.world_canvas.draw_string(ThemeDB.fallback_font, goal.point + Vector2(-55, -80), "追踪目标", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffe1a1"))
