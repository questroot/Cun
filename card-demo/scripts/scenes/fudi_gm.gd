extends CanvasLayer
## Round-local developer controls; the player-only MCP bridge cannot use these operations.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const SPEEDS := [1.0, 2.0, 3.0, 5.0, 10.0]
var game
var multiplier := 1.0
var entry_button: Button
var modal: Control
var panel: PanelContainer
var speed_picker: OptionButton
var map_picker: OptionButton
var quest_picker: OptionButton
var feedback: Label
var progress: Label
var close_button: Button
var travel_button: Button
var complete_button: Button
var complete_all_button: Button

func _ready() -> void:
	game = get_parent()
	layer = 130
	set_meta("cun_play_blocked", true)
	entry_button = UI.button("GM · F8", open)
	entry_button.name = "FudiGMButton"
	entry_button.set_meta("cun_play_blocked", true)
	entry_button.position = Vector2(1076, 28)
	entry_button.size.x = 160
	entry_button.visible = allowed()
	add_child(entry_button)
	_build()
	modal.hide()
	if game.has_method("register_menu_action"):
		game.register_menu_action(entry_button)

func allowed() -> bool:
	return OS.get_environment("CUN_PLAY_TOKEN").length() < 32

func is_open() -> bool:
	return modal != null and modal.visible

func speed_multiplier() -> float:
	return multiplier if allowed() else 1.0

func _build() -> void:
	modal = Control.new()
	modal.name = "FudiGMPanel"
	modal.set_meta("cun_play_blocked", true)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.03, 0.04, 0.85)
	modal.add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", UI.panel())
	modal.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	scroll.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := UI.label("福地 GM 工具", 26, Color("#f4daa0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = UI.button("关闭 · Esc", close)
	heading.add_child(close_button)
	var note := UI.label("本轮有效，重新开局恢复默认。任务线完成后可按 B 回看调查见闻。", 17)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(note)
	layout.add_child(UI.label("加速移动", 21, Color("#f4daa0")))
	speed_picker = OptionButton.new()
	speed_picker.custom_minimum_size.y = 42
	for speed: float in SPEEDS:
		speed_picker.add_item("%d 倍移速%s" % [int(speed), " · 正常速度" if speed == 1.0 else ""])
	speed_picker.item_selected.connect(func(index: int) -> void: set_speed_multiplier(SPEEDS[index]))
	layout.add_child(speed_picker)
	layout.add_child(HSeparator.new())
	layout.add_child(UI.label("移动至指定地图", 21, Color("#f4daa0")))
	map_picker = OptionButton.new()
	map_picker.custom_minimum_size.y = 42
	layout.add_child(map_picker)
	travel_button = UI.button("传送至所选地图出生点", _travel_selected)
	layout.add_child(travel_button)
	layout.add_child(HSeparator.new())
	layout.add_child(UI.label("完成人物任务线", 21, Color("#f4daa0")))
	quest_picker = OptionButton.new()
	quest_picker.custom_minimum_size.y = 42
	quest_picker.item_selected.connect(func(_index: int) -> void: _refresh_progress())
	layout.add_child(quest_picker)
	progress = UI.label("", 17)
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(progress)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	complete_button = UI.button("完成所选人物任务线", _complete_selected)
	actions.add_child(complete_button)
	complete_all_button = UI.button("完成全部人物任务线", func() -> void: _show_completion(complete_questline("", true)))
	actions.add_child(complete_all_button)
	feedback = UI.label("", 17, Color("#f4daa0"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 48
	layout.add_child(feedback)

func open() -> void:
	if not allowed() or game.finished or game._paused():
		return
	feedback.text = ""
	speed_picker.select(SPEEDS.find(multiplier))
	map_picker.clear()
	quest_picker.clear()
	var characters: Array[String] = []
	for id: String in Maps.IDS:
		map_picker.add_item(Catalog.REGIONS[id].name)
		map_picker.set_item_metadata(map_picker.item_count - 1, id)
		if id == game.region:
			map_picker.select(map_picker.item_count - 1)
		var npc: String = Maps.MAPS[id].npc
		if not characters.has(npc):
			characters.append(npc)
			quest_picker.add_item(npc)
			quest_picker.set_item_metadata(quest_picker.item_count - 1, npc)
	quest_picker.select(characters.find(str(Maps.MAPS[game.region].npc)))
	_refresh_progress()
	game.set_meta("fudi_gm_open", true)
	modal.show()
	game.model.update_movement(Vector2.ZERO, 0)
	close_button.grab_focus()

func close() -> void:
	modal.hide()
	game.set_meta("fudi_gm_open", false)
	entry_button.release_focus()

func set_speed_multiplier(value: float) -> bool:
	if not allowed() or not SPEEDS.has(value):
		return false
	multiplier = value
	speed_picker.select(SPEEDS.find(value))
	entry_button.text = "GM ×%d · F8" % int(value) if value > 1.0 else "GM · F8"
	feedback.text = "移动速度已设为 %d 倍。" % int(value)
	return true

func teleport(id: String) -> bool:
	if not allowed() or game.finished or not Maps.IDS.has(id) or not game.states.has(id):
		return false
	var spawn: Vector2 = Maps.MAPS[id].spawn * Maps.MAPS[id].size
	if not Maps.walkable(id, spawn):
		return false
	# Reuse travel's encounter/projectile cleanup, then use spawn even when travelling in-place.
	game.enter_region(id)
	game.player_foot = spawn
	game.states[id].foot = spawn
	game.model.position = spawn
	game.model.update_movement(Vector2.ZERO, 0)
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	return true

func complete_questline(npc: String, all_lines: bool = false) -> int:
	if not allowed() or game.finished:
		return -1
	var ids: Array[String] = []
	for id: String in Maps.IDS:
		if all_lines or str(Maps.MAPS[id].npc) == npc:
			if not game.states.has(id) or game.states[id].visited.size() != Maps.MAPS[id].sites.size():
				return -1
			ids.append(id)
	if ids.is_empty():
		return -1
	var changed := 0
	for id: String in ids:
		for index in range(game.states[id].visited.size()):
			if not game.states[id].visited[index]:
				game.states[id].visited[index] = true
				changed += 1
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()
	_refresh_progress()
	return changed

func _refresh_progress() -> void:
	if quest_picker.selected < 0:
		return
	var npc: String = str(quest_picker.get_item_metadata(quest_picker.selected))
	var completed := 0
	var total := 0
	for id: String in Maps.IDS:
		if str(Maps.MAPS[id].npc) == npc:
			total += Maps.MAPS[id].sites.size()
			for visited: bool in game.states[id].visited:
				if visited:
					completed += 1
	progress.text = "%s：调查见闻 %d / %d  ·  全部人物 %d / %d" % [npc, completed, total, game._visited_total(), Maps.site_total()]

func _travel_selected() -> void:
	if map_picker.selected >= 0 and teleport(str(map_picker.get_item_metadata(map_picker.selected))):
		close()
	else:
		feedback.text = "传送失败，请确认地图与出生点有效。"

func _complete_selected() -> void:
	if quest_picker.selected >= 0:
		_show_completion(complete_questline(str(quest_picker.get_item_metadata(quest_picker.selected))))

func _show_completion(changed: int) -> void:
	feedback.text = "已补齐 %d 条调查见闻，可关闭面板后按 B 回看。" % changed if changed > 0 else "任务线已经完成，无需重复操作。" if changed == 0 else "任务线无效，未修改进度。"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if is_open():
			if key in [KEY_ESCAPE, KEY_F8]:
				close()
			if key not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				get_viewport().set_input_as_handled()
		elif key == KEY_F8 and allowed():
			open()
			get_viewport().set_input_as_handled()
