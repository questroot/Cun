extends RefCounted

const Maps := preload("res://scripts/scenes/fudi_maps.gd")
const GRAY := preload("res://assets/fudi/mailbox/mailbox-gray.png")
const PAINTED := preload("res://assets/fudi/mailbox/mailbox-color.png")
const FIRE := preload("res://assets/fudi/mailbox/mailbox-fire.png")
const FIRE_SIZE := Vector2(96, 96)
const FIRE_ANCHOR := Vector2(48, 86)
const IDLE_FRAMES := 18
const WAVE_FRAMES := 48
const WAVE_PERIOD := 2.5
const FIRE_COLUMNS := 6
const SCALE := 2.0
const RADIUS := 96.0
const EXPOSURE := 2.0
const BURN_TIME := 5.0
const DAMAGE_PER_SECOND := 3
const BURN_EFFECT := "status-burn"

enum Stage { IDLE, BURNING, COMPLETE }

var exposure := 0.0
var burn_left := 0.0
var wave_time := 0.0

static func stage(visited: Array) -> Stage:
	if visited[2]:
		return Stage.COMPLETE
	return Stage.BURNING if visited[0] else Stage.IDLE

func enter_region(game: Control) -> void:
	exposure = 0.0
	wave_time = 0.0
	if burn_left > 0.0:
		game.show_player_ailment(BURN_EFFECT, burn_left)

func tick(game: Control, delta: float) -> void:
	var burning: bool = game.region == "post" and stage(game.states.post.visited) == Stage.BURNING
	if burning:
		wave_time = fmod(wave_time + delta, WAVE_PERIOD)
	var near_fire: bool = burning and game.player_foot.distance_squared_to(Maps.site_position("post", 0)) <= RADIUS * RADIUS
	if not near_fire:
		exposure = 0.0
	elif exposure < EXPOSURE:
		var time_to_burn := EXPOSURE - exposure
		exposure = minf(EXPOSURE, exposure + delta)
		if exposure == EXPOSURE and burn_left <= time_to_burn:
			_tick_burn(game, time_to_burn)
			burn_left = BURN_TIME
			_tick_burn(game, delta - time_to_burn)
			if burn_left > 0.0:
				game.show_player_ailment(BURN_EFFECT, burn_left)
			return
	_tick_burn(game, delta)

func _tick_burn(game: Control, delta: float) -> void:
	if burn_left <= 0.0:
		return
	var previous := burn_left
	burn_left = maxf(0.0, burn_left - delta)
	var ticks := ceili(previous) - ceili(burn_left)
	game.health = maxi(0, game.health - ticks * DAMAGE_PER_SECOND)

func draw(canvas: CanvasItem, point: Vector2, current: Stage, idle_cycle: float) -> void:
	var wave_frame := IDLE_FRAMES + floori(wave_time * WAVE_FRAMES / WAVE_PERIOD)
	if current == Stage.BURNING:
		_draw_fire(canvas, point, wave_frame)
	var sprite := PAINTED if current == Stage.COMPLETE else GRAY
	var tint := Color("#ebc8ab") if current == Stage.BURNING else Color.WHITE
	canvas.draw_texture_rect(sprite, Rect2(point - Vector2(24, 60) * SCALE, sprite.get_size() * SCALE), false, tint)
	if current == Stage.IDLE:
		_draw_fire(canvas, point, floori(idle_cycle * IDLE_FRAMES / 1.25))
	elif current == Stage.BURNING:
		_draw_fire(canvas, point, wave_frame + WAVE_FRAMES)

static func _draw_fire(canvas: CanvasItem, point: Vector2, frame: int) -> void:
	@warning_ignore("integer_division")
	var cell := Vector2(frame % FIRE_COLUMNS, frame / FIRE_COLUMNS)
	var target := Rect2(point - FIRE_ANCHOR * SCALE, FIRE_SIZE * SCALE)
	canvas.draw_texture_rect_region(FIRE, target, Rect2(cell * FIRE_SIZE, FIRE_SIZE))
