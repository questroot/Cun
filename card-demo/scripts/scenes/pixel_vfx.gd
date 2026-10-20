extends RefCounted
## Native 96px cells, nearest filtering; damage is resolved by combat, never by particles.
const SIZE := 96
const DURATIONS := [0.09,0.07,0.05,0.10,0.08,0.08,0.10,0.13]
const LIFETIME := 0.70
static var textures: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if not textures.has(key): textures[key] = load("res://assets/effects/pixel/%s.png" % key)
	return textures[key]

static func frame_at(age: float) -> int:
	var cursor := 0.0
	for i in range(8):
		cursor += DURATIONS[i]
		if age < cursor: return i
	return 7

static func draw(canvas: Control, key: String, position: Vector2, age: float, scale: Vector2 = Vector2.ONE, angle: float = 0.0, tint: Color = Color.WHITE, loop: bool = false) -> void:
	var art := texture(key)
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
		draw(canvas,s.fx,cast.target,age,Vector2.ONE*4,angle)
	else:
		for zone: Vector2 in cast.zones:
			draw(canvas,s.fx,zone,age,Vector2.ONE*maxf(1,float(s.radius)/34.0),angle if s.shape == "sector" else 0.0)

static func draw_weather(canvas: Control, weather: String, area: Vector2, elapsed: float) -> void:
	var count := 36 if weather in ["rain","snow","storm"] else (9 if weather == "fog" else 18)
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
			if i == 0 and fmod(elapsed,8.0)<0.96:
				draw(canvas,"weather-storm",Vector2(area.x*.72,area.y*.24),elapsed,Vector2(2,3),0,Color(1,1,1,.7),true)
			draw(canvas,"weather-rain",point,elapsed+i*.17,Vector2.ONE,0,Color(1,1,1,.5),true)
		else: draw(canvas,"weather-"+weather,point,elapsed+i*.17,scale,0,Color(1,1,1,opacity),true)
