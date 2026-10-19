extends SceneTree
## Real Godot runtime tests, not a human playthrough or image review.
const Story = preload("res://story_state.gd")
var checks := 0
var failures := 0
var state = Story.new()
var test_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func at(place: String, action: String) -> bool:
	state.change_place(place)
	return state.act(action)

func investigate() -> void:
	check(at("shelter", "timetable"), "inspect actual timetable")
	check(at("shelter", "lamp"), "inspect modified lamp")
	check(at("shelter", "bell"), "inspect missing tongue")
	check(at("shelter", "inscription"), "inspect inscription")
	check(at("shelter", "verify"), "verify source with Zhou")
	check(state.core(), "four core facts obtained")

func run() -> void:
	var start := Time.get_ticks_msec()
	test_dir = "res://.test-output/run-%d" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(test_dir)
	state.save_path = test_dir + "/journey.json"
	print("TEST_STORAGE ", ProjectSettings.globalize_path(test_dir), " (never production user://)")
	for identity in ["xu", "he"]:
		state.fresh(identity)
		check(not at("shelter", "restore"), identity + " cannot restore without information/night")
		check(state.s.pollution == 0, "wrong reasoning never pollutes")
		check(not at("steps", "untie"), "untie cannot be menu-selected")
		investigate()
		if identity == "he":
			check(at("street", "ledger"), "apprentice reads own shop ledger")
			check(at("street", "yellow"), "apprentice borrows actual item")
			check(at("shelter", "deliver"), "deliver starting wick")
			check(not at("shelter", "deliver"), "no repeated wick reward")
		check(at("shelter", "consent"), "Zhou understands waiting versus goodbye")
		check(state.act("night"), "explicit night transition")
		if identity == "he":
			check(not at("steps", "board"), "apprentice cannot board")
			check(not at("steps", "xu_voice"), "no automatic sharing of whistle/voice")
			check(at("shelter", "swap"), "unique borrowed yellow lamp prevents white signal")
			check(not at("shelter", "danger"), "safe lamp state has actual effect")
		else:
			check(at("steps", "board"), "returnee boards local side deck")
			check(state.s.place == "boat", "boat local location entered")
			state.change_place("steps")
			check(state.s.place == "steps", "boat can return before any result")
		check(at("shelter", "restore"), identity + " can restore from shore without farewell")
		check(state.s.ending == "light" and state.flag("tongue_home") and state.flag("shade_off") and state.flag("yellow_lit"), "light is physical three-part repair")
		check(state.has("mark"), "mark has observable outcome source")
		check(not at("steps", "untie"), "cannot replace committed ending")
		check(state.save_game(), "save successful ending")
		var snapshot := JSON.stringify(state.s)
		state.fresh("xu" if identity == "he" else "he")
		check(state.load_game() and JSON.stringify(state.s) == snapshot, "exact identity/phase/items/flags/ending roundtrip")
		for place in ["street", "house", "shelter", "steps"]:
			check(at(place, "epilogue"), "walkable epilogue inspect " + place)
		check(at("street", "morning_ge"), "living town has morning routines")
		if identity == "he":
			check(at("street", "return_lamp") and not state.item("手提黄灯"), "borrowed property actually returned")
			check(not at("street", "return_lamp"), "lamp return cannot duplicate")
			check(not at("house", "roof_commission"), "apprentice cannot decide for house owner")
		else:
			check(at("house", "roof_commission") and state.flag("roof_commissioned"), "returnee makes own modest morning plan")
			check(not at("house", "leave_contact"), "cannot overwrite committed morning choice by sweeping buttons")
		check(state.save_game() and state.load_game() and state.s.ending == "light", "morning choices persist without replacing night ending")
		check(at("street", "leave") and state.s.left, "explicit leave retains record")
		check(not state.act("leave"), "leave commits only once")

	for identity in ["xu", "he"]:
		state.fresh(identity)
		check(not at("steps", "tool_retrieve"), "unidentified bag not automatically looted")
		check(at("street", "ge_talk"), "living witness has ordinary context")
		check(at("steps", "tool_retrieve") and state.item("老葛的工具袋"), "retrieve physical bag safely")
		check(not at("steps", "tool_retrieve"), "cannot duplicate optional bag")
		check(at("street", "tool_return") and state.flag("tool_returned") and not state.item("老葛的工具袋"), "return belongs to living owner")
		check(not at("house", "basin_place"), "cannot place absent basin")
		check(not at("house", "basin_take"), "observe leak before moving basin")
		check(at("house", "roof_listen") and at("house", "basin_take"), "observe and carry basin")
		check(at("house", "basin_wrong") and not state.flag("basin_placed"), "wrong location gives feedback not success")
		check(state.save_game() and state.load_game() and state.flag("basin_carried"), "save carried basin state")
		check(at("house", "basin_place") and state.flag("basin_placed") and not state.flag("basin_carried"), "successful mundane intervention changes world")
		check(state.s.pollution == 0 and state.s.ending == "", "optional domestic act does not gate or resolve main story")

	for identity in ["xu", "he"]:
		state.fresh(identity)
		check(not at("steps", "answer_whistle"), "no river identity confirmed in daylight")
		check(state.act("night"), "enter river encounter at own pace")
		check(at("steps", "listen_river") and not state.has("xu_wish"), "hearing voices is not knowing wishes")
		check(at("steps", "call_paper") and state.s.pollution == 0, "questioning unverified invitation is safe")
		check(not at("steps", "answer_whistle"), "cannot identify from missing personal context")
		if identity == "xu":
			check(at("house", "whistle_memory"), "returnee recalls lived signal")
		else:
			check(not at("house", "whistle_memory"), "apprentice cannot own another person's memory")
			at("shelter", "lamp")
			at("shelter", "bell")
			check(at("house", "exchange"), "apprentice gets explicit cooperation")
		check(at("steps", "answer_whistle") and state.flag("xu_identified") and not state.has("xu_wish"), "identification distinct from deciding wishes")
		check(at("steps", "ask_roof") and not state.has("xu_wish"), "ordinary conversation not automatic farewell")
		check(state.save_game() and state.load_game() and state.flag("xu_identified"), "encounter progress survives save")
		check(at("steps", "ask_departure") and state.has("xu_wish"), "ask person rather than infer desired ending")

	for identity in ["xu", "he"]:
		state.fresh(identity)
		check(not at("shelter", "retrieve_tongue"), "cannot retrieve through closed shade")
		check(not at("shelter", "install_tongue"), "cannot install absent tongue")
		investigate()
		check(not at("shelter", "waiting_plan"), "facts alone do not replace hearing motive")
		check(at("shelter", "zhou_memory"), "hear Zhou in identity-specific scene")
		check(at("shelter", "promise_forever") and not state.flag("consent"), "empty lifelong promise not automatic success")
		check(not at("shelter", "waiting_plan"), "must explain signal comparison rather than guess password")
		check(at("shelter", "signal_guess"), "player proposes visible-signal hypothesis")
		check(state.save_game() and state.load_game() and state.flag("heard_zhou") and state.flag("signal_compared"), "negotiation survives save")
		check(at("shelter", "waiting_plan") and state.flag("consent"), "limited honest plan earns consent")
		check(state.s.pollution == 0, "disagreement never adds invasion")
		check(at("shelter", "remove_shade"), "player removes actual outer shade")
		check(at("shelter", "retrieve_tongue") and state.item("拆下的铜舌"), "player carries removed tongue")
		check(state.save_game() and state.load_game() and state.item("拆下的铜舌"), "in-progress physical repair survives save")
		check(at("shelter", "install_tongue") and not state.item("拆下的铜舌"), "install consumes carried item")
		check(not at("shelter", "light_yellow") and state.s.ending == "", "dusk repair does not skip night")
		check(state.act("night") and at("shelter", "light_yellow") and state.s.ending == "light", "physical three-site repair resolves night")

	for identity in ["xu", "he"]:
		state.fresh(identity)
		investigate()
		check(at("shelter", "consent"), "farewell first gains trust")
		check(state.act("night"), "farewell enters night")
		if identity == "he":
			check(not at("steps", "shen"), "apprentice cannot auto-read boat conversation")
			check(at("house", "exchange"), "explicit evidence exchange creates cooperation")
			check(not state.item("铜哨"), "cooperation never steals private property")
		check(at("steps", "xu_voice"), "identify Xu then ask actual wish")
		check(at("steps", "xiaoman"), "Xiaoman separately expresses wish")
		check(at("steps", "shen"), "Shen separately expresses wish")
		check(not state.farewell_ready(), "wishes alone are insufficient")
		check(at("steps", "return"), "voluntary object return")
		check(at("shelter", "farewell_consent"), "Zhou consents to last bell after reports")
		check(at("steps", "untie") and state.s.ending == "untie", identity + " completes negotiated untie")
		check(at("street", "leave"), "untie can leave")

	state.fresh("xu")
	state.act("night")
	check(at("shelter", "danger"), "first explicitly dangerous action")
	check(state.s.pollution == 1 and state.s.place == "street" and state.s.ending == "", "first incursion retreats, remains repairable")
	check(state.save_game(), "save pollution one")
	state.fresh("he")
	check(state.load_game() and state.s.pollution == 1 and state.s.phase == "night" and state.s.identity == "xu", "night/pollution/identity preserved")
	investigate()
	state.act("consent")
	check(state.act("restore") and state.s.ending == "light", "repair remains possible after first incursion")

	state.fresh("he")
	state.act("night")
	at("shelter", "danger")
	check(at("shelter", "danger"), "second confirmed white signal")
	check(state.s.pollution == 2 and state.s.ending == "flood" and state.s.place == "street", "second incursion closes ferry and evacuates")
	check(state.save_game(), "save flood")
	state.fresh("xu")
	check(state.load_game() and state.s.ending == "flood", "flood persists across load")
	state.change_place("steps")
	check(state.s.place == "street", "closed pier cannot be bypassed")
	check(at("shelter", "epilogue"), "flood safe shelter still inspectable")
	check(at("street", "leave"), "failure still allows explicit leave")

	var good: Dictionary = state.s.duplicate(true)
	for field in ["identity", "phase", "place"]:
		var bad: Dictionary = good.duplicate(true)
		bad[field] = "not-an-enum"
		check(not state.valid_save(bad), "reject invalid enum " + field)
	for field in ["evidence", "items", "journal"]:
		var bad: Dictionary = good.duplicate(true)
		bad[field] = [45]
		check(not state.valid_save(bad), "reject invalid elements " + field)
	var invalid: Dictionary = good.duplicate(true)
	invalid.flags = {"consent": "yes"}
	check(not state.valid_save(invalid), "reject non-boolean flag")
	invalid = good.duplicate(true)
	invalid.pollution = 0
	check(not state.valid_save(invalid), "reject inconsistent flood")
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var before := JSON.stringify(state.s)
	check(not state.load_game() and before == JSON.stringify(state.s), "corrupt save preserves current state")
	check(FileAccess.get_file_as_string(state.save_path) == "{broken", "corrupt file never silently deleted")

	# Instantiate the actual main scene to catch UI, draw, callback and movement errors.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.start_game("xu")
	await process_frame
	var origin: Vector2 = scene.player
	scene.move_player(Vector2(20, 0))
	check(scene.player != origin, "real scene free top-down movement")
	scene.player = Vector2(45, 440)
	scene.move_player(Vector2(-100, 0))
	check(scene.player.x >= 40, "world boundary blocks escape")
	scene.story.change_place("shelter")
	scene.last_place = ""
	scene.update_world()
	scene.player = Vector2(300, 400)
	scene.nearest = "lamp"
	scene.interact()
	check(scene.modal_open, "actual interaction panel opens")
	scene.close_modal()
	scene.show_journal()
	scene.close_modal()
	scene.show_items()
	scene.close_modal()
	scene.show_pause()
	check(scene.paused and scene.modal_open, "pause stops world input")
	scene.close_modal()
	scene.start_game("xu")
	scene.travel("shelter")
	scene.story.set_flag("consent")
	scene.player = Vector2(750, 550)
	check(not scene.try_world_click(Vector2(250,360)), "direct repair cannot work remotely")
	scene.player = Vector2(250,400)
	check(scene.try_world_click(Vector2(250,360)) and scene.story.flag("shade_off"), "direct click removes shade nearby")
	check(scene.try_world_click(Vector2(250,360)) and scene.story.item("拆下的铜舌"), "direct click takes revealed tongue")
	scene.player = Vector2(550,280)
	check(scene.try_world_click(Vector2(550,240)) and scene.story.flag("tongue_home"), "direct install changes equipment")
	check(not scene.modal_open, "repair manipulation does not open choice menus")
	scene.start_game("he")
	scene.travel("shelter")
	scene.player = Vector2(455,430)
	scene.nearest = "zhou"
	scene.interact()
	scene.continue_zhou("zhou_memory")
	check(scene.modal_open and scene.conversation_target == "zhou", "listening continues in same conversation")
	check(scene.conversation_response == scene.story.notice and scene.story.flag("heard_zhou"), "current response retained on screen")
	scene.continue_zhou("promise_forever")
	check(scene.modal_open and not scene.story.flag("consent"), "disagreement stays in dialogue not exit loop")
	scene.close_modal()
	check(scene.conversation_target == "" and scene.conversation_response == "", "leaving dialogue clears only presentation")
	for id in ["xu", "he"]:
		scene.start_game(id)
		for place in ["street", "house", "shelter", "steps"]:
			scene.travel(place)
			await process_frame
			for obj in scene.scene_objects.duplicate():
				scene.nearest = obj.id
				scene.interact()
				await process_frame
				scene.close_modal()
	check(true, "all four scene draw/interaction panels execute for both identities")
	scene.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failures=", failures, " elapsed_ms=", Time.get_ticks_msec() - start)
	quit(0 if failures == 0 else 1)
