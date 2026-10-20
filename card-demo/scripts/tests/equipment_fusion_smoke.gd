extends "res://scripts/tests/equipment_smoke.gd"
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
var gear
var fusion

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Equipment-"):
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	game = load("res://scenes/Fudi.tscn").instantiate()
	if current_scene != null:
		current_scene.free()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	gear = game.equipment
	fusion = gear.fusion
	var original_items: int = Loot.ITEMS.size()
	await key(KEY_C)
	await click(gear.fusion_button)
	check(fusion.view.visible and not gear.equipment_view.visible and game._paused(), "真实点击融合页，保持世界暂停")
	check(fusion.fuse_button.disabled and fusion.target_picker.disabled, "空背包显示指引并禁用融合")
	await capture("fusion_empty")
	check(not fusion.fuse("unknown", 1, "ore").ok, "未知目标不能融合")
	game.inventory["w02-ruinsplitter"] = 1
	game.inventory["ore"] = 100
	game.inventory["iron"] = 100
	game.inventory["copper"] = 100
	var before_inventory: Dictionary = game.inventory.duplicate()
	for invalid: String in ["wood", "crystal", "herb", "scrap", "unknown"]:
		check(not fusion.fuse("w02-ruinsplitter", 1, invalid).ok, "拒绝非金属融合材料 " + invalid)
	check(not fusion.fuse("w02-ruinsplitter", 0, "w02-ruinsplitter").ok and game.inventory == before_inventory, "仅一件目标不能吞掉自己，失败不扣材料")
	game.inventory["s1-top"] = 1
	check(not fusion.preview("w02-ruinsplitter", 0, "s1-top").ok, "不同部位不能融合")
	game.inventory["w01-ashen-echo"] = 1
	gear.equip_item("w01-ashen-echo")
	check(not fusion.preview("w02-ruinsplitter", 0, "w01-ashen-echo").ok, "穿戴中的唯一副本受保护")
	game.inventory["w01-ashen-echo"] = 2
	check(fusion.donor_count("w02-ruinsplitter", "w01-ashen-echo") == 1, "穿戴中装备的多余副本可作材料")
	var result: Dictionary = fusion.fuse("w02-ruinsplitter", 0, "w01-ashen-echo")
	check(result.ok and game.inventory["w01-ashen-echo"] == 1 and gear.equipped.weapon == "w01-ashen-echo", "同类不同武器消耗一件，保留穿戴副本")
	var upgraded: String = result.get("item", "")
	check(game.inventory["w02-ruinsplitter"] == 0 and game.inventory.get(upgraded, 0) == 1, "目标一件替换为融合产物")
	check(Catalog.stats(upgraded) == {"attack": 20, "defense": 0, "speed": 0}, "融合+1伤害按基础10%向上取整，零属性不增加")
	check(not Catalog.effect_text(upgraded).contains("异变品质") and Catalog.effect_text(upgraded).contains("破墟斩"), "普通融合保留武器特效，未误标异变品质")
	check(not fusion.preview("w01-ashen-echo", 0, upgraded).ok, "已融合装备不会被当作耗材")
	game.inventory["w02-ruinsplitter"] = 2
	gear.equip_item("w02-ruinsplitter")
	result = fusion.fuse("w02-ruinsplitter", 0, "w02-ruinsplitter")
	check(result.ok and game.inventory["w02-ruinsplitter"] == 0 and game.inventory[upgraded] == 2 and gear.equipped.weapon == upgraded, "两件同ID融合正确扣两件，并即时替换穿戴目标")
	check(fusion.donor_count(upgraded, upgraded) == 0, "融合副本即使多件也不作为耗材")
	gear.selected = upgraded
	gear.show_view("equipment")
	gear.refresh()
	await click(gear.fuse_item_button)
	check(fusion.view.visible and fusion.target_id == upgraded, "单件详情融合按钮定位到选中装备")
	await click(fusion.mode_buttons[1])
	check(fusion.fusion_mode == 1 and fusion.cost_ids.size() == 3 and fusion.mode_buttons[1].button_pressed, "真实点击切换金属模式，仅列三种金属")
	fusion.cost_id = "ore"
	fusion.refresh()
	check(fusion.preview_label.text.contains("20") and fusion.preview_label.text.contains("22") and fusion.cost_label.text.contains("×2"), "点击前显示+2属性和玄铁两份消耗")
	await capture("fusion_preview")
	var ore_before: int = game.inventory.ore
	await click(fusion.fuse_button)
	var upgraded2: String = fusion.target_id
	check(fusion.level(upgraded2) == 2 and game.inventory.ore == ore_before - 2, "真实点击消耗玄铁并融合到+2")
	check(game.inventory[upgraded] == 1 and Catalog.stats(upgraded).attack == 20 and Catalog.stats(upgraded2).attack == 22, "相同融合等级的其他副本属性保持不变")
	check(gear.equipped.weapon == upgraded2 and gear.bonuses().attack == 22 and fusion.message.text.contains("融合成功"), "穿戴目标即刻更新加成与成功反馈")
	await capture("fusion_success")
	check(gear.panel.get_global_rect().end.y <= 720 and fusion.fuse_button.get_global_rect().end.y <= 680, "融合成功页面板与按钮在720p视口内")
	var recipe: Dictionary = fusion.preview(upgraded2, 1, "ore")
	game.inventory.ore = 2
	before_inventory = game.inventory.duplicate()
	check(recipe.ok and not fusion.fuse(upgraded2, 1, "ore").ok and game.inventory == before_inventory, "过期预览在提交时复查材料，不足不扣除")
	fusion.refresh()
	check(fusion.fuse_button.disabled and fusion.cost_label.text.contains("不足"), "数量不足界面明确提示并禁用提交")
	await capture("fusion_insufficient")
	game.inventory.ore = 100
	check(fusion.preview(upgraded2, 1, "iron").cost_count == 6 and fusion.preview(upgraded2, 1, "copper").cost_count == 6, "铁片与铜丝消耗为下一等级两倍")
	result = fusion.fuse(upgraded2, 1, "iron")
	check(result.ok and game.inventory.iron == 94, "铁片实际扣除六份")
	upgraded2 = result.get("item", "")
	result = fusion.fuse(upgraded2, 1, "copper")
	check(result.ok and game.inventory.copper == 92, "铜丝实际扣除八份")
	upgraded2 = result.get("item", "")
	gear.close()
	before_inventory = game.inventory.duplicate()
	check(not fusion.fuse(upgraded2, 1, "ore").ok and game.inventory == before_inventory, "关闭面板时不允许融合")
	gear.open()
	game.finished = true
	check(not fusion.fuse(upgraded2, 1, "ore").ok and game.inventory == before_inventory, "结算时不能融合")
	game.finished = false
	for n in range(5, 11):
		result = fusion.fuse(upgraded2, 1, "ore")
		upgraded2 = result.get("item", "")
		check(result.ok and fusion.level(upgraded2) == n and Catalog.stats(upgraded2).attack == 18 + 2 * n, "逐级融合使用原始基础值 +%d" % n)
	before_inventory = game.inventory.duplicate()
	check(not fusion.fuse(upgraded2, 1, "ore").ok and game.inventory == before_inventory, "+10到达上限不再消耗")
	fusion.refresh()
	check(fusion.fuse_button.disabled and fusion.cost_label.text.contains("上限"), "上限界面明确说明并禁用按钮")
	check(fusion.preview_label.text.contains("38") and fusion.preview_label.text.contains("上限"), "上限页仍展示已强化的当前属性")
	await capture("fusion_cap")
	# Mutated equipment retains both its quality and set/effect identity.
	game.inventory["s1-top@mutated"] = 2
	game.inventory["s2-top"] = 1
	gear.equip_item("s1-top@mutated")
	result = fusion.fuse("s1-top@mutated", 0, "s2-top")
	var mutated: String = result.get("item", "")
	check(result.ok and Catalog.stats(mutated) == {"attack": 0, "defense": 5, "speed": 5}, "异变基础先加品质再融合，跨套同部位可消耗")
	check(game.inventory["s1-top@mutated"] == 1 and Catalog.stats("s1-top@mutated").defense == 4, "异变目标也只提升一件")
	game.inventory["s1-legs"] = 1
	gear.equip_item("s1-legs")
	check(Catalog.set_counts(gear.equipped).s1 == 2 and gear.bonuses().speed == 28 and Catalog.effect_text(mutated).contains("异变品质"), "融合异变装备仍计入追归套装且保留品质标注")
	check(Items.ITEMS.has(mutated) and Loot.ITEMS[mutated].icon == Loot.ITEMS["s1-top@mutated"].icon, "融合产物注册行囊名称和原始图标")
	gear.show_view("equipment")
	gear.selected = mutated
	gear._refresh_detail()
	await capture("fusion_equipped")
	check(gear.panel.get_global_rect().end.y <= 720 and gear.fuse_item_button.get_global_rect().end.y < 700, "融合异变详情和操作仍在720p内")
	# Verify real attack, damage reduction and WASD movement with upgraded stats.
	gear.close()
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.facing = Vector2.RIGHT
	game.states[game.region].enemies = [{"position": game.player_foot + Vector2(80, 0), "hp": 500, "max_hp": 500, "flash": 0.0}]
	game.cooldowns.j = 0
	check(game.attack("j") and game.states[game.region].enemies[0].hp == 436, "融合+10武器真实J伤害为26+38")
	check(game.incoming_damage(20) == 13, "融合防具进入实际减伤计算")
	var foot: Vector2 = game.player_foot
	var held := InputEventKey.new()
	held.physical_keycode = KEY_D
	held.pressed = true
	Input.parse_input_event(held)
	await frames()
	game._process(0.1)
	check(absf(game.player_foot.distance_to(foot) - 28.8) < 0.1, "融合与套装移速加成进入真实WASD移动")
	held.pressed = false
	Input.parse_input_event(held)
	game.inventory["w03-prism-saber@mutated"] = 1
	gear.open()
	result = fusion.fuse("w03-prism-saber@mutated", 1, "ore")
	var prism: String = result.get("item", "")
	gear.equip_item(prism)
	check(gear.effects.weapon() == "w03-prism-saber" and Catalog.effect_text(prism).contains("棱光分流"), "异变融合武器映射回原武器特效")
	gear.close()
	game.cooldowns.k = 0
	check(game.attack("k") and game.projectiles.size() == 3, "融合后棱光K仍真实发射三向灵弹")
	var counts: Dictionary = game.inventory.duplicate()
	var loadout: Dictionary = gear.equipped.duplicate()
	for region: String in Maps.IDS:
		game.enter_region(region)
	check(game.inventory == counts and gear.equipped == loadout and Catalog.stats(prism).attack == 21, "跨全部地图保留融合物品、属性和穿戴")
	game.open_journal()
	check(game.journal_text.text.contains(Loot.ITEMS[prism].name) and game.journal_text.text.contains(Loot.ITEMS[mutated].name), "行囊实际显示融合后的物品名称")
	game.journal.hide()
	var runtime_ids: Array = fusion.created.duplicate()
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	check(game._inventory_total() == 0 and game.equipment.equipped.is_empty() and Loot.ITEMS.size() == original_items, "真实重开清空融合背包、穿戴和动态定义")
	var cleared := true
	for id: String in runtime_ids:
		cleared = cleared and not Items.ITEMS.has(id)
	check(cleared and Catalog.stats("w02-ruinsplitter").attack == 18, "重开移除行囊融合定义且基础装备不变")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "融合、战斗、旅行与重开不修改灵伴存档")
	print("EQUIPMENT_RESULT: fusion %d checks, %d failures" % [checks, failures])
	await finish_checks()
