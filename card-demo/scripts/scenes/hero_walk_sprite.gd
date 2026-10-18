extends Sprite2D
## Shared exploration sprite. Call with actual movement after collision resolution.
const SHEETS := {
	"E": preload("res://assets/characters/hero/walk/walk_E.png"),
	"SE": preload("res://assets/characters/hero/walk/walk_SE.png"),
	"S": preload("res://assets/characters/hero/walk/walk_S.png"),
	"SW": preload("res://assets/characters/hero/walk/walk_SW.png"),
	"W": preload("res://assets/characters/hero/walk/walk_W.png"),
	"NW": preload("res://assets/characters/hero/walk/walk_NW.png"),
	"N": preload("res://assets/characters/hero/walk/walk_N.png"),
	"NE": preload("res://assets/characters/hero/walk/walk_NE.png"),
}
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const BASE_SCALE := 0.26
const FPS := 10.0
var facing := "S"
var walk_elapsed := 0.0
var walking := false

func _init() -> void:
	texture = SHEETS[facing]
	hframes = 4
	vframes = 2
	offset = Vector2(0, -248)
	scale = Vector2.ONE * BASE_SCALE

func update_movement(displacement: Vector2, delta: float) -> void:
	walking = displacement.length_squared() > 0.0001
	if not walking:
		walk_elapsed = 0.0
		frame = 0
		return
	var sector := posmod(roundi(displacement.angle() / (PI / 4.0)), 8)
	facing = DIRECTIONS[sector]
	texture = SHEETS[facing]
	walk_elapsed = fposmod(walk_elapsed + maxf(delta, 0.0), 8.0 / FPS)
	frame = int(walk_elapsed * FPS) % 8
