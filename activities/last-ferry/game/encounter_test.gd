extends SceneTree
## Isolated rule assertions; not public-input play or visual acceptance.
## Run only after the complete encounter implementation is ready.
const Story = preload("res://story_state.gd")
var state = Story.new()
var checks := 0
var failures := 0
var test_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func position(place: String = "steps", x: float = 150.0, y: float = 550.0) -> void:
	state.change_place(place)
	state.s.x = x
	state.s.y = y

func new_night(identity: String = "xu") -> void:
	state.fresh(identity)
	check(state.act("night"), identity + " enters night via actual action")
	position()

func ready_retreat() -> void:
	new_night()
	state.set_flag("xu_identified")

func rejected(label: String) -> void:
	var before: Dictionary = state.s.duplicate(true)
	check(not state.act("meet_retreat"), label + " rejected")
	check(state.s == before, label + " leaves state unchanged")

func round_trip(label: String) -> void:
	var before: Dictionary = state.s.duplicate(true)
	check(state.valid_save(before), label + " valid v1 state")
	check(state.save_game(), label + " isolated save")
	# Loading must restore disk data, not just keep the current in-memory object.
	state.s.x = 999.0
	check(state.load_game() and state.s == before, label + " real file restores exact state")

func view_is_read_only(label: String) -> Dictionary:
	var before: Dictionary = state.s.duplicate(true)
	var notice_before: String = state.notice
	var view: Dictionary = state.first_meet_view()
	check(state.s == before and state.notice == notice_before, label + " view is pure read")
	return view

func identify(place: String) -> void:
	new_night()
	position("house")
	check(state.act("whistle_memory"), place + " recalls actual private rhythm")
	position(place, 460.0, 335.0)
	check(state.act("listen_river"), place + " listens before answering")
	for sound in ["whistle_short", "whistle_short", "whistle_long"]:
		check(state.act(sound), place + " plays " + sound)
	check(state.act("whistle_listen") and state.flag("xu_identified"), place + " recognized with private reply")

func run() -> void:
	# All Story instances below share this explicit test-only path, assigned before fresh().
	# No Main scene is instantiated and no production user:// journey is opened.
	test_dir = "res://.test-output/encounter-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(test_dir) != OK:
		push_error("Cannot create isolated test directory; refusing to run")
		quit(2)
		return
	state.save_path = test_dir + "/journey.json"
	print("TEST_STORAGE ", ProjectSettings.globalize_path(state.save_path), " (never production user://)")
	if not state.has_method("first_meet_view"):
		push_error("Encounter implementation absent; stop rather than exercise a partial contract")
		quit(2)
		return

	state.fresh("xu")
	check(state.first_meet_view().is_empty() and not state.flag("meet_on") and not state.flag("meet_done"), "dusk is not a meeting")
	rejected("dusk before identification")
	new_night()
	check(state.flag("meet_on") and not state.flag("meet_done"), "new Xu night enables unfinished meeting")
	check(view_is_read_only("new night") == {"active":true, "identified":false, "settled":false}, "new night view matches contract")
	rejected("retreat before identification")
	check(state.s.pollution == 0, "unrecognized departure carries no penalty")
	new_night("he")
	check(not state.flag("meet_on") and state.first_meet_view().is_empty(), "He night never enables meeting")
	state.set_flag("meet_on")
	state.set_flag("xu_identified")
	rejected("He even with forged meeting flags")
	check(state.first_meet_view().is_empty(), "He view stays empty with meeting flags")

	ready_retreat()
	state.s.flags.erase("meet_on")
	state.s.flags.erase("meet_done")
	round_trip("legacy night missing new flags")
	check(not state.s.flags.has("meet_on") and not state.s.flags.has("meet_done"), "load never backfills legacy meeting flags")
	check(view_is_read_only("legacy night").is_empty(), "legacy night view empty")
	rejected("legacy identified night missing meet_on")
	check(not state.act("night") and not state.flag("meet_on"), "repeated night action cannot opt legacy night in")

	ready_retreat()
	position("boat")
	rejected("boat coordinates are not shore dry ground")
	position("shelter")
	rejected("shelter coordinates are not shore dry ground")
	for point in [Vector2(69,550), Vector2(310,550), Vector2(150,514), Vector2(150,605), Vector2(700,330)]:
		position("steps", point.x, point.y)
		rejected("outside Rect2 at %s" % point)
	for point in [Vector2(70,515), Vector2(309.9,604.9)]:
		ready_retreat()
		position("steps", point.x, point.y)
		check(state.act("meet_retreat"), "inside Rect2 inclusive start/exclusive end at %s" % point)

	ready_retreat()
	state.set_flag("released")
	rejected("already released")
	check(view_is_read_only("released").is_empty(), "released view empty")
	ready_retreat()
	state.s.phase = "dusk"
	rejected("dusk despite meeting flags")
	check(state.first_meet_view().is_empty(), "dusk view empty despite flags")
	for ending in ["light", "untie", "flood"]:
		ready_retreat()
		if ending == "flood": state.s.pollution = 2
		state.finish(ending)
		position("street" if ending == "flood" else "steps")
		check(state.first_meet_view().is_empty(), ending + " view empty")
		rejected(ending + " epilogue")
		round_trip(ending + " ending")
		rejected(ending + " loaded epilogue")
		state.s.flags.erase("meet_on")
		state.s.flags.erase("meet_done")
		round_trip(ending + " legacy ending missing flags")
		check(state.first_meet_view().is_empty() and not state.s.flags.has("meet_on"), ending + " old ending not backfilled")
	ready_retreat()
	state.s.left = true
	rejected("already left")
	check(state.first_meet_view().is_empty(), "left view empty")

	for place in ["steps", "boat"]:
		identify(place)
		var items_before: Array = state.s.items.duplicate()
		var evidence_before: Array = state.s.evidence.duplicate()
		var pollution_before: int = state.s.pollution
		check(not state.flag("meet_done"), place + " recognition does not settle encounter")
		round_trip(place + " recognized mid-scene")
		check(view_is_read_only(place) == {"active":true, "identified":true, "settled":false}, place + " loaded recognition view retained")
		position()
		var journal_before: int = state.s.journal.size()
		check(state.act("meet_retreat") and state.flag("meet_done"), place + " voluntary dry-ground retreat settles once")
		check(state.s.journal.size() == journal_before + 1, place + " single short retreat record")
		check(state.s.items == items_before and state.s.evidence == evidence_before and state.s.pollution == pollution_before, place + " retreat has no item/evidence/pollution side effects")
		check(not state.has("xu_wish") and not state.has("shen_wish") and not state.item("旧渡牌") and not state.flag("ferry_tag_taken") and not state.flag("ferry_tag_returned"), place + " neither wishes nor ferry tag granted")
		check(not state.flag("released") and state.s.ending == "" and state.s.phase == "night", place + " no automatic departure or ending")
		check(view_is_read_only(place + " settled") == {"active":true, "identified":true, "settled":true}, place + " settled presentation remains readable")
		rejected(place + " repeated retreat")
		round_trip(place + " settled meeting")
		rejected(place + " loaded settled retreat")
		position("shelter")
		position()
		rejected(place + " re-entry after settlement")
		check(state.act("ask_roof") and not state.has("xu_wish"), place + " life conversation remains independent")
		check(state.act("ask_departure") and state.has("xu_wish"), place + " later explicit wish remains available")

	new_night()
	position("house")
	check(state.act("whistle_memory"), "wrong rhythm setup")
	position("steps")
	check(state.act("listen_river"), "wrong rhythm hears river")
	check(state.act("whistle_long") and state.act("whistle_short") and state.act("whistle_short") and state.act("whistle_listen"), "wrong rhythm returns safe feedback")
	check(not state.flag("xu_identified") and not state.flag("meet_done") and state.s.pollution == 0, "wrong rhythm grants no recognition or penalty")
	rejected("wrong rhythm cannot settle")
	check(state.act("whistle_reset"), "reset allows recovery")
	check(state.act("whistle_short") and state.act("whistle_short") and state.act("whistle_long") and state.act("whistle_listen") and state.flag("xu_identified"), "correct second attempt recovers")
	check(state.act("meet_retreat"), "recovered recognition can settle without taking tag")

	new_night()
	check(not state.flag("xu_identified") and state.act("xu_voice") and state.has("xu_wish"), "legacy xu_voice not gated by new identification/meeting")
	check(not state.flag("meet_done") and not state.flag("xu_identified"), "legacy wish does not invent encounter recognition")
	state.s.flags.erase("meet_on")
	round_trip("legacy xu_voice night")
	check(state.act("xu_voice") and not state.flag("meet_on"), "legacy direct wish remains repeatable without meet_on")
	for flag_name in ["meet_on", "meet_done"]:
		for bad in [1, "true", null]:
			new_night()
			state.s.flags[flag_name] = bad
			check(not state.valid_save(state.s), flag_name + " rejects non-bool save flag")

	print("ENCOUNTER_TEST_RESULT checks=%d failures=%d storage=%s" % [checks, failures, ProjectSettings.globalize_path(test_dir)])
	quit(0 if failures == 0 else 1)
