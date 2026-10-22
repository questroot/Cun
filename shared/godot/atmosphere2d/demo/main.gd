extends Node2D
## Spatial greybox, not final art. Input only; no remote state setters.
const Atmosphere = preload("../addon/atmosphere.gd")
const ROOM := Rect2(850,200,340,340)
const EAVE := Rect2(420,260,280,140)
const DOOR := Rect2(842,370,16,80)
const OPEN_LEAF := Rect2(858,362,70,8)
const WALLS := [Rect2(842,192,356,16),Rect2(1182,192,16,356),Rect2(842,532,356,16),Rect2(842,208,16,162),Rect2(842,450,16,82)]
const PRESETS := [
	{"name":"晴日","preset":"clear"},
	{"name":"阴雨","preset":"rain"},
	{"name":"雪日","preset":"snow"},
	{"name":"晴夜","preset":"night","rain":0.0,"wetness":0.0,"fog":0.04},
	{"name":"雨夜雾","preset":"night","rain":0.8,"snow":0.0,"wetness":0.8,"fog":0.35},
	{"name":"雪夜雾","preset":"night","rain":0.0,"snow":0.8,"wetness":0.0,"snow_cover":0.55,"fog":0.3}]
var atmosphere
var player := Vector2(200,530)
var crate := Vector2(670,470)
var carrying := false
var light_on := true
var door_open := true
var wall: LightOccluder2D
var feedback: Label
var png: Sprite2D
var _png_texture: Texture2D
var preset_name := "阴雨"
var notice := "走到门洞或箱旁按 E；不需解锁条件。"
var door_button: Button
var ground_cells: Array = []

func _ready() -> void:
	add_to_group("cun_play_visible")
	atmosphere = Atmosphere.new()
	atmosphere.attach_world(self)
	atmosphere.bounds = Rect2(24,176,1232,584)
	atmosphere.register_region("eave",EAVE,{"shelter":true})
	atmosphere.register_region("room",ROOM,{"indoor":true,"blend":40,"ambient":Color(0.65,0.55,0.43)})
	atmosphere.register_region("river_mist",Rect2(50,650,740,80),{"fog":0.3})
	atmosphere.set_light("lamp",{"position":Vector2(790,410),"radius":310,"energy":1.4})
	for rect in WALLS: _occluder(rect)
	wall = _occluder(DOOR)
	_update_door_occluder()
	# Ordinary runtime PNG consumer; a diagnostic swatch, not generated artwork.
	var image := Image.create(28,28,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.75,0.53,0.28))
	var decoded := Image.new()
	decoded.load_png_from_buffer(image.save_png_to_buffer())
	_png_texture = ImageTexture.create_from_image(decoded)
	png = Sprite2D.new()
	png.texture = _png_texture
	add_child(png)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,10)
	ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "氛围空间灰盒 · WASD/方向键走 · E近距开门/拿放箱 · 箱可带过门洞"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	for values in PRESETS:
		var button := Button.new()
		button.text = values.name
		button.pressed.connect(func(): choose_environment(values))
		row.add_child(button)
	for quality in ["high","low","off"]:
		var button := Button.new()
		button.text = {"high":"高","low":"低","off":"关效果"}[quality]
		button.pressed.connect(func(): atmosphere.set_quality(quality))
		row.add_child(button)
	var lamp := Button.new()
	lamp.text = "灯 开/关"
	lamp.pressed.connect(func(): light_on=not light_on; atmosphere.set_light("lamp",{"enabled":light_on,"position":Vector2(790,410),"radius":310,"energy":1.4}))
	row.add_child(lamp)
	door_button = Button.new()
	door_button.text = "近门 E开关"
	door_button.pressed.connect(toggle_door)
	row.add_child(door_button)
	var debug := CheckButton.new()
	debug.text = "区域调试（地面格是湿雪采样，非反射）"
	debug.toggled.connect(func(value): atmosphere.debug_regions=value)
	box.add_child(debug)
	feedback = Label.new()
	box.add_child(feedback)
	choose_environment(PRESETS[1],0)
	_update_ground()
	_update_objects()

func _occluder(rect: Rect2) -> LightOccluder2D:
	var node := LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	node.occluder = polygon
	add_child(node)
	return node

func choose_environment(values: Dictionary, seconds: float = 0.6) -> void:
	preset_name = values.name
	atmosphere.set_environment(values,seconds)

func toggle_door() -> void:
	if player.distance_to(DOOR.get_center()) > 105:
		notice = "请走近左墙唯一门洞（850,410）再开关。"
		return
	if door_open and (DOOR.grow(14).has_point(player) or DOOR.grow(20).has_point(crate)):
		notice = "门洞有人或箱，先退开，不夹住物件。"
		return
	door_open = not door_open
	_update_door_occluder()
	notice = "门已打开，固定墙仍在。" if door_open else "门已关闭，门叶挡路也挡灯。"

func _update_door_occluder() -> void:
	var r: Rect2 = OPEN_LEAF if door_open else DOOR
	wall.occluder.polygon = PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if carrying: place_crate()
		elif player.distance_to(crate) <= 64:
			carrying = true
			notice = "已提箱；E放下，湿雪不会因你进屋消失。"
		elif player.distance_to(DOOR.get_center()) <= 105: toggle_door()
		_update_objects()
		get_viewport().set_input_as_handled()

func interaction_hint() -> String:
	if carrying: return "E 放箱"
	if player.distance_to(crate) <= 64: return "E 拿箱"
	if player.distance_to(DOOR.get_center()) <= 105: return "E 关门" if door_open else "E 开门"
	return "无近距对象"

func place_crate() -> void:
	# Box half extent 16 + person radius 12 + 8px clearance.
	# Never leave the person on the inclusive top edge of Rect2.grow(12).
	for offset in [Vector2(0,36),Vector2(-36,0),Vector2(36,0),Vector2(0,-36)]:
		var target: Vector2 = player+offset
		var expanded := Rect2(target-Vector2(16,16),Vector2(32,32)).grow(12.5)
		if expanded.has_point(player) or not passable(target,16,false): continue
		crate = target
		carrying = false
		notice = "箱落地，身旁留有间隙；可再次拿起。"
		return
	notice = "身旁放不下，请先走到空处；箱仍在手上。"

func passable(point: Vector2, radius: float = 12, check_crate: bool = true) -> bool:
	if not Rect2(32+radius,180+radius,1216-radius*2,580-radius*2).has_point(point): return false
	for rect in WALLS:
		if rect.grow(radius).has_point(point): return false
	var leaf: Rect2 = OPEN_LEAF if door_open else DOOR
	if leaf.grow(radius).has_point(point): return false
	if check_crate and not carrying and Rect2(crate-Vector2(16,16),Vector2(32,32)).grow(radius).has_point(point): return false
	return true

func move_player(offset: Vector2) -> void:
	# Axis-separated, small bounded steps prevent tunnelling through thin walls.
	var steps := maxi(1,int(ceil(offset.length()/4.0)))
	for i in range(steps):
		var part := offset/steps
		for movement in [Vector2(part.x,0),Vector2(0,part.y)]:
			var next: Vector2 = player+movement
			if passable(next) and (not carrying or passable(next+Vector2(0,-18),16,false)): player = next
	if carrying: crate = player+Vector2(0,-18)

func _process(delta: float) -> void:
	var d := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	move_player(d.normalized()*minf(delta,0.05)*190)
	atmosphere.observer = player
	_update_ground()
	_update_objects()
	var surface: Dictionary = atmosphere.surface_at(player)
	feedback.text = "%s · %s · %s · %s · %s\n%s" % [preset_name,"室内" if ROOM.has_point(player) else ("檐下" if surface.sheltered else "庭院"),"提箱" if carrying else "空手",atmosphere.quality,interaction_hint(),notice]
	door_button.disabled = player.distance_to(DOOR.get_center()) > 105
	queue_redraw()

func _update_ground() -> void:
	ground_cells.clear()
	for y in range(184,744,28):
		for x in range(32,1236,28):
			var point := Vector2(x+14,y+14)
			var surface: Dictionary = atmosphere.surface_at(point)
			ground_cells.append({"rect":Rect2(x,y,26,26),"wet":float(surface.wetness),"snow":float(surface.snow_cover)})

func _update_objects() -> void:
	if carrying: crate = player+Vector2(0,-18)
	png.position = crate-Vector2(0,10)

func play_visible() -> Dictionary:
	# All descriptions below correspond to persistent drawn geometry/text, no future state.
	return {"scene":"公共氛围空间灰盒","player_screen":{"x":player.x,"y":player.y},"room":{"bounds":_rect(ROOM),"doorway":_rect(DOOR),"appearance":"开门" if door_open else "关门"},"fixed_walls":WALLS.map(func(r): return _rect(r)),"eave":{"bounds":_rect(EAVE)},"crate":{"x":crate.x,"y":crate.y,"appearance":"手上小箱" if carrying else "地面小箱"},"weather_label":preset_name,"visible_hint":feedback.text if feedback != null else "","ground":"固定28px采样格显示湿雪，不是反射","lamp":{"x":790,"y":410,"appearance":"亮" if light_on else "灭"},"input":"WASD/方向键移动，近箱或近门E；天气和质量用屏幕按钮"}

func _rect(r: Rect2) -> Dictionary:
	return {"x":r.position.x,"y":r.position.y,"width":r.size.x,"height":r.size.y}

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color(0.28,0.35,0.35))
	draw_rect(EAVE,Color(0.48,0.43,0.32))
	draw_rect(ROOM,Color(0.52,0.45,0.36))
	for cell in ground_cells:
		if cell.wet > 0.001: draw_rect(cell.rect,Color(0.44,0.60,0.69,cell.wet*0.26))
		if cell.snow > 0.001: draw_rect(cell.rect,Color(0.91,0.95,0.98,cell.snow*0.8))
	for rect in WALLS: draw_rect(rect,Color(0.25,0.20,0.16))
	draw_rect(Rect2(842,370,16,80) if not door_open else Rect2(858,362,70,8),Color(0.65,0.42,0.24))
	# Open leaf rests inside above doorway; never hides/replaces fixed walls.
	draw_line(Vector2(420,400),Vector2(700,400),Color(0.68,0.59,0.40),5)
	draw_circle(Vector2(790,410),7,Color(1,0.8,0.45) if light_on else Color(0.3,0.3,0.3))
	if not carrying: draw_ellipse_shadow(crate+Vector2(0,5),18)
	draw_ellipse_shadow(player+Vector2(0,18),16)
	draw_rect(Rect2(player-Vector2(10,10),Vector2(20,30)),Color(0.8,0.63,0.43))
	draw_circle(player-Vector2(0,17),10,Color(0.88,0.77,0.63))

func draw_ellipse_shadow(at: Vector2, radius: float) -> void:
	draw_set_transform(at,0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,radius,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO)
