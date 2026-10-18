extends Node
## JSON 配置与 user:// 单机存档入口。
signal save_changed

const DATA_PATHS := {"units": "res://data/units.json", "skills": "res://data/skills.json", "stages": "res://data/stages.json", "passives": "res://data/passives.json", "rules": "res://data/rules.json"}
const SAVE_PATH := "user://spirit_save.json"
const DEFAULT_TEAM := ["hero", "sprout", "ember", "pebble", "mist"]
var tables: Dictionary = {}
var save_data: Dictionary = {}

func _ready() -> void:
	for key in DATA_PATHS:
		var file := FileAccess.open(DATA_PATHS[key], FileAccess.READ)
		if file == null:
			push_error("配置缺失: " + DATA_PATHS[key])
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			tables[key] = parsed
		else:
			push_error("配置格式错误: " + DATA_PATHS[key])
	load_save()

## 返回配置拷贝，避免战斗运行态污染原始表。
func get_entry(table: String, key: String) -> Dictionary:
	var value: Variant = (tables.get(table, {}) as Dictionary).get(key, {})
	return value.duplicate(true) if value is Dictionary else {}

func load_save() -> void:
	save_data = {"team": ["hero", "sprout", "ember", "pebble", "mist"], "positions": ["middle", "front", "middle", "front", "back"], "levels": {"hero": 1, "sprout": 1, "ember": 1, "pebble": 1, "mist": 1}, "exp": {"hero": 0, "sprout": 0, "ember": 0, "pebble": 0, "mist": 0}, "unlocked_stage": 1, "hero_skill": "hero_strike", "formation": ["sprout", "", "mist", "pebble", "hero", "", "", "ember", ""]}
	var parsed: Variant = {}
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in save_data:
			if parsed.has(key):
				save_data[key] = parsed[key]
	if not save_data["levels"] is Dictionary:
		save_data["levels"] = {}
	if not save_data["exp"] is Dictionary:
		save_data["exp"] = {}
	if not (save_data["team"] is Array and save_data["positions"] is Array and save_data["formation"] is Array):
		save_data["team"] = DEFAULT_TEAM.duplicate()
		save_data["positions"] = ["middle", "front", "middle", "front", "back"]
		save_data["formation"] = ["sprout", "", "mist", "pebble", "hero", "", "", "ember", ""]
	# 兼容四人旧档：从配置候选中补一位，不覆盖已有等级与通关记录。
	if (save_data["team"] as Array).size() == 4:
		for candidate: String in available_pets():
			if not (save_data["team"] as Array).has(candidate):
				(save_data["team"] as Array).append(candidate)
				(save_data["positions"] as Array).append("back")
				break
	# 旧档将已有可选宠物视为已拥有；新档可独立维护拥有列表（空数组代表确实没有宠物）。
	if parsed is Dictionary and parsed.get("owned_pets") is Array:
		save_data["owned_pets"] = parsed["owned_pets"].duplicate()
	else:
		save_data["owned_pets"] = available_pets()
	# 新宠通过单位配置中的 playable 标记进入候选库；已有存档保持原上阵阵容。
	for id: String in available_pets():
		if not (save_data["levels"] as Dictionary).has(id):
			(save_data["levels"] as Dictionary)[id] = 1
		if not (save_data["exp"] as Dictionary).has(id):
			(save_data["exp"] as Dictionary)[id] = 0
	# 旧版只保存前中后排，此处用空格补齐九宫格，同时保留已培养角色。
	var has_formation: bool = parsed is Dictionary and (parsed as Dictionary).has("formation")
	if not has_formation:
		var cells := ["", "", "", "", "", "", "", "", ""]
		var columns := {"front": 0, "middle": 1, "back": 2}
		for i in range((save_data["team"] as Array).size()):
			var position: String = str((save_data["positions"] as Array)[i]) if i < (save_data["positions"] as Array).size() else "middle"
			var column: int = int(columns.get(position, 1))
			for row in range(3):
				var index := row * 3 + column
				if cells[index] == "":
					cells[index] = str((save_data["team"] as Array)[i])
					break
		# 旧档某一列满员时，从任何空位补齐，防止升级后阵容无法开战。
			var unit_id: String = str((save_data["team"] as Array)[i])
			if not cells.has(unit_id):
				var free_cell: int = cells.find("")
				if free_cell >= 0:
					cells[free_cell] = unit_id
		save_data["formation"] = cells
	if not valid_team(save_data["team"], save_data["formation"]):
		push_warning("存档编队不合法，已还原默认上阵队伍；等级和通关进度保留")
		save_data["team"] = DEFAULT_TEAM.duplicate()
		save_data["formation"] = ["sprout", "", "mist", "pebble", "hero", "", "", "ember", ""]

## 可参战宠物来自 JSON，不依赖写死的角色名单或排序。
func available_pets() -> Array[String]:
	var result: Array[String] = []
	var units: Dictionary = tables.get("units", {})
	for key: Variant in units:
		var id: String = str(key)
		var config: Dictionary = units[id]
		if bool(config.get("playable", false)) and id != "hero":
			result.append(id)
	return result

## 背包只展示存档中实际拥有且当前有有效模板的宠物，保留存档原顺序。
func owned_pets() -> Array[String]:
	var result: Array[String] = []
	var allowed: Array[String] = available_pets()
	var owned: Variant = save_data.get("owned_pets", [])
	if owned is Array:
		for raw_id: Variant in owned:
			var id: String = str(raw_id)
			if allowed.has(id) and not result.has(id):
				result.append(id)
	return result

## 保证主角固定＋四只不同宠物且九宫格恰好有五名成员。
func valid_team(team: Array, formation: Array) -> bool:
	if team.size() != 5 or formation.size() != 9 or str(team[0]) != "hero":
		return false
	var allowed: Array[String] = available_pets()
	for index in range(team.size()):
		var id: String = str(team[index])
		if (index > 0 and not allowed.has(id)) or team.count(id) != 1 or formation.count(id) != 1:
			return false
	for occupant: Variant in formation:
		if str(occupant) != "" and not team.has(str(occupant)):
			return false
	return true

## 保存单机进度、阵容和成长；断电保护可在后续版本增加临时文件轮换。
func write_save() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("存档写入失败")
		return false
	file.store_string(JSON.stringify(save_data, "  "))
	file.close()
	save_changed.emit()
	return true

## GM 只提升已拥有宠物，保留当前经验、主角、编队与其他存档字段。
## 返回实际提升数量；无效请求或保存失败返回 -1。
func gm_raise_pet_levels(pet_ids: Array[String], target_level: int) -> int:
	if pet_ids.is_empty() or target_level < 1 or target_level > 999:
		return -1
	var owned: Array[String] = owned_pets()
	for id: String in pet_ids:
		if not owned.has(id):
			return -1
	var previous: Dictionary = (save_data["levels"] as Dictionary).duplicate(true)
	var changed := 0
	for id: String in pet_ids:
		if int(save_data["levels"].get(id, 1)) < target_level:
			save_data["levels"][id] = target_level
			changed += 1
	if changed > 0 and not write_save():
		save_data["levels"] = previous
		return -1
	return changed

func add_experience(amount: int) -> void:
	for id in save_data["team"]:
		var exp: int = int(save_data["exp"].get(id, 0)) + amount
		var level: int = int(save_data["levels"].get(id, 1))
		while exp >= level * int((tables.get("rules", {}) as Dictionary).get("base_exp_per_level", 100)):
			exp -= level * int((tables.get("rules", {}) as Dictionary).get("base_exp_per_level", 100))
			level += 1
		save_data["exp"][id] = exp
		save_data["levels"][id] = level
	write_save()
