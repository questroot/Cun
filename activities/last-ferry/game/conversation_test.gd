extends SceneTree
const Story = preload("res://story_state.gd")
var state = Story.new()
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
func setup(identity: String, place: String, night: bool = true) -> void:
	state.fresh(identity)
	if night: state.act("night")
	state.change_place(place)
func unchanged_except_journal(before: Dictionary, label: String) -> void:
	var after: Dictionary = state.s.duplicate(true)
	var original: Dictionary = before.duplicate(true)
	after.erase("journal")
	original.erase("journal")
	check(after == original, label + " no knowledge/flag/item/pollution mutation")
	check(state.s.journal.size() == before.journal.size() + 1, label + " one response record")
func run() -> void:
	var dir := "res://.test-output/conversation-%d" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(dir) == OK, "isolated directory")
	state.save_path = dir + "/journey.json"
	print("TEST_STORAGE ", ProjectSettings.globalize_path(state.save_path))
	for place in ["steps", "boat"]:
		setup("xu", place)
		state.set_flag("river_heard")
		var before: Dictionary = state.s.duplicate(true)
		check(state.act("call_paper"), place + " ordinary question succeeds without invitation")
		check(not state.notice.contains("湿纸") and state.notice.contains("带什么"), place + " does not invent wet paper knowledge")
		unchanged_except_journal(before, place + " ordinary question")
		state.learn("invitation")
		before = state.s.duplicate(true)
		check(state.act("call_paper") and state.notice.begins_with("你照着湿纸问要带什么。"), place + " known invitation retains original reply")
		unchanged_except_journal(before, place + " known paper question")
		for identity in ["xu", "he"]:
			setup(identity, "steps" if identity == "he" else place)
			# He cannot normally board; steps covers its legal natural-question entry.
			before = state.s.duplicate(true)
			check(state.act("shen") and state.notice.contains("沈渡扶住舷边") and state.notice.contains("黄灯底座"), identity + place + " unknown covenant gets person response")
			check(not state.has("shen_wish") and not state.has("covenant") and not state.has("inscription"), "natural reply is not evidence or consent")
			unchanged_except_journal(before, identity + place + " natural Shen")
	for action in ["call_paper", "shen"]:
		for place in ["house", "shelter", "street"]:
			setup("xu", place)
			state.set_flag("river_heard")
			var before: Dictionary = state.s.duplicate(true)
			check(not state.act(action) and state.s == before, action + " invalid place " + place)
		setup("xu", "steps", false)
		state.set_flag("river_heard")
		check(not state.act(action), action + " daylight rejected")
	setup("xu", "steps")
	check(not state.act("call_paper"), "paper followup still requires hearing")
	setup("he", "steps")
	state.learn("covenant")
	check(not state.act("shen") and not state.has("shen_wish"), "He known covenant requires help and Xu wish")
	state.set_flag("xu_help")
	check(not state.act("shen") and not state.has("shen_wish"), "He help alone insufficient")
	state.s.flags.erase("xu_help")
	state.learn("xu_wish")
	check(not state.act("shen") and not state.has("shen_wish"), "He wish alone insufficient")
	state.set_flag("xu_help")
	check(state.act("shen") and state.has("shen_wish"), "He help plus Xu wish retains original evidence")
	for place in ["steps", "boat"]:
		setup("xu", place)
		state.learn("covenant")
		check(state.act("shen") and state.has("shen_wish"), place + " Xu known covenant preserves original evidence path")
		check(not state.has("xu_wish"), "Shen never invents Xu wish")
	setup("xu", "steps")
	check(not state.act("ask_departure") and not state.has("xu_wish"), "Xu explicit wish still requires recognition")
	state.set_flag("xu_identified")
	check(state.act("ask_departure") and state.has("xu_wish"), "Xu recognized explicit question grants original wish")
	print("CONVERSATION_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
