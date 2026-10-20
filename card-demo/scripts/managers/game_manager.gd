extends Node
## 场景路由与待进入关卡状态。
signal stage_selected(stage_id: String)
var current_stage := "stage_1"
var stage_pending := false
var city_spawn := Vector2(334, 558)
var last_result := ""
var water_activity_state: Dictionary = {}
const SEA_SAVE := "user://sea_chapter_v1.json"
const SEA_TEMP := "user://sea_chapter_v1.json.tmp"
const SEA_BACKUP := "user://sea_chapter_v1.json.bak"
var sea_save_error := ""

func _ready() -> void:
	load_sea_save()

func _read_sea_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	return _read_sea_text(file.get_as_text())

func _read_sea_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("state") is Dictionary:
		return {}
	var state: Dictionary = parsed["state"]
	for key in ["wood", "scrap", "water", "fiber", "rope", "raft_tiles", "collectors", "orders_completed", "pending_water", "pending_fiber"]:
		if not (state.get(key) is float or state.get(key) is int) or state[key] < 0 or state[key] > 1000000 or state[key] != floor(state[key]):
			return {}
	for key in ["automated_collecting", "workshop_built", "resident", "resident_working", "partner", "blueprint", "tide_table", "delegated", "neighbor_surveyed"]:
		if not state.get(key) is bool:
			return {}
	if not state.get("debris") is Array or not state.get("player_foot") is Array or state.player_foot.size() != 2 or state.debris.size() > 5:
		return {}
	for point in [state.player_foot] + state.debris:
		if not point is Array or point.size() != 2 or not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):
			return {}
		if absf(float(point[0])) > 10000 or absf(float(point[1])) > 10000:
			return {}
	for key in ["production_elapsed", "debris_elapsed"]:
		if not (state.get(key) is float or state.get(key) is int) or state[key] < 0 or state[key] > 100:
			return {}
	if not state.get("result") is String or state.result.length() > 300 or int(state.collectors) > int(state.raft_tiles) - 1 or int(state.raft_tiles) < 1:
		return {}
	return state

func load_sea_save() -> void:
	sea_save_error = ""
	var state := _read_sea_file(SEA_SAVE)
	if state.is_empty():
		state = _read_sea_file(SEA_BACKUP + ".pending")
		if state.is_empty():
			state = _read_sea_file(SEA_BACKUP)
		if not state.is_empty():
			sea_save_error = "海上主档不可用，已从备份恢复；请核对进度。"
		elif FileAccess.file_exists(SEA_SAVE) or FileAccess.file_exists(SEA_BACKUP) or FileAccess.file_exists(SEA_BACKUP + ".pending"):
			sea_save_error = "海上存档损坏，未覆盖原档；请先备份文件。"
	water_activity_state = state

func save_sea_state(state: Dictionary) -> bool:
	sea_save_error = ""
	var text := JSON.stringify({"version": 1, "state": state})
	if _read_sea_text(text).is_empty():
		sea_save_error = "海上存档数据无效，未保存。"
		return false
	var file := FileAccess.open(SEA_TEMP, FileAccess.WRITE)
	if file == null:
		sea_save_error = "海上存档临时文件写入失败，进度未提交。"
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_sea_file(SEA_TEMP).is_empty():
		sea_save_error = "海上存档写入校验失败，旧档保留。"
		return false
	var absolute := ProjectSettings.globalize_path(SEA_SAVE)
	var backup := ProjectSettings.globalize_path(SEA_BACKUP)
	var temp := ProjectSettings.globalize_path(SEA_TEMP)
	var pending := backup + ".pending"
	if FileAccess.file_exists(SEA_SAVE):
		if _read_sea_file(SEA_SAVE).is_empty():
			sea_save_error = "海上主档无效，原档与备份均保留；请先备份文件。"
			return false
		if FileAccess.file_exists(SEA_BACKUP + ".pending"):
			if not _read_sea_file(SEA_BACKUP + ".pending").is_empty():
				if FileAccess.file_exists(SEA_BACKUP) and DirAccess.remove_absolute(backup) != OK:
					sea_save_error = "海上旧备份清理失败，进度未提交。"
					return false
				if DirAccess.rename_absolute(pending, backup) != OK:
					sea_save_error = "海上备份轮换失败，进度未提交。"
					return false
			elif DirAccess.remove_absolute(pending) != OK:
				sea_save_error = "海上无效临时备份清理失败，进度未提交。"
				return false
		if DirAccess.rename_absolute(absolute, pending) != OK:
			sea_save_error = "海上存档备份失败，旧档保留。"
			return false
	if DirAccess.rename_absolute(temp, absolute) != OK:
		if FileAccess.file_exists(SEA_BACKUP + ".pending") and not FileAccess.file_exists(SEA_SAVE):
			DirAccess.rename_absolute(pending, absolute)
		sea_save_error = "海上存档置换失败，旧档或备份保留。"
		return false
	water_activity_state = state.duplicate(true)
	if FileAccess.file_exists(SEA_BACKUP + ".pending"):
		if FileAccess.file_exists(SEA_BACKUP) and DirAccess.remove_absolute(backup) != OK:
			sea_save_error = "海上进度已保存，旧备份整理失败；临时备份仍保留。"
		elif DirAccess.rename_absolute(pending, backup) != OK:
			sea_save_error = "海上进度已保存，临时备份仍保留。"
	return true

## 统一切换场景，避免 UI 模块直接依赖关卡实现。
func goto_scene(scene_name: String) -> void:
	if scene_name == "fudi":
		stage_pending = false
		UIManager.close_popup()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Fudi.tscn")
		return
	var paths := {"menu": "res://scenes/MainMenu.tscn", "city": "res://scenes/MainCity.tscn", "team": "res://scenes/TeamSelect.tscn", "battle": "res://scenes/Battle.tscn", "stages": "res://scenes/StageSelect.tscn", "outskirts": "res://scenes/Outskirts.tscn", "water_activity": "res://scenes/WaterActivity.tscn"}
	if paths.has(scene_name):
		if scene_name in ["city", "menu"]:
			stage_pending = false
		UIManager.close_popup()
		get_tree().call_deferred("change_scene_to_file", paths[scene_name])

func enter_region(region: String, arrival: Vector2 = Vector2.ZERO) -> void:
	if region == "city":
		city_spawn = arrival if arrival != Vector2.ZERO else Vector2(334, 558)
	goto_scene(region)

func select_stage(stage_id: String) -> void:
	if not stage_id.begins_with("stage_") or not stage_id.trim_prefix("stage_").is_valid_int():
		return
	var stage_number := int(stage_id.trim_prefix("stage_"))
	if stage_number < 1 or stage_number > int(DataManager.save_data["unlocked_stage"]) or DataManager.get_entry("stages", stage_id).is_empty():
		return
	current_stage = stage_id
	stage_pending = true
	stage_selected.emit(stage_id)
	goto_scene("team")

func finish_battle(won: bool) -> void:
	last_result = "胜利" if won else "失败"
	if won:
		var stage := DataManager.get_entry("stages", current_stage)
		DataManager.add_experience(int(stage.get("reward_exp", 0)))
		var stage_number := int(current_stage.trim_prefix("stage_"))
		DataManager.save_data["unlocked_stage"] = mini(DataManager.tables["stages"].size(), maxi(int(DataManager.save_data["unlocked_stage"]), stage_number + 1))
		DataManager.write_save()

## GM 跳关仍走正常编队入口；先验证真实关卡，再保存解锁进度。
func gm_jump_to_stage(stage_id: String) -> bool:
	if not stage_id.begins_with("stage_") or not stage_id.trim_prefix("stage_").is_valid_int():
		return false
	var stage_number := int(stage_id.trim_prefix("stage_"))
	if stage_number < 1 or DataManager.get_entry("stages", stage_id).is_empty():
		return false
	var previous := int(DataManager.save_data["unlocked_stage"])
	if stage_number > previous:
		DataManager.save_data["unlocked_stage"] = stage_number
		if not DataManager.write_save():
			DataManager.save_data["unlocked_stage"] = previous
			return false
	select_stage(stage_id)
	return true
