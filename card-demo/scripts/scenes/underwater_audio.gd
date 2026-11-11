extends Node
## Scene-owned, original in-memory PCM. No buses, files, downloads or save access.
const RATE := 11025
const FADE := 1.0
const SILENCE := -80.0
const MAPS := ["shoal", "wreck", "trench"]
const CUES := {"gather": 0.30, "push": 0.40, "hit": 0.25, "archive": 0.85, "surface": 0.75, "low": 0.65, "critical": 0.80}
const NOTES := [0, 7, 12, 4, 9, 7, 2, 7, 0, 4, 12, 7, 9, 2, 7, 4]
var music: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var tide: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var cache: Dictionary = {}
var jobs: Array[Dictionary] = []
var last_sfx: Dictionary = {}
var pending_cues: Dictionary = {}
var requested := ""
var current_track := ""
var active_slot := 0
var fade_left := 0.0
var clock := 0.0
var muted := false
var rising := false
var oxygen_ratio := 1.0
var music_level := 0.7
var effects_level := 0.8
var ambience_level := 0.55

func _ready() -> void:
	for i in range(2): music.append(_player())
	for i in range(8): voices.append(_player())
	ambient = _player()
	tide = _player()
	heartbeat = _player()
	_queue("bed", 4.0, true)
	_queue("tide", 4.0, true)
	_queue("heart", 1.0, true)
	if not requested.is_empty(): _queue("music/" + requested, 40.0, true)

func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = SILENCE
	add_child(p)
	return p

## shoal / wreck / trench; an empty id fades out all continuous layers.
func enter(map_id: String) -> void:
	if not map_id.is_empty() and map_id not in MAPS: return
	requested = map_id
	if is_node_ready() and not map_id.is_empty():
		_queue("music/" + map_id, 40.0, true)

func cue(event: String) -> void:
	if not is_node_ready() or muted or effects_level <= 0 or not CUES.has(event): return
	var interval := 2.5 if event in ["low", "critical"] else 0.12
	if clock - float(last_sfx.get(event, -100.0)) < interval: return
	var key := "cue/" + event
	_queue(key, float(CUES[event]), false)
	# A first request is synthesized in the next frame and expires if no voice is free.
	last_sfx[event] = clock
	pending_cues[event] = clock

func set_tide(value: bool) -> void:
	rising = value

func set_oxygen(ratio: float) -> void:
	oxygen_ratio = clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 1.0

func set_muted(value: bool) -> void:
	muted = value
	if not is_node_ready(): return
	if muted:
		for p: AudioStreamPlayer in music + voices + [ambient, tide, heartbeat]:
			p.volume_db = SILENCE
		for p: AudioStreamPlayer in voices: p.stop()
		pending_cues.clear()

func _process(delta: float) -> void:
	clock += delta
	_build_pending()
	if fade_left <= 0 and requested != current_track:
		if requested.is_empty() or cache.has("music/" + requested):
			active_slot = 1 - active_slot
			var p := music[active_slot]
			p.stop()
			p.volume_db = SILENCE
			current_track = requested
			if not current_track.is_empty():
				p.stream = cache["music/" + current_track]
				p.play()
			fade_left = FADE
	fade_left = maxf(0.0, fade_left - delta)
	var blend := 1.0 - fade_left / FADE
	var level := 0.0 if muted else music_level * 0.34
	_set_level(music[active_slot], level * sin(blend * PI * 0.5))
	_set_level(music[1 - active_slot], level * cos(blend * PI * 0.5))
	if fade_left <= 0: music[1 - active_slot].stop()
	var underwater := not requested.is_empty()
	_bed(ambient, "bed", ambience_level * 0.11 if underwater else 0.0, delta)
	_bed(tide, "tide", ambience_level * 0.075 if underwater and rising else 0.0, delta)
	heartbeat.pitch_scale = lerpf(1.8, 0.85, clampf(oxygen_ratio / 0.3, 0.0, 1.0))
	_bed(heartbeat, "heart", effects_level * lerpf(0.28, 0.10, oxygen_ratio / 0.3) if underwater and oxygen_ratio < 0.3 else 0.0, delta)
	for event: String in pending_cues.keys():
		var key := "cue/" + event
		var age := clock - float(pending_cues[event])
		if age >= 0.25 or muted:
			pending_cues.erase(event)
		elif cache.has(key):
			_play_cue(event, cache[key])
			pending_cues.erase(event)

func _play_cue(event: String, sound: AudioStreamWAV) -> void:
	var warning := event in ["low", "critical", "surface"]
	for i in range(6, 8) if warning else range(6):
		var p := voices[i]
		if not p.playing:
			p.stream = sound
			_set_level(p, effects_level * (0.40 if warning else 0.48))
			p.play()
			return

func _bed(p: AudioStreamPlayer, key: String, target: float, delta: float) -> void:
	if not p.playing and target > 0 and cache.has(key):
		p.stream = cache[key]
		p.play()
	var value := move_toward(db_to_linear(p.volume_db), 0.0 if muted else target, delta * 0.25)
	_set_level(p, value)
	if target <= 0 and value <= 0.0001: p.stop()

func _set_level(p: AudioStreamPlayer, value: float) -> void:
	p.volume_db = SILENCE if muted or value <= 0.0001 else linear_to_db(value)

func _queue(key: String, seconds: float, loop: bool) -> void:
	if cache.has(key): return
	for job: Dictionary in jobs:
		if job.key == key: return
	var frames := int(round(seconds * RATE))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var job := {"key": key, "frames": frames, "cursor": 0, "data": bytes, "loop": loop}
	# Short event cues must not wait behind a forty-second music buffer.
	if key.begins_with("cue/"): jobs.push_front(job)
	else: jobs.append(job)

func _build_pending() -> void:
	# Bound synthesis to roughly 2 ms per frame, rather than blocking scene startup.
	var deadline := Time.get_ticks_usec() + 2000
	while not jobs.is_empty() and Time.get_ticks_usec() < deadline:
		var job: Dictionary = jobs[0]
		var end := mini(int(job.cursor) + 128, int(job.frames))
		var bytes: PackedByteArray = job.data
		job.erase("data") # Keep one owner while writing, avoiding PCM copy-on-write.
		for i in range(int(job.cursor), end):
			var t := float(i) / RATE
			var value := _sample(job.key, t)
			var edge := minf(1.0, minf(t, float(job.frames - 1 - i) / RATE) / 0.012)
			bytes.encode_s16(i * 2, int(clampf(value * edge, -0.95, 0.95) * 32767.0))
		job.data = bytes
		job.cursor = end
		if end == int(job.frames):
			var sound := AudioStreamWAV.new()
			sound.format = AudioStreamWAV.FORMAT_16_BITS
			sound.mix_rate = RATE
			sound.stereo = false
			sound.data = bytes
			if job.loop:
				sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
				sound.loop_end = end
			cache[job.key] = sound
			jobs.pop_front()

func _sample(key: String, t: float) -> float:
	if key.begins_with("music/"):
		var region := key.trim_prefix("music/")
		var root := 130.8128 if region == "shoal" else 97.9989 if region == "wreck" else 65.4064
		var beat := int(t / 2.5) % 16
		var note := int(NOTES[beat]) + (0 if region == "shoal" else -2 if region == "wreck" else -5)
		var f := root * pow(2.0, float(note) / 12.0)
		var local := fmod(t, 2.5)
		var envelope := sin(PI * local / 2.5)
		var pad := sin(TAU * root * t) * 0.15 + sin(TAU * root * 1.5 * t) * 0.08
		var bell := sin(TAU * f * local) * 0.32 + sin(TAU * f * 2.0 * local) * 0.06
		return pad * pow(sin(PI * fmod(t, 10.0) / 10.0), 2.0) + bell * envelope * exp(-local * 0.65)
	if key == "bed":
		var bubble := fmod(t, 0.8)
		return 0.24 * sin(TAU * 43.0 * t) + 0.12 * sin(TAU * 67.0 * t) + 0.25 * sin(TAU * (180.0 * bubble + 240.0 * bubble * bubble)) * sin(PI * bubble / 0.8) * exp(-bubble * 7.0)
	if key == "tide":
		return (sin(TAU * 81.0 * t) * 0.27 + sin(TAU * 119.0 * t) * 0.14 + sin(TAU * 237.0 * t) * 0.08) * (0.6 + 0.4 * sin(TAU * t / 4.0))
	if key == "heart":
		var first := exp(-t * 26.0) * sin(TAU * 62.0 * t)
		var second := maxf(0.0, t - 0.18)
		return 0.65 * first + (0.45 * exp(-second * 32.0) * sin(TAU * 54.0 * second) if t >= 0.18 else 0.0)
	var event := key.trim_prefix("cue/")
	var duration := float(CUES[event])
	var x := t / duration
	var envelope := sin(PI * x) * exp(-x * 2.0)
	match event:
		"gather": return sin(TAU * (520.0 * t + 300.0 * t * t)) * envelope * 0.65
		"push": return (sin(TAU * 92.0 * t) + sin(TAU * 143.0 * t) * 0.3) * envelope * 0.6
		"hit": return (sin(TAU * (170.0 * t - 140.0 * t * t)) + sin(TAU * 613.0 * t) * 0.2) * envelope * 0.7
		"archive":
			var f: float = [392.0, 493.883, 587.33][mini(2, int(x * 3.0))]
			return sin(TAU * f * t) * envelope * 0.65
		"surface": return sin(TAU * (260.0 * t + 280.0 * t * t)) * envelope * 0.6
		"low": return sin(TAU * 330.0 * t) * pow(sin(PI * x * 2.0), 2.0) * envelope * 0.7
		"critical": return (sin(TAU * 220.0 * t) + sin(TAU * 233.0 * t) * 0.3) * pow(sin(PI * x * 3.0), 2.0) * envelope * 0.6
	return 0.0

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	jobs.clear()
	cache.clear()
