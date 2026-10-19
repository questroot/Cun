extends Node2D
const Story = preload("res://story_state.gd")
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

func _ready() -> void:
	add_to_group("cun_play_visible")
	font = ThemeDB.fallback_font
	_setup_ui()
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
	if story.s.place == "shelter":
		result["visible_equipment"] = {"outer_shade":("放在灯旁" if story.flag("shade_off") else "扣在灯上"),"bell":("铜片挂在钟内" if story.flag("tongue_home") else "挂孔空着"),"yellow_lamp":("亮着" if story.flag("yellow_lit") else "未点亮")}
		if story.item("拆下的铜舌"): result["visible_equipment"]["carried"] = "手上铜片"
	result["objects"] = targets
	result["obstacles"] = obstacles
	result["walk_area"] = {"x":40,"y":175,"width":780,"height":445}
	return result

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
	root_ui.theme = theme
	var panel := PanelContainer.new()
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
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hud)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("c8c4a9"))
	column.add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	message = RichTextLabel.new()
	message.fit_content = true
	message.custom_minimum_size = Vector2(342, 150)
	message.bbcode_enabled = false
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(message)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	inner.add_child(action_box)
	var menu := HFlowContainer.new()
	column.add_child(menu)
	button(menu, "记录 [J]", show_journal)
	button(menu, "物品 [I]", show_items)
	button(menu, "保存", save_game)
	button(menu, "读取", func(): confirm("读取会替换当前未保存进度，继续？", load_game))
	button(menu, "暂停 [Esc]", show_pause)
	button(menu, "水声 开/关", toggle_sound)
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
	var sc := ScrollContainer.new()
	mm.add_child(sc)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 12)
	sc.add_child(modal_body)

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
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
	overlay.show()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	modal_body.add_child(title_label)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 665
	modal_body.add_child(text)

func close_modal() -> void:
	if not started: return
	modal_open = false
	conversation_target = ""
	conversation_response = ""
	paused = false
	overlay.hide()
	refresh_ui()

func confirm(text: String, callback: Callable) -> void:
	open_modal("请确认", text)
	button(modal_body, "确认", func(): close_modal(); callback.call())
	button(modal_body, "取消，回到探索", close_modal)

func show_title() -> void:
	open_modal("末班渡船", "俯视探索 · 独立活动首版\n\n在回水埠，一个傍晚，两种处境。选择身份后本次固定；你不必重演既定结局。\n\nWASD / 方向键自由走动，靠近发光圆环后按 E 打开交互，也可点击右侧按钮。走到路口，交互前往相邻地点。J 记录，I 物品，Esc 暂停。鼠标可点击场地下方方向按钮移动。\n\n探索、交谈、暂停和读记录都不会增加污染。入夜由你主动确认，没有倒计时。危险动作会再次确认，取消没有惩罚。所有图形与水声由本项目自制，无闪烁、跳吓或截图采集。")
	button(modal_body, "许宁 · 返乡者｜离家多年，回来处理旧屋", func(): start_game("xu"))
	button(modal_body, "阿禾 · 学徒｜杂货铺帮工，熟悉这条街的人", func(): start_game("he"))
	button(modal_body, "读取独立活动存档", load_game)
	button(modal_body, "退出游戏", func(): get_tree().quit())
	refresh_ui()

func start_game(identity: String) -> void:
	story.fresh(identity)
	started = true
	player = Vector2(story.s.x, story.s.y)
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
	if story.load_game():
		started = true
		last_place = ""
		player = Vector2(story.s.x, story.s.y)
		close_modal()
		update_world()
		if not walkable(player): player = Vector2(450, 440)
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
func try_world_click(point: Vector2) -> bool:
	if not started or modal_open or paused or story.s.left: return false
	if story.s.phase == "epilogue": return false
	if story.s.place == "shelter":
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
	elif not story.flag("basin_placed") and player.distance_to(Vector2(600, 250)) < 82 and point.distance_to(Vector2(600, 250)) < 35:
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

func _process(delta: float) -> void:
	if sound_enabled and playback != null:
		for i in range(playback.get_frames_available()):
			audio_time += 1.0 / 22050.0
			var wave := sin(audio_time * 130.0) * 0.05 + sin(audio_time * 173.0) * 0.025 + rng.randf_range(-0.018, 0.018)
			playback.push_frame(Vector2(wave, wave))
	if not started or modal_open or paused or story.s.left: return
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
	var previous := nearest
	nearest = ""
	var distance := 96.0
	for obj in scene_objects:
		var d := player.distance_to(obj.pos)
		if d < distance:
			distance = d
			nearest = obj.id
	if previous != nearest: refresh_ui()
	queue_redraw()

func move_player(offset: Vector2) -> void:
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
		"street":
			solids.append(Rect2(145, 190, 235, 95))
			add_object("tao", "陶婶", Vector2(260, 330), "npc")
			add_object("ledger", "铺内账本", Vector2(420, 235))
			add_object("ge", "围挡旁补鞋的老葛", Vector2(620, 470), "npc")
			add_object("shelter_gate", "去候船棚", Vector2(750, 385), "gate")
			add_object("house_gate", "去许家旧屋", Vector2(100, 440), "gate")
			add_object("departure", "街口·离开体验", Vector2(450, 570), "gate")
		"house":
			solids.append(Rect2(220, 190, 200, 105))
			add_object("paper", "旧桌·私人物品", Vector2(320, 340))
			add_object("roof", "屋梁与旧搪瓷盆", Vector2(600, 250))
			add_object("drip", "桌脚的新湿痕", Vector2(450, 340))
			add_object("watermark", "墙下的旧水印", Vector2(130, 300))
			if story.s.identity == "he": add_object("xu", "许宁", Vector2(550, 405), "npc")
			add_object("street_gate", "回杂货铺 / 街口", Vector2(450, 580), "gate")
		"shelter":
			solids.append(Rect2(350, 285, 100, 70))
			add_object("timetable", "旧通航告示", Vector2(125, 250))
			add_object("lamp", "卸下白罩的旧灯" if story.flag("shade_off") else "白罩船灯", Vector2(250, 360))
			add_object("bell", "铜舌归位的钟" if story.flag("tongue_home") else "缺铜舌的钟", Vector2(550, 240))
			add_object("inscription", "黄灯底座", Vector2(620, 390))
			if story.s.phase != "epilogue" or story.s.ending == "light": add_object("zhou", "周伯", Vector2(455, 430), "npc")
			else: add_object("morning", "渡口次日告示", Vector2(455, 430))
			add_object("street_gate", "回街口", Vector2(95, 570), "gate")
			add_object("steps_gate", "去旧石阶", Vector2(750, 570), "gate")
		"steps":
			add_object("mooring", "系缆石", Vector2(460, 295))
			if story.flag("closing_light"): add_object("closing_zhou", "提着钟柄等你的周伯", Vector2(590, 410), "npc")
			if not story.flag("tool_returned") and not story.item("老葛的工具袋"): add_object("toolbag", "湿阶低处的布袋", Vector2(235, 355))
			if story.s.phase == "night": add_object("ship", "靠岸夜船", Vector2(700, 295))
			else: add_object("morning", "河面与普通渡船", Vector2(700, 295))
			add_object("shelter_gate", "回候船棚", Vector2(115, 565), "gate")
		"boat":
			solids.append(Rect2(260, 195, 240, 80))
			add_object("voices", "旧物与河声", Vector2(570, 335))
			add_object("back", "返回旧石阶（安全）", Vector2(450, 570), "gate")
	queue_redraw()

func refresh_ui() -> void:
	clear_children(action_box)
	if not started:
		hud.text = "末班渡船\n独立活动 · 故事驱动探索"
		summary.text = "选择一个身份，亲自走到线索旁。"
		return
	hud.text = "%s\n%s · %s" % [story.who(), {"dusk":"傍晚", "night":"入夜", "epilogue":"次日尾声"}[story.s.phase], Story.PLACES[story.s.place]]
	summary.text = "侵入 %d / 2　证据 %d 项\n%s" % [story.s.pollution, story.s.evidence.size(), (story.ending_name() if not story.s.ending.is_empty() else "无倒计时 · 调查/普通交谈不增加侵入")]
	message.text = story.notice
	foot_hint.text = "WASD / 方向键移动　E 交互　J 记录　I 物品　Esc 暂停\n" + ("靠近「%s」· E 或点击右侧交互" % object_title(nearest) if not nearest.is_empty() else "走近有圆环的物件或人物，再交互。鼠标可按住下方方向键。")
	if story.s.place == "house" and story.s.phase != "epilogue": foot_hint.text += "\n鼠标：走近盆点击拿起，再走近湿痕点击放下（也可E交互）。"
	if story.s.place == "shelter" and story.flag("consent") and story.s.phase != "epilogue": foot_hint.text += "\n可走近后直接点击灯罩、铜钟或黄灯操作；E交互仍可用。"
	if story.s.left:
		button(action_box, "本活动首版到此 · 返回身份选择", func(): started = false; show_title())
		button(action_box, "退出游戏", func(): get_tree().quit())
		return
	if not nearest.is_empty():
		button(action_box, "[E] 交互：" + object_title(nearest), interact)
	if story.s.phase == "dusk":
		button(action_box, "准备好了 · 进入入夜", func(): confirm("进入入夜？人物将开始赴约；必要线索和工具仍可补查。没有自动倒计时。", func(): do_action("night")))
	button(action_box, "当前目标 / 操作提示", show_help)

func object_title(id: String) -> String:
	for obj in scene_objects:
		if obj.id == id: return obj.title
	return ""

func show_help() -> void:
	open_modal("操作与当前目标", "走近圆环物件或人物，按E或点击交互。用WASD/方向键或按住地图下方方向按钮走动。调查、普通交谈和暂停都不会让侵入升级。\n\n傍晚：了解这里的生活，亲眼看看渡口有什么变化。准备好才确认入夜。\n入夜：你可以介入灯的信号，也可先问清各人的意愿。危险举灯有明确警告与取消。\n次日：走访你改变的生活，再从街口离开本段体验。\n\n记录本只显示已获取证据。需要时可以主动打开带剧透的详细路线。")
	button(modal_body, "需要详细路线（有剧透，不授予证据）", func(): confirm("详细路线会直接说明三个结果的条件，仍要查看？", show_spoiler_help))
	button(modal_body, "回到探索", close_modal)

func show_spoiler_help() -> void:
	var text := "四个地点通过路口连接，必须走到路口附近再交互。\n\n灯钟因果可由棚内告示＋黄灯铭文与周伯核实，也可先检查灯罩＋钟痕，再向周伯追问。全部证据可在入夜后补齐。\n\n留灯：查清四项核心事实，与周伯说明恢复边界并非告别；入夜在棚中恢复信号。\n解缆：先了解旧约，在旧阶分别询问三方意愿，归还旧物，再回棚征得最后敲钟同意，返回旧阶请沈渡解缆。\n\n许宁可在岸上吹哨，不必登船。阿禾须主动在旧屋交换灯钟线索才能请许宁协助确认弟弟与船上答复；不合作也能留灯。\n\n成功与漫水后均可走动尾声，在街口明确离开。离开只记录经历，首版没有下一个地区。"
	open_modal("路线提示（不授予证据）", text)
	button(modal_body, "回到探索", close_modal)

func act_button(text: String, id: String) -> void:
	button(modal_body, text, func():
		if conversation_target == "zhou" and id in ["deliver", "verify", "zhou_memory", "signal_guess", "promise_forever", "waiting_plan", "force", "apologize"]:
			continue_zhou(id)
		elif conversation_target == "closing_zhou" and id in ["closing_ring", "closing_speak", "closing_silent", "closing_watch"]:
			var target := conversation_target
			story.act(id)
			conversation_response = story.notice
			modal_open = false
			nearest = target
			interact()
			refresh_ui()
		elif conversation_target in ["mooring", "voices"] and id in ["listen_river", "call_paper", "answer_whistle", "ask_roof", "ask_departure", "xiaoman", "shen", "whistle_short", "whistle_long", "whistle_listen", "whistle_reset"]:
			continue_river(id)
		else:
			close_modal()
			do_action(id))

func continue_river(id: String) -> void:
	var target := conversation_target
	if not started or story.s.phase != "night" or not story.s.place in ["steps", "boat"]: return
	var location := Vector2(460,295) if target == "mooring" else Vector2(570,335)
	if player.distance_to(location) > 82: return
	story.act(id)
	conversation_response = story.notice
	modal_open = false
	nearest = target
	interact()
	refresh_ui()

func continue_zhou(id: String) -> void:
	# Keep the actual interlocutor nearby; never move or acquire evidence off-screen.
	if not started or story.s.place != "shelter" or player.distance_to(Vector2(455,430)) > 82: return
	story.act(id)
	conversation_response = story.notice
	modal_open = false
	nearest = "zhou"
	interact()
	refresh_ui()

func travel(place: String) -> void:
	story.change_place(place)
	player = Vector2(story.s.x, story.s.y)
	last_place = ""
	close_modal()
	update_world()
	refresh_ui()

func do_action(id: String) -> void:
	var before_phase: String = story.s.phase
	story.s.x = player.x
	story.s.y = player.y
	story.act(id)
	if before_phase != story.s.phase or id in ["tool_retrieve", "tool_return", "remove_shade", "retrieve_tongue", "install_tongue", "swap", "light_yellow"]: last_place = ""
	if last_place != story.s.place:
		player = Vector2(story.s.x, story.s.y)
		update_world()
	refresh_ui()

func interact() -> void:
	if nearest.is_empty() or modal_open or not started: return
	var target := nearest
	if target.ends_with("_gate"):
		var dest := target.trim_suffix("_gate")
		if story.s.ending == "flood" and dest == "steps":
			story.notice = "旧阶已封闭。可以去旧屋、棚内与街口查看后果，不必涉水才能离开。"
			refresh_ui()
			return
		travel(dest)
		return
	if target == "back": travel("steps"); return
	conversation_target = target if target in ["zhou", "mooring", "voices", "closing_zhou"] else ""
	open_modal(object_title(target), conversation_response if not conversation_target.is_empty() and not conversation_response.is_empty() else ("周伯扶着灯等你开口。你可以谈眼前的装置，也可以先问他为什么守在这里；不用许诺自己做不到的事。" if target == "zhou" else "看看眼前的东西；你也可以先离开。"))
	if story.s.phase == "epilogue":
		open_modal(object_title(target), "天已经亮了。夜里的处理不会因为你走访而重来；看看人们各自准备做的事，再决定何时离开。")
		act_button("看看这里今早怎样继续", "epilogue")
		if target == "tao" and story.s.identity == "he" and story.item("手提黄灯"): act_button("擦干提柄，把借来的灯还给陶婶", "return_lamp")
		if target == "ge": act_button("问老葛今早准备做什么", "morning_ge")
		if target == "paper" and story.s.identity == "xu" and not story.flag("morning_decided"):
			act_button("先请人看屋顶，不急着决定卖不卖房", "roof_commission")
			act_button("今天还不能留下，先给陶婶写联络方式", "leave_contact")
		if target == "departure":
			button(modal_body, "离开这段体验", func(): confirm("离开前可先保存。保留旅途经历，不带走当地财物与身份。本活动首版到此，没有尚未制作的第二地区。确认离开？", func(): do_action("leave")))
	else:
		match target:
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
				act_button("坐下听他说昨晚的事", "ge_talk")
				if story.item("老葛的工具袋"): act_button("把挑上来的工具袋交还给他", "tool_return")
			"toolbag": act_button("站在干阶上，用竹竿挑起布袋", "tool_retrieve")
			"tao":
				button(modal_body, "闲谈 · 门口那只杯子", func(): close_modal(); story.note("陶婶：门口那只杯子别收，接漏水的。喝水用柜子上那只。\n" + ("许宁想起从前赊账的橘子糖。陶婶说还卖，不过现在得自己付钱。" if story.s.identity == "xu" else "阿禾说杯沿缺了一角，明天换个盆吧。陶婶看了看天：盆接铺子里头那处漏，门口先用这个。")); refresh_ui())
				if story.s.identity == "he": act_button("向陶婶借手提黄灯（物品）", "yellow")
			"ledger":
				if story.s.identity == "he": act_button("核对周伯两份灯芯的账", "ledger")
				else: button(modal_body, "不翻别人的账本", close_modal)
			"paper":
				act_button("查看旧桌（尊重私人物品）", "paper")
				if story.s.identity == "xu": act_button("坐一会儿，试试口袋里那半只旧哨", "whistle_memory")
			"roof":
				act_button("停下脚步，听屋里的滴水", "roof_listen")
				if story.flag("heard_drip") and not story.flag("basin_placed"): act_button("端起搪瓷盆", "basin_take")
			"drip":
				if story.flag("basin_carried"): act_button("把盆放在新湿痕下", "basin_place")
				else: button(modal_body, "看一眼桌脚", func(): close_modal(); story.note("桌脚旁泛着水光。先前那些脚印已经干了，这里却是新的。"); refresh_ui())
			"watermark":
				if story.flag("basin_carried"): act_button("试把盆放在旧水印下", "basin_wrong")
				else: button(modal_body, "摸摸墙下的水印", func(): close_modal(); story.note("手指上只沾到墙灰。水印是旧的。"); refresh_ui())
			"xu":
				button(modal_body, "闲谈 · 她为什么还在等", func(): close_modal(); story.note("阿禾：周伯说今晚别去河边。你为什么还在等？\n许宁：因为他说别去的时候，没说那里什么都没有。"); refresh_ui())
				if story.has("lamp") and story.has("bell"): act_button("告诉她棚里的灯罩与缺舌铜钟，问她愿不愿一起查", "exchange")
			"timetable", "lamp", "bell", "inscription":
				act_button("现场检查与记录", target)
				if target == "bell":
					act_button("察看钟座背面刻记", "mark")
					if story.item("拆下的铜舌"): act_button("将取出的铜片挂回钟腹", "install_tongue")
				if target == "lamp" and story.flag("consent"):
					if not story.flag("shade_off"): act_button("扶稳灯，松开外罩卡扣", "remove_shade")
					elif not story.flag("tongue_taken"): act_button("解开罩内的棉线，取出铜片", "retrieve_tongue")
				if target == "inscription" and story.flag("consent") and story.s.phase == "dusk":
					if story.s.identity == "he" and story.item("手提黄灯") and not story.flag("swapped"): act_button("把借来的黄灯安在等候的位置，暂不点亮", "swap")
					button(modal_body, "等天暗再点灯（现在不结束傍晚）", func(): close_modal(); story.note("灯的位置已经可以安排，火要等暗下来再点。你还可以回街上、看旧屋，或准备好后主动确认入夜；钟和灯不会重置。"); refresh_ui())
				if target == "inscription" and story.s.phase == "night" and story.flag("consent"):
					button(modal_body, "将黄灯留在等候的位置，点亮灯芯", func(): confirm("点亮黄灯后仍留在夜里，周伯会到旧阶兑现敲钟的承诺；等你决定才进入次日。现在点亮？", func(): do_action("light_yellow")))
				if target == "lamp" and story.s.phase == "night" and not story.flag("shade_off"):
					if story.s.identity == "he" and not story.flag("swapped"): act_button("用手提黄灯换下白罩（需周伯同意）", "swap")
					button(modal_body, "危险：举白灯回应河声", func():
						var warning := "白灯表示可以登船。河声会借熟人的声音叫人，继续回应可能让它越过岸边界限。确认举灯？"
						if story.s.pollution == 1: warning = "水迹已越过候船棚。再次回应将使渡口失守；你仍可取消，回去分开灯罩、归还钟舌。确认再次举灯？"
						confirm(warning, func(): do_action("danger")))
					button(modal_body, "危险：强行砸坏灯内铜舌", func(): confirm("铜舌承载旧约，破坏后将无法恢复边界，立即导致渡口失守。这不是修复方法。确认破坏？", func(): do_action("break")))
			"zhou":
				button(modal_body, "闲谈 · 明早的渡船", func(): close_modal(); story.note("周伯：最后一班已经走了。明天六点。桥开了，这棚就拆。我还能守几年？她要是回来，看不见灯怎么办？"); refresh_ui())
				if story.s.identity == "he" and story.item("新灯芯"): act_button("交付新灯芯（物品）", "deliver")
				if story.has("inscription"): act_button("问他：黄灯底座写的‘钟声归岸’是什么意思？", "verify")
				if not story.core() and story.has("covenant"):
					button(modal_body, "把目前查到的事告诉周伯", func(): close_modal(); story.note("周伯听完，摇摇头：你说这些都是一回事，可我想知道你在哪儿看见的。\n仍可去现场查看：" + story.missing_sources()); refresh_ui())
				act_button("问他：小满以前坐渡船是什么样？", "zhou_memory")
				if story.has("lamp") and story.has("timetable"):
					act_button("把白罩与通航告示放在一起，讲出自己的猜测", "signal_guess")
				if (story.flag("heard_zhou") or story.flag("signal_compared")) and not story.flag("consent"):
					act_button("说以后自己会一直替他守灯", "promise_forever")
					act_button("提议只把今晚的等候和通航分开，不承诺替任何人守一生", "waiting_plan")
				if story.core() and not story.flag("consent"): act_button("不愿再等，坚持先收白灯", "force")
				if story.flag("forced"): act_button("为强硬干预道歉并重新说明", "apologize")
				if story.s.phase == "night":
					act_button("转述本人意愿，请周伯敲最后一次钟", "farewell_consent")
			"mooring":
				if story.s.phase == "night":
					add_river_choices()
					act_button("请周伯到黄灯旁，让小满自己表达意愿", "xiaoman")
					act_button("询问沈渡是否愿意结束渡程", "shen")
					act_button("经本人同意归还旧物（不销毁）", "return")
					act_button("解缆：让沈渡结束这一程", "untie")
				else: button(modal_body, "查看旧阶", func(): close_modal(); story.note("普通渡船已走。系缆石上留下年复一年的磨痕。准备好后主动确认入夜。"); refresh_ui())
			"ship":
				if story.s.phase == "night" and story.s.identity == "xu": act_button("许宁独有：踏上靠岸侧舷（可随时回岸）", "board")
				else: button(modal_body, "留在岸上", func(): close_modal(); story.note("夜船不公开卖票。阿禾不能凭身份登船；可以调查灯钟，在岸上恢复边界，或明确请许宁协助传话。"); refresh_ui())
			"voices":
				add_river_choices()
				act_button("询问沈渡的摆渡约定与意愿", "shen")
			"departure": button(modal_body, "尚未天亮，继续本段体验", close_modal)
	button(modal_body, "先不做，回到探索", close_modal)

func add_river_choices() -> void:
	act_button("先站住，听河上有什么声音", "listen_river")
	if story.flag("river_heard"):
		act_button("问那张湿纸到底要带什么", "call_paper")
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

func _draw() -> void:
	var night: bool = started and story.s.phase == "night"
	var sky := Color("111f2b") if night else Color("516069")
	draw_rect(Rect2(0, 0, 855, 800), sky)
	draw_rect(Rect2(20, 155, 820, 480), Color("383f3f") if night else Color("75756a"))
	draw_rect(Rect2(40, 175, 780, 445), Color("363c39") if night else Color("858373"))
	for i in range(10):
		draw_line(Vector2(50, 190 + i * 44), Vector2(810, 190 + i * 44), Color(0.8, 0.82, 0.74, 0.07), 1)
	draw_string(font, Vector2(30, 45), "末班渡船", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("eee4c9"))
	if not started:
		draw_string(font, Vector2(32, 98), "河岸不催你作答。先走近，看看他们的生活。", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("bfcac7"))
		return
	draw_string(font, Vector2(32, 95), Story.PLACES[story.s.place], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e0d5b4"))
	draw_string(font, Vector2(32, 130), "道路范围：石色地面　圆环：可交互　门形：地点连接", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bac5c3"))
	match story.s.place:
		"street":
			draw_rect(Rect2(130, 175, 265, 120), Color("554b44"))
			draw_rect(Rect2(138, 165, 250, 25), Color("4e645d"))
			draw_string(font, Vector2(175, 228), "陶记杂货", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e1cfa6"))
			if story.s.ending == "flood":
				draw_rect(Rect2(695, 315, 18, 160), Color("b68a59"))
				draw_string(font, Vector2(550, 180), "渡口停航 · 安全撤离", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e3c29f"))
		"house":
			draw_rect(Rect2(210, 185, 220, 110), Color("5b5045"))
			draw_rect(Rect2(40, 175, 780, 12), Color("a29376"))
			var basin_pos := player + Vector2(15, -8) if story.flag("basin_carried") else (Vector2(450, 340) if story.flag("basin_placed") else Vector2(600, 250))
			draw_circle(basin_pos, 24, Color("a5b4b5"))
			draw_circle(basin_pos, 17, Color("515f64"))
			draw_circle(Vector2(450, 340), 10, Color("5a777b"))
			draw_line(Vector2(445, 187), Vector2(450, 325), Color(0.7, 0.8, 0.8, 0.45), 1)
		"shelter":
			draw_rect(Rect2(350, 285, 100, 70), Color("5f4e3e"))
			draw_line(Vector2(76, 190), Vector2(770, 190), Color("ad9672"), 10)
			for x in [80, 770]: draw_line(Vector2(x, 190), Vector2(x, 450), Color("6b5a46"), 12)
			var lamp_color := Color("e9bd5d") if story.flag("shade_off") or story.flag("swapped") else Color("e5edf0")
			draw_circle(Vector2(250, 360), 45, Color(lamp_color, 0.08))
			draw_circle(Vector2(250, 360), 14, lamp_color)
			draw_circle(Vector2(620, 390), 12, Color("f7d276") if story.flag("yellow_lit") else Color("77654a"))
			draw_arc(Vector2(550, 240), 22, PI, TAU, 24, Color("b49b6c"), 4)
			if story.flag("tongue_home"): draw_line(Vector2(550, 223), Vector2(550, 253), Color("c4a26a"), 5)
			if story.item("拆下的铜舌"): draw_line(player + Vector2(12, -8), player + Vector2(12, 12), Color("c4a26a"), 4)
			if story.flag("shade_off"): draw_rect(Rect2(275, 375, 28, 19), Color("d4d8d6"), false, 3)
			if story.s.pollution > 0: draw_rect(Rect2(90, 478, 690, 100), Color(0.2, 0.36, 0.4, 0.55))
		"steps":
			draw_rect(Rect2(40, 175, 780, 135), Color("223d4a"))
			for i in range(7):
				draw_line(Vector2(55, 188 + i * 16), Vector2(805, 188 + i * 16), Color("36505b"), 2)
			for i in range(4): draw_line(Vector2(60, 310 + i * 34), Vector2(810, 310 + i * 34), Color("a3a69b"), 3)
			if story.s.phase == "night":
				draw_colored_polygon(PackedVector2Array([Vector2(565, 230), Vector2(810, 230), Vector2(777, 300), Vector2(605, 300)]), Color("332e2b"))
				draw_line(Vector2(460, 295), Vector2(625, 275), Color("baab87"), 3)
		"boat":
			draw_rect(Rect2(40, 175, 780, 445), Color("403d37"))
			for i in range(10): draw_line(Vector2(55 + i * 80, 180), Vector2(55 + i * 80, 610), Color("746957"), 2)
			draw_rect(Rect2(260, 195, 240, 80), Color("353733"))
			for i in range(6): draw_circle(Vector2(290 + i * 35, 220), 7, Color("9a8c71"))
	for obj in scene_objects:
		var pos: Vector2 = obj.pos
		var color := Color("9ba89c")
		if obj.kind == "gate":
			color = Color("a9bdc0")
			draw_rect(Rect2(pos - Vector2(22, 24), Vector2(44, 48)), Color("4e6268"), false, 3)
		elif obj.kind == "npc":
			draw_circle(pos - Vector2(0, 9), 11, Color("bba58c"))
			draw_rect(Rect2(pos + Vector2(-12, 4), Vector2(24, 25)), Color("556d70"))
		else:
			draw_circle(pos, 7, Color("c1b18a"))
		draw_arc(pos, 33, 0, TAU, 32, Color(color, 0.6), 1.5)
		if obj.id == nearest: draw_arc(pos, 40, 0, TAU, 32, Color("f2d68b"), 3)
		draw_string(font, pos + Vector2(-64, 59), obj.title, HORIZONTAL_ALIGNMENT_LEFT, 175, 17, Color("ebe5d0"))
	draw_circle(player + Vector2(0, 14), 18, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(player - Vector2(10, 3), Vector2(20, 24)), Color("bf8f62") if story.s.identity == "xu" else Color("7eb2a0"))
	draw_circle(player - Vector2(0, 10), 10, Color("ead1ac"))
	draw_line(player, player + face * 20, Color("f1dbad"), 3)
	for i in range(4):
		var r := Rect2(280 + i * 70, 650, 65, 55)
		draw_rect(r, Color("384c54"))
		draw_string(font, r.position + Vector2(23, 36), ["←", "↑", "↓", "→"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ddd8bc"))
