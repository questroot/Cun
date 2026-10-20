extends Node
## Opt-in player-only loopback bridge. No class_name and no game-manager calls.
const MAX_BYTES := 65536
const MAX_PEERS := 4
var _server := TCPServer.new()
var _token := ""
var _peers: Array = []
var _buttons: Dictionary = {}
var _active := false

func _ready() -> void:
	var port_text := OS.get_environment("CUN_PLAY_PORT")
	_token = OS.get_environment("CUN_PLAY_TOKEN")
	if not port_text.is_valid_int() or _token.length() < 32:
		set_process(false)
		return
	# Headless Window may report 64x64 despite project viewport settings.
	if DisplayServer.get_name() == "headless":
		var window := get_tree().root
		window.content_scale_size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)), int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var port := int(port_text)
	if port < 1 or port > 65535 or _server.listen(port, "127.0.0.1") != OK:
		push_error("AI play bridge could not bind loopback")
		set_process(false)

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var socket := _server.take_connection()
		if _peers.size() >= MAX_PEERS:
			socket.disconnect_from_host()
		else:
			_peers.append({"socket": socket, "buffer": PackedByteArray(), "since": Time.get_ticks_msec()})
	for peer in _peers.duplicate():
		if peer.get("handling", false):
			continue
		var socket: StreamPeerTCP = peer.socket
		socket.poll()
		if socket.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - peer.since > 8000:
			_drop(peer)
			continue
		var count := socket.get_available_bytes()
		if count == 0:
			continue
		if peer.buffer.size() + count > MAX_BYTES:
			_drop(peer)
			continue
		var chunk := socket.get_data(count)
		if chunk[0] != OK:
			_drop(peer)
			continue
		peer.buffer.append_array(chunk[1])
		var newline: int = peer.buffer.find(10)
		if newline >= 0:
			var request = JSON.parse_string(peer.buffer.slice(0, newline).get_string_from_utf8())
			if not request is Dictionary or request.get("token", "") != _token:
				_reply(peer, {"ok": false, "error": "unauthorized"})
				continue
			if _active:
				_reply(peer, {"ok": false, "error": "action in progress"})
				continue
			peer["handling"] = true
			_handle(peer, request)

func _drop(peer: Dictionary) -> void:
	peer.socket.disconnect_from_host()
	_peers.erase(peer)

func _reply(peer: Dictionary, value: Dictionary) -> void:
	var payload := (JSON.stringify(value) + "\n").to_utf8_buffer()
	if payload.size() > MAX_BYTES:
		payload = (JSON.stringify({"ok": false, "error": "visible UI response exceeds byte limit"}) + "\n").to_utf8_buffer()
	peer.socket.put_data(payload)
	_drop(peer)

func _blocked(node: Node) -> bool:
	var current := node
	while current:
		if current.get_meta("cun_play_blocked", false):
			return true
		current = current.get_parent()
	return false

func _blocked_input(node: Node, point: Vector2, keyboard: bool) -> bool:
	if node is Control and node.is_visible_in_tree() and _blocked(node):
		if keyboard and (not node is BaseButton or node.has_focus()):
			return true
		if not keyboard and node.get_global_rect().has_point(point):
			return true
	for child in node.get_children():
		if _blocked_input(child, point, keyboard):
			return true
	return false

func _visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect().intersection(get_viewport().get_visible_rect())
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			rect = rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect

# Return only complete laid-out lines inside the clipped scrolling text viewport.
# Complex tables/custom effects need a dedicated provider; never fall back to full text.
func _rich_visible_text(label: RichTextLabel) -> String:
	if not label.is_finished(): return ""
	if label.bbcode_enabled and ("[table" in label.text or "[img" in label.text): return ""
	var value := label.get_parsed_text()
	if label.visible_characters >= 0: value = value.left(label.visible_characters)
	var clip := _visible_rect(label)
	var style := label.get_theme_stylebox("normal")
	var origin := label.global_position+Vector2(style.get_content_margin(SIDE_LEFT),style.get_content_margin(SIDE_TOP))
	var scroll := label.get_v_scroll_bar().value
	var lines: PackedStringArray = []
	for i in range(label.get_line_count()):
		var y := origin.y+label.get_line_offset(i)-scroll
		var height := label.get_line_height(i)
		var width := label.get_line_width(i)
		if y < clip.position.y or y+height > clip.end.y: continue
		if origin.x < clip.position.x or origin.x+width > clip.end.x: continue
		var span := label.get_line_range(i)
		if span.x >= value.length(): continue
		lines.append(value.substr(span.x,mini(span.y,value.length())-span.x))
	return "".join(lines).left(4096)

func _walk(node: Node, texts: Array, buttons: Array) -> void:
	if node is Control and node.is_visible_in_tree() and _visible_rect(node).has_area():
		if node is Label or node is RichTextLabel:
			var value: String = node.text if node is Label else _rich_visible_text(node)
			if node.visible_characters >= 0:
				value = value.left(node.visible_characters)
			if not value.is_empty():
				texts.append(value.left(4096))
		if node is BaseButton:
			var id := str(node.get_instance_id())
			_buttons[id] = weakref(node)
			var rect: Rect2 = _visible_rect(node)
			buttons.append({"id": id, "text": node.text if node is Button else node.name, "disabled": node.disabled or _blocked(node), "blocked": _blocked(node), "rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}})
	for child in node.get_children():
		if texts.size() + buttons.size() > 512:
			break
		_walk(child, texts, buttons)

func _observe() -> Dictionary:
	_buttons.clear()
	var texts: Array = []
	var buttons: Array = []
	var scene := get_tree().current_scene
	if scene:
		_walk(scene, texts, buttons)
	var visible: Array = []
	for provider in get_tree().get_nodes_in_group("cun_play_visible"):
		if visible.size() >= 32:
			break
		if provider is CanvasItem and provider.is_visible_in_tree() and not _blocked(provider) and provider.has_method("play_visible"):
			# Trusted project opt-in only; no method name or arguments from caller.
			var description = provider.play_visible()
			if description is Dictionary or description is Array or description is String:
				if JSON.stringify(description).length() <= 8192:
					visible.append(description)
	return {"visible": visible, "title": ProjectSettings.get_setting("application/config/name", ""), "scene": scene.name if scene else "", "texts": texts, "buttons": buttons, "viewport": {"width": get_viewport().get_visible_rect().size.x, "height": get_viewport().get_visible_rect().size.y}}

func _handle(peer: Dictionary, request: Dictionary) -> void:
	if request.get("method") == "observe":
		_reply(peer, {"ok": true, "result": _observe()})
		return
	if request.get("method") != "action" or not request.get("params") is Dictionary:
		_reply(peer, {"ok": false, "error": "unsupported method or params"})
		return
	var args: Dictionary = request.params
	var kind = args.get("kind")
	var frames = args.get("frames", 1)
	if not (frames is int or frames is float) or frames != int(frames) or frames < 1 or frames > 120:
		_reply(peer, {"ok": false, "error": "frames must be integer 1..120"})
		return
	var down: InputEvent
	var up: InputEvent
	if kind == "click":
		_observe()
		var ref = _buttons.get(str(args.get("button_id", "")))
		var button = ref.get_ref() if ref else null
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled or _blocked(button):
			_reply(peer, {"ok": false, "error": "button not visible or enabled"})
			return
		var visible_rect := _visible_rect(button)
		if not visible_rect.has_area():
			_reply(peer, {"ok": false, "error": "button clipped outside visible UI"})
			return
		var center: Vector2 = visible_rect.get_center()
		down = _mouse(center, MOUSE_BUTTON_LEFT, true)
		up = _mouse(center, MOUSE_BUTTON_LEFT, false)
	elif kind == "key":
		var keys := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "enter": KEY_ENTER, "escape": KEY_ESCAPE, "space": KEY_SPACE, "tab": KEY_TAB, "w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "e": KEY_E, "j": KEY_J, "k": KEY_K, "l": KEY_L, "i": KEY_I, "m": KEY_M, "b": KEY_B, "c": KEY_C, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4}
		if not keys.has(args.get("key", "")):
			_reply(peer, {"ok": false, "error": "key not allowed"})
			return
		var press := InputEventKey.new()
		press.keycode = keys[args.key]
		press.physical_keycode = keys[args.key]
		press.pressed = true
		down = press
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		up = release
	elif kind == "mouse":
		var x = args.get("x")
		var y = args.get("y")
		if not (x is float or x is int) or not (y is float or y is int) or not is_finite(float(x)) or not is_finite(float(y)):
			_reply(peer, {"ok": false, "error": "invalid coordinates"})
			return
		var position := Vector2(float(x), float(y))
		if not get_viewport().get_visible_rect().has_point(position) or args.get("button", "left") not in ["left", "right", "wheel_up", "wheel_down"]:
			_reply(peer, {"ok": false, "error": "mouse outside viewport or invalid button"})
			return
		var indices := {"left":MOUSE_BUTTON_LEFT,"right":MOUSE_BUTTON_RIGHT,"wheel_up":MOUSE_BUTTON_WHEEL_UP,"wheel_down":MOUSE_BUTTON_WHEEL_DOWN}
		var index: int = indices[args.get("button", "left")]
		down = _mouse(position, index, true)
		up = _mouse(position, index, false)
	else:
		_reply(peer, {"ok": false, "error": "unsupported action"})
		return
	var scene := get_tree().current_scene
	if scene and _blocked_input(scene, down.position if down is InputEventMouseButton else Vector2.ZERO, down is InputEventKey):
		_reply(peer, {"ok": false, "error": "player mode blocks marked UI input"})
		return
	_active = true
	if down is InputEventMouseButton:
		var motion := InputEventMouseMotion.new()
		motion.position = down.position
		motion.global_position = down.position
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
	if down is InputEventMouseButton:
		get_viewport().push_input(down, true)
	else:
		Input.parse_input_event(down)
	var held_started := Time.get_ticks_usec()
	for _i in range(int(frames)):
		await get_tree().process_frame
	var held_usec := Time.get_ticks_usec() - held_started
	if up is InputEventMouseButton:
		get_viewport().push_input(up, true)
	else:
		Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	_active = false
	var observation := _observe()
	observation["input_timing"] = {"held_process_frames":int(frames),"held_wall_ms":float(held_usec)/1000.0,"clock":"process_frame; not fixed physics ticks or a guaranteed displacement"}
	_reply(peer, {"ok": true, "result": observation})

func _mouse(position: Vector2, index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = index
	event.button_mask = index if pressed else 0
	event.pressed = pressed
	return event
