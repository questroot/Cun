extends "res://scripts/tests/fudi_progress_smoke.gd"
var origin := Vector2.ZERO

func capture(label: String) -> void:
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await super.capture(label)

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Fudi-Refinements-"):
		quit(2)
		return
	await frames()
	var spirit_path: String = root.get_node("DataManager").SAVE_PATH
	root.get_node("DataManager").write_save()
	var before := FileAccess.get_file_as_string(spirit_path)
	await open_game()
	if "--verify-relaunch" in OS.get_cmdline_user_args():
		check(game.book.tracked == "stove" and game.inventory.field_bandage == 1, "新进程恢复追踪任务和使用后剩余的补给")
		check(game.states.grove.enemies[0].behavior == "charger" and game.states.grove.enemies[0].guard_phase == "idle" and game.guards.shots.is_empty(), "保存守卫角色，读档取消旧攻击与飞弹")
		check(game.states.grove.rested, "修补后再次使用的休息次数被保存")
		check(is_equal_approx(game.mana, 26.5) and game.inventory.wakeleaf_potion == 1, "新进程恢复法力和药水库存")
	else:
		await check_guards()
		await check_enemy_feedback()
		await check_player_ailments()
		await check_book_and_supplies()
		await check_mana_supplies()
		await check_legacy_save()
	check(FileAccess.get_file_as_string(spirit_path) == before, "改进系统不修改灵伴存档")
	print("FUDI_REFINEMENTS_RESULT: %d checks, %d failures" % [checks, failures])
	current_scene.free()
	current_scene = null
	await frames()
	quit(1 if failures else 0)

func corridor() -> Vector2:
	for y in range(200, 2100, 20):
		for x in range(200, 3100, 20):
			var point := Vector2(x, y)
			var clear := true
			for dx in range(0, 401, 16):
				if not Maps.walkable("grove", point + Vector2(dx, 0), 30):
					clear = false
					break
			if not clear: continue
			for dx in [60, 180, 300]:
				if not Maps.walkable("grove", point + Vector2(dx, 140), 16): clear = false
			for dy in range(0, 121, 12):
				if not Maps.walkable("grove", point + Vector2(60, dy), 20): clear = false
			if clear: return point
	return Vector2.ZERO

func guard_fixture(kind: String, distance: float) -> Dictionary:
	var enemy: Dictionary = game.states.grove.enemies[0]
	for other: Dictionary in game.states.grove.enemies: other.position = origin + Vector2(900, 0)
	enemy.position = origin
	enemy.behavior = kind
	enemy.damage = 10
	enemy.speed = 76.0
	enemy.weather = "clear"
	game.Guards.reset(enemy)
	enemy.guard_left = 0.0
	game.player_foot = origin + Vector2(distance, 0)
	game.health = 100
	game.hurt_timer = 0
	game.guards.shots.clear()
	game._update_camera()
	return enemy

func check_guards() -> void:
	origin = corridor()
	check(origin != Vector2.ZERO, "真实地图存在无遮挡测试走廊")
	var kinds := {}
	for enemy: Dictionary in game.states.grove.enemies: kinds[enemy.behavior] = true
	check(kinds.size() == 3, "同一地图实际混编三类守卫")
	var enemy := guard_fixture("melee", 60)
	game.guards.tick(0.01)
	check(enemy.guard_phase == "windup" and game.health == 100, "贴近不再直接扣血，近战先完整蓄力")
	check(not game.guards.play_visible().is_empty(), "公开观察只返回实际绘制的攻击预警")
	var camera: Vector2 = game.camera_origin
	game.camera_origin = Vector2(9000, 9000)
	check(game.guards.play_visible().is_empty(), "屏外守卫预警不进入公开观察")
	game.camera_origin = camera
	await capture("melee-windup")
	var locked: Vector2 = enemy.guard_target
	game.player_foot += Vector2(0, 140)
	game.guards.tick(0.66)
	check(game.health == 100 and enemy.guard_target == locked, "离开锁定近战圈可闪避，蓄力不追踪位置")
	enemy = guard_fixture("melee", 60)
	game.guards.tick(0.01)
	game.guards.tick(0.66)
	check(game.health == 90 and enemy.guard_phase == "recover", "站在圈内只结算一次攻击并进入恢复")
	game.hurt_timer = 0
	game.guards.tick(0.1)
	check(game.health == 90, "攻击恢复期不会反复接触扣血")
	enemy = guard_fixture("melee", 60)
	game.guards.tick(0.01)
	var move := InputEventKey.new()
	move.physical_keycode = KEY_S
	move.pressed = true
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	for i in range(14): game._process(0.05)
	move = move.duplicate()
	move.pressed = false
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	check(game.health == 100 and game.player_foot.y > origin.y + 65, "真实S按键移动可在近战蓄力期间走出攻击圈")
	enemy = guard_fixture("ranged", 300)
	game.guards.tick(0.01)
	check(enemy.guard_phase == "windup", "投石守卫在远处停止追逐并预瞄")
	await capture("ranged-windup")
	game.guards.tick(0.66)
	check(game.guards.shots.size() == 1 and game.health == 100, "投石生成有飞行时间的实际弹体")
	game.guards.tick(0.3)
	check(game.health == 90 and game.guards.shots.is_empty(), "飞石命中使用实际防御接口并销毁")
	enemy = guard_fixture("ranged", 300)
	game.guards.release(enemy)
	var short_shot: Dictionary = game.guards.shots[0]
	short_shot.life = 0.02
	game.guards.tick(0.1)
	check(short_shot.position.distance_to(origin) <= 6.21 and game.guards.shots.is_empty(), "飞石最后一帧仅移动剩余寿命距离，不越出预警")
	enemy = guard_fixture("ranged", 300)
	game.guards.tick(0.01)
	game.player_foot += Vector2(0, 120)
	game.guards.tick(0.66)
	game.guards.tick(1.0)
	check(game.health == 100, "横移可躲开已锁定的投石方向")
	enemy = guard_fixture("charger", 180)
	game.guards.tick(0.01)
	check(enemy.guard_phase == "windup" and enemy.guard_left == 0.9, "冲锋提供0.9秒可见直道预警")
	await capture("charge-windup")
	game.guards.tick(0.91)
	game.guards.tick(0.36)
	check(game.health == 90 and enemy.position.x > origin.x + 170, "冲锋实际位移，扫过玩家时结算一次伤害")
	game.hurt_timer = 0
	game.guards.tick(0.1)
	check(game.health == 90, "一次冲锋不会重复命中")
	enemy = guard_fixture("charger", 180)
	game.guards.tick(0.01)
	game.journal.show()
	var left: float = enemy.guard_left
	game.guards.tick(1)
	check(enemy.guard_left == left, "行囊打开暂停守卫预警")
	game.journal.hide()
	game.player_foot += Vector2(0, 140)
	game.guards.tick(0.91)
	game.guards.tick(0.36)
	check(game.health == 100, "侧移离开直道可躲冲锋")
	check(enemy.position.x <= origin.x + 224, "冲锋时间到期不会因最后一帧多走而超出预警距离")
	check_wall_collision()
	enemy = guard_fixture("ranged", 300)
	game.guards.tick(0.01)
	game.guards.tick(0.66)
	enemy.hp = 0
	game.guards.tick(0.1)
	check(game.guards.shots.is_empty(), "击败投石者取消其未命中的飞石")
	enemy.hp = 60
	game.enter_region("post")
	check(game.guards.shots.is_empty(), "切图清除守卫弹体")
	game.enter_region("grove")
	check(enemy.guard_phase == "idle" and enemy.guard_left >= 1, "回图取消旧攻击并保留反应时间")
	var bosses = game.get_node("Bosses")
	var boss: Dictionary = bosses.bosses.H02
	game.player_foot = boss.home + Vector2(40, 0)
	boss.cooldown = 0
	bosses.tick(0.01)
	check(boss.windup > 0, "首领真实进入起手姿态")
	await capture("boss-windup")
	bosses.tick(boss.windup + 0.01)
	check(boss.attack_pose > 0, "首领结算技能时触发出招姿态")
	await capture("boss-strike")
	game._damage(boss, 1)
	check(boss.flash > 0, "首领受击姿态与真实受伤连接")
	await capture("boss-hurt")
	game.health = 100
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size

func check_enemy_feedback() -> void:
	game.enter_region("grove")
	var enemy: Dictionary = game.Guards.create(game.player_foot + Vector2(80, 0), "melee")
	game.guards.recover(enemy)
	game.states.grove.enemies.append(enemy)
	var point: Vector2 = enemy.position
	game._damage(enemy, 1)
	var bursts: Array = game.enemy_feedback.bursts
	check(enemy.hp < 60 and enemy.flash > 0 and enemy.hit_direction == Vector2.RIGHT and enemy.position == point and not bursts[-1].fallen, "实际受伤触发方向性受击反馈，碰撞位置保持原位")
	await capture("guard-hit")
	game.journal.show()
	game._process(0.3)
	check(bursts.size() == 1 and bursts[0].age == 0.0, "行囊暂停受击火花")
	game.journal.hide()
	game._process(0.3)
	check(bursts.is_empty() and enemy.position == point, "火花正常结束，守卫无击退位移")
	game.equipment.effects.secondary_damage(enemy, 999, "测试追加伤害", Color.WHITE)
	game._remove_dead()
	check(not game.combat_targets().has(enemy) and bursts.size() == 1 and bursts[0].fallen, "追加伤害击杀后目标立即移除，原地保留阵亡特效")
	game._damage(enemy, 999)
	check(bursts.size() == 1, "死亡目标不会重复产生阵亡特效")
	game.enemy_feedback.tick(0.15)
	await capture("guard-fallen")
	game._process(0.6)
	check(bursts.is_empty(), "阵亡特效播完自动清除")
	var boss: Dictionary = game.get_node("Bosses").bosses.H02
	game.player_foot = boss.position - Vector2(135, 0)
	game._damage(boss, 9999)
	game._remove_dead()
	check(not game.combat_targets().has(boss) and bursts.size() == 1 and bursts[0].fallen and bursts[0].boss, "地图首领阵亡特效与掉落同步触发")
	game.enemy_feedback.tick(0.20)
	await capture("boss-fallen")
	game.enter_region("post")
	check(bursts.is_empty(), "切图清除阵亡特效")
	game.enter_region("grove")

func check_player_ailments() -> void:
	var ailments: Dictionary = game.player_ailments
	for weather: String in game.Guards.HIT_AILMENTS:
		var enemy := guard_fixture("melee", 60)
		enemy.weather = weather
		enemy.guard_target = game.player_foot
		game.guards.release(enemy)
		var key: String = game.Guards.HIT_AILMENTS[weather]
		check(game.health < 100 and ailments.has(key), "属性攻击造成伤害并附着对应特效 " + weather)
		if weather == "heat":
			await capture("player-burn")
		game.journal.show()
		game._process(0.5)
		check(ailments[key].age == 0.0, "暂停冻结角色异常特效 " + weather)
		game.journal.hide()
		game._process(1.0)
		check(ailments.is_empty(), "角色异常特效到期消失 " + weather)
	var thrower := guard_fixture("ranged", 150)
	thrower.weather = "storm"
	game.guards.release(thrower)
	thrower.weather = "clear"
	game.guards.tick(0.5)
	check(game.health < 100 and ailments.has("status-stun"), "飞石命中沿用出手时的雷属性")
	game.take_enemy_hit(10, "status-freeze")
	check(not ailments.has("status-freeze"), "受伤保护阻止异常伤害特效")
	game.enter_region("archive")
	check(ailments.is_empty(), "切图清除玩家异常特效")
	var bosses = game.get_node("Bosses")
	var frost_boss: Dictionary = bosses.bosses.H05
	game.player_foot = frost_boss.position
	bosses.Skills.lock(frost_boss, game.player_foot)
	frost_boss.windup = 0.01
	game.hurt_timer = 0.0
	bosses.tick(0.02)
	check(ailments.has("status-freeze"), "霜典记录者的实际技能命中附着冰霜")
	game.enter_region("grove")
	game.health = 100

func check_wall_collision() -> void:
	var wall_start := Vector2.ZERO
	for y in range(100, 2200, 40):
		for x in range(100, 3200, 20):
			var point := Vector2(x, y)
			if Maps.walkable("grove", point, 30) and not Maps.walkable("grove", point + Vector2(60, 0), 0) and Maps.walkable("grove", point + Vector2(300, 0), 30):
				wall_start = point
				break
		if wall_start != Vector2.ZERO: break
	check(wall_start != Vector2.ZERO, "真实地图存在两侧可站立的墙体夹具")
	if wall_start == Vector2.ZERO: return
	var enemy := guard_fixture("ranged", 300)
	enemy.position = wall_start
	game.player_foot = wall_start + Vector2(300, 0)
	enemy.guard_phase = "recover"
	enemy.guard_left = 3
	game.guards.shots.append({"owner": enemy, "position": wall_start, "velocity": Vector2(310, 0), "damage": 10, "life": 2.0, "weather": enemy.weather})
	game.guards.tick(1.3)
	check(game.health == 100 and game.guards.shots.is_empty(), "高速飞石逐段先撞墙，不能穿墙命中玩家")
	enemy.behavior = "charger"
	game.Guards.reset(enemy)
	enemy.guard_phase = "charge"
	enemy.guard_direction = Vector2.RIGHT
	enemy.guard_left = 0.36
	game.guards.tick(0.36)
	check(Maps.walkable("grove", enemy.position, 20) and enemy.position.x < wall_start.x + 60 and game.health == 100, "冲锋沿地图碰撞停止，不能穿透墙体")

func check_book_and_supplies() -> void:
	await tap(KEY_B)
	check(game.journal.visible and game.book.tabs.get_tab_count() == 4, "真实B打开物品、委托、见闻、帮助四页")
	check(not game.book.texts[0].text.contains("首领 · 小地图"), "物品页不混入百科规则")
	check(not game.book.texts[2].text.contains(str(Maps.MAPS.archive.sites[2][2])), "未调查的剧情不会在见闻页泄露")
	game.inventory.bloodgrass = 4
	game.inventory.fiber = 2
	game.inventory.herb = 2
	game.inventory.dewleaf = 1
	game.inventory.berry = 2
	game.inventory.mint = 1
	game.book.refresh()
	await click(game.book.craft_buttons.field_bandage)
	check(game.inventory.field_bandage == 1 and game.inventory.bloodgrass == 2 and game.inventory.fiber == 1, "真实制作按钮精确扣除止血草2与纤维1")
	await click(game.book.craft_buttons.field_bandage)
	check(game.inventory.field_bandage == 2 and not game.supplies.craft("field_bandage"), "不足材料不额外制作或扣料")
	for id: String in ["herbal_draught", "berry_tonic"]:
		await click(game.book.craft_buttons[id])
		check(game.inventory[id] == 1, "实际制作恢复品 " + id)
	game.health = 90
	game.book.refresh()
	await click(game.book.use_buttons.herbal_draught)
	check(game.health == 100 and game.inventory.herbal_draught == 0, "使用药饮精确扣一份且生命封顶")
	check(not game.supplies.use("berry_tonic") and game.inventory.berry_tonic == 1, "满血不消耗恢复品")
	game.health = 40
	game.book.refresh()
	await click(game.book.use_buttons.berry_tonic)
	check(game.health == 85 and game.inventory.berry_tonic == 0, "不同配方拥有实际45点恢复效果")
	game.inventory.wood = 6
	game.inventory.resin = 2
	game.states.grove.rested = true
	game.player_foot = origin
	check(not game.supplies.repair(), "远离休息点不能远程修补")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.book.refresh()
	await click(game.book.repair_button)
	check(not game.states.grove.rested and game.inventory.wood == 3 and game.inventory.resin == 1, "修补精确消耗木料3松脂1并恢复休息机会")
	check(not game.supplies.repair(), "未使用的休息点不重复扣料")
	await capture("items")
	game.book.select_page(1)
	game.book.set_tracked("stove")
	check(game.book.target().region == "grove" and game.book.track_label.text.contains("旧灶台"), "追踪祝婶显示实际目标区域和地点")
	game.story.state.stage = 1
	game.book.update_tracking()
	check(game.book.target().point == Maps.site_position("grove", 1), "接取后追踪自动推进到药圃")
	game.states.grove.visited[0] = true
	game.states.grove.visited[1] = true
	game.book.update_tracking()
	check(game.book.target().point == Maps.site_position("grove", 0), "调查完成后追踪自动返回交料地点")
	await frames()
	check(game.journal.get_global_rect().end.y <= 700 and game.book.repair_button.get_global_rect().end.y < 650, "720p物品与制作操作完整落在屏内")
	game.npcs.tasks["ye-ting"] = "active"
	game.book.refresh()
	game.book.set_tracked("ye-ting")
	check(game.book.tracked == "ye-ting" and game.book.target().region in Maps.IDS, "可改为追踪已接NPC委托，只保留一个目标")
	game.book.set_tracked("stove")
	await capture("tasks")
	game.book.select_page(2)
	check(game.journal_text.text.contains(Maps.MAPS.grove.sites[1][2]) and not game.journal_text.text.contains("小怪35%"), "见闻只显示已调查正文")
	await capture("lore")
	game.book.select_page(3)
	check(game.journal_text.text.contains("投石守卫") and game.journal_text.text.contains("首领"), "详细战斗与资源规则单独进入帮助页")
	await capture("help")
	game.journal.hide()
	check(not game.supplies.craft("field_bandage"), "关闭行囊不允许后台制作")
	game.health = 50
	game.interact()
	check(game.health > 50 and game.states.grove.rested, "修补后可以通过真实休息接口再次回血")
	game.dialogue.hide()
	game.tools.open_map()
	await capture("tracked-map")
	check(game.tools.atlas.has_meta("task_provider"), "地图接入实际追踪目标提供器")
	game.tools.atlas.close()

func check_mana_supplies() -> void:
	game.enter_region("grove")
	game.facing = Vector2.RIGHT
	game.mana = 20
	game.cooldowns = {"j": 0.0, "k": 0.0, "l": 0.0}
	check(game.attack("j") and game.mana == 20, "斩击免费")
	check(game.attack("k") and game.mana == 12, "灵弹实际消耗8法力")
	check(not game.attack("l") and game.mana == 12 and game.cooldowns.l == 0, "法力不足不释放震荡也不触发冷却")
	game._process(1.0)
	check(game.mana == 16 and game.attack("l") and game.mana == 0, "自然回蓝每秒4点，震荡消耗16法力")
	game.open_journal()
	game._process(1.0)
	check(game.mana == 0, "行囊暂停自然回蓝")
	game.journal.hide()
	game.inventory.dewleaf = 1
	game.inventory.herb = 1
	for pickup: Dictionary in game.states.grove.pickups:
		if pickup.item == "dewleaf":
			game.player_foot = pickup.position
			game._collect_nearby()
			break
	check(game.inventory.dewleaf >= 2, "采集青露叶进入制作材料库存")
	var leaves: int = game.inventory.dewleaf
	game.open_journal()
	game.book.select_page(0)
	await click(game.book.craft_buttons.dewleaf_potion)
	check(game.inventory.dewleaf == leaves - 2 and game.inventory.herb == 0 and game.inventory.dewleaf_potion == 1, "真实制作按钮用采集植物制作青露灵液")
	game.inventory.wakeleaf = 2
	game.inventory.mint = 1
	game.book.refresh()
	await click(game.book.craft_buttons.wakeleaf_potion)
	check(game.inventory.wakeleaf == 0 and game.inventory.mint == 0 and game.inventory.wakeleaf_potion == 1, "醒神灵液配方精确扣除醒神叶和薄荷")
	game.health = 60
	game.mana = 80
	game.journal.hide()
	game._refresh_ui()
	await click(game.potion_buttons.mana)
	check(game.mana == 100 and game.health == 60 and game.inventory.dewleaf_potion == 0 and game.inventory.wakeleaf_potion == 1, "回蓝按钮优先消耗青露灵液，只补法力并封顶")
	check(game.potion_buttons.mana.disabled and game.potion_buttons.mana.get_global_rect().end.x <= 800, "满蓝禁用药水按钮且按钮未挤入主导航")
	await click(game.potion_buttons.health)
	check(game.health == 85 and game.mana == 100 and game.inventory.field_bandage == 1, "回血按钮只补生命并扣除一份绷带")
	await capture("quick-potions")
	game.mana = 26.5

func check_legacy_save() -> void:
	game.states.grove.enemies[0].behavior = "charger"
	check(game.persistence.save_now(), "新补给、任务追踪、守卫角色通过存档校验")
	var snapshot: Dictionary = game.persistence.capture()
	var legacy := snapshot.duplicate(true)
	legacy.erase("mana")
	legacy.inventory.erase("wakeleaf_potion")
	legacy.inventory.erase("dewleaf_potion")
	var v2 := {"version": 2, "data": Save.encode(legacy)}
	var migrated: Dictionary = game.persistence.decode_snapshot(v2)
	check(migrated.mana == 100 and migrated.inventory.field_bandage == 1, "v2旧档补入满法力并保留原补给")
	legacy.erase("tracked_task")
	for item: String in game.Catalog.SUPPLIES: legacy.inventory.erase(item)
	for region: Dictionary in legacy.regions.values():
		for actor: Dictionary in region.enemies: actor.erase("behavior")
	var bad := snapshot.duplicate(true)
	bad.inventory.erase("herb")
	check(not game.persistence.valid(bad), "边界拒绝缺失必需材料键的损坏库存")
	bad = snapshot.duplicate(true)
	bad.tracked_task = "not-a-task"
	check(not game.persistence.valid(bad), "边界拒绝不存在的追踪任务")
	var file := FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "data": Save.encode(legacy)}, "", false, true))
	file.close()
	await open_game()
	check(game.book.tracked == "" and game.states.grove.enemies[0].guard_phase == "idle" and game.mana == 100, "真实v1旧档补上守卫角色和法力，缺省不追踪任务")
	check(Save.parse_text(FileAccess.get_file_as_string(Save.PATH)).version == Save.VERSION, "真实v1文件加载后升级到v3")
	game.persistence.apply(snapshot)
	check(game.persistence.save_now(), "保留新功能跨进程复验存档")
