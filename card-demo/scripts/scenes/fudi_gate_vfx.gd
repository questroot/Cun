extends RefCounted

const RADIUS := 58.0
const RIPPLE_PERIOD := 3.6
const FLOW_PERIOD := 2.4
const OPEN_SECONDS := 0.82
const CLOSE_SECONDS := 0.42
const COLUMNS := 6
const RIPPLE_CELL := Vector2(144, 88)
const DOOR_CELL := Vector2(144, 152)
const RIPPLE_FRAMES := 48
const OPENING_FRAMES := 25
const FLOW_FRAMES := 36
const RIPPLE_ART := preload("res://assets/effects/fudi-pixelfx/gate-ripples.png")
const OPENING_ART := preload("res://assets/effects/fudi-pixelfx/gate-opening.png")
const FLOW_ART := preload("res://assets/effects/fudi-pixelfx/gate-flow.png")

var ripple_time := 0.0
var openings: Dictionary[String, float] = {}
var flow_times: Dictionary[String, float] = {}

func reset() -> void:
	ripple_time = 0.0
	openings.clear()
	flow_times.clear()

func tick(delta: float, exits: Array, extent: Vector2, player: Vector2) -> void:
	ripple_time = fposmod(ripple_time + delta, RIPPLE_PERIOD)
	for gate: Array in exits:
		var destination: String = gate[0]
		var on_gate := player.distance_squared_to(gate[1] * extent) <= RADIUS * RADIUS
		var amount: float = openings.get(destination, 0.0)
		var next := move_toward(amount, 1.0 if on_gate else 0.0, delta / (OPEN_SECONDS if on_gate else CLOSE_SECONDS))
		openings[destination] = next
		if next == 1.0:
			flow_times[destination] = fposmod(flow_times[destination] + delta, FLOW_PERIOD) if amount == 1.0 else 0.0
		else:
			flow_times.erase(destination)

func draw(canvas: CanvasItem, foot: Vector2, destination: String) -> void:
	var ripple := floori(ripple_time * RIPPLE_FRAMES / RIPPLE_PERIOD)
	_draw_frame(canvas, RIPPLE_ART, ripple, RIPPLE_CELL, foot, Vector2(72, 44), 1.0)
	var amount: float = openings.get(destination, 0.0)
	if amount == 1.0:
		var frame := floori(flow_times[destination] * FLOW_FRAMES / FLOW_PERIOD)
		_draw_frame(canvas, FLOW_ART, frame, DOOR_CELL, foot, Vector2(72, 126), 2.0)
	elif amount > 0.0:
		var frame := roundi(amount * (OPENING_FRAMES - 1))
		_draw_frame(canvas, OPENING_ART, frame, DOOR_CELL, foot, Vector2(72, 126), 2.0)

func _draw_frame(canvas: CanvasItem, art: Texture2D, frame: int, cell: Vector2, foot: Vector2, pivot: Vector2, scale: float) -> void:
	@warning_ignore("integer_division")
	var row := frame / COLUMNS
	var origin := Vector2(frame % COLUMNS, row) * cell
	canvas.draw_texture_rect_region(art, Rect2(foot.round() - pivot * scale, cell * scale), Rect2(origin, cell))
