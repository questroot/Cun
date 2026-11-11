extends SceneTree

const Audio = preload("res://scripts/scenes/underwater_audio.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func drain(audio: Node) -> void:
	var started := Time.get_ticks_msec()
	while not audio.jobs.is_empty() and Time.get_ticks_msec() - started < 15000:
		audio._build_pending()
	check(audio.jobs.is_empty(), "synthesis did not finish")

func run() -> void:
	var audio := Audio.new()
	audio.enter("shoal")
	audio.set_tide(true)
	audio.set_oxygen(0.1)
	root.add_child(audio)
	audio.set_process(false)
	check(audio.get_child_count() == 13, "bounded owned player pool")
	audio.cue("gather")
	var cue_started := Time.get_ticks_msec()
	var cue_elapsed := 0.0
	while not audio.cache.has("cue/gather") and cue_elapsed < 0.25:
		audio._process(1.0 / 60.0)
		cue_elapsed += 1.0 / 60.0
	check(audio.cache.has("cue/gather") and audio.voices[0].playing, "first cue ready before expiry despite music queue")
	print("First-cue simulated seconds: ", cue_elapsed, "; CPU ms: ", Time.get_ticks_msec() - cue_started)
	var started := Time.get_ticks_msec()
	drain(audio)
	print("First-theme synthesis CPU ms: ", Time.get_ticks_msec() - started)
	audio._process(0.0)
	check(audio.current_track == "shoal" and audio.music[audio.active_slot].playing, "first map playback")
	audio._process(0.5)
	check(is_equal_approx(audio.fade_left, 0.5), "one-second fade midpoint")
	check(audio.ambient.playing and audio.tide.playing and audio.heartbeat.playing, "layer playback")
	check(audio.heartbeat.pitch_scale > 1.0, "low oxygen heartbeat speeds up")
	audio._process(0.5)
	for map: String in ["wreck", "trench"]:
		audio.enter(map)
		drain(audio)
		audio._process(0.0)
		check(audio.current_track == map and audio.fade_left == 1.0, "theme transition")
		check(audio.music[0].playing and audio.music[1].playing, "dual-player crossfade")
		audio._process(1.0)
		check(not audio.music[1 - audio.active_slot].playing, "outgoing player stopped")
	for event: String in audio.CUES:
		audio.cue(event)
		var elapsed := 0.0
		while not audio.cache.has("cue/" + event) and elapsed < 0.25:
			audio._process(1.0 / 60.0)
			elapsed += 1.0 / 60.0
		audio._process(0.0)
		check(elapsed < 0.25 and audio.cache.has("cue/" + event), "cold cue within expiry: " + event)
	check(audio.voices[6].playing and audio.voices[7].playing, "reserved warning voices")
	var last: float = audio.last_sfx.low
	audio._process(0.1)
	audio.cue("low")
	check(audio.last_sfx.low == last and not audio.pending_cues.has("low"), "warning rate limiting")
	audio.set_muted(true)
	for p: AudioStreamPlayer in audio.get_children():
		check(p.volume_db == -80, "immediate mute")
	for p: AudioStreamPlayer in audio.voices: check(not p.playing, "mute stops effects")
	audio.cue("critical")
	check(audio.pending_cues.is_empty(), "muted cues discarded")
	audio.enter("shoal")
	audio._process(0.0)
	audio._process(1.0)
	check(audio.current_track == "shoal" and audio.music[audio.active_slot].volume_db == -80, "map switch while muted")
	audio.set_muted(false)
	audio._process(0.2)
	check(audio.music[audio.active_slot].volume_db > -80, "unmute restores soundtrack")
	audio.set_tide(false)
	audio.set_oxygen(1.0)
	audio._process(2.0)
	check(not audio.tide.playing and not audio.heartbeat.playing, "inactive layers stop")
	var hashes := {}
	var pcm_bytes := 0
	for key: String in audio.cache:
		var sound: AudioStreamWAV = audio.cache[key]
		var data := sound.data
		pcm_bytes += data.size()
		var peak := 0
		for i in range(0, data.size(), 2): peak = maxi(peak, absi(data.decode_s16(i)))
		check(peak > 100 and peak < 32767, "nonempty unclipped PCM: " + key)
		check(data.decode_s16(0) == 0 and data.decode_s16(data.size() - 2) == 0, "click-free boundary: " + key)
		if key.begins_with("music/"):
			check(is_equal_approx(sound.get_length(), 40.0), "40-second music loop")
			check(sound.loop_mode == AudioStreamWAV.LOOP_FORWARD and sound.loop_end == 441000, "loop metadata")
			hashes[hash(data)] = true
	check(hashes.size() == 3, "three distinct original themes")
	check(pcm_bytes < 4000000, "bounded PCM cache")
	print("PCM bytes: ", pcm_bytes)
	var count: int = audio.cache.size()
	audio.enter("shoal")
	check(audio.jobs.is_empty() and audio.cache.size() == count, "revisit uses cache")
	audio.enter("unknown")
	check(audio.requested == "shoal", "unknown map ignored")
	audio.enter("")
	audio._process(0.0)
	audio._process(1.0)
	audio._process(1.0)
	check(not audio.music[0].playing and not audio.music[1].playing and not audio.ambient.playing, "surface fades to silence")
	# Flush the real mixer after the accelerated control-state checks.
	await create_timer(0.3).timeout
	var children := audio.get_children()
	audio.queue_free()
	await process_frame
	check(not is_instance_valid(audio), "controller released")
	for child in children: check(not is_instance_valid(child), "owned player released")
	# Allow the audio mixer to retire its stopped playback references before exit.
	await create_timer(0.15).timeout
	print("UNDERWATER_AUDIO_OK checks=", checks)
	quit(0)
