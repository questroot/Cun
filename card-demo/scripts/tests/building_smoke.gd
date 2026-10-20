extends "res://scripts/tests/boss_smoke.gd"
const BuildingCatalog = preload("res://scripts/scenes/building_catalog.gd")
var structures

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://building_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实建筑渲染 " + label)
	print("BUILDING_CAPTURE: " + ProjectSettings.globalize_path(path))

func grant(effect: String, clear: bool = true) -> void:
	if clear:
		structures.active.clear()
	structures.states[game.region].effect = effect
	structures.states[game.region].inside = false
	game.player_foot = BuildingCatalog.entrance(game.region)
	structures.tick(0.001)

func hold_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Building-"):
		printerr("Building checks require an isolated Cun-Building-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	await open_fudi()
	structures = game.get_node("Buildings")
	check(structures.states.size() == 10 and BuildingCatalog.REGIONS.size() == Maps.IDS.size(), "十张地图各生成一座大型建筑")
	var rolls := {}
	for id: String in Maps.IDS:
		game.enter_region(id)
		var config: Dictionary = BuildingCatalog.REGIONS[id]
		var state: Dictionary = structures.states[id]
		rolls[id] = state.effect
		check(config.pool.has(state.effect), "建筑随机属性属于当地增益/减益池 " + id)
		var positive := 0
		for effect: String in config.pool:
			positive += 1 if BuildingCatalog.EFFECTS[effect].positive else 0
		check(positive == 2 and config.pool.size() == 4, "随机池包含两种增益与两种减益 " + id)
		var footprint := BuildingCatalog.footprint(id)
		check(Maps.obstacles(id)[2].encloses(footprint) and footprint.size.x >= 300, "大型建筑复用现有碰撞占地 " + id)
		var door := BuildingCatalog.entrance(id)
		var reachable := reachable_cells(id)
		check(Maps.walkable(id, door, 32) and reachable.has(Vector2i((door / 64).floor())), "入口从出生点连通且可站立 " + id)
		var approach := door + Vector2(0, 220)
		if Maps.Art.has_art(id):
			# Find a connected point on the actual painted approach, outside the trigger.
			var nearest := INF
			for road: Array in Maps.MAPS[id].roads:
				for n in range(road.size() - 1):
					var a: Vector2 = road[n] * Maps.MAPS[id].size
					var b: Vector2 = road[n + 1] * Maps.MAPS[id].size
					for step in range(101):
						var point := a.lerp(b, float(step) / 100)
						var distance := point.distance_to(door)
						if distance >= 180 and distance < nearest and Maps.walkable(id, point):
							nearest = distance
							approach = point
		game.player_foot = approach
		structures.tick(0.01)
		var visits: int = state.visits
		game.player_foot = game.move_world(game.player_foot, door - game.player_foot)
		structures.tick(0.01)
		var slot := "buff" if BuildingCatalog.EFFECTS[state.effect].positive else "debuff"
		check(state.visits == visits + 1 and structures.active[slot].effect == state.effect, "实际走入建筑入口获得随机效果 " + id)
		structures.tick(0.1)
		check(state.visits == visits + 1 and float(structures.active[slot].left) < 60, "站在圈内不无限刷新持续时间 " + id)
		check(structures.summary(id).contains(config.name) and structures.summary(id).contains(BuildingCatalog.EFFECTS[state.effect].description), "说明提前公开建筑效果与坐标 " + id)
		await capture(id)
		game.player_foot = door + Vector2(0, 220)
		structures.tick(0.01)
	game.enter_region("grove")
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	structures.tick(0.01)
	var preserved := true
	for id: String in rolls:
		preserved = preserved and structures.states[id].effect == rolls[id]
	check(preserved, "走遍十图不会重抽建筑词条")
	game.get_node("Weather").tick(76)
	check(structures.states.grove.effect == rolls.grove, "天气切换不重抽建筑词条")
	game.states.grove.enemies.clear()
	# Verify actual combat results for all three attacks, including the projectile path.
	for effect: String in ["vigor", "weaken"]:
		grant(effect)
		var expected: Array = [33, 25, 53] if effect == "vigor" else [21, 16, 34]
		var index := 0
		for kind: String in ["j", "k", "l"]:
			var enemy := {"position": game.player_foot + Vector2(80, 0), "hp": 500, "max_hp": 500, "flash": 0.0}
			game.states.grove.enemies = [enemy]
			game.facing = Vector2.RIGHT
			game.cooldowns[kind] = 0.0
			key({"j": KEY_J, "k": KEY_K, "l": KEY_L}[kind])
			if kind == "k":
				game._tick_projectiles(0.2)
			check(enemy.hp == 500 - expected[index], "真实JKL伤害生效 " + effect + "/" + kind)
			index += 1
	game.states.grove.enemies.clear()
	for effect: String in ["haste", "heavy"]:
		grant(effect)
		var foot: Vector2 = game.player_foot
		hold_key(KEY_D, true)
		game._process(0.1)
		hold_key(KEY_D, false)
		var expected := 31.2 if effect == "haste" else 20.8
		check(is_equal_approx(game.player_foot.x - foot.x, expected), "真实WASD移动受建筑效果影响 " + effect)
	grant("ward")
	check(game.incoming_damage(20) == 15, "建筑庇佑实际减少受击伤害")
	grant("fragile")
	check(game.incoming_damage(20) == 25, "建筑易伤实际增加受击伤害")
	grant("ward", false)
	check(game.incoming_damage(20) == 19 and structures.active.size() == 2, "增益和减益可共存且分别结算")
	game.inventory["s2-top"] = 1
	game.equipment.equip_item("s2-top")
	var defense: int = game.equipment.bonuses().defense
	check(game.incoming_damage(20) == maxi(1, 19 - defense), "建筑效果与装备减伤共同进入伤害公式")
	game.equipment.unequip_slot("top")
	# Use the catalog's actual slot rather than relying on UI labels.
	for slot: String in game.equipment.equipped.keys():
		game.equipment.unequip_slot(slot)
	grant("fatigue")
	for kind: String in ["j", "k", "l"]:
		game.cooldowns[kind] = 0.0
		game.attack(kind)
		check(is_equal_approx(float(game.cooldowns[kind]), float(game.ATTACKS[kind].cooldown) * 1.25), "技能实际冷却受到灵滞影响 " + kind)
	game.projectiles.clear()
	grant("vigor")
	grant("ward", false)
	check(structures.active.size() == 1 and structures.multiplier("attack") == 1, "同类增益替换不叠加攻击数值")
	grant("heavy", false)
	grant("fragile", false)
	check(structures.active.size() == 2 and structures.multiplier("speed") == 1, "同类减益替换不残留减速")
	game.player_foot = BuildingCatalog.entrance("grove") + Vector2(0, 220)
	structures.tick(61)
	check(structures.active.is_empty() and structures.multiplier("incoming") == 1 and structures.multiplier("speed") == 1, "60秒结束后属性完全恢复")
	grant("renewal")
	game.health = 20
	structures.tick(1.5)
	check(game.health == 23, "复苏按真实秒数恢复生命")
	structures.tick(0.5)
	check(game.health == 24, "小数帧累积治疗不丢失")
	game.health = 99
	structures.tick(1)
	check(game.health == 100, "治疗不超过生命上限")
	for modal: Control in [game.dialogue, game.journal, game.equipment.modal]:
		modal.show()
		var remaining: float = structures.active.buff.left
		game.health = 50
		structures.tick(5)
		check(structures.active.buff.left == remaining and game.health == 50, "模态界面暂停建筑计时和治疗 " + modal.name)
		modal.hide()
	game.tools.atlas.open("grove")
	var before_pause: float = structures.active.buff.left
	structures.tick(5)
	check(structures.active.buff.left == before_pause, "地图暂停建筑状态倒计时")
	await capture("atlas")
	game.tools.atlas.close()
	game.finished = true
	game.health = 0
	structures.tick(5)
	check(game.health == 0 and structures.active.buff.left == before_pause, "死亡结算暂停效果且不能治疗复活")
	game.finished = false
	game.health = 100
	game.player_foot = BuildingCatalog.entrance("grove") + Vector2(0, 220)
	game.set_process(true)
	await create_timer(0.25).timeout
	game.set_process(false)
	check(structures.active.buff.left < before_pause, "真实逐帧运行推进建筑效果")
	var effect_before: String = structures.active.buff.effect
	game.enter_region("post")
	game.player_foot = Maps.MAPS.post.spawn * Maps.MAPS.post.size
	structures.tick(0.01)
	check(structures.active.buff.effect == effect_before and structures.states.grove.effect == "renewal", "跨图保留限时效果和建筑抽取结果")
	game.open_journal()
	var text: String = game.journal_text.get_parsed_text()
	check(text.contains("大型建筑") and text.contains("霜脊观星高台") and text.contains("青岚百味大食堂"), "B行囊展示十地建筑与当前效果")
	game.journal.hide()
	await open_fudi()
	structures = game.get_node("Buildings")
	var reset: bool = structures.active.is_empty()
	for state: Dictionary in structures.states.values():
		reset = reset and state.visits == 0
	check(reset and game.health == 100, "重开清空限时效果和触发次数，重新抽取词条")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "建筑探索不修改灵伴存档")
	print("BUILDING_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
