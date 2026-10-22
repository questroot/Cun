extends Node2D
const Story = preload("res://story_state.gd")
const CohesiveKit = preload("res://ferry_cohesive_kit.gd")
var cohesive_kit = CohesiveKit.new()
const FerryAtmosphere = preload("res://ferry_atmosphere.gd")
var ferry_atmosphere = FerryAtmosphere.new()
const Renderer = preload("res://ferry_world_renderer.gd")
var world_renderer: Node2D
var interface_renderer: Node2D
var world_commands: Array = []
var interface_commands: Array = []

func environment_world() -> Node2D:
	return world_renderer

func record_draw(method: String, arguments: Array, interface: bool = false) -> void:
	var command := {"method":method,"arguments":arguments}
	if interface: interface_commands.append(command)
	else: world_commands.append(command)

const Motion = preload("res://actor_motion.gd")
var player_motion = Motion.new()
var zhou_motion = Motion.new()
var player_motion_view: Dictionary = {}
var zhou_motion_view: Dictionary = {}
var motion_place := ""
const SHENDU_OFFER: Texture2D = preload("res://assets/encounter/shendu_offer.png")
const SHENDU_REST: Texture2D = preload("res://assets/encounter/shendu_rest.png")
const SHENDU_ANCHOR := Vector2(24,21)
const VISUAL := {
	"standing":preload("res://assets/visual_upgrade/zhou_standing.png"),
	"walking":preload("res://assets/visual_upgrade/zhou_walking.png"),
	"dragging":preload("res://assets/visual_upgrade/zhou_dragging.png"),
	"seated":preload("res://assets/visual_upgrade/zhou_seated.png"),
	"stool":preload("res://assets/visual_upgrade/stool.png"),
	"dry":preload("res://assets/visual_upgrade/stone_dry.png"),
	"wet":preload("res://assets/visual_upgrade/stone_wet.png"),
	"edge":preload("res://assets/visual_upgrade/wet_edge.png"),
	"beam":preload("res://assets/visual_upgrade/shelter_beam.png"),
	"post":preload("res://assets/visual_upgrade/shelter_post.png"),
	"awning":preload("res://assets/visual_upgrade/awning_panel.png"),
	"hem":preload("res://assets/visual_upgrade/awning_hem.png"),
	"white":preload("res://assets/visual_upgrade/lamp_white.png"),
	"warm":preload("res://assets/visual_upgrade/lamp_warm.png"),
	"yellow_off":preload("res://assets/visual_upgrade/lamp_yellow_off.png"),
	"yellow_on":preload("res://assets/visual_upgrade/lamp_yellow_on.png"),
	"light":preload("res://assets/visual_upgrade/light_pool.png")
}
var story = Story.new()
var player := Vector2(450, 440)
var face := Vector2.DOWN
var nearest := ""
var paused := false
var modal_open := false
var started := false
var hud: Label
var summary: Label
var message: RichTextLabel
var action_box: VBoxContainer
var overlay: PanelContainer
var modal_body: VBoxContainer
var font: Font
var scene_objects: Array = []
var solids: Array[Rect2] = []
var last_place := ""
var foot_hint: Label
var root_ui: Control
var audio_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var audio_time := 0.0
var sound_enabled := false
var rng := RandomNumberGenerator.new()
var conversation_target := ""
var conversation_response := ""
var comparing_photo := false
var pulling_cart := false
var pulling_awning := false
var boat_approach_offset := 0.0
# Transient walk presentation. Reload/travel resumes the already admitted visit at its destination.
var roof_guest_position := Vector2(635,490)
var roof_guest_walking := false
# Transient presentation only: no saved rules, delayed inputs, or movement ownership.
var presentation_time := 0.0
var presentation_last_player := Vector2.ZERO
var presentation_moving := false
var step_marks: Array = []
var step_distance := 0.0
var action_age := 1.0
var action_position := Vector2.ZERO
var action_ok := true
var action_caption := ""
var pose_blend := 1.0
var last_wait_pose := ""
var details_visible := false
var inventory_visible := false
var inventory_caption: Label
var details_toggle: Button
var primary_action: Button
var response_count := 0
var modal_header: Label
var modal_prose: RichTextLabel
var hud_panel: PanelContainer
var modal_prose_scroll: ScrollContainer
var modal_options_scroll: ScrollContainer
var context_caption: Label
var modal_option_number := 0

# Presentation helpers use backend-owned positions; the same rectangles feed drawing
# and collision. Returning {} preserves original ending/absent-Zhou priorities.
func shelter_wait_scene() -> Dictionary:
	if not started or story.s.place != "shelter": return {}
	if story.s.ending == "flood" or (story.s.phase == "night" and (story.flag("closing_light") or story.flag("closing_release"))): return {}
	var view: Dictionary = story.wait_view()
	return view if view.get("present",false) and (story.s.phase != "epilogue" or story.s.ending == "light") else {}

func rect_description(rect: Rect2) -> Dictionary:
	return {"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y}

func chair_bounds(pos: Vector2) -> Rect2:
	return Rect2(pos-Vector2(18,10),Vector2(36,20))

func zhou_bounds(pos: Vector2) -> Rect2:
	return Rect2(pos-Vector2(12,16),Vector2(24,32))

func zhou_position() -> Vector2:
	var view := shelter_wait_scene()
	return view.zhou if not view.is_empty() else Vector2(455,430)

func cart_position() -> Vector2:
	if story.flag("lane_cart_moved") and not story.s.has("cart_x"): return Vector2(520,260)
	return Vector2(float(story.s.get("cart_x",430.0)),400)

func _ready() -> void:
	add_to_group("cun_play_visible")
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_renderer = Renderer.new()
	world_renderer.name = "FerryWorld"
	add_child(world_renderer)
	_setup_ui()
	interface_renderer = Renderer.new()
	interface_renderer.name = "FerryInterfaceDrawing"
	root_ui.add_child(interface_renderer)
	root_ui.move_child(interface_renderer,0)
	_setup_sound()
	show_title()

## Describes only objects and geometry already drawn on this screen.
func play_visible() -> Dictionary:
	if not started:
		return {"location":"身份选择"}
	var result := {"location":Story.PLACES[story.s.place], "player_screen":{"x":player.x,"y":player.y}, "controls":"WASD/方向键移动，靠近圆环E交互；J记录，I物品，Esc暂停", "modal_open":modal_open}
	if modal_open:
		return result
	var targets: Array = []
	for obj in scene_objects:
		targets.append({"title":obj.title,"x":obj.pos.x,"y":obj.pos.y,"kind":obj.kind})
	var obstacles: Array = []
	for rect in solids:
		obstacles.append({"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y})
	if story.s.place == "house":
		result["visible_basin"] = {"x":(player.x + 15 if story.flag("basin_carried") else (450.0 if story.flag("basin_placed") else 600.0)),"y":(player.y - 8 if story.flag("basin_carried") else (340.0 if story.flag("basin_placed") else 250.0)),"appearance":("端在手上" if story.flag("basin_carried") else ("接住滴水" if story.flag("basin_placed") else "空盆"))}
	if story.s.place == "shelter" and story.s.ending == "flood":
		result["sealed_equipment"] = "灯钟盖着防水布，绳结封存；棚下留有水痕，通向旧阶的口子用横木封住，未见亮灯。"
	elif story.s.place == "shelter":
		result["visible_equipment"] = {"outer_shade":("放在灯旁" if story.flag("shade_off") else "扣在灯上"),"bell":("铜片挂在钟内" if story.flag("tongue_home") else "挂孔空着"),"yellow_lamp":("亮着" if story.flag("yellow_lit") else "未点亮")}
		if story.item("拆下的铜舌"): result["visible_equipment"]["carried"] = "手上铜片"
	if story.item("新灯芯"):
		result["visible_wick"] = {"x":player.x-18,"y":player.y+7,"appearance":"手边纸包灯芯"}
	elif story.flag("wick_kept") and story.s.place == "street":
		result["visible_wick"] = {"x":420,"y":250,"appearance":"柜台干货格留存的灯芯"}
	if story.item("老葛的工具袋"):
		result["visible_toolbag"] = {"x":player.x+20,"y":player.y+8,"appearance":"手提着布袋，袋绳完整"}
	elif story.flag("tool_returned") and story.s.place == "street":
		result["visible_toolbag"] = {"x":650,"y":490,"appearance":"老葛长凳边的工具袋"}
	elif story.s.place == "steps" and not story.flag("tool_returned"):
		result["visible_toolbag"] = {"x":235,"y":355,"appearance":"挂在湿阶低处的布袋"}
	if story.s.place == "shelter":
		result["visible_awning"] = {"x":575,"y":195,"width":160,"lower_edge_y":280-float(story.s.get("awning_pull",0.0))/2.0,"rope_end_y":350+float(story.s.get("awning_pull",0.0)),"appearance":("棚布与系绳仍在，下面已漫水，不能避水" if story.s.ending == "flood" else ("棚绳系在木桩，棚下干处" if story.flag("awning_tied") else ("棚布低边滴水，松绳可向下拉" if story.s.phase != "epilogue" else "低垂棚布与未系绳端")))}
		result["visible_awning_post"] = {"x":700,"y":420,"width":7,"height":35,"appearance":"系棚绳的木桩，拉绳端到桩旁再系"}
		if story.flag("awning_tied") and story.s.ending != "flood":
			result["visible_dry_patch"] = {"x":590,"y":365,"width":135,"height":75,"appearance":"地面勾线标出的棚下干处；仅避棚布滴水，不防漫水"}
	if story.s.place == "arrival" and story.s.ending == "flood":
		result["visible_receiver_table"] = {"x":580,"y":372,"width":110,"height":12,"appearance":"桥头接应干台，两脚支起","sign":"河街住户：被褥｜六码头商铺：工具"}
	if story.flag("evac_pack_carried"):
		result["visible_evac_pack"] = {"x":player.x+8,"y":player.y,"width":34,"height":26,"appearance":"托着扎紧的被褥包"}
		if story.flag("evac_pack_tag_read"): result["visible_evac_pack"]["cloth_tag"] = "河街十二号 · 陈家 · 被褥一包"
	elif story.s.ending == "flood" and story.s.place == "arrival" and story.flag("evac_pack_delivered"):
		result["visible_evac_pack"] = {"x":590,"y":350,"width":34,"height":26,"appearance":"干台上已交接的被褥包"}
	if story.item("旧渡牌"):
		result["visible_ferry_tag"] = {"x":player.x+18,"y":player.y+8,"appearance":"手上携带的木渡牌"}
	if story.s.place == "lane":
		if story.s.ending == "flood": result["visible_dry_lane"] = {"x":95,"y":510,"width":660,"height":60,"appearance":"浅色干路带，西向桥头接应，东向许家门内"}
		var cart := cart_position()
		result["visible_cart"] = {"x":cart.x,"y":cart.y,"width":64,"height":60,"appearance":"空车木板车身，两侧车轮，左侧伸出车把"}
		result["visible_barrier"] = {"x":390,"y":280,"width":80,"height":220,"appearance":"石料围挡中段缺口已通，南侧也可绕行" if story.flag("lane_cart_moved") else "修桥石料围挡，空车堵中段缺口，南侧可绕行"}
	if story.flag("luggage_taken") and not story.flag("luggage_placed"):
		result["carried_luggage"] = {"x":player.x+20,"y":player.y+5,"appearance":"自己提着的棕色行李箱"}
	if story.flag("stock_carried"):
		result["carried_stock"] = {"x":player.x+15,"y":player.y+10,"appearance":"托着湿货箱"}
	if comparing_photo and story.s.place == "steps":
		result["held_photo"] = {"description":"新棚启用前的旧照：水面在上，三道矮阶靠岸，斜柳朝水，木柱上的灯在矮阶左上；照片不含新棚或桥围挡。", "screen_rect":{"x":50,"y":510,"width":210,"height":110}}
	if story.s.place == "steps" and story.s.pollution == 1:
		result["visible_step_water"] = {"x":40,"y":310,"width":780,"height":34,"appearance":"水越过最低一层阶，上一层仍露出；湿面不代表可登船"}
	if story.s.place == "steps" and story.s.phase == "night" and not shore_heard_excerpt().is_empty():
		result["visible_shore_heard"] = {"x":55,"y":185,"width":520,"height":62,"text":shore_heard_excerpt()}
	if story.s.place == "shelter":
		result["visible_shelter_materials"] = {"floor":{"appearance":"湿石地面；材质不是额外障碍" if story.s.ending == "flood" else "湿石地面，棚檐内干石窄带；材质不是额外障碍","bounds":rect_description(Rect2(40,175,780,445))},"beam":rect_description(Rect2(72,180,704,20)),"posts":[rect_description(Rect2(72,184,16,272)),rect_description(Rect2(762,184,16,272))]}
	var wait := shelter_wait_scene()
	if not wait.is_empty():
		var chair: Vector2 = wait.chair
		var zhou: Vector2 = wait.zhou
		result["visible_waiting"] = {"chair":{"x":chair.x,"y":chair.y,"bounds":rect_description(Rect2(chair-Vector2(20,14),Vector2(40,28))),"appearance":"托在手边的矮凳" if wait.carried else "地上的木矮凳"},"zhou":{"x":zhou.x,"y":zhou.y,"bounds":rect_description(Rect2(zhou-Vector2(24,40),Vector2(48,72)).grow(4).merge(Rect2(zhou+Vector2(-64,59-font.get_ascent(17)),Vector2(font.get_string_size("周伯",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x,font.get_height(17))))),"appearance":{"standing":"起身站着","dragging":"双手扶凳，慢慢拖动","walking":"向凳子走去","seated":"收脚坐着，望向河面"}.get(wait.pose,"站着")},"speech":wait.line,"drips":"右棚沿仍滴水" if not story.flag("awning_tied") else "棚沿抬高，水滴落到干处外侧","left_eave":{"x":330,"y":340,"width":110,"height":70,"appearance":"檐内窄处，石面无水滴"}}
		if not wait.line.is_empty(): result["visible_waiting"]["speech_bounds"] = rect_description(waiting_bubble(wait))
		obstacles.append(rect_description(zhou_bounds(zhou)))
		if not wait.carried: obstacles.append(rect_description(chair_bounds(chair)))
		else:
			var foot := player+Vector2(0,22)
			result["visible_chair_drop_outline"] = {"bounds":rect_description(chair_bounds(foot)),"appearance":"浅色落点轮廓" if Rect2(55,190,750,410).has_point(foot) and not Rect2(350,285,100,70).grow(12).has_point(foot) else "赭红落点轮廓，凳脚放不稳"}
	var meet_scene := first_meet_scene()
	if not meet_scene.is_empty(): result["visible_first_meet"] = first_meet_visible(meet_scene)
	result["visible_player_pose"] = {"appearance":"俯身拿放" if not player_motion_view.get("segment","").is_empty() else ("托着物件" if player_carrying() else ("迈步" if player_motion_view.get("moving",false) else "站定")),"facing":{"x":face.x,"y":face.y},"bounds":rect_description(Rect2(player-Vector2(24,24),Vector2(48,54)))}
	if action_age < 0.45: result["visible_action_feedback"]={"text":action_caption,"bounds":rect_description(Rect2(action_position-Vector2(55,52),Vector2(150,85)))}
	result["objects"] = targets
	result["obstacles"] = obstacles
	result["walk_area"] = {"x":40,"y":175,"width":780,"height":445}
	return result

## Shared by drawing and observation: scene-local visible poses, never story flags.
func first_meet_scene() -> Dictionary:
	var view: Dictionary = story.first_meet_view()
	if view.is_empty() or not view.get("active", false) or not view.get("identified", false): return {}
	if story.s.place not in ["steps", "boat"] or story.flag("boat_arrival_pending"): return {}
	var ashore: bool = story.s.place == "steps"
	var quiet: bool = view.get("settled", false)
	var actors: Array = []
	actors.append({"name":"许澄", "pos":Vector2(615,265) if ashore else Vector2(575,370), "gesture":"望向许宁，手停在身侧" if quiet else "朝许宁偏过头，抬手回应私哨"})
	var shendu_resting: bool = quiet or story.item("旧渡牌") or story.flag("ferry_tag_returned")
	actors.append({"name":"沈渡", "pos":Vector2(765,265) if ashore else Vector2(790,365), "resting":shendu_resting, "gesture":"收手留在舷边守船" if shendu_resting else "一手摊向舷边，露出木牌的刻字面"})
	var plaque := Rect2(667,281,110,26) if ashore else Rect2(646,405,110,28)
	var has_plaque: bool = not story.item("旧渡牌") and not story.flag("ferry_tag_taken") and not story.flag("ferry_tag_returned")
	# These are sustained on-screen lines, not a confirmation or a replayed journal event.
	var lines: Array[String] = []
	if not quiet:
		lines.append("许澄：最后那声又破了。")
		lines.append("许澄：屋顶还漏？")
		if has_plaque: lines.append("沈渡：交班的。挂回岸棚。")
	return {"actors":actors, "quiet":quiet, "plaque":plaque if has_plaque else Rect2(), "lines":lines, "speech":Rect2(400,490,405,112) if ashore else Rect2(65,485,350,115)}

func first_meet_visible(scene: Dictionary) -> Dictionary:
	var visible := {"actors":[], "fragments":[]}
	for actor in scene.actors:
		var pos: Vector2 = actor.pos
		var bounds := Rect2(pos+Vector2(-25,-21),Vector2(50,72))
		if actor.name == "沈渡":
			var texture: Texture2D = SHENDU_REST if actor.resting else SHENDU_OFFER
			bounds = Rect2(pos-SHENDU_ANCHOR,texture.get_size())
		var label_size := Vector2(font.get_string_size(actor.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x,font.get_height(17))
		bounds = bounds.merge(Rect2(pos+Vector2(-20,49-font.get_ascent(17)),label_size))
		visible.actors.append({"name":actor.name, "appearance":actor.gesture, "bounds":{"x":bounds.position.x,"y":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y}})
	if not scene.lines.is_empty():
		var speech: Rect2 = scene.speech
		visible.fragments.append({"text":"\n".join(scene.lines), "bounds":{"x":speech.position.x,"y":speech.position.y,"width":speech.size.x,"height":speech.size.y}})
	var plaque: Rect2 = scene.plaque
	if plaque.has_area():
		visible["plaque"] = {"appearance":"舷边木牌，刻字面朝上", "text":"末班交回岸棚", "bounds":{"x":plaque.position.x,"y":plaque.position.y,"width":plaque.size.x,"height":plaque.size.y}}
	if story.s.place == "steps" and not comparing_photo:
		visible["dry_ground"] = {"appearance":"旧阶后方的干石地", "bounds":{"x":70,"y":515,"width":240,"height":90}}
	return visible

func tile_visual(key: String, rect: Rect2) -> void:
	var texture: Texture2D = VISUAL[key]
	for y in range(int(rect.position.y),int(rect.end.y),texture.get_height()):
		for x in range(int(rect.position.x),int(rect.end.x),texture.get_width()):
			var part := Rect2(Vector2(x,y),texture.get_size()).intersection(rect)
			record_draw("draw_texture_rect_region",[texture,part,Rect2(Vector2.ZERO,part.size)])

func visual_quad(key: String, quad: PackedVector2Array) -> void:
	if key in ["awning","hem"]:
		var sway := sin(presentation_time*0.8)*0.7
		quad[2].x += sway
		quad[3].x += sway
	record_draw("draw_polygon",[quad,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),cohesive_kit.textures.awning if key in ["awning","hem"] else VISUAL[key]])

func shelter_ground_tint() -> Color:
	return Color.WHITE # Ambient now belongs exclusively to the world atmosphere.

func draw_shelter_ground() -> void:
	# Base art drawn before titles/actors; retain authoritative dry overlays below.
	if story.s.ending == "flood":
		record_draw("draw_rect",[Rect2(40,175,780,445),Color(0.12,0.32,0.40,0.52)])
	if story.s.ending != "flood":
		tile_visual("dry",Rect2(330,340,110,70))
		tile_visual("edge",Rect2(330,402,110,16))
		if story.flag("awning_tied"):
			tile_visual("dry",Rect2(590,365,135,75))
			tile_visual("edge",Rect2(590,432,135,16))
		# Textured PointLight2D replaces the old painted light pools.

func player_carrying() -> bool:
	return story.flag("basin_carried") or story.flag("stock_carried") or story.flag("evac_pack_carried") or shelter_wait_scene().get("carried",false)

func reset_actor_motion() -> void:
	motion_place = story.s.place
	player_motion_view = player_motion.reset(player,face,player_carrying(),"player")
	presentation_last_player = player
	var wait := shelter_wait_scene()
	zhou_motion_view = zhou_motion.reset(wait.get("zhou",Vector2(455,430)),Vector2.DOWN,false,wait.get("pose","standing"))

func update_actor_motion(delta: float, event: String = "") -> void:
	if motion_place != story.s.place or player_motion_view.is_empty(): reset_actor_motion()
	player_motion_view = player_motion.step(delta,player,face,modal_open or paused,player_carrying(),event,"player")
	var wait := shelter_wait_scene()
	if not wait.is_empty(): zhou_motion_view = zhou_motion.step(delta,wait.zhou,Vector2.ZERO,modal_open or paused,false,"",wait.pose)

func presentation_step(delta: float) -> void:
	presentation_time += minf(delta,0.05)
	action_age += minf(delta,0.05)
	pose_blend = minf(1.0,pose_blend+delta*5.0)
	var distance := player.distance_to(presentation_last_player)
	presentation_moving = distance > 0.05 and distance < 40
	if presentation_moving:
		step_distance += distance
		if step_distance > 22:
			step_distance = 0
			step_marks.append({"at":player+Vector2(0,20),"time":presentation_time})
	presentation_last_player = player
	while not step_marks.is_empty() and presentation_time-step_marks[0].time > 0.8: step_marks.pop_front()
	var wait := shelter_wait_scene()
	if not wait.is_empty() and wait.pose != last_wait_pose:
		last_wait_pose = wait.pose
		pose_blend = 0.0

func draw_presentation_feedback() -> void:
	for mark in step_marks:
		var fade: float = 1.0-(presentation_time-float(mark.time))/0.8
		record_draw("draw_line",[mark.at-Vector2(4,0),mark.at+Vector2(4,0),Color(0.8,0.76,0.62,fade*0.25),2])
	for obj in scene_objects:
		var pointed: bool = get_global_mouse_position().distance_to(obj.pos) < 28
		if (obj.id == nearest or pointed) and player.distance_to(obj.pos) < 96:
			record_draw("draw_arc",[obj.pos,36,0,TAU,36,Color("f2d68b"),2],true)
			record_draw("draw_line",[obj.pos+Vector2(-8,-42),obj.pos+Vector2(0,-36),Color("f2d68b"),2],true)
	if action_age < 0.45:
		var color := Color("d7c6a0") if action_ok else Color("c9987f")
		record_draw("draw_arc",[action_position,18+action_age*12,0,TAU,24,color,2])
		record_draw("draw_string",[font,action_position+Vector2(-50,-34),action_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color],true)

func draw_player_body() -> void:
	if story.s.place == "shelter":
		var direction: String = player_motion_view.get("direction","S")
		if player_carrying() or not player_motion_view.get("segment","").is_empty():
			cohesive_kit.keypose(self,"protagonist_carry_"+("E" if direction == "W" else direction),player+Vector2(0,24),false,direction == "W")
		else: cohesive_kit.actor(self,"protagonist_"+direction,player+Vector2(0,24))
		return # Genuine keyposes, not generated animation frames.
	var segment: String = player_motion_view.get("segment","")
	var lean := 5.0 if segment in ["bend","contact"] else (2.0 if segment == "rise" else 0.0)
	var stride := sin(float(player_motion_view.get("walk_phase",0.0))*TAU)*4.0 if player_motion_view.get("moving",false) else 0.0
	record_draw("draw_line",[player+Vector2(-6,15),player+Vector2(-7,24+stride),Color("554c3e"),4])
	record_draw("draw_line",[player+Vector2(6,15),player+Vector2(7,24-stride),Color("554c3e"),4])
	record_draw("draw_circle",[player+Vector2(0,14),18,Color(0,0,0,0.2)])
	record_draw("draw_rect",[Rect2(player-Vector2(10,3),Vector2(20,24)),Color("bf8f62") if story.s.identity == "xu" else Color("7eb2a0")])
	record_draw("draw_circle",[player-Vector2(0,10-lean),10,Color("ead1ac")])
	record_draw("draw_line",[player-Vector2(0,10-lean),player-Vector2(0,10-lean)+face*8,Color("554c3e"),2])
	if player_carrying() or not segment.is_empty():
		var sockets: Dictionary = player_motion_view.get("hand_sockets",{"left":Vector2(-14,12),"right":Vector2(14,12)})
		record_draw("draw_line",[player+Vector2(-9,1),player+sockets.left,Color("ead1ac"),3])
		record_draw("draw_line",[player+Vector2(9,1),player+sockets.right,Color("ead1ac"),3])
	else: record_draw("draw_line",[player,player+face*20,Color("f1dbad"),3])

func draw_shelter_actors() -> void:
	var wait := shelter_wait_scene()
	var bodies: Array = [{"kind":"table","foot":355.0},{"kind":"player","foot":player.y+24}]
	if not wait.is_empty():
		bodies.append({"kind":"chair","foot":wait.chair.y+8})
		bodies.append({"kind":"zhou","foot":wait.zhou.y+20})
	bodies.sort_custom(func(a,b): return a.foot < b.foot)
	for body in bodies:
		match body.kind:
			"table": cohesive_kit.prop(self,"table",Vector2(400,355),100)
			"player": draw_player_body()
			"chair":
				if wait.wet and not wait.carried: record_draw("draw_arc",[wait.chair+Vector2(0,10),22,0,PI,12,Color("75a5bb"),2])
				cohesive_kit.stool(self,wait.chair)
			"zhou":
				if wait.pose == "standing":
					cohesive_kit.actor(self,"zhou_"+zhou_motion_view.get("direction","S"),wait.zhou+Vector2(0,20))
					continue
				if wait.pose == "seated":
					var clip: String = zhou_motion_view.get("clip","")
					cohesive_kit.keypose(self,"zhou_half_squat_E" if clip == "sit_down" and float(zhou_motion_view.get("phase",1.0))<0.5 else "zhou_seated_E",cohesive_kit.stool_seat(wait.chair),true)
				elif wait.pose == "dragging": cohesive_kit.keypose(self,"zhou_drag_E",wait.zhou+Vector2(0,20))
				else: cohesive_kit.actor(self,"zhou_"+zhou_motion_view.get("direction","S"),wait.zhou+Vector2(0,20))
	if not wait.is_empty():
		if wait.carried:
			var foot := player+Vector2(0,22)
			var legal := Rect2(55,190,750,410).has_point(foot) and not Rect2(350,285,100,70).grow(12).has_point(foot)
			record_draw("draw_rect",[chair_bounds(foot),Color("d7c6a0") if legal else Color("c9987f"),false,2])
	# Same post texture is genuinely split, not drawn twice in full.
	# No duplicate pixel posts: baked margin timber is background only; replacement silhouettes missing.
	var t := float(story.s.get("awning_pull",0.0))/90.0
	visual_quad("hem",PackedVector2Array([Vector2(575,280-t*45),Vector2(735,270-t*45),Vector2(735,278-t*45),Vector2(575,288-t*45)]))
	# Marks and labels stay above actors and narrow foreground.
	for obj in scene_objects:
		record_draw("draw_arc",[obj.pos,33,0,TAU,32,Color(0.7,0.78,0.76,0.45),1.5],true)
		if obj.id == nearest: record_draw("draw_arc",[obj.pos,40,0,TAU,32,Color("f2d68b"),3],true)
		record_draw("draw_string",[font,obj.pos+Vector2(-64,59),obj.title,HORIZONTAL_ALIGNMENT_LEFT,175,17,Color("ebe5d0")],true)

func waiting_bubble(wait: Dictionary) -> Rect2:
	return Rect2(Vector2(clampf(wait.zhou.x-180,55,365),clampf(wait.zhou.y-102,180,500)),Vector2(450,37))

func draw_waiting() -> void:
	var wait := shelter_wait_scene()
	if wait.is_empty(): return
	if not wait.line.is_empty():
		var bubble := waiting_bubble(wait)
		record_draw("draw_line",[wait.zhou-Vector2(0,35),bubble.position+Vector2(20,bubble.size.y),Color("94aaa8"),1],true)
		record_draw("draw_rect",[bubble,Color("25363c")],true)
		record_draw("draw_string",[font,bubble.position+Vector2(10,25),"周伯："+wait.line,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("dccfaf")],true)

func draw_first_meet(scene: Dictionary) -> void:
	if scene.is_empty(): return
	if story.s.place == "steps":
		record_draw("draw_rect",[Rect2(70,515,240,90),Color("77745c"),false,2])
		record_draw("draw_string",[font,Vector2(177,538),"阶后干地",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d4c8a9")],true)
	for actor in scene.actors:
		var pos: Vector2 = actor.pos
		if actor.name == "沈渡":
			# The PNG replaces the entire old body/head/hand pass; never overpaint its face.
			record_draw("draw_texture",[SHENDU_REST if actor.resting else SHENDU_OFFER,pos-SHENDU_ANCHOR])
		else:
			var looking := (player-pos).normalized()
			record_draw("draw_rect",[Rect2(pos+Vector2(-11,3),Vector2(22,27)),Color("7c8073")])
			record_draw("draw_circle",[pos-Vector2(0,10),10,Color("bba58c")])
			record_draw("draw_line",[pos-Vector2(0,10),pos-Vector2(0,10)+looking*8,Color("eee0bd"),3])
			var hand := pos+Vector2(-20,23) if scene.quiet else pos+Vector2(-23,-5)
			record_draw("draw_line",[pos+Vector2(-9,7),hand,Color("bba58c"),4])
			record_draw("draw_circle",[hand,3,Color("ead1ac")])
		record_draw("draw_string",[font,pos+Vector2(-20,49),actor.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e5d6b4")],true)
	var plaque: Rect2 = scene.plaque
	if plaque.has_area():
		record_draw("draw_rect",[plaque,Color("b19a70")],true)
		record_draw("draw_rect",[plaque.grow(-3),Color("6d5b43"),false,1],true)
		record_draw("draw_string",[font,plaque.position+Vector2(7,19),"末班交回岸棚",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("342f29")],true)
	if not scene.lines.is_empty():
		var speech: Rect2 = scene.speech
		record_draw("draw_rect",[speech,Color("25363c")],true)
		for i in range(scene.lines.size()):
			record_draw("draw_string",[font,speech.position+Vector2(12,26+i*30),scene.lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("dccfaf")],true)

func _setup_sound() -> void:
	# Locally generated quiet, continuous river bed: no samples, network, peaks or scares.
	audio_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	audio_player.stream = stream
	audio_player.volume_db = -22.0
	add_child(audio_player)

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if sound_enabled:
		audio_player.play()
		playback = audio_player.get_stream_playback()
	else:
		audio_player.stop()

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_ui)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color","Label",Color("dccfaf"))
	theme.set_color("default_color","RichTextLabel",Color("dccfaf"))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("172830")
	panel_style.border_color = Color("647878")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	theme.set_stylebox("panel","PanelContainer",panel_style)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("354c54") if state in ["hover","focus"] else Color("25363c")
		style.border_color = Color("b7a07b") if state in ["hover","focus"] else Color("556d70")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		theme.set_stylebox(state,"Button",style)
	theme.set_color("font_color","Button",Color("eee4c9"))
	root_ui.theme = theme
	var panel := PanelContainer.new()
	hud_panel = panel
	panel.position = Vector2(865, 12)
	panel.size = Vector2(403, 776)
	root_ui.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size",22)
	hud.add_theme_color_override("font_color",Color("eee4c9"))
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hud)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("c8c4a9"))
	summary.add_theme_font_size_override("font_size",16)
	column.add_child(summary)
	context_caption = Label.new()
	context_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_caption.add_theme_font_size_override("font_size",20)
	context_caption.add_theme_color_override("font_color",Color("eee4c9"))
	column.add_child(HSeparator.new())
	column.add_child(context_caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	inner.add_theme_constant_override("separation",12)
	details_toggle = button(inner,"展开最近经历",func(): details_visible=not details_visible; message.visible=details_visible; details_toggle.text="收起最近经历" if details_visible else "展开最近经历")
	message = RichTextLabel.new()
	message.fit_content = true
	message.custom_minimum_size = Vector2(342, 150)
	message.bbcode_enabled = false
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.hide()
	inner.add_child(message)
	inventory_caption = Label.new()
	inventory_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_caption.hide()
	button(inner,"随身物品 · 展开/收起",func(): inventory_visible=not inventory_visible; inventory_caption.visible=inventory_visible)
	inner.add_child(inventory_caption)
	inner.add_child(HSeparator.new())
	var action_heading := Label.new()
	action_heading.text = "眼前可做"
	action_heading.add_theme_font_size_override("font_size",20)
	inner.add_child(action_heading)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	inner.add_child(action_box)
	column.add_child(HSeparator.new())
	var menu := GridContainer.new()
	menu.columns = 3
	menu.add_theme_constant_override("h_separation",6)
	menu.add_theme_constant_override("v_separation",6)
	column.add_child(menu)
	button(menu, "记录 [J]", show_journal)
	button(menu, "物品 [I]", show_items)
	button(menu, "保存", save_game)
	button(menu, "读取", func(): confirm("读取会替换当前未保存进度，继续？", load_game))
	button(menu, "暂停 [Esc]", show_pause)
	button(menu, "水声 开/关", toggle_sound)
	primary_action = button(root_ui,"[E] 交互",interact)
	primary_action.position = Vector2(595,650)
	primary_action.custom_minimum_size = Vector2(240,55)
	primary_action.size = Vector2(240,55)
	foot_hint = Label.new()
	foot_hint.position = Vector2(22, 716)
	foot_hint.size = Vector2(820, 73)
	foot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_ui.add_child(foot_hint)
	overlay = PanelContainer.new()
	overlay.position = Vector2(175, 85)
	overlay.size = Vector2(760, 620)
	overlay.visible = false
	root_ui.add_child(overlay)
	var mm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: mm.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(mm)
	var modal_column := VBoxContainer.new()
	modal_column.add_theme_constant_override("separation",12)
	mm.add_child(modal_column)
	modal_header = Label.new()
	modal_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_header.add_theme_font_size_override("font_size",26)
	modal_header.add_theme_color_override("font_color",Color("eee4c9"))
	modal_column.add_child(modal_header)
	modal_column.add_child(HSeparator.new())
	modal_prose_scroll = ScrollContainer.new()
	modal_prose_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_prose_scroll.custom_minimum_size.y = 170
	modal_column.add_child(modal_prose_scroll)
	modal_prose = RichTextLabel.new()
	modal_prose.bbcode_enabled = false
	modal_prose.fit_content = true
	modal_prose.scroll_active = false
	modal_prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_prose.custom_minimum_size.x = 665
	modal_prose.add_theme_constant_override("line_spacing",5)
	modal_prose_scroll.add_child(modal_prose)
	var navigation := HBoxContainer.new()
	modal_column.add_child(navigation)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 210
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_options_scroll = sc
	modal_column.add_child(sc)
	var prose_up := button(navigation,"正文 ↑",func(): modal_prose_scroll.scroll_vertical=maxi(0,modal_prose_scroll.scroll_vertical-170))
	var prose_down := button(navigation,"正文 ↓",func(): modal_prose_scroll.scroll_vertical+=170)
	var prose_bar := modal_prose_scroll.get_v_scroll_bar()
	var update_prose_paging := func():
		prose_up.disabled = prose_bar.value <= prose_bar.min_value
		prose_down.disabled = prose_bar.value+prose_bar.page >= prose_bar.max_value
	prose_bar.changed.connect(update_prose_paging)
	prose_bar.value_changed.connect(func(_value: float): update_prose_paging.call())
	update_prose_paging.call()
	var page_up := button(navigation, "向上翻阅", func(): sc.scroll_vertical = maxi(0, sc.scroll_vertical - 180))
	var page_down := button(navigation, "向下翻阅", func(): sc.scroll_vertical += 260)
	var bar := sc.get_v_scroll_bar()
	var update_paging := func():
		page_up.disabled = bar.value <= bar.min_value
		page_down.disabled = bar.value + bar.page >= bar.max_value
		page_up.text = "已在顶部" if page_up.disabled else "向上翻阅"
		page_down.text = "已到底部" if page_down.disabled else "向下翻阅"
	bar.changed.connect(update_paging)
	bar.value_changed.connect(func(_value: float): update_paging.call())
	update_paging.call()
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 12)
	sc.add_child(modal_body)

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if parent == modal_body:
		modal_option_number += 1
		var number := Label.new()
		number.text = "选项 %02d" % modal_option_number
		number.add_theme_font_size_override("font_size",14)
		number.add_theme_color_override("font_color",Color("94aaa8"))
		parent.add_child(number)
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func open_modal(title: String, body: String) -> void:
	clear_children(modal_body)
	modal_open = true
	hud_panel.hide()
	primary_action.hide()
	foot_hint.hide()
	overlay.show()
	modal_option_number = 0
	modal_header.text = title + (" · 回应 %d" % response_count if not conversation_target.is_empty() and not conversation_response.is_empty() else "")
	modal_prose.text = body
	modal_prose_scroll.scroll_vertical = 0
	modal_options_scroll.scroll_vertical = 0

func close_modal() -> void:
	if not started: return
	modal_open = false
	conversation_target = ""
	conversation_response = ""
	paused = false
	overlay.hide()
	hud_panel.show()
	foot_hint.show()
	refresh_ui()

func confirm(text: String, callback: Callable) -> void:
	open_modal("请确认", text)
	button(modal_body, "确认", func(): close_modal(); callback.call())
	button(modal_body, "取消，回到探索", close_modal)

func show_title() -> void:
	open_modal("末班渡船", "俯视探索 · 独立活动首版\n\n在回水埠，一个傍晚，两种处境。选择身份后本次固定；你不必重演既定结局。\n\nWASD / 方向键自由走动，靠近发光圆环后按 E 打开交互，也可点击底部交互按钮。走到路口，交互前往相邻地点。J 记录，I 物品，Esc 暂停。鼠标可点击场地下方方向按钮移动。\n\n探索、交谈、暂停和读记录都不会增加污染。入夜由你主动确认，没有倒计时。危险动作会再次确认，取消没有惩罚。所有图形与水声由本项目自制，无闪烁、跳吓或截图采集。")
	button(modal_body, "许宁 · 返乡者｜离家多年，回来处理旧屋", func(): start_game("xu"))
	button(modal_body, "阿禾 · 学徒｜杂货铺帮工，熟悉这条街的人", func(): start_game("he"))
	button(modal_body, "许宁到埠前段 · 从桥头走回旧屋", func(): start_game("xu"); story.set_flag("arrival_started"); story.change_place("arrival"); player = Vector2(450,440); story.note("班车在桥头放下你和一只行李箱。司机还在栏边收好行李舱的搭扣，抬头问：‘这几年巷口改过，要指一下路吗？’旧屋钥匙在你的口袋里。"); last_place = ""; update_world(); refresh_ui())
	button(modal_body, "读取独立活动存档", load_game)
	button(modal_body, "退出游戏", func(): get_tree().quit())
	refresh_ui()

func start_game(identity: String) -> void:
	comparing_photo = false
	story.fresh(identity)
	started = true
	player = Vector2(story.s.x, story.s.y)
	reset_actor_motion()
	last_place = ""
	close_modal()
	update_world()
	refresh_ui()

func save_game() -> void:
	if not started: return
	story.s.x = player.x
	story.s.y = player.y
	story.save_game()
	refresh_ui()

func load_game() -> void:
	boat_approach_offset = 0.0
	roof_guest_walking = false
	roof_guest_position = Vector2(635,490)
	pulling_cart = false
	pulling_awning = false
	if story.load_game():
		if story.flag("roof_leak_shown"): roof_guest_position = Vector2(565,395)
		comparing_photo = false
		started = true
		last_place = ""
		player = Vector2(story.s.x, story.s.y)
		close_modal()
		update_world()
		if not walkable(player): player = Vector2(450, 440)
		settle_shelter_entry()
		reset_actor_motion()
		refresh_ui()
	else:
		open_modal("读取未完成", story.notice + "\n存档没有被删除或覆盖。")
		button(modal_body, "返回", close_modal if started else show_title)

func show_pause() -> void:
	if not started: return
	paused = true
	open_modal("暂停", "没有全局倒计时。当前所有移动与交互停止。\n存档只属于本活动，不读取或改动原型数据。")
	button(modal_body, "继续探索", close_modal)
	button(modal_body, "保存当前进度", func(): save_game(); show_pause())
	button(modal_body, "读取存档", func(): confirm("读取会替换当前未保存进度，继续？", load_game))
	button(modal_body, "返回身份选择（不自动保存）", func(): confirm("当前未保存进度不会保留。重新选择身份？", func(): started = false; paused = false; show_title()))
	button(modal_body, "退出程序（不自动保存）", func(): confirm("退出游戏？如需保存请先取消，选择保存。", func(): get_tree().quit()))

func show_journal() -> void:
	if not started: return
	var text := "证据只记录此身份已实际获取的信息；不自动继承另一身份的见闻。\n\n"
	for id in story.s.evidence: text += "• " + Story.EVIDENCE[id] + "\n\n"
	text += "—— 行动与经历 ——\n"
	for line in story.s.journal: text += "• " + str(line) + "\n\n"
	open_modal("记录本", text)
	button(modal_body, "返回探索", close_modal)

func show_items() -> void:
	if not started: return
	var text := "携带：" + ("、".join(story.s.items) if not story.s.items.is_empty() else "无")
	if story.item("铜哨"): text += "\n\n铜哨：半只旧哨，与你随身的钥匙系在一起。它不是驱邪物。"
	if story.item("新灯芯"): text += "\n\n新灯芯：陶记包好的货，纸上写着周伯的名字。"
	if story.item("手提黄灯"): text += "\n\n手提黄灯：陶婶借给你的，只照亮等待的人。你答应天亮归还。"
	if story.item("拆下的铜舌"): text += "\n\n铜片：刚从灯罩里取出来，边缘留着新断口。"
	if story.flag("basin_carried"): text += "\n\n手上端着旧搪瓷盆。"
	text += "\n\n物品的使用按钮只在相应目标附近出现。打开背包不会隔空施加结果。"
	open_modal("物品", text)
	button(modal_body, "返回探索", close_modal)

## Direct manipulation uses the same location-checked rules as keyboard accessibility.
func handle_luggage(put_down: bool) -> void:
	close_modal()
	story.set_flag("luggage_taken")
	story.s.flags["luggage_placed"] = put_down
	story.note("许宁把箱子竖放在门内干处。文件留在箱里，钥匙还在自己口袋。" if put_down else "许宁抠掉箱轮里的碎石，拎起自己的行李。箱里是换洗衣服和处理旧屋的文件。")
	last_place = ""
	update_world()
	refresh_ui()

func try_world_click(point: Vector2) -> bool:
	if not started or modal_open or paused or story.s.left: return false
	if story.s.phase == "epilogue": return false
	if story.s.place == "arrival" and not story.flag("luggage_taken") and point.distance_to(Vector2(305,360)) < 28 and player.distance_to(Vector2(305,360)) < 82:
		handle_luggage(false); return true
	if story.s.place == "house" and story.flag("luggage_taken") and point.distance_to(Vector2(590,510)) < 28 and player.distance_to(Vector2(590,510)) < 82:
		handle_luggage(not story.flag("luggage_placed")); return true
	if story.s.place == "house":
		if story.flag("drawer_open") and point.distance_to(Vector2(350,375)) < 24 and player.distance_to(Vector2(350,375)) < 82:
			read_handover_response(); return true
		if not story.flag("drawer_open") and point.distance_to(Vector2(320,340)) < 27 and player.distance_to(Vector2(320,340)) < 82:
			do_action("drawer_open")
			show_current_response(object_title("drawer"))
			return true
	if story.s.place == "street" and story.s.phase == "night" and story.s.pollution == 1 and not story.flag("stock_dried"):
		if point.distance_to(Vector2(420,300)) < 28 and player.distance_to(Vector2(420,300)) < 82 and story.flag("stock_carried"):
			do_action("move_wet_stock"); return true
		if point.distance_to(Vector2(365,365)) < 28 and player.distance_to(Vector2(365,365)) < 82:
			do_action("stock_put_back" if story.flag("stock_carried") else "stock_take"); return true
	if comparing_photo and story.s.place == "steps":
		if point.distance_to(Vector2(460,295)) < 30 and player.distance_to(Vector2(460,295)) < 82:
			story.note("这块石上磨的是缆绳槽，没有挂灯木柱的方形底脚。系船的位置能帮你定位河边，却还不能指出照片里的灯原来在哪。"); refresh_ui(); return true
		if point.distance_to(Vector2(485,405)) < 30 and player.distance_to(Vector2(485,405)) < 82:
			do_action("socket_view")
			if story.act("photo_shift"): comparing_photo = false
			refresh_ui(); return true
	if story.s.place == "steps":
		for mark in [{"pos":Vector2(165,445),"action":"root_view"},{"pos":Vector2(330,470),"action":"stairs_view"},{"pos":Vector2(485,405),"action":"socket_view"}]:
			if point.distance_to(mark.pos) < 30 and player.distance_to(mark.pos) < 82:
				do_action(mark.action)
				return true
	if story.s.place == "street" and story.s.identity == "he" and story.item("新灯芯") and point.distance_to(Vector2(420,235)) < 35 and player.distance_to(Vector2(420,235)) < 82:
		confirm("把这卷尚未送出的灯芯留在陶记干货格，并由你亲口向周伯解释？这不会替他决定今晚怎样等候。", func(): do_action("wick_keep"))
		return true
	if story.s.place == "steps" and point.distance_to(Vector2(235,355)) < 35 and player.distance_to(Vector2(235,355)) < 82:
		if not story.flag("tool_returned") and not story.item("老葛的工具袋"):
			do_action("tool_retrieve")
			return true
	if story.s.place == "street" and story.item("老葛的工具袋") and point.distance_to(Vector2(620,470)) < 35 and player.distance_to(Vector2(620,470)) < 82:
		do_action("tool_return")
		return true
	if story.s.place == "shelter":
		var wait := shelter_wait_scene()
		if not wait.is_empty() and story.s.ending.is_empty():
			if wait.carried and point.distance_to(player+Vector2(0,22)) < 35:
				do_action("chair_place"); return true
			if point.distance_to(wait.zhou-Vector2(0,23)) < 14 and player.distance_to(wait.zhou) < 96:
				nearest="zhou"; interact(); return true
			if not wait.carried and chair_bounds(wait.chair).grow(4).has_point(point) and player.distance_to(wait.chair) <= 64:
				do_action("chair_take"); return true
		if player.distance_to(point) > 82: return false
		if point.distance_to(Vector2(250, 360)) < 35 and story.flag("consent"):
			if not story.flag("shade_off"): do_action("remove_shade")
			elif not story.flag("tongue_taken"): do_action("retrieve_tongue")
			else: return false
			return true
		if point.distance_to(Vector2(550, 240)) < 35 and story.item("拆下的铜舌"):
			do_action("install_tongue")
			return true
		if point.distance_to(Vector2(620, 390)) < 35 and story.flag("consent"):
			if story.s.phase == "night" and story.flag("shade_off") and story.flag("tongue_home"):
				confirm("在等候的位置点亮黄灯，让钟声送夜船归岸？这会开始收束当晚的岸边场景，但不会立刻跳到次日；仍可先取消。", func(): do_action("light_yellow"))
			else: do_action("light_yellow")
			return true
		return false
	if story.s.place != "house": return false
	if story.flag("basin_carried"):
		if player.distance_to(point) > 82: return false
		if point.distance_to(Vector2(450, 340)) < 35:
			do_action("basin_place")
			return true
		if point.distance_to(Vector2(130, 300)) < 35:
			do_action("basin_wrong")
			return true
	elif player.distance_to(Vector2(450,340) if story.flag("basin_placed") else Vector2(600,250)) < 82 and point.distance_to(Vector2(450,340) if story.flag("basin_placed") else Vector2(600,250)) < 35:
		if not story.flag("heard_drip"): story.act("roof_listen")
		do_action("basin_take")
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if try_world_click(event.position): get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if modal_open and started: close_modal()
		else: show_pause()
	elif not modal_open and started:
		match event.keycode:
			KEY_E: interact()
			KEY_J: show_journal()
			KEY_I: show_items()
			KEY_1: river_in_place("whistle_short")
			KEY_2: river_in_place("whistle_long")
			KEY_3: river_in_place("whistle_listen")
			KEY_4: river_in_place("whistle_reset")

func _process(delta: float) -> void:
	if sound_enabled and playback != null:
		for i in range(playback.get_frames_available()):
			audio_time += 1.0 / 22050.0
			var wave := sin(audio_time * 130.0) * 0.05 + sin(audio_time * 173.0) * 0.025 + rng.randf_range(-0.018, 0.018)
			playback.push_frame(Vector2(wave, wave))
	ferry_atmosphere.update(self)
	if started: update_actor_motion(delta)
	if not started or modal_open or paused or story.s.left: return
	presentation_step(delta)
	# World geometry rebuilds clear nearest; compare against the frame's actual
	# interaction context, not that temporary empty value, before rebuilding UI.
	var previous := nearest
	var previous_title := object_title(nearest)
	if story.s.place == "shelter":
		var before_wait := shelter_wait_scene()
		story.s.x = player.x
		story.s.y = player.y
		if not before_wait.is_empty() and before_wait.stage == "idle" and story.s.ending.is_empty(): story.act("wait_offer")
		story.wait_step(delta,player,{"rope":pulling_awning,"rects":[Rect2(350,285,100,70)]})
		var after_wait := shelter_wait_scene()
		if not after_wait.is_empty():
			# Updating geometry must not churn button identity on every NPC step.
			last_place = ""
			update_world()
			if before_wait.is_empty() or before_wait.pose != after_wait.pose or before_wait.carried != after_wait.carried or before_wait.line != after_wait.line: refresh_ui()
	if story.s.place == "steps" and story.s.phase == "night" and story.flag("boat_arrival_pending") and not story.flag("released"):
		if boat_approach_offset <= 0: boat_approach_offset = 75.0
		boat_approach_offset = maxf(0.0,boat_approach_offset-minf(delta,0.05)*65)
		if boat_approach_offset <= 0:
			story.s.flags["boat_arrival_pending"] = false
			story.note("船身挨近石阶，系缆绳落在岸侧。你仍站在干地，船上的人没有替你决定是否靠近。")
		last_place = ""
		update_world()
		if boat_approach_offset <= 0: refresh_ui()
	if roof_guest_walking:
		if story.s.place != "house":
			roof_guest_walking = false
			roof_guest_position = Vector2(635,490)
		else:
			roof_guest_position = roof_guest_position.move_toward(Vector2(635,490),minf(delta,0.05)*95.0)
			if roof_guest_position.distance_to(Vector2(635,490)) < 0.1: roof_guest_walking = false
			last_place = ""
			update_world()
	if story.s.place == "house" and story.flag("roof_guiding") and not story.flag("roof_inspected"):
		if not story.flag("roof_leak_shown"):
			var guest_next := roof_guest_position.move_toward(player+Vector2(55,25),minf(delta,0.05)*110.0)
			if walkable(guest_next): roof_guest_position = guest_next
			elif walkable(Vector2(guest_next.x,roof_guest_position.y)): roof_guest_position.x = guest_next.x
			elif walkable(Vector2(roof_guest_position.x,guest_next.y)): roof_guest_position.y = guest_next.y
			if player.distance_to(Vector2(510,370)) < 65 and roof_guest_position.distance_to(player) < 95:
				story.s.x = player.x
				story.s.y = player.y
				story.act("roof_show")
		last_place = ""
		update_world()
	if story.s.place == "lane":
		var observed_level := ""
		if player.distance_to(Vector2(200,300)) < 48 and not story.flag("lane_old_level"): observed_level = "lane_old_level"
		elif player.distance_to(Vector2(650,300)) < 48 and not story.flag("lane_today_level"): observed_level = "lane_level_revisit"
		if not observed_level.is_empty():
			story.act(observed_level)
			refresh_ui()
		elif player.distance_to(Vector2(650,300)) < 48:
			if story.act("lane_level_revisit"): refresh_ui()
	if story.s.place == "shelter" and story.flag("awning_tied") and not story.flag("shelter_dry_stood") and not pulling_awning:
		if Rect2(590,365,135,75).has_point(player):
			story.s.x = player.x
			story.s.y = player.y
			if story.act("shelter_dry_stand"): refresh_ui()
	if story.s.place == "steps" and story.s.phase == "night" and not story.flag("released"):
		for listening in [{"id":"river_willow_listen","at":Vector2(165,445)},{"id":"river_stair_listen","at":Vector2(330,470)}]:
			if not story.flag(listening.id) and player.distance_to(listening.at) < 55:
				story.s.x = player.x
				story.s.y = player.y
				if story.act(listening.id): refresh_ui()
	var movement := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1
	# Large bottom map controls also allow a mouse-only playthrough.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse := get_global_mouse_position()
		if mouse.y > 650 and mouse.y < 705:
			if mouse.x > 280 and mouse.x < 345: movement.x = -1
			elif mouse.x > 350 and mouse.x < 415: movement.y = -1
			elif mouse.x > 420 and mouse.x < 485: movement.y = 1
			elif mouse.x > 490 and mouse.x < 555: movement.x = 1
	if movement != Vector2.ZERO:
		face = movement.normalized()
		move_player(face * minf(delta, 0.05) * 200.0)
	# Only actual presence in this screen's dry ground ends the encounter.
	# Board -> back is not itself a retreat, nor is any modal/menu action.
	if story.s.place == "steps" and Rect2(70,515,240,90).has_point(player):
		var meet: Dictionary = story.first_meet_view()
		if meet.get("active",false) and meet.get("identified",false) and not meet.get("settled",false):
			story.s.x = player.x
			story.s.y = player.y
			if story.act("meet_retreat"): refresh_ui()
	nearest = ""
	var distance := 96.0
	for obj in scene_objects:
		var d := player.distance_to(obj.pos)
		if obj.id == "wait_chair" and d > 64: continue
		if d < distance or (obj.id == "wait_chair" and d <= 64):
			distance = d
			nearest = obj.id
	if previous != nearest or previous_title != object_title(nearest): refresh_ui()
	queue_redraw()

func move_player(offset: Vector2) -> void:
	if pulling_awning and story.s.place == "shelter":
		var amount := clampf(float(story.s.get("awning_pull",0.0))+maxf(offset.y,0.0),0,90)
		var displacement := amount-float(story.s.get("awning_pull",0.0))
		if not walkable(player+Vector2(0,displacement)): return
		story.s["awning_pull"] = amount
		player.y += displacement
		story.s.x = player.x
		story.s.y = player.y
		last_place = ""
		update_world()
		return
	if pulling_cart and story.s.place == "lane":
		var x := clampf(cart_position().x + minf(offset.x,0.0)*0.5,250,430)
		var displacement := x-cart_position().x
		if not walkable(player + Vector2(displacement,0)): return
		story.s["cart_x"] = x
		player.x += displacement
		if x <= 340: story.set_flag("lane_cart_moved")
		story.s.x = player.x
		story.s.y = player.y
		last_place = ""
		update_world()
		return
	var next := player + Vector2(offset.x, 0)
	if walkable(next): player = next
	next = player + Vector2(0, offset.y)
	if walkable(next): player = next
	story.s.x = player.x
	story.s.y = player.y

func walkable(pos: Vector2) -> bool:
	if not Rect2(40, 175, 780, 445).has_point(pos): return false
	for r in solids:
		if r.grow(13).has_point(pos): return false
	var wait := shelter_wait_scene()
	if not wait.is_empty():
		for body in [zhou_bounds(wait.zhou),chair_bounds(wait.chair) if not wait.carried else Rect2()]:
			if not body.has_area() or not body.grow(13).has_point(pos): continue
			# Legacy entrances can overlap the old fixed seat. Allow walking out,
			# never further in; do not teleport either participant to resolve it.
			if body.grow(13).has_point(player) and pos.distance_to(body.get_center()) > player.distance_to(body.get_center()): continue
			return false
	return true

func add_object(id: String, title: String, pos: Vector2, kind: String = "thing") -> void:
	scene_objects.append({"id":id, "title":title, "pos":pos, "kind":kind})

func update_world() -> void:
	if not started: return
	if last_place == story.s.place: return
	last_place = story.s.place
	nearest = ""
	scene_objects.clear()
	solids.clear()
	match story.s.place:
		"arrival":
			if story.s.ending == "flood":
				add_object("evac_receiver","桥头接应的人与干台",Vector2(570,330),"npc")
				add_object("departure","沿安全桥路离开渡口",Vector2(300,510),"gate")
				add_object("lane_gate","沿干路返回旧屋与街口",Vector2(745,500),"gate")
			else:
				add_object("driver", "收行李舱搭扣的班车司机",Vector2(570,330),"npc")
				add_object("luggage", "桥栏边自己的行李箱" if not story.flag("luggage_taken") else "桥栏边的空位", Vector2(305,360))
				add_object("lane_gate", "沿修桥绕行巷去旧屋", Vector2(745,500), "gate")
		"lane":
			solids.append(Rect2(390,280,80,80))
			solids.append(Rect2(390,440,80,60))
			var cart := cart_position()
			solids.append(Rect2(cart-Vector2(32,30),Vector2(64,60)))
			add_object("old_level", "桥墩：旧年份的干褐洪痕",Vector2(200,300))
			add_object("today_level", "施工水尺："+story.lane_water_description(),Vector2(650,300))
			add_object("lane_cart", "缺口外停住的空手推车" if story.flag("lane_cart_moved") else "卡在围挡缺口的空手推车",cart-Vector2(80,0))
			add_object("arrival_gate", "返回桥头落客点",Vector2(100,510),"gate")
			add_object("house_gate", "许家旧屋门口",Vector2(745,320),"gate")
			if story.s.ending == "flood": add_object("street_gate","公共干路回街口",Vector2(745,550),"gate")
		"street":
			if story.s.ending == "flood" and not story.flag("evac_pack_carried") and not story.flag("evac_pack_delivered"): add_object("evac_pack","老葛扎好的邻居被褥包",Vector2(650,470))
			solids.append(Rect2(145, 190, 235, 95))
			if story.s.pollution == 1:
				add_object("wet_stock", "干台上的湿货箱" if story.flag("stock_dried") else ("陶婶摊开的湿货" if story.s.phase == "epilogue" else ("货箱原来放的位置" if story.flag("stock_carried") else "门边被水浸到的货箱")), Vector2(420,300) if story.flag("stock_dried") or story.s.phase == "epilogue" else Vector2(365,365))
			if story.s.pollution == 1 and story.s.phase == "night" and not story.flag("stock_dried"): add_object("dry_stock", "柜台边的干台", Vector2(420,300))
			add_object("tao", "陶婶", Vector2(260, 330), "npc")
			add_object("ledger", "铺内账本", Vector2(420, 235))
			if not story.roof_visit_active():
				add_object("ge", "围挡旁补鞋的老葛", Vector2(620, 470), "npc")
			else:
				add_object("ge_visit_note", "收起的鞋摊·纸条：按约去许家看漏点", Vector2(620,470))
			if story.flag("street_evening_seen") and not story.flag("shoe_collected") and story.s.phase == "dusk": add_object("shoe_parcel", "等主人来取的鞋包", Vector2(675,460))
			add_object("shelter_gate", "去候船棚", Vector2(750, 385), "gate")
			add_object("house_gate", "去许家旧屋", Vector2(100, 440), "gate")
			if story.s.ending == "flood": add_object("lane_gate","沿公共干路去桥头接应",Vector2(100,550),"gate")
			add_object("departure", "街口·离开体验", Vector2(450, 570), "gate")
		"house":
			solids.append(Rect2(220, 190, 200, 105))
			if story.flag("arrival_started") or story.s.ending == "flood":
				add_object("lane_gate", "沿绕行巷返回桥头", Vector2(100,510), "gate")
				if story.flag("luggage_taken"): add_object("luggage_place", "门内放自己行李的位置" if not story.flag("luggage_placed") else "门内自己的行李箱",Vector2(590,510))
			add_object("paper", "旧桌·私人物品", Vector2(320, 340))
			if story.flag("drawer_open"): add_object("handover", "旧交接单与今日附记" if story.flag("handover_updated") else "下层抽屉里的折单", Vector2(350,375))
			add_object("roof", "屋梁与旧搪瓷盆", Vector2(600, 250))
			if story.flag("roof_inspected"): add_object("roof_note", "桌边的两项修屋工序纸",Vector2(400,375))
			if story.roof_visit_active():
				if story.flag("roof_guest_admitted") or story.flag("roof_inspected"):
					add_object("roof_ge", "正擦净鞋底走向屋内干处的老葛" if roof_guest_walking else (("已看清漏点、等你让开勘看的老葛" if story.flag("roof_leak_shown") else "跟你查看桌脚漏点的老葛") if story.flag("roof_guiding") and not story.flag("roof_inspected") else ("按约来勘看的老葛" if not story.flag("roof_inspected") else "留下分项工序的老葛")),roof_guest_position if roof_guest_walking or story.flag("roof_guiding") else Vector2(635,490),"npc")
				else:
					add_object("roof_ge_door", "门口等你招呼的老葛",Vector2(500,550),"npc")
			if story.flag("roof_guiding") and not story.flag("roof_leak_shown") and not story.flag("roof_inspected"): add_object("roof_guide_spot","带老葛查看漏点的桌脚干处",Vector2(510,370))
			add_object("drip", "桌脚的新湿痕", Vector2(450, 340))
			add_object("watermark", "墙下的旧水印", Vector2(130, 300))
			if story.s.identity == "he": add_object("xu", "许宁", Vector2(550, 405), "npc")
			add_object("old_photo", "窗边的旧渡口照片", Vector2(695,230))
			add_object("street_gate", "回杂货铺 / 街口", Vector2(450, 580), "gate")
		"shelter":
			add_object("ferry_tag_hook","告示旁挂回的旧渡牌" if story.flag("ferry_tag_returned") else "告示旁的空木钩",Vector2(175,320))
			if story.s.phase != "epilogue": add_object("awning_rope","系稳后不再滴水的棚绳" if story.flag("awning_tied") else "滴水棚布垂下的松绳",Vector2(690,350+float(story.s.get("awning_pull",0.0))))
			solids.append(Rect2(350, 285, 100, 70))
			add_object("timetable", "旧通航告示", Vector2(125, 250))
			add_object("lamp", "卸下白罩的旧灯" if story.flag("shade_off") else "白罩船灯", Vector2(250, 360))
			add_object("bell", "铜舌归位的钟" if story.flag("tongue_home") else "缺铜舌的钟", Vector2(550, 240))
			add_object("inscription", "黄灯底座", Vector2(620, 390))
			if story.s.phase == "night" and (story.flag("closing_light") or story.flag("closing_release")):
				add_object("zhou_absent", "周伯留下的空凳（他去了旧阶）", Vector2(455,430))
			elif story.s.phase != "epilogue" or story.s.ending == "light": add_object("zhou", "周伯", zhou_position(), "npc")
			else: add_object("morning", "渡口次日告示", Vector2(455, 430))
			add_object("street_gate", "回街口", Vector2(95, 570), "gate")
			add_object("steps_gate", "去旧石阶", Vector2(750, 570), "gate")
			var wait := shelter_wait_scene()
			if not wait.is_empty() and not wait.carried and story.s.ending.is_empty(): add_object("wait_chair","矮凳 · 近处E抬起",wait.chair)
		"steps":
			add_object("old_root", "斜柳老根", Vector2(165,445))
			add_object("old_stairs", "三道矮阶", Vector2(330,470))
			add_object("post_socket", "石缝里的方槽", Vector2(485,405))
			add_object("mooring", "系缆石旁·河声与岸上交谈" if story.s.phase == "night" else "系缆石", Vector2(460, 295))
			if story.flag("closing_release") and story.s.phase == "night": add_object("release_scene", "正收缆绳的沈渡与岸上的人", Vector2(590,410), "npc")
			if story.flag("closing_light") and story.s.phase == "night": add_object("closing_zhou", "提着钟柄等你的周伯", Vector2(590, 410), "npc")
			if not story.flag("tool_returned") and not story.item("老葛的工具袋"): add_object("toolbag", "湿阶低处的布袋", Vector2(235, 355))
			if story.s.phase == "night": add_object("ship", "已离岸的夜船" if story.flag("released") else ("正靠近旧阶的夜船" if story.flag("boat_arrival_pending") else "靠岸夜船"), Vector2(700, 245) if story.flag("released") else Vector2(700,295-boat_approach_offset))
			else: add_object("morning", "河面与普通渡船", Vector2(700, 295))
			add_object("shelter_gate", "回候船棚", Vector2(115, 565), "gate")
		"boat":
			if not story.flag("ferry_tag_returned"): add_object("ferry_tag","舷边可放回木牌的位置" if story.item("旧渡牌") else "舷边刻着字的木渡牌",Vector2(685,420))
			solids.append(Rect2(260, 195, 240, 80))
			add_object("voices", "旧物与河声", Vector2(570, 335))
			add_object("back", "返回旧石阶（安全）", Vector2(450, 570), "gate")
	if story.s.ending == "flood":
		if story.s.place == "shelter":
			solids.append(Rect2(705,522,83,48))
			scene_objects.clear()
			add_object("evacuation", "撤离后封起的灯钟与停航告示", Vector2(455,430))
			add_object("street_gate", "沿干路回街口", Vector2(95,570), "gate")
		elif story.s.place == "street":
			for obj in scene_objects:
				if obj.id == "ge": obj.title = "帮邻居扎撤离包的老葛"
				if obj.id == "tao": obj.title = "收存受潮账货的陶婶"
	queue_redraw()

func river_in_place(id: String) -> void:
	if not started or modal_open or paused or story.s.phase != "night" or story.s.place != "steps": return
	if player.distance_to(Vector2(460,295)) >= 96 or story.flag("released"): return
	do_action(id)

func refresh_ui() -> void:
	clear_children(action_box)
	if not started:
		hud.text = "末班渡船\n独立活动 · 故事驱动探索"
		summary.text = "选择一个身份，亲自走到线索旁。"
		return
	hud.text = "%s\n%s · %s" % [story.who(), {"dusk":"傍晚", "night":"入夜", "epilogue":"次日尾声"}[story.s.phase], Story.PLACES[story.s.place]]
	summary.text = "侵入 %d / 2　证据 %d 项\n%s" % [story.s.pollution, story.s.evidence.size(), (story.ending_name() if not story.s.ending.is_empty() else "无倒计时 · 调查/普通交谈不增加侵入")]
	if story.flag("closing_release") and story.s.phase == "night":
		summary.text += "\n" + ("船已离岸；可再陪站，或确认迎天明。" if story.flag("released") else "答复已带回；在旧阶看沈渡自己解缆。")
	if story.flag("closing_light") and story.s.phase == "night":
		summary.text += "\n" + ("周伯已敲钟；可再陪站，或由你确认迎接天明。" if story.flag("closing_rang") else "黄灯已亮；周伯在旧阶等你，一起把钟敲完。")
	context_caption.text = "现场 · " + ("把矮凳放在脚前" if shelter_wait_scene().get("carried",false) else ("握绳退拉 · E系住或松手" if pulling_awning else (object_title(nearest) if not nearest.is_empty() else "走近物件或人物")))
	message.text = story.notice
	inventory_caption.text = "随身：" + ("、".join(story.s.items) if not story.s.items.is_empty() else "无")
	primary_action.visible = not modal_open and not story.s.left
	var carried_wait := shelter_wait_scene()
	primary_action.disabled = nearest.is_empty() and not pulling_cart and not pulling_awning and not carried_wait.get("carried",false)
	primary_action.text = "[E] 放下矮凳" if carried_wait.get("carried",false) else ("[E] 系住 / 松手" if pulling_awning else ("[E] 松开车把" if pulling_cart else ("[E] " + object_title(nearest) if not nearest.is_empty() else "走近物件或人物")))
	foot_hint.text = "WASD / 方向键移动　E 交互　J 记录　I 物品　Esc 暂停\n" + ("靠近「%s」· E 或点击底部交互按钮" % object_title(nearest) if not nearest.is_empty() else "走近有圆环的物件或人物，再交互。鼠标可按住下方方向键。")
	var wait := shelter_wait_scene()
	if not wait.is_empty() and story.s.ending.is_empty():
		foot_hint.text += "\n" + ("托着矮凳 · E或点击脚前轮廓原地放下；可继续走动。" if wait.carried else "走近矮凳按E抬起；棚绳仍可照常握住后向下退拉。")
	if pulling_cart and story.s.place == "lane": foot_hint.text = "正握住车把 · 左方向键逐步拉出 · E或底部交互按钮松手\n车停在哪就在哪挡路；松手后可自由走动。"
	if story.s.place == "house" and story.s.phase != "epilogue" and (player.distance_to(Vector2(600,250)) < 100 or player.distance_to(Vector2(450,340)) < 100 or story.flag("basin_carried")): foot_hint.text += "\n鼠标：走近盆点击拿起，再走近湿痕点击放下（也可E交互）。"
	if story.s.place == "shelter" and story.flag("consent") and story.s.phase != "epilogue" and not story.flag("closing_light") and not story.flag("closing_release"): foot_hint.text += "\n可走近后直接点击灯罩、铜钟或黄灯操作；E交互仍可用。"
	if story.s.phase != "epilogue" and story.flag("ge_met") and not story.flag("tool_returned"):
		if story.s.place == "steps" and not story.item("老葛的工具袋"): foot_hint.text += "\n老葛说的布袋在湿阶低处；走近后点击，用竹竿挑回，不必涉水（E也可）。"
		if story.s.place == "street" and story.item("老葛的工具袋"): foot_hint.text += "\n带回了工具袋，走近老葛点击交还，或按E交谈。"
	if story.s.place == "street" and story.item("新灯芯") and story.s.phase != "epilogue": foot_hint.text += "\n灯芯可送给周伯，或走近账本点击确认留店；决定由阿禾自己解释。"
	# Match interact() ownership: held props/rope take E before the nearest NPC.
	if not wait.is_empty() and wait.carried:
		foot_hint.text = "WASD / 方向键移动　J 记录　I 物品　Esc 暂停\n托着矮凳 · E把矮凳放在脚前，或点击脚前轮廓；可继续走动。"
	elif pulling_awning and story.s.place == "shelter":
		foot_hint.text = "正握住棚绳 · 向下退拉棚布\nE系住或松手；绳端未到木桩时可松手再续。"
	if story.s.left:
		button(action_box, "本活动首版到此 · 返回身份选择", func(): started = false; show_title())
		button(action_box, "退出游戏", func(): get_tree().quit())
		return
	if not wait.is_empty() and wait.carried:
		pass # The persistent bottom primary_action is the single E control.
	elif not nearest.is_empty():
		pass
	if story.s.phase == "dusk" and story.s.place not in ["arrival", "lane"]:
		button(action_box, "准备好了 · 进入入夜", func(): confirm("进入入夜？人物将开始赴约；必要线索和工具仍可补查。没有自动倒计时。", func(): do_action("night")))
	if story.s.phase == "night" and story.s.place == "steps" and nearest == "mooring" and not story.flag("released"):
		if not story.flag("river_heard"):
			button(action_box, "先站在干阶听河声", func(): river_in_place("listen_river"))
		elif story.s.identity == "xu" and story.item("铜哨") and not story.flag("xu_identified"):
			button(action_box, "铜哨 · 短音 [1]", func(): river_in_place("whistle_short"))
			button(action_box, "铜哨 · 长音 [2]", func(): river_in_place("whistle_long"))
			button(action_box, "停下听回应 [3]", func(): river_in_place("whistle_listen"))
			button(action_box, "放下重来 [4]", func(): river_in_place("whistle_reset"))
	if comparing_photo:
		button(action_box, "收起照片，暂不比较", func(): comparing_photo = false; story.note("你把照片收好，观察仍记着，不必这次就下结论。"); refresh_ui())
		foot_hint.text += "\n照片在手边：走近后点击自己选的参照位置。"
	button(action_box, "当前目标 / 操作提示", show_help)

func object_title(id: String) -> String:
	for obj in scene_objects:
		if obj.id == id: return obj.title
	return ""

func show_help() -> void:
	if story.flag("closing_release") and story.s.phase == "night":
		open_modal("答复已到岸上", "缆绳应由沈渡自己解，不必再找线索或改灯。旧阶上可以走近他与周伯所在的位置，继续眼前的事。\n" + ("船已离岸。还可以陪岸上的人站一会儿，再确认迎接天明。" if story.flag("released") else "他还没有收回缆绳。你留在干阶上看他做完即可，不必登船。"))
		button(modal_body, "回到岸上", close_modal)
		return
	if story.flag("closing_light") and story.s.phase == "night":
		open_modal("当晚还没结束", "黄灯已经亮了，装置不必再重做。\n" + ("周伯已在旧阶敲过钟。可以继续在岸上听一会儿、同他说话，再由你选择‘今夜到这里，迎接天明’。没有倒计时。" if story.flag("closing_rang") else "周伯去了旧石阶，等你在干阶上陪他把钟敲完。从候船棚东侧路口过去，走近他再交互；不必登船或再找物品。"))
		button(modal_body, "回到岸上", close_modal)
		return
	open_modal("操作与当前目标", "走近圆环物件或人物，按E或点击交互。用WASD/方向键或按住地图下方方向按钮走动。调查、普通交谈和暂停都不会让侵入升级。\n\n傍晚：了解这里的生活，亲眼看看渡口有什么变化。准备好才确认入夜。\n入夜：你可以介入灯的信号，也可先问清各人的意愿。危险举灯有明确警告与取消。\n次日：走访你改变的生活，再从街口离开本段体验。\n\n记录本只显示已获取证据。需要时可以主动打开带剧透的详细路线。\n\n根据你目前已知的事：\n" + story.current_questions())
	button(modal_body, "需要详细路线（有剧透，不授予证据）", func(): confirm("详细路线会直接说明三个结果的条件，仍要查看？", show_spoiler_help))
	button(modal_body, "回到探索", close_modal)

func show_spoiler_help() -> void:
	var text := "四个地点通过路口连接，必须走到路口附近再交互。\n\n灯钟因果可由棚内告示＋黄灯铭文与周伯核实，也可先检查灯罩＋钟痕，再向周伯追问。全部证据可在入夜后补齐。\n\n留灯：查清四项核心事实，与周伯说明恢复边界并非告别；入夜在棚中恢复信号。\n解缆：先了解旧约，在旧阶分别询问三方意愿，归还旧物，再回棚征得最后敲钟同意，返回旧阶请沈渡解缆。\n\n许宁可在岸上吹哨，不必登船。阿禾须主动在旧屋交换灯钟线索才能请许宁协助确认弟弟与船上答复；不合作也能留灯。\n\n成功与漫水后均可走动尾声，在街口明确离开。离开只记录经历，首版没有下一个地区。"
	open_modal("路线提示（不授予证据）", text)
	button(modal_body, "回到探索", close_modal)

func read_handover_response() -> void:
	do_action("handover_revisit" if story.flag("handover_updated") else "handover_read")
	show_current_response(object_title("handover"))
	if story.s.phase == "epilogue":
		act_button("看看这里今早怎样继续", "epilogue")
		if story.flag("handover_discussed") and not story.flag("handover_updated"):
			act_button("另附今日处理记录，不改旧单", "handover_update")

func show_current_response(title: String) -> void:
	open_modal(title,story.notice)
	button(modal_body,"返回探索",close_modal)

func act_button(text: String, id: String) -> void:
	button(modal_body, text, func():
		if conversation_target == "zhou" and id in ["deliver", "verify", "zhou_memory", "signal_guess", "promise_forever", "waiting_plan", "force", "apologize", "hypothesis_voices", "hypothesis_brightness", "hypothesis_signals", "wick_explain", "photo_zhou"]:
			continue_zhou(id)
		elif conversation_target in ["closing_zhou", "release_scene"] and id in ["closing_ring", "closing_speak", "closing_silent", "closing_watch", "release_rope", "release_watch"]:
			var target := conversation_target
			story.act(id)
			if id == "release_rope":
				last_place = ""
				update_world()
			conversation_response = story.notice
			response_count += 1
			modal_open = false
			nearest = target
			interact()
			refresh_ui()
		elif conversation_target in ["mooring", "voices"] and id in ["photo_same", "photo_shift", "listen_river", "call_paper", "answer_whistle", "ask_roof", "ask_departure", "xiaoman", "shen", "whistle_short", "whistle_long", "whistle_listen", "whistle_reset", "xiaoman_recognize", "xiaoman_wait", "xiaoman_ask"]:
			continue_river(id)
		else:
			var source := modal_header.text
			var place: String = story.s.place
			close_modal()
			do_action(id)
			if story.s.place == place:
				open_modal(source,story.notice)
				button(modal_body,"返回探索",close_modal))

func continue_river(id: String) -> void:
	var target := conversation_target
	if not started or not story.s.place in ["steps", "boat"]: return
	if story.s.phase != "night" and not id in ["photo_same", "photo_shift"]: return
	var location := Vector2(460,295) if target == "mooring" else Vector2(570,335)
	if player.distance_to(location) >= 96: return
	story.act(id)
	conversation_response = story.notice
	response_count += 1
	modal_open = false
	nearest = target
	interact()
	refresh_ui()

func continue_zhou(id: String) -> void:
	# Keep the actual interlocutor nearby; never move or acquire evidence off-screen.
	if not started or story.s.place != "shelter": return
	if player.distance_to(zhou_position()) >= 96:
		conversation_response = "隔得有些远，周伯没有听清。先结束谈话，走近一点再说。"
		modal_open = false
		nearest = "zhou"
		interact()
		return
	story.act(id)
	conversation_response = story.notice
	response_count += 1
	modal_open = false
	nearest = "zhou"
	interact()
	refresh_ui()

func settle_shelter_entry() -> void:
	if story.s.place != "shelter": return
	# Check physical occupancy without walkable's intentional overlap-escape exception.
	var blocked := false
	for r in solids:
		if r.grow(13).has_point(player): blocked = true
	var wait := shelter_wait_scene()
	if not wait.is_empty():
		blocked = blocked or zhou_bounds(wait.zhou).grow(13).has_point(player)
		if not wait.carried: blocked = blocked or chair_bounds(wait.chair).grow(13).has_point(player)
	if blocked:
		for candidate in [Vector2(450,495),Vector2(520,495),Vector2(550,530),Vector2(100,530)]:
			var clear := Rect2(40,175,780,445).has_point(candidate)
			for r in solids:
				if r.grow(13).has_point(candidate): clear = false
			if not wait.is_empty():
				if zhou_bounds(wait.zhou).grow(13).has_point(candidate): clear = false
				if not wait.carried and chair_bounds(wait.chair).grow(13).has_point(candidate): clear = false
			if clear:
				player = candidate
				break
	story.s.x = player.x
	story.s.y = player.y
	reset_actor_motion()

func travel(place: String) -> void:
	pulling_cart = false
	pulling_awning = false
	if story.flag("stock_carried"):
		story.act("stock_put_back")
	comparing_photo = false
	var previous_place: String = story.s.place
	story.change_place(place)
	if place == "lane":
		story.s.x = 690.0 if previous_place in ["house","street"] else 150.0
		story.s.y = 540.0
		if story.s.ending == "flood":
			if not story.flag("flood_dry_lane_seen"):
				story.set_flag("flood_dry_lane_seen")
				story.note("旧阶方向已经封住。这里石料南侧的浅色人行带仍干，向西通桥头接应点，向东可回许家门内。通道不要求先挪空车。")
		else: story.note("巷中修桥的石料挡住直路。围挡南端留着人行通道，许家门口在另一侧。脚步落在散砂上，行李轮能绕过去。")
	if place == "street" and previous_place == "lane":
		story.s.x = 150.0
		story.s.y = 540.0
	if place == "street" and story.s.phase == "dusk" and not story.flag("street_evening_seen"):
		story.set_flag("street_evening_seen")
		story.note("你回到街口时，老葛正把补好的鞋并排放在凳上。\n陶婶从门内问：‘明早量桥，先吃了再去？’\n‘带两个馒头就行。鞋等晾干，让他自己来拿，别又替他送到家。’\n她把一张包货纸压在秤下，没喊你停步。")
	elif place == "street" and story.s.phase == "dusk" and story.flag("street_evening_seen") and not story.flag("shoe_collected"):
		story.set_flag("shoe_collected")
		story.note("你再回街口，鞋主正把修好的鞋拎走。他把旧鞋踩在脚下试了两步，跟老葛争一句‘这回别再开线’，两人都笑了一下。\n老葛把空纸折平，凳子往檐下收。陶婶喊的馒头还没凉。")
	player = Vector2(story.s.x, story.s.y)
	reset_actor_motion()
	last_place = ""
	close_modal()
	update_world()
	settle_shelter_entry()
	refresh_ui()

func do_action(id: String) -> void:
	var before_phase: String = story.s.phase
	story.s.x = player.x
	story.s.y = player.y
	var acted: bool = story.act(id)
	if acted and id in ["chair_take","basin_take","take_basin","stock_take","take_wet_stock","evac_pack_take","chair_place","basin_place","move_wet_stock","evac_pack_deliver","stock_put_back","evac_pack_drop"]:
		update_actor_motion(0.0,"take" if id in ["chair_take","basin_take","take_basin","stock_take","take_wet_stock","evac_pack_take"] else "place")
	if id in ["chair_take","chair_place","basin_take","basin_place","stock_take","stock_put_back","tool_retrieve","tool_return","ferry_tag_take","ferry_tag_put_back"]:
		action_age=0.0
		action_position=player+Vector2(0,22)
		action_ok=acted
		action_caption=("抬起" if id.ends_with("take") else "放稳") if acted else "这里放不稳"
	if id == "roof_admit" and acted:
		roof_guest_position = Vector2(500,550)
		roof_guest_walking = true
	if before_phase != story.s.phase or id in ["tool_retrieve", "tool_return", "remove_shade", "retrieve_tongue", "install_tongue", "swap", "light_yellow", "begin_release", "release_rope", "roof_commission", "roof_admit", "roof_inspect", "move_wet_stock", "stock_take", "stock_put_back", "drawer_open", "handover_update", "ferry_tag_take", "ferry_tag_return", "ferry_tag_put_back", "evac_pack_take", "evac_pack_drop", "evac_pack_deliver", "chair_take", "chair_place", "wait_offer"]: last_place = ""
	if last_place != story.s.place:
		player = Vector2(story.s.x, story.s.y)
		update_world()
	refresh_ui()

func interact() -> void:
	if not started or modal_open or paused: return
	var wait := shelter_wait_scene()
	if not wait.is_empty() and wait.carried:
		story.wait_step(0.0,player,{"rope":pulling_awning,"rects":[Rect2(350,285,100,70)]})
		do_action("chair_place")
		return
	if pulling_awning:
		pulling_awning = false
		story.s.x = player.x
		story.s.y = player.y
		story.act("awning_tie")
		last_place = ""
		update_world()
		refresh_ui()
		return
	if pulling_cart:
		pulling_cart = false
		story.note("你松开车把，车停在脚边。" + ("中段缺口已经让开。" if story.flag("lane_cart_moved") else "车身仍占着缺口，可以继续拉，也可从南侧绕行。"))
		refresh_ui()
		return
	if nearest.is_empty() or modal_open or not started: return
	var target := nearest
	if comparing_photo and target in ["old_root", "old_stairs", "post_socket", "mooring"]:
		for obj in scene_objects:
			if obj.id == target:
				try_world_click(obj.pos)
				return
	if target.ends_with("_gate"):
		var dest := target.trim_suffix("_gate")
		if story.s.ending == "flood" and dest == "steps":
			story.notice = "旧阶已封闭。可以去旧屋、棚内与街口查看后果，不必涉水才能离开。"
			refresh_ui()
			return
		travel(dest)
		return
	if target == "back": travel("steps"); return
	if target == "wait_chair":
		do_action("chair_take")
		return
	if target == "handover" and story.s.place == "house" and story.flag("drawer_open"):
		var visible_handover := false
		for obj in scene_objects:
			if obj.id == target and player.distance_to(obj.pos) < 82: visible_handover = true
		if not visible_handover: return
		read_handover_response()
		return
	conversation_target = target if target in ["zhou", "mooring", "voices", "closing_zhou", "release_scene"] else ""
	open_modal(object_title(target), conversation_response if not conversation_target.is_empty() and not conversation_response.is_empty() else ("周伯扶着灯等你开口。你可以谈眼前的装置，也可以先问他为什么守在这里；不用许诺自己做不到的事。" if target == "zhou" else (("与%s交谈；你也可以先离开。" % object_title(target)) if target in ["tao","ge","xu","roof_ge","roof_ge_door"] else "看看眼前的东西；你也可以先离开。")))
	if story.s.phase == "epilogue":
		open_modal(object_title(target), "天已经亮了。夜里的处理不会因为你走访而重来；看看人们各自准备做的事，再决定何时离开。")
		act_button("看看这里今早怎样继续", "epilogue")
		if target == "handover" and story.flag("handover_updated"): act_button("再看旧单与今日附记", "handover_revisit")
		if target == "handover" and story.flag("handover_discussed") and not story.flag("handover_updated"): act_button("另附今日处理记录，不改旧单", "handover_update")
		if target == "tao" and story.s.identity == "he" and story.item("手提黄灯"): act_button("擦干提柄，把借来的灯还给陶婶", "return_lamp")
		if target == "wet_stock": act_button("看看昨晚浸湿的货物怎么处理", "stock_morning")
		if target == "ge":
			act_button("问老葛今早准备做什么", "morning_ge")
			if story.s.ending == "flood" and story.flag("morning_ge_seen"):
				if story.flag("evac_pack_carried"): act_button("这趟不能送，把被褥包交回老葛", "evac_pack_drop")
				elif not story.flag("evac_pack_delivered"): act_button("接过扎好的被褥包，沿干路送桥头", "evac_pack_take")
		if target == "evac_pack":
			if story.flag("morning_ge_seen"): act_button("接过扎好的被褥包，沿干路送桥头", "evac_pack_take")
			else: button(modal_body,"先问老葛包要送往哪里",close_modal)
		if target == "evac_receiver" and story.flag("evac_pack_carried"):
			act_button("托住包，翻看包角布签", "evac_pack_read_tag")
			act_button("按登记交给河街住户被褥接收", "evac_pack_deliver")
			act_button("按登记交给六码头商铺工具接收", "evac_pack_wrong_desk")
		if target == "drip" and story.flag("basin_carried") and story.s.ending != "flood": act_button("把端着的盆放回漏点", "basin_place")
		if target == "roof_note": act_button("展开工序纸，核对还没做的事", "roof_note_read")
		if target == "ferry_tag_hook" and story.item("旧渡牌"): act_button("把交班渡牌挂回岸棚木钩", "ferry_tag_return")
		if target == "roof_ge_door": act_button("到门口招呼他进屋看漏点", "roof_admit")
		if target == "roof_ge" and not roof_guest_walking:
			if not story.flag("roof_guiding") and not story.flag("roof_inspected"): act_button("请他跟自己去桌脚，指清漏点", "roof_guide")
			elif story.flag("roof_leak_shown") or story.flag("roof_inspected"): act_button("请他从干处看漏点，商量分项安排", "roof_inspect")
		if target == "roof_guide_spot": button(modal_body,"回到探索，带他走到桌脚干处",close_modal)
		if target == "paper" and story.s.identity == "xu" and not story.flag("morning_decided"):
			if story.s.ending == "flood": act_button("留联络方式，等安全后再回来处理旧屋", "leave_contact")
			else:
				act_button("先请人看屋顶，不急着决定卖不卖房", "roof_commission")
				act_button("今天还不能留下，先给陶婶写联络方式", "leave_contact")
		if target == "departure":
			button(modal_body, "离开这段体验", func(): confirm("离开前可先保存。保留旅途经历，不带走当地财物与身份。本活动首版到此，没有尚未制作的第二地区。确认离开？", func(): do_action("leave")))
	else:
		match target:
			"ferry_tag":
				if story.item("旧渡牌"): act_button("还没决定，把渡牌放回舷边", "ferry_tag_put_back")
				else: act_button("听沈渡说明这块木牌，接过他递来的牌", "ferry_tag_take")
			"ferry_tag_hook":
				if story.item("旧渡牌"): act_button("把交班渡牌挂回岸棚木钩", "ferry_tag_return")
				else: button(modal_body,"看看木钩",func(): close_modal();story.note("木钩钉在旧告示旁，外侧有一圈磨亮的痕迹。" );refresh_ui())
			"awning_rope":
				if story.flag("awning_tied"): button(modal_body,"棚绳已系稳，下面留出一块干处",close_modal)
				else: button(modal_body,"握住绳端，向下退拉棚布；E系住或松手",func(): close_modal(); story.s.x=player.x; story.s.y=player.y; pulling_awning=story.act("awning_grip"); refresh_ui())
			"lane_cart":
				if story.flag("lane_cart_moved"):
					button(modal_body,"空车已靠墙停稳，缺口可通行",close_modal)
				else:
					button(modal_body,"握住车把，向左逐步拉出空车",func(): close_modal(); pulling_cart=true; story.note("握住车把。按左方向键把车从两堆石料之间拉出；E松手。南侧绕路一直留着。"); refresh_ui())
			"driver":
				button(modal_body, "请他指一指如今的巷口", func(): close_modal(); story.note("司机指着栏杆尽头：‘沿这头进巷，许家旧屋在里面。桥修好以后，车就不停这边了。’\n他没问你回来住几天，蹲下确认搭扣扣牢，把这条路留给你自己走。"); refresh_ui())
				button(modal_body, "谢过他，自己慢慢走", func(): close_modal(); story.note("许宁说自己认得屋子，想慢慢走。司机点头：‘行，箱轮那儿有碎石，留点神。’\n他转身收车里的空水瓶，没有再替她安排去处。"); refresh_ui())
			"luggage_place":
				if story.flag("luggage_placed"):
					button(modal_body, "重新提起自己的行李", func(): handle_luggage(false))
					button(modal_body, "仍留在干处", close_modal)
					return
				button(modal_body, "把自己的行李留在门内", func(): handle_luggage(true))
			"luggage":
				if story.flag("luggage_taken"):
					button(modal_body, "行李已留在旧屋门内" if story.flag("luggage_placed") else "行李已经提在自己手上", close_modal)
					return
				button(modal_body, "提起自己的行李", func(): handle_luggage(false))
			"zhou_absent":
				button(modal_body, "看看棚边留下什么", func(): close_modal(); story.note("矮凳空着，通向旧阶的钟绳已经绷直。周伯没有消失，他说过要亲自把钟敲完。旧阶的路就在棚东侧。"); refresh_ui())
			"release_scene":
				if not story.flag("released"):
					act_button("留在干阶上，看沈渡自己解缆", "release_rope")
				else:
					act_button("船离岸后，陪岸上的人再站一会儿", "release_watch")
					button(modal_body, "不必等话都说完，迎接天明", func(): confirm("这次渡程已经结束，进入可走访的次日？", func(): do_action("release_dawn")))
			"closing_zhou":
				if not story.flag("closing_rang"):
					act_button("站到周伯身旁，等他敲钟", "closing_ring")
				else:
					if not story.flag("closing_answered"):
						act_button("告诉他灯仍在，但不再招呼人登船", "closing_speak")
						act_button("不替他们补话，安静陪他站着", "closing_silent")
					act_button("再看看岸和河上各自的动静", "closing_watch")
					button(modal_body, "今夜到这里，迎接天明", func(): confirm("结束夜晚，进入可自由走访的次日？", func(): do_action("closing_dawn")))
			"ge":
				if story.flag("roof_visit_arranged"): act_button("已约明早看瓦 · 核对安排", "roof_recall")
				elif story.flag("heard_drip"): act_button("说说旧屋漏点，约明早先看瓦", "roof_arrange")
				act_button("坐下听他说昨晚的事", "ge_talk")
				if story.item("老葛的工具袋"): act_button("把挑上来的工具袋交还给他", "tool_return")
			"shoe_parcel":
				button(modal_body, "看看纸包，不替主人取走", func(): close_modal(); story.note("鞋头露出纸包一角，新缝的线还绷着。包上只写了一个取鞋的姓，不是给旅人的物品。\n老葛把包往棚檐下推了推：‘他认得我的摊，会自己来。’你不必替这条街把每件小事都做完。"); refresh_ui())
			"wet_stock":
				if story.flag("stock_carried"): act_button("把箱子放回门边", "stock_put_back")
				elif not story.flag("stock_dried"): act_button("托住箱底，拿起湿货箱", "stock_take")
			"dry_stock":
				if story.flag("stock_carried"): act_button("把手中的货箱放到干台", "move_wet_stock")
			"old_root":
				act_button("沿树根看它原来朝哪边生长", "root_view")
			"old_stairs":
				act_button("数矮阶，对照旁边后来加高的岸", "stairs_view")
			"post_socket": act_button("蹲下看方槽边的旧铁锈", "socket_view")
			"old_photo": act_button("翻看照片正反面，记下岸的位置", "photo_view")
			"toolbag": act_button("站在干阶上，用竹竿挑起布袋", "tool_retrieve")
			"tao":
				if story.flag("heard_drip"): act_button("旧屋还在漏水，问问能找谁看", "roof_help")
				button(modal_body, "闲谈 · 门口那只杯子", func(): close_modal(); story.note("陶婶：门口那只杯子别收，接漏水的。喝水用柜子上那只。\n" + ("许宁想起从前赊账的橘子糖。陶婶说还卖，不过现在得自己付钱。" if story.s.identity == "xu" else "阿禾说杯沿缺了一角，明天换个盆吧。陶婶看了看天：盆接铺子里头那处漏，门口先用这个。")); show_current_response("陶婶"))
				if story.s.identity == "he": act_button("向陶婶借手提黄灯（物品）", "yellow")
			"ledger":
				if story.s.identity == "he":
					act_button("核对周伯两份灯芯的账", "ledger")
					if story.item("新灯芯"): act_button("这卷先留店里，亲自向周伯说明未送", "wick_keep")
				else: button(modal_body, "不翻别人的账本", close_modal)
			"handover":
				act_button("再看旧单与今日附记" if story.flag("handover_updated") else "展开公用物件交接单，看两栏记的什么", "handover_revisit" if story.flag("handover_updated") else "handover_read")
				if story.flag("handover_discussed") and not story.flag("handover_updated"): act_button("另附今日处理记录，不改旧单", "handover_update")
			"paper":
				if not story.flag("drawer_open"): act_button("托住底板，拉开下层抽屉", "drawer_open")
				act_button("查看旧桌（尊重私人物品）", "paper")
				if story.s.identity == "xu": act_button("坐一会儿，试试口袋里那半只旧哨", "whistle_memory")
			"roof":
				if story.flag("roof_visit_arranged"): act_button("看看记下的勘看安排", "roof_arrangement")
				act_button("停下脚步，听屋里的滴水", "roof_listen")
				if story.flag("heard_drip") and not story.flag("basin_placed"): act_button("端起搪瓷盆", "basin_take")
			"drip":
				if story.flag("basin_carried"): act_button("把盆放在新湿痕下", "basin_place")
				elif story.flag("basin_placed"): act_button("重新端起接水的盆", "basin_take")
				else: button(modal_body, "看一眼桌脚", func(): close_modal(); story.note("桌脚旁泛着水光。先前那些脚印已经干了，这里却是新的。"); refresh_ui())
			"watermark":
				if story.flag("basin_carried"): act_button("试把盆放在旧水印下", "basin_wrong")
				else: button(modal_body, "摸摸墙下的水印", func(): close_modal(); story.note("手指上只沾到墙灰。水印是旧的。"); refresh_ui())
			"xu":
				if story.s.identity == "he" and not story.flag("drawer_allowed"): act_button("问她：可以看旧桌下层的公用单据吗", "drawer_permission")
				button(modal_body, "闲谈 · 她为什么还在等", func(): close_modal(); story.note("阿禾：周伯说今晚别去河边。你为什么还在等？\n许宁：因为他说别去的时候，没说那里什么都没有。"); refresh_ui())
				if story.has("lamp") and story.has("bell"): act_button("告诉她棚里的灯罩与缺舌铜钟，问她愿不愿一起查", "exchange")
			"timetable", "lamp", "bell", "inscription":
				act_button("现场检查与记录", target)
				if target in ["lamp", "bell"] and story.flag("handover_seen") and not story.flag("handover_matched"): act_button("拿交接补记，就近核对灯罩" if target == "lamp" else "拿交接补记，就近核对钟架", "handover_lamp" if target == "lamp" else "handover_bell")
				if target == "bell":
					act_button("察看钟座背面刻记", "mark")
					if story.item("拆下的铜舌"): act_button("将取出的铜片挂回钟腹", "install_tongue")
				if target == "lamp" and story.flag("consent"):
					if not story.flag("shade_off"): act_button("扶稳灯，松开外罩卡扣", "remove_shade")
					elif not story.flag("tongue_taken"): act_button("解开罩内的棉线，取出铜片", "retrieve_tongue")
				if target == "inscription" and story.flag("consent") and story.s.phase == "dusk":
					if story.s.identity == "he" and story.item("手提黄灯") and not story.flag("swapped"): act_button("把借来的黄灯安在等候的位置，暂不点亮", "swap")
					button(modal_body, "等天暗再点灯（现在不结束傍晚）", func(): close_modal(); story.note("灯的位置已经可以安排，火要等暗下来再点。你还可以回街上、看旧屋，或准备好后主动确认入夜；钟和灯不会重置。"); refresh_ui())
				if target == "inscription" and story.s.phase == "night" and story.flag("consent") and not story.flag("closing_light") and not story.flag("closing_release"):
					button(modal_body, "将黄灯留在等候的位置，点亮灯芯", func(): confirm("点亮黄灯后仍留在夜里，周伯会到旧阶兑现敲钟的承诺；等你决定才进入次日。现在点亮？", func(): do_action("light_yellow")))
				if target == "lamp" and story.s.phase == "night" and not story.flag("shade_off"):
					if story.s.identity == "he" and not story.flag("swapped"): act_button("用手提黄灯换下白罩（需周伯同意）", "swap")
					button(modal_body, "危险：举白灯回应河声", func():
						var warning := "白灯表示可以登船。河声会借熟人的声音叫人，继续回应可能让它越过岸边界限。确认举灯？"
						if story.s.pollution == 1: warning = "水迹已越过候船棚。再次回应将使渡口失守；你仍可取消，回去分开灯罩、归还钟舌。确认再次举灯？"
						confirm(warning, func(): do_action("danger")))
					button(modal_body, "危险：强行砸坏灯内铜舌", func(): confirm("铜舌承载旧约，破坏后将无法恢复边界，立即导致渡口失守。这不是修复方法。确认破坏？", func(): do_action("break")))
			"zhou":
				if story.flag("handover_matched") and not story.flag("handover_discussed"): act_button("问交接补记：暂夹的铜件后来怎样了", "handover_zhou")
				button(modal_body, "闲谈 · 明早的渡船", func(): close_modal(); story.note("周伯：最后一班已经走了。明天六点。桥开了，这棚就拆。我还能守几年？她要是回来，看不见灯怎么办？"); refresh_ui())
				if story.s.identity == "he" and story.item("新灯芯"): act_button("交付新灯芯（物品）", "deliver")
				if story.flag("wick_kept") and not story.flag("wick_explained"): act_button("亲口说明这卷留店，不把未送推给陶婶", "wick_explain")
				if story.has("inscription"): act_button("问他：黄灯底座写的‘钟声归岸’是什么意思？", "verify")
				if not story.core() and story.has("covenant"):
					button(modal_body, "把目前查到的事告诉周伯", func(): close_modal(); story.note("周伯听完，摇摇头：你说这些都是一回事，可我想知道你在哪儿看见的。\n仍可去现场查看：" + story.missing_sources()); refresh_ui())
				if story.flag("photo_compared") and not story.flag("photo_discussed"): act_button("告诉他亲眼核对的旧灯柱位置，不替小满回答", "photo_zhou")
				act_button("问他：小满以前坐渡船是什么样？", "zhou_memory")
				act_button("提出解释：河上的声音都不可信，最好一概不听", "hypothesis_voices")
				if story.has("lamp"):
					act_button("提出解释：白罩太亮，遮暗些就行", "hypothesis_brightness")
				if story.has("lamp") and story.has("timetable"):
					act_button("提出解释：等候的光和招呼登船的光混在了一处", "hypothesis_signals")
				if (story.flag("heard_zhou") or story.flag("signal_compared")) and not story.flag("consent"):
					act_button("说以后自己会一直替他守灯", "promise_forever")
					act_button("提议只把今晚的等候和通航分开，不承诺替任何人守一生", "waiting_plan")
				if story.core() and not story.flag("consent"): act_button("不愿再等，坚持先收白灯", "force")
				if story.flag("forced"): act_button("为强硬干预道歉并重新说明", "apologize")
				if story.s.phase == "night":
					act_button("转述本人意愿，请周伯敲最后一次钟", "farewell_consent")
			"mooring":
				if story.flag("photo_seen") and not story.flag("photo_compared"):
					button(modal_body, "拿照片到现场，自己选参照位置", func(): close_modal(); comparing_photo = true; story.note("照片拿在手边。走近你要对照的位置，点击现场物件；可先看柳根或矮阶，也可以试别的参照。没有时间限制。"); refresh_ui())
				if story.s.phase == "night" and story.flag("released"):
					act_button("回身看看仍留在岸上的人", "release_watch")
				elif story.s.phase == "night":
					add_river_choices()
					if not story.flag("xiaoman_known"): act_button("请周伯先辨认他女儿的回应", "xiaoman_recognize")
					else:
						act_button("听父女谈来年怎样等、怎样过日子", "xiaoman_wait")
						act_button("明确问她：愿不愿结束这一次渡程？", "xiaoman_ask")
					act_button("询问沈渡是否愿意结束渡程" if story.has("covenant") else "问摆渡人：你在这里做什么？", "shen")
					if not story.flag("closing_light"):
						act_button("经本人同意归还旧物（不销毁）", "return")
						if not story.flag("closing_release"): act_button("把两岸的答复带给沈渡，请他自己解缆", "begin_release")
				else: button(modal_body, "查看旧阶", func(): close_modal(); story.note("普通渡船已走。系缆石上留下年复一年的磨痕。准备好后主动确认入夜。"); refresh_ui())
			"morning":
				button(modal_body, "看看已经收班的日渡", func(): close_modal(); story.note("日渡的踏板已经收起，座板倒扣在船篷下。棚里写着明早六点开班，此刻没有待登船的乘客。\n河面还有光，不必等一条看不见的任务出现。你可以继续在岸上走走，入夜由你自己决定。"); refresh_ui())
			"ship":
				if story.flag("released"):
					button(modal_body, "目送，不再登船", func(): close_modal(); story.note("缆绳已不在岸上。船灯远了一些，踏板没有再伸回来。可以回身陪岸上的人，不必追到所有话都说完。"); refresh_ui())
				elif story.flag("boat_arrival_pending"): button(modal_body,"船还没贴岸，回到干阶看它靠近",close_modal)
				elif story.s.phase == "night" and story.s.identity == "xu": act_button("许宁独有：踏上靠岸侧舷（可随时回岸）", "board")
				else: button(modal_body, "留在岸上", func(): close_modal(); story.note("夜船不公开卖票。阿禾不能凭身份登船；可以调查灯钟，在岸上恢复边界，或明确请许宁协助传话。"); refresh_ui())
			"voices":
				add_river_choices()
				act_button("询问沈渡的摆渡约定与意愿" if story.has("covenant") else "问摆渡人：你在这里做什么？", "shen")
			"departure": button(modal_body, "尚未天亮，继续本段体验", close_modal)
	button(modal_body, "先不做，回到探索", close_modal)

func add_river_choices() -> void:
	act_button("先站住，听河上有什么声音", "listen_river")
	if story.flag("river_heard"):
		act_button("问那张湿纸到底要带什么" if story.has("invitation") else "追问：带什么？", "call_paper")
		if story.s.identity == "he":
			act_button("请许宁按她记得的方式回应，自己留在岸上", "answer_whistle")
		elif not story.flag("xu_identified"):
			act_button("吹一声短音 ·", "whistle_short")
			act_button("吹一声长音 ——", "whistle_long")
			act_button("停下，听听这次是否有人回答", "whistle_listen")
			act_button("放下哨子，等回声散去再试", "whistle_reset")
	if story.flag("xu_identified"):
		act_button("先谈旧屋漏雨的事，不催着告别", "ask_roof")
		act_button("问他：你希望这一程结束吗？", "ask_departure")

func shore_heard_excerpt() -> String:
	var lines: Array[String] = []
	if story.flag("river_willow_listen"): lines.append("柳根处已听：岸后也喊回家吃饭，碗沿轻碰。")
	if story.flag("river_stair_listen"): lines.append("干阶处已听：又慢了；热的留着呢。")
	return "\n".join(lines)

func _draw() -> void:
	world_commands = []
	interface_commands = []
	build_presentation_commands()
	world_renderer.submit(world_commands)
	interface_renderer.submit(interface_commands)

func build_presentation_commands() -> void:
	var night: bool = started and story.s.phase == "night"
	var sky := Color("111f2b") if night else Color("516069")
	record_draw("draw_rect",[Rect2(0, 0, 855, 800), sky])
	record_draw("draw_rect",[Rect2(20, 155, 820, 480), Color("383f3f") if night else Color("75756a")])
	record_draw("draw_rect",[Rect2(40, 175, 780, 445), Color("363c39") if night else Color("858373")])
	for i in range(10):
		record_draw("draw_line",[Vector2(50, 190 + i * 44), Vector2(810, 190 + i * 44), Color(0.8, 0.82, 0.74, 0.07), 1])
	if started and story.s.place == "shelter":
		record_draw("draw_texture_rect",[cohesive_kit.textures.background,Rect2(0,0,855,640),false])
		# Readable title backing only above walk y175; never covers walk geometry.
		record_draw("draw_rect",[Rect2(0,0,855,151),Color(0.04,0.08,0.11,0.74)],true)
	record_draw("draw_string",[font, Vector2(30, 45), "末班渡船", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("eee4c9")],true)
	if not started:
		record_draw("draw_string",[font, Vector2(32, 98), "河岸不催你作答。先走近，看看他们的生活。", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("bfcac7")],true)
		return
	record_draw("draw_string",[font, Vector2(32, 95), Story.PLACES[story.s.place], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e0d5b4")],true)
	record_draw("draw_string",[font, Vector2(32, 130), "道路范围：石色地面　圆环：可交互　门形：地点连接", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bac5c3")],true)
	match story.s.place:
		"lane":
			if story.s.ending == "flood":
				record_draw("draw_rect",[Rect2(95,510,660,60),Color("9b977c")])
				record_draw("draw_string",[font,Vector2(270,560),"← 桥头接应　　干路　　许家 →",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("353c35")],true)
			record_draw("draw_rect",[Rect2(390,280,80,80),Color("736f65")])
			record_draw("draw_rect",[Rect2(390,440,80,60),Color("736f65")])
			record_draw("draw_rect",[Rect2(180,200,40,100),Color("676f70")])
			record_draw("draw_line",[Vector2(180,240),Vector2(220,240),Color("9f7351"),5])
			record_draw("draw_string",[font,Vector2(150,220),"旧年洪痕",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c8a883")],true)
			record_draw("draw_line",[Vector2(650,220),Vector2(650,305),Color("d2d2b9"),7])
			for tick in range(5): record_draw("draw_line",[Vector2(642,230+tick*15),Vector2(660,230+tick*15),Color("8ea4a7"),2])
			var water_y := 220.0 if story.s.ending == "flood" or story.s.pollution >= 2 else (260.0 if story.s.pollution == 1 else 290.0)
			record_draw("draw_line",[Vector2(638,290),Vector2(664,290),Color("4a96bb"),2])
			record_draw("draw_line",[Vector2(635,water_y),Vector2(668,water_y),Color("82bcdd"),5])
			record_draw("draw_string",[font,Vector2(580,210),"今日 · " + ("越上格" if water_y == 220 else ("升中格" if water_y == 260 else "低格")),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("82bcdd")],true)
			var cart := cart_position()
			record_draw("draw_rect",[Rect2(cart-Vector2(32,30),Vector2(64,60)),Color("927b58")])
			record_draw("draw_circle",[cart+Vector2(-28,28),8,Color("333d40")])
			record_draw("draw_circle",[cart+Vector2(28,28),8,Color("333d40")])
			record_draw("draw_line",[cart-Vector2(32,0),cart-Vector2(80,0),Color("b1a18a"),5])
			record_draw("draw_string",[font,Vector2(280,255),"修桥备料 · 南侧绕行",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ddcca5")],true)
			record_draw("draw_line",[Vector2(100,550),Vector2(740,550),Color("9b947f"),3])
		"arrival":
			record_draw("draw_rect",[Rect2(40,175,780,100),Color("3b5057")])
			record_draw("draw_line",[Vector2(80,290),Vector2(790,290),Color("a9a18e"),8])
			if story.s.ending == "flood":
				record_draw("draw_string",[font,Vector2(490,305),"河街住户：被褥　｜　六码头商铺：工具",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e3d4ad")],true)
				record_draw("draw_rect",[Rect2(580,372,110,12),Color("887659")])
				record_draw("draw_line",[Vector2(590,384),Vector2(590,405),Color("71644f"),6])
				record_draw("draw_line",[Vector2(680,384),Vector2(680,405),Color("71644f"),6])
			else:
				if not story.flag("luggage_taken"): record_draw("draw_rect",[Rect2(290,345,30,28),Color("785c49")])
		"street":
			if story.s.pollution == 1:
				var stock_pos := player+Vector2(15,10) if story.flag("stock_carried") else (Vector2(420,300) if story.flag("stock_dried") or story.s.phase == "epilogue" else Vector2(365,365))
				record_draw("draw_rect",[Rect2(185,375,270,24),Color("456777")])
				record_draw("draw_rect",[Rect2(stock_pos-Vector2(20,14),Vector2(40,28)),Color("9a8057")])
				record_draw("draw_line",[stock_pos-Vector2(15,0),stock_pos+Vector2(15,0),Color("665643"),3])
			record_draw("draw_rect",[Rect2(130, 175, 265, 120), Color("554b44")])
			record_draw("draw_rect",[Rect2(138, 165, 250, 25), Color("4e645d")])
			record_draw("draw_string",[font, Vector2(175, 228), "陶记杂货", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e1cfa6")],true)
			if story.flag("street_evening_seen") and not story.flag("shoe_collected") and story.s.phase == "dusk":
				record_draw("draw_rect",[Rect2(657,449,36,22),Color("b5a17a")])
				record_draw("draw_line",[Vector2(675,449),Vector2(675,471),Color("71634c"),2])
			if story.s.ending == "flood":
				record_draw("draw_rect",[Rect2(695, 315, 18, 160), Color("b68a59")])
				record_draw("draw_string",[font, Vector2(550, 180), "渡口停航 · 安全撤离", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e3c29f")],true)
		"house":
			record_draw("draw_rect",[Rect2(292,322,58,25),Color("655342")])
			record_draw("draw_line",[Vector2(310,338),Vector2(332,338),Color("c0a97d"),3])
			if story.flag("drawer_open"):
				record_draw("draw_rect",[Rect2(292,345,78,42),Color("473f36")])
				if story.flag("handover_updated"): record_draw("draw_rect",[Rect2(315,353,26,18),Color("eee3c9")])
				record_draw("draw_rect",[Rect2(337,365,26,18),Color("dfcfaa")])
				record_draw("draw_line",[Vector2(350,366),Vector2(350,381),Color("99886a"),1])
			record_draw("draw_rect",[Rect2(675,215,40,30),Color("d4c9a7")])
			record_draw("draw_line",[Vector2(680,238),Vector2(709,238),Color("6a746b"),2])
			record_draw("draw_line",[Vector2(687,218),Vector2(687,236),Color("72614a"),2])
			record_draw("draw_rect",[Rect2(210, 185, 220, 110), Color("5b5045")])
			record_draw("draw_rect",[Rect2(40, 175, 780, 12), Color("a29376")])
			var basin_pos := player + Vector2(15, -8) if story.flag("basin_carried") else (Vector2(450, 340) if story.flag("basin_placed") else Vector2(600, 250))
			record_draw("draw_circle",[basin_pos, 24, Color("a5b4b5")])
			record_draw("draw_circle",[basin_pos, 17, Color("515f64")])
			record_draw("draw_circle",[Vector2(450, 340), 10, Color("5a777b")])
			record_draw("draw_line",[Vector2(445, 187), Vector2(450, 325), Color(0.7, 0.8, 0.8, 0.45), 1])
		"shelter":
			draw_shelter_ground()
			var tension := float(story.s.get("awning_pull",0.0))/90.0
			visual_quad("awning",PackedVector2Array([Vector2(575,195),Vector2(735,195),Vector2(735,270-tension*45),Vector2(575,280-tension*45)]))
			record_draw("draw_line",[Vector2(690,245-tension*40),Vector2(690,350+tension*90),Color("b8a279"),3])
			record_draw("draw_line",[Vector2(700,420),Vector2(700,455),Color("8d7250"),7])
			record_draw("draw_string",[font,Vector2(710,450),"系绳桩",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c4b294")],true)
			if story.flag("awning_tied") and story.s.ending != "flood": record_draw("draw_rect",[Rect2(590,365,135,75),Color("77745c"),false,2])
			elif not story.flag("awning_tied"):
				for drop in range(3):
					var fall := fmod(presentation_time*22+drop*7,20)
					record_draw("draw_line",[Vector2(610+drop*32,285-tension*40+fall),Vector2(610+drop*32,291-tension*40+fall),Color("75a5bb"),2])
			# Table now participates in the actor foot-depth pass.
			# Beam candidate rejected for proportions; no stretched/doubled pixel beam.

			cohesive_kit.lamp(self,Vector2(250,360),story.s.ending != "flood",story.flag("shade_off") or story.flag("swapped"))
			cohesive_kit.lamp(self,Vector2(620,390),story.flag("yellow_lit") and story.s.ending != "flood",true)
			cohesive_kit.prop(self,"bell",Vector2(550,253),44)
			if story.flag("tongue_home"): record_draw("draw_line",[Vector2(550, 223), Vector2(550, 253), Color("c4a26a"), 5])
			if story.item("拆下的铜舌"): record_draw("draw_line",[player + Vector2(12, -8), player + Vector2(12, 12), Color("c4a26a"), 4])
			if story.flag("shade_off"): record_draw("draw_rect",[Rect2(275, 375, 28, 19), Color("d4d8d6"), false, 3])
			if story.s.ending == "flood":
				record_draw("draw_rect",[Rect2(193,304,120,104),Color("53605a")])
				record_draw("draw_line",[Vector2(193,345),Vector2(313,375),Color("b3a07c"),4])
				record_draw("draw_rect",[Rect2(516,204,69,66),Color("53605a")])
				record_draw("draw_line",[Vector2(516,224),Vector2(585,249),Color("b3a07c"),4])
				record_draw("draw_rect",[Rect2(602,370,36,40),Color("53605a")])
				record_draw("draw_line",[Vector2(705,522),Vector2(788,570),Color("98774e"),12])
				record_draw("draw_line",[Vector2(705,570),Vector2(788,522),Color("98774e"),12])
				record_draw("draw_string",[font,Vector2(340,470),"停航 · 灯钟封存",HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("ddc9a5")],true)
			if story.s.pollution > 0: record_draw("draw_rect",[Rect2(90, 478, 690, 100), Color(0.2, 0.36, 0.4, 0.55)])
		"steps":
			record_draw("draw_rect",[Rect2(40, 175, 780, 135), Color("223d4a")])
			for i in range(7):
				record_draw("draw_line",[Vector2(55, 188 + i * 16), Vector2(805, 188 + i * 16), Color("36505b"), 2])
			for i in range(4): record_draw("draw_line",[Vector2(60, 310 + i * 34), Vector2(810, 310 + i * 34), Color("a3a69b"), 3])
			if story.s.pollution == 1:
				record_draw("draw_rect",[Rect2(40,310,780,34),Color("365864")])
				record_draw("draw_string",[font,Vector2(75,335),"水已越最低阶 · 上一层仍露出",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ccdee0")],true)
			record_draw("draw_line",[Vector2(135,417),Vector2(178,450),Color("89785a"),10])
			record_draw("draw_line",[Vector2(157,438),Vector2(192,429),Color("89785a"),5])
			for step in range(3): record_draw("draw_rect",[Rect2(282,447+step*10,94,7),Color("81867d")])
			record_draw("draw_rect",[Rect2(475,395,20,20),Color("141f23")])
			record_draw("draw_rect",[Rect2(475,395,20,20),Color("ac9977"),false,2])
			if story.s.phase == "night":
				var drift := Vector2(0,-60) if story.flag("released") else Vector2(0,-boat_approach_offset)
				record_draw("draw_colored_polygon",[PackedVector2Array([Vector2(565,230)+drift,Vector2(810,230)+drift,Vector2(777,300)+drift,Vector2(605,300)+drift]), Color("332e2b")])
				if not story.flag("released") and not story.flag("boat_arrival_pending"): record_draw("draw_line",[Vector2(460, 295), Vector2(625, 275), Color("baab87"), 3])
		"boat":
			record_draw("draw_rect",[Rect2(40, 175, 780, 445), Color("403d37")])
			for i in range(10): record_draw("draw_line",[Vector2(55 + i * 80, 180), Vector2(55 + i * 80, 610), Color("746957"), 2])
			record_draw("draw_rect",[Rect2(260, 195, 240, 80), Color("353733")])
			for i in range(6): record_draw("draw_circle",[Vector2(290 + i * 35, 220), 7, Color("9a8c71")])
	if story.s.place == "shelter": draw_shelter_actors()
	for obj in scene_objects:
		if story.s.place == "shelter": continue # markers are drawn after the sorted actor pass
		var pos: Vector2 = obj.pos
		var color := Color("9ba89c")
		if obj.kind == "gate":
			color = Color("a9bdc0")
			record_draw("draw_rect",[Rect2(pos - Vector2(22, 24), Vector2(44, 48)), Color("4e6268"), false, 3])
		elif obj.kind == "npc" and not (obj.id == "zhou" and not shelter_wait_scene().is_empty()):
			record_draw("draw_circle",[pos - Vector2(0, 9), 11, Color("bba58c")])
			record_draw("draw_rect",[Rect2(pos + Vector2(-12, 4), Vector2(24, 25)), Color("556d70")])
		elif obj.id not in ["zhou", "wait_chair"]:
			record_draw("draw_circle",[pos, 7, Color("c1b18a")])
		record_draw("draw_arc",[pos, 33, 0, TAU, 32, Color(color, 0.6), 1.5],true)
		if obj.id == nearest: record_draw("draw_arc",[pos, 40, 0, TAU, 32, Color("f2d68b"), 3],true)
		record_draw("draw_string",[font, pos + Vector2(-64, 59), obj.title, HORIZONTAL_ALIGNMENT_LEFT, 175, 17, Color("ebe5d0")],true)
	if story.flag("luggage_taken") and not story.flag("luggage_placed"): record_draw("draw_rect",[Rect2(player+Vector2(12,0),Vector2(24,25)),Color("785c49")])
	elif story.flag("luggage_placed") and story.s.place == "house": record_draw("draw_rect",[Rect2(578,498,24,25),Color("785c49")])
	if story.flag("evac_pack_carried"):
		record_draw("draw_rect",[Rect2(player+Vector2(8,0),Vector2(34,26)),Color("929581")])
		if story.flag("evac_pack_tag_read"):
			var tag_pos := Vector2(clampf(player.x-85,45,590),clampf(player.y+35,180,590))
			record_draw("draw_rect",[Rect2(tag_pos,Vector2(225,23)),Color("ded4b8")],true)
			record_draw("draw_string",[font,tag_pos+Vector2(4,17),"河街十二号 · 陈家 · 被褥一包",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("343c39")],true)
	elif story.s.ending == "flood" and ((story.s.place == "street" and not story.flag("evac_pack_delivered")) or (story.s.place == "arrival" and story.flag("evac_pack_delivered"))): record_draw("draw_rect",[Rect2(Vector2(635,455) if story.s.place == "street" else Vector2(590,350),Vector2(34,26)),Color("929581")])
	if story.item("旧渡牌"): record_draw("draw_rect",[Rect2(player+Vector2(12,-3),Vector2(14,22)),Color("b19a70")])
	if story.s.place == "boat" and not story.flag("ferry_tag_taken") and not story.flag("ferry_tag_returned") and not story.item("旧渡牌") and first_meet_scene().is_empty(): record_draw("draw_rect",[Rect2(678,405,14,22),Color("b19a70")])
	if story.s.place == "shelter":
		cohesive_kit.prop(self,"hook",Vector2(175,326),14)
		if story.flag("ferry_tag_returned"): record_draw("draw_rect",[Rect2(168,322,14,22),Color("b19a70")])
	if story.s.place != "shelter": draw_player_body()
	var wick_pos := player+Vector2(-18,7) if story.item("新灯芯") else (Vector2(420,250) if story.flag("wick_kept") and story.s.place == "street" else Vector2.ZERO)
	if wick_pos != Vector2.ZERO:
		record_draw("draw_rect",[Rect2(wick_pos-Vector2(12,6),Vector2(24,12)),Color("d7c7a3")])
		record_draw("draw_line",[wick_pos-Vector2(0,6),wick_pos+Vector2(0,6),Color("8d7450"),2])
	var bag_pos := Vector2.ZERO
	if story.item("老葛的工具袋"): bag_pos = player + Vector2(20,8)
	elif story.flag("tool_returned") and story.s.place == "street": bag_pos = Vector2(650,490)
	elif story.s.place == "steps" and not story.flag("tool_returned"): bag_pos = Vector2(235,355)
	if bag_pos != Vector2.ZERO:
		record_draw("draw_rect",[Rect2(bag_pos-Vector2(11,4),Vector2(22,19)),Color("8e7052")])
		record_draw("draw_arc",[bag_pos-Vector2(0,5),8,PI,TAU,12,Color("cbb28b"),2])
		record_draw("draw_line",[bag_pos+Vector2(-5,4),bag_pos+Vector2(6,8),Color("c3c2b6"),2])
	if story.s.place == "steps" and story.s.phase == "night" and not shore_heard_excerpt().is_empty():
		record_draw("draw_rect",[Rect2(55,185,520,62),Color("25363c")],true)
		var heard_lines := shore_heard_excerpt().split("\n")
		for i in range(heard_lines.size()): record_draw("draw_string",[font,Vector2(65,209+i*24),heard_lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("dccfaf")],true)
	if not modal_open: draw_waiting()
	# Draw above the ordinary object markers, with matching provider geometry.
	# Modal content occludes this presentation and never advances it.
	if not modal_open: draw_first_meet(first_meet_scene())
	if comparing_photo and story.s.place == "steps":
		record_draw("draw_rect",[Rect2(50,510,210,110),Color("d4c9a7")],true)
		record_draw("draw_rect",[Rect2(60,520,190,29),Color("72827f")],true)
		for step in range(3): record_draw("draw_line",[Vector2(130,558+step*7),Vector2(215,558+step*7),Color("6c6e60"),3])
		record_draw("draw_line",[Vector2(225,587),Vector2(209,542),Color("655e44"),5])
		record_draw("draw_line",[Vector2(212,551),Vector2(237,535),Color("655e44"),2])
		record_draw("draw_line",[Vector2(110,583),Vector2(110,550),Color("6e5a43"),4])
		record_draw("draw_circle",[Vector2(110,550),5,Color("a68b55")])
		record_draw("draw_string",[font,Vector2(63,609),"旧照 · 新棚启用前",HORIZONTAL_ALIGNMENT_LEFT,185,15,Color("3e443e")],true)
	if not modal_open:
		draw_presentation_feedback()
		if story.s.place in ["steps","boat"]:
			for wave in range(4):
				var wx := 590.0+wave*45.0
				var wy := 210.0+sin(presentation_time*0.7+wave)*2.0
				record_draw("draw_line",[Vector2(wx,wy),Vector2(wx+24,wy),Color(0.46,0.65,0.73,0.3),1])
	for i in range(0 if modal_open else 4):
		var r := Rect2(280 + i * 70, 650, 65, 55)
		record_draw("draw_rect",[r, Color("384c54")],true)
		record_draw("draw_string",[font, r.position + Vector2(23, 36), ["←", "↑", "↓", "→"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ddd8bc")],true)
