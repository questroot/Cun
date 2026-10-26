extends SceneTree
# Purpose: underwater loop, collision, migration and transaction regression.
# Godot 4.7; run only in the isolated copy created by underwater.tests.ps1.
var failures := 0
var checks := 0
var sea: Control
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func walk(view: Control, destination: Vector2) -> void:
	for i in 500:
		if view.foot.distance_to(destination) < 3: break
		view.move_step((destination - view.foot).limit_length(5))
	check(view.foot.distance_to(destination) < 3, "通行路线可达 " + str(destination))

func run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	game = root.get_node("GameManager")
	game.water_activity_state = {}
	sea = load("res://scenes/WaterActivity.tscn").instantiate()
	root.add_child(sea)
	await process_frame
	sea.set_process(false)
	var base: Dictionary = sea._round_state()
	for version in [1, 2, 3, 4]:
		var migrated: Dictionary = game._read_sea_text(JSON.stringify({"version": version, "state": base}))
		check(not migrated.is_empty() and not migrated.dive_shoal and not migrated.dive_sonar and not migrated.dive_core and not migrated.dive_archived, "v%d默认初始化所有海底字段" % version)
	check(not sea._commit_dive("dive_core") and not sea._commit_dive("dive_sonar"), "线索前置")
	sea._open_dive()
	var view: Control = sea.dive_view
	view.set_process(false)
	view.foot = Vector2(250, 520)
	check(view.place == "shoal" and not view.interact(), "起点调查距离受限")
	for code in [KEY_D, KEY_RIGHT, KEY_W]:
		var start: Vector2 = view.foot
		var press := InputEventKey.new()
		press.keycode = code
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		view._process(0.05)
		check(view.foot != start, "真实移动键 " + str(code))
		press = InputEventKey.new()
		press.keycode = code
		Input.parse_input_event(press)
		await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300, 520)
	Input.parse_input_event(click)
	await process_frame
	var click_start: Vector2 = view.foot
	view._process(0.05)
	check(view.moving and view.foot != click_start, "真实点击移动")
	view.moving = false
	var clock: float = sea.wave_elapsed
	var position: Vector2 = sea.player_foot
	sea._process(20)
	check(sea.wave_elapsed == clock and sea.player_foot == position and sea._round_state() == base, "海上计时移动及产出暂停")
	sea.exploration_tools.open_map()
	sea.exploration_tools.switch_game()
	sea.get_node("ReturnButton").pressed.emit()
	await key(KEY_M)
	check(not sea.exploration_tools.is_open() and is_instance_valid(sea.dive_view), "地图切换返回被阻挡")
	view.foot = Vector2(1080, 490)
	await key(KEY_E)
	check(view.place == "shoal" and view.message.contains("先调查"), "未调查不能进入沉船")
	view.foot = Vector2(350, 250)
	view.move_step(Vector2(250, 0))
	check(view.foot.x < 420, "珊瑚阻挡且高速不穿墙")
	view.foot = Vector2(145, 520)
	walk(view, Vector2(350, 390))
	walk(view, Vector2(650, 390))
	await key(KEY_E)
	check(sea.dive_shoal, "真实E调查光迹")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(sea.dive_layer) and sea.dive_shoal, "提前返航保留线索")
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	check(view.place == "shoal", "重进从浅滩开始")
	view.foot = Vector2(1080, 490)
	await key(KEY_E)
	check(view.place == "wreck", "船尾航路解锁")
	view.foot = Vector2(1080, 480)
	await key(KEY_E)
	check(view.place == "wreck", "无声呐方向不能进海沟")
	view.foot = Vector2(300, 300)
	view.move_step(Vector2(300, 0))
	check(view.foot.x < 380, "船头堵死")
	view.foot = Vector2(145, 490)
	walk(view, Vector2(540, 490))
	walk(view, Vector2(720, 375))
	await key(KEY_E)
	check(sea.dive_sonar, "船尾可进入声呐台")
	walk(view, Vector2(1080, 480))
	await key(KEY_E)
	check(view.place == "trench", "声呐解锁海沟")
	view.foot = Vector2(145, 410)
	walk(view, Vector2(875, 410))
	await key(KEY_E)
	check(sea.dive_core and not sea.dive_archived, "唯一核心待归档")
	var unique: Dictionary = sea._round_state()
	await key(KEY_E)
	check(sea._round_state() == unique, "重复核心不发奖")
	view.move_step(Vector2(400, 0))
	check(view.foot.x < 950, "断崖深处信号不可达")
	await key(KEY_ESCAPE)
	sea._open_dive(true)
	sea.dive_view.archive_button.pressed.emit()
	check(sea.dive_archived, "浮台明确归档")
	var archived: Dictionary = sea._round_state()
	sea.dive_view.archive_button.pressed.emit()
	check(sea._round_state() == archived, "重复归档无奖励")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(game.SEA_SAVE)).version) == 5, "写入v5")
	game.load_sea_save()
	check(game.water_activity_state.dive_archived, "v5重读")
	for field in ["dive_shoal", "dive_sonar", "dive_core", "dive_archived"]:
		var invalid: Dictionary = archived.duplicate(true)
		invalid[field] = 1
		check(game._read_sea_text(JSON.stringify({"version": 5, "state": invalid})).is_empty(), "拒绝非布尔 " + field)
	for field in ["dive_shoal", "dive_sonar", "dive_core"]:
		var invalid: Dictionary = archived.duplicate(true)
		invalid[field] = false
		check(game._read_sea_text(JSON.stringify({"version": 5, "state": invalid})).is_empty(), "拒绝破坏前置 " + field)
	sea._close_dive()
	sea._start_round()
	var before: Dictionary = game.water_activity_state.duplicate(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	sea._open_dive()
	view = sea.dive_view
	view.set_process(false)
	view.foot = Vector2(650, 390)
	await key(KEY_E)
	check(not sea.dive_shoal and game.water_activity_state == before and view.message.contains("失败"), "写失败回滚线索及内存")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SEA_TEMP))
	await key(KEY_ESCAPE)
	sea.exploration_tools.open_map()
	sea._open_dive()
	check(not is_instance_valid(sea.dive_layer), "地图打开不能下潜")
	sea.exploration_tools.atlas.close()
	sea._open_dive()
	sea._start_round()
	check(not is_instance_valid(sea.dive_layer) and not sea.dive_core, "重开清理overlay及进度")
	sea.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("UNDERWATER RESULT: ", checks, " checks, ", failures, " failed")
	quit(1 if failures else 0)
