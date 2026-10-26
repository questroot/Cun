extends Control

signal returned
const FIELD := Rect2(70, 155, 1130, 470)
const RADIUS := 12.0
const SPEED := 230.0
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const BAG_RECT := Rect2(300, 220, 680, 310)
var oxygen := Catalog.OXYGEN
var warned := false
var warning_count := 0
var ascending := 0.0
var settling := false
var bag: Array = []
var bag_open := false
var drag_index := -1
var drops: Array = []
var lost_items: Array = []
var lost_count := 0
var pending_core := false
var opening: Dictionary = {}
var opening_left := 0.0
var opening_total := 0.0
var rules_label: Label

func cancel_opening(reason: String) -> void:
	if opening.is_empty(): return
	opening.clear()
	opening_left = 0
	message = "开箱取消：%s；不扣次数、不发奖。" % reason

func start_chest(node: Array) -> void:
	if not opening.is_empty(): return
	var entry: Dictionary = host.node_states[place][node[0]].duplicate()
	Catalog.recover(entry, Time.get_unix_time_from_system())
	if int(entry.stock) <= 0:
		message = "宝箱已开空，等待补充。"
		return
	var slots := Catalog.chest_slots(place, node[0])
	if used_slots() + slots > capacity():
		message = "网袋空间不足：此箱需预留%d格（按最大可能产出）；未开箱、不扣次数。" % slots
		return
	moving = false
	opening = {"map": place, "id": node[0], "position": node[2]}
	opening_total = float(Catalog.CHESTS[Catalog.chest_quality(place, node[0])].seconds)
	opening_left = opening_total
	message = "按一次E已启动开箱，无需按住；移动取消，开启期间继续耗氧。"
	if opening_left == 0: finish_chest()

func finish_chest() -> void:
	if opening.is_empty(): return
	var current := opening.duplicate()
	opening.clear()
	opening_left = 0
	if used_slots() + Catalog.chest_slots(place, current.id) > capacity():
		message = "网袋空间不足；未扣次数、未抽奖。"
		return
	# 只有事务保存成功才计算一次随机结果，失败无奖励也不扣存量。
	var entry: Dictionary = host.node_states[place][current.id].duplicate()
	if not host.gather_node(place, current.id):
		message = "开箱失败：补充中或保存失败；未扣次数、未发奖，可重试。"
		return
	var loot := Catalog.chest_loot(place, current.id, int(entry.stock), float(entry.timestamp))
	bag.append_array(loot)
	message = "宝箱开启：" + settlement_items(loot).replace("\n", "、") + "；暂存网袋，安全上浮才入库。用途："
	for id in loot: message += Catalog.USES[id] + "；"

func tick_opening(delta: float) -> void:
	if opening.is_empty() or not is_finite(delta) or delta <= 0: return
	if place != opening.map or foot.distance_to(opening.position) > 56:
		cancel_opening("离开范围或切图")
		return
	if moving:
		cancel_opening("移动")
		return
	opening_left = maxf(0, opening_left - delta)
	if opening_left == 0: finish_chest()

func _exit_tree() -> void:
	cancel_opening("关闭场景")

func has_core() -> bool:
	return host.dive_core or pending_core
var oxygen_label: Label
var settlement: Dictionary = {}
var settlement_saved := false
var settlement_panel: PanelContainer
var settlement_text: RichTextLabel
var settlement_close: Button
var settlement_records: Button
var settlement_retry: Button

func show_settlement(saved: bool) -> void:
	settlement_saved = saved
	if not is_instance_valid(settlement_panel):
		for child in get_children():
			if child is Control: child.hide()
		settlement_panel = PanelContainer.new()
		settlement_panel.position = Vector2(180, 70)
		settlement_panel.size = Vector2(920, 580)
		add_child(settlement_panel)
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
		settlement_panel.add_child(margin)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		margin.add_child(box)
		var title := Label.new()
		title.text = "氧气耗尽·救援上浮（失败零收益）" if settlement.rescue else "安全上浮"
		title.add_theme_font_size_override("font_size", 28)
		box.add_child(title)
		settlement_text = RichTextLabel.new()
		settlement_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		settlement_text.add_theme_font_size_override("normal_font_size", 22)
		settlement_text.scroll_active = true
		box.add_child(settlement_text)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		box.add_child(buttons)
		settlement_retry = Button.new()
		settlement_retry.text = "重试入库"
		settlement_retry.pressed.connect(host._close_dive)
		buttons.add_child(settlement_retry)
		settlement_records = Button.new()
		settlement_records.text = "查看探索记录 / 显式归档"
		settlement_records.pressed.connect(func() -> void:
			if not settlement_saved: return
			host._dismiss_dive()
			host._open_dive(true))
		buttons.add_child(settlement_records)
		settlement_close = Button.new()
		settlement_close.text = "返回浮台 / Esc"
		settlement_close.pressed.connect(func() -> void:
			if settlement_saved: host._dismiss_dive())
		buttons.add_child(settlement_close)
	var location: String = {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}[settlement.place]
	var lines := PackedStringArray([("耗尽救援 · 本次失败零收益" if settlement.rescue else "安全光柱上浮") + " · " + location, "", ("本次入库" if saved else "待入库网袋") + " · 共%d件：" % settlement.items.size(), settlement_items(settlement.items), "", "全部损失 · 共%d件（不可拾回）：" % settlement.losses.size(), settlement_items(settlement.losses), ""])
	if settlement.rescue:
		lines.append("未安全上浮：本次收获100%不入库，本潜新核心未保留，不能归档领奖；历史仓库、装备及已带回核心不受影响。")
	else:
		lines.append("入库成功 · 已保存，确认关闭不会重复入库。" if saved else "尚未入库 · 保存失败或仓库已满，网袋保留且探索冻结。请重试；不要退出游戏。\n" + host.result_label.text)
	lines.append("线索：浅滩%s / 声呐%s" % ["已记录" if host.dive_shoal else "未调查", "已记录" if host.dive_sonar else "未调查"])
	if host.dive_archived and not host.core_reward_claimed:
		lines.append("核心已归档 · 奖励待补领：打开探索记录，显式补领工坊位＋木2废2。")
	elif host.dive_workshop_built:
		lines.append("核心已归档 · 潜水工坊已建成：返回浮台按C制作或升级装备。")
	elif host.dive_workshop_unlocked:
		lines.append("核心已归档 · 潜水工坊已解锁：返回浮台按C建造（木2废2），再制作装备。")
	elif host.dive_core:
		lines.append("回声核心已取得 · 待归档：查看探索记录后显式归档；本面板不自动领奖。")
	else:
		lines.append("核心尚未取得 · 下一步：" + host._dive_summary())
	if settlement.items.is_empty(): lines.append("本次无收获；不沿用上一潜入库记录。")
	settlement_text.text = "\n".join(lines)
	settlement_retry.visible = not saved
	settlement_records.visible = saved
	settlement_close.visible = saved
	var controls: Array = [settlement_records, settlement_close] if saved else [settlement_retry]
	for i in controls.size():
		var button: Button = controls[i]
		button.focus_next = button.get_path_to(controls[(i + 1) % controls.size()])
		button.focus_previous = button.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: button.set_focus_neighbor(side, button.focus_next)
	controls[-1 if saved else 0].grab_focus()
	queue_redraw()

func settlement_items(items: Array) -> String:
	var counts := {}
	for id in items: counts[id] = int(counts.get(id, 0)) + 1
	var lines := PackedStringArray()
	for id in counts: lines.append("%s × %d" % [Catalog.ITEMS[id][0], counts[id]])
	return "\n".join(lines) if not lines.is_empty() else "空袋 / 无"

func oxygen_max() -> float:
	return Catalog.OXYGEN + host.equipment_level("tank") * 30.0

func swim_speed() -> float:
	return [SPEED, 280.0, 320.0][host.equipment_level("fins")]

func light_radius() -> float:
	return [120.0, 200.0, 260.0][host.equipment_level("mask")]

func safety_position() -> Vector2:
	for site in sites():
		if site[0] == "上浮出口": return site[1]
	return foot

func at_safety() -> bool:
	return foot.distance_to(safety_position()) <= Catalog.SAFETY_RADIUS

func safety_hint() -> String:
	var offset := safety_position() - foot
	var direction := ("东" if offset.x > 35 else ("西" if offset.x < -35 else "")) + ("南" if offset.y > 35 else ("北" if offset.y < -35 else ""))
	if at_safety(): return "已在安全光柱附近 · E/Esc返航入库"
	return "安全点：%s方 %d像素（直线距离，绕障前往）· 到光柱附近才能E/Esc返航" % [direction, ceili(offset.length())]

func request_return() -> void:
	cancel_opening("请求上浮")
	if read_only or settling:
		returned.emit()
		return
	if ascending > 0: return
	if bag_open:
		bag_open = false
		drag_index = -1
		message = "网袋已关闭。" + safety_hint()
	elif at_safety(): returned.emit()
	else: message = safety_hint()
	refresh()

func capacity() -> int:
	return Catalog.BASE_CAPACITY + int(host.net_expansion) * 4

func used_slots() -> int:
	var total := 0
	for id in bag: total += int(Catalog.ITEMS[id][1])
	return total

func fits(id: String) -> bool:
	return used_slots() + int(Catalog.ITEMS[id][1]) <= capacity()

func discard(index: int) -> void:
	if settling or ascending > 0 or index < 0 or index >= bag.size(): return
	drops.append({"id": bag[index], "place": place, "position": foot})
	bag.remove_at(index)
	message = "已丢弃，可在本潜原地按 E 捡回。"
	refresh()

func bag_slot(index: int) -> Rect2:
	return Rect2(320 + (index % 8) * 80, 310 + (index / 8) * 85, 74, 74)

func item_at(point: Vector2) -> int:
	var slot := 0
	for i in bag.size():
		for offset in int(Catalog.ITEMS[bag[i]][1]):
			if bag_slot(slot + offset).has_point(point): return i
		slot += int(Catalog.ITEMS[bag[i]][1])
	return -1

func tick_oxygen(delta: float) -> void:
	if read_only or settling or not is_finite(delta) or delta <= 0: return
	if ascending > 0:
		ascending = maxf(0, ascending - delta)
		if ascending == 0:
			settling = true
			returned.emit()
		return
	var rate: float = Catalog.RATES[place]
	var remainder := maxf(0, delta - oxygen / rate)
	oxygen = maxf(0, oxygen - delta * rate)
	if oxygen <= oxygen_max() * 0.3 and not warned:
		warned = true
		warning_count += 1
		message = "氧气不足30%，建议上浮！"
	if oxygen == 0:
		cancel_opening("氧气耗尽")
		moving = false
		bag_open = false
		lost_items = bag.duplicate()
		lost_count = lost_items.size()
		bag.clear()
		drops.clear()
		pending_core = false
		ascending = Catalog.ASCENT_SECONDS
		message = "氧气耗尽，救援中；本次失败零收益，全部%d件收获丢失，不可拾回。" % lost_count
		if remainder > 0: tick_oxygen(remainder)

func nearest_target() -> Dictionary:
	var nearest := {}
	var distance := 56.0
	for site in sites():
		var candidate := foot.distance_to(site[1])
		if candidate <= 56.0 and (nearest.is_empty() or candidate < distance):
			distance = candidate
			nearest = {"kind": "site", "data": site, "position": site[1], "text": site_text(site[0])}
	for node in Catalog.NODES[place]:
		var candidate := foot.distance_to(node[2])
		if candidate <= 56.0 and (nearest.is_empty() or candidate < distance):
			distance = candidate
			nearest = {"kind": "node", "data": node, "position": node[2], "text": Catalog.CHESTS[Catalog.chest_quality(place, node[0])].name + "宝箱 · " + stock_text(node[0]) + " · E按一次开启"}
	for i in drops.size():
		if drops[i].place != place: continue
		var candidate := foot.distance_to(drops[i].position)
		if candidate <= distance:
			distance = candidate
			nearest = {"kind": "drop", "data": i, "position": drops[i].position, "text": "捡回 " + Catalog.ITEMS[drops[i].id][0]}
	return nearest

func stock_text(id: String) -> String:
	var entry: Dictionary = host.node_states[place][id].duplicate()
	Catalog.recover(entry, Time.get_unix_time_from_system())
	return ["已开空·补充中(0)", "可开(1)", "可开(2)", "可开(3)"][int(entry.stock)]

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
	oxygen = oxygen_max()
	drops = host.recoverable_drops.duplicate(true) if not read_only else []
	oxygen_label = _label(Vector2(70, 133), 16)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	heading = _label(Vector2(70, 30), 30)
	feedback = _label(Vector2(70, 90), 20)
	prompt = _label(Vector2(70, 640), 19)
	rules_label = _label(Vector2(70, 72), 16)
	rules_label.text = "规则：耗尽失败零收益，整袋/新核心丢失不可拾回；宝箱暂存网袋，须安全上浮入库。"
	rules_label.visible = not read_only
	feedback.position.y = 94
	feedback.add_theme_font_size_override("font_size", 14)
	close_button = Button.new()
	close_button.text = "关闭记录 / Esc" if read_only else "安全点返航 / Esc"
	close_button.position = Vector2(980, 30)
	close_button.size = Vector2(220, 44)
	close_button.pressed.connect(request_return)
	add_child(close_button)
	archive_button = Button.new()
	archive_button.text = "在浮台归档回声核心"
	archive_button.position = Vector2(770, 645)
	archive_button.size = Vector2(420, 42)
	archive_button.pressed.connect(func() -> void:
		message = "探索记录已归档；深处信号仍未解。" if host._commit_dive("dive_archived") else host.result_label.text
		refresh()
		if archive_button.disabled:
			close_button.focus_next = NodePath(".")
			close_button.focus_previous = NodePath(".")
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: close_button.set_focus_neighbor(side, NodePath("."))
		close_button.grab_focus()
	)
	add_child(archive_button)
	heading.size.x = 900
	feedback.size = Vector2(1130, 36)
	feedback.clip_text = true
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.size = Vector2(680 if read_only else 1130, 70)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh()
	close_button.focus_next = close_button.get_path_to(archive_button) if read_only and not archive_button.disabled else NodePath(".")
	close_button.focus_previous = close_button.focus_next
	archive_button.focus_next = archive_button.get_path_to(close_button)
	archive_button.focus_previous = archive_button.focus_next
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		close_button.set_focus_neighbor(side, close_button.focus_next)
		archive_button.set_focus_neighbor(side, archive_button.focus_next)
	if read_only and not archive_button.disabled:
		archive_button.grab_focus()
	else:
		close_button.grab_focus()

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
		"wreck": return [["声呐台", Vector2(720, 375)], ["海沟入口", Vector2(1080, 480)], ["返回浅滩", Vector2(145, 490)], ["上浮出口", Vector2(1100, 290)]]
		"trench": return [["回声核心", Vector2(875, 410)], ["返回沉船", Vector2(145, 410)], ["上浮出口", Vector2(350, 410)]]
	return []

func site_text(site: String) -> String:
	match site:
		"上浮出口": return "安全光柱 · 附近E/Esc撤离"
		"光迹": return "光迹 · 已记录 / 回看" if host.dive_shoal else "光迹 · 未调查"
		"声呐台": return "声呐台 · 已记录 / 回看" if host.dive_sonar else "声呐台 · 未调查"
		"船尾航路": return "船尾航路 · 可进入" if host.dive_shoal else "船尾航路 · 未解锁"
		"海沟入口": return "海沟入口 · 可进入" if host.dive_sonar else "海沟入口 · 未解锁"
		"回声核心": return "核心遗址 · 回看" if has_core() else "回声核心 · 未调查"
	return site + " · 可进入"

func interact() -> bool:
	if read_only or settling or ascending > 0 or bag_open: return false
	var chosen := nearest_target()
	if chosen.is_empty(): return false
	if chosen.kind == "node":
		start_chest(chosen.data)
		refresh()
		return true
	if chosen.kind != "site":
		var id: String = drops[int(chosen.data)].id
		if not fits(id):
			message = "网袋已满：上浮结算或 B 内拖出丢弃。"
		elif chosen.kind == "drop":
			bag.append(id)
			drops.remove_at(int(chosen.data))
			message = "已捡回 " + Catalog.ITEMS[id][0]

		refresh()
		return true
	for site in [chosen.data]:
		moving = false
		match site[0]:
			"光迹":
				var recorded: bool = host.dive_shoal
				host._commit_dive("dive_shoal")
				message = (("回看浅滩记录：" if recorded else "首次记录：") + "船舷金属片，光迹指向船尾。") if host.dive_shoal else host.result_label.text
			"船尾航路":
				if not host.dive_shoal: message = "船头封闭。先调查浅滩光迹，确认船尾航路。"
				else: enter("wreck")
			"声呐台":
				var recorded: bool = host.dive_sonar
				host._commit_dive("dive_sonar")
				message = (("回看声呐记录：" if recorded else "首次记录声呐：") + "循间歇光带前往海沟。") if host.dive_sonar else host.result_label.text
			"海沟入口":
				if not host.dive_sonar: message = "缺少海沟方向，请先调查声呐台。"
				else: enter("trench")
			"回声核心":
				var recorded: bool = has_core()
				host._commit_dive("dive_core")
				if not has_core():
					message = host.result_label.text
				elif host.dive_archived:
					message = "回看核心遗址：核心已归档，无需再次归档；深处信号仍隔着断崖。"
				else:
					message = ("核心已取得，无重复奖励。" if recorded else "首次取得唯一回声核心（本潜暂存）。") + "必须到安全光柱返航才保留；耗尽救援本潜新核心丢失。安全带回后在浮台探索记录首次归档可获工坊位＋木2废2；珍珠用于装备二级。断崖深处本版不可达。"
			"返回浅滩": enter("shoal")
			"返回沉船": enter("wreck")
			"上浮出口": request_return()
		refresh()
		return true
	return false

func enter(destination: String) -> void:
	cancel_opening("切换地点")
	var source := place
	place = destination
	foot = Vector2(225, 410 if place == "trench" else 490)
	if source == "wreck" and place == "shoal":
		foot = Vector2(1000, 490)
	elif source == "trench" and place == "wreck":
		foot = Vector2(1000, 480)
	moving = false
	message = {"shoal": "珊瑚墙留有缺口；远方沉船船头封闭。", "wreck": "船头堵死，绕下方船尾缺口进入船舱，寻找声呐台。", "trench": "沿窄道与脉动光带前进；断崖对面信号本版不可达。"}[place]
	refresh()

func refresh() -> void:
	if not is_instance_valid(heading) or not settlement.is_empty(): return
	oxygen_label.visible = not read_only
	oxygen_label.text = "氧气 %.1f / %.0f 秒 ×%.2f  网袋 %d/%d · B查看 · 光柱附近Esc上浮" % [oxygen, oxygen_max(), Catalog.RATES[place], used_slots(), capacity()]
	if warned: oxygen_label.text += " · 低氧警告！耗尽整袋丢失，立即前往光柱"
	oxygen_label.modulate = Color.YELLOW if warned else Color.WHITE
	heading.text = "浮台 · 探索记录" if read_only else {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}[place] + " · WASD / 方向键 / 点击移动"
	feedback.text = (host._dive_summary() + ("\n" + message if message.contains("失败") else "")) if read_only else message
	archive_button.visible = read_only
	archive_button.disabled = not host.dive_core or host.core_reward_claimed
	archive_button.text = "已归档领奖 · 无需重复" if host.core_reward_claimed else ("补领工坊位＋木2废2" if host.dive_archived else ("首次归档：工坊位＋木2废2" if host.dive_core else "尚未取得核心 · 暂不可归档"))
	if read_only:
		prompt.text = "已归档 · 可随时重访" if host.dive_archived else ("带回核心，点击归档完成记录" if host.dive_core else "可提前返航；已调查线索持续保留")
	else:
		prompt.text = safety_hint()
		var chosen := nearest_target()
		if not opening.is_empty():
			prompt.text += "\n开箱进度 %d%% · 剩余%.1f秒 · 移动取消 / B不暂停耗氧" % [int(100 * (1 - opening_left / opening_total)), opening_left]
		elif not chosen.is_empty(): prompt.text += "\nE · 最近目标：" + chosen.text + "（普通即时 / 精良3秒 / 稀有6秒，候选）"
		if ascending > 0: prompt.text = "自动上浮 %.1f秒" % ascending
		elif settling: prompt.text = "待结算：Esc 重试，禁止继续采集。"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not settlement.is_empty():
		if event is InputEventKey:
			if event.keycode in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]: return
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
				if settlement_saved: host._dismiss_dive()
				else: host._close_dive()
		return
	if event is InputEventKey:
		if event.keycode in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or (read_only and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]):
			return
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				cancel_opening("移动输入")
				refresh()
			if event.keycode == KEY_ESCAPE: request_return()
			elif event.keycode == KEY_C:
				message = "装备只读：面具%d / 瓶%d / 蹼%d级；制造请返回浮台C工坊。" % [host.equipment_level("mask"), host.equipment_level("tank"), host.equipment_level("fins")]
				refresh()
			elif event.keycode == KEY_B and not read_only and not settling and ascending <= 0:
				bag_open = not bag_open
				drag_index = -1
				moving = false
				refresh()
			elif event.keycode == KEY_E: interact()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not read_only and bag_open:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed: drag_index = item_at(point)
		else:
			if not BAG_RECT.has_point(point): discard(drag_index)
			drag_index = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not read_only and not settling and ascending <= 0:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if FIELD.has_point(point):
			cancel_opening("点击移动")
			target = point
			moving = true
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	elapsed += delta
	if read_only: return
	tick_oxygen(delta)
	if not is_inside_tree(): return
	if not settling and ascending <= 0:
		var input_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
		if input_moving: cancel_opening("移动输入")
		tick_opening(delta)
	if bag_open or settling or ascending > 0:
		refresh()
		return
	var direction := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
	if direction != Vector2.ZERO: moving = false
	elif moving:
		if foot.distance_to(target) < 4: moving = false
		else: direction = (target - foot).normalized()
	var before := foot
	var motion := direction * minf(delta, 0.05) * swim_speed()
	if moving: motion = motion.limit_length(foot.distance_to(target))
	move_step(motion)
	if moving and direction != Vector2.ZERO and foot.distance_to(before) < 0.01:
		moving = false
		message = "前方受阻，已停止；请用方向键或分段点击绕过缺口。"
	refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071b2b"))
	if not settlement.is_empty(): return
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
	if place != "shoal":
		# 保持暗区轮廓与安全文字可读，装备扩大真正照亮的范围。
		for x in range(70, 1200, 20):
			for y in range(155, 625, 20):
				var distance := foot.distance_to(Vector2(x + 10, y + 10))
				var shade := clampf((distance - light_radius()) / 60.0, 0.0, 1.0) * 0.52
				draw_rect(Rect2(x, y, 20, 20), Color(0, 0, 0.02, shade))
		draw_arc(foot, light_radius(), 0, TAU, 64, Color(0.5, 0.9, 1, 0.25), 1)
	if not at_safety():
		var arrow := (safety_position() - foot).normalized()
		var tip := foot + arrow * 48
		draw_line(foot + arrow * 24, tip, Color.CYAN, 3)
		draw_line(tip, tip - arrow.rotated(0.55) * 12, Color.CYAN, 3)
		draw_line(tip, tip - arrow.rotated(-0.55) * 12, Color.CYAN, 3)
	if moving:
		draw_arc(target, 10, 0, TAU, 20, Color("#ffe6a4"), 2)
		draw_line(target - Vector2(15, 0), target + Vector2(15, 0), Color("#ffe6a4"), 2)
	for site in sites():
		if site[0] == "上浮出口":
			draw_rect(Rect2(Vector2(site[1].x - 15, FIELD.position.y), Vector2(30, site[1].y - FIELD.position.y)), Color(0.5, 1.0, 0.9, 0.22))
		draw_circle(site[1], 19, Color("#84e6d5"))
		var text := site_text(site[0])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var label_at := Vector2(clampf(site[1].x - width / 2, FIELD.position.x, FIELD.end.x - width), site[1].y - 30)
		draw_string(ThemeDB.fallback_font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_circle(foot, RADIUS, Color("#ffe6a4"))
	draw_arc(foot, 20, 0, TAU, 24, Color("#fff4cf"), 2)
	for node in Catalog.NODES[place]:
		if place != "shoal" and foot.distance_to(node[2]) > light_radius():
			if host.equipment_level("mask") >= 2:
				draw_rect(Rect2(node[2] - Vector2(12, 12), Vector2(24, 24)), Color("#768d9d"), false, 2)
			continue
		var quality := Catalog.chest_quality(place, node[0])
		var tint: Color = Catalog.CHESTS[quality].color
		var empty := stock_text(node[0]).contains("(0)")
		var p: Vector2 = node[2]
		draw_rect(Rect2(p + Vector2(-19, -8), Vector2(38, 25)), Color("#4d555b") if empty else Color("#755039"))
		draw_rect(Rect2(p + Vector2(-21, -17 if empty else -14), Vector2(42, 11)), tint, false, 3)
		for x in [-13, 11]: draw_line(p + Vector2(x, -7), p + Vector2(x, 15), tint, 3)
		draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 9)), tint)
		draw_string(ThemeDB.fallback_font, p + Vector2(-53, -25), Catalog.CHESTS[quality].name + "宝箱 " + stock_text(node[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if not opening.is_empty() and opening.id == node[0]:
			draw_rect(Rect2(p + Vector2(-25, 23), Vector2(50, 6)), Color("#18394a"))
			draw_rect(Rect2(p + Vector2(-25, 23), Vector2(50 * (1 - opening_left / opening_total), 6)), tint)
	for drop in drops:
		if drop.place == place:
			draw_circle(drop.position, 8, Color.ORANGE)
			draw_string(ThemeDB.fallback_font, drop.position + Vector2(12, 12), "拾 " + Catalog.ITEMS[drop.id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var chosen := nearest_target()
	if not chosen.is_empty(): draw_arc(chosen.position, 25, 0, TAU, 24, Color.YELLOW, 3)
	var ratio := oxygen / oxygen_max()
	draw_rect(Rect2(980, 82, 220, 10), Color("#18394a"))
	draw_rect(Rect2(980, 82, 220 * ratio, 10), Color.YELLOW if warned else Color.CYAN)
	if ratio <= 0.15:
		var shade := Color(0, 0, 0, 0.65 * (1.0 - ratio / 0.15))
		for edge in [Rect2(0, 0, 45, 720), Rect2(1235, 0, 45, 720), Rect2(0, 0, 1280, 20), Rect2(0, 700, 1280, 20)]: draw_rect(edge, shade)
	if bag_open:
		draw_rect(BAG_RECT, Color("#102535"))
		draw_string(ThemeDB.fallback_font, Vector2(320, 260), "临时网袋 %d/%d格 · 按件占格无堆叠" % [used_slots(), capacity()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(320, 290), "从任一占用格按住拖出面板丢弃 · B关闭 · 氧气继续消耗", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.YELLOW)
		for i in capacity(): draw_rect(bag_slot(i), Color("#608b94"), false, 2)
		var slot := 0
		for i in bag.size():
			var id: String = bag[i]
			for offset in int(Catalog.ITEMS[id][1]):
				var cell := bag_slot(slot + offset).grow(-4)
				draw_rect(cell, Color("#375c70"))
				draw_string(ThemeDB.fallback_font, cell.position + Vector2(2, 28), "%d %s" % [i + 1, Catalog.ITEMS[id][0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			slot += int(Catalog.ITEMS[id][1])
