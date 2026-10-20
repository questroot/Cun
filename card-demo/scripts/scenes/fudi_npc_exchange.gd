extends Node
## Reuse the existing dialogue modal so all pause/input rules stay shared.
const Catalog = preload("res://scripts/scenes/npc_shop_catalog.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Gear = preload("res://scripts/scenes/equipment_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game
var active_id := ""
var stock: Dictionary = {}
var original_layout: Control
var original_position := Vector2.ZERO
var original_size := Vector2.ZERO
var layout: VBoxContainer
var title: Label
var portrait: TextureRect
var role: Label
var note: Label
var conversation: RichTextLabel
var shop: ScrollContainer
var goods: VBoxContainer
var talk_button: Button
var shop_button: Button
var close_button: Button
var wallet: Label
var feedback: Label
var buy_buttons: Dictionary = {}
var stock_labels: Dictionary = {}

func _ready() -> void:
	game = get_parent()
	for id: String in Catalog.STOCK:
		stock[id] = {}
		for row: Array in Catalog.STOCK[id]:
			stock[id][row[0]] = int(row[2])
	original_layout = game.dialogue.get_child(0)
	original_position = game.dialogue.position
	original_size = game.dialogue.size
	_build()
	game.dialogue.visibility_changed.connect(_restore_dialogue)

func _label(parent: Node, text: String, font_size: int = 16) -> Label:
	var label := UI.label(text, font_size)
	parent.add_child(label)
	return label

func _build() -> void:
	layout = VBoxContainer.new()
	layout.name = "NpcExchange"
	layout.add_theme_constant_override("separation", 12)
	game.dialogue.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = _label(header, "", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = UI.button("离开  E / Esc", func() -> void: game.dialogue.hide())
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	layout.add_child(body)
	var person := VBoxContainer.new()
	person.custom_minimum_size.x = 220
	person.add_theme_constant_override("separation", 12)
	body.add_child(person)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(220, 224)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	person.add_child(portrait)
	role = _label(person, "", 17)
	role.custom_minimum_size.x = 220
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note = _label(person, "", 16)
	note.custom_minimum_size.x = 220
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	body.add_child(content)
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	talk_button = UI.button("交流与委托", func() -> void: show_shop(false))
	talk_button.toggle_mode = true
	tabs.add_child(talk_button)
	shop_button = UI.button("购买商品", func() -> void: show_shop(true))
	shop_button.toggle_mode = true
	tabs.add_child(shop_button)
	conversation = RichTextLabel.new()
	conversation.custom_minimum_size = Vector2(760, 300)
	conversation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conversation.add_theme_font_size_override("normal_font_size", 21)
	content.add_child(conversation)
	shop = ScrollContainer.new()
	shop.custom_minimum_size = Vector2(760, 300)
	shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(shop)
	goods = VBoxContainer.new()
	goods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods.add_theme_constant_override("separation", 10)
	shop.add_child(goods)
	wallet = _label(layout, "", 17)
	feedback = _label(layout, "", 16)
	feedback.custom_minimum_size = Vector2(1000, 25)
	feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shop.hide()
	layout.hide()

func present(id: String) -> void:
	if not game.npcs.DEFINITIONS.has(id) or not game.dialogue.visible: return
	active_id = id
	var config: Dictionary = game.npcs.DEFINITIONS[id]
	title.text = str(config.name) + (" · 稀有货品" if id == "changdaozhe" else "")
	portrait.texture = load("res://assets/characters/npcs/%s.png" % id)
	role.text = Catalog.ROLES.get(id, "旅途中的相识")
	note.text = Catalog.NOTES.get(id, "")
	conversation.text = game.dialogue_text.text
	conversation.scroll_to_line(0)
	original_layout.hide()
	layout.show()
	game.dialogue.position = Vector2(80, 78)
	shop_button.visible = Catalog.is_merchant(id)
	_build_goods()
	feedback.text = "买入物品进入行囊；装备可按 C 穿戴。" if Catalog.is_merchant(id) else "听过的委托与调查进度可按 B 回看。"
	show_shop(Catalog.is_merchant(id))
	# Set the size after hiding the other tab, so its old minimum cannot stretch the first visit.
	game.dialogue.set_deferred("size", Vector2(1120, 564))
	close_button.grab_focus()

func show_shop(value: bool) -> void:
	var buying := value and Catalog.is_merchant(active_id)
	shop.visible = buying
	conversation.visible = not buying
	shop_button.set_pressed_no_signal(buying)
	talk_button.set_pressed_no_signal(not buying)
	_refresh_stock()

func _build_goods() -> void:
	for child in goods.get_children():
		goods.remove_child(child)
		child.queue_free()
	buy_buttons.clear()
	stock_labels.clear()
	for offer: Array in Catalog.STOCK.get(active_id, []):
		var item := str(offer[0])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.hud_panel(Color("#1b383d")))
		goods.add_child(row)
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 14)
		row.add_child(columns)
		if Loot.ITEMS.has(item):
			var icon := TextureRect.new()
			icon.texture = Loot.ITEMS[item].icon
			icon.custom_minimum_size = Vector2(56, 64)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			columns.add_child(icon)
		else:
			var color := ColorRect.new()
			color.color = Color(Items.ITEMS[item].color)
			color.custom_minimum_size = Vector2(10, 64)
			columns.add_child(color)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(detail)
		var heading := _label(detail, str(Items.ITEMS[item].name), 19)
		heading.add_theme_color_override("font_color", Color(Items.ITEMS[item].color))
		var description := "材料 · 买入后放进行囊"
		if Loot.ITEMS.has(item):
			description = ("高阶·稀有 / " if item.contains("@mutated") else "装备 / ") + Gear.text(Gear.stats(item))
		var summary := _label(detail, description, 14)
		summary.custom_minimum_size.x = 440
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var remaining := _label(detail, "", 14)
		stock_labels[item] = remaining
		var button := UI.button("", buy.bind(item))
		if Loot.ITEMS.has(item): button.tooltip_text = Gear.effect_text(item)
		button.custom_minimum_size.x = 155
		columns.add_child(button)
		buy_buttons[item] = button
	shop.scroll_vertical = 0

func _offer(item: String) -> Array:
	for row: Array in Catalog.STOCK.get(active_id, []):
		if row[0] == item: return row
	return []

func buy(item: String) -> bool:
	if active_id.is_empty() or not game.dialogue.visible or not layout.visible or not shop.visible or game.finished: return false
	# Revalidate the actual merchant and offer at purchase time; never trust the button alone.
	if game.npcs.region_of(active_id) != game.region or game.player_foot.distance_to(game.npcs.position_of(active_id)) >= game.npcs.TALK_RADIUS: return false
	var offer := _offer(item)
	if offer.is_empty() or not Items.ITEMS.has(item): return false
	var price := int(offer[1])
	if int(stock[active_id].get(item, 0)) <= 0:
		feedback.text = "这件货品已经售罄。"
		return false
	if int(game.inventory.get("crystal", 0)) < price:
		feedback.text = "灵晶不足，继续探索可采集灵晶。"
		return false
	game.inventory.crystal -= price
	game.inventory[item] = int(game.inventory.get(item, 0)) + 1
	stock[active_id][item] -= 1
	feedback.text = "已购入 %s ×1，消耗 %d 灵晶；已放进行囊。" % [Items.ITEMS[item].name, price]
	game.sound_requested.emit("pickup")
	game._refresh_ui()
	_refresh_stock()
	return true

func _refresh_stock() -> void:
	wallet.text = "持有灵晶 %d · 货品按件购买，库存本轮有效，跨地图保留" % int(game.inventory.get("crystal", 0)) if Catalog.is_merchant(active_id) else "交流期间暂停探索 · E / Esc 离开"
	for item: String in buy_buttons:
		var offer := _offer(item)
		var left := int(stock[active_id][item])
		var price := int(offer[1])
		stock_labels[item].text = "库存 %d · 每件 %d 灵晶" % [left, price]
		buy_buttons[item].text = "已售罄" if left <= 0 else ("灵晶不足" if int(game.inventory.get("crystal", 0)) < price else "购买 · %d灵晶" % price)
		buy_buttons[item].disabled = left <= 0 or int(game.inventory.get("crystal", 0)) < price

func _restore_dialogue() -> void:
	if game.dialogue.visible or active_id.is_empty(): return
	layout.hide()
	original_layout.show()
	game.dialogue.position = original_position
	game.dialogue.set_deferred("size", original_size)
	active_id = ""
