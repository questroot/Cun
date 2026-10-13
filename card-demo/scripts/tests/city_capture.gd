extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var battle_mode: bool = OS.get_cmdline_user_args().has("--battle")
	var scene_path: String = "res://scenes/Battle.tscn" if battle_mode else "res://scenes/MainCity.tscn"
	var scene: PackedScene = load(scene_path)
	var instance := scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	for i in range(35 if battle_mode else 5):
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("CAPTURE: SKIPPED (headless renderer has no framebuffer)")
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var output: String = "user://battle_capture_preview.png" if battle_mode else "user://city_capture_preview.png"
	var error := image.save_png(output)
	print("CAPTURE: %s (%s) %s" % ["PASS" if error == OK else "FAIL", image.get_size(), ProjectSettings.globalize_path(output)])
	quit(0 if error == OK else 1)
