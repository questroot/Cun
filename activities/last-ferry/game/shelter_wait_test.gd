extends SceneTree
## Real backend fixture, not normal-input or visual acceptance.
const Story = preload("res://story_state.gd")
var state = Story.new()
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
func setup() -> void:
	state.fresh("xu")
	state.change_place("shelter")
	state.wait_step(0.01,Vector2(100,550),{})
func at(pos: Vector2) -> void:
	state.s.x = pos.x
	state.s.y = pos.y
func tick(player: Vector2 = Vector2(100,550), blocked: Dictionary = {}) -> void:
	state.wait_step(0.05,player,blocked)
func advance(label: String) -> void:
	var moved := false
	var bounded := true
	for i in range(400):
		var prev: Vector2 = state.wait_view().zhou
		tick()
		var view: Dictionary = state.wait_view()
		var dist: float = prev.distance_to(view.zhou)
		bounded = bounded and dist <= 3.751
		moved = moved or dist > 0.1
		if view.stage == "settled": break
	check(bounded, label + " speed capped 75px/s at 0.05s")
	check(moved, label + " actual intermediate movement")
	check(state.wait_view().stage == "settled", label + " arrives before settlement")
func take_chair() -> void:
	at(state.wait_view().chair)
	check(state.act("chair_take"), "near chair immediately liftable")
func place_chair(pos: Vector2) -> void:
	at(pos - Vector2(0,22))
	check(state.act("chair_place"), "place at actual legal foot point")
	check(state.wait_view().chair.distance_to(pos) < 0.01, "placement not snapped to dry target")
func run() -> void:
	var dir := "res://.test-output/shelter-%d" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(dir) == OK, "isolated storage")
	state.save_path = dir + "/journey.json"
	print("TEST_STORAGE ",ProjectSettings.globalize_path(state.save_path))
	setup()
	check(not state.s.has("shelter_wait") and state.valid_save(state.s), "legacy missing field remains legal")
	var before: Dictionary = state.s.duplicate(true)
	state.wait_view()
	check(before == state.s, "view pure read does not initialize legacy field")
	check(state.act("wait_offer"), "offer starts")
	var start: Dictionary = state.wait_view()
	tick()
	check(state.wait_view().zhou.distance_to(start.zhou) > 0 and state.wait_view().zhou.x < 505, "offer drags continuously not teleports")
	take_chair()
	place_chair(Vector2(520,480))
	check(state.wait_view().wet and state.wait_view().stage != "settled", "wet placement stays unsettled")
	take_chair()
	place_chair(Vector2(380,390))
	advance("B left dry band")
	check(not state.wait_view().wet and state.wait_view().route == "move" and state.wait_view().pose == "seated" and not state.flag("awning_tied"), "B dry seat without repairing awning")
	# Last backend change: a completed B remains activatable by subsequently doing A.
	state.set_flag("awning_tied")
	tick()
	check(state.wait_view().stage == "working" and state.wait_view().route == "awning" and state.wait_view().pose != "seated", "B to A reactivates and stands before travel")
	advance("B then A")
	check(state.wait_view().chair.distance_to(Vector2(640,400)) < 0.01 and state.wait_view().pose == "seated", "A finishes at right dry seat")
	setup()
	state.act("wait_offer")
	state.set_flag("awning_tied")
	advance("A from offer")
	check(state.wait_view().chair == Vector2(640,400), "A chair reaches actual destination")
	setup()
	state.act("wait_offer")
	var initial: Vector2 = state.wait_view().zhou
	tick(initial + Vector2(3.75,0))
	check(state.wait_view().zhou == initial, "28px actor exclusion blocks movement")
	tick(Vector2(100,550),{"rects":[Rect2(458,420,20,20)]})
	check(state.wait_view().zhou == initial, "static rectangle blocks movement")
	tick()
	check(state.wait_view().zhou != initial, "unblocked movement resumes")
	setup()
	state.act("wait_offer")
	for flag_name in ["basin_carried","stock_carried","evac_pack_carried","luggage_taken"]:
		state.set_flag(flag_name)
		at(state.wait_view().chair)
		check(not state.act("chair_take"), flag_name + " prevents lifting")
		at(Vector2(690,350))
		check(not state.act("awning_grip"), flag_name + " prevents rope grip")
		state.s.flags.erase(flag_name)
	take_chair()
	for action in ["awning_grip","basin_take","stock_take","evac_pack_take"]:
		check(not state.act(action), "chair ownership rejects " + action)
	state.set_flag("stock_carried")
	tick(Vector2(520,450))
	check(not state.wait_view().carried, "dynamic new busy hand releases chair")
	state.s.flags.erase("stock_carried")
	take_chair()
	tick(Vector2(520,450),{"rope":true})
	check(not state.wait_view().carried, "dynamic rope ownership releases chair")
	at(Vector2(690,350))
	check(state.act("awning_grip"), "free hands grip rope")
	at(state.wait_view().chair)
	check(not state.act("chair_take"), "rope prevents lifting in reverse direction")
	tick()
	take_chair()
	tick(Vector2(520,450))
	var carry_pos: Vector2 = state.wait_view().chair
	check(state.save_game() and state.wait_view().carried, "saving does not interrupt holding")
	check(state.load_game() and not state.wait_view().carried and state.wait_view().chair == carry_pos, "loading releases at persisted legal chair point")
	take_chair()
	state.change_place("steps")
	check(not state.wait_view().carried and state.wait_view().chair == carry_pos, "exit releases without chair duplication or reset")
	state.change_place("shelter")
	check(not state.act("wait_offer"), "return does not repeat offer")
	setup()
	state.set_flag("awning_tied")
	check(state.act("wait_offer") and state.wait_view().stage == "settled" and state.wait_view().line.is_empty(), "legacy tied shelter skips dripping offer")
	take_chair()
	check(state.wait_view().carried, "legacy tied chair voluntarily movable")
	for flag_name in ["closing_light","closing_release"]:
		setup()
		state.act("wait_offer")
		state.set_flag(flag_name)
		tick()
		check(not state.wait_view().present and state.wait_view().pose == "absent" and not state.act("chair_take"), flag_name + " departure priority")
	for ending in ["flood","untie","light"]:
		setup()
		state.act("wait_offer")
		if ending == "flood": state.s.pollution = 2
		state.finish(ending)
		tick()
		check(not state.act("wait_offer") and not state.act("chair_take"), ending + " ending cannot restart event")
		if ending != "light": check(not state.wait_view().present, ending + " NPC absent")
	setup()
	state.act("wait_offer")
	var valid: Dictionary = state.s.duplicate(true)
	for key in ["chair","zhou"]:
		for bad in [INF,NAN,"bad",true]:
			var data: Dictionary = valid.duplicate(true)
			data.shelter_wait[key][0] = bad
			check(not state.valid_save(data), key + " rejects nonfinite/nonnumeric coordinate " + str(bad))
	for bad in [1,"true",null]:
		var data: Dictionary = valid.duplicate(true)
		data.shelter_wait.carried = bad
		check(not state.valid_save(data), "carried rejects nonbool " + str(bad))
	for pair in [["stage","invalid"],["route","invalid"],["chair",[400,300]],["zhou",[900,430]]]:
		var data: Dictionary = valid.duplicate(true)
		data.shelter_wait[pair[0]] = pair[1]
		check(not state.valid_save(data), "reject invalid field " + str(pair))
	check(state.s.evidence == ["whistle"] and state.s.items == ["铜哨"] and state.s.pollution == 0 and state.s.ending == "", "life event no knowledge/items/pollution/ending reward")
	print("SHELTER_WAIT_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
