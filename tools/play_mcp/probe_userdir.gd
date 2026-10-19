extends SceneTree
func _initialize() -> void:
	print("USER_DIR=" + OS.get_user_data_dir())
	quit()
