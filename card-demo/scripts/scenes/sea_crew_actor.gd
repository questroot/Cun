extends Node2D
## Nautical field-guide figure. Position is the deck/sea-floor interaction point;
## plates are supersampled, but all the rig dimensions below are logical pixels.
const DECK := preload("res://assets/characters/sea_crew/deckhand.svg")
const DIVE := preload("res://assets/characters/sea_crew/diver.svg")
const COMPASS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const INK := Color("#253f3f")
const CLOTH := Color("#477b73")
const DEEP := Color("#345c59")
const BOOT := Color("#78523e")
const LIGHT := Color("#a1c4a6")
const BRASS := Color("#f5cb82")
var submerged := false:
	set(value):
		submerged = value
		queue_redraw()
var walking := false
var facing := "S"
var stride_phase := 0.0
var _heading := Vector2.DOWN
var _side := 1.0

func update_movement(displacement: Vector2, delta: float) -> void:
	var was_walking := walking
	walking = displacement.length_squared() > 0.0001
	if walking:
		_heading = displacement.normalized()
		facing = COMPASS[posmod(roundi(_heading.angle() / (PI / 4.0)), 8)]
		if absf(_heading.x) > 0.1:
			_side = signf(_heading.x)
		stride_phase = fposmod(stride_phase + maxf(delta, 0.0) * (6.6 if submerged else 10.5), TAU)
	else:
		stride_phase = 0.0
	if walking or was_walking:
		queue_redraw()

func _draw() -> void:
	var stride := sin(stride_phase) if walking else 0.0
	if submerged:
		_swimmer(stride)
	else:
		_deckhand(stride)

func _shape(points: PackedVector2Array, color: Color, width := 1.3) -> void:
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, INK, width, true)

func _deckhand(stride: float) -> void:
	var lift := absf(stride) * 1.5
	var sheet := 1 if absf(_heading.x) > 0.75 else 0
	if _heading.y < -0.36:
		sheet = 2
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_side, 1))
	_boot_leg(-5, -stride, lift, true)
	_boot_leg(4, stride, lift, false)
	var plate := Vector2(48, 60)
	var source_size := Vector2(DECK.get_size()) / Vector2(3, 1)
	draw_texture_rect_region(DECK, Rect2(Vector2(-24, -70 - lift), plate), Rect2(Vector2(sheet * source_size.x, 0), source_size))

func _boot_leg(hip: float, cycle: float, lift: float, far: bool) -> void:
	var ankle := Vector2(hip + cycle * (2 + 5 * absf(_heading.x)), -5 - maxf(0, -cycle) * 4 - (1 if far else 0))
	var knee := Vector2(hip + cycle * 3, -12 - lift)
	_shape([Vector2(hip-4,-24-lift),Vector2(hip+4,-24-lift),knee+Vector2(3,0),ankle+Vector2(2,-1),ankle+Vector2(-3,0),knee+Vector2(-4,0)], DEEP if far else CLOTH)
	var x := ankle.x
	var y := ankle.y
	_shape([Vector2(x-3,y-4),Vector2(x+3,y-5),Vector2(x+3,y),Vector2(x+6,y+1),Vector2(x+7,y+4),Vector2(x+4,y+5),Vector2(x-4,y+5),Vector2(x-4,y+2)], BOOT)
	draw_line(Vector2(x-3,y-3),Vector2(x+2.5,y-4),BRASS,1.2,true)
	draw_line(Vector2(x-3,y+3.4),Vector2(x+5,y+3.4),INK,1.2,true)

func _swimmer(stride: float) -> void:
	# Pitch the entire silhouette; even due north/south the diver keeps a trim,
	# recognisably horizontal swimming posture rather than standing on the fins.
	var pitch := _heading.y * 0.28
	var offset := Vector2(0, -19 - absf(stride))
	draw_set_transform(offset, pitch * _side, Vector2(0.91 * _side, 0.91))
	_fin_leg(Vector2(-7,2), -stride, true)
	_fin_leg(Vector2(-8,6), stride, false)
	draw_texture_rect(DIVE, Rect2(-20,-20,59,36),false)
	# A tiny pair of exhalations gives a distinct head end in dark trenches.
	for n in 2:
		var p := Vector2(30 + n*4, -17 - n*5 - absf(stride)*1.5)
		draw_arc(p, 1.6-n*.5, 0.2, TAU-.5, 12, Color("#c7eedb"), 0.95, true)

func _fin_leg(hip: Vector2, cycle: float, far: bool) -> void:
	var knee := hip + Vector2(-12, (2 if far else 5) + 2 * cycle)
	var heel := knee + Vector2(-9, (-7 if far else -3) + cycle * 5)
	_shape([hip+Vector2(1,-3),hip+Vector2(2,3),knee+Vector2(1,3),heel+Vector2(-1,2),heel+Vector2(-2,-2),knee+Vector2(0,-2)], DEEP if far else CLOTH)
	var tip := heel + Vector2(-13, (1 if far else 4) - cycle*2)
	_shape([heel+Vector2(1,-2),heel+Vector2(2,1),tip+Vector2(1,3),tip+Vector2(-1,0),tip+Vector2(-1,-2),heel+Vector2(-5,-2)], Color("#427c75") if far else Color("#69a18c"))
	draw_line(heel+Vector2(-1,-1),tip+Vector2(2,0),LIGHT,1.0,true)
	draw_line(heel+Vector2(0,-2),heel+Vector2(1,1),BRASS,1.4,true)
