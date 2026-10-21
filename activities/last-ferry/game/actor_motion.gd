extends RefCounted
## Pure presentation, one instance per actor. No tree, Input, rules, save or root motion.
## step(delta, authority_position, facing, modal_frozen, carrying, event, pose, sync)
## event is a one-frame successful-action pulse: "take" / "place" / "".
## pose: "player", "standing", "walking", "dragging", "seated".
## Call reset on load/travel; sync=true is the equivalent in step. Assets are NOT supplied.
const STRIDE_DISTANCE := 72.0
const TELEPORT_DISTANCE := 80.0
const ACTION_SECONDS := 0.4
const TRANSITION_SECONDS := 0.32
var _synced := false
var _position := Vector2.ZERO
var _direction := "S"
var _phase := 0.0
var _idle_time := 0.0
var _action := ""
var _action_age := 0.0
var _transition := ""
var _transition_age := 0.0
var _pose := "player"
var _last: Dictionary = {}

func reset(position: Vector2, facing: Vector2 = Vector2.DOWN, carrying: bool = false, pose: String = "player") -> Dictionary:
	_synced = true
	_position = position
	if facing.is_finite() and facing.length_squared() > 0.0001: _direction = _face(facing)
	_phase = 0.0
	_idle_time = 0.0
	_action = ""
	_action_age = 0.0
	_transition = ""
	_transition_age = 0.0
	_pose = pose
	_last = _output(false,carrying,pose,true)
	return _last.duplicate(true)

func _face(v: Vector2) -> String:
	if absf(v.x) > absf(v.y): return "E" if v.x > 0 else "W"
	return "S" if v.y >= 0 else "N"

func step(delta: float, position: Vector2, facing: Vector2, modal_frozen: bool, carrying: bool, event: String = "", pose: String = "player", sync: bool = false) -> Dictionary:
	if not position.is_finite(): return _last.duplicate(true)
	if sync or not _synced or position.distance_to(_position) > TELEPORT_DISTANCE:
		return reset(position,facing,carrying,pose)
	var displacement := position - _position
	_position = position
	# Consume the current position even while frozen: no resume backlog/phantom steps.
	# Events are pulses and intentionally discarded while frozen, not queued.
	if modal_frozen: return _last.duplicate(true)
	var dt := clampf(delta,0.0,0.05) if is_finite(delta) else 0.0
	var moving := displacement.length_squared() > 0.0001
	if moving: _direction = _face(displacement)
	elif facing.is_finite() and facing.length_squared() > 0.0001: _direction = _face(facing)
	if moving:
		_phase = fposmod(_phase + displacement.length()/STRIDE_DISTANCE,1.0)
		_idle_time = 0.0
	else: _idle_time += dt
	# Moving cancels all upper-body actions immediately, even a same-frame pulse.
	if moving:
		_action = ""
		_transition = ""
	elif event in ["take","place"]:
		_action = event
		_action_age = 0.0
		_transition = ""
	elif not _action.is_empty():
		_action_age += dt
		if _action_age >= ACTION_SECONDS: _action = ""
	if pose != _pose:
		if not moving and _action.is_empty():
			if pose == "seated": _transition = "sit_down"
			elif _pose == "seated": _transition = "stand_up"
			else: _transition = ""
			_transition_age = 0.0
		_pose = pose
	elif not _transition.is_empty():
		_transition_age += dt
		if _transition_age >= TRANSITION_SECONDS: _transition = ""
	_last = _output(moving,carrying,pose,false)
	return _last.duplicate(true)

func _output(moving: bool, carrying: bool, pose: String, did_reset: bool) -> Dictionary:
	var clip := "carry_walk" if carrying and moving else ("carry_idle" if carrying else ("walk" if moving else "idle"))
	var count := 4 if carrying and moving else (6 if moving else (1 if carrying else 2))
	var phase := _phase if moving else fposmod(_idle_time/1.2,1.0)
	var segment := ""
	if pose == "dragging":
		clip = "drag_walk" if moving else "drag_idle"
		count = 6 if moving else 1
	elif pose == "seated":
		clip = "seated"
		count = 2
	if not _transition.is_empty():
		clip = _transition
		count = 4
		phase = minf(_transition_age/TRANSITION_SECONDS,0.99999)
	if not _action.is_empty():
		clip = "pickup" if _action == "take" else "putdown"
		count = 4
		phase = minf(_action_age/ACTION_SECONDS,0.99999)
		segment = ["stand","bend","contact","rise"][mini(3,int(phase*4+0.00001))]
	var foot := Vector2(0,24) if pose == "player" else Vector2(0,20)
	# Socket hints are relative to the unchanged authoritative actor origin.
	# Final per-frame art sockets must override these conservative placeholders.
	var hand_y := 12.0 if carrying or pose == "dragging" else 0.0
	if segment in ["bend","contact"]: hand_y = 20.0
	return {"clip":clip,"direction":_direction,"frame_index":mini(count-1,int(phase*count+0.00001)),"frame_count":count,"phase":phase,"walk_phase":_phase,"segment":segment,"moving":moving,"carrying":carrying,"foot_offset":foot,"hand_sockets":{"left":Vector2(-14,hand_y),"right":Vector2(14,hand_y)},"reset":did_reset,"requires_art":true}
