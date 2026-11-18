extends SceneTree

const Editor = preload("res://scripts/scenes/public_project_editor.gd")
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
var checks := 0
var failures := 0
var editor: VBoxContainer
var previews: Array[Dictionary] = []
var confirmations: Array[Dictionary] = []
var closes := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func fixture() -> Dictionary:
	return {
		"balances": {"coral": 5, "shell": 2, "timber": 7, "copper": 0, "algae": 9, "pearl": 3},
		"bag_items": {"coral": 99, "pearl": 99},
		"deficits": {"coral": 3, "shell": 8, "timber": 0, "copper": 4, "algae": 6, "pearl": 3}
	}

func settle() -> void:
	for index in range(4):
		await process_frame

func button(text: String) -> Button:
	for node: Node in editor.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func edit(id: String, text: String) -> void:
	var input: LineEdit = editor.inputs[id]
	input.text = text
	input.text_changed.emit(text)

func preview_fixture(token: String = "memory-only-token") -> Dictionary:
	var amounts := {}
	var after: Dictionary = fixture().balances.duplicate()
	for id: String in editor.inputs:
		amounts[id] = int(editor.inputs[id].text)
		after[id] -= amounts[id]
	return {"token": token, "amounts": amounts, "before": fixture().balances, "after": after}

func reset() -> void:
	editor.configure(fixture())

func configure_tests() -> void:
	for id: String in Catalog.ITEMS:
		check(editor.inputs.has(id) and editor.inputs[id].text == "0", "configure初始为0 " + id)
	check(not editor.pearl_choice.button_pressed and not editor.inputs.pearl.editable, "珍珠默认未选择且不可编辑")
	check(editor.confirm_button.disabled and not editor.pearl_confirmation.visible, "初始无确认令牌")
	edit("coral", "2")
	editor.show_preview(preview_fixture())
	var data := fixture()
	editor.configure(data, "shell")
	data.balances.shell = 100
	await settle()
	check(editor.context.balances.shell == 2, "configure深复制上下文")
	for id: String in Catalog.ITEMS:
		check(editor.inputs[id].text == "0", "configure重置草稿 " + id)
	check(editor.inputs.shell.has_focus(), "configure聚焦指定普通资源")
	check(editor.confirm_button.disabled and editor._token.is_empty(), "configure清除旧预览令牌")
	editor.configure(fixture(), "pearl")
	await settle()
	check(editor.inputs.pearl.has_focus() and not editor.inputs.pearl.editable, "聚焦珍珠不自动选择")
	reset()

func rejection_tests() -> void:
	for id: String in Catalog.ITEMS:
		for text: String in ["", " ", "\t", "-1", "1.5", "+1", "abc", "10000000", str(int(fixture().balances[id]) + 1)]:
			reset()
			if id == "pearl": editor.pearl_choice.button_pressed = true
			edit(id, text)
			var count := previews.size()
			editor.preview_button.pressed.emit()
			check(previews.size() == count and not editor.message.text.is_empty() and editor.confirm_button.disabled, "拒绝非法数量 %s=%s" % [id, text.c_escape()])
	reset()
	var count := previews.size()
	editor.preview_button.pressed.emit()
	check(previews.size() == count and editor.message.text.contains("至少"), "全0拒绝预览")
	edit("coral", "6")
	editor.preview_button.pressed.emit()
	check(previews.size() == count, "待袋资源不可作为库存投料")

func interaction_tests() -> void:
	reset()
	button("按缺口填入普通资源").pressed.emit()
	for id: String in Catalog.ITEMS:
		var expected := 0 if id == "pearl" else mini(int(fixture().balances[id]), int(fixture().deficits[id]))
		check(editor.inputs[id].text == str(expected), "普通缺口填入且不超库存 " + id)
	check(not editor.pearl_choice.button_pressed, "缺口填入不主动选珍珠")
	editor.preview_button.pressed.emit()
	check(previews.back().amounts.pearl == 0 and not previews.back().pearl_selected, "普通预览信号无珍珠")
	editor.show_preview(preview_fixture("ordinary-token"))
	check(not editor.confirm_button.disabled and not editor.pearl_confirmation.visible, "普通预览可直接确认")
	editor.confirm_button.pressed.emit()
	check(confirmations.back() == {"token": "ordinary-token", "pearl_confirmed": false}, "普通确认信号携带令牌")
	check(editor.confirm_button.disabled, "发出确认后按钮锁定")
	reset()
	var count := previews.size()
	editor._step("pearl", 1)
	check(editor.inputs.pearl.text == "0" and not editor.message.text.is_empty(), "未主动选择禁止珍珠加1")
	edit("pearl", "1")
	editor.preview_button.pressed.emit()
	check(previews.size() == count and editor.message.text.contains("主动选择"), "未主动选择珍珠不得预览")
	editor.pearl_choice.button_pressed = true
	check(editor.inputs.pearl.editable, "主动选择后珍珠可编辑")
	editor.preview_button.pressed.emit()
	check(previews.size() == count + 1 and previews.back().pearl_selected and previews.back().amounts.pearl == 1, "珍珠预览明确携带主动选择")
	editor.show_preview(preview_fixture("pearl-token"))
	check(editor.pearl_confirmation.visible and not editor.pearl_confirmation.button_pressed, "珍珠必须独立额外确认")
	count = confirmations.size()
	editor.confirm_button.pressed.emit()
	check(confirmations.size() == count and editor.message.text.contains("额外确认"), "未额外确认拒绝提交")
	# 拒绝后令牌被清除，必须重新预览，不伪造服务端反馈。
	editor.preview_button.pressed.emit()
	editor.show_preview(preview_fixture("pearl-repreview"))
	editor.pearl_confirmation.button_pressed = true
	editor.confirm_button.pressed.emit()
	check(confirmations.size() == count + 1 and confirmations.back() == {"token": "pearl-repreview", "pearl_confirmed": true}, "额外确认后发送珍珠确认意图")
	button("按缺口填入普通资源").pressed.emit()
	check(editor.inputs.pearl.text == "1", "缺口填入不会改写手动珍珠数量")
	for mutation: String in ["text", "step", "clear", "fill", "pearl_off"]:
		reset()
		editor.pearl_choice.button_pressed = true
		edit("pearl", "1")
		edit("coral", "1")
		editor.show_preview(preview_fixture())
		editor.pearl_confirmation.button_pressed = true
		match mutation:
			"text": edit("coral", "2")
			"step": editor._step("coral", 1)
			"clear": editor._clear("coral")
			"fill": button("按缺口填入普通资源").pressed.emit()
			"pearl_off": editor.pearl_choice.button_pressed = false
		check(editor._token.is_empty() and editor.confirm_button.disabled and not editor.pearl_confirmation.visible and not editor.pearl_confirmation.button_pressed, "编辑使预览及额外确认失效 " + mutation)
		count = confirmations.size()
		editor._confirm()
		check(confirmations.size() == count, "失效令牌不能确认 " + mutation)
	check(editor.inputs.pearl.text == "0" and not editor.inputs.pearl.editable, "取消选珠清零且锁编辑")
	count = closes
	button("取消并返回基地").pressed.emit()
	check(closes == count + 1, "关闭发出一次close_requested")

func capture_tests() -> void:
	var host := Window.new()
	host.title = "公共工程 · 投料结果 · 隔离布局检查"
	host.visible = false
	host.exclusive = true
	host.transient = true
	host.wrap_controls = false
	root.add_child(host)
	editor.reparent(host)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var data := fixture()
	data.balances.copper = 5
	editor.configure(data)
	editor.pearl_choice.button_pressed = true
	for id: String in Catalog.ITEMS:
		edit(id, "1")
	var preview := preview_fixture()
	preview.before = data.balances.duplicate()
	preview.after.copper = 4
	editor.show_preview(preview)
	# 同时保留六行预览与错误提示，覆盖固定尾部最挤的真实状态。
	editor.show_error("库存已变化，请重新预览。")
	var scroll: ScrollContainer = editor.get_child(2)
	for dimensions: Vector2i in [Vector2i(480, 720), Vector2i(960, 540)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		var host_size := Vector2i(mini(800, dimensions.x - 24), mini(550, dimensions.y - 24))
		host.popup_centered(host_size)
		await settle()
		check(DisplayServer.get_name() != "headless" and root.size == dimensions, "原生窗口尺寸 " + str(dimensions))
		check(host.size == host_size, "真实宿主弹窗尺寸 " + str(host_size))
		var bounds := Rect2(Vector2.ZERO, Vector2(host_size))
		check(bounds.encloses(editor.get_global_rect()), "编辑器整体不越界 " + str(dimensions))
		check(scroll.size.y > 80, "滚动区保留可用高度 " + str(dimensions))
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "无横向溢出 " + str(dimensions))
		for control: Control in [editor.preview_button, editor.confirm_button, button("取消并返回基地")]:
			check(bounds.encloses(control.get_global_rect()) and control.size.y >= 40, "固定按钮可见 " + control.text + str(dimensions))
		for id: String in editor.inputs:
			var input: LineEdit = editor.inputs[id]
			check(input.get_global_rect().position.x >= 0 and input.get_global_rect().end.x <= host_size.x, "输入框横向完整 " + id + str(dimensions))
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		check(scroll.get_global_rect().encloses(editor.pearl_confirmation.get_global_rect()), "滚至底部珍珠额外确认完整可达 " + str(dimensions))
		await RenderingServer.frame_post_draw
		var path := "user://public-project-editor-%dx%d.png" % [dimensions.x, dimensions.y]
		check(host.get_texture().get_image().save_png(path) == OK, "保存真实宿主截图 " + path)
		print("RESULT: screenshot ", ProjectSettings.globalize_path(path), " host=", host.size, " scroll=", scroll.size)
		host.hide()

func host_frame_tests() -> void:
	var activity = load("res://scenes/WaterActivity.tscn").instantiate()
	root.add_child(activity)
	await settle()
	activity.open_public_project_editor()
	await settle()
	check(activity._public_project_operation == "editor" and activity._public_project_window.visible, "真实海面宿主打开editor并逐帧保持")
	check(not activity._public_project_panels.has("editor") and not activity._public_project_snapshots.has("editor"), "editor不伪造结果面板和快照")
	activity._sync_public_project_actions("missing")
	var panel := preload("res://scripts/scenes/public_project_result_panel.gd").new()
	activity._public_project_panels["missing_snapshot"] = panel
	activity._sync_public_project_actions("missing_snapshot")
	activity._public_project_panels.erase("missing_snapshot")
	panel.free()
	activity._public_project_panels["freed"] = panel
	activity._public_project_snapshots["freed"] = {}
	activity._sync_public_project_actions("freed")
	activity._public_project_panels.erase("freed")
	activity._public_project_snapshots.erase("freed")
	await settle()
	check(is_instance_valid(activity._public_project_editor), "缺失键和已释放面板不影响editor宿主逐帧运行")
	activity._close_public_project_result("editor")
	await settle()
	check(not activity._public_project_window.visible and not is_instance_valid(activity._public_project_editor), "editor取消关闭且不残留弹窗")
	activity.queue_free()
	await settle()

func run() -> void:
	# 在创建任何测试节点或写入截图之前拒绝非隔离用户目录。
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) or String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).is_empty():
		print("FAIL: 必须从启用custom_user_dir且配置独立目录名的隔离工程运行")
		quit(2)
		return
	root.size = Vector2i(480, 720)
	editor = Editor.new()
	editor.configure(fixture(), "coral")
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.preview_requested.connect(func(amounts: Dictionary, selected: bool) -> void: previews.append({"amounts": amounts.duplicate(true), "pearl_selected": selected}))
	editor.confirm_requested.connect(func(token: String, confirmed: bool) -> void: confirmations.append({"token": token, "pearl_confirmed": confirmed}))
	editor.close_requested.connect(func() -> void: closes += 1)
	await settle()
	check(editor.inputs.coral.has_focus(), "ready前configure聚焦")
	await configure_tests()
	rejection_tests()
	interaction_tests()
	await host_frame_tests()
	if "--editor-capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			check(false, "图形布局检查禁止使用headless")
		else:
			await capture_tests()
	print("RESULT: public_project_editor checks=", checks, " failures=", failures, " display=", DisplayServer.get_name())
	quit(1 if failures > 0 else 0)
