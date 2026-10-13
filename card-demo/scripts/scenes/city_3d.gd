extends Node3D
## Truly 3D playable city: 3D camera, GLB geometry, 3D characters and physical blockers.
const CONCEPT := preload("res://assets/models/city_concept_ai_reference.glb")
const CityNavigation := preload("res://scripts/scenes/city_map.gd")
const BUILDINGS := [
	preload("res://assets/models/city_west_hall.glb"),
	preload("res://assets/models/city_market.glb"),
	preload("res://assets/models/city_east_hall.glb"),
	preload("res://assets/models/city_library.glb"),
	preload("res://assets/models/city_observatory.glb"),
]
const FOOTPRINTS := [Rect2(104,363,220,111), Rect2(403,367,153,76), Rect2(962,361,216,115), Rect2(1310,365,245,116), Rect2(1710,370,190,117)]
const DETAIL_BLOCKERS := [Rect2(604,526,88,75),Rect2(172,534,84,69),Rect2(1017,549,85,65),Rect2(1440,614,92,70),Rect2(1840,624,94,68)]
const NPC_FOOT := Vector2(843, 562)
const TALK_DISTANCE := 105.0
const WORLD_SCALE := 100.0
const MIN_X := 0.8
const MAX_X := 20.0
const MIN_Z := 3.55
const MAX_Z := 7.82

var player: CharacterBody3D
var npc: Node3D
var camera: Camera3D
var dialogue: PanelContainer
var header: PanelContainer
var status_panel: PanelContainer
var nav_panel: PanelContainer
var party_panel: PanelContainer
var near_hint: Label
var status_label: Label
var nav_label: Label
var world: Node3D
var target := Vector3.ZERO
var has_target := false
var waiting_for_npc := false
var exit_armed := true
var city_map: Node3D
var navigation: Node2D
var route: Array[Vector2] = []

func to_world(point: Vector2) -> Vector3:
	return Vector3(point.x / WORLD_SCALE, 0.03, point.y / WORLD_SCALE)

func _ready() -> void:
	world = Node3D.new()
	world.name = "Playable3DWorld"
	add_child(world)
	city_map = world
	# Retain the existing obstacle-grid route planner, but never render its 2D map.
	navigation = CityNavigation.new()
	navigation.visible = false
	navigation.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(navigation)
	_build_environment()
	_build_ground()
	_build_concept_landmark()
	_build_buildings()
	_build_props()
	_build_characters()
	_build_camera()
	_build_ui()
	player.global_position = to_world(GameManager.city_spawn if GameManager.city_spawn.x < 1950 else Vector2(1840, 700))
	GameManager.city_spawn = Vector2(334, 558)
	target = player.global_position
	_update_camera(1.0)
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	DataManager.save_changed.connect(_refresh_status)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "SkyAndAmbient"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#aecfc3")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#e1eed7")
	settings.ambient_light_energy = 0.85
	env.environment = settings
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -24, 0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	world.add_child(sun)

func _material(color: Color, roughness := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _box(label: String, size: Vector3, center: Vector3, color: Color, solid := false) -> Node3D:
	var host: Node3D = StaticBody3D.new() if solid else Node3D.new()
	host.name = label
	host.position = center
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = _material(color)
	host.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		host.add_child(collision)
	world.add_child(host)
	return host

func _build_ground() -> void:
	_box("SolidGround", Vector3(21.0, 0.3, 9.2), Vector3(10.4, -0.18, 4.5), Color("#718f71"), true)
	_box("StoneMainRoad", Vector3(19.5, 0.03, 2.94), Vector3(10.4, 0.0, 6.2), Color("#c9b798"))
	_box("StoneNorthRoad", Vector3(19.5, 0.035, 0.5), Vector3(10.4, 0.02, 5.02), Color("#d4c49e"))
	for x in [8.4, 16.4]:
		_box("OpenPlaza", Vector3(2.0, 0.04, 1.85), Vector3(x, 0.03, 6.4), Color("#dac9a5"))
	for row in range(5):
		for column in range(33):
			var x := 2.8 + column * 0.53 + (0.23 if row % 2 == 1 else 0.0)
			var z := 5.5 + row * 0.5
			_box("PavingJoint", Vector3(0.29, 0.004, 0.007), Vector3(x, 0.044, z), Color("#a99878"))
	_box("EastExitMarker", Vector3(0.32, 0.055, 0.7), Vector3(19.8, 0.05, 7.15), Color("#e5c577"))

func _build_concept_landmark() -> void:
	# Actual GLB in the main 3D world, NOT a ViewportTexture or Sprite2D.
	var concept := CONCEPT.instantiate()
	concept.name = "ConceptCityGLB"
	concept.position = Vector3(10.3, 3.4, 1.0)
	concept.rotation_degrees = Vector3(0, 180, 0)
	concept.scale = Vector3.ONE * 3.2
	world.add_child(concept)
	# The generated combined mesh has no reliable individual walkable/collision parts.
	# Accessible ground and close-range buildings are explicit 3D geometry below.

func _build_buildings() -> void:
	for index in range(FOOTPRINTS.size()):
		var footprint: Rect2 = FOOTPRINTS[index]
		var center := to_world(footprint.get_center())
		var width := footprint.size.x / WORLD_SCALE
		var depth := footprint.size.y / WORLD_SCALE
		var blocker := _box("BuildingCollision%d" % index, Vector3(width, 2.7, depth), center + Vector3(0, 1.35, 0), Color("#bda986"), true)
		blocker.get_child(0).visible = false
		var building: Node3D = BUILDINGS[index].instantiate()
		building.name = "BuildingModel%d" % index
		building.position = center + Vector3(0, 0, 0)
		world.add_child(building)

func _build_props() -> void:
	for index in range(DETAIL_BLOCKERS.size()):
		var area: Rect2 = DETAIL_BLOCKERS[index]
		var center := to_world(area.get_center())
		var size := Vector3(area.size.x / WORLD_SCALE, 0.36, area.size.y / WORLD_SCALE)
		_box("GardenOrFountain%d" % index, size, center + Vector3(0, 0.18, 0), Color("#68a09a") if index == 0 else Color("#5d9970"), true)
		if index == 0:
			var water := _box("FountainWater", Vector3(0.62, 0.02, 0.48), center + Vector3(0, 0.38, 0), Color("#91cdd0", 0.22))
			water.rotation_degrees.y = 12
	for x in [3.6, 7.4, 12.1, 16.1, 18.1]:
		_box("StreetLamp", Vector3(0.07, 1.1, 0.07), Vector3(x, 0.55, 4.45), Color("#415e58"))
		_box("LampLight", Vector3(0.22, 0.22, 0.22), Vector3(x, 1.16, 4.45), Color("#f2d9a4"))

func _build_character(label: String, color: Color, at: Vector3) -> CharacterBody3D:
	var character := CharacterBody3D.new()
	character.name = label
	character.position = at
	character.collision_layer = 1
	character.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.14
	capsule.height = 0.86
	collision.shape = capsule
	collision.position.y = 0.43
	character.add_child(collision)
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 0.74
	body.mesh = body_mesh
	body.material_override = _material(color)
	body.position.y = 0.4
	character.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "HeadMesh"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.material_override = _material(Color("#e4c9a2"))
	head.position.y = 0.92
	character.add_child(head)
	world.add_child(character)
	return character

func _build_characters() -> void:
	player = _build_character("Player3D", Color("#a4584d"), to_world(Vector2(334, 558)))
	npc = _build_character("StageGuide3D", Color("#427e75"), to_world(NPC_FOOT))
	_box("GuideSign", Vector3(0.53, 0.25, 0.1), to_world(NPC_FOOT) + Vector3(0, 1.45, -0.16), Color("#d7c28d"))

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FollowCamera3D"
	camera.fov = 55
	camera.near = 0.05
	camera.far = 90.0
	world.add_child(camera)
	camera.current = true

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.13, 0.15, 0.91)
	style.border_color = Color("#dbcc93")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style

func _panel(label: String) -> PanelContainer:
	var ui := PanelContainer.new()
	ui.name = label
	ui.add_theme_stylebox_override("panel", _card_style())
	add_child(ui)
	return ui

func _build_ui() -> void:
	header = _panel("CityHeader")
	var title := Label.new()
	title.text = "云庭主城 · 三维漫游"
	title.add_theme_font_size_override("font_size", 23)
	header.add_child(title)
	status_panel = _panel("CityStatus")
	status_label = Label.new()
	status_panel.add_child(status_label)
	party_panel = _panel("CityParty")
	var team := Button.new()
	team.text = "调整阵容"
	team.pressed.connect(func() -> void: GameManager.goto_scene("team"))
	party_panel.add_child(team)
	nav_panel = _panel("CityNavigation")
	nav_label = Label.new()
	nav_label.text = "WASD 移动 · 点击地面寻路 · 靠近向导按 E"
	nav_panel.add_child(nav_label)
	near_hint = Label.new()
	near_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_hint.add_theme_color_override("font_color", Color("#fff0c6"))
	near_hint.add_theme_color_override("font_shadow_color", Color("#183b3b"))
	near_hint.add_theme_constant_override("shadow_offset_x", 2)
	near_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(near_hint)
	dialogue = _panel("GuideDialogue")
	dialogue.visible = false
	var box := VBoxContainer.new()
	dialogue.add_child(box)
	var speech := Label.new()
	speech.text = "关卡向导：历练之路已开放，要查看可挑战的副本吗？"
	box.add_child(speech)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var open := Button.new()
	open.text = "查看关卡"
	open.pressed.connect(func() -> void: GameManager.goto_scene("stages"))
	actions.add_child(open)
	var close := Button.new()
	close.text = "稍后再说"
	close.pressed.connect(func() -> void: dialogue.hide())
	actions.add_child(close)
	_refresh_status()

func _refresh_status() -> void:
	if status_label == null:
		return
	var level := int((DataManager.save_data.get("levels", {}) as Dictionary).get("hero", 1))
	status_label.text = "主角 Lv.%d · 历练 %d/3" % [level, int(DataManager.save_data.get("unlocked_stage", 1))]

func _layout_ui() -> void:
	if header == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var margin := 16.0 if screen.x < 1000.0 else 24.0
	header.position = Vector2(margin, margin)
	header.size = Vector2(290, 54)
	status_panel.position = Vector2(margin, margin + 62)
	status_panel.size = Vector2(minf(285.0, screen.x - margin * 2.0), 48)
	party_panel.position = Vector2(margin, margin + 119) if screen.x < 780.0 else Vector2(screen.x - margin - 166, margin)
	party_panel.size = Vector2(166, 56)
	nav_panel.position = Vector2(margin, screen.y - margin - 55)
	nav_panel.size = Vector2(minf(550.0, screen.x - margin * 2.0), 55)
	dialogue.position = Vector2(maxf(margin, (screen.x - 630.0) / 2.0), screen.y - margin - 165)
	dialogue.size = Vector2(minf(630.0, screen.x - margin * 2.0), 148)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not dialogue.visible:
		var from := camera.project_ray_origin(event.position)
		var direction := camera.project_ray_normal(event.position)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * 90.0))
		if hit.has("position"):
			var point: Vector3 = hit["position"]
			if hit["collider"] == npc:
				request_npc_conversation()
			elif point.x >= MIN_X and point.x <= MAX_X and point.z >= MIN_Z and point.z <= MAX_Z:
				set_destination(point)
				waiting_for_npc = false
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not dialogue.visible:
		if player.global_position.distance_to(npc.global_position) <= TALK_DISTANCE / WORLD_SCALE:
			dialogue.show()

func request_npc_conversation() -> void:
	if player.position.distance_to(npc.position) <= TALK_DISTANCE / WORLD_SCALE:
		dialogue.show()
	else:
		var approach := npc.position + (player.position - npc.position).normalized() * 0.75
		set_destination(approach)
		waiting_for_npc = has_target

func set_destination(point: Vector3) -> void:
	var start := Vector2(player.position.x * WORLD_SCALE, player.position.z * WORLD_SCALE)
	var goal := Vector2(point.x * WORLD_SCALE, point.z * WORLD_SCALE)
	route = navigation.find_path(start, goal)
	has_target = not route.is_empty()
	if has_target:
		target = to_world(route[0])

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var move := Vector3.ZERO
	if not dialogue.visible:
		move = Vector3(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), 0, float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		if move.length_squared() > 0:
			move = move.normalized()
			has_target = false
			route.clear()
		elif has_target:
			while not route.is_empty() and player.position.distance_to(to_world(route[0])) < 0.16:
				route.pop_front()
			if route.is_empty():
				has_target = false
				if waiting_for_npc and player.position.distance_to(npc.position) <= TALK_DISTANCE / WORLD_SCALE:
					dialogue.show()
					waiting_for_npc = false
			else:
				target = to_world(route[0])
				var offset := target - player.position
				offset.y = 0
				move = offset.normalized()
	player.velocity.x = move.x * 3.1
	player.velocity.z = move.z * 3.1
	player.velocity.y = -1.0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, MIN_X, MAX_X)
	player.position.z = clampf(player.position.z, MIN_Z, MAX_Z)
	if move.length_squared() > 0:
		player.rotation.y = atan2(-move.x, -move.z)
	_update_camera(delta)
	var position := camera.unproject_position(npc.global_position + Vector3(0, 1.6, 0))
	near_hint.position = Vector2(clampf(position.x - 112.0, 12.0, get_viewport().get_visible_rect().size.x - 230.0), clampf(position.y, 120.0, get_viewport().get_visible_rect().size.y - 92.0))
	near_hint.text = "靠近向导按 E 查看关卡" if player.global_position.distance_to(npc.global_position) <= TALK_DISTANCE / WORLD_SCALE else ""
	if exit_armed and player.position.x >= 19.55 and player.position.z >= 6.8:
		exit_armed = false
		GameManager.enter_region("outskirts", Vector2(140, 576))

func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	var goal := player.global_position + Vector3(0, 4.8, 8.0)
	camera.global_position = camera.global_position.lerp(goal, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 0.7, -1.7), Vector3.UP)
