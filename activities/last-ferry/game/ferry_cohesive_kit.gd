extends RefCounted
## Only approved static candidates; standing art is never substituted for carry/sit/drag.
const ROOT := "res://art/cohesive_v1/"
var layers: Dictionary = {}
var textures: Dictionary = {}

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for layer in data.layers:
		if layer.ready or layer.id in ["stool","white_lamp"]:
			layers[layer.id] = layer
			textures[layer.id] = load(ROOT+layer.path)
	textures["background"] = load(ROOT+data.background.path)
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cohesive_actions_v1/manifest.json"))
	for pose in actions.poses:
		layers[pose.id] = pose
		textures[pose.id] = load("res://art/cohesive_actions_v1/"+pose.path)

func actor(host: Node2D, id: String, foot: Vector2) -> void:
	var layer: Dictionary = layers[id]
	var scale: float = layer.uniform_scale
	var anchor := Vector2(layer.foot_anchor[0],layer.foot_anchor[1])
	var texture: Texture2D = textures[id]
	host.record_draw("draw_set_transform",[foot+Vector2(0,-2),0.0,Vector2(1,0.28)])
	host.record_draw("draw_circle",[Vector2.ZERO,12,Color(0,0,0,0.16)])
	host.record_draw("draw_set_transform",[Vector2.ZERO,0.0,Vector2.ONE])
	host.record_draw("draw_texture_rect",[texture,Rect2(foot-anchor*scale,texture.get_size()*scale),false])

func keypose(host: Node2D, id: String, point: Vector2, seat: bool = false, mirrored: bool = false) -> void:
	var layer: Dictionary = layers[id]
	var scale: float = layer.scale
	var raw: Array = layer.seat_anchor if seat else layer.foot_anchor
	var anchor := Vector2(raw[0],raw[1])
	var texture: Texture2D = textures[id]
	var foot_offset := (Vector2(layer.foot_anchor[0],layer.foot_anchor[1])-anchor)*scale
	if mirrored: foot_offset.x = -foot_offset.x
	# Same subtle contact as standing; derive the ground point even when seated.
	host.record_draw("draw_set_transform",[point+foot_offset+Vector2(0,-2),0.0,Vector2(1,0.28)])
	host.record_draw("draw_circle",[Vector2.ZERO,12,Color(0,0,0,0.16)])
	host.record_draw("draw_set_transform",[Vector2.ZERO,0.0,Vector2.ONE])
	if mirrored:
		host.record_draw("draw_set_transform",[point,0.0,Vector2(-1,1)])
		host.record_draw("draw_texture_rect",[texture,Rect2(-anchor*scale,texture.get_size()*scale),false])
		host.record_draw("draw_set_transform",[Vector2.ZERO,0.0,Vector2.ONE])
	else:
		host.record_draw("draw_texture_rect",[texture,Rect2(point-anchor*scale,texture.get_size()*scale),false])

func stool_seat(chair: Vector2) -> Vector2:
	return chair+Vector2(0,-10)

func carry_layout(player: Vector2, direction: String) -> Dictionary:
	var pose: Dictionary = layers["protagonist_carry_"+("E" if direction == "W" else direction)]
	var foot := Vector2(pose.foot_anchor[0],pose.foot_anchor[1])
	var points: Array[Vector2] = []
	for raw in pose.hand_sockets:
		var offset := (Vector2(raw[0],raw[1])-foot)*float(pose.scale)
		if direction == "W": offset.x = -offset.x
		points.append(player+Vector2(0,24)+offset)
	return {"seat":(points[0]+points[1])*0.5,"hands":points,"id":pose.id,"mirrored":direction == "W"}

func carried_stool(host: Node2D, player: Vector2, direction: String) -> void:
	# Temporary legacy composition; replace with an authored combined carry asset.
	# Never overlay detached rectangular hand patches over the stool texture.
	var layout := carry_layout(player,direction)
	stool(host,layout.seat-Vector2(0,-10))

func stool(host: Node2D, chair: Vector2) -> void:
	var texture: Texture2D = textures.stool
	var scale := 40.0/texture.get_width()
	var raw: Array = layers.stool.seat_anchor
	var visual_scale := Vector2(scale,scale*1.11765) # +2.417px seat-to-bottom; width stays 40.
	host.record_draw("draw_texture_rect",[texture,Rect2(stool_seat(chair)-Vector2(raw[0],raw[1])*visual_scale,texture.get_size()*visual_scale),false])

func lamp(host: Node2D, position: Vector2, on: bool, warm: bool = false) -> void:
	var texture: Texture2D = textures.white_lamp
	var size := texture.get_size()*32.0/texture.get_width()
	var tint := Color(0.32,0.36,0.38) if not on else (Color(1,0.86,0.68) if warm else Color(0.8,0.85,0.88))
	host.record_draw("draw_texture_rect",[texture,Rect2(position-Vector2(size.x/2,size.y/2),size),false,tint])

func prop(host: Node2D, id: String, anchor: Vector2, width: float) -> void:
	var texture: Texture2D = textures[id]
	var size := texture.get_size()*width/texture.get_width()
	host.record_draw("draw_texture_rect",[texture,Rect2(anchor-Vector2(size.x/2,size.y),size),false])
