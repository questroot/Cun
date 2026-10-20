extends "res://scripts/tests/exploration_smoke.gd"
const Shops = preload("res://scripts/scenes/npc_shop_catalog.gd")

func meet(id: String) -> void:
	game.dialogue.hide()
	game.enter_region(game.npcs.region_of(id))
	game.player_foot = game.npcs.position_of(id)
	game.model.position = game.player_foot
	game._update_camera()
	game.interact()
	await frames()

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-NpcExchange-"):
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	game = await load_scene("res://scenes/Fudi.tscn")
	var exchange = game.npc_exchange
	var initial_stock: Dictionary = exchange.stock.duplicate(true)
	for id: String in game.npcs.DEFINITIONS:
		await meet(id)
		check(game.dialogue.visible and exchange.active_id == id and exchange.layout.visible and game._paused(), "近处E打开人物面板并暂停: " + id)
		check(exchange.portrait.texture != null and exchange.conversation.text.contains(str(game.npcs.DEFINITIONS[id].name)), "使用已绘人物并保留委托交流: " + id)
		check(exchange.shop.visible == Shops.is_merchant(id) and exchange.shop_button.visible == Shops.is_merchant(id), "按职责打开交流或商品界面: " + id)
		check(Rect2(0,0,1280,720).encloses(game.dialogue.get_global_rect()) and game.dialogue.get_global_rect().encloses(exchange.close_button.get_global_rect()), "人物面板和离开按钮完整可见: " + id)
		check(game.play_visible().get("world_occluded", false), "人物面板遮挡世界观察: " + id)
		key(KEY_ESCAPE)
		key(KEY_ESCAPE, false)
		await frames()
		check(not game.dialogue.visible and not exchange.layout.visible and not game._paused(), "Esc关闭人物面板恢复探索: " + id)
	await meet("changdaozhe")
	check(exchange.title.text.contains("稀有货品") and exchange.buy_buttons.size() == 6, "长祷者有独立高阶稀有货架")
	var item := "w03-prism-saber@mutated"
	var empty_wallet: Dictionary = game.inventory.duplicate()
	check(exchange.buy_buttons[item].disabled and not exchange.buy(item) and game.inventory == empty_wallet and exchange.stock == initial_stock, "不足灵晶不能购买，不扣物品也不扣库存")
	game.inventory.crystal = 40
	await meet("changdaozhe")
	await capture("npc_rare_shop")
	await click(exchange.buy_buttons[item])
	check(game.inventory.crystal == 28 and game.inventory[item] == 1 and exchange.stock.changdaozhe[item] == 0, "真实点击购买扣12灵晶并获得一件高阶装备")
	check(exchange.buy_buttons[item].disabled and exchange.buy_buttons[item].text == "已售罄" and not exchange.buy(item) and game.inventory.crystal == 28, "售罄及重复购买不再扣款")
	check(not exchange.buy("wood") and not exchange.buy("unknown") and game.inventory.crystal == 28, "拒绝货架外物品与未知ID")
	await click(exchange.talk_button)
	check(exchange.conversation.visible and not exchange.shop.visible and not exchange.buy("memory_sand"), "切换交流页，交流页不能误购买")
	await capture("npc_conversation")
	await click(exchange.shop_button)
	var foot: Vector2 = game.player_foot
	var cooldowns: Dictionary = game.cooldowns.duplicate()
	key(KEY_D)
	key(KEY_J)
	game._process(1)
	key(KEY_D, false)
	key(KEY_J, false)
	for code: int in [KEY_M, KEY_B, KEY_C]:
		key(code)
		key(code, false)
	check(game.player_foot == foot and game.cooldowns == cooldowns and not game.tools.is_open() and not game.equipment.is_open() and not game.journal.visible, "交易阻止移动、攻击和其他面板快捷键穿透")
	var wander: Vector2 = game.npcs.wander_foot
	game.npcs.tick(1)
	check(game.npcs.wander_foot == wander, "交易期间巡游商人停留")
	game.player_foot += Vector2(500,0)
	check(not exchange.buy("memory_sand"), "购买时重新校验交谈距离")
	game.player_foot = foot
	await click(exchange.close_button)
	check(not exchange.buy("memory_sand"), "关闭面板后不能购买")
	game.equipment.open()
	check(game.equipment.equip_item(item) and game.equipment.equipped.weapon == item, "买入稀有装备可由原装备系统穿戴")
	game.equipment.close()
	await meet("lu-yan")
	game.inventory.crystal = 5
	exchange._refresh_stock()
	var owned: int = game.inventory.wood
	await click(exchange.buy_buttons.wood)
	check(game.inventory.wood == owned + 1 and game.inventory.crystal == 4 and exchange.stock["lu-yan"].wood == 3, "普通行商材料交易实际生效")
	await capture("npc_common_shop")
	game.dialogue.hide()
	await frames()
	game.enter_region("grove")
	await meet("lu-yan")
	check(exchange.stock["lu-yan"].wood == 3 and exchange.stock.changdaozhe[item] == 0, "跨图及重开窗口不刷新库存")
	game.dialogue.hide()
	await frames()
	game.player_foot = Maps.site_position(game.region, 0)
	game.interact()
	await frames()
	check(game.dialogue.visible and not exchange.layout.visible and exchange.original_layout.visible and game.dialogue.size.y <= 300, "调查对话恢复原布局，人物面板不污染旧地标交互")
	game.dialogue.hide()
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	check(game.npc_exchange.stock == initial_stock and game.inventory[item] == 0 and game.inventory.crystal == 0, "重开清空购买并恢复库存，不赠送初始货币")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "交易不修改灵伴存档")
	print("NPC_EXCHANGE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
