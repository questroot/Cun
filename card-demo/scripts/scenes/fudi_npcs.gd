extends Node
## Nine authored residents and one unique road-bound traveller. Round-local task state.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Regions = preload("res://scripts/scenes/exploration_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const CELL := 48
const SPEED := 70.0
const TALK_RADIUS := 90.0
const DEFINITIONS := {
	"lu-yan": {"name":"路盐", "region":"causeway", "site":0, "tone":"blue", "quest":"这趟不能空车", "intro":"旧路还能走，地址就不能丢。替我核对驿亭与邮局的留言，给未送达的货物找一个能被认领的去处。", "done":"寄存路线记下了。下一趟，车上给代送物品留一个位置。", "needs":[["causeway",0],["post",2]]},
	"jin-suanpan": {"name":"金算盘", "region":"post", "site":2, "tone":"yellow", "quest":"没有标价的东西", "intro":"寄存物不能直接视为无主货物。请核对收信巷与留言墙，先确认还有谁在寻找。", "done":"已补录认领线索。此批寄存物继续保管，不列入出售。", "needs":[["post",1],["post",2]]},
	"shen-heng": {"name":"沈衡", "region":"refuge", "site":0, "tone":"red", "quest":"谁先用上这条路", "intro":"先弄清救援营缺什么，再安排运输。请核对营地与中继塔的登记，把可核实的需求带回来。", "done":"调度依据已留档。救援运力单列，谁都能来查安排的理由。", "needs":[["refuge",0],["refuge",1]]},
	"luo-zhu": {"name":"洛铸", "region":"kilnwood", "site":1, "tone":"yellow", "quest":"锤子先落在哪里", "intro":"工具先给救援用。去旧炭窑与修复工坊核对材料和承重记录，再谈该怎么下锤。", "done":"这份记录够清楚。先做支撑，再开通道，旁边的人得站稳。", "needs":[["kilnwood",1],["quarry",0]]},
	"ye-ting": {"name":"叶汀", "region":"grove", "site":1, "tone":"yellow", "quest":"三次好转之后", "intro":"好转不等于石化已经解除。请看过街坊药圃与旧渠药棚的记录，替照护区核对药草和饮食安排。", "done":"饮食、药物与陪护各有记录。我们先照顾醒来的人，不把缓解症状说成复苏。", "needs":[["grove",1],["wetland",0]]},
	"qiao-huang": {"name":"乔簧", "region":"ruins", "site":1, "tone":"yellow", "quest":"多出来的零件", "intro":"先别急着给我换零件！去接入台与维护备份库核对原始记录，修好的设备也要让后来的人接着修。", "done":"重复部件记清楚了。能安全工作的结构，比所谓唯一的原装答案要紧。", "needs":[["ruins",0],["ruins",1]]},
	"cen-chi": {"name":"岑尺", "region":"snowridge", "site":2, "tone":"blue", "quest":"地图之外的一条街", "intro":"旧图不能替代今天的测量。核对霜脊信标与望远台，把返程路线和仍待确认的位置一起带回来。", "done":"图上没有的，已经补上。未确认的地方继续留白，不把未知画成安全。", "needs":[["snowridge",1],["snowridge",2]]},
	"xie-tingzhou": {"name":"谢停舟", "region":"wetland", "site":1, "tone":"red", "quest":"醒来之前，请先敲门", "intro":"我替他们留灯，不能替他们回答。请核对雨灯渡口与避雨长亭的留言，把等候的人与留下的话一同记住。", "done":"姓名与留言都留好了。下一次商量复苏时，让这些声音也能被听见。", "needs":[["wetland",1],["wetland",2]]},
	"wen-zhou": {"name":"闻昼", "region":"archive", "site":0, "tone":"red", "quest":"神谕的三个版本", "intro":"一句话从哪里来，比谁说得更响更要紧。去索引台与署名校验室核对版本，别把缺页用推测补齐。", "done":"异文分别存档。眼前的决定，不能交给一份来源不明的抄本。", "needs":[["archive",0],["archive",2]]},
	"changdaozhe": {"name":"长祷者", "region":"", "site":0, "tone":"blue", "quest":"有人回答了我", "intro":"我听见许多声音。请核对渡口的留灯与档案馆的异本，分清哪些是记忆，哪些仍需查证。", "done":"这些声音可以并存。未查明的，我会说还不知道。", "needs":[["wetland",1],["archive",1]]},
}
var game
var rng := RandomNumberGenerator.new()
var actors: Dictionary = {}
var tasks: Dictionary = {}
var grids: Dictionary = {}
var wander_region := ""
var wander_foot := Vector2.ZERO
var wander_route := PackedVector2Array()
var wander_exit := ""
var wander_gate := Vector2.ZERO
var wander_wait := 3.0
var visited_regions: Array[String] = []
var clock := 0.0
static var fixed_positions: Dictionary = {}

static func fixed_position(id: String) -> Vector2:
	if fixed_positions.has(id): return fixed_positions[id]
	var config: Dictionary = DEFINITIONS[id]
	var map_id: String = config.region
	var origin := Maps.site_position(map_id, int(config.site))
	# Offset from the existing investigation radius; stay on its visible road.
	for radius: float in [176.0, 208.0, 256.0, 304.0]:
		for i in range(24):
			var point := origin + Vector2.from_angle(TAU * i / 24.0) * radius
			if not Maps.walkable(map_id, point, 32): continue
			var clear := true
			for site: Array in Maps.MAPS[map_id].sites:
				if point.distance_to(site[1] * Maps.MAPS[map_id].size) < 160: clear = false
			if point.distance_to(Maps.MAPS[map_id].spawn * Maps.MAPS[map_id].size) < 165: clear = false
			for gate: Array in Maps.MAPS[map_id].exits:
				if point.distance_to(gate[1] * Maps.MAPS[map_id].size) < 190: clear = false
			if clear:
				fixed_positions[id] = point
				return point
	push_error("No safe NPC placement for " + id)
	return origin

static func reserved(map_id: String, point: Vector2) -> bool:
	for id: String in DEFINITIONS:
		if DEFINITIONS[id].region == map_id and point.distance_to(fixed_position(id)) < 230:
			return true
	return false

func _ready() -> void:
	game = get_parent()
	rng.randomize()
	for id: String in DEFINITIONS:
		tasks[id] = "available"
		var actor := Node2D.new()
		actor.name = id.replace("-", "_")
		actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sprite := Sprite2D.new()
		sprite.name = "Body"
		sprite.texture = load("res://assets/characters/npcs/%s.png" % id)
		sprite.centered = false
		sprite.position = Vector2(-48, -122)
		sprite.scale = Vector2(2, 2)
		actor.add_child(sprite)
		var marker := Sprite2D.new()
		marker.name = "QuestMarker"
		marker.position = Vector2(0, -155)
		marker.scale = Vector2(2, 2)
		actor.add_child(marker)
		var label := Label.new()
		label.name = "NameLabel"
		label.text = DEFINITIONS[id].name
		label.position = Vector2(-90, 5)
		label.size = Vector2(180, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color("#fff1cc"))
		label.add_theme_color_override("font_outline_color", Color("#19232d"))
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actor.add_child(label)
		game.world_canvas.add_child(actor)
		actors[id] = actor
	wander_region = Maps.IDS[rng.randi_range(0, Maps.IDS.size() - 1)]
	wander_foot = _grid_point(wander_region, Maps.MAPS[wander_region].spawn * Maps.MAPS[wander_region].size)
	visited_regions.append(wander_region)
	game.minimap.draw.connect(draw_minimap)
	refresh()

func task_state(id: String) -> String:
	if tasks[id] != "active": return tasks[id]
	for need: Array in DEFINITIONS[id].needs:
		if not game.states[need[0]].visited[int(need[1])]: return "active"
	return "ready"

func marker_kind(id: String) -> String:
	return "exclamation" if task_state(id) == "available" else "question"

func _process(delta: float) -> void:
	if game.is_processing(): tick(delta)
	refresh()

func tick(delta: float) -> void:
	if delta <= 0 or game._paused() or game.finished: return
	clock += minf(delta, 0.1)
	# Stop beside the player so E can reliably start a conversation.
	if game.region == wander_region and game.player_foot.distance_to(wander_foot) < 130: return
	var budget := SPEED * minf(delta, 0.1)
	if wander_wait > 0:
		wander_wait = maxf(0, wander_wait - minf(delta, 0.1))
		return
	if wander_route.is_empty():
		if not wander_exit.is_empty():
			_cross_border()
		else:
			plan_route()
		return
	while budget > 0 and not wander_route.is_empty():
		var target: Vector2 = wander_route[0]
		var step := minf(budget, minf(10.0, wander_foot.distance_to(target)))
		var next := wander_foot.move_toward(target, step)
		if not Maps.walkable(wander_region, next, 20):
			wander_route.clear()
			wander_exit = ""
			wander_wait = 1.0
			return
		wander_foot = next
		budget -= step
		if wander_foot.distance_to(target) < 0.01: wander_route.remove_at(0)
		if step <= 0: break

func _grid(map_id: String) -> AStarGrid2D:
	if grids.has(map_id): return grids[map_id]
	var extent: Vector2 = Maps.MAPS[map_id].size
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(extent.x / CELL), ceili(extent.y / CELL)))
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL / 2.0, CELL / 2.0)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(grid.region.size.x):
		for y in range(grid.region.size.y):
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not Maps.walkable(map_id, grid.get_point_position(cell), 40))
	grids[map_id] = grid
	return grid

func _cell(map_id: String, point: Vector2) -> Vector2i:
	var grid := _grid(map_id)
	var center := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
	var best := center
	var distance := INF
	for x in range(center.x - 8, center.x + 9):
		for y in range(center.y - 8, center.y + 9):
			var cell := Vector2i(x, y)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
			var d := grid.get_point_position(cell).distance_squared_to(point)
			if d < distance:
				distance = d
				best = cell
	return best

func _grid_point(map_id: String, point: Vector2) -> Vector2:
	return _grid(map_id).get_point_position(_cell(map_id, point))

func plan_route() -> bool:
	var gates: Array = Maps.MAPS[wander_region].exits.duplicate()
	# Random among as-yet unvisited neighbouring maps, then ordinary random travel.
	var fresh: Array = []
	for gate: Array in gates:
		if not visited_regions.has(str(gate[0])): fresh.append(gate)
	if not fresh.is_empty(): gates = fresh
	var offset := rng.randi_range(0, gates.size() - 1)
	for i in range(gates.size()):
		var gate: Array = gates[(offset + i) % gates.size()]
		var goal: Vector2 = gate[1] * Maps.MAPS[wander_region].size
		var grid := _grid(wander_region)
		var path := grid.get_point_path(_cell(wander_region, wander_foot), _cell(wander_region, goal))
		if path.is_empty(): continue
		wander_route = path
		wander_gate = goal
		wander_exit = gate[0]
		return true
	wander_wait = 2.0
	return false

func _cross_border() -> void:
	var previous := wander_region
	wander_region = wander_exit
	wander_exit = ""
	var arrival := Maps.arrival_point(wander_region, previous)
	wander_foot = _grid_point(wander_region, arrival)
	if not visited_regions.has(wander_region): visited_regions.append(wander_region)
	wander_wait = rng.randf_range(3, 8)

func region_of(id: String) -> String:
	return wander_region if id == "changdaozhe" else str(DEFINITIONS[id].region)

func position_of(id: String) -> Vector2:
	return wander_foot if id == "changdaozhe" else fixed_position(id)

func refresh() -> void:
	for id: String in actors:
		var actor: Node2D = actors[id]
		actor.visible = region_of(id) == game.region
		if not actor.visible: continue
		actor.position = position_of(id)
		actor.z_index = 3 if actor.position.y >= game.player_foot.y else 1
		var marker: Sprite2D = actor.get_node("QuestMarker")
		var state := task_state(id)
		marker.visible = state != "complete"
		if marker.visible:
			var key := "%s-%s" % [DEFINITIONS[id].tone, marker_kind(id)]
			if marker.get_meta("art_key", "") != key:
				marker.texture = load("res://assets/ui/quest-markers/%s.png" % key)
				marker.set_meta("art_key", key)
			marker.modulate = Color(0.65, 0.65, 0.65, 0.8) if state == "active" else Color.WHITE
			marker.position.y = -155 + floorf(sin(clock * 2.8) * 2)
	game.model.z_index = 2

func interaction_target() -> Dictionary:
	var result := {}
	var nearest := TALK_RADIUS
	for id: String in actors:
		if region_of(id) != game.region: continue
		var distance: float = game.player_foot.distance_to(position_of(id))
		if distance < nearest:
			nearest = distance
			result = {"kind":"npc", "npc_id":id, "name":"与%s交谈" % DEFINITIONS[id].name}
	return result

func talk(id: String) -> void:
	if not DEFINITIONS.has(id): return
	var config: Dictionary = DEFINITIONS[id]
	var state := task_state(id)
	var message: String = config.intro
	if state == "available":
		tasks[id] = "active"
		message = "已接取 · " + message
	elif state == "ready":
		tasks[id] = "complete"
		message = "委托记录已完成 · " + str(config.done)
	elif state == "complete":
		message = config.done
	game.dialogue_text.text = "%s · %s\n%s\n\n%s" % [config.name, config.quest, message, progress_text(id)]
	game.dialogue.show()
	game.sound_requested.emit("discovery")
	game.model.update_movement(Vector2.ZERO, 0)
	refresh()
	game._refresh_ui()

func progress_text(id: String) -> String:
	var parts: Array[String] = []
	for need: Array in DEFINITIONS[id].needs:
		parts.append("%s%s·%s" % ["✓" if game.states[need[0]].visited[int(need[1])] else "○", Regions.REGIONS[need[0]].name, Maps.MAPS[need[0]].sites[int(need[1])][0]])
	return "；".join(parts)

func journal_lines() -> Array[String]:
	var lines: Array[String] = ["\n人物委托 · 红色主线 / 黄色人物 / 蓝色探索；！可接取，暗？进行中，亮？可回报"]
	for id: String in tasks:
		if tasks[id] == "available": continue
		var state := task_state(id)
		lines.append("%s《%s》·%s\n%s" % [DEFINITIONS[id].name, DEFINITIONS[id].quest, {"active":"进行中", "ready":"可回报", "complete":"已完成"}[state], progress_text(id)])
	return lines

func draw_minimap() -> void:
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	for id: String in actors:
		if region_of(id) != game.region: continue
		var point: Vector2 = rect.position + position_of(id) / Maps.MAPS[game.region].size * rect.size
		game.minimap.draw_circle(point, 3, Color("#91c9ed") if id == "changdaozhe" else Color("#f4c65d"))

func play_visible() -> Array:
	var result: Array = []
	if game._paused() or game.finished: return result
	for id: String in actors:
		if region_of(id) != game.region: continue
		var foot: Vector2 = game.world_to_screen(position_of(id))
		var bounds := Rect2(foot - Vector2(48, 175) * game.WORLD_ZOOM, Vector2(96, 200) * game.WORLD_ZOOM)
		# Only fully drawn actors; never expose other maps, routes or unaccepted text.
		if not game.ARENA.encloses(bounds): continue
		var state := task_state(id)
		result.append({"name":DEFINITIONS[id].name, "x":foot.x, "y":foot.y, "kind":"npc", "head_marker":"无" if state == "complete" else "%s色%s%s" % [{"red":"红", "yellow":"黄", "blue":"蓝"}[DEFINITIONS[id].tone], "！" if state == "available" else "？", "（暗）" if state == "active" else ""], "interaction":"靠近按E交谈"})
	return result
