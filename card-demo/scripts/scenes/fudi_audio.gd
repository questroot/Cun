extends Node
## Scene-owned soundtrack: no autoload, global bus edits or spirit-save writes.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const BossCatalog = preload("res://scripts/scenes/boss_catalog.gd")
const UI = preload("res://scripts/scenes/exploration_style.gd")
const ROOT := "res://assets/audio/"
const FADE := 1.2
const AMBIENCE := {"grove": "forest", "post": "wind", "quarry": "fire", "ruins": "water", "refuge": "wind", "wetland": "water", "causeway": "wind", "kilnwood": "fire", "archive": "wind", "snowridge": "wind"}
const STEPS := {"grove": "grass", "post": "stone", "quarry": "stone", "ruins": "stone", "refuge": "snow", "wetland": "water", "causeway": "stone", "kilnwood": "grass", "archive": "stone", "snowridge": "snow"}
var game
var music: Array[AudioStreamPlayer] = []
var ambient: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var last_sfx: Dictionary = {}
var observed: Dictionary = {}
var requested := ""
var current_track := ""
var active_slot := 0
var fade_left := 0.0
var ambient_keys: Array[String] = ["", ""]
var music_level := 0.7
var effects_level := 0.8
var ambience_level := 0.55
var muted := false
var clock := 0.0
var boss_hold := 0.0
var engaged := ""
var last_region := ""
var last_foot := Vector2.ZERO
var walked := 0.0
var last_health := 100
var last_hurt := 0.0
var ready_audio := false
var panel: PanelContainer
var mute_button: Button
var previous_pause := false

func _ready() -> void:
	process_priority = 100
	call_deferred("initialize")

func player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80
	add_child(p)
	return p

func initialize() -> void:
	game = get_parent()
	# Receive modal hotkeys before equipment/map handlers added by the scene.
	game.move_child(self, -1)
	for i in range(2):
		music.append(player())
		ambient.append(player())
	for i in range(12):
		voices.append(player())
	game.sound_requested.connect(cue)
	last_health = game.health
	last_foot = game.player_foot
	_build_controls()
	ready_audio = true
	update_audio(0.0)

func stream(path: String, loop: bool = false) -> AudioStream:
	if not cache.has(path):
		var extension := ".ogg" if path.begins_with("music/") else ".wav"
		var sound := load(ROOT + path + extension) as AudioStream
		if sound == null:
			return null
		sound = sound.duplicate() as AudioStream
		if sound is AudioStreamWAV and loop:
			sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sound.loop_begin = 0
			sound.loop_end = int(round(sound.get_length() * sound.mix_rate))
		elif sound is AudioStreamOggVorbis:
			sound.loop = loop
			sound.loop_offset = 0.0
		cache[path] = sound
	return cache[path]

func cue(kind: String) -> void:
	if not ready_audio or muted or effects_level <= 0:
		return
	if clock - float(last_sfx.get(kind, -100.0)) < (0.12 if kind == "hit" or kind == "pickup" else 0.07):
		return
	# Drop excess sounds instead of cutting off an important warning/jingle.
	for p: AudioStreamPlayer in voices:
		if not p.playing:
			p.stream = stream("sfx/" + kind)
			p.pitch_scale = randf_range(0.95, 1.05) if kind.begins_with("step_") or kind == "hit" else 1.0
			p.volume_db = linear_to_db(maxf(effects_level * (0.18 if kind.begins_with("step_") else 0.48), 0.0001))
			p.play()
			last_sfx[kind] = clock
			return

func request_track(key: String) -> void:
	requested = key
	if requested == current_track or fade_left > 0:
		return
	active_slot = 1 - active_slot
	var p := music[active_slot]
	p.stop()
	p.volume_db = -80
	current_track = requested
	if not current_track.is_empty():
		p.stream = stream("music/" + current_track, true)
		p.play()
	fade_left = FADE

func _boss_candidate(delta: float) -> String:
	var nearest := INF
	var found := ""
	var targets: Array[Dictionary] = []
	var bosses = game.get_node_or_null("Bosses")
	if bosses != null:
		targets.append_array(bosses.targets(game.region))
	var chests = game.get_node_or_null("Chests")
	if chests != null:
		for target: Dictionary in chests.targets(game.region):
			if target.has("art"):
				targets.append(target)
	for boss: Dictionary in targets:
		var id: String = boss.get("id", boss.get("art", "H01"))
		var distance: float = game.player_foot.distance_to(boss.position)
		var inside: bool = game.player_foot.distance_to(boss.home) <= 650
		if inside and (distance <= 520 or float(boss.flash) > 0) and distance < nearest:
			found = id
			nearest = distance
	if not found.is_empty():
		engaged = found
		boss_hold = 2.5
	else:
		var living := false
		for boss: Dictionary in targets:
			living = living or str(boss.get("id", boss.get("art", ""))) == engaged
		boss_hold = maxf(0, boss_hold - delta) if living else 0.0
		if boss_hold <= 0:
			engaged = ""
	return engaged

func _observe_warnings() -> void:
	var bosses = game.get_node_or_null("Bosses")
	if bosses != null:
		for id: String in bosses.bosses:
			var b: Dictionary = bosses.bosses[id]
			if BossCatalog.DEFINITIONS[id].region == game.region:
				_observe_boss(id, b)
	var chests = game.get_node_or_null("Chests")
	if chests != null:
		for i in range(chests.regions[game.region].size()):
			var c: Dictionary = chests.regions[game.region][i]
			var key := "chest_" + str(i)
			if observed.has(key) and observed[key] != c.state:
				cue("chest" if c.state == "opened" else "warning" if c.state == "guarding" else "discovery")
			observed[key] = c.state
			if not c.boss.is_empty():
				_observe_boss(key + "boss", c.boss)
	var traps = game.get_node_or_null("Traps")
	if traps != null and traps.initialized:
		var warning: bool = not traps.hazards.is_empty()
		if warning and not observed.get("trap", false):
			cue("warning")
		observed["trap"] = warning

func _observe_boss(key: String, boss: Dictionary) -> void:
	var now := {"hp": int(boss.hp), "windup": float(boss.windup)}
	if observed.has(key):
		var old: Dictionary = observed[key]
		if old.hp > 0 and now.hp <= 0:
			cue("boss_down")
		if old.windup <= 0 and now.windup > 0:
			cue("warning")
	observed[key] = now

func _process(delta: float) -> void:
	if ready_audio:
		update_audio(minf(delta, 0.1))

func update_audio(delta: float) -> void:
	clock += delta
	var paused: bool = game._paused() or panel.visible or not game.is_processing()
	if game.region != last_region:
		last_region = game.region
		last_foot = game.player_foot
		last_health = game.health
		last_hurt = game.hurt_timer
		walked = 0
		engaged = ""
		boss_hold = 0
		observed.clear()
		for p: AudioStreamPlayer in voices:
			p.stop()
		cue("discovery")
	if not paused and not game.finished:
		var travel: float = last_foot.distance_to(game.player_foot)
		if travel < 100:
			walked += travel
		if walked >= 82:
			cue("step_" + STEPS[game.region])
			walked = fmod(walked, 82.0)
		if game.health < last_health or (game.hurt_timer > 0.9 and last_hurt <= 0.9):
			cue("hurt")
		_observe_warnings()
		var boss := _boss_candidate(delta)
		request_track("map_" + game.region if boss.is_empty() else "boss_" + boss)
	elif game.finished:
		request_track("")
	last_health = game.health
	last_hurt = game.hurt_timer
	last_foot = game.player_foot
	# Pause existing transient gameplay sounds while browsing; UI cues remain audible.
	if paused != previous_pause:
		for p: AudioStreamPlayer in voices:
			p.stop()
		previous_pause = paused
	fade_left = maxf(0, fade_left - delta)
	var blend := 1.0 - fade_left / FADE
	var level := 0.0 if muted else music_level * (0.14 if paused else 0.34)
	music[active_slot].volume_db = linear_to_db(maxf(level * sin(blend * PI / 2), 0.0001))
	music[1-active_slot].volume_db = linear_to_db(maxf(level * cos(blend * PI / 2), 0.0001))
	if fade_left <= 0:
		music[1-active_slot].stop()
		if requested != current_track:
			request_track(requested)
	var weather: String = game.states[game.region].get("weather", "")
	_update_bed(0, "amb_" + AMBIENCE[game.region], delta, paused)
	_update_bed(1, "amb_rain" if weather in ["rain", "storm"] else "amb_wind" if weather in ["wind", "snow"] else "", delta, paused)
	if not paused and not game.finished and weather == "storm" and clock - float(observed.get("thunder_at", clock)) > 14:
		cue("thunder")
		observed["thunder_at"] = clock
	elif not observed.has("thunder_at") or weather != "storm":
		observed["thunder_at"] = clock

func _update_bed(slot: int, key: String, delta: float, paused: bool) -> void:
	var p := ambient[slot]
	var base := 0.11 if slot == 0 else 0.075
	var target := 0.0 if muted or game.finished or ambient_keys[slot] != key or key.is_empty() else ambience_level * base * (0.4 if paused else 1.0)
	var value := move_toward(db_to_linear(p.volume_db), target, delta * 0.15)
	p.volume_db = linear_to_db(maxf(value, 0.0001))
	if value <= 0.0002 and ambient_keys[slot] != key:
		p.stop()
		ambient_keys[slot] = key
		if not key.is_empty():
			p.stream = stream("ambience/" + key, true)
			p.play()

func set_muted(value: bool) -> void:
	muted = value
	mute_button.text = "恢复声音" if muted else "全部静音"
	if muted:
		for p: AudioStreamPlayer in voices + music + ambient:
			p.volume_db = -80
		for p: AudioStreamPlayer in voices:
			p.stop()

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var button := UI.button("声音", func() -> void:
		if game._paused() and not panel.visible:
			return
		panel.visible = not panel.visible
		if not panel.visible:
			game.set_meta("audio_settings_open", false)
		else:
			game.set_meta("audio_settings_open", true)
	)
	button.position = Vector2(1004, 158)
	layer.add_child(button)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.06, 0.65)
	shade.hide()
	layer.add_child(shade)
	panel = PanelContainer.new()
	panel.position = Vector2(870, 215)
	panel.custom_minimum_size = Vector2(365, 280)
	panel.add_theme_stylebox_override("panel", UI.panel())
	layer.add_child(panel)
	panel.visibility_changed.connect(func() -> void: shade.visible = panel.visible)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	rows.add_child(UI.label("声音设置 · 本次游玩有效", 20))
	for setting: String in ["music", "effects", "ambience"]:
		var label := {"music": "音乐", "effects": "音效", "ambience": "环境"}
		rows.add_child(UI.label(label[setting], 17))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = get(setting + "_level")
		slider.value_changed.connect(func(value: float) -> void:
			set(setting + "_level", value)
			if setting == "effects":
				for p: AudioStreamPlayer in voices:
					p.stop()
		)
		rows.add_child(slider)
	mute_button = UI.button("全部静音", func() -> void: set_muted(not muted))
	rows.add_child(mute_button)
	rows.add_child(UI.button("收起  Esc", close_settings))
	panel.hide()
	if game.has_method("register_menu_action"):
		game.register_menu_action(button)

func close_settings() -> void:
	panel.hide()
	game.set_meta("audio_settings_open", false)

func _input(event: InputEvent) -> void:
	if panel != null and panel.visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_settings()
		get_viewport().set_input_as_handled()
