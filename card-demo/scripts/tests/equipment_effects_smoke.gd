extends "res://scripts/tests/equipment_smoke.gd"
var gear
var fx

func wear(id: String = "", amount: int = 0, weapon: String = "") -> void:
	game.finished = false
	gear.close()
	for slot: String in Catalog.SLOTS:
		gear.unequip_slot(slot)
	for i in range(amount):
		gear.equip_item(Loot.SETS[id][i])
	if weapon != "":
		gear.equip_item(weapon)
	game.health = 100
	game.hurt_timer = 0.0
	game.cooldowns = {"j": 0.0, "k": 0.0, "l": 0.0}
	game.effects.clear()
	game.projectiles.clear()
	game.states[game.region].enemies.clear()

func target(distance: float = 80.0, hp: int = 500) -> Dictionary:
	var enemy := {"position": game.player_foot + Vector2(distance, 0), "hp": hp, "max_hp": 500, "flash": 0.0, "speed": 76.0}
	game.states[game.region].enemies.append(enemy)
	return enemy

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Equipment-"):
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	gear = game.equipment
	fx = gear.effects
	for item: String in Loot.ITEMS:
		game.inventory[item] = 2
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.facing = Vector2.RIGHT
	var counts: Dictionary = game.inventory.duplicate()
	check(Catalog.set_counts(gear.equipped) == {"s1": 0, "s2": 0, "s3": 0}, "背包副本与武器不计入套装数量")
	for id: String in Loot.SETS:
		for n in [1, 2, 3, 4, 5]:
			wear(id, n)
			check(fx.count(id) == n, "不同部位计数 %s %d件" % [id, n])
	wear("s1", 2)
	gear.selected = "s2-legs"
	gear._refresh_detail()
	check(gear.comparison.text.contains("-23"), "换装预览包含拆掉追归2件造成的移速损失")
	gear.equip_item("s3-boots")
	gear.equip_item("s3-ring")
	check(fx.count("s1") == 2 and fx.count("s3") == 2 and gear.bonuses().speed == 41 and gear.bonuses().defense == 10, "混穿2追归与2镜潮同时激活各自2件效果")
	wear("s1", 1)
	check(gear.bonuses().speed == 3 and fx.cooldown_scale() == 1.0, "追归1件不触发套装")
	gear.equip_item("s1-legs")
	check(gear.bonuses().speed == 26, "追归2件额外移速20")
	wear("s1", 4)
	var enemy := target()
	game.attack("j")
	check(is_equal_approx(game.cooldowns.j, 0.32 * 0.85), "追归4件实际缩短J冷却")
	game.attack("k")
	check(is_equal_approx(game.cooldowns.k, 0.85 * 0.85), "追归4件实际缩短K冷却")
	game.attack("l")
	check(is_equal_approx(game.cooldowns.l, 3.5 * 0.85), "追归4件实际缩短L冷却")
	gear.unequip_slot("necklace")
	game.cooldowns.j = 0
	game.attack("j")
	check(is_equal_approx(game.cooldowns.j, 0.32), "卸至3件后新攻击恢复原冷却")
	wear("s1", 5)
	fx.heal_ready = fx.elapsed
	enemy = target()
	target(90)
	game.health = 60
	game.attack("j")
	check(game.health == 64, "追归5件群体命中仅恢复4生命一次")
	game.cooldowns.j = 0
	game.attack("j")
	check(game.health == 64, "追归治疗1秒内不能重复触发")
	fx.tick(1.0)
	game.health = 99
	game.cooldowns.j = 0
	game.attack("j")
	check(game.health == 100 and fx.notice.contains("+1生命"), "追归治疗到期恢复且不超过上限，提示实际恢复值")
	gear.unequip_slot("ring")
	fx.tick(1.0)
	game.health = 50
	game.cooldowns.j = 0
	game.attack("j")
	check(game.health == 50, "拆掉5件后治疗立即失效")
	wear("s2", 1)
	check(gear.bonuses().attack == 1, "烽炉1件仅有单件伤害")
	gear.equip_item("s2-legs")
	check(gear.bonuses().attack == 8, "烽炉2件追加6伤害")
	wear("s2", 4)
	enemy = target()
	game.attack("j")
	var before: int = enemy.hp
	fx.tick(0.99)
	check(enemy.hp == before and fx.burns.size() == 1, "烽炉4件命中附灼烧，满一秒前不结算")
	fx.tick(0.01)
	check(enemy.hp == before - 6, "灼烧一秒实际扣6生命")
	fx.tick(2.0)
	check(enemy.hp == before - 18 and fx.burns.is_empty(), "灼烧完整三跳且不递归触发灼烧")
	game.cooldowns.j = 0
	game.attack("j")
	var next: float = fx.burns[0].next
	fx.tick(0.5)
	game.cooldowns.j = 0
	game.attack("j")
	check(fx.burns.size() == 1 and fx.burns[0].next == next, "多次命中只刷新灼烧，不叠加也不延后下一跳")
	gear.unequip_slot("necklace")
	check(fx.burns.is_empty(), "换装立即清理遗留灼烧")
	wear("s2", 5)
	enemy = target(220)
	check(game.attack("l") and enemy.hp == 500 - (42 + int(gear.bonuses().attack) + 12), "烽炉5件L扩大范围并额外造成12伤害")
	check(fx.attack_radius("l", 180) == 230 and fx.attack_radius("j", 112) == 112, "烽炉仅扩大L范围")
	gear.unequip_slot("ring")
	check(fx.attack_radius("l", 180) == 180, "卸至4件取消L范围加成")
	wear("s3", 2)
	check(gear.bonuses().defense == 10, "镜潮2件额外减伤3")
	wear("s3", 4)
	var armor: int = gear.bonuses().defense
	check(game.incoming_damage(40) == ceili((40 - armor) * 0.8) and game.incoming_damage(1) == 1, "镜潮4件固定减伤后再减20%，至少1点")
	wear("s3", 5)
	check(fx.shield_points == 0, "镜潮5件初穿不免费获得护盾")
	fx.tick(7.99)
	check(fx.shield_points == 0, "护盾满8秒前不生成")
	fx.tick(0.01)
	check(fx.shield_points == 18, "满8秒获得18护盾")
	await capture("shield")
	enemy = target(0)
	enemy.damage = 20
	game._process(0.01)
	check(game.health == 100 and fx.shield_points < 18, "护盾实际吸收怪物伤害")
	var shield: int = fx.shield_points
	var remainder: int = game.incoming_damage(100)
	check(remainder == ceili((100 - int(gear.bonuses().defense)) * 0.8) - shield and fx.shield_points == 0, "大伤害击破护盾后剩余伤害正确")
	fx.tick(8)
	fx.tick(8)
	check(fx.shield_points == 18, "多周期护盾刷新而不叠加")
	gear.unequip_slot("ring")
	gear.equip_item("s3-ring")
	check(fx.shield_points == 0 and fx.shield_charge == 0, "拆套重穿清除护盾且需要重新等待")
	fx.tick(8.0)
	var traps = game.get_node("Traps")
	for y in range(500, 2000, 150):
		for x in range(600, 3000, 150):
			if traps.valid_point(game.region, Vector2(x, y), 85):
				game.player_foot = Vector2(x, y)
	game.health = 100
	game.hurt_timer = 0
	var hazard := {"damage": 20, "position": game.player_foot, "hit": false}
	traps._try_hit(hazard, {"radius": 100.0, "duration": 0.0, "push": 0.0, "name": "护盾测试陷阱"})
	check(hazard.hit and game.health == 100 and fx.shield_points < 18 and traps.notice.contains("-0生命"), "镜潮护盾实际吸收陷阱伤害并显示扣血0")
	fx.tick(8.0)
	game.hurt_timer = 0
	var bosses = game.get_node("Bosses")
	var boss: Dictionary = bosses.bosses.H02
	boss.windup = 0.001
	boss.target = game.player_foot
	bosses.tick(0.01)
	check(game.health == 100 and fx.shield_points < 18, "镜潮护盾实际吸收Boss预警攻击")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	# Weapon effects run through the actual attack paths.
	wear("", 0, "w01-ashen-echo")
	fx.echo_ready = fx.elapsed
	enemy = target()
	game.attack("j")
	before = enemy.hp
	fx.tick(0.34)
	check(enemy.hp == before and fx.pending.size() == 1, "回响有完整0.35秒延迟")
	fx.tick(0.01)
	check(enemy.hp == before - 10 and fx.pending.is_empty(), "回响追加10伤害且不递归")
	game.cooldowns.j = 0
	game.attack("j")
	check(fx.pending.is_empty(), "回响2秒内不重复触发")
	gear.unequip_slot("weapon")
	gear.equip_item("w01-ashen-echo")
	game.cooldowns.j = 0
	game.attack("j")
	check(fx.pending.is_empty(), "换武器不能刷新回响内置冷却")
	wear("", 0, "w02-ruinsplitter")
	enemy = target(80, 175)
	game.attack("j")
	check(enemy.hp == 175 - ceili((26 + 18) * 1.6), "裂墟重刃在35%生命阈值增伤60%")
	enemy.hp = 176
	game.cooldowns.j = 0
	game.attack("j")
	check(enemy.hp == 176 - 26 - 18, "高于35%时不触发破墟斩")
	wear("", 0, "w03-prism-saber")
	enemy = target()
	game.attack("k")
	check(game.projectiles.size() == 3 and game.projectiles[0].velocity != game.projectiles[2].velocity, "棱光长刀发射三条不同方向灵弹")
	game._tick_projectiles(0.1)
	check(enemy.hp == 500 - 3 * (20 + 14), "近距离三颗灵弹均可实际命中")
	wear("", 0, "w05-bone-halberd")
	enemy = target(170)
	game.attack("j")
	check(enemy.hp < 500 and fx.enemy_speed_scale(enemy) == 0.65, "骨枝长戟扩大J范围并减速")
	var start: Vector2 = enemy.position
	game._process(0.1)
	check(absf(start.distance_to(enemy.position) - 76.0 * 0.65 * 0.1) < 0.1, "小怪追踪实际使用缚根减速")
	fx.tick(2.0)
	check(fx.enemy_speed_scale(enemy) == 1.0, "缚根2秒到期恢复移速")
	boss.position = game.player_foot + Vector2(160, 0)
	boss.home = boss.position
	boss.cooldown = 10.0
	boss.windup = 0.0
	game.cooldowns.j = 0
	game.attack("j")
	start = boss.position
	bosses.tick(0.1)
	check(fx.enemy_speed_scale(boss) == 0.65 and absf(start.distance_to(boss.position) - float(bosses.Catalog.DEFINITIONS.H02.speed) * 0.65 * 0.1) < 0.1, "长戟减速作用于真实Boss追踪且不取消预警")
	boss.position = boss.home + Vector2(700, 0)
	wear("", 0, "w06-falling-crag")
	enemy = target(100)
	game.attack("l")
	before = enemy.hp
	fx.tick(0.44)
	check(enemy.hp == before, "重锤余震完整预留0.45秒")
	fx.tick(0.01)
	check(enemy.hp == before - 18 and fx.pending.is_empty(), "重锤原地余震真实追加18伤害")
	await capture("quake")
	# Delay damage can kill and settle loot exactly once.
	game.cooldowns.l = 0
	game.attack("l")
	enemy.hp = 1
	fx.tick(0.45)
	check(enemy.hp == 0 and not game.states[game.region].enemies.has(enemy), "余震致死进入正常掉落清理")
	var pickups: int = game.states[game.region].pickups.size()
	fx.tick(1.0)
	check(game.states[game.region].pickups.size() == pickups, "追加伤害致死不重复结算掉落")
	wear("", 0, "w01-ashen-echo")
	fx.echo_ready = fx.elapsed
	enemy = target()
	game.attack("j")
	before = enemy.hp
	game.set_process(true)
	await create_timer(0.43).timeout
	game.set_process(false)
	check(enemy.hp == before - 10, "真实游戏逐帧推进自动触发回响，无需手动tick")
	wear("s2", 5, "w01-ashen-echo")
	fx.echo_ready = fx.elapsed
	enemy = target()
	game.attack("j")
	gear.open()
	var clock: float = fx.elapsed
	before = enemy.hp
	fx.tick(20)
	check(fx.elapsed == clock and enemy.hp == before and not fx.pending.is_empty() and not fx.burns.is_empty(), "装备面板暂停特效时钟、回响与灼烧")
	gear.close()
	for modal: String in ["map", "dialogue", "journal", "confirm", "outcome"]:
		match modal:
			"map": game.tools.open_map()
			"dialogue": game.dialogue.show()
			"journal": game.open_journal()
			"confirm": game.tools.confirm.show()
			"outcome": game.finished = true
		fx.tick(10)
		check(fx.elapsed == clock and enemy.hp == before, "特效计时在模态/结算暂停 " + modal)
		game.tools.atlas.close()
		game.dialogue.hide()
		game.journal.hide()
		game.tools.confirm.hide()
		game.finished = false
	gear.open()
	await click(gear.effects_button)
	check(gear.effects_view.visible and gear.effects_view.text.contains("已激活 5件") and gear.effects_view.text.contains("未激活 2件") and gear.effects_view.text.contains("余烬回响"), "真实点击特效页显示激活档位和武器说明")
	await capture("set_effects")
	await click(gear.effects_button)
	gear.selected = "w01-ashen-echo"
	gear._refresh_detail()
	check(gear.special_label.text.contains("余烬回响"), "装备详情可见武器特殊效果")
	await capture("weapon_detail")
	check(gear.panel.get_global_rect().end.y <= 720 and gear.unequip_button.get_global_rect().end.y < 680, "扩充特效后面板仍完整显示于720p")
	gear.close()
	# Travel cancels offensive effects but keeps global cooldown and shield time.
	var ready: float = fx.echo_ready
	game.enter_region("post")
	check(fx.pending.is_empty() and fx.burns.is_empty() and fx.echo_ready == ready, "跨地图取消残留特效但保留内置冷却")
	wear("s3", 5)
	fx.tick(9.0)
	var charge: float = fx.shield_charge
	game.enter_region("grove")
	check(fx.shield_points == 18 and fx.shield_charge == charge, "旅行保留镜潮护盾及充能进度")
	if Loot.ITEMS.has("w01-ashen-echo@mutated"):
		wear("", 0, "w01-ashen-echo@mutated")
		game.enter_region("grove")
		fx.echo_ready = fx.elapsed
		enemy = target()
		game.attack("j")
		before = enemy.hp
		fx.tick(0.35)
		check(fx.weapon() == "w01-ashen-echo" and enemy.hp == before - 10, "异变品质武器保留基础武器的回响效果")
		wear()
		for item: String in Loot.SETS.s1:
			gear.equip_item(item + "@mutated")
		check(fx.count("s1") == 5 and fx.cooldown_scale() == 0.85, "异变品质防具按所属系列正常累计套装件数")
	check(game.inventory == counts, "套装切换和特效不改变收集数量")
	game.restart()
	await frames()
	game = current_scene
	game.set_process(false)
	check(game.equipment.effects.elapsed < 0.5 and game.equipment.effects.shield_points == 0 and game.equipment.effects.echo_ready == 0 and game.equipment.effects.pending.is_empty() and game.equipment.equipped.is_empty(), "真实重开重置套装、武器时钟、待触发队列和护盾")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "套装与武器特殊效果不写灵伴存档")
	print("EQUIPMENT_RESULT: effects %d checks, %d failures" % [checks, failures])
	await finish_checks()
