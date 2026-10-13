extends Node2D
## Render the actual concept-derived GLB behind the walkable 2D city.
## The source is one fused diorama without usable individual collision meshes.
const CONCEPT_MODEL := preload("res://assets/models/city_concept_ai_reference.glb")
const VIEW_SIZE := Vector2i(1024, 700)

var model_view: SubViewport
var model_instance: Node3D

func _ready() -> void:
	z_index = 0
	model_view = SubViewport.new()
	model_view.name = "ConceptModelViewport"
	model_view.size = VIEW_SIZE
	model_view.transparent_bg = false
	# The GLB is static; redraw only when needed instead of rendering 3D every frame.
	model_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	model_view.own_world_3d = true
	add_child(model_view)

	var stage := Node3D.new()
	stage.name = "ConceptModelStage"
	model_view.add_child(stage)
	model_instance = CONCEPT_MODEL.instantiate()
	model_instance.name = "ConceptCityGLB"
	stage.add_child(model_instance)
	# The input asset is a single, normalized GLB (about 1.9 units wide).
	# A slight turn reveals its relief while preserving its front-facing composition.
	model_instance.rotation_degrees = Vector3(-7, -9, 0)

	var camera := Camera3D.new()
	camera.name = "ModelCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.3
	camera.position = Vector3(0, 0.02, 3.5)
	camera.current = true
	stage.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var environment := WorldEnvironment.new()
	environment.name = "ModelEnvironment"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#b3cbb4")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#e4ebd9")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	stage.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "ModelLight"
	key_light.rotation_degrees = Vector3(-28, -35, 0)
	key_light.light_energy = 1.8
	stage.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(32, 140, 0)
	fill_light.light_energy = 0.7
	stage.add_child(fill_light)

	var artwork := Sprite2D.new()
	artwork.name = "LiveConceptModel"
	artwork.texture = model_view.get_texture()
	artwork.centered = false
	# The only visible city art: fill the original 2080 x 900 playable world.
	artwork.position = Vector2.ZERO
	artwork.scale = Vector2(2080.0 / VIEW_SIZE.x, 900.0 / VIEW_SIZE.y)
	add_child(artwork)
