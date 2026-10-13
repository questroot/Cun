class_name BattleUnit
extends RefCounted
## 战斗单位运行态，不写回 JSON 配置。
var id: String
var name: String
var side: String
var slot: int
var row: String
var cell: int
var max_hp: int
var hp: int
var attack: int
var defense: int
var initiative: int
var crit: float
var energy := 0
var shields := 0
var skills: Array = []
var chase := ""
var passives: Array = []
var elements: Array[String] = []
var color: Color
var effects: Dictionary = {}
var cooldowns: Dictionary = {}

func _init(unit_id: String, team_side: String, team_slot: int, cell_index: int, level: int = 1) -> void:
	id = unit_id
	side = team_side
	slot = team_slot
	cell = cell_index
	row = ["front", "middle", "back"][cell_index % 3]
	var data_manager: Node = (Engine.get_main_loop() as SceneTree).root.get_node("DataManager")
	var data: Dictionary = data_manager.get_entry("units", id)
	var rules: Dictionary = data_manager.tables.get("rules", {})
	var growth: Dictionary = rules.get("level_growth", {})
	energy = int(rules.get("initial_energy", 20))
	name = str(data.get("name", id))
	max_hp = int(data.get("hp", 100)) + (level - 1) * int(growth.get("hp", 20))
	hp = max_hp
	attack = int(data.get("attack", 10)) + (level - 1) * int(growth.get("attack", 4))
	defense = int(data.get("defense", 5)) + (level - 1) * int(growth.get("defense", 2))
	initiative = int(data.get("initiative", 10)) + (level - 1) * int(growth.get("initiative", 1))
	crit = float(data.get("crit", 0.05))
	color = Color(str(data.get("color", "#ffffff")))
	for element: Variant in data.get("elements", []):
		elements.append(str(element))
	skills = data.get("skills", []).duplicate()
	passives = data.get("passives", []).duplicate()
	chase = str(data.get("chase", ""))

func alive() -> bool:
	return hp > 0

func has_effect(key: String) -> bool:
	return effects.has(key) and int(effects[key].get("turns", 0)) > 0

func add_effect(key: String, turns: int, value: float = 0.0) -> void:
	effects[key] = {"turns": turns, "value": value}

## 回合末衰减状态与冷却，保证新释放奥义需经历完整的下一个回合。
func tick() -> void:
	for key in effects.keys():
		# 眩晕按下一次行动消费；目标本轮已行动时也不能提前过期。
		if key == "stun":
			continue
		effects[key]["turns"] = int(effects[key]["turns"]) - 1
		if int(effects[key]["turns"]) <= 0:
			effects.erase(key)
	for key in cooldowns.keys():
		cooldowns[key] = maxi(0, int(cooldowns[key]) - 1)
