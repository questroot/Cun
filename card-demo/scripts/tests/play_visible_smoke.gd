extends SceneTree
## Boundary fixture only: deliberately positions actors/warnings; not real-input gameplay.
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func run_checks() -> void:
	var game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	var bosses = game.get_node("Bosses")
	bosses.set_process(false)
	var id: String = bosses.bosses.keys()[0]
	game.region = bosses.Catalog.DEFINITIONS[id].region
	game.camera_origin = Vector2(9000,9000)
	check(game.play_visible().visible_terrain.is_empty(),"offscreen terrain omitted")
	var terrain_rect: Rect2 = game.Maps.obstacles(game.region)[0]
	game.camera_origin = terrain_rect.position+Vector2(terrain_rect.size.x-20,0)
	var terrain: Array = game.play_visible().visible_terrain
	check(not terrain.is_empty() and terrain[0].visible_bounds.width <= 20.1,"painted terrain clipped at viewport edge")
	game.camera_origin = Vector2.ZERO
	var enemy: Dictionary = game.states[game.region].enemies[0]
	for other: Dictionary in game.states[game.region].enemies: other.position = Vector2(9000,9000)
	enemy.position = Vector2(300,200)
	enemy.hp = 30
	enemy.max_hp = 60
	var guards: Array = game.play_visible().objects.filter(func(t):return t.kind == "enemy")
	check(guards.size()==1 and guards[0].visible_health_bar.fill_ratio==0.5,"drawn guard bar reports proportion not internal hp")
	enemy.position = Vector2(300,50)
	guards = game.play_visible().objects.filter(func(t):return t.kind == "enemy")
	check(guards.size()==1 and not guards[0].has("visible_health_bar"),"clipped guard bar omitted independently of visible body")
	for b in bosses.bosses.values(): b.hp = 0
	var boss: Dictionary = bosses.bosses[id]
	boss.hp = 100
	boss.position = Vector2(3000,3000)
	boss.windup = 0.0
	check(bosses.play_visible().visible_bosses.is_empty(),"offscreen boss omitted")
	boss.position = Vector2(300,200)
	check(bosses.play_visible().visible_bosses.size()==1,"onscreen boss described")
	boss.windup = 0.5
	boss.target = Vector2(5,5)
	var view: Dictionary = bosses.play_visible()
	check(view.visible_warnings.size()==1,"visible warning described")
	var rect: Dictionary = view.visible_warnings[0].visible_bounds
	check(rect.x>=24 and rect.y>=212 and rect.x+rect.width<=1256 and rect.y+rect.height<=642,"warning clipped to arena")
	boss.target = Vector2(9000,9000)
	check(bosses.play_visible().visible_warnings.is_empty(),"offscreen warning omitted")
	boss.windup = 0.0
	check(bosses.play_visible().visible_warnings.is_empty(),"finished warning omitted")
	var buildings = game.buildings
	buildings.set_process(false)
	var door: Vector2 = buildings.Catalog.entrance(game.region)
	game.camera_origin = door-Vector2(600,260)
	var building: Dictionary = buildings.play_visible()
	check(building.has("entrance"),"visible building entrance described")
	check(building.has("visible_label"),"fully visible effect label described")
	game.camera_origin = door-Vector2(600,10)
	building = buildings.play_visible()
	check(building.has("entrance") and not building.has("visible_label"),"clipped label not leaked with visible entrance")
	game.camera_origin = door+Vector2(2000,2000)
	check(buildings.play_visible().is_empty(),"offscreen building effect omitted")
	var traps = game.get_node("Traps")
	traps.set_process(false)
	game.camera_origin = Vector2.ZERO
	var kind: String = traps.Catalog.TRAPS.keys()[0]
	traps.hazards.clear()
	traps.hazards.append({"kind":kind,"position":Vector2(5,5),"age":0.0})
	check(traps.play_visible().size()==1 and traps.play_visible()[0].appearance=="黄色预警圈","visible yellow hazard described")
	var hazard_bounds: Dictionary = traps.play_visible()[0].visible_bounds
	check(hazard_bounds.x>=24 and hazard_bounds.y>=212,"hazard clipped at viewport edge")
	traps.hazards[0].age = float(traps.Catalog.TRAPS[kind].warning)
	check(traps.play_visible()[0].appearance=="红色爆发圈","active red hazard described")
	traps.hazards[0].position = Vector2(9000,9000)
	check(traps.play_visible().is_empty(),"offscreen hazard omitted")
	traps.hazards.clear()
	check(traps.play_visible().is_empty(),"expired hazard omitted")
	var chests = game.get_node("Chests")
	chests.set_process(false)
	var chest: Dictionary = chests.regions[game.region][0]
	chest.position = Vector2(300,200)
	chest.mutated = false
	chest.state = "sealed"
	check(chests.play_visible().any(func(t): return t.title=="普通宝箱 · E开启"),"normal sealed chest visible")
	chest.state = "opened"
	check(chests.play_visible().any(func(t): return t.title=="普通宝箱 · 已领取"),"opened chest visible")
	chest.mutated = true
	chest.state = "guarding"
	check(chests.play_visible().any(func(t): return t.title=="异变宝箱 · 守卫中"),"mutated guarding chest visible")
	chest.position = Vector2(9000,9000)
	check(not chests.play_visible().any(func(t): return t.title=="异变宝箱 · 守卫中"),"offscreen chest omitted")
	chest.mobs = [{"hp":10,"position":Vector2(300,200)},{"hp":0,"position":Vector2(320,200)},{"hp":10,"position":Vector2(9000,9000)}]
	chest.boss = {"hp":10,"position":Vector2(350,200),"art":chests.Bosses.DEFINITIONS.keys()[0],"windup":0.5,"target":Vector2(5,5)}
	chest.warning = 0.5
	var encounter: Dictionary = chests.play_visible_encounters()
	check(encounter.actors.size()==2,"offscreen chest still exposes independently visible live actors only")
	check(encounter.warnings.size()==1,"visible boss warning but not offscreen chest awakening")
	var warning_bounds: Dictionary = encounter.warnings[0].visible_bounds
	check(warning_bounds.x>=24 and warning_bounds.y>=212,"encounter warning clipped")
	chest.state = "cleared"
	check(chests.play_visible_encounters().actors.is_empty(),"cleared encounter actors omitted")
	var weather = game.get_node("Weather")
	weather.set_process(false)
	var plot: Dictionary = weather.plots[game.region][0]
	for other: Dictionary in weather.plots[game.region]: other.position = Vector2(9000,9000)
	plot.position = Vector2(300,200)
	game.player_foot = Vector2(310,210)
	check(weather.play_visible().size()==1 and weather.play_visible()[0].has("visible_label"),"nearby complete garden label visible")
	game.player_foot = Vector2(900,600)
	check(weather.play_visible().size()==1 and not weather.play_visible()[0].has("visible_label"),"distant garden hides species and growth")
	plot.position = Vector2(2,2)
	game.player_foot = Vector2(5,5)
	check(not weather.play_visible()[0].has("visible_label"),"clipped garden label omitted")
	plot.position = Vector2(9000,9000)
	check(weather.play_visible().is_empty(),"offscreen garden omitted")
	game.dialogue.show()
	check(weather.play_visible().is_empty(),"modal hides garden")
	check(chests.play_visible_encounters().is_empty(),"modal hides encounter")
	check(chests.play_visible().is_empty(),"modal hides chests")
	check(buildings.play_visible().is_empty(),"modal hides building")
	check(game.play_visible().get("world_occluded",false) and not game.play_visible().has("boss_view"),"modal hides world and boss descriptions")
	print("VISIBLE_BOUNDARIES failures=%d" % failures)
	game.queue_free()
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
