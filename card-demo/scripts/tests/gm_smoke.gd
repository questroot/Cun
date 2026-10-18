extends SceneTree
## 仅在隔离副本中运行：application/config/custom_user_dir_name 必须以 Cun-GM-Test- 开头。
## --headless --path ISOLATED_PROJECT --script res://scripts/tests/gm_smoke.gd
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])

func run_checks() -> void:
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-GM-Test-"):
		printerr("GM tests require an isolated project and test save directory.")
		quit(2)
		return
	await process_frame
	var data := root.get_node("DataManager")
	var game := root.get_node("GameManager")
	var battle := root.get_node("BattleManager")
	data.save_data["owned_pets"] = data.available_pets()
	data.save_data["unlocked_stage"] = 1
	for id: String in data.available_pets():
		data.save_data["levels"][id] = 1
		data.save_data["exp"][id] = 37
	data.save_data["levels"]["hero"] = 4
	data.save_data["levels"]["sprout"] = 30
	var before: Dictionary = data.save_data.duplicate(true)
	var invalid: Array[String] = ["hero", "enemy_seed", "missing"]
	for id: String in invalid:
		check(raise_levels(["metal", id], 20) == -1 and data.save_data == before, "拒绝无效/非宠物请求且无部分写入: " + id)
	check(raise_levels([], 10) == -1, "拒绝空升级请求")
	check(raise_levels(["metal"], 0) == -1 and raise_levels(["metal"], 1000) == -1, "校验 GM 等级范围")
	check(raise_levels(["metal"], 12) == 1 and data.save_data["levels"]["metal"] == 12, "未上阵金犼也能单独提升等级")
	check(raise_levels(["metal"], 10) == 0 and data.save_data["levels"]["metal"] == 12, "目标较低时不会降级")
	check(raise_levels(data.owned_pets(), 20) == 4 and data.save_data["levels"]["sprout"] == 30, "批量升级保留已有高等级")
	check(data.save_data["exp"] == before["exp"] and data.save_data["levels"]["hero"] == 4 and data.save_data["team"] == before["team"] and data.save_data["formation"] == before["formation"], "升级保留经验、主角、队伍和阵位")
	data.load_save()
	check(data.save_data["levels"]["metal"] == 20 and data.save_data["exp"]["metal"] == 37, "重新读取存档保留升级结果和经验")
	data.save_data["owned_pets"] = ["metal"]
	check(raise_levels(["ember"], 50) == -1 and data.save_data["levels"]["ember"] == 20, "不能升级未拥有的宠物")
	data.save_data["owned_pets"] = data.available_pets()
	var city = load("res://scenes/MainCity.tscn").instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	check(city.gm_button != null and not city.gm_panel.visible, "主城存在 GM 入口且面板默认关闭")
	city.toggle_pet_bag()
	city._select_pet("metal")
	city.open_gm_panel()
	var gm = city.gm_panel
	check(gm.visible and not city.pet_bag.visible and gm.pet_picker.get_item_metadata(gm.pet_picker.selected) == "metal", "背包选中宠物可带入 GM 面板")
	check(gm.stage_picker.item_count == 10 and gm.z_index > city.npc.z_index, "GM 列出合并后的十关且位于世界角色上方")
	city.set_destination(Vector2(600, 550))
	city.open_gm_panel()
	var foot: Vector2 = city.player_foot
	city._process(1.0)
	check(city.player_foot == foot and not city.has_destination, "GM 打开时停止寻路与世界移动")
	gm.level_input.get_line_edit().text = "25"
	gm.raise_button.pressed.emit()
	check(data.save_data["levels"]["metal"] == 25 and gm.feedback.text.contains("已保存"), "升级按钮应用手输目标等级并反馈保存结果")
	gm.level_input.get_line_edit().text = "22"
	gm.raise_all_button.pressed.emit()
	check(data.save_data["levels"]["ember"] == 22 and data.save_data["levels"]["metal"] == 25 and data.save_data["levels"]["sprout"] == 30, "批量升级按钮提升低等级宠物并保留更高等级")
	await process_frame
	await process_frame
	check(gm.level_input.size.y < 60 and gm.panel.get_global_rect().encloses(gm.jump_button.get_global_rect()), "默认分辨率下等级输入与跳转按钮完整显示")
	if DisplayServer.get_name() != "headless":
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var capture_path := "user://gm_preview.png"
		check(root.get_texture().get_image().save_png(capture_path) == OK, "GM 面板真实窗口渲染截图")
		print("GM_CAPTURE: " + ProjectSettings.globalize_path(capture_path))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	city._unhandled_input(escape)
	check(not gm.visible, "Esc 关闭 GM 面板")
	data.save_data["owned_pets"] = []
	gm.open_for_pet()
	check(gm.pet_picker.disabled and gm.raise_button.disabled and gm.raise_all_button.disabled, "空背包禁用升级操作")
	data.save_data["owned_pets"] = data.available_pets()
	gm.open_for_pet("metal")
	check(not game.gm_jump_to_stage("stage_999") and not game.gm_jump_to_stage("bad") and data.save_data["unlocked_stage"] == 1, "无效跳关不会修改解锁状态")
	game.select_stage("stage_3")
	check(not game.stage_pending, "普通选关仍拒绝未解锁关卡")
	gm.stage_picker.select(9)
	gm.jump_button.pressed.emit()
	await process_frame
	await process_frame
	check(game.current_stage == "stage_10" and game.stage_pending and current_scene.scene_file_path.ends_with("TeamSelect.tscn"), "GM 从第一关跳至第十关实际编队场景")
	data.load_save()
	check(int(data.save_data["unlocked_stage"]) == 10 and int(data.save_data["levels"]["metal"]) == 25, "第十关跳关与升级进度均持久保存")
	current_scene.save_team(true)
	await process_frame
	await process_frame
	check(current_scene.scene_file_path.ends_with("Battle.tscn") and game.current_stage == "stage_10" and battle.running, "编队确认后进入所选第十关战斗")
	var grown_pet: BattleUnit = null
	for unit: BattleUnit in battle.allies:
		if unit.id == "sprout":
			grown_pet = unit
	check(grown_pet != null and grown_pet.max_hp == int(data.get_entry("units", "sprout")["hp"]) + 29 * int(data.tables["rules"]["level_growth"]["hp"]), "升级后的宠物属性实际进入战斗")
	battle.running = false
	game.finish_battle(true)
	data.load_save()
	check(int(data.save_data["unlocked_stage"]) == 10, "第十关胜利后解锁上限仍为十关且持久保存")
	check(game.gm_jump_to_stage("stage_1") and int(data.save_data["unlocked_stage"]) == 10, "回跳低关卡不会降低十关解锁进度")
	await process_frame
	await process_frame
	current_scene.save_team(false)
	await process_frame
	await process_frame
	check(not game.stage_pending and current_scene.scene_file_path.ends_with("MainCity.tscn"), "取消跳关编队后安全回到主城")
	print("GM_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func raise_levels(ids: Array[String], target: int) -> int:
	return root.get_node("DataManager").gm_raise_pet_levels(ids, target)
