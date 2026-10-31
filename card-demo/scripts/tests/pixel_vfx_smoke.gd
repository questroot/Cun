extends SceneTree
const Skills = preload("res://scripts/scenes/boss_skills.gd")
const VFX = preload("res://scripts/scenes/pixel_vfx.gd")
const Catalog = preload("res://scripts/scenes/boss_catalog.gd")
var game
var bosses
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func frames() -> void:
	for i in range(3): await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.model.position = game.player_foot
	game._update_camera()
	game._refresh_ui()
	game.world_canvas.queue_redraw()
	game.get_node("Weather")._refresh()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("user://vfx_"+label+".png")==OK,"capture "+label)
	print("VFX_CAPTURE: "+ProjectSettings.globalize_path("user://vfx_"+label+".png"))

func lane(region: String, point: Vector2) -> Vector2:
	var maps = preload("res://scripts/scenes/fudi_maps.gd")
	var nearest := INF
	var result := Vector2.RIGHT
	for road: Array in maps.MAPS[region].roads:
		for i in range(road.size()-1):
			var a: Vector2 = road[i]*maps.MAPS[region].size
			var b: Vector2 = road[i+1]*maps.MAPS[region].size
			var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))
			if distance < nearest:
				nearest = distance
				result = a.direction_to(b)
	return result

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("Cun-VFX-"):
		printerr("VFX checks require isolated saves.")
		quit(2)
		return
	await frames()
	var data = root.get_node("DataManager")
	data.write_save()
	var saved := FileAccess.get_file_as_string(data.SAVE_PATH)
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await frames()
	bosses = game.get_node("Bosses")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/pixel/manifest.json"))
	check(manifest.effects.size()==56,"56 authored VFX assets")
	for entry: Dictionary in manifest.effects:
		var art := VFX.texture(entry.key)
		check(art!=null and art.get_width()==768 and art.get_height()==96,"eight native frames "+entry.key)
	check(VFX.frame_at(.0)==0 and VFX.frame_at(.17)==2 and VFX.frame_at(.22)==3 and VFX.frame_at(.699)==7,"nonuniform frame timings")
	var names := {}
	for id: String in Skills.MOVES:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		game.enter_region(config.region)
		var boss: Dictionary = bosses.bosses[id]
		var direction := lane(config.region,boss.home)
		check(Skills.MOVES[id].size()==5,"five skills "+id)
		for index in range(Skills.MOVES[id].size()):
			var s: Dictionary = Skills.MOVES[id][index]
			names[s.name] = true
			boss.position = boss.home
			boss.skill_index = index
			boss.windup = 0.0
			boss.cooldown = 0.0
			game.health = 100
			game.hurt_timer = 0.0
			game.player_foot = boss.home + direction * (150 if s.shape=="ring" else 65)
			bosses.tick(.01)
			check(boss.windup==s.windup and game.health==100,"telegraph before damage "+s.name)
			check(Skills.hits(boss,game.player_foot),"designated danger point "+s.name)
			var target: Vector2 = boss.target
			var heading: Vector2 = boss.direction
			var zones: Array = boss.zones.duplicate()
			var hit_point: Vector2 = game.player_foot
			var safe := Vector2.ZERO
			match str(s.shape):
				"ring": safe = boss.home
				"line", "sector": safe = boss.home-direction*100
				"cross": safe = boss.target+direction*90+direction.orthogonal()*90
				_: safe = boss.target+direction*280
			check(not Skills.hits(boss,safe),"safe gap lies outside damage "+s.name)
			game.player_foot = safe
			bosses.tick(.1)
			check(boss.target==target and boss.direction==heading and boss.zones==zones,"warning locks shape and aim "+s.name)
			game.menu.show()
			var windup: float = boss.windup
			bosses.tick(3)
			check(boss.windup==windup and game.health==100,"modal pause "+s.name)
			game.menu.hide()
			await capture(id+"_"+str(index)+"_warning")
			bosses.tick(float(s.windup)+.01)
			check(game.health==100 and boss.skill_index==(index+1)%5,"dodge and rotate "+s.name)
			check(not bosses.casts.is_empty() and bosses.casts[-1].skill.fx==s.fx,"matching animated effect "+s.name)
			bosses.casts[-1].life = VFX.LIFETIME-.22
			await capture(id+"_"+str(index)+"_impact")
			bosses.casts.clear()
			boss.skill_index = index
			boss.windup = 0.0
			boss.cooldown = 0.0
			game.player_foot = hit_point
			bosses.tick(.01)
			bosses.tick(float(s.windup)+.01)
			check(game.health==100-int(s.damage),"single authored damage "+s.name)
			check(boss.cooldown==s.cooldown,"authored recovery "+s.name)
			var life: float = bosses.casts[-1].life
			game.journal.show()
			bosses.tick(1)
			check(bosses.casts[-1].life==life,"VFX freeze in journal "+s.name)
			game.journal.hide()
			bosses.tick(.8)
			check(bosses.casts.is_empty(),"effect expires without repeat damage "+s.name)
			boss.cooldown = 0.0
			boss.skill_index = index
			bosses.tick(.01)
			game.hurt_timer = 1
			bosses.tick(float(s.windup)+.01)
			check(game.health==100-int(s.damage),"shared invulnerability "+s.name)
			bosses.casts.clear()
		check(bosses.summary(config.region).contains(Skills.MOVES[id][4].name),"map/journal lists five skills "+id)
	check(names.size()==30,"30 distinct move names")
	# Switching maps cancels all visuals and pending casts; death cancels its own casts.
	game.enter_region("grove")
	var target: Dictionary = bosses.bosses.H02
	target.skill_index = 0
	target.cooldown = 0.0
	game.player_foot = target.position+Vector2.RIGHT*65
	bosses.tick(.01)
	game.enter_region("post")
	check(target.windup==0 and bosses.casts.is_empty(),"travel cancels warnings and particles")
	game.enter_region("grove")
	target.cooldown = 0.0
	game.player_foot = target.position+Vector2.RIGHT*65
	bosses.tick(.01)
	bosses.tick(2)
	target.hp = 0
	bosses.collect_defeated()
	check(target.windup==0 and bosses.casts.is_empty(),"death cancels remaining cast effects")
	# Mutated chest variants inherit all four moves and the existing 60% damage scale.
	var chests = game.get_node("Chests")
	for id: String in Skills.MOVES:
		var config: Dictionary = Catalog.DEFINITIONS[id]
		game.enter_region(config.region)
		chests._add_chest(config.region,true)
		var chest: Dictionary = chests.regions[config.region][-1]
		game.player_foot = chest.position
		chests.interact(chest)
		check(chest.state=="guarding" and chest.boss.id==id,"spawn matching chest archetype "+id)
		var guard: Dictionary = chest.boss
		# Random chests may sit at road bends. Exercise move geometry on a known straight lane;
		# random spawn accessibility is covered separately by chests_smoke.gd.
		guard.position = bosses.bosses[id].home
		guard.home = guard.position
		var direction := lane(config.region,guard.position)
		for index in range(Skills.MOVES[id].size()):
			guard.skill_index = index
			guard.cooldown = 0.0
			guard.windup = 0.0
			game.health = 100
			game.hurt_timer = 0
			var s: Dictionary = Skills.current(guard)
			game.player_foot = guard.position+direction*(150 if s.shape=="ring" else 65)
			chests._tick_boss(guard,.01)
			check(guard.windup==s.windup,"chest warning "+s.name)
			chests._tick_boss(guard,float(s.windup)+.01)
			check(game.health==100-ceili(float(s.damage)*.6),"chest scaled skill damage "+s.name)
			check(guard.skill_index==(index+1)%5 and guard.cast_fx.skill.fx==s.fx,"chest cycle and effect "+s.name)
			guard.cast_fx.life=VFX.LIFETIME-.22
			if index==2: await capture("chest_"+id)
			chests._tick_boss(guard,.8)
			check(guard.cast_fx.is_empty(),"chest effect expires "+s.name)
		game.enter_region("post")
		check(guard.windup==0 and guard.cast_fx.is_empty(),"chest travel cleanup "+id)
	# A full-cast fight without resetting the selected move proves the complete rotation.
	game.enter_region("causeway")
	var fighter: Dictionary = bosses.bosses.H01
	fighter.skill_index = 0
	var seen: Array[String] = []
	for i in range(Skills.MOVES["H01"].size()):
		var move := Skills.current(fighter)
		fighter.cooldown = 0.0
		game.health = 100
		game.hurt_timer = 0
		game.player_foot = fighter.position+lane("causeway",fighter.position)*120
		bosses.tick(.01)
		seen.append(Skills.current(fighter).name)
		bosses.tick(float(move.windup)+.01)
	check(seen.size()==5 and seen[0]!=seen[1] and seen[1]!=seen[2] and seen[2]!=seen[3] and seen[3]!=seen[4] and fighter.skill_index==0,"fight cycles through all five moves")
	# All elemental guards emit the same element that actually dealt contact damage.
	game.enter_region("post")
	var weather = game.get_node("Weather")
	var enemy: Dictionary = game.states.post.enemies[0]
	for element: String in weather.Ecology.WEATHER:
		weather.climates.post = element
		weather.adapt_enemies("post")
		for other: Dictionary in game.states.post.enemies: other.position=game.player_foot+Vector2(900,0)
		enemy.position=game.player_foot
		game.health=100
		game.hurt_timer=0
		game._process(.01)
		check(enemy.attack_weather==element and float(enemy.attack_fx)>0,"guard elemental effect "+element)
		check(game.health==100-int(weather.Ecology.WEATHER[element].damage),"guard contact damage preserved "+element)
		enemy.attack_fx=VFX.LIFETIME-.22
		weather.elapsed=.36
		await capture("guard_"+element)
		var elapsed: float = weather.elapsed
		game.menu.show()
		weather.tick(1)
		check(weather.elapsed==elapsed,"weather particles pause "+element)
		game.menu.hide()
	game.enter_region("grove")
	game.open_journal()
	for moves: Array in Skills.MOVES.values():
		for s: Dictionary in moves: check(game.journal_text.get_parsed_text().contains(s.name),"journal "+s.name)
	game.journal.hide()
	# Player swings and status auras must resolve to real atlas keys, not dead references.
	var keys := {}
	for entry: Dictionary in manifest.effects: keys[entry.key] = true
	for wid: String in ["w01","w02","w03","w05","w06"]:
		check(bool(keys.get("player-"+wid,false)),"player swing atlas "+wid)
	for aura: String in ["status-heal","status-burn","status-freeze"]+VFX.STATUS_BY_EFFECT.values():
		check(bool(keys.get(aura,false)),"status aura atlas "+aura)
	var unit := BattleUnit.new("hero","ally",0,0)
	check(VFX.status_for(unit)=="","no aura without an effect")
	unit.add_effect("stun",2)
	check(VFX.status_for(unit)=="status-stun","stun resolves to an aura")
	unit.add_effect("damage_up",2)
	check(VFX.status_for(unit).begins_with("status-"),"stacked effects still resolve")
	game.enter_region("post")
	game.inventory["w03-prism-saber"] = 1
	check(game.equipment.equip_item("w03-prism-saber"),"weapon equips from inventory")
	game.cooldowns["j"] = 0.0
	game.health = 100
	game.hurt_timer = 0.0
	check(game.attack("j"),"melee attack fires")
	check(game.effects.size()==1 and str(game.effects[0].get("swing",""))=="w03","swing keyed to equipped weapon")
	check(VFX.texture("player-w03")!=null,"swing atlas loads")
	game.equipment.effects.shield_points = 18
	game.equipment.effects.heal_glow = 0.5
	await frames()
	game.equipment.effects.shield_points = 0
	game.equipment.effects.heal_glow = 0.0
	game.effects.clear()
	check(FileAccess.get_file_as_string(data.SAVE_PATH)==saved,"existing isolated save unchanged")
	game.queue_free()
	await create_timer(.5).timeout
	print("VFX_RESULT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
