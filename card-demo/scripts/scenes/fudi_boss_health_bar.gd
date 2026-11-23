extends RefCounted

static func tick(boss: Dictionary, delta: float) -> void:
	if not boss.has("hp_trail") or boss.flash > 0.0:
		return
	var remaining: float = boss.hp
	boss.hp_trail = move_toward(boss.hp_trail, remaining, boss.max_hp * 1.6 * delta)
	if boss.hp_trail <= remaining:
		boss.erase("hp_trail")

static func draw(canvas: CanvasItem, bar: Rect2, boss: Dictionary, color: Color) -> void:
	var fraction: float = float(boss.hp) / boss.max_hp
	var trailing: float = float(boss.get("hp_trail", boss.hp)) / boss.max_hp
	var flash := clampf(float(boss.flash) / 0.14, 0.0, 1.0)
	var edge := color.darkened(0.35).lerp(Color("#fff1ce"), flash)
	canvas.draw_rect(bar.grow(3), Color("#13111c"))
	canvas.draw_rect(bar.grow(1), edge, false, 1.0)
	canvas.draw_rect(bar, Color("#302737"))
	if trailing > fraction:
		var lost := Rect2(bar.position + Vector2(bar.size.x * fraction, 0), Vector2(bar.size.x * (trailing - fraction), bar.size.y))
		canvas.draw_rect(lost, color.lightened(0.32).lerp(Color("#fff3d6"), flash))
	var remaining := Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y))
	canvas.draw_rect(remaining, color.darkened(0.23).lerp(color.lightened(0.35), flash))
	canvas.draw_rect(Rect2(remaining.position, Vector2(remaining.size.x, 2)), color.lightened(0.30))
