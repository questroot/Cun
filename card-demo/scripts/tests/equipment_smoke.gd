extends SceneTree
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Catalog = preload("res://scripts/scenes/equipment_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])

func frames() -> void:
	for i in range(3):
		await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await frames()

func click(control: Control) -> void:
	if game != null and game.equipment.scroll.is_ancestor_of(control):
		game.equipment.scroll.ensure_control_visible(control)
	await frames()
	var point := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		Input.parse_input_event(event)
		await frames()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://equipment_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实窗口截图 " + label)
	print("EQUIPMENT_CAPTURE: " + ProjectSettings.globalize_path(path))

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Equipment-"):
		printerr("Equipment checks require an isolated Cun-Equipment-* save directory.")
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
	var gear = game.equipment
	check(gear.equipped.is_empty() and gear.bonuses().attack == 0 and game.incoming_damage(10) == 10, "新局空装备与基础战斗数值不变")
	await key(KEY_C)
	check(gear.is_open() and game._paused(), "真实C键打开装备面板并暂停")
	check(gear.item_buttons.is_empty() and gear.equip_button.disabled and gear.unequip_button.disabled, "无装备显示空态，操作禁用")
	await capture("empty")
	check(not gear.equip_item("s1-top") and not gear.equip_item("herb") and not gear.equip_item("unknown"), "未拥有、材料与未知ID不能穿戴")
	await key(KEY_ESCAPE)
	check(not gear.is_open() and not game._paused(), "Esc关闭装备面板")
	await click(gear.entry_button)
	check(gear.is_open(), "真实鼠标入口打开面板")
	# All art-backed items must map to a supported slot and be wearable.
	for item: String in Loot.ITEMS:
		game.inventory[item] = 1
		check(Catalog.SLOTS.has(Catalog.slot(item)) and gear.equip_item(item), "现有装备可穿戴 " + item)
	var total: int = game._inventory_total()
	var counts: Dictionary = game.inventory.duplicate()
	check(gear.equipped.size() == 6, "所有品质装备均只能占用对应的六个栏位")
	for item: String in Loot.ITEMS:
		check(gear.equip_item(item) or gear.equipped.values().has(item), "同部位装备可反复替换 " + item)
	check(game.inventory == counts and game._inventory_total() == total, "连续替换不丢失或增加任何已收集数量")
	check(not gear.equip_item(gear.equipped.weapon), "重复穿戴同一件装备不叠加")
	for slot: String in Catalog.SLOTS:
		check(gear.unequip_slot(slot) and not gear.unequip_slot(slot), "卸下只执行一次 " + slot)
	check(gear.bonuses() == {"attack": 0, "defense": 0, "speed": 0} and game.inventory == counts, "全卸下恢复基础属性且装备数量不变")
	gear.filter.select(0)
	gear.filter_slot = ""
	gear.refresh()
	await capture("collection")
	await click(gear.item_buttons["w02-ruinsplitter"])
	check(gear.selected == "w02-ruinsplitter" and gear.comparison.text.contains("+18"), "真实鼠标选武器并查看伤害差值")
	await click(gear.equip_button)
	check(gear.equipped.weapon == "w02-ruinsplitter" and gear.equip_button.disabled and not gear.unequip_button.disabled, "真实鼠标穿戴并刷新按钮状态")
	await click(gear.item_buttons["w01-ashen-echo"])
	check(gear.comparison.text.contains("-6") and gear.comparison.text.contains("+2"), "替换预览包含负伤害与正减伤")
	await click(gear.equip_button)
	check(gear.equipped.weapon == "w01-ashen-echo" and gear.available("w02-ruinsplitter") == 1, "真实替换释放旧武器")
	await click(gear.unequip_button)
	check(not gear.equipped.has("weapon") and gear.available("w01-ashen-echo") == 1, "真实卸下回到可用物品")
	for item: String in ["w03-prism-saber", "s3-top", "s3-legs", "s1-boots", "s2-necklace", "s2-ring"]:
		gear.equip_item(item)
	await click(gear.slot_buttons.top)
	check(gear.filter_slot == "top" and gear.item_buttons.size() == (6 if Loot.ITEMS.has("s1-top@mutated") else 3) and gear.selected == "s3-top", "点击上衣栏位筛选全部品质的上衣")
	gear.filter.select(0)
	gear.filter_slot = ""
	gear.refresh()
	await capture("equipped")
	check(gear.panel.get_global_rect().end.y <= 720 and gear.unequip_button.get_global_rect().end.y < 680, "面板与操作按钮处于720p视口内")
	# Pause every subsystem through the same predicate used in normal gameplay.
	var hp: int = game.health
	var foot: Vector2 = game.player_foot
	var cd: Dictionary = game.cooldowns.duplicate()
	var weather = game.get_node("Weather")
	var elapsed: float = weather.elapsed
	var traps = game.get_node("Traps")
	var timer: float = traps.timers[game.region]
	game._process(0.1)
	weather.tick(1.0)
	traps.tick(1.0)
	game.get_node("Bosses").tick(1.0)
	await key(KEY_J)
	await key(KEY_M)
	await key(KEY_B)
	check(game.health == hp and game.player_foot == foot and game.cooldowns == cd and weather.elapsed == elapsed and traps.timers[game.region] == timer and not game.tools.is_open() and not game.journal.visible, "装备面板暂停移动、技能、天气、陷阱、首领且拦截其他快捷键")
	await key(KEY_C)
	var attack: int = gear.bonuses().attack
	# J and K run the actual action and collision paths, against living targets.
	game.states[game.region].enemies = [{"position": game.player_foot + Vector2(80, 0), "hp": 500, "flash": 0.0}]
	var enemy: Dictionary = game.states[game.region].enemies[0]
	game.facing = Vector2.RIGHT
	game.cooldowns.j = 0
	check(game.attack("j") and enemy.hp == 500 - 26 - attack, "穿戴后J近战伤害实际增加")
	game.cooldowns.k = 0
	var before: int = enemy.hp
	check(game.attack("k"), "K真实发射灵弹")
	game._tick_projectiles(0.1)
	check(enemy.hp == before - 3 * (20 + attack), "棱光长刀三颗灵弹碰撞均使用装备伤害")
	game.cooldowns.l = 0
	before = enemy.hp
	check(game.attack("l") and enemy.hp == before - 42 - attack, "L范围攻击实际使用装备伤害")
	var defense: int = gear.bonuses().defense
	check(defense > 0 and game.incoming_damage(20) == 20 - defense and game.incoming_damage(1) == 1, "减伤计算生效且不能免疫全部伤害")
	enemy.position = game.player_foot
	enemy.damage = 20
	game.hurt_timer = 0
	game.health = 100
	game._process(0.01)
	check(game.health == 100 - (20 - defense), "怪物接触伤害实际经过装备减伤")
	game.health = 100
	game.hurt_timer = 0
	for y in range(500, 2000, 150):
		for x in range(600, 3000, 150):
			if traps.valid_point(game.region, Vector2(x, y), 85):
				game.player_foot = Vector2(x, y)
	var hazard := {"damage": 20, "position": game.player_foot, "hit": false}
	# Trap hit also exercises the shared incoming-damage hook directly.
	traps._try_hit(hazard, {"radius": 100.0, "duration": 0.0, "push": 0.0, "name": "测试陷阱"})
	check(game.health == 100 - (20 - defense), "地图陷阱实际经过装备减伤")
	game.health = 100
	game.hurt_timer = 0
	traps.slow_left = 0
	var bosses = game.get_node("Bosses")
	var boss: Dictionary = bosses.bosses.H02
	var boss_config: Dictionary = bosses.Catalog.DEFINITIONS.H02
	boss.windup = 0.001
	boss.target = game.player_foot
	bosses.tick(0.01)
	check(game.health == 100 - maxi(1, int(boss_config.damage) - defense), "首领预警攻击实际经过装备减伤")
	# Exercise real movement input rather than merely reading the computed speed.
	enemy.position = game.player_foot + Vector2(700, 0)
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	foot = game.player_foot
	await key(KEY_D) # key() releases after three frames; process is disabled here.
	var held := InputEventKey.new()
	held.physical_keycode = KEY_D
	held.pressed = true
	Input.parse_input_event(held)
	await frames()
	game._process(0.1)
	var distance: float = game.player_foot.distance_to(foot)
	check(absf(distance - (260 + int(gear.bonuses().speed)) * 0.1) < 0.1, "战靴与武器移速进入真实WASD移动")
	held.pressed = false
	Input.parse_input_event(held)
	var loadout: Dictionary = gear.equipped.duplicate()
	for region: String in Maps.IDS:
		game.enter_region(region)
	check(gear.equipped == loadout and game.inventory == counts, "所有地图旅行保留穿戴与物品数量")
	game.open_journal()
	await key(KEY_C)
	check(not gear.is_open(), "行囊打开时不能叠加装备面板")
	game.journal.hide()
	game.tools.open_map()
	await key(KEY_C)
	check(not gear.is_open(), "地图打开时不能叠加装备面板")
	game.tools.atlas.close()
	game.finished = true
	check(not gear.equip_item("s1-top") and not gear.unequip_slot("top"), "结算时禁止修改穿戴")
	game.finished = false
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	check(game.equipment.equipped.is_empty() and game._inventory_total() == 0, "真实重开清空装备与穿戴状态")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "穿戴、战斗、跨图与重开未修改灵伴存档")
	print("EQUIPMENT_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
