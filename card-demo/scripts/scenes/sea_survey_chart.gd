extends Control
const Survey = preload("res://scripts/scenes/dive_survey.gd")
const Dive = preload("res://scripts/scenes/underwater_catalog.gd")
const GLASS := Color("9cd5cb")
const BRASS := Color("ffd386")
var place := "shoal"
var tiles := 1
var drift: Array = []
var harbor := Rect2(72, 238, 744, 414)

func _ink(at: Vector2, text: String, tint: Color, px: int = 15) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)

func _draw() -> void:
	if place == "water_activity":
		_draw_harbor()
		return
	var field := Survey.FIELD
	var unit := minf((size.x - 80) / field.size.x, (size.y - 104) / field.size.y)
	if unit <= 0: return
	var paper := Rect2((size - field.size * unit) * 0.5, field.size * unit)
	var origin := paper.position - field.position * unit
	draw_rect(Rect2(Vector2.ZERO, size), Color("102832"))
	draw_rect(paper, Color("244751"))
	# Survey grid uses the same unit and origin on both axes.
	for i in range(7):
		var x := paper.position.x + i * paper.size.x / 6
		draw_line(Vector2(x, paper.position.y), Vector2(x, paper.end.y), Color("416169"))
		if i < 6: _ink(Vector2(x + 5, paper.position.y - 7), String.chr(65 + i), GLASS, 12)
	for i in range(5):
		var y := paper.position.y + i * paper.size.y / 4
		draw_line(Vector2(paper.position.x, y), Vector2(paper.end.x, y), Color("416169"))
		if i < 4: _ink(Vector2(paper.position.x - 20, y + 16), str(i + 1), GLASS, 12)
	for rock in Survey.obstacles(place):
		var r := Rect2(origin + rock.position * unit, rock.size * unit)
		draw_rect(r, Color("38474a"))
		draw_rect(r, Color("8b9789"), false, 1)
		for x in range(2, int(r.size.x) - 4, 10):
			draw_line(r.position + Vector2(x, 2), r.position + Vector2(x + 4, 7), Color("788581"))
	for node in Dive.NODES[place]:
		var p: Vector2 = origin + Vector2(node[2]) * unit
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), GLASS)
	for site in Survey.sites(place):
		var p: Vector2 = origin + Vector2(site[1]) * unit
		var ascent: bool = site[0] == "上浮出口"
		var tint := Color("a6f6c8") if ascent else BRASS
		if ascent:
			draw_arc(p, Dive.SAFETY_RADIUS * unit, 0, TAU, 48, tint, 1, true)
		draw_circle(p, 4, tint)
		var label_at := Vector2(clampf(p.x - 22, paper.position.x + 2, paper.end.x - 68), p.y - 9)
		_ink(label_at, site[0], tint, 15)
	draw_rect(paper, GLASS, false, 1)
	var bar := Vector2(paper.position.x, paper.end.y + 23)
	draw_line(bar, bar + Vector2(100 * unit, 0), GLASS, 3)
	_ink(bar + Vector2(100 * unit + 9, 5), "100 场景单位", GLASS, 13)
	_ink(Vector2(paper.end.x - 76, bar.y + 5), "↑  图上方", GLASS, 13)

func _draw_harbor() -> void:
	var scale_by := minf((size.x - 50) / harbor.size.x, (size.y - 30) / harbor.size.y)
	if scale_by <= 0: return
	var paper := Rect2((size - harbor.size * scale_by) / 2, harbor.size * scale_by)
	var origin := paper.position - harbor.position * scale_by
	draw_rect(Rect2(Vector2.ZERO, size), Color("102832"))
	draw_rect(paper, Color("245161"))
	for i in range(1, 8):
		var x := paper.position.x + i * paper.size.x / 8
		draw_line(Vector2(x, paper.position.y), Vector2(x, paper.end.y), Color("396371"))
	for i in range(1, 5):
		var y := paper.position.y + i * paper.size.y / 5
		draw_line(Vector2(paper.position.x, y), Vector2(paper.end.x, y), Color("396371"))
	for point: Vector2 in drift:
		draw_circle(origin + point * scale_by, 3.5, GLASS)
	for i in tiles:
		var tile := Vector2(360 + (i % 4) * 81, 374 + floori(i / 4.0) * 78)
		var rect := Rect2(origin + tile * scale_by, Vector2(72, 68) * scale_by)
		draw_rect(rect, Color("946c47"))
		draw_rect(rect, BRASS, false, 1)
	_ink(origin + Vector2(360, 374) * scale_by - Vector2(0, 4), "甲板", BRASS)
	for site in [[Vector2(242, 264), "研究站位"], [Vector2(612, 264), "打捞机位"]]:
		var pos: Vector2 = origin + Vector2(site[0]) * scale_by
		draw_rect(Rect2(pos, Vector2(110, 66) * scale_by), Color("538081"))
		_ink(pos + Vector2(2, 17), site[1], Color.WHITE)
	draw_rect(paper, GLASS, false, 1)
