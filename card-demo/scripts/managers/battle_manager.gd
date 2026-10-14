extends Node
## 单机战斗状态机：行动与追打在每一段演出结束后才继续，杜绝瞬间扣血。
signal state_changed
signal action_logged(message: String, target: BattleUnit, damage: int)
signal action_started(actor: BattleUnit, target: BattleUnit, skill_id: String, combo: int, action_id: int)
signal action_impact(actor: BattleUnit, target: BattleUnit, skill_id: String, damage: int, combo: int, action_id: int)
signal animation_completed(action_id: int, phase: String)
signal turn_requested(unit: BattleUnit)
signal battle_finished(won: bool)
## 只在被动效果实际触发时发送，入场事件可由战斗场景延后到角色创建后显示。
signal passive_triggered(unit: BattleUnit, passive_id: String, effect: String, amount: int)
## 敌方状态在伤害演出结束后附加，视觉提示与真实附加时点保持一致。
signal status_applied(unit: BattleUnit, effect: String)
const UnitScript = preload("res://scripts/battle/battle_unit.gd")
var allies: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var queue: Array[BattleUnit] = []
var round_number := 0
var active_unit: BattleUnit
var selected_target: BattleUnit
var running := false
var busy := false
var chase_count := 0
var chase_used: Array[BattleUnit] = []
var rng := RandomNumberGenerator.new()
var stage: Dictionary = {}
## 演出超时只阻止画面永久卡住，伤害仍恰好结算一次。
const ANIMATION_TIMEOUT := 1.5
const CLEANSABLE_EFFECTS := ["stun", "air", "down", "damage_down"]
var last_cleansed: Array[String] = []
var action_serial := 0
var battle_serial := 0
var expected_action_id := -1
var expected_phase := ""
var acknowledged := false

func _ready() -> void:
	rng.randomize()
	animation_completed.connect(acknowledge_animation)

## 从存档九宫格索引实例化 5 名我方单位及 JSON 定义的敌方单位。
func start(stage_id: String) -> void:
	battle_serial += 1
	running = false
	expected_action_id = -1
	stage = DataManager.get_entry("stages", stage_id)
	last_cleansed.clear()
	allies.clear()
	enemies.clear()
	queue.clear()
	var team: Array = DataManager.save_data["team"]
	var formation: Array = DataManager.save_data.get("formation", [])
	if not DataManager.valid_team(team, formation):
		push_error("存档阵容无效：需要主角、四只灵伴和九宫格阵位")
		return
	for i in range(team.size()):
		var id := str(team[i])
		var cell_index: int = formation.find(id)
		if cell_index < 0 or formation.count(id) != 1:
			push_error("上阵角色阵位无效: " + id)
			allies.clear()
			return
		allies.append(UnitScript.new(id, "ally", i, cell_index, int(DataManager.save_data["levels"].get(id, 1))))
	var enemy_ids: Array = stage.get("enemies", [])
	var enemy_cells := [0, 3, 4, 8]
	for i in range(min(4, enemy_ids.size())):
		enemies.append(UnitScript.new(str(enemy_ids[i]), "enemy", i, enemy_cells[i], int(stage.get("enemy_level", 1))))
	if enemies.is_empty():
		push_error("关卡未配置敌人: " + stage_id)
		allies.clear()
		return
	allies[0].skills = [str(DataManager.save_data["hero_skill"])]
	round_number = 0
	busy = false
	active_unit = null
	selected_target = null
	running = true
	for unit in allies + enemies:
		trigger_passive(unit, "enter")
	begin_round()

## 每轮全体恢复能量，按先手降序排序；同速按主角/队伍顺序打破平局。
func begin_round() -> void:
	if not running:
		return
	round_number += 1
	if round_number > int(stage.get("max_rounds", 20)):
		finish(false)
		return
	queue.clear()
	for unit in allies + enemies:
		if unit.alive():
			unit.energy = mini(int((DataManager.tables.get("rules", {}) as Dictionary).get("max_energy", 100)), unit.energy + int(stage.get("energy_regen", 20)))
			trigger_passive(unit, "round_start")
			queue.append(unit)
	queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.initiative == b.initiative:
			return (a.slot + (0 if a.side == "ally" else 5)) < (b.slot + (0 if b.side == "ally" else 5))
		return a.initiative > b.initiative
	)
	state_changed.emit()
	call_deferred("advance")

## 按队列取行动者，我方主角与宠物均等待玩家选择；仅敌方自动决策。
func advance() -> void:
	if not running or busy:
		return
	if check_end():
		return
	while not queue.is_empty():
		active_unit = queue.pop_front()
		selected_target = null
		if not active_unit.alive():
			continue
		state_changed.emit()
		if active_unit.has_effect("stun"):
			action_logged.emit(active_unit.name + "眩晕，跳过行动", active_unit, 0)
			active_unit.effects.erase("stun")
			call_deferred("advance")
			return
		if active_unit.side == "ally":
			turn_requested.emit(active_unit)
			return
		var skill_id := "basic"
		if not active_unit.skills.is_empty():
			var option: String = str(active_unit.skills[0])
			if can_cast(active_unit, option):
				skill_id = option
		execute_action(active_unit, skill_id)
		return
	active_unit = null
	for unit in allies + enemies:
		unit.tick()
	begin_round()

func can_cast(unit: BattleUnit, skill_id: String) -> bool:
	if unit == null:
		return false
	var skill := DataManager.get_entry("skills", skill_id)
	if not unit.alive() or not unit.skills.has(skill_id) or skill.get("type", "") != "ultimate" or unit.energy < int(skill.get("cost", 0)) or int(unit.cooldowns.get(skill_id, 0)) != 0:
		return false
	if str(skill.get("apply", "")) == "cleanse":
		return not valid_targets(unit, skill_id).is_empty()
	return true

## 合法目标清单是 UI 高亮与真正结算的唯一来源；cell % 3 为前/中/后列。默认优先最前存活列，特例可自由选敌方。
func valid_targets(actor: BattleUnit, skill_id: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	if actor == null or not actor.alive():
		return result
	var skill: Dictionary = DataManager.get_entry("skills", skill_id)
	var target_type: String = str(skill.get("target", "enemy"))
	if target_type == "self":
		result.append(actor)
	elif target_type == "ally":
		var friends: Array[BattleUnit] = allies if actor.side == "ally" else enemies
		for friend: BattleUnit in friends:
			if friend.alive() and (str(skill.get("apply", "")) != "cleanse" or has_cleansable_effect(friend)):
				result.append(friend)
	elif target_type == "enemy":
		var opponents: Array[BattleUnit] = enemies if actor.side == "ally" else allies
		var nearest_column: int = 3
		for opponent: BattleUnit in opponents:
			if opponent.alive():
				nearest_column = mini(nearest_column, opponent.cell % 3)
		for opponent: BattleUnit in opponents:
			if opponent.alive() and (bool(skill.get("free_target", false)) or opponent.cell % 3 == nearest_column):
				result.append(opponent)
	return result

func has_cleansable_effect(unit: BattleUnit) -> bool:
	for effect: String in CLEANSABLE_EFFECTS:
		if unit.has_effect(effect):
			return true
	return false

func select_target(unit: BattleUnit, skill_id: String) -> bool:
	if not running or busy or active_unit == null or active_unit.side != "ally" or not valid_targets(active_unit, skill_id).has(unit):
		return false
	selected_target = unit
	state_changed.emit()
	return true

func player_action(skill_id: String, target: BattleUnit = null) -> void:
	if not running or busy or active_unit == null or active_unit.side != "ally" or not allies.has(active_unit) or not active_unit.alive() or active_unit.has_effect("stun"):
		return
	if skill_id != "basic" and not can_cast(active_unit, skill_id):
		return
	var choice: BattleUnit = target if target != null else selected_target
	if not valid_targets(active_unit, skill_id).has(choice):
		return
	execute_action(active_unit, skill_id, choice)

## 每段命中依次等待场景播放，随后扣血/追打，再释放行动锁。
func execute_action(actor: BattleUnit, skill_id: String, requested_target: BattleUnit = null) -> void:
	if busy or not running or actor == null or actor != active_unit or not actor.alive() or actor.has_effect("stun"):
		return
	if skill_id != "basic" and not can_cast(actor, skill_id):
		return
	var skill: Dictionary = DataManager.get_entry("skills", skill_id)
	if skill.is_empty():
		return
	var current_battle: int = battle_serial
	var target: BattleUnit = actor
	var target_type: String = str(skill.get("target", "enemy"))
	if target_type != "self" and target_type != "ally" and target_type != "enemy":
		push_error("未知技能目标类型: " + target_type)
		return
	if actor.side == "ally" and requested_target != null:
		if not valid_targets(actor, skill_id).has(requested_target):
			return
		target = requested_target
	elif target_type == "ally":
		var friends: Array[BattleUnit] = allies if actor.side == "ally" else enemies
		target = pick_afflicted_ally(friends) if str(skill.get("apply", "")) == "cleanse" else pick_wounded_ally(friends)
	elif target_type == "enemy":
		var opponents: Array[BattleUnit] = enemies if actor.side == "ally" else allies
		target = pick_target(opponents, skill_id)
	if target == null:
		check_end()
		if running:
			active_unit = null
			call_deferred("advance")
		return
	busy = true
	selected_target = null
	if skill_id != "basic":
		actor.energy -= int(skill.get("cost", 0))
		actor.cooldowns[skill_id] = int(skill.get("cooldown", 0)) + 1
	chase_count = 0
	chase_used.clear()
	await animate_and_hit(actor, target, skill_id, 0)
	if not running or current_battle != battle_serial:
		return
	if actor.alive() and target.alive() and str(skill.get("target", "enemy")) == "enemy":
		var applied := str(skill.get("apply", ""))
		apply_status(target, applied, skill)
		if applied == "air" or applied == "down":
			await chase(actor.side, target, applied, current_battle)
	if not running or current_battle != battle_serial:
		return
	check_end()
	if not running:
		return
	state_changed.emit()
	busy = false
	call_deferred("advance")

## 回执带动作序号与阶段；超时继续，避免画面故障锁死战斗。
func acknowledge_animation(action_id: int, phase: String) -> void:
	if running and action_id == expected_action_id and phase == expected_phase:
		acknowledged = true

func wait_for_animation(action_id: int, phase: String, current_battle: int) -> void:
	var elapsed := 0.0
	while not acknowledged and elapsed < ANIMATION_TIMEOUT and running and current_battle == battle_serial:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not acknowledged and running and current_battle == battle_serial:
		push_warning("战斗演出回执超时: %s #%d" % [phase, action_id])
	if current_battle == battle_serial and expected_action_id == action_id and expected_phase == phase:
		expected_action_id = -1
		expected_phase = ""

## 出手演出在命中前完成；命中时才计算伤害，命中反馈结束后进入下一击。
func animate_and_hit(actor: BattleUnit, target: BattleUnit, skill_id: String, combo: int) -> void:
	var skill := DataManager.get_entry("skills", skill_id)
	var current_battle: int = battle_serial
	action_serial += 1
	var action_id: int = action_serial
	await get_tree().process_frame
	if not running or current_battle != battle_serial:
		return
	# 先设置等待阶段，避免场景在信号监听器中立即回执时发生丢失。
	expected_action_id = action_id
	expected_phase = "windup"
	acknowledged = false
	action_started.emit(actor, target, skill_id, combo, action_id)
	await wait_for_animation(action_id, "windup", current_battle)
	if not running or current_battle != battle_serial:
		return
	# 前摇期间出手者被其它事件击败时，不再结算这次伤害。
	if not actor.alive():
		return
	var damage := 0
	last_cleansed.clear()
	if str(skill.get("target", "enemy")) == "self":
		apply_status(actor, str(skill.get("apply", "")), skill)
	elif str(skill.get("target", "enemy")) == "ally":
		var hp_before: int = target.hp
		apply_status(target, str(skill.get("apply", "")), skill)
		damage = hp_before - target.hp # 负数代表实际治疗量，避免溢出治疗被误报。
	elif target.alive():
		damage = deal_damage(actor, target, skill)
	expected_action_id = action_id
	expected_phase = "impact"
	acknowledged = false
	action_impact.emit(actor, target, skill_id, damage, combo, action_id)
	action_logged.emit(actor.name + (" 追打 " if combo > 0 else " 使用 ") + str(skill.get("name", "")) + " → " + target.name, target, damage)
	state_changed.emit()
	await wait_for_animation(action_id, "impact", current_battle)

## 支援技能选择生命比例最低的存活友方；同值按阵容顺序确定，避免无效治疗。
func pick_wounded_ally(team: Array[BattleUnit]) -> BattleUnit:
	var chosen: BattleUnit = null
	for unit in team:
		if not unit.alive():
			continue
		if chosen == null or unit.hp * chosen.max_hp < chosen.hp * unit.max_hp:
			chosen = unit
	return chosen

## 净化优先清除有效负面状态最多的存活友方，同数按阵容顺序；不将增益或护盾当作目标。
func pick_afflicted_ally(team: Array[BattleUnit]) -> BattleUnit:
	var chosen: BattleUnit = null
	var most := 0
	for unit in team:
		if not unit.alive():
			continue
		var count := 0
		for effect: String in CLEANSABLE_EFFECTS:
			if unit.has_effect(effect):
				count += 1
		if count > most:
			most = count
			chosen = unit
	return chosen

## 敌方自动行动在同一合法目标池内随机抽取，不再使用跨排权重。
func pick_target(team: Array[BattleUnit], skill_id: String = "basic") -> BattleUnit:
	var actor: BattleUnit = active_unit
	var pool: Array[BattleUnit] = []
	if actor == null:
		var nearest_column: int = 3
		for unit: BattleUnit in team:
			if unit.alive():
				nearest_column = mini(nearest_column, unit.cell % 3)
		for unit: BattleUnit in team:
			if unit.alive() and unit.cell % 3 == nearest_column:
				pool.append(unit)
	else:
		var options: Array[BattleUnit] = valid_targets(actor, skill_id)
		for unit: BattleUnit in team:
			if options.has(unit):
				pool.append(unit)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]

## 防御减伤、暴击、增伤/减伤及护盾吸收。
func deal_damage(actor: BattleUnit, target: BattleUnit, skill: Dictionary) -> int:
	var multiplier := 1.0
	if actor.has_effect("damage_up"):
		multiplier += float(actor.effects["damage_up"]["value"])
	if actor.has_effect("damage_down"):
		multiplier -= float(actor.effects["damage_down"]["value"])
	var rules: Dictionary = DataManager.tables.get("rules", {})
	var raw: int = maxi(1, roundi(float(actor.attack) * float(skill.get("power", 1.0)) * maxf(0.1, multiplier) - float(target.defense) * float(rules.get("defense_factor", 0.5))))
	raw = maxi(1, roundi(float(raw) * element_multiplier(actor, target, skill)))
	if rng.randf() < actor.crit:
		raw = roundi(raw * float(rules.get("crit_multiplier", 1.5)))
	var absorbed: int = mini(target.shields, raw)
	target.shields -= absorbed
	var actual: int = raw - absorbed
	target.hp = maxi(0, target.hp - actual)
	trigger_passive(target, "hit")
	return actual

## 当前只按单属性生效；数组保留未来双属性容量，扩展时须另定聚合规则。
func element_multiplier(actor: BattleUnit, target: BattleUnit, skill: Dictionary) -> float:
	var source: String = str(skill.get("element", "owner"))
	var attack_element: String = actor.elements[0] if source == "owner" and not actor.elements.is_empty() else source
	if attack_element == "" or attack_element == "none" or target.elements.is_empty():
		return 1.0
	var rules: Dictionary = DataManager.tables.get("rules", {})
	var elements: Dictionary = rules.get("elements", {})
	var attack_rule: Dictionary = elements.get(attack_element, {})
	var defender_element: String = target.elements[0]
	var defense_rule: Dictionary = elements.get(defender_element, {})
	if (attack_rule.get("overcomes", []) as Array).has(defender_element):
		return float(rules.get("element_advantage", 1.0))
	if (defense_rule.get("overcomes", []) as Array).has(attack_element):
		return float(rules.get("element_disadvantage", 1.0))
	return 1.0

func apply_status(unit: BattleUnit, effect: String, skill: Dictionary) -> void:
	if effect == "" or not unit.alive():
		return
	match effect:
		"shield": unit.shields += maxi(0, int(skill.get("value", 0)))
		"heal": unit.hp = mini(unit.max_hp, unit.hp + maxi(0, int(skill.get("value", 0))))
		"cleanse":
			last_cleansed.clear()
			for key: String in CLEANSABLE_EFFECTS:
				if unit.has_effect(key):
					unit.effects.erase(key)
					last_cleansed.append(key)
		_: unit.add_effect(effect, int(skill.get("duration", 1)), float(skill.get("value", 0)))
	state_changed.emit()
	if effect != "" and effect != "heal" and effect != "shield" and effect != "cleanse" and unit.has_effect(effect):
		status_applied.emit(unit, effect)

## 追打串行播完每一击；本连击同一追打者只可出手一次，最多三击。
func chase(side: String, target: BattleUnit, status: String, current_battle: int = -1) -> void:
	if current_battle < 0:
		current_battle = battle_serial
	while running and current_battle == battle_serial and target.alive() and chase_count < int(stage.get("chase_limit", 3)):
		var found := false
		var team: Array[BattleUnit] = allies if side == "ally" else enemies
		for unit in team:
			if not unit.alive() or unit.has_effect("stun") or chase_used.has(unit) or unit.chase == "":
				continue
			var skill := DataManager.get_entry("skills", unit.chase)
			if str(skill.get("trigger", "")) != status:
				continue
			chase_used.append(unit)
			chase_count += 1
			await animate_and_hit(unit, target, unit.chase, chase_count)
			if not running or current_battle != battle_serial:
				return
			status = str(skill.get("apply", ""))
			if target.alive():
				apply_status(target, status, skill)
			found = true
			break
		if not found:
			break

func trigger_passive(unit: BattleUnit, timing: String) -> void:
	if not unit.alive():
		return
	for passive_id: String in unit.passives:
		var passive: Dictionary = DataManager.get_entry("passives", passive_id)
		if str(passive.get("trigger", "")) != timing:
			continue
		var effect: String = str(passive.get("effect", ""))
		var amount: int = 0
		match effect:
			"heal":
				var before: int = unit.hp
				unit.hp = mini(unit.max_hp, unit.hp + maxi(0, int(passive.get("value", 0))))
				amount = unit.hp - before
			"shield":
				amount = maxi(0, int(passive.get("value", 0)))
				unit.shields += amount
			"damage_up", "damage_down":
				unit.add_effect(effect, int(passive.get("duration", 1)), float(passive.get("value", 0)))
				amount = roundi(float(passive.get("value", 0)) * 100.0)
			_: continue
		if amount > 0:
			passive_triggered.emit(unit, passive_id, effect, amount)

func check_end() -> bool:
	var ally_alive := false
	var enemy_alive := false
	for unit in allies:
		if unit.alive(): ally_alive = true
	for unit in enemies:
		if unit.alive(): enemy_alive = true
	if not ally_alive or not enemy_alive:
		finish(ally_alive)
		return true
	return false

func abort() -> void:
	if not running:
		return
	running = false
	busy = false
	battle_serial += 1
	queue.clear()
	active_unit = null
	selected_target = null
	expected_action_id = -1
	expected_phase = ""
	acknowledged = false
	chase_count = 0
	chase_used.clear()
	state_changed.emit()

func finish(won: bool) -> void:
	if not running:
		return
	running = false
	busy = false
	expected_action_id = -1
	GameManager.finish_battle(won)
	battle_finished.emit(won)
