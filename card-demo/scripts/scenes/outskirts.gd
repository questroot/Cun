extends Control
const ExplorationTools = preload("res://scripts/scenes/exploration_tools.gd")
var exploration_tools: ExplorationTools
## Small linked exploration zone. Future areas can reuse the same region entry contract.
const HeroWalkScript = preload("res://scripts/scenes/hero_walk_sprite.gd")
const AREA := Rect2(58, 340, 1155, 315)
const RETURN := Rect2(58, 479, 58, 155)
# 海底水世界已移至游戏选择；保留原水门配置供回看。
# const WATER_PORTAL := Rect2(1000, 500, 88, 115)
var player_foot := Vector2(140, 576)
var model: HeroWalkScript
var target := Vector2.ZERO
var moving := false
var transition_ready := false

func _ready() -> void:
	add_to_group("cun_play_visible")
	var landscape := Node2D.new()
	landscape.set_script(preload("res://scripts/scenes/outskirts_map.gd"))
	add_child(landscape)
	model = HeroWalkScript.new()
	add_child(model)
	var header := PanelContainer.new()
	header.position = Vector2(28, 24)
	header.custom_minimum_size = Vector2(453, 92)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.03, 0.14, 0.16, 0.92)
	skin.border_color = Color("#ddc991")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(12)
	skin.set_content_margin_all(12)
	header.add_theme_stylebox_override("panel", skin)
	add_child(header)
	var message := Label.new()
	message.text = "云庭外缘  /  漫游广场\nWASD 或点击移动 · 左侧返回主城\n海底水世界请从游戏选择进入"
	message.add_theme_color_override("font_color", Color("#fff1d0"))
	message.add_theme_font_size_override("font_size", 20)
	header.add_child(message)
	var back := Button.new()
	back.text = "返回主城"
	back.position = Vector2(1071, 34)
	back.size = Vector2(170, 47)
	back.pressed.connect(func() -> void: GameManager.enter_region("city", Vector2(1900, 729)))
	add_child(back)
	# 原冒险世界水门停用，入口移至主界面的“海底水世界”。
	# var portal_button := Button.new()
	# portal_button.text = "漂流浮台 →"
	# portal_button.position = Vector2(1000, 608)
	# portal_button.size = Vector2(150, 43)
	# portal_button.pressed.connect(func() -> void: GameManager.goto_scene("water_activity"))
	# add_child(portal_button)
	model.position = player_foot
	# Prevent an immediate bounce when the arrival spawn overlaps the return gate.
	call_deferred("_enable_transition")
	exploration_tools = ExplorationTools.new()
	exploration_tools.region = "outskirts"
	add_child(exploration_tools)

func play_visible() -> Dictionary:
	return {"location":"云庭外缘", "player_screen":{"x":player_foot.x,"y":player_foot.y}, "return_gate_screen":{"x":RETURN.get_center().x,"y":RETURN.get_center().y}, "controls":"WASD或点击地面移动；左侧返回主城；海底水世界请从游戏选择进入"}

func _enable_transition() -> void:
	transition_ready = true

func _unhandled_input(event: InputEvent) -> void:
	if exploration_tools.is_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		if AREA.has_point(point):
			target = point
			moving = true

func _process(delta: float) -> void:
	if exploration_tools.is_open():
		model.update_movement(Vector2.ZERO, 0)
		return
	var previous_foot := player_foot
	var direction := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))).normalized()
	if direction != Vector2.ZERO:
		moving = false
	elif moving:
		if player_foot.distance_to(target) < 4.0:
			moving = false
		else:
			direction = (target - player_foot).normalized()
	var motion := direction * delta * 260.0
	if moving and motion.length() > player_foot.distance_to(target):
		motion = target - player_foot
	player_foot += motion
	player_foot.x = clampf(player_foot.x, AREA.position.x + 10, AREA.end.x - 10)
	player_foot.y = clampf(player_foot.y, AREA.position.y + 10, AREA.end.y - 10)
	model.position = player_foot
	model.update_movement(player_foot - previous_foot, delta)
	if transition_ready and RETURN.has_point(player_foot):
		transition_ready = false
		GameManager.enter_region("city", Vector2(1900, 729))
	# elif transition_ready and WATER_PORTAL.has_point(player_foot):
	# 	transition_ready = false
	# 	GameManager.goto_scene("water_activity")
