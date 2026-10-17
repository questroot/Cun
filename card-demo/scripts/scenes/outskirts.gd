extends Control
## Small linked exploration zone. Future areas can reuse the same region entry contract.
const PLAYER_ART := preload("res://assets/characters/pet_hero.png")
const AREA := Rect2(58, 340, 1155, 315)
const RETURN := Rect2(58, 479, 58, 155)
var player_foot := Vector2(140, 576)
var model: Sprite2D
var target := Vector2.ZERO
var moving := false
var transition_ready := false

func _ready() -> void:
	var landscape := Node2D.new()
	landscape.set_script(preload("res://scripts/scenes/outskirts_map.gd"))
	add_child(landscape)
	model = Sprite2D.new()
	model.texture = PLAYER_ART
	model.offset = Vector2(0, -128)
	model.scale = Vector2(0.52, 0.52)
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
	message.text = "云庭外缘  /  探索区域\nWASD 或点击移动 · 从左侧出口返回主城"
	message.add_theme_color_override("font_color", Color("#fff1d0"))
	message.add_theme_font_size_override("font_size", 20)
	header.add_child(message)
	var back := Button.new()
	back.text = "返回主城"
	back.position = Vector2(1071, 34)
	back.size = Vector2(170, 47)
	back.pressed.connect(func() -> void: GameManager.enter_region("city", Vector2(1900, 729)))
	add_child(back)
	model.position = player_foot
	# Prevent an immediate bounce when the arrival spawn overlaps the return gate.
	call_deferred("_enable_transition")

func _enable_transition() -> void:
	transition_ready = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		if AREA.has_point(point):
			target = point
			moving = true

func _process(delta: float) -> void:
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
	if absf(direction.x) > 0.01:
		model.flip_h = direction.x < 0
	if transition_ready and RETURN.has_point(player_foot):
		transition_ready = false
		GameManager.enter_region("city", Vector2(1900, 729))
