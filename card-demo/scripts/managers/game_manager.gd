extends Node
## 场景路由与待进入关卡状态。
signal stage_selected(stage_id: String)
var current_stage := "stage_1"
var stage_pending := false
var city_spawn := Vector2(334, 558)
var last_result := ""

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
