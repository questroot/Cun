extends Node
## One target copy becomes one upgraded copy; never upgrades an entire stack.
const Catalog = preload("res://scripts/scenes/equipment_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const MAX_LEVEL := 10
const METALS := {"ore": 1, "iron": 2, "copper": 2}
var gear
var game
var created: Array[String] = []
var view: VBoxContainer
var target_picker: OptionButton
var fusion_mode := 0
var mode_buttons: Array[Button] = []
var material_picker: OptionButton
var target_icon: TextureRect
var target_label: Label
var preview_label: Label
var cost_label: Label
var message: Label
var fuse_button: Button
var target_ids: Array[String] = []
var cost_ids: Array[String] = []
var target_id := ""
var cost_id := ""
var notice := ""

func _ready() -> void:
	gear = get_parent()
	game = gear.game

func _exit_tree() -> void:
	# Runtime item definitions belong to this round, just like inventory/loadout.
	for id: String in created:
		Loot.ITEMS.erase(id)
		Items.ITEMS.erase(id)

func level(item: String) -> int:
	return int(Loot.ITEMS.get(item, {}).get("fusion_level", 0))

func donor_count(target: String, donor: String) -> int:
	if Catalog.slot(target) == "" or Catalog.slot(target) != Catalog.slot(donor) or level(donor) > 0:
		return 0
	var amount := int(game.inventory.get(donor, 0))
	var worn: bool = gear.equipped.values().has(donor)
	amount -= 1 if worn else 0
	if target == donor and not worn:
		amount -= 1 # Reserve the target copy when it is in the bag.
	return maxi(0, amount)

func preview(target: String, mode: int, material: String) -> Dictionary:
	var result := {"ok": false, "reason": "请选择已拥有的装备", "target": target, "cost": material}
	if not Loot.ITEMS.has(target) or int(game.inventory.get(target, 0)) <= 0:
		return result
	if game.finished:
		result.reason = "本轮已经结束，不能融合"
		return result
	var current := level(target)
	if current >= MAX_LEVEL:
		result.reason = "已达到融合上限 +%d" % MAX_LEVEL
		return result
	var source: String = Loot.ITEMS[target].get("fusion_source", target)
	var next := current + 1
	var before := Catalog.stats(target)
	var after := Catalog.stats(source)
	for key: String in after:
		if int(after[key]) > 0:
			after[key] += maxi(1, ceili(float(after[key]) * 0.1)) * next
	result.merge({"source": source, "next_level": next, "before": before, "after": after, "cost_count": 1, "cost_name": "", "available": 0})
	if mode == 0:
		result.cost_name = str(Loot.ITEMS.get(material, {}).get("name", "同部位装备"))
		result.available = donor_count(target, material)
		if result.available <= 0:
			result.reason = "缺少可消耗的同部位装备；穿戴中、已融合的装备不会作为材料"
			return result
	elif mode == 1 and METALS.has(material):
		result.cost_count = next * int(METALS[material])
		result.cost_name = Items.MATERIALS[material].name
		result.available = int(game.inventory.get(material, 0))
		if result.available < result.cost_count:
			result.reason = "%s不足：需要%d份，拥有%d份" % [result.cost_name, result.cost_count, result.available]
			return result
	else:
		result.reason = "只能使用同部位装备，或玄铁、旧铁片、细铜丝"
		return result
	result.ok = true
	result.reason = "确定消耗后融合必定成功"
	return result

func fuse(target: String, mode: int, material: String) -> Dictionary:
	# Always recheck live quantities; a previously drawn preview is not authority.
	var recipe := preview(target, mode, material)
	if not gear.is_open():
		recipe.ok = false
		recipe.reason = "请先打开人物装备面板"
	if not recipe.ok:
		return recipe
	var result_id := "%s@fusion%d" % [recipe.source, recipe.next_level]
	if not Loot.ITEMS.has(result_id):
		var metadata: Dictionary = Loot.ITEMS[recipe.source].duplicate()
		metadata.name = "%s +%d" % [metadata.name, recipe.next_level]
		metadata["base_item"] = Loot.base_item(recipe.source)
		metadata["fusion_source"] = recipe.source
		metadata["fusion_level"] = recipe.next_level
		Loot.ITEMS[result_id] = metadata
		Items.ITEMS[result_id] = metadata
		created.append(result_id)
	game.inventory[target] -= 1
	game.inventory[material] -= int(recipe.cost_count)
	game.inventory[result_id] = int(game.inventory.get(result_id, 0)) + 1
	var slot := Catalog.slot(target)
	if gear.equipped.get(slot, "") == target:
		gear.equipped[slot] = result_id
	gear.effects.loadout_changed()
	gear.selected = result_id
	target_id = result_id
	notice = "融合成功：%s；已消耗 %s ×%d" % [Loot.ITEMS[result_id].name, recipe.cost_name, recipe.cost_count]
	gear.refresh()
	game._refresh_ui()
	recipe["item"] = result_id
	return recipe

func _text(parent: Node, text: String, size: int = 18, color: Color = Color("#dfebe3")) -> Label:
	var label := UI.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func build(parent: Node) -> void:
	view = VBoxContainer.new()
	view.custom_minimum_size.y = 508
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 8)
	parent.add_child(view)
	_text(view, "装备融合  /  同部位装备或金属材料，二选一", 22, Color("#f4daa0"))
	target_picker = OptionButton.new()
	target_picker.custom_minimum_size.y = 36
	target_picker.item_selected.connect(func(index: int) -> void:
		target_id = target_ids[index]
		notice = ""
		refresh())
	view.add_child(target_picker)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	view.add_child(columns)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 350
	columns.add_child(card)
	target_icon = TextureRect.new()
	target_icon.custom_minimum_size = Vector2(180, 90)
	target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(target_icon)
	target_label = _text(card, "", 18, Color("#c1ddcd"))
	var recipe := VBoxContainer.new()
	recipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe.add_theme_constant_override("separation", 8)
	columns.add_child(recipe)
	var modes := HBoxContainer.new()
	recipe.add_child(modes)
	for index in range(2):
		var button := UI.button(["同类装备 ×1", "金属材料"][index], func() -> void:
			fusion_mode = index
			cost_id = ""
			notice = ""
			refresh())
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(button)
		mode_buttons.append(button)
	material_picker = OptionButton.new()
	material_picker.custom_minimum_size.y = 36
	material_picker.item_selected.connect(func(index: int) -> void:
		cost_id = cost_ids[index]
		notice = ""
		_refresh_preview())
	recipe.add_child(material_picker)
	cost_label = _text(recipe, "", 16, Color("#e6d099"))
	cost_label.custom_minimum_size.y = 60
	preview_label = _text(view, "", 18, Color("#b9e6c2"))
	preview_label.custom_minimum_size.y = 48
	message = _text(view, "", 16, Color("#f4daa0"))
	message.custom_minimum_size.y = 22
	fuse_button = UI.button("选择材料后融合", func() -> void:
		var result := fuse(target_id, fusion_mode, cost_id)
		if not result.ok:
			notice = str(result.reason)
			_refresh_preview())
	view.add_child(fuse_button)
	_text(view, "每级：原有非零属性各增加基础值的10%（向上取整，至少1点），最高+10。\n只强化目标1件；原品质、套装与武器特效保留。已融合或穿戴中的装备不作耗材。", 16, Color("#9ebbb6"))
	view.hide()

func open_for(item: String) -> void:
	target_id = item
	notice = ""
	gear.show_view("fusion")
	refresh()

func refresh() -> void:
	if view == null:
		return
	target_picker.clear()
	target_ids.clear()
	for item: String in Loot.ITEMS:
		if int(game.inventory.get(item, 0)) > 0:
			target_ids.append(item)
			target_picker.add_item("%s  ×%d%s" % [Loot.ITEMS[item].name, game.inventory[item], "  ·  已穿戴" if gear.equipped.values().has(item) else ""])
	if not target_ids.has(target_id):
		target_id = gear.selected if target_ids.has(gear.selected) else (target_ids[0] if not target_ids.is_empty() else "")
	if not target_ids.is_empty():
		target_picker.select(target_ids.find(target_id))
	else:
		target_picker.add_item("还没有装备，先拾取一件装备")
	target_picker.disabled = target_ids.is_empty()
	material_picker.clear()
	cost_ids.clear()
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(fusion_mode == index)
	if fusion_mode == 0:
		for item: String in Loot.ITEMS:
			var amount := donor_count(target_id, item)
			if amount > 0:
				cost_ids.append(item)
				material_picker.add_item("%s  ·  可消耗%d件" % [Loot.ITEMS[item].name, amount])
	else:
		for item: String in METALS:
			cost_ids.append(item)
			material_picker.add_item("%s  ·  拥有%d份" % [Items.MATERIALS[item].name, int(game.inventory.get(item, 0))])
	if not cost_ids.has(cost_id):
		cost_id = cost_ids[0] if not cost_ids.is_empty() else ""
	if cost_ids.is_empty():
		material_picker.add_item("没有可消耗的同部位装备")
	else:
		material_picker.select(cost_ids.find(cost_id))
	material_picker.disabled = cost_ids.is_empty()
	_refresh_preview()

func _refresh_preview() -> void:
	var recipe := preview(target_id, fusion_mode, cost_id)
	target_icon.texture = Loot.ITEMS[target_id].icon if Loot.ITEMS.has(target_id) else null
	target_label.text = "%s\n融合等级 +%d / +%d" % [Loot.ITEMS[target_id].name, level(target_id), MAX_LEVEL] if Loot.ITEMS.has(target_id) else "请选择要提升的装备"
	preview_label.text = "当前：%s\n融合后：%s" % [Catalog.text(recipe.before), Catalog.text(recipe.after)] if recipe.has("after") else "消耗与属性预览将在选中装备后显示。"
	if not recipe.has("after") and Loot.ITEMS.has(target_id):
		preview_label.text = "当前：%s\n%s" % [Catalog.text(Catalog.stats(target_id)), recipe.reason]
	cost_label.text = "%s ×%d  /  可用%d\n%s" % [recipe.cost_name, recipe.cost_count, recipe.available, recipe.reason] if recipe.has("cost_count") else str(recipe.reason)
	fuse_button.disabled = not recipe.ok
	fuse_button.text = "消耗 %s ×%d 并融合至 +%d" % [recipe.cost_name, recipe.cost_count, recipe.next_level] if recipe.ok else "暂不可融合"
	message.text = notice
