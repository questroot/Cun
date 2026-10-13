extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, name: String) -> void:
	if value:
		print("PASS: " + name)
	else:
		failures += 1
		push_error("FAIL: " + name)
func run_checks() -> void:
	var scene: PackedScene = load("res://scenes/City3D.tscn")
	check(scene != null, "三维主城场景可加载")
	var city := scene.instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/City3D.tscn", "启动直接进入三维主城")
	check(city.camera is Camera3D and city.camera.current, "游戏使用真实三维相机")
	check(city.world.get_node_or_null("ConceptCityGLB") is Node3D, "概念 GLB 位于主游戏三维世界")
	check(city.get_node_or_null("ConceptModelLayer") == null and city.world.get_node_or_null("LiveConceptModel") == null, "没有视口图像冒充三维场景")
	check(city.player is CharacterBody3D and city.npc is Node3D, "三维玩家和向导实体已创建")
	check(city.world.get_node_or_null("SolidGround") is StaticBody3D, "地面具有三维碰撞")
	for i in range(5):
		check(city.world.get_node_or_null("BuildingCollision%d" % i) is StaticBody3D, "建筑三维碰撞 %d" % i)
	check(city.dialogue != null and city.party_panel != null and city.status_label.text.contains("Lv."), "关卡对话和状态 HUD 保留")
	var start: Vector3 = city.player.position
	city.set_destination(start + Vector3(0.7, 0, 0.2))
	check(city.has_target, "三维点击目的地启用")
	for i in range(30):
		city._physics_process(0.016)
		await physics_frame
	check(city.player.position.distance_to(start) > 0.03, "角色可在三维地面移动")
	city.player.position = city.to_world(city.NPC_FOOT + Vector2(0, 80))
	city._physics_process(0.016)
	check(city.near_hint.text.contains("按 E"), "向导互动距离可触发")
	check(load("res://scenes/StageSelect.tscn") is PackedScene and load("res://scenes/Outskirts.tscn") is PackedScene, "原关卡和邻接区域可加载")
	print("CITY3D RESULT: %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
