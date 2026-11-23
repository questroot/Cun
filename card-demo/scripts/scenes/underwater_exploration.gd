extends Control

signal returned
const Art = preload("res://scripts/scenes/dive_art_chart.gd")
const InstrumentTheme = preload("res://scripts/water_instrument_theme.gd")
const Survey = preload("res://scripts/scenes/dive_survey.gd")
const FIELD := Survey.FIELD
const RADIUS := 12.0
const SPEED := 230.0
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const BAG_RECT := Rect2(300, 220, 680, 310)
const SeaCrewActor = preload("res://scripts/scenes/sea_crew_actor.gd")
const BACKDROPS := {
	"shoal": preload("res://assets/backgrounds/fudi/wetland.webp"),
	"wreck": preload("res://assets/backgrounds/fudi/causeway.webp"),
	"trench": preload("res://assets/backgrounds/fudi/ruins.webp"),
}
const CHEST_ART := preload("res://assets/pixel/fudi/chests/normal_closed.png")
const SITE_MARKER := preload("res://assets/ui/quest-markers/blue-question.png")
var model: SeaCrewActor
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
var observing_id := ""
var observation_elapsed := 0.0
var observation_blocked: Dictionary = {}
var records_page := "clues"
var records_tabs: HBoxContainer
var clues_tab: Button
var species_tab: Button
var orders_tab: Button
const ArchiveFolio = preload("res://scripts/scenes/dive_archive_folio.gd")
var folio: ArchiveFolio
var orders_content: HBoxContainer
var clues_content: VBoxContainer
var species_content: VBoxContainer
var species_count: Label
var species_regions: Dictionary = {}
var species_cards: Dictionary = {}
var observed: Dictionary = {}
var facing := Vector2.RIGHT
var push_cooldown := 0.0
var hit_cooldown := 0.0
var narrow_wreck := false
var audio: Node

func species_position(id: String) -> Vector2:
	return host.creature_states.get(id, {}).get("pos", Catalog.species()[id].pos)

func tide() -> Dictionary:
	var phase := fposmod(host.tide_clock, 270.0)
	if phase < 90: return {"name": "平潮", "left": 90 - phase, "rising": false, "falling": false}
	if phase < 135: return {"name": "涨潮", "left": 135 - phase, "rising": true, "falling": false}
	if phase < 225: return {"name": "平潮", "left": 225 - phase, "rising": false, "falling": false}
	return {"name": "落潮", "left": 270 - phase, "rising": false, "falling": true}

func cue(event: String) -> void:
	if is_instance_valid(audio): audio.cue(event)

func tick_ecology(delta: float) -> void:
	push_cooldown = maxf(0, push_cooldown - delta)
	hit_cooldown = maxf(0, hit_cooldown - delta)
	for id in Catalog.species():
		var entry: Dictionary = Catalog.species()[id]
		if not host.creature_states.has(id):
			host.creature_states[id] = {"pos": entry.pos, "stun": 0.0, "respawn": 0.0, "phase": 0.0, "warning": 0.0, "dash": 0.0, "direction": Vector2.RIGHT, "attack": 3.0}
		var state: Dictionary = host.creature_states[id]
		if state.respawn > 0:
			state.respawn = maxf(0, float(state.respawn) - delta)
			if state.respawn == 0: state.pos = entry.pos
			continue
		state.stun = maxf(0, float(state.stun) - delta)
		if entry.place != place or state.stun > 0: continue
		state.phase += delta
		var motion := Vector2(cos(float(state.phase)), sin(float(state.phase) * 0.7)) * delta * 12
		if id == "trench_blind_eel":
			state.attack -= delta * (1.5 if tide().rising else 1.0)
			if state.warning > 0:
				state.warning = maxf(0, float(state.warning) - delta)
				if state.warning == 0: state.dash = 0.7
			elif state.dash > 0:
				state.dash = maxf(0, float(state.dash) - delta)
				motion = state.direction * delta * 310
			elif state.attack <= 0 and foot.distance_to(state.pos) < 260:
				state.direction = (foot - Vector2(state.pos)).normalized()
				state.warning = 0.8
				state.attack = 5.0
		if can_stand(Vector2(state.pos) + motion): state.pos += motion
		if hit_cooldown <= 0 and foot.distance_to(state.pos) < 28 and (id == "wreck_rust_crab" or (id == "trench_blind_eel" and state.dash > 0)):
			var light: bool = id == "wreck_rust_crab"
			var wrist: int = host.equipment_level("wrist")
			var damage := (0.0 if wrist == 2 else (3.0 if wrist == 1 else 6.0)) if light else (8.0 if wrist == 2 else (12.0 if wrist == 1 else 18.0))
			hit_cooldown = 1.2
			oxygen = maxf(0, oxygen - damage)
			move_step((foot - Vector2(state.pos)).normalized() * 32)
			cue("hit")
			if oxygen <= 0:
				tick_oxygen(0.000001)
				return
	if place == "trench" and tide().rising:
		move_step(Vector2(24 * delta, 0))
	if place == "wreck":
		if not tide().falling: narrow_wreck = false
		elif not Rect2(378, 423, 114, 44).has_point(foot): narrow_wreck = true

func push() -> bool:
	if read_only or settling or ascending > 0 or oxygen <= 0 or bag_open or push_cooldown > 0: return false
	push_cooldown = 1.0
	for id in host.creature_states:
		var state: Dictionary = host.creature_states[id]
		if Catalog.species()[id].place != place or state.respawn > 0: continue
		var offset: Vector2 = state.pos - foot
		if offset.length() <= 85 and (offset.length() < 1 or facing.dot(offset.normalized()) >= 0.4):
			state.stun = 2.0 + host.equipment_level("capture_net") * 1.5
			state.dash = 0.0
			state.warning = 0.0
			var destination: Vector2 = state.pos + offset.normalized() * 28
			if can_stand(destination): state.pos = destination
	cue("push")
	return true

func capture() -> bool:
	if host.equipment_level("capture_net") <= 0: return false
	for id in host.creature_states:
		var state: Dictionary = host.creature_states[id]
		if Catalog.species()[id].place != place or state.respawn > 0 or state.stun <= 0 or foot.distance_to(state.pos) > 56: continue
		if not fits("live:" + id):
			message = "活捕需要2格空间；生物仍在原处。"
			return true
		bag.append("live:" + id)
		state.respawn = 180.0
		state.stun = 0.0
		message = "活捕成功；安全入库后认证。"
		cue("gather")
		return true
	return false

func tidal_shells() -> Array:
	if place != "shoal" or not tide().falling: return []
	var result := []
	for i in 2:
		var id := "%d:%d" % [int(host.tide_clock / 270), i]
		if not host.tide_shells.has(id): result.append([id, Vector2(210 + i * 560, 590)])
	return result

func reset_observation() -> void:
	observing_id = ""
	observation_elapsed = 0.0

func nearest_species() -> String:
	var nearest := ""
	var distance := Catalog.OBSERVE_RADIUS
	var entries := Catalog.species()
	for id in entries:
		var entry: Dictionary = entries[id]
		if entry.place != place or observed.has(id) or host.creature_states.get(id, {}).get("respawn", 0) > 0 or observation_blocked.has(id): continue
		var candidate := foot.distance_to(species_position(id))
		if candidate <= distance:
			if nearest.is_empty() or candidate < distance:
				nearest = id
				distance = candidate
	return nearest

func tick_observation(delta: float) -> void:
	var entries := Catalog.species()
	for id in observation_blocked.keys():
		var entry: Dictionary = entries[id]
		if entry.place != place or foot.distance_to(species_position(id)) > Catalog.OBSERVE_RADIUS:
			observation_blocked.erase(id)
	if read_only or settling or ascending > 0 or oxygen <= 0 or bag_open or not opening.is_empty() or not settlement.is_empty():
		reset_observation()
		return
	if not is_finite(delta) or delta <= 0: return
	var chosen := nearest_species()
	if chosen != observing_id:
		reset_observation()
		observing_id = chosen
	if observing_id.is_empty(): return
	observation_elapsed = minf(Catalog.OBSERVE_SECONDS, observation_elapsed + delta)
	if observation_elapsed < Catalog.OBSERVE_SECONDS: return
	var id := observing_id
	reset_observation()
	if host._commit_species(id):
		observed[id] = true
		message = "生态记录已保存：%s；救援上浮仍保留，可在浮台生态图鉴回看。" % entries[id].name
	else:
		observation_blocked[id] = true
		message = "生态记录保存失败；请离开观察圈后重新靠近观察，不会自动重试。"

func update_records_focus() -> void:
	if not read_only: return
	var controls: Array = [clues_tab, species_tab, orders_tab]
	if records_page == "clues" and not archive_button.disabled: controls.append(archive_button)
	controls.append(close_button)
	for i in controls.size():
		var button: Button = controls[i]
		button.focus_next = button.get_path_to(controls[(i + 1) % controls.size()])
		button.focus_previous = button.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		button.set_focus_neighbor(SIDE_RIGHT, button.focus_next)
		button.set_focus_neighbor(SIDE_BOTTOM, button.focus_next)
		button.set_focus_neighbor(SIDE_LEFT, button.focus_previous)
		button.set_focus_neighbor(SIDE_TOP, button.focus_previous)

func show_records_page(page: String) -> void:
	if not read_only or page not in ["clues", "species", "orders"]: return
	records_page = page
	refresh()
	({"clues": clues_tab, "species": species_tab, "orders": orders_tab}[page]).grab_focus()

func build_records() -> void:
	records_tabs = HBoxContainer.new()
	records_tabs.position = Vector2(70, 144)
	records_tabs.add_theme_constant_override("separation", 16)
	add_child(records_tabs)
	clues_tab = Button.new()
	clues_tab.text = "探索线索"
	clues_tab.toggle_mode = true
	clues_tab.custom_minimum_size = Vector2(180, 42)
	clues_tab.pressed.connect(show_records_page.bind("clues"))
	records_tabs.add_child(clues_tab)
	species_tab = Button.new()
	species_tab.text = "生态图鉴"
	species_tab.toggle_mode = true
	species_tab.custom_minimum_size = Vector2(180, 42)
	species_tab.pressed.connect(show_records_page.bind("species"))
	records_tabs.add_child(species_tab)
	orders_tab = Button.new()
	orders_tab.text = "阿汐委托 / 航程"
	orders_tab.toggle_mode = true
	orders_tab.custom_minimum_size = Vector2(220, 42)
	orders_tab.pressed.connect(show_records_page.bind("orders"))
	records_tabs.add_child(orders_tab)
	folio = ArchiveFolio.new()
	for i in records_tabs.get_child_count():
		var tab: Button = records_tabs.get_child(i)
		tab.text = "%02d    %s" % [i + 1, tab.text]
		tab.custom_minimum_size = Vector2(366, 42)
	archive_button.theme_type_variation = &"HarborLaunch"
	orders_content = HBoxContainer.new()
	orders_content.position = Vector2(70, 205)
	orders_content.size = Vector2(1130, 408)
	orders_content.add_theme_constant_override("separation", 14)
	add_child(orders_content)
	folio.build_orders(orders_content)
	clues_content = VBoxContainer.new()
	clues_content.position = Vector2(70, 206)
	clues_content.size = Vector2(1130, 405)
	clues_content.add_theme_constant_override("separation", 10)
	add_child(clues_content)
	folio.build_clues(clues_content)
	species_content = VBoxContainer.new()
	species_content.position = Vector2(70, 197)
	species_content.size = Vector2(1130, 426)
	species_content.add_theme_constant_override("separation", 8)
	add_child(species_content)
	species_count = folio.build_species_header(species_content)
	var regions := HBoxContainer.new()
	regions.add_theme_constant_override("separation", 12)
	species_content.add_child(regions)
	var entries := Catalog.species()
	for region in ["shoal", "wreck", "trench"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		regions.add_child(column)
		var region_index := ["shoal", "wreck", "trench"].find(region)
		var region_label := ArchiveFolio.label(column, "", 18, ArchiveFolio.INKS[region_index])
		species_regions[region] = region_label
		for id in entries:
			var entry: Dictionary = entries[id]
			if entry.place != region: continue
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(0, 112)
			column.add_child(panel)
			var row := HBoxContainer.new()
			panel.add_child(row)
			var icon := Control.new()
			icon.custom_minimum_size = Vector2(66, 100)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var serial := entries.keys().find(id) + 1
			icon.draw.connect(func() -> void:
				var accent: Color = ArchiveFolio.INKS[region_index]
				icon.draw_rect(Rect2(0, 0, 61, icon.size.y), Color("#0a202a"))
				icon.draw_arc(Vector2(30, 52), 25, 0, TAU, 40, Color("#395866"), 1.0, true)
				icon.draw_string(ThemeDB.fallback_font, Vector2(7, 16), "E / %02d" % serial, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
				draw_creature(icon, Vector2(30, 52), entry.shape, entry.color if host.species_records.get(id, false) else Color("#506879"), not host.species_records.get(id, false)))
			row.add_child(icon)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(details)
			var text := ArchiveFolio.label(details, "", 16)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var stamps := ArchiveFolio.label(details, "", 15, ArchiveFolio.INKS[region_index])
			species_cards[id] = {"text": text, "icon": icon, "stamps": stamps}

func refresh_records() -> void:
	var locations := {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}
	clues_tab.button_pressed = records_page == "clues"
	species_tab.button_pressed = records_page == "species"
	clues_content.visible = records_page == "clues"
	species_content.visible = records_page == "species"
	orders_tab.button_pressed = records_page == "orders"
	orders_content.visible = records_page == "orders"
	folio.refresh(host)
	var counts := {"shoal": 0, "wreck": 0, "trench": 0}
	var totals := {"shoal": 0, "wreck": 0, "trench": 0}
	var total := 0
	var entries := Catalog.species()
	for id in entries:
		var entry: Dictionary = entries[id]
		var recorded: bool = host.species_records.get(id, false)
		totals[entry.place] += 1
		if recorded:
			counts[entry.place] += 1
			total += 1
		species_cards[id].text.text = (entry.name + " · 已记录\n" + entry.description) if recorded else "未知生物 · 未记录\n靠近48像素，持续观察2秒解锁。"
		species_cards[id].stamps.text = "安全认证 %s     活捕 %s" % ["✓" if host.dive_archive.safe[id] else "—", "✓" if host.dive_archive.captured[id] else "—"]
		species_cards[id].icon.queue_redraw()
	for region in counts:
		species_regions[region].text = "%s · %d/%d" % [locations[region], counts[region], totals[region]]
	var safe_count: int = host.dive_archive.safe.values().count(true)
	species_count.text = "观察 %d/9   ·   安全 %d/9   /   装备门槛" % [total, safe_count]
	folio.update_milestones(safe_count)
	update_records_focus()

func cancel_opening(reason: String) -> void:
	if opening.is_empty(): return
	opening.clear()
	opening_left = 0
	message = "开箱取消：%s；不扣次数、不发奖。" % reason

func start_chest(node: Array) -> void:
	reset_observation()
	if not opening.is_empty(): return
	var entry: Dictionary = host.node_states[place][node[0]].duplicate()
	Catalog.recover(entry, Time.get_unix_time_from_system())
	if int(entry.stock) <= 0:
		message = "宝箱已开空，等待补充。"
		return
	var slots := chest_slots(node[0])
	if used_slots() + slots > capacity():
		message = "网袋空间不足：此箱需预留%d格（按最大可能产出）；未开箱、不扣次数。" % slots
		return
	moving = false
	opening = {"map": place, "id": node[0], "position": node[2]}
	opening_total = float(Catalog.CHESTS[Catalog.chest_quality(place, node[0])].seconds)
	if host.technology.researched("T6"): opening_total *= 2.0 / 3.0
	opening_left = opening_total
	message = "按一次E已启动开箱，无需按住；移动取消，开启期间继续耗氧。"
	if opening_left == 0: finish_chest()

func chest_slots(id: String) -> int:
	return Catalog.chest_slots(place, id)

func finish_chest() -> void:
	if opening.is_empty(): return
	var current := opening.duplicate()
	opening.clear()
	opening_left = 0
	if used_slots() + chest_slots(current.id) > capacity():
		message = "网袋空间不足；未扣次数、未抽奖。"
		return
	# 只有事务保存成功才计算一次随机结果，失败无奖励也不扣存量。
	var entry: Dictionary = host.node_states[place][current.id].duplicate()
	if not host.gather_node(place, current.id):
		message = "开箱失败：补充中或保存失败；未扣次数、未发奖，可重试。"
		return
	var loot := Catalog.chest_loot(place, current.id, int(entry.stock), float(entry.timestamp))
	if tide().rising:
		for item in loot.duplicate():
			if item == "algae": loot.append(item)
	bag.append_array(loot)
	cue("gather")
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
	reset_observation()
	cancel_opening("关闭场景")
	if not read_only and not settlement_saved and not return_secured and is_instance_valid(host):
		host.rollback_dive_stock()

func has_core() -> bool:
	return host.dive_core or pending_core
var oxygen_label: Label
var bag_meter: Label
var tide_meter: Label
var settlement: Dictionary = {}
var settlement_saved := false
var return_secured := false
var settlement_panel: PanelContainer
var settlement_text: RichTextLabel
var settlement_close: Button
var settlement_records: Button
var settlement_technology: Button
var settlement_retry: Button

func show_settlement(saved: bool) -> void:
	cue("surface")
	if is_instance_valid(audio): audio.enter("")
	reset_observation()
	model.hide()
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
		settlement_technology = Button.new()
		settlement_technology.text = "查看科技"
		settlement_technology.pressed.connect(func() -> void:
			if not settlement_saved: return
			host._dismiss_dive()
			host.technology.show_page("tech"))
		buttons.add_child(settlement_technology)
		settlement_close = Button.new()
		settlement_close.text = "返回浮台 / Esc"
		settlement_close.pressed.connect(func() -> void:
			if settlement_saved: host._dismiss_dive())
		buttons.add_child(settlement_close)
	var location: String = {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}[settlement.place]
	var lines := PackedStringArray([("耗尽救援 · 本次失败零收益" if settlement.rescue else "安全光柱上浮") + " · " + location, "", ("安全封存·待入库" if saved and host.public_project.pending_bag != null else ("本次入库" if saved else "待封存网袋")) + " · 共%d件：" % settlement.items.size(), settlement_items(settlement.items), "", "全部损失 · 共%d件（不可拾回）：" % settlement.losses.size(), settlement_items(settlement.losses), ""])
	if settlement.rescue:
		lines.append("未安全上浮：本次收获100%不入库，本潜新核心未保留，不能归档领奖；历史仓库、装备、已带回核心及已保存生态记录不受影响。")
		lines.append("已扣宝箱存量已回滚；再次开启同代次不会重抽。" if saved else "宝箱存量回滚保存失败，探索冻结，请重试。\n" + host.result_label.text)
		settlement_retry.text = "重试存量回滚"
	else:
		lines.append(("返航袋已安全封存，可返回基地；待袋整袋入库前禁止再次下潜。" if host.public_project.pending_bag != null else "材料与核心已入库并保存。") if saved else "封存保存失败，尚未安全保存；网袋冻结，请原地重试。\n" + host.result_label.text)
		settlement_retry.text = "重试安全封存"
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
	elif not settlement.rescue: lines.append("安全带回的材料可用于装备与科技；点击查看科技预览缺口，不会自动扣料。")
	settlement_text.text = "\n".join(lines)
	settlement_retry.visible = not saved
	settlement_records.visible = saved
	settlement_close.visible = saved
	settlement_technology.visible = saved
	var controls: Array = [settlement_records, settlement_technology, settlement_close] if saved else [settlement_retry]
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
	for id in counts: lines.append("%s × %d" % [Catalog.item_name(id), counts[id]])
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
	reset_observation()
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
	for id in bag: total += Catalog.item_slots(id)
	return total

func fits(id: String) -> bool:
	return used_slots() + Catalog.item_slots(id) <= capacity()

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
		for offset in Catalog.item_slots(bag[i]):
			if bag_slot(slot + offset).has_point(point): return i
		slot += Catalog.item_slots(bag[i])
	return -1

func tick_oxygen(delta: float) -> void:
	if read_only or settling or not is_finite(delta) or delta <= 0: return
	if ascending > 0:
		ascending = maxf(0, ascending - delta)
		if ascending == 0:
			settling = true
			returned.emit()
		return
	var rate: float = Catalog.RATES[place] * (1.1 if tide().rising else 1.0)
	var remainder := maxf(0, delta - oxygen / rate)
	oxygen = maxf(0, oxygen - delta * rate)
	if oxygen <= oxygen_max() * 0.3 and not warned:
		warned = true
		warning_count += 1
		message = "氧气不足30%，建议上浮！"
	if oxygen == 0:
		reset_observation()
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
		ascending = maxf(0, ascending - remainder)
		if ascending == 0:
			settling = true
			returned.emit()

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
			nearest = {"kind": "drop", "data": i, "position": drops[i].position, "text": "捡回 " + Catalog.item_name(drops[i].id)}
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
	theme = InstrumentTheme.build()
	model = SeaCrewActor.new()
	model.submerged = true
	add_child(model)
	oxygen = oxygen_max()
	drops = host.recoverable_drops.duplicate(true) if not read_only else []
	oxygen_label = _label(Vector2(345, 39), 22)
	bag_meter = _label(Vector2(612, 39), 21)
	tide_meter = _label(Vector2(780, 39), 20)
	bag_meter.visible = not read_only
	tide_meter.visible = not read_only
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	heading = _label(Vector2(74, 36), 31)
	feedback = _label(Vector2(74, 78 if read_only else 103), 16)
	prompt = _label(Vector2(70 if read_only else 204, 641), 18)
	rules_label = _label(Vector2(74, 80), 15)
	rules_label.text = "安全上浮入库 · 耗尽丢失整袋和新核心　｜　靠近生物观察 2 秒，J 推开，E 活捕（需捕网与 2 格）。"
	rules_label.visible = not read_only
	feedback.add_theme_color_override("font_color", Color("#b6d9d2"))
	close_button = Button.new()
	close_button.text = "关闭记录 / Esc" if read_only else "安全点返航 / Esc"
	close_button.theme_type_variation = &"HarborPrimary"
	close_button.position = Vector2(980, 20)
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
		close_button.grab_focus()
	)
	add_child(archive_button)
	heading.size.x = 260
	feedback.size = Vector2(890, 48)
	feedback.clip_text = true
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.size = Vector2(680 if read_only else 995, 70)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not read_only and ResourceLoader.exists("res://scripts/scenes/underwater_audio.gd"):
		audio = load("res://scripts/scenes/underwater_audio.gd").new()
		add_child(audio)
		audio.enter(place)
		var mute := Button.new()
		mute.text = "静音"
		mute.position = Vector2(980, 79)
		mute.size = Vector2(90, 40)
		mute.pressed.connect(func() -> void:
			audio.set_muted(not audio.muted)
			mute.text = "恢复声音" if audio.muted else "静音")
		add_child(mute)
		var volume := HSlider.new()
		volume.position = Vector2(1090, 87)
		volume.size = Vector2(95, 24)
		volume.max_value = 100
		volume.value = 70
		volume.value_changed.connect(func(value: float) -> void:
			audio.music_level = value / 100.0
			audio.effects_level = value / 100.0
			audio.ambience_level = value / 100.0)
		add_child(volume)
	if read_only: build_records()
	refresh()
	if read_only:
		clues_tab.grab_focus()
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
	return Survey.obstacles(place, narrow_wreck)

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
	return Survey.sites(place)

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
	if read_only or settling or ascending > 0 or oxygen <= 0 or bag_open: return false
	if capture():
		refresh()
		return true
	for shell in tidal_shells():
		if foot.distance_to(shell[1]) <= 56:
			if fits("shell"):
				bag.append("shell")
				host.tide_shells[shell[0]] = true
				cue("gather")
			return true
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
			message = "已捡回 " + Catalog.item_name(id)

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
	reset_observation()
	observation_blocked.clear()
	cancel_opening("切换地点")
	var source := place
	place = destination
	if is_instance_valid(audio): audio.enter(place)
	foot = Vector2(225, 410 if place == "trench" else 490)
	if source == "wreck" and place == "shoal":
		foot = Vector2(1000, 490)
	elif source == "trench" and place == "wreck":
		foot = Vector2(1000, 480)
	moving = false
	message = {"shoal": "珊瑚墙留有缺口；远方沉船船头封闭。", "wreck": "船头堵死，绕下方船尾缺口进入船舱，寻找声呐台。", "trench": "沿窄道与脉动光带前进；断崖对面信号本版不可达。"}[place]
	refresh()

func refresh() -> void:
	if is_instance_valid(model):
		model.position = foot
		model.visible = not read_only and settlement.is_empty() and not bag_open
		if bag_open or settling or ascending > 0: model.update_movement(Vector2.ZERO, 0)
	if not is_instance_valid(heading) or not settlement.is_empty(): return
	oxygen_label.visible = not read_only
	oxygen_label.text = "%.1f / %.0f 秒" % [oxygen, oxygen_max()]
	oxygen_label.mouse_filter = Control.MOUSE_FILTER_PASS
	oxygen_label.tooltip_text = "当地耗氧倍率 ×%.2f" % Catalog.RATES[place]
	bag_meter.text = "%02d / %02d 格" % [used_slots(), capacity()]
	var current_tide := tide()
	tide_meter.text = "%s · %ds" % [current_tide.name, ceili(current_tide.left)]
	if is_instance_valid(audio):
		audio.set_tide(tide().rising)
		audio.set_oxygen(oxygen / oxygen_max())
	if warned: oxygen_label.text = "低氧警告 %.1fs · 整袋丢失" % oxygen
	oxygen_label.add_theme_font_size_override("font_size", 17 if warned else 22)
	oxygen_label.modulate = Art.AMBER if warned else Art.GLASS
	heading.text = "浮台 · 探索记录" if read_only else {"shoal": "珊瑚浅滩", "wreck": "侧倾沉船", "trench": "发光海沟"}[place]
	feedback.text = (host._dive_summary() + ("\n" + message if message.contains("失败") else "")) if read_only else message
	archive_button.visible = read_only and records_page == "clues"
	archive_button.disabled = not host.dive_core or host.core_reward_claimed
	archive_button.text = "已归档领奖 · 无需重复" if host.core_reward_claimed else ("补领工坊位＋木2废2" if host.dive_archived else ("首次归档：工坊位＋木2废2" if host.dive_core else "尚未取得核心 · 暂不可归档"))
	if read_only:
		refresh_records()
		match records_page:
			"clues": prompt.text = "已归档 · 可随时重访" if host.dive_archived else ("核心已带回 · 在右侧归档领取奖励" if host.dive_core else "已调查线索持续保留；安全带回核心后可归档。")
			"species": prompt.text = "图鉴只读   /   观察后记录物种，安全入库后认证。"
			"orders": prompt.text = "航务只读   /   交付与航程在安全入库时结算。"
	else:
		prompt.text = safety_hint()
		var chosen := nearest_target()
		if not opening.is_empty():
			prompt.text += "\n开箱进度 %d%% · 剩余%.1f秒 · 移动取消 / B不暂停耗氧" % [int(100 * (1 - opening_left / opening_total)), opening_left]
		elif not chosen.is_empty(): prompt.text += "\nE · 最近目标：" + chosen.text + "（普通即时 / 精良3秒 / 稀有6秒，候选）"
		if not observing_id.is_empty():
			prompt.text += "\n生态观察 %.1f / %.0f秒 · 圈内移动可继续；离圈/开箱/网袋会清零" % [observation_elapsed, Catalog.OBSERVE_SECONDS]
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
	if read_only:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			request_return()
		return
	if event is InputEventKey:
		if event.keycode in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				cancel_opening("移动输入")
				refresh()
			if event.keycode == KEY_ESCAPE: request_return()
			elif event.keycode == KEY_C:
				message = "装备只读：面具 %d · 氧气瓶 %d · 脚蹼 %d · 网袋 %d　｜　捕网 %d · 护腕 %d；制造请返回浮台 C 工坊。" % [host.equipment_level("mask"), host.equipment_level("tank"), host.equipment_level("fins"), host.net_expansion, host.equipment_level("capture_net"), host.equipment_level("wrist")]
				refresh()
			elif event.keycode == KEY_B and not read_only and not settling and ascending <= 0:
				reset_observation()
				bag_open = not bag_open
				drag_index = -1
				moving = false
				refresh()
			elif event.keycode == KEY_J: push()
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
	var was_opening := not opening.is_empty()
	if not settling and ascending <= 0:
		var input_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
		if input_moving: cancel_opening("移动输入")
		tick_ecology(delta)
		if ascending <= 0 and not settling: tick_opening(delta)
	if bag_open or settling or ascending > 0:
		reset_observation()
		refresh()
		return
	var direction := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
	if direction != Vector2.ZERO: moving = false
	elif moving:
		if foot.distance_to(target) < 4: moving = false
		else: direction = (target - foot).normalized()
	if direction != Vector2.ZERO: facing = direction
	var before := foot
	var motion := direction * minf(delta, 0.05) * swim_speed()
	if moving: motion = motion.limit_length(foot.distance_to(target))
	move_step(motion)
	model.update_movement(foot - before, delta)
	if moving and direction != Vector2.ZERO and foot.distance_to(before) < 0.01:
		moving = false
		message = "前方受阻，已停止；请用方向键或分段点击绕过缺口。"
	if not was_opening: tick_observation(delta)
	refresh()

func draw_creature(canvas: CanvasItem, p: Vector2, shape: String, color: Color, silhouette: bool = false) -> void:
	var ink := color.darkened(0.35) if silhouette else Color("#123346")
	match shape:
		"crab":
			for side in [-1, 1]:
				for i in 3:
					canvas.draw_line(p + Vector2(side * 10, i * 5 - 3), p + Vector2(side * (23 - i * 2), i * 7), color, 3)
				canvas.draw_line(p + Vector2(side * 11, -2), p + Vector2(side * 20, -14), color, 4)
				canvas.draw_circle(p + Vector2(side * 21, -15), 5, color)
			canvas.draw_circle(p, 13, color)
			canvas.draw_arc(p, 9, 0, TAU * 1.6, 24, ink, 2)
		"flatfish":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-25, 0), p + Vector2(-6, -13), p + Vector2(20, -6), p + Vector2(25, 0), p + Vector2(10, 12), p + Vector2(-12, 12)]), color)
			if not silhouette:
				for offset in [Vector2(-10, 0), Vector2(0, 7), Vector2(8, -5)]: canvas.draw_circle(p + offset, 3, ink)
		"eel":
			var points := PackedVector2Array()
			for i in 13: points.append(p + Vector2(-27 + i * 4, sin(i * 0.65) * 8))
			canvas.draw_polyline(points, color, 9, true)
			canvas.draw_circle(points[-1], 6, color)
		"jellyfish":
			for i in 5:
				var x := -16 + i * 8
				canvas.draw_polyline(PackedVector2Array([p + Vector2(x, 0), p + Vector2(x + 3, 13), p + Vector2(x - 2, 28)]), color, 2, true)
			var dome := PackedVector2Array()
			for i in 17: dome.append(p + Vector2(cos(PI + i * PI / 16) * 23, sin(PI + i * PI / 16) * 20))
			canvas.draw_colored_polygon(dome, color)
		"snail":
			canvas.draw_line(p + Vector2(-22, 12), p + Vector2(23, 12), color, 8)
			canvas.draw_circle(p + Vector2(-3, -1), 16, color)
			canvas.draw_arc(p + Vector2(-3, -1), 10, 0, TAU * 1.7, 32, ink, 2)
			canvas.draw_line(p + Vector2(17, 10), p + Vector2(23, -8), color, 3)
			canvas.draw_line(p + Vector2(13, 10), p + Vector2(13, -7), color, 3)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-26, -12), p + Vector2(-26, 12), p + Vector2(-10, 0)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 0), p + Vector2(-3, -12), p + Vector2(15, -9), p + Vector2(25, 0), p + Vector2(12, 11), p + Vector2(-3, 10)]), color)
			if shape == "angler":
				canvas.draw_polyline(PackedVector2Array([p + Vector2(6, -8), p + Vector2(10, -25), p + Vector2(23, -25), p + Vector2(25, -17)]), color, 2, true)
				canvas.draw_circle(p + Vector2(25, -17), 5, color if silhouette else Color("#fff1a1"))
	if not silhouette and shape not in ["jellyfish", "snail"]:
		canvas.draw_circle(p + Vector2(15 if shape != "crab" else 5, -4 if shape != "crab" else -10), 2, ink)

func draw_species() -> void:
	var entries := Catalog.species()
	for id in entries:
		var entry: Dictionary = entries[id]
		if entry.place != place: continue
		if host.creature_states.get(id, {}).get("respawn", 0) > 0: continue
		var p: Vector2 = species_position(id)
		var recorded: bool = host.species_records.get(id, false)
		draw_creature(self, p, entry.shape, entry.color)
		var state: Dictionary = host.creature_states.get(id, {})
		if state.get("warning", 0) > 0: draw_arc(p, 36, 0, TAU, 24, Color.RED, 3)
		if state.get("stun", 0) > 0: draw_string(ThemeDB.fallback_font, p - Vector2(25, 28), "硬直 · E活捕", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
		if entry.shape == "fish":
			draw_creature(self, p + Vector2(31, 18), "fish", entry.color.darkened(0.15))
		var nearby := foot.distance_to(p) <= Catalog.OBSERVE_RADIUS
		if nearby or observing_id == id:
			draw_arc(p, Catalog.OBSERVE_RADIUS, 0, TAU, 48, Color(0.6, 0.9, 1, 0.35), 1)
		var text: String = entry.name + " · 已记录" if recorded else "未知生物 · 靠近观察"
		if observation_blocked.has(id): text = "保存失败 · 离圈重试"
		elif observing_id == id:
			draw_arc(p, 31, -PI / 2, -PI / 2 + TAU * observation_elapsed / Catalog.OBSERVE_SECONDS, 48, Color("#b4f5c4"), 4)
			text = "观察 %.1f / %.0f秒" % [observation_elapsed, Catalog.OBSERVE_SECONDS]
		draw_string(ThemeDB.fallback_font, p + Vector2(-55, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b4f5c4") if recorded else Color.WHITE)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071b2b"))
	if not settlement.is_empty(): return
	if read_only:
		draw_rect(Rect2(52, 12, 1166, 120), Color("#102b38"))
		draw_rect(Rect2(52, 12, 4, 120), Art.AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(74, 34), "探索档案   /   FIELD ARCHIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Art.AMBER)
		draw_rect(Rect2(52, 192, 1166, 436), Color("#102b38"))
		draw_rect(Rect2(52, 635, 1166, 76), Color("#17353e"))
		draw_rect(Rect2(52, 635, 4, 76), Art.GLASS)
		return
	# 福地背景仅作水下氛围；通行区域和真实障碍始终使用原矩形。
	draw_texture_rect(BACKDROPS[place], FIELD, false, Color("#78cbdc"))
	draw_rect(FIELD, {"shoal": Color(0.03, 0.28, 0.36, 0.72), "wreck": Color(0.02, 0.17, 0.26, 0.78), "trench": Color(0.01, 0.10, 0.22, 0.82)}[place])
	Art.water(self, place, elapsed)
	for obstacle in obstacles():
		draw_rect(obstacle, {"shoal": Color("#365962"), "wreck": Color("#3a4855"), "trench": Color("#202d44")}[place])
		for y in range(int(obstacle.position.y + 14), int(obstacle.end.y), 24):
			draw_line(Vector2(obstacle.position.x + 4, y), Vector2(minf(obstacle.position.x + 20, obstacle.end.x - 4), minf(y + 12, obstacle.end.y - 3)), Color("#66828c"), 2)
		Art.barrier(self, obstacle, place)
	if place == "wreck":
		draw_string(ThemeDB.fallback_font, Vector2(275, 285), "船头堵死", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(350, 510), "船尾缺口 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	elif place == "trench":
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
	# 暗区也保留碰撞边界，避免背景里的桥路被误认为实际通道。
	draw_rect(FIELD, Color("#83bccb"), false, 2)
	for obstacle in obstacles(): draw_rect(obstacle, Color("#8bb3bd"), false, 2)
	Art.hud(self, FIELD, place)
	if not at_safety():
		var arrow := (safety_position() - foot).normalized()
		var tip := foot + arrow * 48
		draw_line(foot + arrow * 24, tip, Art.GLASS, 3)
		draw_line(tip, tip - arrow.rotated(0.55) * 12, Art.GLASS, 3)
		draw_line(tip, tip - arrow.rotated(-0.55) * 12, Art.GLASS, 3)
	if moving:
		draw_arc(target, 10, 0, TAU, 20, Color("#ffe6a4"), 2)
		draw_line(target - Vector2(15, 0), target + Vector2(15, 0), Color("#ffe6a4"), 2)
	draw_species()
	for shell in tidal_shells():
		draw_circle(shell[1], 14, Color.CYAN)
		draw_string(ThemeDB.fallback_font, shell[1] - Vector2(35, 22), "临时贝群 · E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for site in sites():
		if site[0] == "上浮出口":
			Art.beacon(self, site[1], Catalog.SAFETY_RADIUS, elapsed)
		else:
			draw_circle(site[1], 19, Art.INK)
			draw_arc(site[1], 19, 0, TAU, 32, Color("#84b9bc"), 1.5)
			draw_texture_rect(SITE_MARKER, Rect2(site[1] - Vector2(10, 13), Vector2(20, 25)), false)
		var text := site_text(site[0])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var label_at := Vector2(clampf(site[1].x - width / 2, FIELD.position.x, FIELD.end.x - width), site[1].y - 30)
		draw_rect(Rect2(label_at - Vector2(3, 18), Vector2(width + 6, 23)), Color("#0b2034d9"))
		draw_string(ThemeDB.fallback_font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.GLASS if site[0] == "上浮出口" else Color.WHITE)
	draw_circle(foot, RADIUS, Color(0.03, 0.12, 0.18, 0.65))
	draw_arc(foot, RADIUS, 0, TAU, 24, Color("#fff4cf"), 2)
	for node in Catalog.NODES[place]:
		if place != "shoal" and foot.distance_to(node[2]) > light_radius():
			if host.equipment_level("mask") >= 2:
				draw_rect(Rect2(node[2] - Vector2(12, 12), Vector2(24, 24)), Color("#768d9d"), false, 2)
			continue
		var quality := Catalog.chest_quality(place, node[0])
		var tint: Color = Catalog.CHESTS[quality].color
		var empty := stock_text(node[0]).contains("(0)")
		var p: Vector2 = node[2]
		draw_texture_rect(CHEST_ART, Rect2(p + Vector2(-24, -24), Vector2(48, 48)), false, Color("#687980") if empty else Color.WHITE)
		draw_rect(Rect2(p + Vector2(-25, -21), Vector2(50, 42)), tint, false, 2)
		if empty:
			draw_line(p + Vector2(-17, -15), p + Vector2(17, 15), Color("#d4dde1"), 3)
			draw_line(p + Vector2(17, -15), p + Vector2(-17, 15), Color("#d4dde1"), 3)
		draw_string(ThemeDB.fallback_font, p + Vector2(-53, -25), Catalog.CHESTS[quality].name + "宝箱 " + stock_text(node[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if not opening.is_empty() and opening.id == node[0]:
			draw_rect(Rect2(p + Vector2(-25, 23), Vector2(50, 6)), Color("#18394a"))
			draw_rect(Rect2(p + Vector2(-25, 23), Vector2(50 * (1 - opening_left / opening_total), 6)), tint)
	for drop in drops:
		if drop.place == place:
			draw_circle(drop.position, 8, Color.ORANGE)
			draw_string(ThemeDB.fallback_font, drop.position + Vector2(12, 12), "拾 " + Catalog.item_name(drop.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var chosen := nearest_target()
	if not chosen.is_empty(): draw_arc(chosen.position, 25, 0, TAU, 24, Color.YELLOW, 3)
	var ratio := oxygen / oxygen_max()
	draw_rect(Rect2(345, 69, 232, 4), Color("#284a53"))
	draw_rect(Rect2(345, 69, 232 * ratio, 4), Art.AMBER if warned else Art.GLASS)
	for i in range(1, 8):
		draw_line(Vector2(345 + i * 29, 69), Vector2(345 + i * 29, 73), Art.INK, 1)
	if ratio <= 0.15:
		var shade := Color(0, 0, 0, 0.65 * (1.0 - ratio / 0.15))
		for edge in [Rect2(0, 0, 45, 720), Rect2(1235, 0, 45, 720), Rect2(0, 0, 1280, 20), Rect2(0, 700, 1280, 20)]: draw_rect(edge, shade)
	if bag_open:
		draw_rect(FIELD, Color("#04131eb8"))
		draw_rect(BAG_RECT, Color("#102b38"))
		draw_rect(BAG_RECT, Color("#69958f"), false, 1)
		draw_rect(Rect2(301, 221, 678, 63), Color("#21434c"))
		draw_string(ThemeDB.fallback_font, Vector2(320, 244), "打捞装备   /   CARGO NET", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.GLASS)
		draw_string(ThemeDB.fallback_font, Vector2(320, 273), "临时网袋", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(800, 264), "%02d / %02d  格" % [used_slots(), capacity()], HORIZONTAL_ALIGNMENT_RIGHT, 155, 24, Art.AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(320, 302), "按件占格 · 拖出面板丢弃", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Art.GLASS)
		for i in capacity():
			var slot_rect := bag_slot(i)
			draw_rect(slot_rect, Color("#183540"))
			draw_rect(slot_rect, Color("#395d65"), false, 1)
			draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(7, 17), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9db8b7"))
		draw_line(Vector2(320, 486), Vector2(958, 486), Color("#45636b"))
		draw_string(ThemeDB.fallback_font, Vector2(320, 511), "注意  /  氧气继续消耗，安全上浮后才会入库。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(872, 511), "[ B ]  关闭", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.GLASS)
		var slot := 0
		for i in bag.size():
			var id: String = bag[i]
			for offset in Catalog.item_slots(id):
				var cell := bag_slot(slot + offset).grow(-4)
				draw_rect(cell, Color("#375c70"))
				draw_string(ThemeDB.fallback_font, cell.position + Vector2(2, 28), "%d %s" % [i + 1, Catalog.item_name(id)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			slot += Catalog.item_slots(id)
