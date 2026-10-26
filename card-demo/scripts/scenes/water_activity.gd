extends Control
const ExplorationTools = preload("res://scripts/scenes/exploration_tools.gd")
var exploration_tools: ExplorationTools
const Underwater = preload("res://scripts/scenes/underwater_exploration.gd")
var dive_shoal := false
var dive_sonar := false
var dive_core := false
var dive_archived := false
var dive_layer: CanvasLayer
var dive_view: Control
var dive_button: Button
var records_button: Button
var prior_focus: Control

func _sea_window_open() -> bool:
	for child in get_children():
		if child is Window and child.visible:
			return true
	return false

func _sea_modal() -> bool:
	if is_instance_valid(dive_layer):
		return true
	if is_instance_valid(exploration_tools) and exploration_tools.is_open():
		return true
	for child in get_children():
		if child is Window and child.visible:
			return true
	return false

func _open_dive(records := false) -> void:
	if _sea_modal() or at_salt or at_wreck or sailing:
		return
	prior_focus = get_viewport().gui_get_focus_owner()
	moving = false
	model.update_movement(Vector2.ZERO, 0.0)
	exploration_tools.hide()
	exploration_tools.set_process_input(false)
	dive_layer = CanvasLayer.new()
	dive_layer.layer = 100
	add_child(dive_layer)
	dive_view = Underwater.new()
	dive_view.host = self
	dive_view.read_only = records
	dive_view.returned.connect(_close_dive)
	dive_layer.add_child(dive_view)

func _close_dive() -> void:
	if not is_instance_valid(dive_layer):
		return
	dive_layer.remove_child(dive_view)
	dive_view.queue_free()
	remove_child(dive_layer)
	dive_layer.queue_free()
	dive_layer = null
	dive_view = null
	exploration_tools.show()
	exploration_tools.set_process_input(true)
	moving = false
	result_label.text = "返回浮台：已调查线索保留。" + ("回声核心待归档，请打开探索记录。" if dive_core and not dive_archived else "可打开探索记录回看。")
	if is_instance_valid(prior_focus):
		prior_focus.grab_focus()
	else:
		dive_button.grab_focus()

func _commit_dive(key: String) -> bool:
	if key not in ["dive_shoal", "dive_sonar", "dive_core", "dive_archived"]:
		return false
	if bool(get(key)):
		return true
	if (key == "dive_sonar" and not dive_shoal) or (key == "dive_core" and not dive_sonar) or (key == "dive_archived" and (not dive_core or not is_instance_valid(dive_view) or not dive_view.read_only)):
		return false
	set(key, true)
	result_label.text = "探索记录已归档；深处信号仍未解。" if key == "dive_archived" else "海底发现已记录，返航不会丢失。"
	return _cache_round()

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
const TIDE_WOOD := 3
const TIDE_SCRAP := 3
const CORE_WOOD := 2 # 候选成本，待试玩校准
const CORE_SCRAP := 2 # 候选成本，待试玩校准
const MAX_TILES := 12
const SALT := Rect2(72, 238, 744, 414)
const SALT_INTERVAL := 6.0
const FILTER_SALT := 2
const FILTER_WOOD := 2
const FILTER_SCRAP := 2
const WRECK_INTERVAL := 7.0
const WRECK_HAZARD_INTERVAL := 5.0

var resident := false
var resident_working := false
var partner := false
var blueprint := false
var tide_table := false
var delegated := false
var neighbor_surveyed := false
var at_salt := false
var salt := 0
var filter_blueprint := false
var filter_built := false
var salt_nodes: Array[Vector2] = []
var salt_elapsed := 0.0
var at_wreck := false
var wreck_scrap := 0
var wreck_nodes: Array[Vector2] = []
var wreck_elapsed := 0.0
var hazard_elapsed := 0.0
var wreck_hp := 3
var sail_loadout := ""
var active_loadout := ""
var sailing := false
var sail_hp := 0
var enemy_hp := 0
var braced := false

var wood := 0
var scrap := 0
var water := 0
var fiber := 0
var rope := 0
var raft_tiles := 1
var core_level := 1
var guide_seen_pickup := false
var guide_seen_claim := false
var building_slots: Array = ["core"]
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
var processing_flash := 0.0
var initial_state: Dictionary = {}
var button_hints: Array[Label] = []

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
var resident_button: Button
var job_button: Button
var partner_button: Button
var sail_button: Button
var attack_button: Button
var brace_button: Button
var tide_button: Button
var delegate_button: Button
var survey_button: Button
var return_button: Button
var filter_button: Button
var wreck_button: Button
var wreck_return_button: Button
var hull_button: Button
var weapon_button: Button
var sail_dialog: ConfirmationDialog
var sea_panel: Label
var reset_dialog: ConfirmationDialog
var build_dialog: ConfirmationDialog
var core_button: Button
var guide_button: Button
var build_kind := ""
var build_slot := -1
var slot_picker: OptionButton
var guide_skipped := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_make_button("重开海上档", Vector2(930, 23), Vector2(126, 43), func() -> void: reset_dialog.popup_centered())
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.dialog_text = "只清除海上首章进度（包括蓝图）；灵伴存档与十关完全不变。确定重开？"
	reset_dialog.confirmed.connect(_start_round)
	add_child(reset_dialog)
	var back := _make_button("返回外缘", Vector2(1070, 23), Vector2(138, 43), func() -> void: GameManager.goto_scene("outskirts"))
	back.name = "ReturnButton"
	core_button = _make_button("航站核心", Vector2(858, 136), Vector2(345, 32), func() -> void: _open_build("core"))
	guide_button = _make_button("查看任务板", Vector2(72, 204), Vector2(190, 30), _show_guide)
	_make_button("跳过/恢复聚焦提示", Vector2(267, 204), Vector2(180, 30), func() -> void:
		guide_skipped = not guide_skipped
		_refresh_ui()
	)
	build_dialog = ConfirmationDialog.new()
	build_dialog.title = "基地建造预览"
	build_dialog.min_size = Vector2i(430, 240)
	build_dialog.confirmed.connect(_confirm_build)
	add_child(build_dialog)
	slot_picker = OptionButton.new()
	slot_picker.custom_minimum_size = Vector2(300, 36)
	build_dialog.add_child(slot_picker)
	slot_picker.position = Vector2(20, 105)
	expand_button = _make_button("扩建浮台  -3木料  -2废料", Vector2(858, 263), Vector2(345, 32), _expand_raft)
	collector_button = _make_button("建造集水打捞站  -2木料  -3废料", Vector2(858, 313), Vector2(345, 32), _build_collector)
	claim_button = _make_button("领取产出", Vector2(858, 363), Vector2(345, 32), _claim_production)
	upgrade_button = _make_button("升级站：自动收取  -2木料  -2废料", Vector2(858, 413), Vector2(345, 32), _upgrade_collector)
	workshop_button = _make_button("建造简易工坊  -2木料  -2废料", Vector2(858, 463), Vector2(345, 32), _build_workshop)
	process_button = _make_button("搓制绳索  -1纤维  +1绳索", Vector2(858, 513), Vector2(345, 32), _process_fiber)
	order_button = _make_button("交付委托  -2清水  -2绳索", Vector2(858, 563), Vector2(345, 32), _fulfill_order)
	for button in [expand_button, collector_button, claim_button, upgrade_button, workshop_button, process_button, order_button]:
		var hint := Label.new()
		hint.position = button.position + Vector2(4, 32)
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color("#ffe5a0"))
		add_child(hint)
		button_hints.append(hint)
	var note := Label.new()
	note.text = "建站每4秒产出；海上进度自动保存，航战退出返港。"
	note.position = Vector2(862, 628)
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color("#c9e2de"))
	add_child(note)
	sea_panel = Label.new()
	sea_panel.position = Vector2(860, 88)
	sea_panel.add_theme_font_size_override("font_size", 17)
	sea_panel.add_theme_color_override("font_color", Color("#ffe5a0"))
	add_child(sea_panel)
	resident_button = _make_button("接纳居民阿汐  -1清水", Vector2(72, 665), Vector2(207, 38), _accept_resident)
	job_button = _make_button("安排阿汐集水岗位", Vector2(282, 665), Vector2(195, 38), _assign_resident)
	partner_button = _make_button("信标：邀请伙伴岚", Vector2(480, 665), Vector2(188, 38), _recruit_partner)
	sail_button = _make_button("首航 / 重试预览", Vector2(650, 665), Vector2(164, 38), _open_sail_preview)
	sail_dialog = ConfirmationDialog.new()
	sail_dialog.title = "首航出发预览"
	sail_dialog.confirmed.connect(_begin_sail)
	add_child(sail_dialog)
	hull_button = _make_button("稳固船体 +5生命", Vector2(72, 625), Vector2(205, 32), func() -> void: _choose_loadout("hull"))
	weapon_button = _make_button("增加攻击 +2伤害", Vector2(282, 625), Vector2(205, 32), func() -> void: _choose_loadout("weapon"))
	wreck_button = _make_button("航图：风障废船带", Vector2(492, 625), Vector2(205, 32), _enter_wreck)
	wreck_return_button = _make_button("废船带返港", Vector2(702, 625), Vector2(112, 32), _return_from_wreck)
	attack_button = _make_button("攻击浮礁", Vector2(862, 665), Vector2(106, 38), _sail_attack)
	brace_button = _make_button("防御整备", Vector2(971, 665), Vector2(106, 38), _sail_brace)
	tide_button = _make_button("建潮测台 -3木 -3废", Vector2(860, 172), Vector2(240, 32), _build_tide_table)
	delegate_button = _make_button("委任 / 撤任岚", Vector2(1104, 172), Vector2(110, 32), _toggle_delegate)
	survey_button = _make_button("前往盐雾滩", Vector2(860, 215), Vector2(170, 32), _survey_neighbor)
	return_button = _make_button("带盐晶返港", Vector2(1034, 215), Vector2(180, 32), _return_from_salt)
	filter_button = _make_button("建盐雾过滤架", Vector2(860, 586), Vector2(345, 32), func() -> void: _open_build("filter"))
	if GameManager.water_activity_state.is_empty():
		_start_round()
	else:
		_restore_round(GameManager.water_activity_state)
		initial_state = GameManager.water_activity_state.duplicate(true)
	exploration_tools = ExplorationTools.new()
	exploration_tools.region = "water_activity"
	exploration_tools.modal_blocker = func() -> bool: return is_instance_valid(dive_layer) or _sea_window_open()
	add_child(exploration_tools)
	dive_button = _make_button("下潜 · 海底探索", Vector2(455, 204), Vector2(175, 30), func() -> void: _open_dive())
	records_button = _make_button("探索记录 / 归档", Vector2(637, 204), Vector2(177, 30), func() -> void: _open_dive(true))

func _exit_tree() -> void:
	pass

func _round_state() -> Dictionary:
	return {
		"dive_shoal": dive_shoal, "dive_sonar": dive_sonar, "dive_core": dive_core, "dive_archived": dive_archived,
		"wood": wood, "scrap": scrap, "water": water, "fiber": fiber, "rope": rope,
		"raft_tiles": raft_tiles, "core_level": core_level, "guide_seen_pickup": guide_seen_pickup, "guide_seen_claim": guide_seen_claim, "building_slots": building_slots.duplicate(), "collectors": collectors, "orders_completed": orders_completed,
		"pending_water": pending_water, "pending_fiber": pending_fiber,
		"automated_collecting": automated_collecting, "workshop_built": workshop_built,
		"production_elapsed": production_elapsed, "debris_elapsed": debris_elapsed,
		"player_foot": [player_foot.x, player_foot.y], "debris": debris.map(func(point: Vector2) -> Array: return [point.x, point.y]), "result": result_label.text,
		"resident": resident, "resident_working": resident_working, "partner": partner,
		"blueprint": blueprint, "tide_table": tide_table, "delegated": delegated, "neighbor_surveyed": neighbor_surveyed,
		"at_salt": at_salt, "salt": salt, "filter_blueprint": filter_blueprint, "filter_built": filter_built,
		"salt_nodes": salt_nodes.map(func(point: Vector2) -> Array: return [point.x, point.y]), "salt_elapsed": salt_elapsed,
		"at_wreck": at_wreck, "wreck_scrap": wreck_scrap, "wreck_nodes": wreck_nodes.map(func(point: Vector2) -> Array: return [point.x, point.y]),
		"wreck_elapsed": wreck_elapsed, "hazard_elapsed": hazard_elapsed, "wreck_hp": wreck_hp, "sail_loadout": sail_loadout
	}

func _cache_round() -> bool:
	var old := GameManager.water_activity_state.duplicate(true)
	var state := _round_state()
	if initial_state.is_empty():
		initial_state = state.duplicate(true)
	if GameManager.save_sea_state(state):
		return true
	var error: String = GameManager.sea_save_error
	_restore_round(old if not old.is_empty() else initial_state)
	result_label.text = error
	return false

func _restore_round(state: Dictionary) -> void:
	dive_shoal = state.get("dive_shoal", false)
	dive_sonar = state.get("dive_sonar", false)
	dive_core = state.get("dive_core", false)
	dive_archived = state.get("dive_archived", false)
	wood = state["wood"]
	scrap = state["scrap"]
	water = state["water"]
	fiber = state["fiber"]
	rope = state["rope"]
	raft_tiles = state["raft_tiles"]
	core_level = int(state.get("core_level", 1))
	guide_seen_pickup = bool(state.get("guide_seen_pickup", false))
	guide_seen_claim = bool(state.get("guide_seen_claim", false))
	building_slots = state.get("building_slots", ["core"]).duplicate()
	collectors = state["collectors"]
	orders_completed = state["orders_completed"]
	pending_water = state["pending_water"]
	pending_fiber = state["pending_fiber"]
	automated_collecting = state["automated_collecting"]
	workshop_built = state["workshop_built"]
	production_elapsed = state["production_elapsed"]
	debris_elapsed = state["debris_elapsed"]
	player_foot = Vector2(state.player_foot[0], state.player_foot[1])
	debris.clear()
	for point in state.debris:
		debris.append(Vector2(point[0], point[1]))
	resident = state.resident
	resident_working = state.resident_working
	partner = state.partner
	blueprint = state.blueprint
	tide_table = state.tide_table
	delegated = state.delegated
	neighbor_surveyed = state.neighbor_surveyed
	at_salt = bool(state.get("at_salt", false))
	salt = int(state.get("salt", 0))
	filter_blueprint = bool(state.get("filter_blueprint", false))
	filter_built = bool(state.get("filter_built", false))
	salt_elapsed = float(state.get("salt_elapsed", 0.0))
	salt_nodes.clear()
	for point in state.get("salt_nodes", []):
		salt_nodes.append(Vector2(point[0], point[1]))
	at_wreck = bool(state.get("at_wreck", false))
	wreck_scrap = int(state.get("wreck_scrap", 0))
	wreck_elapsed = float(state.get("wreck_elapsed", 0.0))
	hazard_elapsed = float(state.get("hazard_elapsed", 0.0))
	wreck_hp = int(state.get("wreck_hp", 3))
	sail_loadout = str(state.get("sail_loadout", ""))
	wreck_nodes.clear()
	for point in state.get("wreck_nodes", []):
		wreck_nodes.append(Vector2(point[0], point[1]))
	active_loadout = ""
	sailing = false
	model.position = player_foot
	result_label.text = GameManager.sea_save_error if GameManager.sea_save_error != "" else state["result"]
	_refresh_ui()

func _make_button(text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position_value
	button.size = size_value
	button.pressed.connect(func() -> void:
		if not _sea_modal(): action.call()
	)
	add_child(button)
	return button

func _start_round() -> void:
	_close_dive()
	dive_shoal = false
	dive_sonar = false
	dive_core = false
	dive_archived = false
	resident = false
	resident_working = false
	partner = false
	blueprint = false
	tide_table = false
	delegated = false
	neighbor_surveyed = false
	at_salt = false
	salt = 0
	filter_blueprint = false
	filter_built = false
	salt_nodes.clear()
	salt_elapsed = 0.0
	at_wreck = false
	wreck_scrap = 0
	wreck_nodes.clear()
	wreck_elapsed = 0.0
	hazard_elapsed = 0.0
	wreck_hp = 3
	sail_loadout = ""
	active_loadout = ""
	sailing = false
	wood = 0
	scrap = 0
	water = 0
	fiber = 0
	rope = 0
	raft_tiles = 1
	core_level = 1
	guide_seen_pickup = false
	guide_seen_claim = false
	building_slots = ["core"]
	guide_skipped = false
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
	processing_flash = 0.0
	result_label.text = "走近水面漂浮物自动打捞；收集五份可扩建浮台并建造第一座站。"
	_refresh_ui()
	if GameManager.water_activity_state.is_empty():
		initial_state = _round_state()
	_cache_round()

func _accept_resident() -> bool:
	if resident or collectors == 0 or water < 1 or at_salt or at_wreck:
		return false
	water -= 1
	resident = true
	result_label.text = "阿汐入住：基础需求清水1已满足；可安排集水岗位。"
	_refresh_ui()
	return _cache_round()

func _assign_resident() -> bool:
	if not resident or resident_working or collectors == 0 or at_salt or at_wreck:
		return false
	resident_working = true
	result_label.text = "阿汐在岗：每批集水额外+1（纤维不变）。"
	_refresh_ui()
	return _cache_round()

func _recruit_partner() -> bool:
	if partner or not resident_working or orders_completed < 1 or at_salt or at_wreck:
		return false
	partner = true
	result_label.text = "修好信标，剧情伙伴岚加入；首航可出发。"
	_refresh_ui()
	return _cache_round()

func _choose_loadout(choice: String) -> void:
	if sailing or at_salt or at_wreck or choice not in ["hull", "weapon"]:
		return
	sail_loadout = choice
	result_label.text = "首航准备：%s；出发前可改选。" % ("稳固船体（生命14，攻击3）" if choice == "hull" else "增加攻击（生命9，攻击5）")
	_refresh_ui()
	_cache_round()

func _open_sail_preview() -> void:
	if sail_button.disabled:
		return
	sail_dialog.dialog_text = "已选：%s。\n消耗清水1、绳索1；库存清水%d、绳索%d。\n敌浮礁生命9，攻击回合反击4，防御回合反击1。\n失利补给不返还，可返港调整准备重试；首胜蓝图仅领一次。" % ["稳固船体：生命14／攻击3" if sail_loadout == "hull" else "增加攻击：生命9／攻击5", water, rope]
	sail_dialog.popup_centered()

func _begin_sail() -> bool:
	if sailing or at_salt or at_wreck or sail_loadout not in ["hull", "weapon"] or not partner or not resident_working or water < 1 or rope < 1:
		return false
	water -= 1
	rope -= 1
	sailing = true
	active_loadout = sail_loadout
	sail_hp = 14 if active_loadout == "hull" else 9
	enemy_hp = 9
	braced = false
	result_label.text = "首航出发：%s；选择攻击或防御，攻击后承受反击。" % ("稳固船体" if active_loadout == "hull" else "增加攻击")
	_refresh_ui()
	if not _cache_round():
		sailing = false
		return false
	return true

func _sail_attack() -> bool:
	if not sailing:
		return false
	var dealt := 5 if active_loadout == "weapon" else 3
	enemy_hp = maxi(0, enemy_hp - dealt)
	result_label.text = "攻击造成%d伤害；浮礁剩余%d/9。" % [dealt, enemy_hp]
	if enemy_hp == 0:
		sailing = false
		var first := not blueprint
		blueprint = true
		result_label.text = "首航胜利！" + ("首次取得潮测台蓝图；核心需3级且有连接空位才可建造。" if first else "蓝图已领过，本次无重复奖励。")
		_refresh_ui()
		return _cache_round()
	_sail_retaliate()
	return true

func _sail_brace() -> bool:
	if not sailing:
		return false
	braced = true
	result_label.text = "岚掩护防御；敌浮礁来袭，伤害减为1。"
	_sail_retaliate()
	return true

func _sail_retaliate() -> void:
	var damage := 1 if braced else 4
	sail_hp = maxi(0, sail_hp - damage)
	braced = false
	if sail_hp == 0:
		sailing = false
		result_label.text = "首航失利，返回港口。补给不返还；可改选船体或攻击、生产补给重试；蓝图不会丢失。"
	else:
		result_label.text += " 浮礁反击%d；船体%d/%d，浮礁%d/9。" % [damage, sail_hp, 14 if active_loadout == "hull" else 9, enemy_hp]
	_refresh_ui()

func _build_tide_table() -> bool:
	_open_build("tide")
	return false

func _toggle_delegate() -> bool:
	if not tide_table or not partner or sailing or at_salt or at_wreck:
		return false
	delegated = not delegated
	result_label.text = "岚已委任：每批额外+1清水。" if delegated else "岚已撤任：恢复基础产能。"
	_refresh_ui()
	return _cache_round()

func _survey_neighbor() -> bool:
	if not tide_table or at_salt or at_wreck or sailing:
		return false
	at_salt = true
	neighbor_surveyed = true
	player_foot = Vector2(180, 520)
	moving = false
	if salt_nodes.is_empty():
		salt_nodes = [Vector2(260, 365), Vector2(620, 390), Vector2(530, 565)]
	result_label.text = "抵达盐雾滩：靠近紫白色盐晶采集；盐晶会重新析出，带回港口解锁过滤架图纸。"
	model.position = player_foot
	_refresh_ui()
	return _cache_round()

func _return_from_salt() -> bool:
	if not at_salt:
		return false
	at_salt = false
	player_foot = Vector2(240, 480)
	moving = false
	var first := salt > 0 and not filter_blueprint
	if first:
		filter_blueprint = true
	result_label.text = "带盐晶返港！首次成功探索，永久取得盐雾过滤架图纸。" if first else "返回港口；盐晶库存保留，可再次探索采集。"
	model.position = player_foot
	_refresh_ui()
	return _cache_round()

func _enter_wreck() -> bool:
	if at_wreck or at_salt or sailing:
		return false
	at_wreck = true
	wreck_hp = 3
	hazard_elapsed = 0.0
	player_foot = Vector2(180, 520)
	moving = false
	if wreck_nodes.is_empty():
		wreck_nodes = [Vector2(265, 365), Vector2(620, 395), Vector2(525, 555)]
	result_label.text = "风障废船带：靠近锈红船骸拾取废料+2；阵风每5秒损船体1，耗尽自动返港。"
	model.position = player_foot
	_refresh_ui()
	return _cache_round()

func _return_from_wreck() -> bool:
	if not at_wreck:
		return false
	at_wreck = false
	player_foot = Vector2(240, 480)
	moving = false
	model.position = player_foot
	result_label.text = "废船带返港；已带回废料%d，安全浅滩仍可持续打捞木废。" % wreck_scrap
	_refresh_ui()
	return _cache_round()

func _collect_wreck() -> void:
	for i in range(wreck_nodes.size() - 1, -1, -1):
		if player_foot.distance_to(wreck_nodes[i]) <= PICKUP_RADIUS:
			wreck_nodes.remove_at(i)
			scrap += 2
			wreck_scrap += 2
			result_label.text = "拾取锈船废料+2（累计%d）；小心阵风，剩余船体%d/3。" % [wreck_scrap, wreck_hp]
			_refresh_ui()
			if not _cache_round():
				break

func _collect_salt() -> void:
	for i in range(salt_nodes.size() - 1, -1, -1):
		if player_foot.distance_to(salt_nodes[i]) <= PICKUP_RADIUS:
			salt_nodes.remove_at(i)
			salt += 1
			result_label.text = "采得盐晶 +1（库存%d）；返港后可用于过滤架。" % salt
			_refresh_ui()
			if not _cache_round():
				break

func _collect_nearby() -> void:
	for i in range(debris.size() - 1, -1, -1):
		if player_foot.distance_to(debris[i]) <= PICKUP_RADIUS:
			debris.remove_at(i)
			wood += 1
			scrap += 1
			var first := not guide_seen_pickup
			guide_seen_pickup = true
			result_label.text = "首次打捞：查看上方库存，再攒3木2废扩甲板。" if first else "打捞成功：获得1木料、1废料。"
			_refresh_ui()
			if not _cache_round():
				break

func _expand_raft() -> bool:
	_open_build("expand")
	return false

func _build_collector() -> bool:
	_open_build("collector")
	return false

func _tick_production(delta: float) -> void:
	if collectors == 0 or at_salt or at_wreck:
		return
	production_elapsed += maxf(delta, 0.0)
	var cycles := int(production_elapsed / PRODUCTION_INTERVAL)
	if cycles > 0:
		production_elapsed -= cycles * PRODUCTION_INTERVAL
		var water_gain := cycles * (collectors + int(resident_working) + int(delegated) + int(filter_built))
		if automated_collecting:
			water += water_gain
			if workshop_built:
				rope += cycles * collectors
				processing_flash = 1.0
			else:
				fiber += cycles * collectors
		else:
			pending_water += water_gain
			pending_fiber += cycles * collectors
		result_label.text = "设施已产出 %d 批%s。" % [cycles * collectors, "，自动收取并加工" if workshop_built else ("，自动收取" if automated_collecting else "，等待领取")]
		_refresh_ui()
		_cache_round()

func _claim_production() -> bool:
	if at_salt or at_wreck or automated_collecting or pending_water == 0 and pending_fiber == 0:
		return false
	water += pending_water
	fiber += pending_fiber
	guide_seen_claim = true
	result_label.text = "领取产出：清水 +%d，纤维 +%d；搓绳后交基础发展订单。" % [pending_water, pending_fiber]
	pending_water = 0
	pending_fiber = 0
	_refresh_ui()
	return _cache_round()

func _upgrade_collector() -> bool:
	if at_salt or at_wreck or collectors == 0 or automated_collecting or orders_completed < 1 or wood < UPGRADE_WOOD or scrap < UPGRADE_SCRAP:
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
	return _cache_round()

func _build_workshop() -> bool:
	_open_build("workshop")
	return false

func _process_fiber() -> bool:
	if fiber < 1 or at_salt or at_wreck:
		return false
	fiber -= 1
	rope += 1
	result_label.text = "加工完成：1纤维制成1绳索。"
	_refresh_ui()
	return _cache_round()

func _fulfill_order() -> bool:
	if at_salt or at_wreck or water < ORDER_WATER or rope < ORDER_ROPE:
		return false
	water -= ORDER_WATER
	rope -= ORDER_ROPE
	wood += 2
	scrap += 2
	orders_completed += 1
	if orders_completed == 1:
		result_label.text = "首单完成！奖励木料、废料各2；航站核心现可升2级，站点也可升级自动收取。"
	elif orders_completed == 2:
		result_label.text = "第二单完成！奖励木料、废料各2；现在可建工坊自动加工。"
	else:
		result_label.text = "委托完成！获得2木料、2废料，可以继续经营。"
	_refresh_ui()
	return _cache_round()

func _build_reason(kind: String) -> String:
	var missing := PackedStringArray()
	if kind == "core":
		if core_level >= 3:
			return "核心已达3级"
		if orders_completed < (1 if core_level == 1 else 2):
			missing.append("先完成%s（交清水2、绳索2）" % ("首单" if core_level == 1 else "第二单／出航发展目标"))
	elif kind == "expand":
		if raft_tiles >= MAX_TILES:
			return "甲板已满（12格）"
	elif kind == "workshop":
		if workshop_built:
			return "工坊已建成"
		if core_level < 2:
			missing.append("需核心2级：首单后升核心")
		if orders_completed < 2:
			missing.append("需第二单解锁工坊")
		if not automated_collecting:
			missing.append("先升级站点自动收取")
	elif kind == "tide":
		if tide_table:
			return "潮测台已建成"
		if core_level < 3:
			missing.append("需核心3级：第二单后升核心")
		if not blueprint:
			missing.append("需首航胜利蓝图")
	elif kind == "filter":
		if filter_built:
			return "过滤架已建成"
		if core_level < 3:
			missing.append("需核心3级")
		if not filter_blueprint:
			missing.append("需携盐晶首次返港取得图纸")
		if salt < FILTER_SALT:
			missing.append("缺盐晶%d（盐雾滩可重复采集）" % (FILTER_SALT - salt))
	if kind in ["collector", "workshop", "tide", "filter"] and not building_slots.has("empty"):
		missing.append("无连接空位：先扩甲板")
	var cost := _build_cost(kind)
	if wood < cost.x or scrap < cost.y:
		missing.append("缺木%d、废%d（水面漂浮物每6秒补充）" % [maxi(0, int(cost.x) - wood), maxi(0, int(cost.y) - scrap)])
	return "；".join(missing)

func _build_cost(kind: String) -> Vector2i:
	match kind:
		"core": return Vector2i(CORE_WOOD, CORE_SCRAP)
		"expand": return Vector2i(EXPAND_WOOD, EXPAND_SCRAP)
		"collector": return Vector2i(COLLECTOR_WOOD, COLLECTOR_SCRAP)
		"workshop": return Vector2i(WORKSHOP_WOOD, WORKSHOP_SCRAP)
		"tide": return Vector2i(TIDE_WOOD, TIDE_SCRAP)
		"filter": return Vector2i(FILTER_WOOD, FILTER_SCRAP)
	return Vector2i.ZERO

func _open_build(kind: String) -> void:
	if sailing or at_salt or at_wreck:
		return
	build_kind = kind
	var names := {"core": "航站核心", "expand": "扩建甲板", "collector": "集水打捞站", "workshop": "简易工坊", "tide": "潮测台", "filter": "盐雾过滤架"}
	var cost := _build_cost(kind)
	var reason := _build_reason(kind)
	slot_picker.visible = kind in ["collector", "workshop", "tide", "filter"]
	slot_picker.clear()
	if slot_picker.visible:
		for i in range(1, building_slots.size()):
			if building_slots[i] == "empty":
				slot_picker.add_item("连接位 %d（空）" % i, i)
	build_dialog.dialog_text = "%s%s\n需木%d、废%d%s；库存木%d、废%d、盐晶%d。\n\n\n%s" % [names[kind], " %d→%d级；解锁%s" % [core_level, core_level + 1, "工坊目录" if core_level == 1 else "潮测台等级资格"] if kind == "core" and core_level < 3 else "", cost.x, cost.y, "、盐晶2" if kind == "filter" else "", wood, scrap, salt, "可确认；取消不扣料。" if reason == "" else "锁定：" + reason]
	build_dialog.get_ok_button().disabled = reason != ""
	build_dialog.popup_centered()

func _confirm_build() -> void:
	var kind := build_kind
	if _build_reason(kind) != "" or sailing or at_salt or at_wreck:
		return
	var slot := -1
	if kind in ["collector", "workshop", "tide", "filter"]:
		if slot_picker.selected < 0:
			return
		slot = slot_picker.get_item_id(slot_picker.selected)
		if slot <= 0 or slot >= building_slots.size() or building_slots[slot] != "empty":
			return
	var cost := _build_cost(kind)
	wood -= cost.x
	scrap -= cost.y
	match kind:
		"core":
			core_level += 1
			result_label.text = "航站核心升至%d级；%s。" % [core_level, "工坊目录已解锁" if core_level == 2 else "潮测台等级资格已解锁；还需首航蓝图"]
		"expand":
			raft_tiles += 1
			building_slots.append("empty")
			result_label.text = "浮台扩建完成，新增连接空位%d；可选择空位建造。" % (raft_tiles - 1)
		"collector":
			collectors += 1
			result_label.text = "连接位%d建成集水站；每4秒产出，请手动领取。" % slot
		"workshop":
			workshop_built = true
			processing_flash = 1.0
			rope += fiber
			fiber = 0
			result_label.text = "连接位%d建成工坊：现有纤维已加工，此后自动制绳。" % slot
		"tide":
			tide_table = true
			result_label.text = "连接位%d建成潮测台；现在可以前往盐雾滩。" % slot
		"filter":
			salt -= FILTER_SALT
			filter_built = true
			result_label.text = "连接位%d建成盐雾过滤架；每批集水额外+1清水。" % slot
	if slot >= 0:
		building_slots[slot] = kind
	_refresh_ui()
	_cache_round()

func _guide_step() -> String:
	if not guide_seen_pickup:
		return "靠近水面漂浮物打捞第一份木料和废料；WASD或点击水域移动。"
	if raft_tiles == 1:
		return "看上方库存：攒木3废2，点右侧扩建甲板；材料来自水面反复打捞。"
	if collectors == 0:
		return "右侧建集水站：需木2废3，选择甲板连接空位；不够就继续打捞。"
	if not guide_seen_claim:
		return "等站点每4秒产出，点击右侧『领取产出』；首次必须手领。"
	if orders_completed == 0:
		return "纤维搓绳，攒清水2、绳索2交第一单；站点持续生产。"
	if core_level == 1:
		return "点右侧航站核心升2级，需木2废2（候选）和已完成首单；解锁工坊目录。"
	if core_level == 2 and orders_completed < 2:
		return "工坊目录已解锁！现在完成第二单，为核心3级解锁资格。"
	if core_level == 2:
		return "完成第二单后升核心3级（木2废2）；工坊可在目录另行建造。"
	if not tide_table:
		return "核心3级：首航取蓝图，扩空位建潮测台，开启盐雾滩。"
	if not filter_blueprint:
		return "进入盐雾滩采盐晶，带至少1枚返港，解锁过滤架图纸。"
	if not filter_built:
		return "攒盐晶2、木2、废2，扩空位后建过滤架，每批清水+1。"
	return "过滤架已建成；盐雾滩可重复采盐，集水每批额外+1。"

func _show_guide() -> void:
	var popup := AcceptDialog.new()
	popup.title = "海上任务板 / 基础操作"
	popup.dialog_text = "当前唯一目标：%s\n\n库存显示在左上；木废来自近岸水面每6秒补充的漂浮物。\n右侧可点击航站核心、扩甲板或建筑目录查看等级／蓝图／任务／材料／空位缺口。\n跳过聚焦提示：%s；任务板始终可回看。" % [_guide_step(), "是" if guide_skipped else "否"]
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)

func _refresh_ui() -> void:
	status_label.text = "木 %d   废 %d   盐晶 %d   清水 %d   纤维 %d   绳索 %d   待领水/纤维 %d/%d" % [wood, scrap, salt, water, fiber, rope, pending_water, pending_fiber]
	core_button.text = "航站核心 %d级 · 点击预览升级" % core_level
	core_button.disabled = sailing or at_salt or at_wreck
	guide_button.text = "任务板 · 查看下一步"
	goal_label.text = "任务板可回看 · 点击查看当前目标" if guide_skipped else "当前目标：" + _guide_step()
	expand_button.disabled = sailing or at_salt or at_wreck
	collector_button.disabled = sailing or at_salt or at_wreck
	claim_button.disabled = at_salt or at_wreck or automated_collecting or pending_water == 0 and pending_fiber == 0
	upgrade_button.disabled = at_salt or at_wreck or collectors == 0 or automated_collecting or orders_completed < 1 or wood < UPGRADE_WOOD or scrap < UPGRADE_SCRAP
	workshop_button.disabled = sailing or at_salt or at_wreck
	process_button.disabled = at_salt or at_wreck or fiber < 1
	order_button.disabled = at_salt or at_wreck or water < ORDER_WATER or rope < ORDER_ROPE
	button_hints[0].text = _build_reason("expand") if _build_reason("expand") != "" else "可扩建连接空位"
	button_hints[1].text = _build_reason("collector") if _build_reason("collector") != "" else "可选择连接空位"
	button_hints[2].text = "已自动收取" if automated_collecting else ("暂无待领产出（建站后每4秒产出）" if claim_button.disabled else "可领取")
	button_hints[3].text = "先建站" if collectors == 0 else ("完成首单解锁" if orders_completed < 1 else ("已升级" if automated_collecting else ("缺木料 %d、废料 %d" % [maxi(0, UPGRADE_WOOD - wood), maxi(0, UPGRADE_SCRAP - scrap)] if upgrade_button.disabled else "可升级")))
	button_hints[4].text = _build_reason("workshop") if _build_reason("workshop") != "" else "可选择连接空位建造"
	button_hints[5].text = "缺纤维 %d（建站产出后领取）" % maxi(0, 1 - fiber) if process_button.disabled else "可加工"
	button_hints[6].text = "缺清水 %d、绳索 %d" % [maxi(0, ORDER_WATER - water), maxi(0, ORDER_ROPE - rope)] if order_button.disabled else "可交付"
	resident_button.disabled = resident or collectors == 0 or water < 1 or sailing or at_salt or at_wreck
	job_button.disabled = not resident or resident_working or sailing or at_salt or at_wreck
	partner_button.disabled = partner or not resident_working or orders_completed < 1 or sailing or at_salt or at_wreck
	sail_button.disabled = sailing or at_salt or at_wreck or sail_loadout == "" or not partner or not resident_working or water < 1 or rope < 1
	hull_button.disabled = sailing or at_salt or at_wreck
	weapon_button.disabled = sailing or at_salt or at_wreck
	hull_button.text = ("已选 · " if sail_loadout == "hull" else "") + "稳固船体 +5生命"
	weapon_button.text = ("已选 · " if sail_loadout == "weapon" else "") + "增加攻击 +2伤害"
	wreck_button.disabled = sailing or at_salt or at_wreck
	wreck_return_button.disabled = not at_wreck
	attack_button.disabled = not sailing
	brace_button.disabled = not sailing
	tide_button.disabled = sailing or at_salt or at_wreck
	tide_button.tooltip_text = _build_reason("tide") if _build_reason("tide") != "" else "可选择连接位建造"
	delegate_button.disabled = not tide_table or not partner or sailing or at_salt or at_wreck
	survey_button.disabled = not tide_table or at_salt or at_wreck or sailing
	return_button.disabled = not at_salt
	filter_button.disabled = sailing or at_salt or at_wreck
	filter_button.tooltip_text = _build_reason("filter") if _build_reason("filter") != "" else "每批清水+1"
	if at_wreck:
		sea_panel.text = "风障废船带：锈船废料%d · 船体%d/3\n阵风每5秒伤1；废船每7秒再现。返港保留废料。" % [wreck_scrap, wreck_hp]
	elif at_salt:
		sea_panel.text = "盐雾滩：盐晶%d · 地面晶簇%d\n靠近晶簇采集；每6秒再生。点击右侧返港。" % [salt, salt_nodes.size()]
	elif sailing:
		sea_panel.text = "首航进行中：船体%d/%d  浮礁%d/9\n攻击造成%d伤；敌反击4，防御时1。" % [sail_hp, 14 if active_loadout == "hull" else 9, enemy_hp, 5 if active_loadout == "weapon" else 3]
	elif not resident:
		sea_panel.text = "下一目标：建站领水，接纳阿汐（清水1）\n居民岗位：未安排 | 伙伴：未加入"
	elif not resident_working:
		sea_panel.text = "下一目标：安排阿汐集水岗位\n居民需求已供清水1；在岗每批+1清水"
	elif not partner:
		sea_panel.text = "下一目标：完成首单，邀请保底伙伴岚\n阿汐在岗：每批+1清水"
	elif not blueprint:
		sea_panel.text = "下一目标：准备清水和绳索各1，首航取蓝图\n失败可返港补给并重试"
	elif not tide_table:
		sea_panel.text = "潮测台：%s\n近岸打捞可重复获取材料" % ("核心需3级" if core_level < 3 else "蓝图已入册，点击目录查看缺口")
	else:
		sea_panel.text = "潮测台已建 | 岚委任：%s\n盐雾滩%s | 过滤架：%s（每批清水+1）" % ["是" if delegated else "否", "已首探" if filter_blueprint else "待探索", "已建" if filter_built else "未建"]
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _sea_modal():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		if SEA.has_point(point):
			target = Vector2(clampf(point.x, SEA.position.x + 24, SEA.end.x - 24), clampf(point.y, SEA.position.y + 96, SEA.end.y - 12))
			moving = true

func _process(delta: float) -> void:
	if _sea_modal():
		model.update_movement(Vector2.ZERO, 0)
		queue_redraw()
		return
	processing_flash = maxf(0.0, processing_flash - delta)
	wave_elapsed += delta
	if at_wreck:
		wreck_elapsed += maxf(delta, 0.0)
		if wreck_elapsed >= WRECK_INTERVAL:
			wreck_elapsed = fmod(wreck_elapsed, WRECK_INTERVAL)
			for point in [Vector2(265, 365), Vector2(620, 395), Vector2(525, 555)]:
				if wreck_nodes.size() < 3 and not wreck_nodes.has(point) and point.distance_to(player_foot) > PICKUP_RADIUS:
					wreck_nodes.append(point)
					break
			_refresh_ui()
			_cache_round()
		hazard_elapsed += maxf(delta, 0.0)
		if hazard_elapsed >= WRECK_HAZARD_INTERVAL:
			hazard_elapsed = fmod(hazard_elapsed, WRECK_HAZARD_INTERVAL)
			wreck_hp = maxi(0, wreck_hp - 1)
			if wreck_hp == 0:
				_return_from_wreck()
				result_label.text = "阵风击穿船体，已被迫返港；拾得废料保留。"
			else:
				result_label.text = "阵风袭来：船体剩余%d/3；可随时返港。" % wreck_hp
				_refresh_ui()
				_cache_round()
	elif at_salt:
		salt_elapsed += maxf(delta, 0.0)
		if salt_elapsed >= SALT_INTERVAL:
			salt_elapsed = fmod(salt_elapsed, SALT_INTERVAL)
			if salt_nodes.size() < 3:
				for point in [Vector2(260, 365), Vector2(620, 390), Vector2(530, 565)]:
					if not salt_nodes.has(point) and point.distance_to(player_foot) > PICKUP_RADIUS:
						salt_nodes.append(point)
						break
				_refresh_ui()
	else:
		_tick_production(delta)
	if not at_salt and not at_wreck:
		debris_elapsed += delta
	var spawned := false
	if not at_salt and not at_wreck and debris_elapsed >= DEBRIS_INTERVAL:
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
					spawned = true
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
	if at_salt:
		_collect_salt()
	elif at_wreck:
		_collect_wreck()
	else:
		_collect_nearby()
	if spawned:
		_cache_round()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#102e40"))
	draw_rect(SEA.grow(7.0), Color("#d1b988"))
	draw_rect(SEA, Color("#746f77") if at_salt else Color("#263f53") if at_wreck else Color("#176879"))
	if at_wreck:
		for i in 7:
			var mast := Vector2(125 + i * 102, 310 + (i % 2) * 185)
			draw_line(mast, mast + Vector2(42, -40), Color("#83919a"), 5.0)
			draw_line(mast + Vector2(42, -40), mast + Vector2(83, -12), Color("#c2d4dc"), 2.0)
		for point in wreck_nodes:
			draw_colored_polygon(PackedVector2Array([point + Vector2(-23, 10), point + Vector2(-14, -12), point + Vector2(18, -8), point + Vector2(23, 10)]), Color("#ac593d"))
			draw_line(point + Vector2(-8, 0), point + Vector2(12, 0), Color("#e2a474"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(250, 325), "风障废船带 · 锈船废料 +2 · 阵风伤船", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		return
	if at_salt:
		for i in 9:
			var ridge := Vector2(120 + i * 78, 300 + (i % 3) * 95)
			draw_arc(ridge, 43, 0, PI, 16, Color("#d0c7bc"), 5.0)
		for point in salt_nodes:
			draw_colored_polygon(PackedVector2Array([point + Vector2(-18, 12), point + Vector2(-8, -13), point + Vector2(0, 0), point + Vector2(9, -22), point + Vector2(18, 12)]), Color("#e9d9f5"))
			draw_circle(point + Vector2(0, 5), 5, Color("#a579b5"))
		draw_string(ThemeDB.fallback_font, Vector2(305, 326), "盐雾滩 · 紫白晶簇可采集", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		return
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
	for i in mini(raft_tiles, MAX_TILES):
		var center := Vector2(360 + (i % 4) * 81, 374 + (i / 4) * 78)
		draw_rect(Rect2(center, Vector2(72, 68)), Color("#745b40"))
		draw_rect(Rect2(center + Vector2(5, 5), Vector2(62, 58)), Color("#d5b581"))
		var kind: String = building_slots[i]
		if kind == "core":
			draw_circle(center + Vector2(36, 34), 23.0, [Color("#657e88"), Color("#4e9586"), Color("#e5b85f")][core_level - 1])
			draw_string(ThemeDB.fallback_font, center + Vector2(14, 41), "核心%d" % core_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		elif kind == "collector":
			draw_circle(center + Vector2(36, 33), 20.0, Color("#427a81"))
			draw_circle(center + Vector2(36, 33), 13.0, Color("#ace1da"))
			draw_line(center + Vector2(36, 13), center + Vector2(36, 3), Color("#e8f4d5"), 3.0)
		elif kind == "workshop":
			draw_rect(Rect2(center + Vector2(13, 14), Vector2(46, 42)), Color("#a84436"))
			draw_string(ThemeDB.fallback_font, center + Vector2(16, 40), "工坊", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		elif kind == "tide":
			draw_circle(center + Vector2(36, 35), 20.0, Color("#565d9b"))
			draw_string(ThemeDB.fallback_font, center + Vector2(8, 42), "潮测台", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		else:
			draw_string(ThemeDB.fallback_font, center + Vector2(19, 41), "空位%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#625540"))
	if workshop_built and processing_flash > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(492, 340), "工坊加工 +绳索", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#fff0a1"))
