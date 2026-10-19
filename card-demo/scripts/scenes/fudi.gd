extends Control
## Self-contained action prototype; never writes the spirit game's save.
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const Tools = preload("res://scripts/scenes/exploration_tools.gd")
const Hero = preload("res://scripts/scenes/hero_walk_sprite.gd")
const ENEMY_ART := preload("res://assets/characters/pet_enemy_stone.png")
const ARENA := Rect2(64, 250, 1152, 382)
const SPEED := 260.0
const ATTACKS := {
	"j": {"damage": 26, "cooldown": 0.32, "radius": 112.0, "name": "斩击"},
	"k": {"damage": 20, "cooldown": 0.85, "radius": 0.0, "name": "灵弹"},
	"l": {"damage": 42, "cooldown": 3.5, "radius": 180.0, "name": "震荡"},
}
var region := "grove"
var states: Dictionary = {}
var inventory: Dictionary = {"wood": 0, "herb": 0, "ore": 0, "crystal": 0}
var player_foot := Vector2(640, 460)
var facing := Vector2.RIGHT
var health := 100
var hurt_timer := 0.0
var cooldowns: Dictionary = {"j": 0.0, "k": 0.0, "l": 0.0}
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var model: Hero
var tools: Tools
var status: Label
var bag: Label
var skills: Label
var hint: Label
var outcome: PanelContainer
var result: Label
var finished := false

func _ready() -> void:
	DisplayServer.window_set_title("福地")
	for id: String in ["grove", "quarry", "ruins"]:
		states[id] = _create_region(id)
	model = Hero.new()
	add_child(model)
	_build_hud()
	tools = Tools.new()
	tools.region = region
	add_child(tools)
	tools.atlas.can_travel = true
	tools.atlas.resource_provider = remaining_resources
	tools.atlas.travel_requested.connect(enter_region)
	enter_region(region)

func _create_region(id: String) -> Dictionary:
	var pickups: Array[Dictionary] = []
	var index := 0
	for item: String in Catalog.REGIONS[id].resources:
		for n in range(int(Catalog.REGIONS[id].resources[item])):
			var point := Vector2(135 + (index % 8) * 140, 328 + floori(index / 8.0) * 126)
			pickups.append({"item": item, "position": point})
			index += 1
	var enemies: Array[Dictionary] = []
	for n in range(int(Catalog.REGIONS[id].enemies)):
		enemies.append({"position": Vector2(190 + n * 170, 565 if n % 2 == 0 else 320), "hp": 60, "flash": 0.0})
	return {"pickups": pickups, "enemies": enemies}

func _build_hud() -> void:
	var header := PanelContainer.new()
	header.position = Vector2(24, 20)
	header.size = Vector2(1232, 126)
	header.add_theme_stylebox_override("panel", UI.panel())
	add_child(header)
	var layout := VBoxContainer.new()
	header.add_child(layout)
	status = UI.label("", 27, Color("#f4daa0"))
	layout.add_child(status)
	bag = UI.label("", 19)
	layout.add_child(bag)
	layout.add_child(UI.label("WASD 移动  /  J 朝向斩击  /  K 朝向灵弹  /  L 范围震荡  /  靠近光点自动采集", 18))
	skills = UI.label("", 19, Color("#b5d9d1"))
	skills.position = Vector2(350, 169)
	add_child(skills)
	hint = UI.label("", 19, Color("#e5d49e"))
	hint.position = Vector2(66, 662)
	add_child(hint)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	outcome = PanelContainer.new()
	outcome.position = Vector2(375, 270)
	outcome.size = Vector2(530, 240)
	outcome.add_theme_stylebox_override("panel", UI.panel(Color("#142b38")))
	layer.add_child(outcome)
	var end_layout := VBoxContainer.new()
	end_layout.add_theme_constant_override("separation", 18)
	outcome.add_child(end_layout)
	result = UI.label("", 25, Color("#f4daa0"))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_layout.add_child(result)
	end_layout.add_child(UI.button("重新开始一轮", restart))
	end_layout.add_child(UI.button("返回游戏选择", func() -> void: GameManager.goto_scene("menu")))
	outcome.hide()

func remaining_resources(id: String) -> Dictionary:
	var counts: Dictionary = {}
	if not states.has(id):
		return counts
	for item: String in Catalog.REGIONS[id].resources:
		counts[item] = 0
	for pickup: Dictionary in states[id].pickups:
		counts[pickup.item] += 1
	return counts

func enter_region(id: String) -> void:
	if not states.has(id) or finished:
		return
	region = id
	tools.region = id
	player_foot = Vector2(640, 460)
	model.position = player_foot
	model.update_movement(Vector2.ZERO, 0)
	projectiles.clear()
	effects.clear()
	hurt_timer = maxf(hurt_timer, 1.0)
	_refresh_ui()
	queue_redraw()

func restart() -> void:
	GameManager.goto_scene("fudi")

func _unhandled_input(event: InputEvent) -> void:
	if tools.is_open() or finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var actions := {KEY_J: "j", KEY_K: "k", KEY_L: "l"}
		if actions.has(key):
			attack(actions[key])
			get_viewport().set_input_as_handled()

func attack(kind: String) -> bool:
	if not ATTACKS.has(kind) or finished or tools.is_open() or float(cooldowns[kind]) > 0:
		return false
	var config: Dictionary = ATTACKS[kind]
	cooldowns[kind] = config.cooldown
	var origin := player_foot - Vector2(0, 30)
	if kind == "k":
		projectiles.append({"position": origin + facing * 30, "velocity": facing * 620, "life": 0.85})
	else:
		for enemy: Dictionary in states[region].enemies:
			var offset: Vector2 = enemy.position - player_foot
			if offset.length() <= float(config.radius) and (kind == "l" or offset.length() < 25 or offset.normalized().dot(facing) >= 0.15):
				_damage(enemy, int(config.damage))
		effects.append({"position": origin, "radius": config.radius, "life": 0.22, "kind": kind, "facing": facing})
	_remove_dead()
	_refresh_ui()
	queue_redraw()
	return true

func _damage(enemy: Dictionary, amount: int) -> void:
	enemy.hp = maxi(0, int(enemy.hp) - amount)
	enemy.flash = 0.14

func _remove_dead() -> void:
	var enemies: Array = states[region].enemies
	for i in range(enemies.size() - 1, -1, -1):
		if int(enemies[i].hp) <= 0:
			enemies.remove_at(i)
	var remaining := 0
	for id: String in states:
		remaining += states[id].enemies.size()
	if remaining == 0:
		_end_round(true)

func _collect_nearby() -> void:
	var pickups: Array = states[region].pickups
	for i in range(pickups.size() - 1, -1, -1):
		if player_foot.distance_to(pickups[i].position) <= 32:
			inventory[pickups[i].item] += 1
			pickups.remove_at(i)

func _process(delta: float) -> void:
	if tools.is_open() or finished:
		model.update_movement(Vector2.ZERO, 0)
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var previous := player_foot
	player_foot += direction * SPEED * delta
	player_foot = player_foot.clamp(ARENA.position + Vector2(24, 64), ARENA.end - Vector2(24, 16))
	if direction != Vector2.ZERO:
		facing = direction
	model.position = player_foot
	model.update_movement(player_foot - previous, delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	model.modulate = Color("#ff9c8c") if hurt_timer > 0.75 else Color.WHITE
	for key: String in cooldowns:
		cooldowns[key] = maxf(0, float(cooldowns[key]) - delta)
	for enemy: Dictionary in states[region].enemies:
		enemy.flash = maxf(0, float(enemy.flash) - delta)
		var offset: Vector2 = player_foot - enemy.position
		if offset.length() > 32:
			enemy.position += offset.normalized() * minf(76.0 * delta, offset.length() - 32)
		elif hurt_timer <= 0:
			health = maxi(0, health - 10)
			hurt_timer = 1.0
	_tick_projectiles(delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if float(effects[i].life) <= 0:
			effects.remove_at(i)
	_collect_nearby()
	if health <= 0:
		_end_round(false)
	_refresh_ui()
	queue_redraw()

func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var start: Vector2 = shot.position
		shot.position += shot.velocity * delta
		shot.life -= delta
		var hit: Dictionary = {}
		var nearest := INF
		for enemy: Dictionary in states[region].enemies:
			var center: Vector2 = enemy.position - Vector2(0, 30)
			var closest := Geometry2D.get_closest_point_to_segment(center, start, shot.position)
			if int(enemy.hp) > 0 and center.distance_to(closest) <= 28 and start.distance_to(closest) < nearest:
				hit = enemy
				nearest = start.distance_to(closest)
		if not hit.is_empty():
			_damage(hit, int(ATTACKS.k.damage))
			shot.life = 0.0
		if float(shot.life) <= 0 or not ARENA.has_point(shot.position):
			projectiles.remove_at(i)
	_remove_dead()

func _end_round(won: bool) -> void:
	finished = true
	result.text = "三境已肃清 · 本轮探索完成\n采集物品 %d 份" % _inventory_total() if won else "本轮探索结束\n采集物品 %d 份，重开后再试一次。" % _inventory_total()
	outcome.show()

func _inventory_total() -> int:
	var count := 0
	for amount: int in inventory.values():
		count += amount
	return count

func _refresh_ui() -> void:
	status.text = "福地  /  %s     生命 %d / 100     守卫 %d" % [Catalog.REGIONS[region].name, health, states[region].enemies.size()]
	bag.text = "行囊    木料 %d     灵草 %d     玄铁 %d     灵晶 %d" % [inventory.wood, inventory.herb, inventory.ore, inventory.crystal]
	var parts: Array[String] = []
	for key: String in cooldowns:
		parts.append("%s %s  %s" % [key.to_upper(), ATTACKS[key].name, "就绪" if float(cooldowns[key]) <= 0 else "%.1fs" % cooldowns[key]])
	skills.text = "    ".join(parts)
	var cleared := 0
	for id: String in states:
		if states[id].enemies.is_empty():
			cleared += 1
	hint.text = "三境肃清 %d / 3  ·  %s" % [cleared, "本地已清理，按 M 选择下一地图；可继续收集资源。" if states[region].enemies.is_empty() else "面向守卫攻击，保持移动躲避接触伤害。"]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0d1c26"))
	draw_style_box(UI.panel(Color(Catalog.REGIONS[region].color)), ARENA)
	for x in range(100, 1200, 70):
		for y in range(280, 620, 70):
			draw_circle(Vector2(x, y), 2, Color(0.7, 0.8, 0.7, 0.10))
	if not states.has(region):
		return
	var font := ThemeDB.fallback_font
	for pickup: Dictionary in states[region].pickups:
		var color := Color(Catalog.ITEMS[pickup.item].color)
		draw_circle(pickup.position, 19, Color(color, 0.16))
		draw_circle(pickup.position, 7, color)
		draw_string(font, pickup.position + Vector2(-18, 35), Catalog.ITEMS[pickup.item].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	for enemy: Dictionary in states[region].enemies:
		var point: Vector2 = enemy.position
		draw_set_transform(point, 0, Vector2(1, 0.30))
		draw_circle(Vector2.ZERO, 29, Color(0.02, 0.04, 0.05, 0.45))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(ENEMY_ART, Rect2(point - Vector2(38, 76), Vector2(76, 76)), false, Color("#ffbca0") if float(enemy.flash) > 0 else Color.WHITE)
		draw_rect(Rect2(point - Vector2(28, 84), Vector2(56, 5)), Color("#18212b"))
		draw_rect(Rect2(point - Vector2(28, 84), Vector2(56 * float(enemy.hp) / 60.0, 5)), Color("#dc947e"))
	var origin := player_foot - Vector2(0, 30)
	draw_line(origin + facing * 26, origin + facing * 48, Color("#f5d69b"), 3, true)
	for shot: Dictionary in projectiles:
		draw_circle(shot.position, 10, Color("#9ceafa"))
		draw_circle(shot.position, 4, Color.WHITE)
	for effect: Dictionary in effects:
		var color := Color("#b9a0f5") if effect.kind == "l" else Color("#ffe6ab")
		color.a = clampf(float(effect.life) / 0.22, 0, 1)
		var angle: float = effect.facing.angle()
		draw_arc(effect.position, float(effect.radius), 0 if effect.kind == "l" else angle - 1.4, TAU if effect.kind == "l" else angle + 1.4, 48, color, 7, true)
