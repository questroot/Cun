extends RefCounted
const Atmosphere = preload("res://addons/cun_atmosphere2d/atmosphere.gd")
var effect: Node2D
var occluders: Node2D
var signature := ""

func clear() -> void:
	if is_instance_valid(effect):
		effect.hide()
		effect.dispose()
	if is_instance_valid(occluders): occluders.queue_free()
	effect = null
	occluders = null
	signature = ""

func update(host: Node2D) -> void:
	if not host.started or host.story.s.place != "shelter":
		if is_instance_valid(effect): clear()
		return
	if not is_instance_valid(effect):
		effect = Atmosphere.new()
		effect.attach_world(host.environment_world())
		effect.bounds = Rect2(0,155,855,485)
		occluders = Node2D.new()
		host.environment_world().add_child(occluders)
		# The cohesive background removed the old interior beam/posts. Their old
		# screen rectangles must not cast invisible shadows. Background edge timber
		# has no verified independent silhouette yet; deliberately register none.
		var visible_timber: Array[Rect2] = []
		for rect in visible_timber:
			var blocker := LightOccluder2D.new()
			var shape := OccluderPolygon2D.new()
			shape.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			blocker.occluder = shape
			occluders.add_child(blocker)
	effect.observer = host.player
	effect.frozen = host.modal_open or host.paused
	var phase: String = host.story.s.phase
	var flood: bool = host.story.s.ending == "flood"
	var tied: bool = host.story.flag("awning_tied")
	var warm: bool = host.story.flag("shade_off") or host.story.flag("swapped")
	var yellow: bool = host.story.flag("yellow_lit")
	var next := str([phase,flood,tied,warm,yellow])
	if signature == next: return
	signature = next
	var ambient := Color(0.32,0.38,0.46) if phase == "night" else (Color(0.82,0.84,0.82) if phase == "epilogue" else Color(0.78,0.76,0.71))
	effect.set_environment({"ambient":ambient,"rain":0.0 if phase == "epilogue" and not flood else 0.28,"snow":0.0,"fog":0.06 if phase == "night" else 0.02,"wind":0.12,"wetness":0.65},0.6)
	effect.register_region("left_dry",Rect2(330,340,110,70),{"shelter":true})
	if tied: effect.register_region("right_dry",Rect2(590,365,135,75),{"shelter":true})
	else: effect.remove_region("right_dry")
	effect.set_light("main",{"position":Vector2(250,360),"radius":110,"color":Color("ffd49a") if warm else Color("e8efff"),"energy":1.0,"enabled":not flood,"seconds":0.3})
	effect.set_light("yellow",{"position":Vector2(620,390),"radius":95,"color":Color("ffd49a"),"energy":0.8,"enabled":yellow and not flood,"seconds":0.3})
