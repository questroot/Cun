extends SceneTree
const Rules = preload("res://scripts/scenes/chest_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Gear = preload("res://scripts/scenes/equipment_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Bosses = preload("res://scripts/scenes/boss_catalog.gd")
var game
var chests
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

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func open_fudi() -> void:
	if current_scene != null:
		current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	chests = game.get_node("Chests")

func force_boss_roll(wanted: bool) -> void:
	var probe := RandomNumberGenerator.new()
	probe.seed = 102030
	for i in range(1000):
		var before := probe.state
		if (probe.randf() < Rules.BOSS_DROP_CHANCE) == wanted:
			chests.rng.state = before
			return
	check(false, "找不到守箱首领掉落分支种子")

func enhanced_drops(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pickup: Dictionary in game.states[id].pickups:
		if pickup.get("chest_boss_drop", false):
			result.append(pickup)
	return result

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://chests_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图 " + label)
	print("CHESTS_CAPTURE: " + ProjectSettings.globalize_path(path))

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Chests-"):
		printerr("Chest checks require an isolated Cun-Chests-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	await open_fudi()
	check(chests.initialized and chests.remaining() == 0, "宝箱初始化且未开启不生成敌人")
	var mutations := 0
	for id: String in Maps.IDS:
		var normal := 0
		var valid := true
		for chest: Dictionary in chests.regions[id]:
			normal += int(not chest.mutated)
			mutations += int(chest.mutated)
			valid = valid and Maps.walkable(id, chest.position, 28) and chest.position.distance_to(Maps.MAPS[id].spawn * Maps.MAPS[id].size) >= 400
			for other: Dictionary in chests.regions[id]:
				if not is_same(chest, other):
					valid = valid and chest.position.distance_to(other.position) >= 240
		check(normal == 2 and valid, "地图两普通箱，落点合法并远离出生 " + id)
	check(mutations >= 1 and mutations <= Maps.IDS.size(), "随机额外异变箱，整轮至少一处")
	# Normal chest through the actual E input; rewards remain visible pickups.
	var normal: Dictionary = chests.regions.grove[0]
	game.player_foot = normal.position
	await capture("normal_sealed")
	var count: int = game.states.grove.pickups.size()
	key(KEY_E)
	check(normal.state == "opened" and normal.rewarded and game.states.grove.pickups.size() == count + 4, "E开启普通箱：一件装备与三份材料")
	key(KEY_E)
	chests.interact(normal)
	check(game.states.grove.pickups.size() == count + 4, "重复按E和调用不能重复发箱内奖励")
	var reward_points: Array[Vector2] = []
	for pickup: Dictionary in game.states.grove.pickups:
		if pickup.get("chest_drop", false):
			reward_points.append(pickup.position)
	var total: int = game._inventory_total()
	for point: Vector2 in reward_points:
		game.player_foot = point
		game._collect_nearby()
	check(game._inventory_total() >= total + 4, "宝箱奖励靠近实际入行囊")
	var upgraded_item := ""
	for index in range(Maps.IDS.size()):
		var id: String = Maps.IDS[index]
		game.enter_region(id)
		chests._add_chest(id, true)
		var chest: Dictionary = chests.regions[id][-1]
		game.player_foot = chest.position
		var before: int = game.states[id].pickups.size()
		key(KEY_E)
		check(chest.state == "guarding" and chests.targets(id).size() == 5 and game.states[id].pickups.size() == before, "E触发四小怪与一首领，奖励锁定 " + id)
		if chest.state != "guarding":
			continue
		var boss: Dictionary = chest.boss
		var base: Dictionary = Bosses.DEFINITIONS[boss.art]
		check(boss.max_hp == ceili(float(base.hp) * 0.60) and boss.damage == ceili(float(base.damage) * 0.60), "守箱首领生命与伤害削弱至60% " + id)
		var safe := true
		for guard: Dictionary in chests.targets(id):
			safe = safe and Maps.walkable(id, guard.position, 28) and guard.position.distance_to(game.player_foot) >= 125
		check(safe, "五名守卫落点可达且不贴脸 " + id)
		var health: int = game.health
		chests.tick(0.6)
		check(game.health == health and chest.warning > 0, "开箱留完整安全预警 " + id)
		if index == 0:
			await capture("mutated_encounter")
			for modal: Control in [game.dialogue, game.journal, game.equipment.modal, game.tools.atlas]:
				modal.show()
				var warning: float = chest.warning
				chests.tick(2)
				check(chest.warning == warning and game.health == health, "模态暂停宝箱守卫 " + modal.get_class())
				modal.hide()
			chest.warning = 0.0
			boss.position = chest.position + Vector2(80, 0)
			boss.cooldown = 0.0
			chests._tick_boss(boss, 0.01)
			check(boss.windup > 0 and game.health == health, "守箱首领先预警再攻击")
			game.player_foot = chest.position + Vector2(-220, 0)
			chests._tick_boss(boss, 1.3)
			check(game.health == health, "走出锁定圈可躲守箱首领伤害")
			game.player_foot = boss.position + Vector2(-65, 0)
			boss.cooldown = 0.0
			game.hurt_timer = 0.0
			chests._tick_boss(boss, 0.01)
			chests._tick_boss(boss, 1.3)
			check(game.health == health - int(boss.damage), "首领实际造成削弱后伤害")
			boss.hp -= 7
			var injured: int = boss.hp
			game.enter_region("post")
			chests.tick(5)
			game.enter_region(id)
			check(boss.hp == injured and boss.windup == 0 and boss.cooldown >= 1.8, "旅行保留守卫伤势并取消预警")
			game.get_node("Weather").tick(76)
			check(boss.hp == injured and boss.max_hp == ceili(float(base.hp) * 0.60), "天气不覆盖守箱首领")
		# Kill the boss via real J input and prove the two loot branches.
		var wanted := index % 2 == 0
		force_boss_roll(wanted)
		var loot_before := enhanced_drops(id).size()
		boss.hp = 1
		game.player_foot = boss.position + Vector2(-75, 0)
		game.facing = Vector2.RIGHT
		game.cooldowns.j = 0.0
		key(KEY_J)
		check(int(boss.hp) == 0 and boss.paid and enhanced_drops(id).size() == loot_before + int(wanted), "实际J击杀，守箱首领概率分支 " + str(wanted) + " " + id)
		game._remove_dead()
		check(enhanced_drops(id).size() == loot_before + int(wanted) and chest.state == "guarding", "首领不重复掉落且小怪存活仍锁箱 " + id)
		if wanted and upgraded_item.is_empty():
			var pickup: Dictionary = enhanced_drops(id)[-1]
			upgraded_item = pickup.item
			game.player_foot = pickup.position
			game._collect_nearby()
			check(game.inventory[upgraded_item] == 1 and Loot.base_item(upgraded_item) != upgraded_item, "强化品质装备拾取且与普通副本分开计数")
		for mob: Dictionary in chest.mobs:
			game._damage(mob, 999)
		game._remove_dead()
		check(chest.state == "cleared" and chests.targets(id).is_empty(), "清空守卫后解锁箱内奖励 " + id)
		game.player_foot = chest.position
		var loot_count: int = game.states[id].pickups.size()
		key(KEY_E)
		check(chest.state == "opened" and game.states[id].pickups.size() == loot_count + 4, "清怪后E领取一件装备与三材料 " + id)
	# Verify the entire enhanced family without modifying any base item's stats.
	for id: String in Loot.BASE_ITEMS:
		var base := Gear.stats(id)
		var improved := Gear.stats(id + "@mutated")
		var valid := Gear.slot(id) == Gear.slot(id + "@mutated")
		for stat: String in base:
			valid = valid and improved[stat] == ceili(float(base[stat]) * 1.3)
		check(valid and Gear.stats(id) == base, "强化属性提升30%、原数值不变 " + id)
	check(not upgraded_item.is_empty() and game.equipment.equip_item(upgraded_item), "实际掉落的强化装备可穿戴")
	var expected := Gear.loadout_stats(game.equipment.equipped)
	check(game.equipment.bonuses() == expected and game.equipment.detail_stats.text.contains("+"), "强化属性进入人物面板及实际加成接口")
	# Keep original set/weapon effects when using upgraded copies.
	game.inventory["w05-bone-halberd@mutated"] = 1
	game.equipment.equip_item("w05-bone-halberd@mutated")
	check(game.equipment.effects.weapon() == "w05-bone-halberd" and game.equipment.effects.attack_radius("j", 112) == 182, "异变武器保留原武器特效")
	var target := {"position": game.player_foot + Vector2(80, 0), "hp": 200, "max_hp": 200, "flash": 0.0}
	game.states[game.region].enemies = [target]
	var damage: int = 26 + game.equipment.bonuses().attack
	game.cooldowns.j = 0.0
	game.facing = Vector2.RIGHT
	game.attack("j")
	check(target.hp == 200 - damage, "异变武器增加真实J伤害")
	for id: String in ["s1-top@mutated", "s1-legs@mutated"]:
		game.inventory[id] = 1
		game.equipment.equip_item(id)
	check(Gear.set_counts(game.equipment.equipped).s1 >= 2 and game.equipment.bonuses().speed >= 28, "异变防具继续计入原套装档位")
	game.equipment.open()
	game.equipment.selected = "w05-bone-halberd@mutated"
	game.equipment._refresh_detail()
	await capture("enhanced_equipment")
	game.equipment.close()
	game.open_journal()
	check(game.journal_text.text.contains("异变宝箱") and game.journal_text.text.contains("60%"), "B行囊展示宝箱状态与守卫掉率")
	game.journal.hide()
	game.tools.atlas.open(game.region)
	var text := ""
	for child in game.tools.atlas.detail.get_children():
		if child is Label:
			text += child.text
	check(text.contains("宝箱") and text.contains("30%"), "M地图展示宝箱剩余和强化说明")
	await capture("atlas")
	game.tools.atlas.close()
	# Unopened chests are optional; active guards prevent premature completion.
	await open_fudi()
	chests._add_chest("grove", true)
	var encounter: Dictionary = chests.regions.grove[-1]
	game.player_foot = encounter.position
	chests.interact(encounter)
	for id: String in Maps.IDS:
		game.states[id].enemies.clear()
	for boss: Dictionary in game.get_node("Bosses").bosses.values():
		boss.hp = 0
	game._remove_dead()
	check(not game.finished and chests.remaining() == 5, "场景敌人清空仍须处理已触发的守箱战")
	for guard: Dictionary in chests.targets("grove"):
		guard.hp = 0
	game._remove_dead()
	check(game.finished and game.round_cleared and encounter.state == "cleared", "已触发守卫清空后正常结算，未开箱不阻碍胜利")
	game.resume_exploration()
	game.player_foot = encounter.position
	chests.interact(encounter)
	check(encounter.state == "opened", "胜后继续探索可领取已解锁宝箱")
	await open_fudi()
	check(game._inventory_total() == 0 and game.equipment.equipped.is_empty() and chests.remaining() == 0, "重开清空奖励、异变装备与战斗")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "全流程不修改灵伴隔离存档")
	print("CHESTS_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
