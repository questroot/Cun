extends SceneTree
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const Bosses = preload("res://scripts/scenes/boss_catalog.gd")
var checks := 0
var failures := 0
var game
var audio

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s: %s" % ["PASS" if value else "FAIL", message])

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func settle() -> void:
	for i in range(30):
		audio.update_audio(0.1)

func key(code: int) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("Cun-Audio-"):
		printerr("Audio checks require tests/audio.tests.ps1 and an isolated save directory.")
		quit(2)
		return
	var data := root.get_node("DataManager")
	data.write_save()
	var save_file: String = data.SAVE_PATH
	var before := FileAccess.get_file_as_string(save_file)
	game = load("res://scenes/Fudi.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	audio = game.get_node("Audio")
	check(audio.ready_audio and audio.music.size() == 2 and audio.voices.size() == 12, "scene-owned initialized players")
	# Keep game.is_processing true for audio decisions while preventing simulation drift.
	game.set_process(false)
	audio.set_process(false)
	game.get_node("Bosses").set_process(false)
	game.get_node("Weather").set_process(false)
	game.get_node("Traps").set_process(false)
	game.get_node("Chests").set_process(false)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	check(manifest.assets.size() == 38, "38 generated audio assets")
	for asset: Dictionary in manifest.assets:
		var sound = audio.stream(str(asset.path).trim_suffix(".wav"), asset.loop)
		check(sound != null and absf(sound.get_length() - float(asset.seconds)) < 0.002, "load/duration " + asset.id)
		if asset.loop:
			check(sound.loop_mode == AudioStreamWAV.LOOP_FORWARD and sound.loop_end > 0, "loop metadata " + asset.id)
	game.set_process(true)
	# Manual updates happen within this turn, before the engine processes gameplay.
	for id: String in Maps.IDS:
		game.enter_region(id)
		settle()
		check(audio.current_track == "map_" + id, "travel soundtrack " + id)
		check(audio.ambient_keys[0] == "amb_" + audio.AMBIENCE[id], "regional environment " + id)
	for id: String in Bosses.DEFINITIONS:
		var config: Dictionary = Bosses.DEFINITIONS[id]
		game.enter_region(config.region)
		var b: Dictionary = game.get_node("Bosses").bosses[id]
		game.player_foot = b.position + Vector2(-100, 0)
		settle()
		check(audio.current_track == "boss_" + id and audio.music[audio.active_slot].playing, "engagement " + id)
		game.player_foot = Maps.MAPS[game.region].spawn * Maps.MAPS[game.region].size
		settle()
		settle()
		check(audio.current_track == "map_" + game.region, "disengagement " + id)
	game.enter_region("grove")
	var boss: Dictionary = game.get_node("Bosses").bosses.H02
	game.player_foot = boss.position + Vector2(-100, 0)
	settle()
	boss.hp = 0
	audio.update_audio(0.1)
	check(audio.last_sfx.has("boss_down"), "boss death fanfare")
	settle()
	check(audio.current_track == "map_grove", "dead boss cannot retain combat music")
	# Surviving mutated chest boss must use its actual art identity.
	var chests = game.get_node("Chests")
	var chest: Dictionary = chests.regions.grove[0]
	chest.state = "guarding"
	chest.boss = {"art": "H05", "position": game.player_foot, "home": game.player_foot, "hp": 100, "windup": 0.0, "flash": 0.0}
	settle()
	check(audio.current_track == "boss_H05", "mutated chest boss soundtrack")
	chest.boss.hp = 0
	settle()
	check(audio.current_track == "map_grove", "chest boss death restores map")
	chest.state = "opened"
	game.states.grove.weather = "storm"
	settle()
	check(audio.ambient_keys[1] == "amb_rain", "storm rain bed")
	game.states.grove.weather = "snow"
	settle()
	check(audio.ambient_keys[1] == "amb_wind", "snow wind bed")
	audio.set_muted(true)
	check(audio.voices.all(func(p): return not p.playing), "mute immediately clears SFX")
	check((audio.music + audio.ambient).all(func(p): return p.volume_db <= -79), "mute immediately silences continuous layers")
	audio.set_muted(false)
	var sliders: Array[HSlider] = []
	for child in audio.panel.get_child(0).get_children():
		if child is HSlider:
			sliders.append(child)
	sliders[0].value = 0.23
	sliders[1].value = 0.41
	sliders[2].value = 0.37
	check(is_equal_approx(audio.music_level, .23) and is_equal_approx(audio.effects_level, .41) and is_equal_approx(audio.ambience_level, .37), "independent slider bindings")
	sliders[0].value = .7
	sliders[1].value = .8
	sliders[2].value = .55
	audio.last_sfx.clear()
	for p in audio.voices:
		p.stop()
	game.cooldowns.j = 0
	check(game.attack("j") and audio.last_sfx.has("slash"), "accepted J plays slash")
	var stamp: float = audio.last_sfx.slash
	audio.clock += 0.5
	check(not game.attack("j") and audio.last_sfx.slash == stamp, "cooldown rejection remains silent")
	game.cooldowns.k = 0
	game.attack("k")
	check(audio.last_sfx.has("cast"), "K cast cue")
	game.cooldowns.l = 0
	game.attack("l")
	check(audio.last_sfx.has("slam"), "L impact cue")
	game.states.grove.pickups.append({"item": "wood", "position": game.player_foot})
	game._collect_nearby()
	check(audio.last_sfx.has("pickup"), "actual collection cue")
	audio.panel.show()
	game.set_meta("audio_settings_open", true)
	check(game._paused() and not game.attack("j"), "sound panel pauses gameplay")
	key(KEY_C)
	check(not game.equipment.is_open(), "sound panel blocks equipment hotkey")
	key(KEY_M)
	check(not game.tools.atlas.visible, "sound panel blocks map hotkey")
	key(KEY_ESCAPE)
	check(not audio.panel.visible and not game._paused(), "Esc closes audio settings and resumes")
	for panel in [game.dialogue, game.journal, game.equipment.modal, game.tools.atlas]:
		panel.show()
		audio.update_audio(.1)
		check(game._paused() and not game.attack("k"), "modal preserves audio/gameplay pause")
		panel.hide()
	game.player_foot = Maps.MAPS.grove.spawn * Maps.MAPS.grove.size
	settle()
	# Record the real mixer output, with the game simulation frozen.
	game.set_process(false)
	await create_timer(0.2).timeout
	print("AUDIO_MIX: driver=%s track=%s playing=%s db=%.2f position=%.3f" % [AudioServer.get_driver_name(), audio.current_track, audio.music[audio.active_slot].playing, audio.music[audio.active_slot].volume_db, audio.music[audio.active_slot].get_playback_position()])
	var recorder := AudioEffectCapture.new()
	recorder.buffer_length = 1.0
	AudioServer.add_bus_effect(0, recorder)
	await create_timer(0.6).timeout
	var samples := recorder.get_buffer(recorder.get_frames_available())
	var peak := 0.0
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 4)
	for i in range(samples.size()):
		peak = maxf(peak, maxf(absf(samples[i].x), absf(samples[i].y)))
		pcm.encode_s16(i * 4, int(clampf(samples[i].x, -1, 1) * 32767))
		pcm.encode_s16(i * 4 + 2, int(clampf(samples[i].y, -1, 1) * 32767))
	check(samples.size() > AudioServer.get_mix_rate() * 0.2 and peak > 0.001, "real audio mixer produces nonzero PCM")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = int(AudioServer.get_mix_rate())
	recording.data = pcm
	recording.save_to_wav("user://audio_mix.wav")
	print("AUDIO_MIX_CAPTURE: frames=%d peak=%.6f" % [samples.size(), peak])
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	var looping: AudioStreamPlayer = audio.music[audio.active_slot]
	looping.seek(looping.stream.get_length() - 0.12)
	await create_timer(0.35).timeout
	check(looping.playing and looping.get_playback_position() < 1.0, "actual map PCM loop crosses endpoint")
	audio.request_track("boss_H04")
	for i in range(15):
		audio.fade_left = maxf(0, audio.fade_left - 0.1)
	looping = audio.music[audio.active_slot]
	looping.volume_db = -15
	looping.seek(looping.stream.get_length() - 0.12)
	await create_timer(0.35).timeout
	check(looping.playing and looping.get_playback_position() < 1.0, "actual boss PCM loop crosses endpoint")
	game.set_process(true)
	audio.clock += 2
	game._end_round(false)
	check(audio.last_sfx.has("defeat"), "defeat cue")
	settle()
	check(audio.current_track.is_empty() and audio.music.all(func(p): return not p.playing), "outcome fades music to silence")
	game.resume_exploration()
	settle()
	check(audio.current_track == "map_grove", "resume restores exploration soundtrack")
	var after := FileAccess.get_file_as_string(save_file) if FileAccess.file_exists(save_file) else ""
	check(before == after, "spirit save unchanged")
	if DisplayServer.get_name() != "headless":
		game.set_process(false)
		audio.panel.show()
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://audio_settings.png")
		print("AUDIO_CAPTURE: " + ProjectSettings.globalize_path("user://audio_settings.png"))
	game.queue_free()
	await frames()
	check(root.get_node_or_null("Fudi") == null, "audio players freed with scene")
	print("AUDIO_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
