extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene: PackedScene = load("res://scenes/City3D.tscn")
	var city := scene.instantiate()
	root.add_child(city)
	current_scene = city
	for i in range(20):
		await process_frame
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var error := image.save_png("user://city3d_capture_preview.png")
	print("CITY3D CAPTURE: %s (%s)" % ["PASS" if error == OK else "FAIL", image.get_size()])
	quit(0 if error == OK else 1)
