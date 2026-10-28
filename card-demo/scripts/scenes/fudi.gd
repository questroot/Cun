extends Control
signal sound_requested(kind: String)
## Self-contained action prototype; never writes the spirit game's save.
const Catalog = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const Tools = preload("res://scripts/scenes/exploration_tools.gd")
const Hero = preload("res://scripts/scenes/hero_walk_sprite.gd")
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Landscape = preload("res://scripts/scenes/fudi_landscape.gd")
const Bosses = preload("res://scripts/scenes/fudi_bosses.gd")
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const MaterialArt = preload("res://scripts/scenes/fudi_material_art.gd")
const Equipment = preload("res://scripts/scenes/fudi_equipment.gd")
const Buildings = preload("res://scripts/scenes/fudi_buildings.gd")
const Chests = preload("res://scripts/scenes/fudi_chests.gd")
const GMTools = preload("res://scripts/scenes/fudi_gm.gd")
const NPCs = preload("res://scripts/scenes/fudi_npcs.gd")
const NpcExchange = preload("res://scripts/scenes/fudi_npc_exchange.gd")
const PixelVFX = preload("res://scripts/scenes/pixel_vfx.gd")
const ENEMY_ART := preload("res://assets/characters/pet_enemy_stone.png")
const ARENA := Rect2(16, 88, 1248, 560)
const WORLD_ZOOM := 0.8
const VIEW_SIZE := ARENA.size / WORLD_ZOOM
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
var round_cleared := false
var world_view: Control
var world_canvas: Control
var camera_origin := Vector2.ZERO
var minimap: Control
var dialogue: PanelContainer
var dialogue_text: Label
var journal: PanelContainer
var journal_text: RichTextLabel
var continue_button: Button
var loot_rng := RandomNumberGenerator.new()
var equipment: Equipment
var buildings: Buildings
var gm: CanvasLayer
var health_bar: ProgressBar
var health_label: Label
var hud_actions: HBoxContainer
var menu_button: Button
var menu: Control
var menu_actions: VBoxContainer
var menu_exit: Button
var menu_info: Label
var npcs: Node
var npc_exchange: Node

## Fixed observation provider: only painted targets intersecting the clipped world view.
func play_visible() -> Dictionary:
	if not states.has(region) or world_view == null: return {}
	var result := {"location":Catalog.REGIONS[region].name,"controls":"WASD移动，J斩击/K灵弹/L震荡，E附近交互，M地图，B行囊","world_view":{"x":ARENA.position.x,"y":ARENA.position.y,"width":ARENA.size.x,"height":ARENA.size.y}}
	if _paused() or finished:
		result["world_occluded"] = true
		return result
	var targets: Array = []
	var data: Dictionary = Maps.MAPS[region]
	for i in range(data.sites.size()):
		var site: Array = data.sites[i]
		_visible_target(targets,site[1]*data.size,str(site[0]),"investigation",80)
	_visible_target(targets,data.spawn*data.size,"休息点 · E恢复一次","rest",60)
	for exit: Array in data.exits:
		_visible_target(targets,exit[1]*data.size,"E → "+str(Catalog.REGIONS[exit[0]].name),"exit",80)
	for enemy: Dictionary in states[region].enemies:
		var center := world_to_screen(enemy.position)
		_visible_target(targets,enemy.position-Vector2(0,38),"守卫","enemy",46)
		var bar := Rect2(center-Vector2(28,84)*WORLD_ZOOM,Vector2(56,5)*WORLD_ZOOM)
		if ARENA.encloses(bar) and not targets.is_empty() and targets[-1].kind == "enemy" and ARENA.has_point(center-Vector2(0,38)*WORLD_ZOOM):
			targets[-1]["visible_health_bar"] = {"fill_ratio":clampf(float(enemy.hp)/float(enemy.get("max_hp",60)),0.0,1.0),"x":bar.position.x,"y":bar.position.y,"width":bar.size.x,"height":bar.size.y}
	for pickup: Dictionary in states[region].pickups:
		if not pickup.get("weather_growth",false): _visible_target(targets,pickup.position,str(Catalog.ITEMS[pickup.item].name),"pickup",30)
	var point := world_to_screen(player_foot)
	result["player_screen"] = {"x":point.x,"y":point.y}
	result["objects"] = targets
	var terrain: Array = []
	for rect: Rect2 in Maps.obstacles(region):
		var painted := Rect2(world_to_screen(rect.position),rect.size*WORLD_ZOOM)
		var clipped := ARENA.intersection(painted)
		if clipped.has_area():
			terrain.append({"appearance":"地形或建筑的已绘主体，不代表完整碰撞轮廓","visible_bounds":{"x":clipped.position.x,"y":clipped.position.y,"width":clipped.size.x,"height":clipped.size.y}})
	result["visible_terrain"] = terrain
	var bosses := get_node_or_null("Bosses")
	if bosses != null: result["boss_view"] = bosses.play_visible()
	if buildings != null: result["building_view"] = buildings.play_visible()
	var traps := get_node_or_null("Traps")
	if traps != null: result["visible_hazards"] = traps.play_visible()
	var chests := get_node_or_null("Chests")
	if chests != null:
		result["visible_chests"] = chests.play_visible()
		result["chest_encounter_view"] = chests.play_visible_encounters()
	var weather := get_node_or_null("Weather")
	if weather != null: result["visible_gardens"] = weather.play_visible()
	if npcs != null: result["visible_npcs"] = npcs.play_visible()
	return result

func _visible_target(targets: Array, point: Vector2, title: String, kind: String, _radius: float) -> void:
	var screen := world_to_screen(point)
	# Conservative until exact per-art bounds are available: omit edge fragments.
	if not ARENA.has_point(screen): return
	targets.append({"title":title,"kind":kind,"x":screen.x,"y":screen.y})

func world_to_screen(point: Vector2) -> Vector2:
	return ARENA.position + (point - camera_origin) * WORLD_ZOOM

func visible_world() -> Rect2:
	return Rect2(camera_origin, VIEW_SIZE)

func _ready() -> void:
	add_to_group("cun_play_visible")
	DisplayServer.window_set_title("福地")
	loot_rng.randomize()
	for item: String in Catalog.ITEMS:
		inventory[item] = 0
	for id: String in Maps.IDS:
		states[id] = _create_region(id)
	world_view = Control.new()
	world_view.position = ARENA.position
	world_view.size = ARENA.size
	world_view.clip_contents = true
	world_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_view)
	world_canvas = Control.new()
	world_canvas.scale = Vector2.ONE * WORLD_ZOOM
	world_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_canvas.draw.connect(_draw_world)
	world_view.add_child(world_canvas)
	model = Hero.new()
	world_canvas.add_child(model)
	_build_hud()
	tools = Tools.new()
	tools.region = region
	add_child(tools)
	tools.atlas.can_travel = true
	tools.atlas.resource_provider = remaining_resources
	tools.atlas.set_meta("loot_provider", Loot.summary)
	tools.atlas.travel_requested.connect(enter_region)
	tools.modal_blocker = func() -> bool: return menu.visible or get_meta("audio_settings_open", false) or get_meta("fudi_gm_open", false) or dialogue.visible or journal.visible or outcome.visible or (equipment != null and equipment.is_open())
	enter_region(region)
	var bosses := Bosses.new()
	bosses.name = "Bosses"
	add_child(bosses)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	buildings = Buildings.new()
	buildings.name = "Buildings"
	add_child(buildings)
	var chests := Chests.new()
	chests.name = "Chests"
	add_child(chests)
	gm = GMTools.new()
	gm.name = "GMTools"
	add_child(gm)
	npcs = NPCs.new()
	npcs.name = "NPCs"
	add_child(npcs)
	npc_exchange = NpcExchange.new()
	npc_exchange.name = "NpcExchange"
	add_child(npc_exchange)

func combat_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	targets.assign(states[region].enemies)
	var bosses := get_node_or_null("Bosses")
	if bosses != null:
		targets.append_array(bosses.targets(region))
	var chests := get_node_or_null("Chests")
	if chests != null:
		targets.append_array(chests.targets(region))
	return targets

func _create_region(id: String) -> Dictionary:
	var pickups: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + Maps.IDS.find(id) * 79
	var extent: Vector2 = Maps.MAPS[id].size
	for item: String in Catalog.REGIONS[id].resources:
		for n in range(int(Catalog.REGIONS[id].resources[item])):
			var point := _free_point(id, rng, pickups)
			pickups.append({"item": item, "position": point})
	var enemies: Array[Dictionary] = []
	for n in range(int(Catalog.REGIONS[id].enemies)):
		var point := _free_point(id, rng, enemies)
		enemies.append({"position": point, "home": point, "hp": 60, "flash": 0.0})
	return {"pickups": pickups, "enemies": enemies, "visited": [false, false, false], "rested": false, "foot": Maps.MAPS[id].spawn * extent}

func _free_point(id: String, rng: RandomNumberGenerator, occupied: Array) -> Vector2:
	var extent: Vector2 = Maps.MAPS[id].size
	for attempt in range(3000):
		var point := Vector2(rng.randf_range(130, extent.x - 130), rng.randf_range(160, extent.y - 130))
		if not Maps.walkable(id, point, 55) or point.distance_to(Maps.MAPS[id].spawn * extent) < 400 or NPCs.reserved(id, point):
			continue
		var clear := true
		for site: Array in Maps.MAPS[id].sites:
			if point.distance_to(site[1] * extent) < 150:
				clear = false
		for exit: Array in Maps.MAPS[id].exits:
			if point.distance_to(exit[1] * extent) < 160:
				clear = false
		for other: Dictionary in occupied:
			if point.distance_to(other.position) < 76:
				clear = false
		if clear:
			return point
	# A deterministic safe road point; normal configured densities never exhaust the attempts.
	return Maps.MAPS[id].spawn * extent

func _build_hud() -> void:
	var header := PanelContainer.new()
	header.position = Vector2(16, 12)
	header.size = Vector2(1248, 64)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := UI.panel(Color("#142d32"))
	skin.set_content_margin_all(0)
	header.add_theme_stylebox_override("panel", skin)
	add_child(header)
	status = UI.label("", 22, Color("#f4daa0"))
	status.position = Vector2(34, 18)
	add_child(status)
	bag = UI.label("", 13, Color("#9eb8b0"))
	bag.position = Vector2(34, 49)
	bag.size.x = 280
	bag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(bag)
	health_label = UI.label("", 16)
	health_label.position = Vector2(330, 22)
	add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(330, 51)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#29423f")
	track.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", track)
	health_bar.add_theme_stylebox_override("fill", track.duplicate())
	add_child(health_bar)
	health_bar.size = Vector2(200, 7)
	hud_actions = HBoxContainer.new()
	hud_actions.position = Vector2(800, 25)
	hud_actions.add_theme_constant_override("separation", 8)
	add_child(hud_actions)
	menu_button = UI.button("菜单 Esc", toggle_menu)
	style_hud_button(menu_button)
	hud_actions.add_child(menu_button)
	skills = UI.label("", 16, Color("#b5d9d1"))
	skills.position = Vector2(28, 674)
	add_child(skills)
	minimap = Control.new()
	minimap.position = Vector2(1042, 100)
	minimap.size = Vector2(210, 140)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	add_child(minimap)
	hint = UI.label("", 16, Color("#e5d49e"))
	hint.position = Vector2(420, 674)
	hint.size = Vector2(830, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(hint)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var modal_shade := ColorRect.new()
	modal_shade.color = Color(0.01, 0.03, 0.04, 0.65)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal_shade)
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
	continue_button = UI.button("继续自由探索", resume_exploration)
	end_layout.add_child(continue_button)
	end_layout.add_child(UI.button("重新开始一轮", restart))
	end_layout.add_child(UI.button("返回游戏选择", func() -> void: GameManager.goto_scene("menu")))
	outcome.hide()
	dialogue = PanelContainer.new()
	dialogue.position = Vector2(210, 250)
	dialogue.size = Vector2(860, 280)
	dialogue.add_theme_stylebox_override("panel", UI.panel(Color("#142e35")))
	layer.add_child(dialogue)
	var talk_layout := VBoxContainer.new()
	talk_layout.add_theme_constant_override("separation", 18)
	dialogue.add_child(talk_layout)
	dialogue_text = UI.label("", 22, Color("#f0dfb5"))
	dialogue_text.custom_minimum_size = Vector2(810, 160)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_layout.add_child(dialogue_text)
	talk_layout.add_child(UI.button("收起记录  E / Esc", func() -> void: dialogue.hide()))
	dialogue.hide()
	journal = PanelContainer.new()
	journal.position = Vector2(180, 100)
	journal.size = Vector2(920, 520)
	journal.add_theme_stylebox_override("panel", UI.panel())
	layer.add_child(journal)
	var book_layout := VBoxContainer.new()
	journal.add_child(book_layout)
	journal_text = RichTextLabel.new()
	journal_text.custom_minimum_size = Vector2(860, 420)
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 20)
	book_layout.add_child(journal_text)
	book_layout.add_child(UI.button("继续探索  B / Esc", func() -> void: journal.hide()))
	journal.hide()
	menu = Control.new()
	menu.name = "ExplorationMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	var menu_shade := ColorRect.new()
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_shade.color = Color(0.01, 0.03, 0.04, 0.65)
	menu.add_child(menu_shade)
	var menu_panel := PanelContainer.new()
	menu_panel.position = Vector2(850, 88)
	menu_panel.custom_minimum_size = Vector2(398, 460)
	menu_panel.add_theme_stylebox_override("panel", UI.panel())
	menu.add_child(menu_panel)
	var menu_layout := VBoxContainer.new()
	menu_layout.add_theme_constant_override("separation", 14)
	menu_panel.add_child(menu_layout)
	menu_layout.add_child(UI.label("探索菜单", 24, Color("#f4daa0")))
	menu_info = UI.label("", 16)
	menu_info.custom_minimum_size.x = 355
	menu_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_layout.add_child(menu_info)
	menu_actions = VBoxContainer.new()
	menu_actions.add_theme_constant_override("separation", 8)
	menu_layout.add_child(menu_actions)
	menu_actions.add_child(UI.button("继续探索  Esc", close_menu))
	menu_layout.add_child(UI.label("WASD 移动 · E 交互\nJ 斩击 · K 灵弹 · L 震荡\nM 地图 · B 行囊 · C 装备\n靠近资源自动采集；规则详见 M / B。", 15, Color("#9eb8b0")))
	menu.hide()
	var update_shade := func() -> void: modal_shade.visible = outcome.visible or dialogue.visible or journal.visible
	for panel: Control in [outcome, dialogue, journal]:
		panel.visibility_changed.connect(update_shade)
	update_shade.call()

func style_hud_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(104, 36)
	button.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed"]:
		var skin: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		skin.set_content_margin_all(8)
		button.add_theme_stylebox_override(state, skin)

func register_hud_action(button: Button) -> void:
	button.reparent(hud_actions, false)
	style_hud_button(button)
	button.custom_minimum_size.x = 104
	button.size = button.custom_minimum_size
	hud_actions.move_child(menu_button, -1)

func configure_exploration_actions(bar: HBoxContainer) -> void:
	var map_button := bar.get_child(0) as Button
	var exit_button := bar.get_child(1) as Button
	register_hud_action(map_button)
	register_menu_action(exit_button)
	menu_exit = exit_button
	bar.hide()
	var journal_button := UI.button("行囊 B", func() -> void:
		if not _paused() and not finished:
			open_journal())
	hud_actions.add_child(journal_button)
	style_hud_button(journal_button)
	hud_actions.move_child(menu_button, -1)

func register_menu_action(button: Button) -> void:
	var actions := button.pressed.get_connections()
	for action: Dictionary in actions:
		button.pressed.disconnect(action.callable)
	button.pressed.connect(func() -> void:
		close_menu()
		for action: Dictionary in actions:
			action.callable.call())
	button.reparent(menu_actions, false)
	button.custom_minimum_size.x = 0
	button.size.x = 0
	if menu_exit != null:
		menu_actions.move_child(button, menu_exit.get_index())

func toggle_menu() -> void:
	if menu.visible:
		close_menu()
	elif not _paused() and not finished:
		menu_info.text = "%s · %s\n守卫剩余 %d · 见闻 %d / %d\n行囊 %d 份 · 坐标 %d, %d" % [Maps.MAPS[region].npc, Maps.MAPS[region].chapter, states[region].enemies.size(), _visited_total(), Maps.site_total(), _inventory_total(), int(player_foot.x), int(player_foot.y)]
		menu.show()
		model.update_movement(Vector2.ZERO, 0)

func close_menu() -> void:
	menu.hide()
	menu_button.release_focus()

func remaining_resources(id: String) -> Dictionary:
	var counts: Dictionary = {}
	if not states.has(id):
		return counts
	for item: String in Catalog.REGIONS[id].resources:
		counts[item] = 0
	for pickup: Dictionary in states[id].pickups:
		counts[pickup.item] = int(counts.get(pickup.item, 0)) + 1
	return counts

func enter_region(id: String, via_gate: bool = false) -> void:
	if not states.has(id) or finished:
		return
	if equipment != null:
		equipment.effects.clear_transients()
	var previous := region
	if world_canvas.size != Vector2.ZERO:
		states[region].foot = player_foot
	region = id
	for enemy: Dictionary in states[id].enemies: enemy["attack_fx"] = 0.0
	tools.region = id
	var chests := get_node_or_null("Chests")
	if chests != null:
		chests.enter_region()
	var bosses := get_node_or_null("Bosses")
	if bosses != null:
		bosses.enter_region()
	var traps := get_node_or_null("Traps")
	if traps != null and traps.initialized:
		traps.enter_region(id)
	player_foot = states[id].foot
	if via_gate:
		player_foot = Maps.arrival_point(id, previous)
	world_canvas.size = Maps.MAPS[id].size
	model.position = player_foot
	model.update_movement(Vector2.ZERO, 0)
	projectiles.clear()
	effects.clear()
	hurt_timer = maxf(hurt_timer, 1.0)
	_update_camera()
	_refresh_ui()
	world_canvas.queue_redraw()
	queue_redraw()

func restart() -> void:
	GameManager.goto_scene("fudi")

func resume_exploration() -> void:
	finished = false
	outcome.hide()
	hurt_timer = maxf(hurt_timer, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if menu.visible:
			if key == KEY_ESCAPE:
				close_menu()
			get_viewport().set_input_as_handled()
			return
		if dialogue.visible:
			if key in [KEY_E, KEY_ESCAPE]:
				dialogue.hide()
			get_viewport().set_input_as_handled()
			return
		if journal.visible:
			if key in [KEY_B, KEY_ESCAPE]:
				journal.hide()
			get_viewport().set_input_as_handled()
			return
		if tools.is_open() or finished:
			return
		if key == KEY_ESCAPE and not _paused():
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif key == KEY_B:
			open_journal()
			get_viewport().set_input_as_handled()
		elif key == KEY_E:
			interact()
			get_viewport().set_input_as_handled()
		var actions := {KEY_J: "j", KEY_K: "k", KEY_L: "l"}
		if actions.has(key):
			attack(actions[key])
			get_viewport().set_input_as_handled()

func attack(kind: String) -> bool:
	if not ATTACKS.has(kind) or finished or _paused() or float(cooldowns[kind]) > 0:
		return false
	var config: Dictionary = ATTACKS[kind]
	sound_requested.emit({"j": "slash", "k": "cast", "l": "slam"}[kind])
	cooldowns[kind] = config.cooldown * (equipment.effects.cooldown_scale() if equipment != null else 1.0)
	if buildings != null:
		cooldowns[kind] *= buildings.multiplier("cooldown")
	var radius := float(config.radius)
	if equipment != null:
		radius = equipment.effects.attack_radius(kind, radius)
	var origin := player_foot - Vector2(0, 30)
	# Swing art is keyed by the equipped weapon id; the arc stays as the range readout.
	var swing: String = ""
	if equipment != null:
		swing = str(equipment.effects.weapon()).split("-")[0]
	if kind == "k":
		var angles: Array = [-0.18, 0.0, 0.18] if equipment != null and equipment.effects.weapon() == "w03-prism-saber" else [0.0]
		for angle: float in angles:
			projectiles.append({"position": origin + facing * 30, "velocity": facing.rotated(angle) * 620, "life": 0.85})
		effects.append({"position": origin, "radius": radius, "life": PixelVFX.LIFETIME, "kind": kind, "facing": facing, "swing": swing})
	else:
		for enemy: Dictionary in combat_targets():
			var offset: Vector2 = enemy.position - player_foot
			if offset.length() <= radius and (kind == "l" or offset.length() < 25 or offset.normalized().dot(facing) >= 0.15):
				_damage(enemy, int(config.damage), kind)
		effects.append({"position": origin, "radius": radius, "life": PixelVFX.LIFETIME, "kind": kind, "facing": facing, "swing": swing})
	if equipment != null:
		equipment.effects.after_attack(kind, radius)
	_remove_dead()
	_refresh_ui()
	world_canvas.queue_redraw()
	return true

func _damage(enemy: Dictionary, amount: int, kind: String = "") -> void:
	if int(enemy.hp) <= 0:
		return
	if equipment != null:
		amount += int(equipment.bonuses().attack)
		amount = equipment.effects.direct_damage(enemy, amount, kind)
	if buildings != null:
		amount = ceili(amount * buildings.multiplier("attack"))
	enemy.hp = maxi(0, int(enemy.hp) - amount)
	sound_requested.emit("hit")
	enemy.flash = 0.14
	if equipment != null:
		equipment.effects.after_hit(enemy, kind)

func incoming_damage(amount: int) -> int:
	if buildings != null:
		amount = maxi(1, ceili(amount * buildings.multiplier("incoming")))
	return equipment.effects.incoming_damage(amount) if equipment != null else maxi(1, amount)

func _remove_dead() -> void:
	var enemies: Array = states[region].enemies
	for i in range(enemies.size() - 1, -1, -1):
		if int(enemies[i].hp) <= 0:
			var item := Loot.roll_monster(region, loot_rng)
			if not item.is_empty():
				_spawn_equipment(region, item, enemies[i].position, "monster_drop")
				if enemies[i].has("drop"):
					states[region].pickups.append({"item": enemies[i].drop, "position": enemies[i].position, "monster_drop": true})
			enemies.remove_at(i)
	var remaining := 0
	for id: String in states:
		remaining += states[id].enemies.size()
	var bosses := get_node_or_null("Bosses")
	if bosses != null:
		bosses.collect_defeated()
		for id: String in bosses.bosses:
			var boss: Dictionary = bosses.bosses[id]
			if int(boss.hp) <= 0 and not boss.get("equipment_paid", false):
				var item := Loot.roll_boss(id, loot_rng)
				if not item.is_empty():
					var destination: String = bosses.Catalog.DEFINITIONS[id].region
					_spawn_equipment(destination, item, boss.position, "boss_drop")
				boss["equipment_paid"] = true
		remaining += bosses.remaining()
	var chests := get_node_or_null("Chests")
	if chests != null:
		chests.collect_defeated()
		remaining += chests.remaining()
	if remaining == 0 and not round_cleared:
		round_cleared = true
		_end_round(true)

func _spawn_equipment(id: String, item: String, origin: Vector2, source: String) -> void:
	var point := origin
	for offset: Vector2 in [Vector2(-64, 0), Vector2(64, 0), Vector2(0, 64), Vector2(0, -64)]:
		if Maps.walkable(id, origin + offset, 28):
			point = origin + offset
			break
	var pickup := {"item": item, "position": point}
	pickup[source] = true
	states[id].pickups.append(pickup)

func _collect_nearby() -> void:
	var pickups: Array = states[region].pickups
	for i in range(pickups.size() - 1, -1, -1):
		if player_foot.distance_to(pickups[i].position) <= 32:
			inventory[pickups[i].item] += 1
			sound_requested.emit("pickup")
			pickups.remove_at(i)

func _process(delta: float) -> void:
	if _paused() or finished:
		model.update_movement(Vector2.ZERO, 0)
		return
	if equipment != null:
		equipment.effects.tick(delta)
		if finished:
			return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var previous := player_foot
	var traps := get_node_or_null("Traps")
	var movement_scale: float = traps.movement_scale() if traps != null and traps.initialized else 1.0
	var move_speed := SPEED + (float(equipment.bonuses().speed) if equipment != null else 0.0)
	if buildings != null:
		move_speed *= buildings.multiplier("speed")
	move_speed *= gm.speed_multiplier() if gm != null else 1.0
	player_foot = move_world(player_foot, direction * move_speed * movement_scale * minf(delta, 0.1))
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
		enemy["attack_fx"] = maxf(0,float(enemy.get("attack_fx",0.0))-delta)
		var offset: Vector2 = player_foot - enemy.position
		if offset.length() > 32 and offset.length() < 380:
			var slow: float = equipment.effects.enemy_speed_scale(enemy) if equipment != null else 1.0
			enemy.position = move_world(enemy.position, offset.normalized() * minf(float(enemy.get("speed", 76.0)) * slow * delta, offset.length() - 32))
		elif offset.length() <= 32 and hurt_timer <= 0:
			health = maxi(0, health - incoming_damage(int(enemy.get("damage", 10))))
			hurt_timer = 1.0
			enemy["attack_fx"] = PixelVFX.LIFETIME
			enemy["attack_weather"] = enemy.get("weather","clear")
			enemy["attack_point"] = player_foot
	_tick_projectiles(delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if float(effects[i].life) <= 0:
			effects.remove_at(i)
	_collect_nearby()
	if health <= 0:
		_end_round(false)
	_refresh_ui()
	_update_camera()
	world_canvas.queue_redraw()

func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var start: Vector2 = shot.position
		shot.position += shot.velocity * delta
		shot.life -= delta
		# Sweep the whole segment so fast shots cannot cross an obstacle between frames.
		var blocked := false
		for sample in range(1, maxi(1, ceili(start.distance_to(shot.position) / 12.0)) + 1):
			var count := maxi(1, ceili(start.distance_to(shot.position) / 12.0))
			if not Maps.walkable(region, start.lerp(shot.position, float(sample) / count), 0):
				shot.position = start.lerp(shot.position, float(sample - 1) / count)
				blocked = true
				break
		var hit: Dictionary = {}
		var nearest := INF
		for enemy: Dictionary in combat_targets():
			var center: Vector2 = enemy.position - Vector2(0, float(enemy.get("hit_height", 30)))
			var closest := Geometry2D.get_closest_point_to_segment(center, start, shot.position)
			if int(enemy.hp) > 0 and center.distance_to(closest) <= float(enemy.get("hit_radius", 28)) and start.distance_to(closest) < nearest:
				hit = enemy
				nearest = start.distance_to(closest)
		if not hit.is_empty():
			_damage(hit, int(ATTACKS.k.damage), "k")
			shot.life = 0.0
		if blocked or float(shot.life) <= 0 or not Maps.walkable(region, shot.position, 0):
			projectiles.remove_at(i)
	_remove_dead()

func _end_round(won: bool) -> void:
	sound_requested.emit("victory" if won else "defeat")
	finished = true
	result.text = "十域已肃清 · 战斗目标完成\n采集 %d 份，可继续寻找人物线索。" % _inventory_total() if won else "本轮探索结束\n采集物品 %d 份，重开后再试一次。" % _inventory_total()
	continue_button.visible = won
	outcome.show()

func _inventory_total() -> int:
	var count := 0
	for amount: int in inventory.values():
		count += amount
	return count

func _refresh_ui() -> void:
	status.text = Catalog.REGIONS[region].name
	health_label.text = "生命 %d / 100" % health
	health_bar.value = health
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("#e78f82") if health <= 30 else Color("#9bceb2")
	var parts: Array[String] = []
	for key: String in cooldowns:
		parts.append("%s %s" % [key.to_upper(), ATTACKS[key].name if float(cooldowns[key]) <= 0 else "%.1fs" % cooldowns[key]])
	skills.text = "   ·   ".join(parts)
	var target := interaction_target()
	var next: int = states[region].visited.find(false)
	bag.text = "%s · %s" % [Maps.MAPS[region].npc, "本地见闻已齐" if next < 0 else "寻找" + str(Maps.MAPS[region].sites[next][0])]
	hint.text = "E  " + str(target.name) if not target.is_empty() else "WASD 移动 · 循路探索"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0d1c26"))

func _draw_world() -> void:
	if not states.has(region):
		return
	var canvas := world_canvas
	Landscape.paint(canvas, region, visible_world())
	var font := ThemeDB.fallback_font
	var data: Dictionary = Maps.MAPS[region]
	for i in range(data.sites.size()):
		var site: Array = data.sites[i]
		var point: Vector2 = site[1] * data.size
		Landscape.landmark(canvas, point, site[3], Color(data.accent), Maps.Art.has_art(region))
		canvas.draw_string(font, point + Vector2(-76, 44), str(site[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(data.accent))
		canvas.draw_string(font, point + Vector2(-65, 68), "已记录" if states[region].visited[i] else "靠近按 E 调查", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#c4d3c9"))
	var rest: Vector2 = data.spawn * data.size
	canvas.draw_circle(rest, 38, Color("#68c7c0", 0.3))
	canvas.draw_arc(rest, 38, 0, TAU, 36, Color("#a4ded2"), 3, true)
	canvas.draw_string(font, rest + Vector2(-72, 60), "休息点 · E 恢复一次", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#b1e6d9"))
	for exit: Array in data.exits:
		var point: Vector2 = exit[1] * data.size
		canvas.draw_arc(point - Vector2(0, 35), 42, 0, TAU, 32, Color("#88cce3"), 5, true)
		canvas.draw_string(font, point + Vector2(-70, 36), "E → " + str(Catalog.REGIONS[exit[0]].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#a2d8e4"))
	for pickup: Dictionary in states[region].pickups:
		if pickup.get("weather_growth", false):
			continue # Renewable plants are drawn by the weather module with growth rings.
		var info: Dictionary = Catalog.ITEMS[pickup.item]
		var color := Color(info.color)
		var icon: Texture2D = info.get("icon")
		canvas.draw_circle(pickup.position, 19, Color(color, 0.16))
		if icon != null:
			canvas.draw_arc(pickup.position, 24, 0, TAU, 32, color, 2, true)
			canvas.draw_texture_rect(icon, Rect2(pickup.position - Vector2(24, 26), Vector2(48, 48)), false)
		else:
			canvas.draw_circle(pickup.position, 7, color)
		canvas.draw_string(font, pickup.position + Vector2(-18, 35), info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	for enemy: Dictionary in states[region].enemies:
		var point: Vector2 = enemy.position
		canvas.draw_set_transform(point, 0, Vector2(1, 0.30))
		canvas.draw_circle(Vector2.ZERO, 29, Color(0.02, 0.04, 0.05, 0.45))
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_texture_rect(ENEMY_ART, Rect2(point - Vector2(38, 76), Vector2(76, 76)), false, Color("#ffbca0") if float(enemy.flash) > 0 else Color(enemy.get("tint", Color.WHITE)))
		canvas.draw_rect(Rect2(point - Vector2(28, 84), Vector2(56, 5)), Color("#18212b"))
		canvas.draw_rect(Rect2(point - Vector2(28, 84), Vector2(56 * float(enemy.hp) / float(enemy.get("max_hp", 60)), 5)), Color("#dc947e"))
		if float(enemy.get("attack_fx",0.0)) > 0:
			PixelVFX.draw(canvas,"guard-"+str(enemy.get("attack_weather","clear")),enemy.get("attack_point",point),PixelVFX.LIFETIME-float(enemy.attack_fx),Vector2.ONE*2)
	var origin := player_foot - Vector2(0, 30)
	canvas.draw_line(origin + facing * 26, origin + facing * 48, Color("#f5d69b"), 3, true)
	for shot: Dictionary in projectiles:
		canvas.draw_circle(shot.position, 10, Color("#9ceafa"))
		canvas.draw_circle(shot.position, 4, Color.WHITE)
	for effect: Dictionary in effects:
		var color := Color("#b9a0f5") if effect.kind == "l" else Color("#ffe6ab")
		color.a = clampf(float(effect.life) / 0.22, 0, 1)
		var angle: float = effect.facing.angle()
		canvas.draw_arc(effect.position, float(effect.radius), 0 if effect.kind == "l" else angle - 1.4, TAU if effect.kind == "l" else angle + 1.4, 48, color, 7, true)
		var swing: String = str(effect.get("swing", ""))
		if swing != "" and PixelVFX.exists("player-" + swing):
			PixelVFX.draw(canvas, "player-" + swing, effect.position + effect.facing * 30, PixelVFX.LIFETIME - float(effect.life), Vector2.ONE * 2, angle, Color(1, 1, 1, 0.9))

func _paused() -> bool:
	return menu.visible or get_meta("audio_settings_open", false) or get_meta("fudi_gm_open", false) or tools.is_open() or dialogue.visible or journal.visible or (equipment != null and equipment.is_open())

func move_world(origin: Vector2, displacement: Vector2) -> Vector2:
	var point := origin
	var steps := maxi(1, ceili(displacement.length() / 12.0))
	var step := displacement / steps
	for i in range(steps):
		var horizontal := point + Vector2(step.x, 0)
		if Maps.walkable(region, horizontal):
			point.x = horizontal.x
		var vertical := point + Vector2(0, step.y)
		if Maps.walkable(region, vertical):
			point.y = vertical.y
	return point

func _update_camera() -> void:
	# Leave headroom for tall boss silhouettes and their health bars.
	var headroom := buildings.camera_height() if buildings != null else 0.65
	camera_origin = (player_foot - VIEW_SIZE * Vector2(0.5, headroom)).clamp(Vector2.ZERO, Maps.MAPS[region].size - VIEW_SIZE)
	world_canvas.position = -camera_origin * WORLD_ZOOM
	minimap.queue_redraw()

func interaction_target() -> Dictionary:
	var data: Dictionary = Maps.MAPS[region]
	if npcs != null:
		var nearest_npc: Dictionary = npcs.interaction_target()
		if not nearest_npc.is_empty():
			var npc_distance: float = player_foot.distance_to(npcs.position_of(nearest_npc.npc_id))
			var landmark_distance: float = player_foot.distance_to(data.spawn * data.size)
			for site: Array in data.sites:
				landmark_distance = minf(landmark_distance, player_foot.distance_to(site[1] * data.size))
			for gate: Array in data.exits:
				landmark_distance = minf(landmark_distance, player_foot.distance_to(gate[1] * data.size))
			if npc_distance < landmark_distance: return nearest_npc
	for i in range(data.sites.size()):
		if player_foot.distance_to(Maps.site_position(region, i)) <= 100:
			return {"kind": "site", "index": i, "name": str(data.sites[i][0]) + " · " + str(data.npc)}
	if player_foot.distance_to(data.spawn * data.size) < 95:
		return {"kind": "rest", "name": "休息点（本地每轮一次）"}
	for exit: Array in data.exits:
		if player_foot.distance_to(exit[1] * data.size) <= 120:
			return {"kind": "exit", "destination": exit[0], "name": "前往" + str(Catalog.REGIONS[exit[0]].name)}
	if npcs != null:
		var npc_target: Dictionary = npcs.interaction_target()
		if not npc_target.is_empty(): return npc_target
	var chests := get_node_or_null("Chests")
	if chests != null:
		return chests.interaction_target()
	return {}

func interact() -> void:
	if finished or _paused():
		return
	var target := interaction_target()
	if target.is_empty():
		return
	if target.kind in ["site", "rest"]:
		sound_requested.emit("discovery")
	var data: Dictionary = Maps.MAPS[region]
	match target.kind:
		"npc":
			npcs.talk(target.npc_id)
			npc_exchange.present(target.npc_id)
			return
		"chest":
			get_node("Chests").interact(target.chest)
			return
		"exit":
			enter_region(target.destination, true)
			return
		"rest":
			if states[region].rested:
				dialogue_text.text = "这里的恢复物资已经用过。继续探索，其他区域也有休息点。"
			elif health >= 100:
				dialogue_text.text = "生命充足，恢复物资留在这里。需要时再回来休息。"
			else:
				health = 100
				states[region].rested = true
				dialogue_text.text = "拾一已确认周围安全。生命恢复至 100；这个休息点本轮不再补充物资。"
		"site":
			var index: int = target.index
			if index > 0 and not states[region].visited[index - 1]:
				dialogue_text.text = "线索尚缺一段。先前往“%s”调查，再回来看这里的记录。" % data.sites[index - 1][0]
			else:
				states[region].visited[index] = true
				dialogue_text.text = "%s · %s\n%s\n\n%s" % [data.npc, data.chapter, data.sites[index][2], "十域人物见闻已收齐。后续复苏与调查的故事仍待继续。" if _visited_total() == Maps.site_total() else "已记入见闻。B 可回看。"]
	dialogue.show()
	model.update_movement(Vector2.ZERO, 0)
	_refresh_ui()
	world_canvas.queue_redraw()

func _visited_total() -> int:
	var count := 0
	for state: Dictionary in states.values():
		for visited: bool in state.visited:
			if visited:
				count += 1
	return count

func open_journal() -> void:
	journal_text.bbcode_enabled = true
	var lines: Array[String] = ["行囊与见闻  ·  本轮收集 %d 份  ·  人物线索 %d / %d" % [_inventory_total(), _visited_total(), Maps.site_total()], "C 打开人物装备，可穿戴、替换与卸下；装备数量包含已穿戴物品，本轮有效。"]
	lines.append("\n此地已读见闻 · " + str(Catalog.REGIONS[region].name))
	var local_data: Dictionary = Maps.MAPS[region]
	var has_local_record := false
	for i in range(local_data.sites.size()):
		if states[region].visited[i]:
			has_local_record = true
			lines.append("%s：%s" % [local_data.sites[i][0], local_data.sites[i][2]])
	if not has_local_record: lines.append("还没有调查记录；靠近地标按 E。")
	if npcs != null: lines.append_array(npcs.journal_lines())
	lines.append("\n行囊与规则")
	for item: String in Loot.ITEMS:
		if int(inventory.get(item, 0)) > 0:
			lines.append("[img=44x44]%s[/img]  %s × %d" % [Loot.ITEMS[item].icon.resource_path, Loot.ITEMS[item].name, inventory[item]])
	for item: String in inventory:
		if inventory[item] > 0 and not Loot.ITEMS.has(item):
			var info: Dictionary = Catalog.ITEMS[item]
			if info.has("icon"):
				lines.append("[img=44x44]%s[/img]  %s × %d" % [info.icon.resource_path, info.name, inventory[item]])
			else:
				lines.append("%s × %d" % [info.name, inventory[item]])
	var chests := get_node_or_null("Chests")
	if chests != null:
		lines.append("\n宝箱 · 金色方块为普通箱，紫色方块为异变箱；靠近按E开启。")
		for id: String in Maps.IDS:
			lines.append("%s：%s" % [Catalog.REGIONS[id].name, chests.summary(id)])
	lines.append("\n掉落规则 · 小怪35%掉落装备，Boss必掉1件；靠近光圈自动拾取。")
	for id: String in Maps.IDS:
		lines.append("%s：%s" % [Catalog.REGIONS[id].name, Loot.REGIONS[id].name])
	for id: String in Loot.BOSSES:
		var config: Dictionary = Loot.BOSSES[id]
		var choices: Array[String] = []
		for item: String in Loot.pool(config):
			choices.append(Loot.ITEMS[item].name)
		lines.append("%s必掉1件（等概率）：%s" % [Bosses.Catalog.DEFINITIONS[id].name, "、".join(choices)])
	var traps := get_node_or_null("Traps")
	if traps != null and traps.initialized:
		lines.append("\n环境陷阱 · 黄圈预警后爆发，可用WASD闪避；地图、对话、行囊与结算时暂停。")
		for id: String in Maps.IDS:
			lines.append("\n%s：%s" % [Catalog.REGIONS[id].name, traps.summary(id)])
	var weather := get_node_or_null("Weather")
	if weather != null and weather.initialized:
		lines.append("\n天气与生态 · 每75秒轮换；适生药圃18–28秒成熟，可反复采集。")
		for id: String in Maps.IDS:
			lines.append("\n%s：%s" % [Catalog.REGIONS[id].name, weather.summary(id)])
			for item: String in weather.Ecology.CLIMATES[id].plants:
				lines.append("%s · 适生%s · %.0f秒成熟" % [Catalog.ITEMS[item].name, weather.Ecology.weather_names(weather.Ecology.PLANTS[item].weather), weather.Ecology.PLANTS[item].time])
	var bosses := get_node_or_null("Bosses")
	if bosses != null:
		lines.append("\n首领 · 小地图红菱形；预警圈锁定后可走出躲避。")
		for id: String in Maps.IDS:
			lines.append("%s：%s" % [Catalog.REGIONS[id].name, bosses.summary(id)])
	for id: String in Maps.IDS:
		var data: Dictionary = Maps.MAPS[id]
		lines.append("\n%s · %s" % [data.npc, data.chapter])
		for i in range(data.sites.size()):
			lines.append("%s：%s" % [data.sites[i][0], data.sites[i][2] if states[id].visited[i] else "尚未调查"])
	journal_text.text = "\n".join(lines)
	if buildings != null:
		journal_text.text += "\n\n大型建筑 · 绿光增益 / 紫光减益；入口光圈触发60秒，同类替换。\n" + buildings.status_text()
		for id: String in Maps.IDS:
			journal_text.text += "\n" + Catalog.REGIONS[id].name + "：" + buildings.summary(id)
	journal_text.scroll_to_line(0)
	journal.show()
	model.update_movement(Vector2.ZERO, 0)

func _draw_minimap() -> void:
	if not states.has(region):
		return
	var rect := Rect2(Vector2(10, 30), minimap.size - Vector2(20, 40))
	var extent: Vector2 = Maps.MAPS[region].size
	minimap.draw_style_box(UI.panel(Color(0.03, 0.08, 0.1, 0.93)), Rect2(Vector2.ZERO, minimap.size))
	minimap.draw_string(ThemeDB.fallback_font, Vector2(12, 22), "%s  %d × %d" % [Catalog.REGIONS[region].name, int(extent.x), int(extent.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e7d4a8"))
	if Maps.Art.has_art(region):
		minimap.draw_texture_rect(Maps.Art.TEXTURES[region], rect, false, Color(0.8, 0.8, 0.8))
	for road: Array in Maps.MAPS[region].roads:
		var points := PackedVector2Array()
		for point: Vector2 in road:
			points.append(rect.position + point * rect.size)
		minimap.draw_polyline(points, Color("#7f927d"), 2, true)
	if not Maps.Art.has_art(region):
		for obstacle: Rect2 in Maps.obstacles(region):
			minimap.draw_rect(Rect2(rect.position + obstacle.position / extent * rect.size, obstacle.size / extent * rect.size), Color("#63716b"))
	for i in range(3):
		var point := rect.position + Maps.site_position(region, i) / extent * rect.size
		var color := Color("#9ecab7") if states[region].visited[i] else Color("#f1d291")
		minimap.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0)]), color)
	for exit: Array in Maps.MAPS[region].exits:
		minimap.draw_arc(rect.position + exit[1] * rect.size, 5, 0, TAU, 12, Color("#8ed6ec"), 2, true)
	for pickup: Dictionary in states[region].pickups:
		minimap.draw_circle(rect.position + pickup.position / extent * rect.size, 1.5, Color("#9db88c", 0.65))
	minimap.draw_rect(Rect2(rect.position + camera_origin / extent * rect.size, VIEW_SIZE / extent * rect.size), Color("#d4e7d2"), false)
	minimap.draw_circle(rect.position + player_foot / extent * rect.size, 4, Color.WHITE)
