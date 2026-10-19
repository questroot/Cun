extends SceneTree
const Ecology = preload("res://scripts/scenes/weather_ecology.gd")
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
var checks := 0
var failures := 0
var game
var weather

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

func frames() -> void:
	for i in range(3):
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.model.position = game.player_foot
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var path := "user://weather_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图: " + label)
	print("WEATHER_CAPTURE: " + ProjectSettings.globalize_path(path))

func open_fudi() -> void:
	if current_scene != null:
		current_scene.free()
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	weather = game.get_node("Weather")

func run_checks() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Weather-"):
		printerr("Weather checks require an isolated Cun-Weather-* save directory.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	var progress: Dictionary = data.save_data.duplicate(true)
	await open_fudi()
	check(weather.initialized and weather.elapsed == 0, "独立天气模块初始化，暂停父场景不推进")
	var initial := {}
	for id: String in Maps.IDS:
		initial[id] = weather.climates[id]
		check(weather.plots[id].size() == 6 and game.remaining_resources(id) == Catalog.REGIONS[id].resources, "初始野生资源保留，新增六处幼苗: " + id)
		for plot: Dictionary in weather.plots[id]:
			check(Maps.walkable(id, plot.position, 55) and plot.position.distance_to(Maps.MAPS[id].spawn * Maps.MAPS[id].size) >= 400, "药圃可达且远离安全出生点: " + id + "/" + str(plot.item))
		var weather_config: Dictionary = Ecology.WEATHER[weather.climates[id]]
		check(game.states[id].enemies[0].name == weather_config.monster and game.states[id].enemies[0].hp == weather_config.hp, "守卫匹配当地天气及生命属性: " + id)
		game.enter_region(id)
		game.player_foot = weather.plots[id][0].position + Vector2(60, 0)
		game._update_camera()
		await capture("initial_" + id)
	game.enter_region("grove")
	check(initial.size() == Maps.IDS.size() and initial.grove == "rain" and initial.refuge == "snow" and initial.causeway == "wind" and initial.archive == "fog", "十地初始化各自的气候，保留原有开局配置")
	check(Ecology.weather_at("grove", 74.99) == "rain" and Ecology.weather_at("grove", 75) == "clear" and Ecology.weather_at("grove", 225) == "rain", "天气轮换边界与循环正确")
	weather.tick(30)
	var plot: Dictionary = weather.plots.grove[0]
	check(plot.ripe and game.states.grove.pickups.has(plot.pickup), "雨属性草药生长成熟，生成真实采集物")
	check(weather.plots.quarry[4].growth == 0 and not weather.plots.quarry[4].ripe, "石缝苔在炎阳停止生长")
	check(weather.plots.post[0].ripe and weather.plots.ruins[0].ripe and weather.plots.refuge[0].ripe, "非当前地图仍按各自气候生长")
	game.player_foot = plot.position
	game._update_camera()
	await capture("rain_garden")
	if DisplayServer.get_name() != "headless":
		var marker: Vector2 = weather.garden.get_global_transform_with_canvas() * Vector2(plot.position) + Vector2(21, 0)
		var pixel := root.get_texture().get_image().get_pixelv(Vector2i(marker))
		check(pixel.g > 0.5 and pixel.r > 0.35, "成熟药圃标记真实渲染，跨图后绘制区域正确")
	var before: int = game.inventory[plot.item]
	game._collect_nearby()
	check(game.inventory[plot.item] == before + 1, "成熟植物采集进现有材料行囊")
	weather.tick(1)
	check(not plot.ripe and plot.harvests == 1 and plot.growth == 1, "采集后幼苗重新开始生长")
	weather.tick(17)
	check(plot.ripe and plot.harvests == 1, "适生天气下可再次成熟")
	var count: int = game.states.grove.pickups.size()
	weather.tick(1)
	check(game.states.grove.pickups.size() == count, "未采集的成熟药材不重复堆积")
	var elapsed_before: float = weather.elapsed
	game.tools.open_map()
	weather.tick(20)
	check(weather.elapsed == elapsed_before, "地图打开暂停天气与植物生长")
	game.tools.atlas.select_region("quarry")
	await capture("atlas_climate")
	game.tools.atlas.close()
	game.dialogue.show()
	weather.tick(20)
	check(weather.elapsed == elapsed_before, "人物对话暂停生态")
	game.dialogue.hide()
	game.open_journal()
	weather.tick(20)
	check(weather.elapsed == elapsed_before, "行囊打开暂停生态")
	game.journal.hide()
	game.tools.confirm.show()
	weather.tick(20)
	check(weather.elapsed == elapsed_before, "切换确认暂停生态")
	game.tools.confirm.hide()
	var enemy: Dictionary = game.states.grove.enemies[0]
	enemy.hp = 30
	game.states.grove.enemies.remove_at(1)
	var enemies_before: int = game.states.grove.enemies.size()
	weather.tick(75 - weather.elapsed)
	check(weather.climates.grove == "clear" and weather.climates.quarry == "wind", "五地同步轮换但各自遵循气候表")
	check(enemy.hp == 26 and enemy.max_hp == 52 and game.states.grove.enemies.size() == enemies_before, "天气转换保留守卫受伤比例，不复活已清除守卫")
	check(enemy.speed == 80 and enemy.damage == 8, "天气改变实际移动与攻击配置")
	weather.tick(10)
	check(weather.plots.quarry[4].growth == 10, "炎阳转疾风后石缝苔恢复生长")
	var grove_growth: float = weather.plots.grove[0].growth
	game.enter_region("refuge")
	game.enter_region("grove")
	check(weather.elapsed == 85 and weather.plots.grove[0].growth == grove_growth, "往返地图保留天气与药圃进度")
	# Combat uses weather stats; controlled fixtures avoid unrelated enemies/pickups.
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	game.states.grove.enemies = [{"position": game.player_foot, "hp": 80, "max_hp": 80, "damage": 15, "speed": 60.0, "flash": 0.0, "drop": "warmflower"}]
	game.hurt_timer = 0
	game._process(0.1)
	check(game.health == 85, "熔火怪实际接触伤害为15")
	game.states.grove.enemies[0].position = game.player_foot + Vector2(120, 0)
	var enemy_start: Vector2 = game.states.grove.enemies[0].position
	game._process(0.1)
	check(is_equal_approx(enemy_start.distance_to(game.states.grove.enemies[0].position), 6.0), "熔火怪实际按60移速追击")
	var loot_before: int = game.remaining_resources("grove").get("warmflower", 0)
	# Keep the weather-material assertion deterministic under random equipment loot.
	var probe := RandomNumberGenerator.new()
	probe.seed = 20261019
	for i in range(1000):
		var state := probe.state
		if not game.Loot.roll_monster("grove", probe).is_empty():
			game.loot_rng.state = state
			break
	game.states.grove.enemies[0].hp = 0
	game._remove_dead()
	check(game.remaining_resources("grove").get("warmflower", 0) == loot_before + 1, "击败属性怪掉落对应植物材料")
	game._remove_dead()
	check(game.remaining_resources("grove").get("warmflower", 0) == loot_before + 1, "重复清理死亡列表不重复掉落")
	weather.tick(100)
	check(weather.climates.grove == "fog", "跨越气候边界正确分段推进")
	var dew: Dictionary = weather.plots.grove[2]
	check(dew.ripe, "分段结算后适生植物成熟")
	for id: String in Maps.IDS:
		game.enter_region(id)
		game.player_foot = weather.plots[id][0].position
		game._update_camera()
		await capture(id)
	game.finished = true
	elapsed_before = weather.elapsed
	weather.tick(100)
	check(weather.elapsed == elapsed_before, "死亡或胜利结算暂停天气")
	await open_fudi()
	check(weather.elapsed == 0 and not weather.plots.grove[0].ripe and game.inventory.bloodgrass == 0, "重开重置天气、幼苗和当局材料")
	# Harvest a plant just before its climate becomes unsuitable: progress must pause.
	weather.tick(74)
	var dew_plot: Dictionary = weather.plots.grove[2]
	game.player_foot = dew_plot.position
	game._collect_nearby()
	weather.tick(2)
	check(dew_plot.growth == 1 and not dew_plot.ripe, "跨天气长帧仅累计适生的一秒，不适生保留进度")
	weather.tick(74)
	check(dew_plot.growth == 1, "晴光期青露叶保持已有生长进度")
	weather.tick(1)
	check(dew_plot.growth == 2, "进入灵雾后从原进度继续生长")
	game.set_process(true)
	await frames()
	game.set_process(false)
	check(weather.elapsed > 151 and weather.elapsed < 152, "真实场景逐帧自动推进天气，无需手动触发")
	check(data.save_data == progress and FileAccess.get_file_as_string(data.SAVE_PATH) == saved, "天气、生长、掉落与重开均不修改灵伴存档")
	print("WEATHER_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
