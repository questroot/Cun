extends Control

signal returned
const FIELD := Rect2(70, 155, 1130, 470)
const RADIUS := 12.0
const SPEED := 230.0
var host: Control
var place := "shoal"
var foot := Vector2(145, 520)
var target := Vector2.ZERO
var moving := false
var elapsed := 0.0
var message := "穿过珊瑚缺口，靠近冷色光迹按 E 调查。"
var read_only := false
var heading: Label
var feedback: Label
var prompt: Label
var close_button: Button
var archive_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	heading = _label(Vector2(70, 30), 30)
	feedback = _label(Vector2(70, 90), 20)
	prompt = _label(Vector2(70, 640), 19)
	close_button = Button.new()
	close_button.text = "关闭记录 / Esc" if read_only else "主动返航 / Esc"
	close_button.position = Vector2(980, 30)
	close_button.size = Vector2(220, 44)
	close_button.pressed.connect(func() -> void: returned.emit())
	add_child(close_button)
	archive_button = Button.new()
	archive_button.text = "在浮台归档回声核心"
	archive_button.position = Vector2(770, 645)
	archive_button.size = Vector2(420, 42)
	archive_button.pressed.connect(func() -> void:
		host._commit_dive("dive_archived")
		refresh()
	)
	add_child(archive_button)
	grab_focus()
	refresh()

func _label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func obstacles() -> Array[Rect2]:
	match place:
		"shoal": return [Rect2(430, 155, 65, 190), Rect2(430, 435, 65, 190)]
		"wreck": return [Rect2(390, 155, 90, 280), Rect2(390, 535, 90, 90), Rect2(480, 155, 570, 70), Rect2(480, 555, 570, 70)]
		"trench": return [Rect2(70, 155, 1130, 175), Rect2(70, 490, 1130, 135), Rect2(960, 155, 240, 470)]
	return []

func can_stand(point: Vector2) -> bool:
	if not FIELD.grow(-RADIUS).has_point(point):
		return false
	for obstacle in obstacles():
		if obstacle.grow(RADIUS).has_point(point):
			return false
	return true

func move_step(motion: Vector2) -> void:
	var steps := maxi(1, int(ceil(motion.length() / 6.0)))
	var step := motion / steps
	for i in steps:
		var next := foot + Vector2(step.x, 0)
		if can_stand(next): foot = next
		next = foot + Vector2(0, step.y)
		if can_stand(next): foot = next

func sites() -> Array:
	match place:
		"shoal": return [["光迹", Vector2(650, 390)], ["船尾航路", Vector2(1080, 490)], ["上浮出口", Vector2(145, 520)]]
		"wreck": return [["声呐台", Vector2(720, 375)], ["海沟入口", Vector2(1080, 480)], ["返回浅滩", Vector2(145, 490)]]
		"trench": return [["回声核心", Vector2(875, 410)], ["返回沉船", Vector2(145, 410)]]
	return []

func interact() -> bool:
	if read_only: return false
	for site in sites():
		if foot.distance_to(site[1]) > 56: continue
		moving = false
		match site[0]:
			"光迹":
				host._commit_dive("dive_shoal")
				message = "光迹指向背面：从船尾进入。线索已记录。" if host.dive_shoal else host.result_label.text
			"船尾航路":
				if not host.dive_shoal: message = "船头封闭。先调查浅滩光迹，确认船尾航路。"
				else: enter("wreck")
			"声呐台":
				host._commit_dive("dive_sonar")
				message = "声呐显示：循间歇光带前往海沟。" if host.dive_sonar else host.result_label.text
			"海沟入口":
				if not host.dive_sonar: message = "缺少海沟方向，请先调查声呐台。"
				else: enter("trench")
			"回声核心":
				host._commit_dive("dive_core")
				message = "唯一回声核心已收好；深处信号隔着断崖无法抵达。请返航归档。" if host.dive_core else host.result_label.text
			"返回浅滩": enter("shoal")
			"返回沉船": enter("wreck")
			"上浮出口": returned.emit()
		refresh()
		return true
	return false

func enter(destination: String) -> void:
	place = destination
	foot = Vector2(145, 410 if place == "trench" else 490)
	moving = false
	message = {"shoal": "珊瑚墙留有缺口；远方沉船船头封闭。", "wreck": "船头堵死，绕下方船尾缺口进入船舱，寻找声呐台。", "trench": "沿窄道与脉动光带前进；断崖对面信号本版不可达。"}[place]
	refresh()

func refresh() -> void:
	if not is_instance_valid(heading): return
	heading.text = "浮台 · 探索记录" if read_only else {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}[place] + " · WASD / 方向键 / 点击移动"
	feedback.text = host.result_label.text if read_only else message
	archive_button.visible = read_only
	archive_button.disabled = not host.dive_core or host.dive_archived
	if read_only:
		prompt.text = "已归档 · 可随时重访" if host.dive_archived else ("带回核心，点击归档完成记录" if host.dive_core else "可提前返航；已调查线索持续保留")
	else:
		prompt.text = "靠近地标按 E 调查 / 出口 · 随时主动返航，线索与核心保留"
		for site in sites():
			if foot.distance_to(site[1]) <= 56: prompt.text = "E · " + site[0]
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: returned.emit()
			elif event.keycode == KEY_E: interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not read_only:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if FIELD.has_point(point):
			target = point
			moving = true
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	elapsed += delta
	if read_only: return
	var direction := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
	if direction != Vector2.ZERO: moving = false
	elif moving:
		if foot.distance_to(target) < 4: moving = false
		else: direction = (target - foot).normalized()
	move_step(direction * minf(delta, 0.05) * SPEED)
	refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071b2b"))
	if read_only:
		var lines := ["珊瑚浅滩：" + ("船舷金属片，光迹指向船尾。" if host.dive_shoal else "尚未调查"), "侧倾沉船：" + ("声呐台记录间歇光带与海沟方向。" if host.dive_sonar else "尚未调查"), "发光海沟：" + ("唯一回声核心已带回。" if host.dive_core else "尚未发现"), "归档：" + ("浅滩 → 船尾声呐 → 海沟核心；深处信号仍未解。" if host.dive_archived else "待取得核心并在浮台归档")]
		for i in lines.size(): draw_string(ThemeDB.fallback_font, Vector2(100, 230 + i * 85), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
		return
	draw_rect(FIELD, {"shoal": Color("#287b88"), "wreck": Color("#193b4a"), "trench": Color("#080e29")}[place])
	for obstacle in obstacles():
		draw_rect(obstacle, {"shoal": Color("#b86f86"), "wreck": Color("#68554e"), "trench": Color("#222940")}[place])
		if place == "shoal":
			for i in 5: draw_circle(obstacle.position + Vector2(32, 20 + i * 35), 23, Color("#d58c99"))
	if place == "shoal":
		draw_colored_polygon(PackedVector2Array([Vector2(825, 235), Vector2(1120, 270), Vector2(1050, 315), Vector2(850, 290)]), Color("#17404f"))
		draw_line(Vector2(960, 270), Vector2(940, 180), Color("#17404f"), 7)
	elif place == "wreck":
		draw_line(Vector2(480, 260), Vector2(1020, 310), Color("#987b62"), 12)
		draw_string(ThemeDB.fallback_font, Vector2(275, 285), "船头堵死", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(350, 510), "船尾缺口 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	else:
		for i in 12:
			var glow := 0.45 + 0.4 * sin(elapsed * 2.5 - i * 0.5)
			draw_circle(Vector2(220 + i * 60, 440), 9, Color(0.25, 0.95, 0.9, glow))
		draw_circle(Vector2(1110, 395), 20 + sin(elapsed * 2) * 5, Color("#7868be"))
		draw_string(ThemeDB.fallback_font, Vector2(975, 460), "断崖 / 深处信号", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for site in sites():
		draw_circle(site[1], 19, Color("#84e6d5"))
		draw_string(ThemeDB.fallback_font, site[1] + Vector2(-45, -30), site[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_circle(foot, RADIUS, Color("#ffe6a4"))
	draw_arc(foot, 20, 0, TAU, 24, Color("#fff4cf"), 2)
