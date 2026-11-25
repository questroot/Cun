extends Node
## A data-only expedition snapshot. Spirit and sea saves are never read or written.
const PATH := "user://fudi_expedition_v1.json"
const VERSION := 3
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const Gear = preload("res://scripts/scenes/equipment_catalog.gd")
const Ecology = preload("res://scripts/scenes/weather_ecology.gd")
const BossCatalog = preload("res://scripts/scenes/boss_catalog.gd")
const ChestRules = preload("res://scripts/scenes/chest_catalog.gd")
const Shop = preload("res://scripts/scenes/npc_shop_catalog.gd")
const Buildings = preload("res://scripts/scenes/building_catalog.gd")
var game
var enabled := true
var ready_to_save := false
var blocked := false
var status := ""
var save_stage := ""
var elapsed := 0.0
var queued := false
var old_auto_quit := true
var notice: Label
var notice_left := 0.0

func _ready() -> void:
	game = get_parent()
	process_priority = 100
	enabled = bool(ProjectSettings.get_setting("fudi/persistence_enabled", true))
	call_deferred("initialize")

func initialize() -> void:
	if not enabled: return
	notice = Label.new()
	notice.position = Vector2(28, 650)
	notice.add_theme_font_size_override("font_size", 14)
	game.add_child(notice)
	old_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	var fresh: bool = game.get_node("/root/GameManager").get_meta("fudi_new_expedition", false)
	if fresh: game.get_node("/root/GameManager").remove_meta("fudi_new_expedition")
	ready_to_save = true
	if fresh:
		status = "新一轮探索已开始"
	elif FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".bak"):
		var loaded := read_save()
		if loaded.is_empty():
			blocked = true
			status = "存档损坏或版本不兼容，原文件已保留。可在菜单确认重新开始。"
			show_notice(true)
			game.menu_info.text = status
			game.menu.show()
			return
		apply(loaded)
		show_notice(false)
		return
	save_now()

func _exit_tree() -> void:
	if enabled and ready_to_save:
		get_tree().auto_accept_quit = old_auto_quit

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled and ready_to_save:
		game.leave_expedition("quit")

func _process(delta: float) -> void:
	if notice != null and notice_left > 0:
		notice_left = maxf(0, notice_left - delta)
		notice.visible = notice_left > 0
	if not enabled or not ready_to_save or blocked or not game.is_processing() or game._paused() or game.finished: return
	elapsed += delta
	if elapsed >= 30.0: save_now()

func request_save() -> void:
	if not enabled or not ready_to_save or queued or blocked: return
	queued = true
	call_deferred("_save_queued")

func _save_queued() -> void:
	queued = false
	save_now()

func save_now() -> bool:
	if not enabled: return true
	if not ready_to_save or blocked: return false
	var error := write_snapshot(capture())
	elapsed = 0.0
	status = "已保存 · " + Time.get_time_string_from_system()
	if error != OK:
		status = "保存失败（%s，错误 %d），本次进度仍在游戏中。" % [save_stage, error]
		push_warning("Fudi save failed: %s (%s, %d)" % [save_stage, error_string(error), error])
	show_notice(error != OK)
	if game.menu.visible: game.menu_info.text = status
	return error == OK

func show_notice(failed: bool) -> void:
	if notice == null: return
	notice.text = status
	notice.add_theme_color_override("font_color", Color("#ffc09b") if failed else Color("#b9d3c0"))
	notice.visible = true
	notice_left = 0.0 if failed else 3.0

func _actor(actor: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["position", "home", "hp", "max_hp", "cooldown", "paid", "equipment_paid", "skill_index", "behavior"]:
		if actor.has(key): result[key] = actor[key]
	return result

func capture() -> Dictionary:
	var regions: Dictionary = {}
	var weather = game.get_node("Weather")
	var chests = game.get_node("Chests")
	for id: String in Maps.IDS:
		var state: Dictionary = game.states[id]
		var enemies: Array = []
		for enemy: Dictionary in state.enemies: enemies.append(_actor(enemy))
		var boxes: Array = []
		for chest: Dictionary in chests.regions[id]:
			var box := {"position": chest.position, "mutated": chest.mutated, "state": chest.state, "rewarded": chest.rewarded, "mobs": [], "boss": {}}
			for mob: Dictionary in chest.mobs: box.mobs.append(_actor(mob))
			if not chest.boss.is_empty(): box.boss = _actor(chest.boss)
			boxes.append(box)
		regions[id] = {"foot": game.player_foot if id == game.region else state.foot, "visited": state.visited.duplicate(), "rested": state.rested, "pickups": state.pickups.duplicate(true), "enemies": enemies, "plots": weather.plots[id].duplicate(true), "chests": boxes}
	var bosses: Dictionary = {}
	for id: String in game.get_node("Bosses").bosses:
		bosses[id] = _actor(game.get_node("Bosses").bosses[id])
	var fx = game.equipment.effects
	return {"region": game.region, "health": game.health, "mana": game.mana, "facing": game.facing, "finished": game.finished, "cleared": game.round_cleared,
		"inventory": game.inventory.duplicate(), "equipped": game.equipment.equipped.duplicate(), "cooldowns": game.cooldowns.duplicate(), "regions": regions,
		"bosses": bosses, "weather_time": weather.elapsed, "building_states": game.buildings.states.duplicate(true), "building_active": game.buildings.active.duplicate(true),
		"tasks": game.npcs.tasks.duplicate(), "tracked_task": game.book.tracked, "wander_region": game.npcs.wander_region, "wander_foot": game.npcs.wander_foot, "wander_wait": game.npcs.wander_wait,
		"wander_visited": game.npcs.visited_regions.duplicate(), "stock": game.npc_exchange.stock.duplicate(true), "quest": game.story.state.duplicate(true),
		"effects": {"elapsed": fx.elapsed, "heal_ready": fx.heal_ready, "echo_ready": fx.echo_ready, "shield_charge": fx.shield_charge, "shield_points": fx.shield_points},
		"traps": game.get_node("Traps").records.duplicate(true),
		"rng": {"loot": str(game.loot_rng.state), "chests": str(chests.rng.state), "npcs": str(game.npcs.rng.state)}}

## Explicit vector tags keep JSON readable and never instantiate objects/scripts.
static func encode(value: Variant) -> Variant:
	if value is Vector2: return {"$point": [value.x, value.y]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(encode(entry))
		return result
	return value

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("$point"):
			var pair: Variant = value["$point"]
			if pair is Array and pair.size() == 2 and number(pair[0], -10000, 10000) and number(pair[1], -10000, 10000): return Vector2(pair[0], pair[1])
			return null
		var result: Dictionary = {}
		for key: String in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(decode(entry))
		return result
	# JSON has one numeric type; restore counters as integers without rounding fractions.
	if value is float and is_finite(value) and value == floor(value) and absf(value) <= 100000000:
		return int(value)
	return value

static func number(value: Variant, low: float = 0.0, high: float = 1000000.0) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int = 0, high: int = 1000000) -> bool:
	return number(value, low, high) and float(value) == floor(float(value))

static func point(value: Variant, id: String) -> bool:
	return value is Vector2 and value.is_finite() and value.x >= 0 and value.y >= 0 and value.x <= Maps.MAPS[id].size.x and value.y <= Maps.MAPS[id].size.y

static func item_valid(id: String) -> bool:
	var parts := id.split("@fusion")
	if parts.size() > 2: return false
	var source: String = parts[0]
	var base := source.trim_suffix("@mutated")
	if parts.size() == 2 and (not parts[1].is_valid_int() or str(int(parts[1])) != parts[1] or not integer(int(parts[1]), 1, 10) or not Loot.BASE_ITEMS.has(base)): return false
	return Loot.BASE_ITEMS.has(base) if source.ends_with("@mutated") else (Loot.BASE_ITEMS.has(source) or (parts.size() == 1 and (Items.MATERIALS.has(source) or Items.SUPPLIES.has(source))))

func _valid_actor(actor: Variant, id: String, boss: bool = false) -> bool:
	if not actor is Dictionary or not point(actor.get("position"), id) or not point(actor.get("home"), id): return false
	for key: String in actor:
		if key not in ["position", "home", "hp", "max_hp", "cooldown", "paid", "equipment_paid", "skill_index", "behavior"]: return false
	if actor.has("behavior") and actor.behavior not in game.Guards.KINDS: return false
	if not integer(actor.get("hp"), 0, 10000) or not integer(actor.get("max_hp"), 1, 10000) or actor.hp > actor.max_hp: return false
	for key: String in ["paid", "equipment_paid"]:
		if actor.has(key) and not actor[key] is bool: return false
	if actor.has("cooldown") and not number(actor.cooldown, 0, 60): return false
	if actor.has("skill_index") and not integer(actor.skill_index, 0, 4): return false
	if boss and (not number(actor.get("cooldown"), 0, 60) or not integer(actor.get("skill_index"), 0, 4) or not actor.get("paid") is bool): return false
	return true

func valid(data: Variant) -> bool:
	if not data is Dictionary or not Maps.IDS.has(data.get("region")): return false
	var tracked: Variant = data.get("tracked_task", "") # Pre-journal v1 saves have no tracked task.
	if not tracked is String or (tracked not in ["", "stove"] and not game.npcs.DEFINITIONS.has(tracked)): return false
	if not integer(data.get("health"), 0, 100) or not data.get("finished") is bool or not data.get("cleared") is bool or not data.get("facing") is Vector2: return false
	if not number(data.get("mana"), 0, game.MAX_MANA): return false
	if not data.facing.is_finite() or data.facing.length() > 1.01 or (data.health == 0 and not data.finished) or (data.finished and data.health > 0 and not data.cleared): return false
	for key: String in ["inventory", "equipped", "regions", "bosses", "cooldowns", "building_states", "building_active", "tasks", "stock", "effects", "traps", "rng"]:
		if not data.get(key) is Dictionary: return false
	if data.regions.size() != Maps.IDS.size() or data.bosses.size() != BossCatalog.DEFINITIONS.size() or data.building_states.size() != Maps.IDS.size() or data.tasks.size() != game.npcs.DEFINITIONS.size(): return false
	if data.stock.size() != Shop.STOCK.size() or data.effects.size() != 5 or data.traps.size() != Maps.IDS.size() or data.rng.size() != 3 or data.cooldowns.size() != 3: return false
	if data.inventory.size() > 500: return false
	for material: String in Items.MATERIALS:
		if not data.inventory.has(material): return false
	for item: String in data.inventory:
		if not item_valid(item) or not integer(data.inventory[item]): return false
	for slot: String in data.equipped:
		var item: Variant = data.equipped[slot]
		if not Gear.SLOTS.has(slot) or not item is String or not item_valid(item) or int(data.inventory.get(item, 0)) < 1: return false
		var base: String = item.get_slice("@", 0)
		if ("weapon" if Gear.WEAPONS.has(base) else base.get_slice("-", 1)) != slot: return false
	for key: String in ["j", "k", "l"]:
		if not number(data.cooldowns.get(key), 0, 30): return false
	if not number(data.get("weather_time"), 0, 100000000): return false
	if not Maps.IDS.has(data.get("wander_region")) or not point(data.get("wander_foot"), data.wander_region) or not number(data.get("wander_wait"), 0, 8): return false
	if not data.get("wander_visited") is Array or data.wander_visited.size() > 10: return false
	for id: Variant in data.wander_visited:
		if not Maps.IDS.has(id): return false
	for id: String in game.npcs.DEFINITIONS:
		if not data.tasks.get(id) in ["available", "active", "complete"]: return false
	if tracked not in ["", "stove"] and data.tasks[tracked] == "available": return false
	for id: String in ["loot", "chests", "npcs"]:
		var value: Variant = data.rng.get(id)
		if not value is String or not value.is_valid_int() or str(int(value)) != value: return false
	for key: String in ["elapsed", "heal_ready", "echo_ready", "shield_charge"]:
		if not number(data.effects.get(key), 0, 100000000): return false
	if not integer(data.effects.get("shield_points"), 0, 18) or data.effects.shield_charge > 8: return false
	for id: String in Maps.IDS:
		var state: Variant = data.regions.get(id)
		if not state is Dictionary or not point(state.get("foot"), id) or not state.get("rested") is bool: return false
		if not state.get("visited") is Array or state.visited.size() != 3: return false
		for i in range(3):
			if not state.visited[i] is bool or (i > 0 and state.visited[i] and not state.visited[i - 1]): return false
		for key: String in ["pickups", "enemies", "plots", "chests"]:
			if not state.get(key) is Array: return false
		if state.pickups.size() > 1000 or state.enemies.size() > int(Items.REGIONS[id].enemies) or state.plots.size() != 6 or state.chests.size() not in [2, 3]: return false
		for pickup: Variant in state.pickups:
			if not _valid_pickup(pickup, id): return false
		for enemy: Variant in state.enemies:
			if not _valid_actor(enemy, id): return false
		for plot: Variant in state.plots:
			if not plot is Dictionary or not Ecology.CLIMATES[id].plants.has(plot.get("item")) or not point(plot.get("position"), id): return false
			if not number(plot.get("growth"), 0, Ecology.PLANTS[plot.item].time) or not plot.get("ripe") is bool or not integer(plot.get("harvests")) or not plot.get("pickup") is Dictionary: return false
			if not plot.pickup.is_empty() and not _valid_pickup(plot.pickup, id): return false
			if plot.ripe and (plot.pickup.is_empty() or plot.growth != Ecology.PLANTS[plot.item].time): return false
		for chest: Variant in state.chests:
			if not chest is Dictionary or not point(chest.get("position"), id) or not chest.get("mutated") is bool or not chest.get("rewarded") is bool or chest.get("state") not in ["sealed", "guarding", "cleared", "opened"]: return false
			if not chest.get("mobs") is Array or not chest.get("boss") is Dictionary or chest.mobs.size() > 4: return false
			if chest.rewarded != (chest.state == "opened") or (not chest.mutated and chest.state in ["guarding", "cleared"]): return false
			if chest.mutated and chest.state != "sealed" and (chest.mobs.size() != 4 or not _valid_actor(chest.boss, id, true)): return false
			for mob: Variant in chest.mobs:
				if not _valid_actor(mob, id) or not mob.get("paid") is bool: return false
		var building: Variant = data.building_states.get(id)
		if not building is Dictionary or not Buildings.REGIONS[id].pool.has(building.get("effect")) or not building.get("inside") is bool or not integer(building.get("visits")): return false
		var record: Variant = data.traps.get(id)
		if not record is Dictionary: return false
		for key: String in ["spawned", "hits", "dodged"]:
			if not integer(record.get(key)): return false
	for id: String in BossCatalog.DEFINITIONS:
		var boss: Variant = data.bosses.get(id)
		if not _valid_actor(boss, BossCatalog.DEFINITIONS[id].region, true) or not boss.get("equipment_paid", false) is bool: return false
	for slot: String in data.building_active:
		var effect: Variant = data.building_active[slot]
		if slot not in ["buff", "debuff"] or not effect is Dictionary or not Buildings.EFFECTS.has(effect.get("effect")) or not Maps.IDS.has(effect.get("source")): return false
		if Buildings.EFFECTS[effect.effect].positive != (slot == "buff") or not number(effect.get("left"), 0, 60) or not number(effect.get("healing"), 0, 1): return false
	for id: String in Shop.STOCK:
		if not data.stock.get(id) is Dictionary: return false
		if data.stock[id].size() != Shop.STOCK[id].size(): return false
		for row: Array in Shop.STOCK[id]:
			if not integer(data.stock[id].get(row[0]), 0, int(row[2])): return false
	return game.story.valid_state(data.get("quest"))

func _valid_pickup(value: Variant, id: String) -> bool:
	if not value is Dictionary or not value.get("item") is String or not item_valid(value.item) or not point(value.get("position"), id): return false
	for key: String in ["weather_growth", "monster_drop", "boss_drop", "equipment_drop", "chest_drop", "chest_boss_drop", "chest_guard_drop"]:
		if value.has(key) and not value[key] is bool: return false
	return true

func read_save() -> Dictionary:
	# A newer primary must not be silently rolled back/overwritten by this build.
	for path: String in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 4000000: continue
		var raw: Variant = parse_text(file.get_as_text())
		if not raw is Dictionary: continue
		if number(raw.get("version"), VERSION + 1, 1000000): return {}
		var data := decode_snapshot(raw)
		if not data.is_empty():
			status = "已从备份恢复探索" if path.ends_with(".bak") else "已继续上次探索"
			return data
	return {}

func decode_snapshot(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not integer(raw.get("version"), 1, VERSION) or not raw.get("data") is Dictionary:
		return {}
	var data: Variant = decode(raw.data)
	if raw.version < 3 and data is Dictionary:
		data["mana"] = game.MAX_MANA
	return data if valid(data) else {}

static func parse_text(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

func write_snapshot(data: Dictionary) -> Error:
	save_stage = "校验进度"
	if not valid(data): return ERR_INVALID_DATA
	save_stage = "写入临时存档"
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "data": encode(data)}, "", false, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	save_stage = "更新备份"
	# Only promote a validated previous primary to the recovery slot.
	if FileAccess.file_exists(PATH):
		var previous: Variant = parse_text(FileAccess.get_file_as_string(PATH))
		if not decode_snapshot(previous).is_empty():
			error = DirAccess.copy_absolute(PATH, PATH + ".bak")
			if error != OK: return error
	# A confirmed new expedition also replaces an unusable old recovery file.
	var backup: Variant = parse_text(FileAccess.get_file_as_string(PATH + ".bak")) if FileAccess.file_exists(PATH + ".bak") else null
	if decode_snapshot(backup).is_empty():
		error = DirAccess.copy_absolute(PATH + ".tmp", PATH + ".bak")
		if error != OK: return error
	save_stage = "替换正式存档"
	return DirAccess.rename_absolute(PATH + ".tmp", PATH)

func apply(data: Dictionary) -> void:
	# Call only after validating the entire snapshot; no partial restore on errors.
	for item: String in data.inventory:
		if item.contains("@fusion"):
			game.equipment.fusion.register_item(item.get_slice("@fusion", 0), int(item.get_slice("@fusion", 1)))
	game.inventory = data.inventory.duplicate()
	game.equipment.equipped = data.equipped.duplicate()
	game.region = data.region
	game.player_foot = data.regions[data.region].foot
	game.health = int(data.health)
	game.mana = float(data.mana)
	game.facing = data.facing
	game.cooldowns = data.cooldowns.duplicate()
	game.round_cleared = data.cleared
	var weather = game.get_node("Weather")
	weather.elapsed = float(data.weather_time)
	var chests = game.get_node("Chests")
	for id: String in Maps.IDS:
		var state: Dictionary = data.regions[id]
		game.states[id] = {"foot": state.foot, "visited": state.visited.duplicate(), "rested": state.rested, "pickups": state.pickups.duplicate(true), "enemies": []}
		for saved: Dictionary in state.enemies:
			var actor := {"flash": 0.0}
			actor.merge(saved)
			# Existing v1 snapshots predate attack roles; assign each surviving guard a role.
			if not actor.has("behavior"): actor["behavior"] = game.Guards.KINDS[game.states[id].enemies.size() % 3]
			game.Guards.reset(actor)
			game.states[id].enemies.append(actor)
		weather.climates[id] = Ecology.weather_at(id, weather.elapsed)
		weather.plots[id] = state.plots.duplicate(true)
		game.states[id]["weather"] = weather.climates[id]
		game.states[id]["weather_plots"] = weather.plots[id]
		weather.adapt_enemies(id)
		chests.regions[id] = []
		for saved: Dictionary in state.chests:
			var chest: Dictionary = saved.duplicate(true)
			chest["warning"] = 1.2 if chest.state == "guarding" else 0.0
			for mob: Dictionary in chest.mobs: mob.merge({"damage": 6, "speed": 72.0, "flash": 0.0}, true)
			if not chest.boss.is_empty():
				var boss_id: String = ChestRules.REGION_BOSS[id]
				chest.boss.merge({"id": boss_id, "art": boss_id, "flash": 0.0, "windup": 0.0, "cast_fx": {}, "hit_radius": 38.0, "hit_height": 45.0}, true)
				chest.boss.cooldown = maxf(1.8, float(chest.boss.cooldown))
			chests.regions[id].append(chest)
	for id: String in data.bosses:
		game.get_node("Bosses").bosses[id].merge(data.bosses[id], true)
	game.buildings.states = data.building_states.duplicate(true)
	game.buildings.active = data.building_active.duplicate(true)
	game.buildings.region = data.region
	game.npcs.tasks = data.tasks.duplicate()
	game.npcs.wander_region = data.wander_region
	game.npcs.wander_foot = data.wander_foot
	game.npcs.wander_wait = float(data.wander_wait)
	game.npcs.visited_regions.assign(data.wander_visited)
	game.npcs.wander_route.clear()
	game.npcs.wander_exit = ""
	game.npc_exchange.stock = data.stock.duplicate(true)
	game.story.state = data.quest.duplicate(true)
	game.book.tracked = data.get("tracked_task", "")
	var fx = game.equipment.effects
	for key: String in data.effects: fx.set(key, data.effects[key])
	fx.clear_transients()
	game.get_node("Traps").records = data.traps.duplicate(true)
	game.loot_rng.state = int(data.rng.loot)
	chests.rng.state = int(data.rng.chests)
	game.npcs.rng.state = int(data.rng.npcs)
	game.finished = false
	game.enter_region(data.region)
	game.hurt_timer = 1.8
	game.get_node("Bosses").enter_region()
	game.story.refresh()
	game.npcs.refresh()
	game._refresh_ui()
	if data.finished:
		game._end_round(data.cleared)
