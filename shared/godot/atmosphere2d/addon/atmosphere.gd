extends Node2D
## Attach to exactly one ordinary world canvas. Never attach to UI CanvasLayer.
const PRESETS = {
	"clear":{"ambient":Color(0.92,0.94,1),"rain":0.0,"snow":0.0,"fog":0.0,"wind":0.15,"wetness":0.0,"snow_cover":0.0},
	"rain":{"ambient":Color(0.50,0.60,0.72),"rain":0.85,"snow":0.0,"fog":0.18,"wind":0.5,"wetness":0.8,"snow_cover":0.0},
	"night":{"ambient":Color(0.16,0.22,0.36),"rain":0.3,"snow":0.0,"fog":0.25,"wind":0.25,"wetness":0.4,"snow_cover":0.0},
	"snow":{"ambient":Color(0.66,0.74,0.85),"rain":0.0,"snow":0.8,"fog":0.15,"wind":0.3,"wetness":0.0,"snow_cover":0.55}}
var bounds := Rect2(0,0,1280,800)
var observer := Vector2.ZERO
var frozen := false
var debug_regions := false
var quality := "high"
var regions: Dictionary = {}
var lights: Dictionary = {}
var _world: Node2D
var _modulate: CanvasModulate
var _current: Dictionary = PRESETS.clear.duplicate(true)
var _from: Dictionary = {}
var _target: Dictionary = PRESETS.clear.duplicate(true)
var _elapsed := 0.0
var _duration := 0.0
var _clock := 0.0
var _texture: GradientTexture2D
var _outside: AudioStreamPlayer
var _inside: AudioStreamPlayer

func attach_world(world: Node2D) -> void:
	assert(_world == null,"one atmosphere per world")
	_world = world
	world.add_child(self)
	z_index = 80
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_outside = AudioStreamPlayer.new()
	_inside = AudioStreamPlayer.new()
	add_child(_outside)
	add_child(_inside)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.width = 256
	_texture.height = 256
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5,0.5)
	_texture.fill_to = Vector2(0.5,1)

func set_environment(values: Dictionary, seconds: float = 1.0) -> void:
	_from = _current.duplicate(true)
	_target = _current.duplicate(true)
	if PRESETS.has(values.get("preset","")): _target = PRESETS[values.preset].duplicate(true)
	for key in _target:
		if not values.has(key): continue
		if key == "ambient" and values[key] is Color: _target[key] = values[key]
		elif key != "ambient" and (values[key] is float or values[key] is int) and is_finite(float(values[key])): _target[key] = clampf(float(values[key]),-1.0 if key == "wind" else 0.0,1.0)
	_elapsed = 0
	_duration = maxf(0,seconds) if is_finite(seconds) else 0
	if _duration == 0: _current = _target.duplicate(true)

func register_region(id: String, rect: Rect2, properties: Dictionary) -> void:
	# Properties: shelter, indoor, blend(px), ambient(Color), fog(0..1), snow_cover(0..1).
	regions[id] = {"rect":rect,"properties":properties.duplicate(true)}

func set_light(id: String, values: Dictionary) -> void:
	if not lights.has(id):
		var light := PointLight2D.new()
		light.texture = _texture
		light.energy = 0.0
		light.visible = quality != "off"
		light.shadow_enabled = true
		_world.add_child(light)
		lights[id] = {"node":light,"target":0.0,"speed":2.0,"config":{"position":Vector2.ZERO,"color":Color(1,0.76,0.46),"radius":180.0,"energy":1.0,"enabled":true,"seconds":0.5}}
	var entry: Dictionary = lights[id]
	var config: Dictionary = entry.config
	for key in config:
		if values.has(key): config[key] = values[key]
	var node: PointLight2D = entry.node
	node.position = config.position
	node.color = config.color
	node.texture_scale = maxf(0.1,float(config.radius)/128.0)
	entry.target = maxf(0,float(config.energy)) if config.enabled else 0.0
	entry.speed = 1.0/maxf(0.02,float(config.seconds))
	_apply_quality()

func remove_region(id: String) -> void:
	regions.erase(id)

func remove_light(id: String) -> void:
	if not lights.has(id): return
	var light: PointLight2D = lights[id].node
	lights.erase(id)
	if is_instance_valid(light):
		light.visible = false
		light.queue_free()

func dispose() -> void:
	for id in lights.keys(): remove_light(id)
	regions.clear()
	queue_free()

func _exit_tree() -> void:
	for id in lights.keys(): remove_light(id)
	regions.clear()

func fog_at(point: Vector2) -> float:
	var density: float = _current.fog
	var suppression := 1.0
	for region in regions.values():
		var w := _weight(point,region.rect,float(region.properties.get("blend",32)))
		density = lerpf(density,float(region.properties.get("fog",density)),w)
		if region.properties.get("indoor",false): suppression = minf(suppression,1.0-w*0.85)
		elif region.properties.get("shelter",false): suppression = minf(suppression,1.0-w*0.4)
	return density*suppression

func set_quality(name: String) -> void:
	if name in ["high","low","off"]:
		quality = name
		_apply_quality()

func _apply_quality() -> void:
	if _modulate == null: return
	var ambient: Color = _current.ambient
	for region in regions.values():
		var w := _weight(observer,region.rect,float(region.properties.get("blend",48)))
		if region.properties.has("ambient"): ambient = ambient.lerp(region.properties.ambient,w)
	_modulate.color = Color.WHITE if quality == "off" else ambient
	for entry in lights.values(): entry.node.visible = quality != "off"
	_outside.stream_paused = frozen or quality == "off"
	_inside.stream_paused = frozen or quality == "off"
	queue_redraw()

func set_audio(outside: AudioStream = null, inside: AudioStream = null) -> void:
	_outside.stream = outside
	_inside.stream = inside
	if outside != null: _outside.play()
	if inside != null: _inside.play()

func surface_at(point: Vector2) -> Dictionary:
	var sheltered := false
	var cover: float = _current.snow_cover
	for region in regions.values():
		if region.rect.has_point(point):
			sheltered = sheltered or region.properties.get("shelter",false) or region.properties.get("indoor",false)
			cover = float(region.properties.get("snow_cover",cover))
	return {"wetness":0.0 if sheltered or quality == "off" else _current.wetness,"snow_cover":0.0 if sheltered or quality == "off" else cover,"sheltered":sheltered}

func _weight(point: Vector2, rect: Rect2, blend: float) -> float:
	if not rect.has_point(point): return 0.0
	var edge := minf(minf(point.x-rect.position.x,rect.end.x-point.x),minf(point.y-rect.position.y,rect.end.y-point.y))
	return clampf(edge/maxf(1,blend),0,1)

func _process(delta: float) -> void:
	if _world == null: return
	if frozen:
		_apply_quality()
		return
	var dt := minf(delta,0.1)
	_clock += dt
	_elapsed += dt
	var t := 1.0 if _duration == 0 else clampf(_elapsed/_duration,0,1)
	for key in _current:
		_current[key] = _from.get(key,_current[key]).lerp(_target[key],t) if key == "ambient" else lerpf(float(_from.get(key,_current[key])),float(_target[key]),t)
	var interior := 0.0
	for region in regions.values():
		var w := _weight(observer,region.rect,float(region.properties.get("blend",48)))
		if region.properties.get("indoor",false): interior = maxf(interior,w)
	for entry in lights.values():
		var light: PointLight2D = entry.node
		light.energy = move_toward(light.energy,entry.target,dt*entry.speed)
	_outside.volume_db = linear_to_db(maxf(0.001,(1.0-interior)*0.65))
	_inside.volume_db = linear_to_db(maxf(0.001,interior*0.65))
	_apply_quality()

func _draw() -> void:
	if quality == "off": return
	var count := 170 if quality == "high" else 45
	for i in range(count):
		var p := Vector2(fposmod(i*127.3+_clock*float(_current.wind)*65,bounds.size.x),fposmod(i*71.9+_clock*(350 if _current.rain > _current.snow else 45),bounds.size.y))+bounds.position
		if surface_at(p).sheltered: continue
		if _current.rain > 0 and float(i)/count < float(_current.rain): draw_line(p,p+Vector2(-3-_current.wind*8,13),Color(0.64,0.78,0.9,0.48),1)
		if _current.snow > 0 and float(i)/count < float(_current.snow): draw_circle(p,1.8,Color(0.95,0.97,1,0.85))
		if i % 8 == 0 and _current.wind != 0: draw_line(p,p+Vector2(_current.wind*22,0),Color(0.8,0.85,0.9,absf(_current.wind)*0.15),1)
	# Soft radial wisps drift slowly; local region sampling suppresses indoor fog.
	var spacing := 52 if quality == "high" else 100
	for y in range(0,int(bounds.size.y),spacing):
		for x in range(0,int(bounds.size.x),spacing):
			var p := bounds.position+Vector2(fposmod(x+_clock*7,bounds.size.x),float(y)+sin(float(x)*0.013+_clock*0.12)*8)
			var alpha := fog_at(p)*0.12*(0.7+0.3*sin(float(x+y)*0.021+_clock*0.2))
			if alpha > 0.001: draw_texture_rect(_texture,Rect2(p-Vector2.ONE*spacing,Vector2.ONE*spacing*2),false,Color(0.65,0.73,0.8,alpha))
	for region in regions.values():
		if debug_regions: draw_rect(region.rect,Color(0.5,0.9,0.7,0.8),false,2)
