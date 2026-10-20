extends CanvasLayer
## Round-local loadout and modal UI. Inventory counts include worn copies.
const Catalog = preload("res://scripts/scenes/equipment_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const Hero = preload("res://scripts/scenes/hero_walk_sprite.gd")
const Effects = preload("res://scripts/scenes/equipment_effects.gd")
const Fusion = preload("res://scripts/scenes/equipment_fusion.gd")
var game
var equipped: Dictionary = {}
var selected := ""
var filter_slot := ""
var modal: Control
var panel: PanelContainer
var slot_buttons: Dictionary = {}
var item_buttons: Dictionary = {}
var grid: GridContainer
var scroll: ScrollContainer
var empty_label: Label
var stats_label: Label
var count_label: Label
var detail_name: Label
var detail_stats: Label
var comparison: Label
var detail_icon: TextureRect
var equip_button: Button
var unequip_button: Button
var filter: OptionButton
var close_button: Button
var entry_button: Button
var effects: Effects
var special_label: Label
var set_label: Label
var equipment_view: HBoxContainer
var effects_view: RichTextLabel
var effects_button: Button
var fusion: Fusion
var fusion_button: Button
var fuse_item_button: Button

func _ready() -> void:
	game = get_parent()
	effects = Effects.new()
	add_child(effects)
	fusion = Fusion.new()
	add_child(fusion)
	layer = 110
	entry_button = UI.button("人物装备  C", open)
	entry_button.position = Vector2(1104, 158)
	entry_button.size.x = 152
	add_child(entry_button)
	if game.has_method("register_hud_action"):
		entry_button.text = "装备 C"
		game.register_hud_action(entry_button)
	_build()
	modal.hide()

func is_open() -> bool:
	return modal != null and modal.visible

func bonuses() -> Dictionary:
	return Catalog.loadout_stats(equipped)

func equip_item(item: String) -> bool:
	var key := Catalog.slot(item)
	if not Catalog.SLOTS.has(key) or int(game.inventory.get(item, 0)) <= 0 or game.finished:
		return false
	if equipped.get(key, "") == item:
		return false
	equipped[key] = item
	effects.loadout_changed()
	selected = item
	refresh()
	return true

func unequip_slot(key: String) -> bool:
	if game.finished or not equipped.has(key):
		return false
	selected = equipped[key]
	equipped.erase(key)
	effects.loadout_changed()
	refresh()
	return true

func available(item: String) -> int:
	return maxi(0, int(game.inventory.get(item, 0)) - (1 if equipped.values().has(item) else 0))

func open() -> void:
	if game.finished or game.dialogue.visible or game.journal.visible or game.tools.is_open() or game.menu.visible:
		return
	refresh()
	modal.show()
	game.model.update_movement(Vector2.ZERO, 0)
	close_button.grab_focus()

func close() -> void:
	modal.hide()
	entry_button.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if is_open():
			if key in [KEY_C, KEY_ESCAPE]:
				close()
			# Keep keyboard GUI navigation available while swallowing game shortcuts.
			if key not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				get_viewport().set_input_as_handled()
		elif key == KEY_C:
			open()
			get_viewport().set_input_as_handled()

func _label(parent: Node, text: String, font_size: int = 18, color: Color = Color("#dfebe3")) -> Label:
	var node := UI.label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func _art(parent: Node, texture: Texture2D, extent: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = extent
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _build() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.04, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	panel = PanelContainer.new()
	panel.position = Vector2(60, 40)
	panel.size = Vector2(1160, 640)
	panel.add_theme_stylebox_override("panel", UI.panel(Color("#10272e")))
	modal.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := _label(heading, "人物装备", 28, Color("#f4daa0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_button = UI.button("套装与特效", func() -> void: show_view("equipment" if effects_view.visible else "effects"))
	heading.add_child(effects_button)
	fusion_button = UI.button("装备融合", func() -> void: show_view("equipment" if fusion.view.visible else "fusion"))
	heading.add_child(fusion_button)
	close_button = UI.button("继续探索  C / Esc", close)
	heading.add_child(close_button)
	var columns := HBoxContainer.new()
	equipment_view = columns
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var character := VBoxContainer.new()
	character.custom_minimum_size.x = 400
	columns.add_child(character)
	_label(character, "复苏旅人  /  当前穿戴", 21, Color("#c1ddcd"))
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 8)
	character.add_child(doll)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	doll.add_child(left)
	var portrait := VBoxContainer.new()
	portrait.custom_minimum_size.x = 132
	doll.add_child(portrait)
	_art(portrait, Hero.IDLE_ART, Vector2(132, 270))
	var note := _label(portrait, "装备属性生效\n角色外观沿用原图", 14, Color("#8fb3ac"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	doll.add_child(right)
	for i in range(Catalog.SLOTS.size()):
		var key: String = Catalog.SLOTS[i]
		var button := UI.button("", func() -> void: select_slot(key))
		button.custom_minimum_size = Vector2(126, 101)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 46)
		button.add_theme_font_size_override("font_size", 15)
		(left if i < 3 else right).add_child(button)
		slot_buttons[key] = button
	stats_label = _label(character, "", 18, Color("#f0d89e"))
	stats_label.custom_minimum_size.y = 90
	set_label = _label(character, "", 16, Color("#9ebbb6"))
	var bag := VBoxContainer.new()
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.add_theme_constant_override("separation", 10)
	columns.add_child(bag)
	var bag_heading := HBoxContainer.new()
	bag.add_child(bag_heading)
	count_label = _label(bag_heading, "", 20, Color("#c1ddcd"))
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter = OptionButton.new()
	filter.add_item("全部部位")
	for key: String in Catalog.SLOTS:
		filter.add_item(Catalog.NAMES[key])
	filter.item_selected.connect(func(index: int) -> void:
		filter_slot = "" if index == 0 else Catalog.SLOTS[index - 1]
		refresh())
	bag_heading.add_child(filter)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	contents.add_child(grid)
	empty_label = _label(contents, "", 19, Color("#a5beb6"))
	empty_label.custom_minimum_size.y = 80
	var details := PanelContainer.new()
	details.add_theme_stylebox_override("panel", UI.panel(Color("#1a353a")))
	bag.add_child(details)
	var detail_layout := VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 6)
	details.add_child(detail_layout)
	var summary := HBoxContainer.new()
	detail_layout.add_child(summary)
	detail_icon = _art(summary, null, Vector2(58, 58))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(words)
	detail_name = _label(words, "", 20, Color("#f4daa0"))
	detail_stats = _label(words, "", 16)
	comparison = _label(detail_layout, "", 16, Color("#9fc8c0"))
	comparison.custom_minimum_size.y = 42
	special_label = _label(detail_layout, "", 15, Color("#e6d099"))
	special_label.max_lines_visible = 3
	special_label.custom_minimum_size.y = 40
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	detail_layout.add_child(actions)
	equip_button = UI.button("穿戴装备", func() -> void: equip_item(selected))
	unequip_button = UI.button("卸下装备", func() -> void: unequip_slot(Catalog.slot(selected)))
	actions.add_child(equip_button)
	actions.add_child(unequip_button)
	fuse_item_button = UI.button("融合此装备", func() -> void: fusion.open_for(selected))
	actions.add_child(fuse_item_button)
	effects_view = RichTextLabel.new()
	effects_view.bbcode_enabled = true
	effects_view.custom_minimum_size.y = 508
	effects_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effects_view.add_theme_font_size_override("normal_font_size", 18)
	layout.add_child(effects_view)
	effects_view.hide()
	fusion.build(layout)
	_label(layout, "本轮探索有效 · 跨地图保留，重开清空  |  点击装备查看对比，点击左侧栏位筛选  |  打开面板时探索暂停", 16, Color("#94b3ac"))

func show_view(page: String) -> void:
	equipment_view.visible = page == "equipment"
	effects_view.visible = page == "effects"
	fusion.view.visible = page == "fusion"
	effects_button.text = "返回装备栏" if effects_view.visible else "套装与特效"
	fusion_button.text = "返回装备栏" if fusion.view.visible else "装备融合"
	_refresh_effects()
	fusion.refresh()

func select_slot(key: String) -> void:
	filter_slot = key
	filter.select(Catalog.SLOTS.find(key) + 1)
	selected = equipped.get(key, "")
	refresh()

func refresh() -> void:
	if modal == null:
		return
	var bonus := bonuses()
	stats_label.text = "装备加成  /  " + Catalog.text(bonus, true) + "\nJ %d   K %d   L %d  ·  移速 %d\n已穿戴 %d / 6  ·  生命 %d / 100" % [26 + bonus.attack, 20 + bonus.attack, 42 + bonus.attack + (12 if effects.count("s2") >= 5 else 0), 260 + bonus.speed, equipped.size(), game.health]
	var counts := Catalog.set_counts(equipped)
	set_label.text = "追归 %d/5  ·  烽炉 %d/5  ·  镜潮 %d/5\n技能冷却 ×%.2f  ·  护盾 %d/18\n上方“套装与特效”查看激活条件与说明。" % [counts.s1, counts.s2, counts.s3, effects.cooldown_scale(), effects.shield_points]
	_refresh_effects()
	for key: String in Catalog.SLOTS:
		var item: String = equipped.get(key, "")
		var button: Button = slot_buttons[key]
		button.text = Catalog.NAMES[key] + "\n" + (Loot.ITEMS[item].name if not item.is_empty() else "空栏位")
		button.icon = Loot.ITEMS[item].icon if not item.is_empty() else null
		button.tooltip_text = "点击查看此部位的装备"
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	var owned := 0
	var shown: Array[String] = []
	for item: String in Loot.ITEMS:
		var amount := int(game.inventory.get(item, 0))
		owned += amount
		if amount <= 0 or (filter_slot != "" and Catalog.slot(item) != filter_slot):
			continue
		shown.append(item)
		var button := UI.button("", func() -> void:
			selected = item
			_refresh_detail())
		button.custom_minimum_size = Vector2(153, 94)
		button.add_theme_font_size_override("font_size", 15)
		button.icon = Loot.ITEMS[item].icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 44)
		button.text = "%s\n%s · ×%d" % [Loot.ITEMS[item].name, "已穿戴" if equipped.values().has(item) else Catalog.NAMES[Catalog.slot(item)], amount]
		button.tooltip_text = Catalog.text(Catalog.stats(item), true) + "\n" + Catalog.effect_text(item)
		grid.add_child(button)
		item_buttons[item] = button
	count_label.text = "已收集 %d 件 · 含穿戴 %d 件" % [owned, equipped.size()]
	empty_label.visible = shown.is_empty()
	empty_label.text = "这个部位还没有装备。\n小怪有35%概率掉装备，Boss必掉1件；靠近地面光圈拾取。" if filter_slot != "" else "行囊里还没有装备。\n小怪有35%概率掉装备，Boss必掉1件；靠近地面光圈拾取。"
	if not shown.has(selected):
		selected = shown[0] if not shown.is_empty() else ""
	_refresh_detail()
	fusion.refresh()

func _refresh_detail() -> void:
	for item: String in item_buttons:
		var skin := UI.panel(Color("#34564f") if item == selected else Color("#254b4b"))
		skin.content_margin_top = 8
		skin.content_margin_bottom = 8
		skin.border_color = Color("#e8c77d") if item == selected else Color("#6c9187")
		item_buttons[item].add_theme_stylebox_override("normal", skin)
	var valid := Loot.ITEMS.has(selected) and int(game.inventory.get(selected, 0)) > 0
	detail_icon.texture = Loot.ITEMS[selected].icon if valid else null
	equip_button.disabled = not valid
	fuse_item_button.disabled = not valid
	unequip_button.disabled = true
	if not valid:
		equip_button.text = "穿戴装备"
		detail_name.text = "选择一件装备"
		detail_stats.text = "拾取后会自动出现在上方列表。"
		comparison.text = "每个部位可穿戴一件；同部位穿戴会替换旧装备。"
		special_label.text = "套装需穿戴同系列的2 / 4 / 5件；武器穿戴即生效。"
		return
	var key := Catalog.slot(selected)
	var worn: String = equipped.get(key, "")
	var values := Catalog.stats(selected)
	detail_name.text = "%s  /  %s" % [Loot.ITEMS[selected].name, Catalog.NAMES[key]]
	detail_stats.text = Catalog.text(values, true) + "  ·  可用 %d 件" % available(selected)
	var preview := equipped.duplicate()
	preview[key] = selected
	var difference := Catalog.loadout_stats(preview)
	var old := bonuses()
	for stat: String in difference:
		difference[stat] -= old[stat]
	comparison.text = "当前：%s\n替换变化：%s" % [Loot.ITEMS[worn].name if worn != "" else "空栏位", Catalog.text(difference, true)]
	special_label.text = Catalog.effect_text(selected)
	special_label.tooltip_text = special_label.text
	equip_button.text = "已穿戴" if worn == selected else ("替换穿戴" if worn != "" else "穿戴装备")
	equip_button.disabled = worn == selected
	unequip_button.disabled = worn != selected

func _refresh_effects() -> void:
	if effects_view == null:
		return
	var counts := Catalog.set_counts(equipped)
	var lines: Array[String] = ["[color=#f4daa0]套装效果 · 同系列不同部位累计，2 / 4 / 5件效果叠加[/color]\n"]
	for id: String in Catalog.SET_EFFECTS:
		var config: Dictionary = Catalog.SET_EFFECTS[id]
		lines.append("[color=#c1ddcd]%s套装  %d / 5[/color]" % [config.name, counts[id]])
		for tier: int in config.tiers:
			var active: bool = counts[id] >= tier
			lines.append("[color=%s]%s %d件：%s[/color]" % ["#a9e2b6" if active else "#91a5a4", "已激活" if active else "未激活", tier, config.tiers[tier]])
		lines.append("")
	lines.append("[color=#f4daa0]武器特殊效果 · 穿戴即生效[/color]")
	for item: String in Catalog.WEAPON_EFFECTS:
		lines.append("[color=%s]%s %s[/color]\n%s" % ["#f4daa0" if effects.weapon() == item else "#91a5a4", "已穿戴" if effects.weapon() == item else "未穿戴", Loot.ITEMS[item].name, Catalog.WEAPON_EFFECTS[item]])
	lines.append("\n护盾 %d/18 · 下次补充 %.1f秒（需穿齐镜潮5件）\n换装/旅行取消燃烧、减速、延迟攻击与在途灵弹；武器冷却保留。\n所有计时随探索暂停；追加伤害不再次触发套装或武器效果。" % [effects.shield_points, 8.0 - effects.shield_charge])
	effects_view.text = "\n".join(lines)
