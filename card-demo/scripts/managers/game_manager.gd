extends Node
## 场景路由与待进入关卡状态。
signal stage_selected(stage_id: String)
var current_stage := "stage_1"
var stage_pending := false
var city_spawn := Vector2(334, 558)
var last_result := ""
const DiveCatalog = preload("res://scripts/scenes/underwater_catalog.gd")
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

func _migrate_sea_state(legacy: Dictionary) -> Dictionary:
	var state := legacy.duplicate(true)
	var slots: Array = ["core"]
	for i in range(int(state.collectors)):
		slots.append("collector")
	while slots.size() < int(state.raft_tiles):
		slots.append("empty")
	for building in ["workshop", "tide"]:
		if (building == "workshop" and state.workshop_built) or (building == "tide" and state.tide_table):
			var empty_slot := slots.find("empty")
			if empty_slot == -1:
				slots.append(building)
			else:
				slots[empty_slot] = building
	state.raft_tiles = slots.size()
	state.building_slots = slots
	state.core_level = 3 if state.tide_table or (state.blueprint and int(state.orders_completed) >= 2) else (2 if state.workshop_built or int(state.orders_completed) >= 1 else 1)
	state.guide_seen_pickup = int(state.wood) > 0 or int(state.scrap) > 0 or int(state.raft_tiles) > 1 or int(state.collectors) > 0 or int(state.orders_completed) > 0
	state.guide_seen_claim = int(state.water) > 0 or int(state.fiber) > 0 or int(state.rope) > 0 or int(state.orders_completed) > 0 or state.automated_collecting or state.workshop_built or state.resident
	return state

func _read_sea_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.get("state") is Dictionary:
		return {}
	var raw_version: Variant = parsed.get("version")
	if not (raw_version is int or raw_version is float) or raw_version not in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		return {}
	var state: Dictionary = parsed["state"]
	var version: int = int(raw_version)
	var has_equipment := state.has("equipment") or state.has("core_reward_claimed") or state.has("dive_workshop_unlocked") or state.has("dive_workshop_built")
	if version < 6 or (version == 6 and not has_equipment):
		state.equipment = DiveCatalog.equipment()
		state.core_reward_claimed = false
		state.dive_workshop_unlocked = false
		state.dive_workshop_built = false
	elif not DiveCatalog.valid_equipment(state):
		return {}
	if version < 6:
		state.resources = DiveCatalog.resources()
		state.node_states = DiveCatalog.defaults()
		state.net_expansion = 0
	elif not DiveCatalog.valid(state):
		return {}
	for key in ["dive_shoal", "dive_sonar", "dive_core", "dive_archived"]:
		if version < 5:
			state[key] = false
		elif not state.get(key) is bool:
			return {}
	if (state.dive_sonar and not state.dive_shoal) or (state.dive_core and not state.dive_sonar) or (state.dive_archived and not state.dive_core):
		return {}
	for key in ["wood", "scrap", "water", "fiber", "rope", "raft_tiles", "collectors", "orders_completed", "pending_water", "pending_fiber"]:
		if not (state.get(key) is float or state.get(key) is int) or state[key] < 0 or state[key] > (1000002 if version >= 2 and key == "raft_tiles" else 1000000) or state[key] != floor(state[key]):
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
	if version == 1:
		state = _migrate_sea_state(state)
	if not (state.get("core_level") is float or state.get("core_level") is int) or state.core_level != floor(state.core_level) or state.core_level < 1 or state.core_level > 3:
		return {}
	if not state.get("guide_seen_pickup") is bool or not state.get("guide_seen_claim") is bool or not state.get("building_slots") is Array:
		return {}
	var slots: Array = state.building_slots
	if slots.size() != int(state.raft_tiles) or slots[0] != "core":
		return {}
	var counts := {"core": 0, "empty": 0, "collector": 0, "workshop": 0, "tide": 0, "filter": 0}
	for slot in slots:
		if not slot is String or not counts.has(slot):
			return {}
		counts[slot] += 1
	if counts.core != 1 or counts.collector != int(state.collectors) or counts.workshop != int(state.workshop_built) or counts.tide != int(state.tide_table):
		return {}
	if (state.workshop_built and state.core_level < 2) or (state.tide_table and state.core_level < 3):
		return {}
	if version < 3:
		if counts.filter != 0:
			return {}
		state.at_salt = false
		state.salt = 0
		state.filter_blueprint = false
		state.filter_built = false
		state.salt_nodes = []
		state.salt_elapsed = 0.0
		state.at_wreck = false
		state.wreck_scrap = 0
		state.wreck_nodes = []
		state.wreck_elapsed = 0.0
		state.hazard_elapsed = 0.0
		state.wreck_hp = 3
		state.sail_loadout = ""
		return state
	for key in ["at_salt", "filter_blueprint", "filter_built"]:
		if not state.get(key) is bool:
			return {}
	if not (state.get("salt") is int or state.get("salt") is float) or state.salt < 0 or state.salt > 1000000 or state.salt != floor(state.salt):
		return {}
	if not (state.get("salt_elapsed") is int or state.get("salt_elapsed") is float) or state.salt_elapsed < 0 or state.salt_elapsed > 100:
		return {}
	if not state.get("salt_nodes") is Array or state.salt_nodes.size() > 3:
		return {}
	for point in state.salt_nodes:
		if not point is Array or point.size() != 2 or not (point[0] is int or point[0] is float) or not (point[1] is int or point[1] is float):
			return {}
		if absf(float(point[0])) > 10000 or absf(float(point[1])) > 10000:
			return {}
	if counts.filter != int(state.filter_built) or (state.filter_built and (not state.filter_blueprint or state.core_level < 3)) or (state.at_salt and not state.tide_table):
		return {}
	if version < 4:
		state.at_wreck = false
		state.wreck_scrap = 0
		state.wreck_nodes = []
		state.wreck_elapsed = 0.0
		state.hazard_elapsed = 0.0
		state.wreck_hp = 3
		state.sail_loadout = ""
		return state
	if not state.get("at_wreck") is bool or not state.get("sail_loadout") is String or state.sail_loadout not in ["", "hull", "weapon"] or (state.at_wreck and state.at_salt):
		return {}
	for key in ["wreck_scrap", "wreck_hp"]:
		if not (state.get(key) is int or state.get(key) is float) or state[key] != floor(state[key]) or state[key] < 0 or state[key] > 1000000:
			return {}
	if state.wreck_hp > 3:
		return {}
	for key in ["wreck_elapsed", "hazard_elapsed"]:
		if not (state.get(key) is int or state.get(key) is float) or state[key] < 0 or state[key] > 100:
			return {}
	if not state.get("wreck_nodes") is Array or state.wreck_nodes.size() > 3:
		return {}
	for point in state.wreck_nodes:
		if not point is Array or point.size() != 2 or not (point[0] is int or point[0] is float) or not (point[1] is int or point[1] is float) or absf(float(point[0])) > 10000 or absf(float(point[1])) > 10000:
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
	var text := JSON.stringify({"version": 6, "state": state}, "", true, true)
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
