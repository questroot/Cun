extends SceneTree
## Run after tests/gm.tests.ps1, using its isolated project path (never player saves).
## Godot --path ISOLATED_PROJECT --script res://scripts/tests/hero_walk_smoke.gd
const HeroWalkScript = preload("res://scripts/scenes/hero_walk_sprite.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for tick in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://hero_walk_%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "真实渲染截图: " + label)
	print("HERO_CAPTURE: " + ProjectSettings.globalize_path(path))

func run_checks() -> void:
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-GM-"):
		printerr("Hero walk tests require a copied project and isolated Cun-GM-* save directory.")
		quit(2)
		return
	await process_frame
	var sprite := HeroWalkScript.new()
	root.add_child(sprite)
	check(sprite.facing == "S" and sprite.frame == 0 and sprite.hframes == 4 and sprite.vframes == 2, "默认南向、8帧网格")
	for sector in range(8):
		var motion := Vector2.RIGHT.rotated(sector * PI / 4.0)
		sprite.update_movement(Vector2.ZERO, 0.0)
		sprite.update_movement(motion, 0.11)
		var direction: String = HeroWalkScript.DIRECTIONS[sector]
		check(sprite.facing == direction and sprite.texture.resource_path.ends_with("walk_%s.png" % direction) and sprite.texture.get_size() == Vector2(1792, 1024), "方向及实际图集正确: " + direction)
		check(sprite.walking and sprite.frame == 1 and not sprite.flip_h and sprite.scale.x > 0.0, "行走使用真实方向帧而非镜像: " + direction)
		sprite.update_movement(Vector2.ZERO, 1.0)
		check(not sprite.walking and sprite.frame == 0 and sprite.facing == direction, "停止回到原朝向第0帧: " + direction)
	var seen: Dictionary = {}
	for tick in range(80):
		sprite.update_movement(Vector2.RIGHT, 0.011)
		seen[sprite.frame] = true
	check(seen.size() == 8 and sprite.walk_elapsed < 0.8, "完整循环覆盖8帧并正常回绕")
	sprite.free()
	var city = load("res://scenes/MainCity.tscn").instantiate()
	root.add_child(city)
	city.set_process(false)
	city.exit_armed = false
	city.player_foot = Vector2(340, 550)
	city.set_destination(Vector2(480, 550))
	city._process(0.11)
	check(city.player_model.walking and city.player_model.facing == "E" and city.player_model.frame > 0, "主城点击寻路播放东向动画")
	city.open_gm_panel()
	var foot: Vector2 = city.player_foot
	city._process(0.11)
	check(city.player_foot == foot and not city.player_model.walking and city.player_model.frame == 0, "打开GM面板停步并停止动画")
	city.gm_panel.hide()
	city.player_foot = Vector2(550, 550)
	city.has_destination = false
	city.path_points.clear()
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	city._process(0.11)
	check(city.player_foot.y < 550 and city.player_model.walking and city.player_model.facing == "N", "W键实际位移播放北向动画")
	city.player_foot = Vector2(550, 466)
	city._process(0.11)
	var release := InputEventKey.new()
	release.keycode = KEY_W
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(city.player_foot == Vector2(550, 466) and not city.player_model.walking, "碰撞阻挡时不原地播放行走")
	city.player_foot = Vector2(410, 630)
	city.set_destination(Vector2(520, 690))
	city._process(0.11)
	check(city.player_model.walking and city.player_model.facing == "SE", "主城斜向位移使用东南帧")
	await capture("city")
	city.free()
	for scene_name in ["Outskirts", "WaterActivity"]:
		var zone = load("res://scenes/%s.tscn" % scene_name).instantiate()
		root.add_child(zone)
		zone.set_process(false)
		if scene_name == "Outskirts":
			zone.transition_ready = false
		zone.player_foot = Vector2(450, 550)
		zone.target = Vector2(390, 490)
		zone.moving = true
		zone._process(0.11)
		check(zone.model.walking and zone.model.facing == "NW" and zone.model.frame > 0, scene_name + "点击移动使用西北动画")
		zone.moving = false
		zone._process(0.11)
		check(not zone.model.walking and zone.model.frame == 0 and zone.model.facing == "NW", scene_name + "停步保留朝向")
		await capture(scene_name)
		zone.free()
	var portrait: Texture2D = load("res://scripts/battle/sprite_atlas.gd").pet_texture("hero")
	check(portrait.resource_path == "res://assets/characters/pet_hero.png", "战斗立绘继续使用原图")
	print("HERO_WALK_RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
