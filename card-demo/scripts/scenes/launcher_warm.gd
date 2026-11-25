extends Node
## Minimal resident scene. The desktop owns visibility; no gameplay until a route is requested.

var channel := ""
var next_poll := 0.0
var dispatched := false
var original_max_fps := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var arg := args.find("--cun-warm")
	if arg < 0 or arg + 1 >= args.size() or "--cun-scroll" not in args:
		get_tree().quit(1)
		return
	channel = args[arg + 1]
	original_max_fps = Engine.max_fps
	Engine.max_fps = 12
	_marker(".ready")

func _process(delta: float) -> void:
	if channel.is_empty() or dispatched:
		return
	next_poll -= delta
	if next_poll > 0.0:
		return
	next_poll = 0.045
	if FileAccess.file_exists(channel + ".stop"):
		get_tree().quit()
		return
	if not FileAccess.file_exists(channel + ".request"):
		return
	dispatched = true
	var route := FileAccess.get_file_as_string(channel + ".request").strip_edges()
	if not route.begins_with("res://") or not route.ends_with(".tscn") or route.contains("..") or route == scene_file_path:
		get_tree().quit(1)
		return
	Engine.max_fps = original_max_fps
	DataManager.load_save()
	GameManager.load_sea_save()
	# The scene change immediately detaches this node from the tree.
	var tree := get_tree()
	tree.scene_changed.connect(GameManager.launcher_scene_ready.bind(channel + ".scene"), CONNECT_ONE_SHOT)
	if tree.change_scene_to_file(route) != OK:
		tree.quit(1)

func _marker(suffix: String) -> void:
	var file := FileAccess.open(channel + suffix, FileAccess.WRITE)
	if file == null:
		get_tree().quit(1)
	else:
		file.store_string("ready")
