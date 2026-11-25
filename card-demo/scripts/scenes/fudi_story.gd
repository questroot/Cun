extends Node
## One playable local story: preparation, safety, repair and a usable shared stove.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const VFX := preload("res://scripts/scenes/pixel_vfx.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
var game
var state := {"stage": 0, "meals": 0}
var action: Button

func _ready() -> void:
	game = get_parent()
	action = UI.button("", perform)
	action.name = "StoveStoryAction"
	game.dialogue.get_child(0).add_child(action)
	action.hide()
	game.dialogue.visibility_changed.connect(func() -> void:
		if not game.dialogue.visible: action.hide())
	game.world_canvas.draw.connect(draw_world)
	game.minimap.draw.connect(draw_minimap)

func valid_state(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and _count(value.get("stage"), 3) and _count(value.get("meals"), 1000000) and (value.stage == 3 or value.meals == 0)

func _count(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= 0 and value <= maximum

func near_stove() -> bool:
	return game.region == "grove" and game.player_foot.distance_to(Maps.site_position("grove", 0)) <= 100

func safe_street() -> bool:
	return game.states.grove.enemies.is_empty() and int(game.get_node("Bosses").bosses.H02.hp) <= 0

func summary() -> String:
	match int(state.stage):
		0: return "祝婶 · 今天几个人吃饭：到青岚灶街旧灶台听听她的打算。"
		1: return "祝婶 · 备料：核对街坊药圃，带灵草2份、木料2份回旧灶台交付（现有灵草%d、木料%d）。" % [game.inventory.get("herb", 0), game.inventory.get("wood", 0)]
		2: return "祝婶 · 安灶：清除灶街守卫与荆冠鹿骑，调查迁灶落脚点，再回旧灶台帮忙。守卫剩%d，鹿骑%s。" % [game.states.grove.enemies.size(), "已击败" if int(game.get_node("Bosses").bosses.H02.hp) <= 0 else "仍在附近"]
		_: return "祝婶 · 灶火已恢复：已获灵晶3、追归上衣1。旧灶台可消耗灵草1份做热汤，恢复30生命（满血不消耗），已做%d碗。" % state.meals

func present() -> void:
	if not near_stove() or game.finished: return
	game.dialogue_text.text = "祝婶 · 今天几个人吃饭\n" + [
		"“菜单找到了，饭还没法开。药圃的忌口得先核对，灶边也缺木料。你愿意搭把手吗？”",
		"“灵草用来煮汤，木料修灶。先去药圃核对街坊的忌口，备齐后再交给我。”",
		"祝婶把草药收进篮里，木料堆在灶边。“料齐了。等街上的石灵散去，再核对落脚点，我们就能把灶修好。”",
		"灶火重新亮起，桌上摆好了汤碗。“熟客回来，总得有一口热的。灵草还有的话，我再煮一锅。”"
	][int(state.stage)] + "\n\n" + summary()
	action.text = ["答应帮忙，准备灶台", "交付灵草 ×2、木料 ×2", "帮祝婶修灶并摆好餐桌", "煮一碗热汤 · 灵草 ×1，恢复30生命"][int(state.stage)]
	action.disabled = (state.stage == 1 and (not game.states.grove.visited[1] or int(game.inventory.get("herb", 0)) < 2 or int(game.inventory.get("wood", 0)) < 2)) or (state.stage == 2 and (not safe_street() or not game.states.grove.visited[2])) or (state.stage == 3 and (game.health >= 100 or int(game.inventory.get("herb", 0)) < 1))
	action.show()
	game.dialogue.show()

func perform() -> void:
	if not near_stove() or not game.dialogue.visible or game.finished: return
	match int(state.stage):
		0:
			state.stage = 1
		1:
			if not game.states.grove.visited[1] or int(game.inventory.get("herb", 0)) < 2 or int(game.inventory.get("wood", 0)) < 2: return
			game.inventory.herb -= 2
			game.inventory.wood -= 2
			state.stage = 2
		2:
			if not safe_street() or not game.states.grove.visited[2]: return
			state.stage = 3
			game.inventory.crystal = int(game.inventory.get("crystal", 0)) + 3
			game.inventory["s1-top"] = int(game.inventory.get("s1-top", 0)) + 1
		3:
			if game.health >= 100 or int(game.inventory.get("herb", 0)) < 1: return
			game.inventory.herb -= 1
			game.health = mini(100, int(game.health) + 30)
			state.meals += 1
	game.sound_requested.emit("discovery")
	game.persistence.request_save()
	refresh()
	present()
	game._refresh_ui()

func refresh() -> void:
	game.world_canvas.queue_redraw()
	game.minimap.queue_redraw()

func draw_world() -> void:
	if game.region != "grove": return
	var point := Maps.site_position("grove", 0)
	var color := Color("#ffd18a") if state.stage == 3 else Color("#b9dbc0")
	var canvas: Control = game.world_canvas
	VFX.cue_arc(canvas, point, 54.0, 0.0, TAU, 3.0, color)
	canvas.draw_string(ThemeDB.fallback_font, point + Vector2(-100, -66), "祝婶的热汤 · E" if state.stage == 3 else "祝婶的灶台 · E", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	if state.stage == 3:
		VFX.draw(canvas, "stove-flame", point - Vector2(0, 28), game.loot_glint_time * (0.96 / 1.25), Vector2.ONE, 0.0, Color.WHITE, true)
		for x: int in [-40, 40]:
			canvas.draw_circle(point + Vector2(x, 12), 9, Color("#f5e7c9"))
			canvas.draw_arc(point + Vector2(x, 5), 9, PI, TAU, 12, Color("#eeb86b"), 2, true)

func draw_minimap() -> void:
	if game.region != "grove": return
	var rect := Rect2(Vector2(10, 30), game.minimap.size - Vector2(20, 40))
	var point: Vector2 = rect.position + Maps.site_position("grove", 0) / Maps.MAPS.grove.size * rect.size
	game.minimap.draw_circle(point, 5, Color("#ffd18a"))
