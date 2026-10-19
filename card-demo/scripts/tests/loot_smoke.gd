extends SceneTree
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
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

func open_fudi() -> void:
	if current_scene != null:
		current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()

func set_next_drop(wanted: bool) -> void:
	var probe := RandomNumberGenerator.new()
	probe.seed = 20261019
	for i in range(1000):
		var state := probe.state
		if (not Loot.roll_monster(game.region, probe).is_empty()) == wanted:
			game.loot_rng.state = state
			return
	check(false, "未找到随机分支测试种子")

func equipment(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pickup: Dictionary in game.states[id].pickups:
		if Loot.ITEMS.has(pickup.item):
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
	var path := "user://loot_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图 " + label)
	print("LOOT_CAPTURE: " + ProjectSettings.globalize_path(path))

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Loot-"):
		printerr("Loot checks require an isolated Cun-Loot-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	await open_fudi()
	check(Loot.BASE_ITEMS.size() == 20 and Loot.ITEMS.size() == 40, "20件原装备及对应20件异变品质均已登记")
	for id: String in Loot.ITEMS:
		var texture: Texture2D = Loot.ITEMS[id].icon
		check(Catalog.ITEMS.has(id) and game.inventory.has(id) and texture.get_size() == Vector2(160, 160), "图标可加载且可入行囊 " + id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1719
	var all_seen := {}
	for id: String in Maps.IDS:
		var drops := 0
		var seen := {}
		var valid := true
		for i in range(10000):
			var item := Loot.roll_monster(id, rng)
			if not item.is_empty():
				drops += 1
				seen[item] = true
				all_seen[item] = true
				valid = valid and Loot.pool(Loot.REGIONS[id]).has(item)
		check(drops > 3200 and drops < 3800 and valid and seen.size() == 6, "小怪有空掉落且概率约35%，完整六件区域池 " + id)
	for id: String in Loot.BOSSES:
		var valid := true
		var seen := {}
		for i in range(1000):
			var item := Loot.roll_boss(id, rng)
			valid = valid and not item.is_empty() and Loot.pool(Loot.BOSSES[id]).has(item)
			seen[item] = true
			all_seen[item] = true
		check(valid and seen.size() == 6, "首领1000次均掉一件对应装备 " + id)
	check(all_seen.size() == 20, "全部20张物品图片均可实际抽到")
	# Exercise death and pickup via the live game, including both random branches.
	game.states.grove.pickups.clear()
	var foot: Vector2 = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.player_foot = foot
	game.facing = Vector2.RIGHT
	for wanted: bool in [false, true]:
		game.states.grove.enemies = [{"position": foot + Vector2(80, 0), "hp": 1, "flash": 0.0, "drop": "dewleaf"}]
		set_next_drop(wanted)
		game.cooldowns.j = 0.0
		check(game.attack("j") and game.states.grove.enemies.is_empty(), "真实战斗入口击杀小怪，掉落分支 " + str(wanted))
		check(equipment("grove").size() == (1 if wanted else 0) and game.states.grove.pickups.size() == (2 if wanted else 0), "随机命中才掉装备和天气材料 " + str(wanted))
	var drops := equipment("grove")
	var pickup_count: int = game.states.grove.pickups.size()
	game._remove_dead()
	check(game.states.grove.pickups.size() == pickup_count, "重复清理尸体不能再抽奖")
	var pickup: Dictionary = drops[0]
	var item: String = pickup.item
	check(Maps.walkable("grove", pickup.position, 28), "装备落在可拾取的合法地面")
	game.player_foot = foot
	await capture("monster_drop")
	game.player_foot = pickup.position
	game._collect_nearby()
	check(game.inventory[item] == 1 and equipment("grove").is_empty(), "靠近图标实际拾取入行囊")
	game._collect_nearby()
	check(game.inventory[item] == 1, "重复拾取不增加装备")
	game.enter_region("post")
	game.enter_region("grove")
	check(game.inventory[item] == 1, "跨地图保留装备")
	# Each real boss death pays once, including when deaths are settled off-region.
	var bosses = game.get_node("Bosses")
	for id: String in bosses.bosses:
		var config: Dictionary = bosses.Catalog.DEFINITIONS[id]
		var before := equipment(config.region).size()
		bosses.bosses[id].hp = 0
		game._remove_dead()
		var after := equipment(config.region)
		check(after.size() == before + 1 and Loot.pool(Loot.BOSSES[id]).has(after[-1].item) and after[-1].boss_drop, "首领实际死亡必掉对应装备一次 " + id)
		game._remove_dead()
		check(equipment(config.region).size() == before + 1, "重复结算不重复首领装备 " + id)
		game.enter_region(config.region)
		game.player_foot = after[-1].position
		var amount: int = game.inventory[after[-1].item]
		game._collect_nearby()
		check(game.inventory[after[-1].item] == amount + 1, "首领装备实际拾取 " + id)
	game.enter_region("quarry")
	# Display several original images together for visual verification.
	game.player_foot = Maps.MAPS.quarry.spawn * Maps.MAPS.quarry.size
	for i in range(3):
		game.states.quarry.pickups.append({"item": ["s2-top", "s2-ring", "w06-falling-crag"][i], "position": game.player_foot + Vector2(100 + 140 * i, 0), "boss_drop": true})
	await capture("boss_loot")
	game.open_journal()
	check(game.journal_text.text.contains("小怪35%") and game.journal_text.text.contains("Boss必掉1件") and game.journal_text.text.contains(Loot.ITEMS[item].name), "行囊有装备数量、图片和掉率规则")
	await capture("inventory")
	game.journal.hide()
	game.tools.atlas.open("quarry")
	var map_text := ""
	for child in game.tools.atlas.detail.get_children():
		if child is Label:
			map_text += child.text
	check(map_text.contains("小怪35%") and map_text.contains("100%") and map_text.contains("烽炉"), "地图展示当前区域掉率与物品池")
	await capture("atlas")
	game.tools.atlas.close()
	await open_fudi()
	check(game._inventory_total() == 0 and game.get_node("Bosses").remaining() == 6, "重开清空装备并恢复六首领")
	var empty := true
	for id: String in Maps.IDS:
		empty = empty and equipment(id).is_empty()
	check(empty, "新局地面没有上一轮掉落")
	check(FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "掉落、拾取、旅行与重开不修改灵伴存档")
	print("LOOT_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
