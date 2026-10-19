extends Control
const ExplorationTools = preload("res://scripts/scenes/exploration_tools.gd")
var exploration_tools: ExplorationTools

const HeroWalkScript = preload("res://scripts/scenes/hero_walk_sprite.gd")
const SEA := Rect2(72, 238, 744, 414)
const PLAYER_SPEED := 220.0
const PICKUP_RADIUS := 35.0
const DEBRIS_INTERVAL := 6.0
const MAX_DEBRIS := 5
const PRODUCTION_INTERVAL := 4.0
const EXPAND_WOOD := 3
const EXPAND_SCRAP := 2
const COLLECTOR_WOOD := 2
const COLLECTOR_SCRAP := 3
const ORDER_WATER := 2
const ORDER_ROPE := 2
const UPGRADE_WOOD := 2
const UPGRADE_SCRAP := 2
const WORKSHOP_WOOD := 2
const WORKSHOP_SCRAP := 2

var wood := 0
var scrap := 0
var water := 0
var fiber := 0
var rope := 0
var raft_tiles := 1
var collectors := 0
var orders_completed := 0
var pending_water := 0
var pending_fiber := 0
var automated_collecting := false
var workshop_built := false
var production_elapsed := 0.0
var wave_elapsed := 0.0
var debris_elapsed := 0.0
var player_foot := Vector2(240, 480)
var debris: Array[Vector2] = []
var target := Vector2.ZERO
var moving := false
var model: HeroWalkScript

var status_label: Label
var goal_label: Label
var result_label: Label
var expand_button: Button
var collector_button: Button
var claim_button: Button
var upgrade_button: Button
var workshop_button: Button
var process_button: Button
var order_button: Button

func _ready() -> void:
	model = HeroWalkScript.new()
	model.scale = Vector2(0.18, 0.18)
	add_child(model)
	var title := Label.new()
	title.text = "漂流浮台  /  水上经营"
	title.position = Vector2(72, 23)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f5efd7"))
	add_child(title)
	var rules := Label.new()
	rules.text = "WASD / 方向键或点击水域移动 · 靠近漂浮物拾荒 · 建站、领取产出、加工并交付委托"
	rules.position = Vector2(74, 75)
	rules.add_theme_font_size_override("font_size", 18)
	rules.add_theme_color_override("font_color", Color("#d7f1f0"))
	add_child(rules)
	status_label = Label.new()
	status_label.position = Vector2(75, 120)
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(status_label)
	goal_label = Label.new()
	goal_label.position = Vector2(75, 160)
	goal_label.add_theme_font_size_override("font_size", 19)
	goal_label.add_theme_color_override("font_color", Color("#ffe5a0"))
	add_child(goal_label)
	result_label = Label.new()
	result_label.position = Vector2(75, 194)
	result_label.add_theme_font_size_override("font_size", 17)
	result_label.add_theme_color_override("font_color", Color("#d7f1f0"))
	add_child(result_label)
	_make_button("重新开始", Vector2(938, 23), Vector2(118, 43), _start_round)
	var back := _make_button("返回外缘", Vector2(1070, 23), Vector2(138, 43), func() -> void: GameManager.goto_scene("outskirts"))
	back.name = "ReturnButton"
	expand_button = _make_button("扩建浮台  -3木料  -2废料", Vector2(858, 263), Vector2(345, 44), _expand_raft)
	collector_button = _make_button("建造集水打捞站  -2木料  -3废料", Vector2(858, 313), Vector2(345, 44), _build_collector)
	claim_button = _make_button("领取产出", Vector2(858, 363), Vector2(345, 44), _claim_production)
	upgrade_button = _make_button("升级站：自动收取  -2木料  -2废料", Vector2(858, 413), Vector2(345, 44), _upgrade_collector)
	workshop_button = _make_button("建造简易工坊  -2木料  -2废料", Vector2(858, 463), Vector2(345, 44), _build_workshop)
	process_button = _make_button("搓制绳索  -1纤维  +1绳索", Vector2(858, 513), Vector2(345, 44), _process_fiber)
	order_button = _make_button("交付委托  -2清水  -2绳索", Vector2(858, 563), Vector2(345, 44), _fulfill_order)
	var note := Label.new()
	note.text = "建站后每4秒产出清水、纤维各1；升级前请手动领取。\n委托奖励木料、废料各2；第二单后解锁工坊自动搓绳。\n漂浮物每6秒补充，最多5份；重开/离开仅重置本活动。"
	note.position = Vector2(862, 615)
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color("#c9e2de"))
	add_child(note)
	_start_round()
	exploration_tools = ExplorationTools.new()
	exploration_tools.region = "water_activity"
	add_child(exploration_tools)

func _make_button(text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position_value
	button.size = size_value
	button.pressed.connect(action)
	add_child(button)
	return button

func _start_round() -> void:
	wood = 0
	scrap = 0
	water = 0
	fiber = 0
	rope = 0
	raft_tiles = 1
	collectors = 0
	orders_completed = 0
	pending_water = 0
	pending_fiber = 0
	automated_collecting = false
	workshop_built = false
	production_elapsed = 0.0
	wave_elapsed = 0.0
	debris_elapsed = 0.0
	player_foot = Vector2(240, 480)
	model.position = player_foot
	model.update_movement(Vector2.ZERO, 0.0)
	moving = false
	debris = [Vector2(152, 350), Vector2(295, 590), Vector2(735, 350), Vector2(735, 570), Vector2(148, 575)]
	result_label.text = "走近水面漂浮物自动打捞；收集五份可扩建浮台并建造第一座站。"
	_refresh_ui()

func _collect_debris() -> void:
	wood += 1
	scrap += 1
	result_label.text = "打捞成功：获得1木料、1废料。"
	_refresh_ui()

func _collect_nearby() -> void:
	for i in range(debris.size() - 1, -1, -1):
		if player_foot.distance_to(debris[i]) <= PICKUP_RADIUS:
			debris.remove_at(i)
			_collect_debris()

func _expand_raft() -> bool:
	if wood < EXPAND_WOOD or scrap < EXPAND_SCRAP:
		return false
	wood -= EXPAND_WOOD
	scrap -= EXPAND_SCRAP
	raft_tiles += 1
	result_label.text = "浮台扩建完成，可以在空位建造设施。"
	_refresh_ui()
	return true

func _build_collector() -> bool:
	if collectors >= raft_tiles - 1 or wood < COLLECTOR_WOOD or scrap < COLLECTOR_SCRAP:
		return false
	wood -= COLLECTOR_WOOD
	scrap -= COLLECTOR_SCRAP
	collectors += 1
	result_label.text = "集水打捞站建成，开始定时产出。请点击领取产出。"
	_refresh_ui()
	return true

func _tick_production(delta: float) -> void:
	if collectors == 0:
		return
	production_elapsed += maxf(delta, 0.0)
	var cycles := int(production_elapsed / PRODUCTION_INTERVAL)
	if cycles > 0:
		production_elapsed -= cycles * PRODUCTION_INTERVAL
		if automated_collecting:
			water += cycles * collectors
			if workshop_built:
				rope += cycles * collectors
			else:
				fiber += cycles * collectors
		else:
			pending_water += cycles * collectors
			pending_fiber += cycles * collectors
		result_label.text = "设施已产出 %d 批%s。" % [cycles * collectors, "，自动收取并加工" if workshop_built else ("，自动收取" if automated_collecting else "，等待领取")]
		_refresh_ui()

func _claim_production() -> bool:
	if automated_collecting or pending_water == 0 and pending_fiber == 0:
		return false
	water += pending_water
	fiber += pending_fiber
	result_label.text = "领取产出：清水 +%d，纤维 +%d。" % [pending_water, pending_fiber]
	pending_water = 0
	pending_fiber = 0
	_refresh_ui()
	return true

func _upgrade_collector() -> bool:
	if collectors == 0 or automated_collecting or orders_completed < 1 or wood < UPGRADE_WOOD or scrap < UPGRADE_SCRAP:
		return false
	wood -= UPGRADE_WOOD
	scrap -= UPGRADE_SCRAP
	automated_collecting = true
	water += pending_water
	fiber += pending_fiber
	pending_water = 0
	pending_fiber = 0
	result_label.text = "站点升级完成：已有待领产出一并领取，此后自动收取。"
	_refresh_ui()
	return true

func _build_workshop() -> bool:
	if not automated_collecting or workshop_built or orders_completed < 2 or wood < WORKSHOP_WOOD or scrap < WORKSHOP_SCRAP:
		return false
	wood -= WORKSHOP_WOOD
	scrap -= WORKSHOP_SCRAP
	workshop_built = true
	rope += fiber
	fiber = 0
	result_label.text = "简易工坊建成：现有纤维已加工，此后产出自动制成绳索。"
	_refresh_ui()
	return true

func _process_fiber() -> bool:
	if fiber < 1:
		return false
	fiber -= 1
	rope += 1
	result_label.text = "加工完成：1纤维制成1绳索。"
	_refresh_ui()
	return true

func _fulfill_order() -> bool:
	if water < ORDER_WATER or rope < ORDER_ROPE:
		return false
	water -= ORDER_WATER
	rope -= ORDER_ROPE
	wood += 2
	scrap += 2
	orders_completed += 1
	if orders_completed == 1:
		result_label.text = "首单完成！奖励木料、废料各2；现在可升级站点自动收取。"
	elif orders_completed == 2:
		result_label.text = "第二单完成！奖励木料、废料各2；现在可建工坊自动加工。"
	else:
		result_label.text = "委托完成！获得2木料、2废料，可以继续经营。"
	_refresh_ui()
	return true

func _refresh_ui() -> void:
	status_label.text = "木料 %d    废料 %d    清水 %d    纤维 %d    绳索 %d    待领清水/纤维 %d/%d" % [wood, scrap, water, fiber, rope, pending_water, pending_fiber]
	if collectors == 0:
		goal_label.text = "浮台 %d 格 · 站点 %d 座 · 委托 %d 单 | 先打捞5份，扩建并建站" % [raft_tiles, collectors, orders_completed]
	elif orders_completed == 0:
		goal_label.text = "委托1：清水 %d/%d · 绳索 %d/%d | 手动领取、搓绳并交付" % [water, ORDER_WATER, rope, ORDER_ROPE]
	elif not automated_collecting:
		goal_label.text = "委托1已完成 | 花2木料、2废料升级站点；解锁自动收取"
	elif orders_completed == 1:
		goal_label.text = "委托2：清水 %d/%d · 绳索 %d/%d | 交付后解锁自动加工" % [water, ORDER_WATER, rope, ORDER_ROPE]
	elif not workshop_built:
		goal_label.text = "委托2已完成 | 花2木料、2废料建工坊；解锁自动搓绳"
	else:
		goal_label.text = "已完成委托 %d 单 | 下单：清水 %d/%d · 绳索 %d/%d（自动生产/加工）" % [orders_completed, water, ORDER_WATER, rope, ORDER_ROPE]
	expand_button.disabled = wood < EXPAND_WOOD or scrap < EXPAND_SCRAP
	collector_button.disabled = collectors >= raft_tiles - 1 or wood < COLLECTOR_WOOD or scrap < COLLECTOR_SCRAP
	claim_button.disabled = automated_collecting or pending_water == 0 and pending_fiber == 0
	upgrade_button.disabled = collectors == 0 or automated_collecting or orders_completed < 1 or wood < UPGRADE_WOOD or scrap < UPGRADE_SCRAP
	workshop_button.disabled = not automated_collecting or workshop_built or orders_completed < 2 or wood < WORKSHOP_WOOD or scrap < WORKSHOP_SCRAP
	process_button.disabled = fiber < 1
	order_button.disabled = water < ORDER_WATER or rope < ORDER_ROPE
	queue_redraw()

func _input(event: InputEvent) -> void:
	if exploration_tools.is_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		if SEA.has_point(point):
			target = Vector2(clampf(point.x, SEA.position.x + 24, SEA.end.x - 24), clampf(point.y, SEA.position.y + 96, SEA.end.y - 12))
			moving = true

func _process(delta: float) -> void:
	if exploration_tools.is_open():
		model.update_movement(Vector2.ZERO, 0)
		return
	wave_elapsed += delta
	_tick_production(delta)
	debris_elapsed += delta
	if debris_elapsed >= DEBRIS_INTERVAL:
		debris_elapsed = fmod(debris_elapsed, DEBRIS_INTERVAL)
		if debris.size() < MAX_DEBRIS:
			for attempt in 12:
				var point := Vector2(randf_range(SEA.position.x + 38, SEA.end.x - 38), randf_range(SEA.position.y + 110, SEA.end.y - 30))
				if point.distance_to(player_foot) < 85 or Rect2(340, 355, 345, 180).has_point(point):
					continue
				var spaced := true
				for item in debris:
					if item.distance_to(point) < 65:
						spaced = false
						break
				if spaced:
					debris.append(point)
					break
	var direction := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
	if direction != Vector2.ZERO:
		moving = false
	elif moving:
		if player_foot.distance_to(target) < 4.0:
			moving = false
		else:
			direction = (target - player_foot).normalized()
	var previous_foot := player_foot
	var motion := direction * delta * PLAYER_SPEED
	if moving and motion.length() > player_foot.distance_to(target):
		motion = target - player_foot
	player_foot += motion
	player_foot.x = clampf(player_foot.x, SEA.position.x + 24, SEA.end.x - 24)
	player_foot.y = clampf(player_foot.y, SEA.position.y + 96, SEA.end.y - 12)
	model.position = player_foot
	model.update_movement(player_foot - previous_foot, delta)
	_collect_nearby()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#102e40"))
	draw_rect(SEA.grow(7.0), Color("#d1b988"))
	draw_rect(SEA, Color("#176879"))
	for row in 6:
		for column in 9:
			var x := SEA.position.x + 40.0 + column * 83.0 + sin(wave_elapsed + float(row)) * 6.0
			var y := SEA.position.y + 34.0 + row * 67.0
			draw_arc(Vector2(x, y), 14.0, 0.15, PI - 0.15, 12, Color("#8ed8d0", 0.32), 2.0)
	for point in debris:
		var bob := sin(wave_elapsed * 2.0 + point.x) * 3.0
		var log_rect := Rect2(point + Vector2(-17, -8 + bob), Vector2(34, 16))
		draw_rect(log_rect, Color("#9c6741"))
		draw_rect(Rect2(log_rect.position + Vector2(3, 3), Vector2(28, 10)), Color("#bd9161"))
		draw_line(point + Vector2(-10, bob), point + Vector2(10, bob), Color("#ead3a0"), 2.0)
	for i in mini(raft_tiles, 12):
		var center := Vector2(360 + (i % 4) * 81, 374 + (i / 4) * 78)
		draw_rect(Rect2(center, Vector2(72, 68)), Color("#745b40"))
		draw_rect(Rect2(center + Vector2(5, 5), Vector2(62, 58)), Color("#d5b581"))
		if i > 0 and i <= collectors:
			draw_circle(center + Vector2(36, 33), 20.0, Color("#427a81"))
			draw_circle(center + Vector2(36, 33), 13.0, Color("#ace1da"))
			draw_line(center + Vector2(36, 13), center + Vector2(36, 3), Color("#e8f4d5"), 3.0)
