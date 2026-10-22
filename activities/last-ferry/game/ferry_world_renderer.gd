extends Node2D
## Replays the one authoritative presentation command stream on its own canvas.
## The world instance is the attach_world target; UI instance lives in CanvasLayer.
var commands: Array = []
var rendered_command_count := 0

func submit(value: Array) -> void:
	commands = value
	queue_redraw()

func _draw() -> void:
	rendered_command_count = 0
	for command in commands:
		callv(command.method,command.arguments)
		rendered_command_count += 1
