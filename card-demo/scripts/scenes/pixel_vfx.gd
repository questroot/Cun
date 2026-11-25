extends RefCounted
## Native 96px cells, nearest filtering. Combat resolves damage.
const SIZE := 96
const DURATIONS := [0.09,0.07,0.05,0.10,0.08,0.08,0.10,0.13]
const LIFETIME := 0.70
const ORIGINAL_ATLAS := "res://assets/effects/pixel/%s.png"
const FUDI_ATLAS := "res://assets/effects/fudi-pixelfx/%s.png"
const CUE_ART := preload("res://assets/effects/fudi-pixelfx/warning-pattern.png")
static var textures: Dictionary = {}

## Which status aura stands for which battle effect key.
const STATUS_BY_EFFECT := {"stun": "status-stun", "shield": "status-shield", "damage_up": "status-buff", "damage_down": "status-poison"}

static func texture(key: String, use_fudi_art: bool = true) -> Texture2D:
	var cache_key := "fudi/" + key if use_fudi_art else key
	if not textures.has(cache_key):
		textures[cache_key] = load((FUDI_ATLAS if use_fudi_art else ORIGINAL_ATLAS) % key)
	return textures[cache_key]

## First active status on a battle unit, empty when nothing is applied.
static func status_for(unit) -> String:
	if unit == null:
		return ""
	for effect: String in STATUS_BY_EFFECT:
		if unit.has_effect(effect):
			return STATUS_BY_EFFECT[effect]
	return ""

static func frame_at(age: float) -> int:
	var cursor := 0.0
	for i in range(8):
		cursor += DURATIONS[i]
		if age < cursor: return i
	return 7

static func draw(canvas: CanvasItem, key: String, position: Vector2, age: float, scale: Vector2 = Vector2.ONE, angle: float = 0.0, tint: Color = Color.WHITE, loop: bool = false, use_fudi_art: bool = true) -> void:
	var art := texture(key, use_fudi_art)
	if art == null: return
	var frame: int = int(floor(age / 0.12)) % 8 if loop else frame_at(age)
	var pixel_scale := Vector2(maxf(1,roundf(scale.x)),maxf(1,roundf(scale.y)))
	canvas.draw_set_transform(position.round(),angle,pixel_scale)
	canvas.draw_texture_rect_region(art,Rect2(-Vector2.ONE*48,Vector2.ONE*SIZE),Rect2(frame*SIZE,0,SIZE,SIZE),tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_cast(canvas: Control, cast: Dictionary) -> void:
	var s: Dictionary = cast.skill
	var age: float = LIFETIME - float(cast.life)
	var angle: float = cast.direction.angle()
	if s.shape == "line":
		var center: Vector2 = cast.origin + cast.direction * float(s.reach)*.5
		draw(canvas,s.fx,center,age,Vector2(float(s.reach)/70.0,float(s.radius)/14.0),angle)
	elif s.shape == "cross":
		for axis: float in [angle, angle + PI * 0.5]:
			draw(canvas, s.fx, cast.target, age, Vector2(4, 2), axis)
	elif s.shape == "ring":
		var radius := (float(s.inner) + float(s.radius)) * 0.5
		for i in range(8):
			var heading := TAU * i / 8.0
			var point: Vector2 = cast.target + Vector2.from_angle(heading) * radius
			draw(canvas, s.fx, point, age, Vector2.ONE, heading + PI * 0.5)
	else:
		for zone: Vector2 in cast.zones:
			draw(canvas,s.fx,zone,age,Vector2.ONE*maxf(1,float(s.radius)/34.0),angle if s.shape == "sector" else 0.0)

static func cue_fill(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		uv.append(Vector2(0.04, 0.04) + (point - bounds.position) / bounds.size * 0.92)
	canvas.draw_polygon(points, PackedColorArray([color]), uv, CUE_ART)

static func cue_circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		points.append(center + Vector2.from_angle(TAU * float(i) / 48.0) * radius)
	cue_fill(canvas, points, color)

static func cue_arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, end: float, width: float, color: Color) -> void:
	var sweep := minf(end - start, TAU - 0.002)
	var steps := maxi(2, ceili(sweep * 10.0))
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(center + Vector2.from_angle(start + sweep * i / steps) * (radius + width * 0.5))
	for i in range(steps, -1, -1):
		points.append(center + Vector2.from_angle(start + sweep * i / steps) * (radius - width * 0.5))
	cue_fill(canvas, points, color)

static func cue_segment(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var side := a.direction_to(b).orthogonal() * (width * 0.5)
	cue_fill(canvas, PackedVector2Array([a + side, b + side, b - side, a - side]), color)

static func draw_weather(canvas: Control, weather: String, area: Vector2, elapsed: float, boost: float) -> void:
	var count := 36 if weather in ["rain","snow","storm"] else (9 if weather == "fog" else 18)
	count += roundi(count * boost * 0.65)
	var flash_age := fmod(elapsed, 8.0)
	for i in range(count):
		var speed := 145.0 if weather in ["rain","storm"] else (20.0 if weather == "snow" else -12.0)
		var point := Vector2(fposmod(i*137.0+elapsed*(16 if weather=="snow" else 35),area.x+160)-80,fposmod(i*79.0+elapsed*speed,area.y+110)-55)
		var scale := Vector2.ONE
		var opacity := 0.65
		if weather == "fog":
			scale = Vector2(4,2)
			opacity = 0.16
		if weather == "storm":
			# One localized flash every eight seconds, rain throughout; no full-screen strobe.
			if i == 0 and flash_age < 0.96:
				draw(canvas,"weather-storm",Vector2(area.x*.72,area.y*.24),flash_age,Vector2(2,3),0,Color(1,1,1,.7),true)
			draw(canvas,"weather-rain",point,elapsed+i*.17,Vector2.ONE,0,Color(1,1,1,0.5 + boost * 0.24),true)
		else:
			draw(canvas, "weather-" + weather, point, elapsed + i * 0.17, scale, 0, Color(1, 1, 1, opacity * (1.0 + boost * 0.45)), true)
