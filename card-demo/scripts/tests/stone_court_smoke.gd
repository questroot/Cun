extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-StoneCourt-"):
		quit(2)
		return
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	await process_frame
	var menu := current_scene
	var entry := menu.get_node("MenuContent/EnterStoneCourt") as Button
	var content := entry.get_parent() as Control
	var backdrop := menu.get_node("MenuBackdrop") as Control
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	check(bounds.encloses(content.get_global_rect()) and backdrop.get_global_rect().encloses(content.get_global_rect()), "菜单入口和其他选项都在屏内")
	entry.pressed.emit()
	await scene_changed
	var court = current_scene
	court.set_process(false)
	check(court.name == "StoneCourt" and court.STONE_BRICK.resource_path.ends_with("/stone-brick-guofeng.png") and court.STONE_BRICK.get_size() == Vector2(747, 610), "菜单进入石庭并加载完整国风石砖")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var before_input: Vector2 = court.foot
	court._process(0.05)
	check(court.foot.x > before_input.x and court.hero.walking, "D键移动并触发行走动画")
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for point: Vector2 in [court.MAP_SIZE, Vector2(court.MAP_SIZE.x, 0)]:
		check(court.tiles.has(court.cell_at(point)), "右侧石砖排列延伸到边角 %s" % point)
	check(not court.tiles.has(court.cell_at(Vector2(525, 667))) and court.tide.texture.get_size() == Vector2(2560, 2004), "左半边铺设潮汐图集，未叠放互动石砖")
	court.foot = Vector2(1260, 680)
	var first: Vector2i = court.cell_at(court.foot)
	var start: Vector2 = court.foot
	court.advance(Vector2.ZERO, 0.05)
	check(court.pressed[first] > 0 and court.pressed[first] < court.MAX_SINK, "踩砖逐渐下沉")
	var age: float = court.star_time
	court.advance(Vector2.ZERO, 0.15)
	check(court.foot == start and court.hero.position == start + Vector2(0, court.MAX_SINK) and court.tiles[first].position.y == start.y + court.MAX_SINK, "完整砖块下沉最多6像素，角色脚底跟随")
	check(court.star_time > age, "原地驻足时星光继续闪烁")
	var adjacent: Vector2 = court.HALF_TILE
	var travel: float = adjacent.length() / court.SPEED
	court.advance(adjacent.normalized(), travel * 0.5)
	check(court.foot_sink == 0 and court.tiles[first].position.y < start.y + court.MAX_SINK, "走进砖缝不亮星光，上一块开始回弹")
	court.advance(adjacent.normalized(), travel * 0.5)
	var next: Vector2i = court.cell_at(court.foot)
	check(next != first and court.pressed[next] > 0 and court.tiles[first].position.y == start.y, "跨过接缝踩下新砖，旧砖恢复原位")
	court.advance(Vector2.ZERO, 0.30)
	check(not court.pressed.has(first) and court.pressed.size() == 1, "回弹后清理旧砖状态")
	court.foot = Vector2(960, 667)
	court.tide_time = 0.0
	court.advance(Vector2.ZERO, 2.4)
	court.world.position = court._camera_target()
	check(court.foot_sink == 0.0 and court.pressed.is_empty(), "踩在沙滩上不触发地砖和星光")
	check(court.tide.frame == 28, "海水逐帧前进")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var file := "user://stone-court-tide.png"
		check(root.get_texture().get_image().save_png(file) == OK, "生成高潮石庭截图")
		print("STONE_COURT_CAPTURE: " + ProjectSettings.globalize_path(file))
		court.advance(Vector2.ZERO, 2.0)
		await process_frame
		await RenderingServer.frame_post_draw
		file = "user://stone-court-ebb.png"
		check(root.get_texture().get_image().save_png(file) == OK, "生成退潮石庭截图")
		print("STONE_COURT_CAPTURE: " + ProjectSettings.globalize_path(file))
	court.tide_time = 3.95
	court.advance(Vector2.ZERO, 0.10)
	check(court.tide.frame == 0, "潮汐播放四秒后循环")
	await check_phoenix(court)
	court.foot = Vector2(42, 42)
	court.advance(Vector2(-1, -1).normalized(), 0.05)
	check(court.foot == Vector2(42, 42) and court._camera_target() == Vector2.ZERO, "地图边界限制移动并保留满屏地面")
	court.get_node("Back").pressed.emit()
	await scene_changed
	check(current_scene.name == "MainMenu", "从石庭返回主菜单")
	check(not FileAccess.file_exists("user://fudi_expedition_v1.json"), "独立石庭未写入福地探索存档")
	print("STONE_COURT_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_phoenix(court) -> void:
	court.tide_cycle = 0
	court.tide_time = 0.0
	court.advance(Vector2.ZERO, 0.0)
	check(not court.phoenix.visible, "第一轮潮汐没有水凤凰")
	court.advance(Vector2.ZERO, 4.0)
	check(not court.phoenix.visible, "第二轮潮汐没有水凤凰")
	court.advance(Vector2.ZERO, 4.0)
	check(court.phoenix.visible and court.phoenix.frame == 0 and court.tide.frame == 0, "第三轮潮汐开头触发水凤凰")
	var landing: Vector2 = court.PHOENIX_SEA_ORIGIN + Vector2(745, 0)
	check(court.tiles.has(court.cell_at(landing)) and court.is_brick_top(landing, court.cell_at(landing)), "俯冲落点位于右侧石砖")
	court.advance(Vector2.ZERO, 0.45)
	await capture_phoenix("vortex")
	court.advance(Vector2.ZERO, 1.30)
	check(court.phoenix.visible and court.phoenix.frame == 35, "水凤凰飞行图集按潮汐时钟推进")
	await capture_phoenix("flight")
	court.advance(Vector2.ZERO, 0.95)
	await capture_phoenix("splash")
	court.advance(Vector2.ZERO, 1.27)
	check(not court.phoenix.visible, "落水之后特效自动收尾")
	court.advance(Vector2.ZERO, 0.03)
	check(not court.phoenix.visible, "下一轮潮汐开始时不会重复出现")
	court.advance(Vector2.ZERO, 8.1)
	check(court.phoenix.visible and court.phoenix.frame < 3, "再过三轮潮汐循环重新触发")

func capture_phoenix(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "user://stone-court-phoenix-%s.png" % stage
	check(root.get_texture().get_image().save_png(file) == OK, "生成水凤凰实机截图 " + stage)
	print("STONE_COURT_CAPTURE: " + ProjectSettings.globalize_path(file))
