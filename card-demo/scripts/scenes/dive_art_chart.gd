extends RefCounted
## Ink and sea-glass marks on the dive chart. All positions are visual only.
const GLASS := Color("#91e1cf")
const AMBER := Color("#f2be78")
const INK := Color("#0c2434")

static func hull(c: CanvasItem, p: Vector2) -> void:
	var wood := Color("#244451")
	c.draw_colored_polygon(PackedVector2Array([p, p + Vector2(233, 18), p + Vector2(200, 48), p + Vector2(48, 36)]), wood)
	c.draw_line(p + Vector2(11, 4), p + Vector2(228, 21), Color("#497074"), 2, true)
	c.draw_line(p + Vector2(109, 10), p + Vector2(94, -59), wood, 5, true)
	c.draw_line(p + Vector2(94, -55), p + Vector2(25, 0), Color("#3a5b65"), 1, true)
	c.draw_line(p + Vector2(94, -55), p + Vector2(188, 14), Color("#3a5b65"), 1, true)
	for i in 6:
		c.draw_circle(p + Vector2(55 + i * 25, 16 + i * 2), 3, INK)

static func water(c: CanvasItem, place: String, time: float) -> void:
	if place == "shoal":
		for i in 5:
			var x := 183.0 + i * 194.0
			c.draw_polygon(PackedVector2Array([Vector2(x,155), Vector2(x+44,155), Vector2(x-54,540), Vector2(x-110,540)]), PackedColorArray([Color("#abf3d519"), Color("#abf3d507"), Color.TRANSPARENT, Color.TRANSPARENT]))
		hull(c, Vector2(866, 253))
	elif place == "wreck":
		# Receding ribs fade into the water; the solid plates live on collision geometry.
		for i in 7:
			var p := Vector2(490 + i * 81, 240 + i * 5)
			c.draw_polyline(PackedVector2Array([p, p+Vector2(14,32), p+Vector2(32,41)]), Color("#53706c"), 4, true)
		c.draw_line(Vector2(492,278), Vector2(1010,309), Color("#807662"), 5, true)
	else:
		for j in 3:
			var line := PackedVector2Array()
			for i in 46:
				var x := 83 + i * 24
				line.append(Vector2(x, 449 + j * 6 + sin(i * 0.33 + j * 0.5) * 9))
			c.draw_polyline(line, Color("#5ebead32"), 1, true)
	# Slow marine snow; deterministic and never competes with interactable markers.
	for i in 27:
		var p := Vector2(82 + fmod(i * 181.0 + time * 2.0, 1106.0), 165 + fposmod(i * 73.0 - time * 3.0, 448.0))
		c.draw_circle(p, 1.1 if i % 3 else 1.7, Color("#acd9d052"))

static func barrier(c: CanvasItem, r: Rect2, place: String) -> void:
	var o := r.position
	var e := r.end
	if place == "shoal":
		for i in 3:
			var p := Vector2(o.x + 12 + i * 17, e.y - 8 - i * 18)
			var coral := Color("#bd947f") if i == 1 else Color("#72aa97")
			c.draw_polyline(PackedVector2Array([p, p+Vector2(-3,-21), p+Vector2(1,-35), p+Vector2(-2,-50)]), coral, 3, true)
			c.draw_polyline(PackedVector2Array([p+Vector2(-3,-21),p+Vector2(-10,-29),p+Vector2(-10,-39)]), coral, 2, true)
			c.draw_polyline(PackedVector2Array([p+Vector2(1,-35),p+Vector2(8,-41),p+Vector2(9,-52)]), coral, 2, true)
	elif place == "wreck":
		for x in range(int(o.x + 12), int(e.x - 8), 53):
			c.draw_line(Vector2(x,o.y+5), Vector2(x,e.y-5), Color("#526064"), 2)
			for y: float in [o.y+9, e.y-9]:
				c.draw_circle(Vector2(x+5,y), 2, Color("#b69a79"))
	else:
		for j in 4:
			var line := PackedVector2Array()
			for i in 36:
				var y := r.size.y * (0.2 + j * 0.18) + sin(i * 0.47 + j) * 7 + cos(i * 0.82) * 4
				line.append(o + Vector2(4 + (r.size.x - 8) * i / 35.0, y))
			c.draw_polyline(line, Color("#455675"), 2, true)

static func beacon(c: CanvasItem, p: Vector2, radius: float, time: float) -> void:
	var top := 155.0
	c.draw_polygon(PackedVector2Array([Vector2(p.x-23,top), Vector2(p.x+23,top), p+Vector2(9,0), p-Vector2(9,0)]), PackedColorArray([Color("#b7f9dc09"),Color("#b7f9dc09"),Color("#93ecd759"),Color("#93ecd759")]))
	c.draw_arc(p, radius, 0, TAU, 56, Color("#91e1cf99"), 1.5, true)
	for i in 4:
		var a := i * PI / 2.0
		c.draw_arc(p,radius,a-0.13,a+0.13,8,GLASS,3,true)
	c.draw_circle(p, 18, INK)
	c.draw_arc(p, 18, 0, TAU, 32, GLASS, 2, true)
	for i in 2:
		var v := p + Vector2(0, 3 + i*7 - sin(time*2.0)*1.5)
		c.draw_polyline(PackedVector2Array([v+Vector2(-7,0),v+Vector2(0,-7),v+Vector2(7,0)]), GLASS, 2.5, true)

static func hud(c: CanvasItem, field: Rect2, place: String) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(52, 9, 1166, 140), Color("#102b38"))
	c.draw_rect(Rect2(52, 9, 258, 65), Color("#23424a"))
	c.draw_rect(Rect2(52, 9, 4, 65), AMBER)
	c.draw_string(font, Vector2(74, 32), "潜区  /  DIVE STATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AMBER)
	for item in [[345, "供氧   O₂"], [612, "网袋   [B]"], [780, "潮汐   TIDE"]]:
		var x := float(item[0])
		c.draw_line(Vector2(x - 17, 19), Vector2(x - 17, 66), Color("#395760"))
		c.draw_string(font, Vector2(x, 32), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GLASS)
	c.draw_line(Vector2(70, 76), Vector2(1200, 76), Color("#395760"))
	c.draw_rect(Rect2(52, 635, 1166, 80), Color("#102b38"))
	c.draw_rect(Rect2(52, 635, 132, 80), Color("#24434a"))
	c.draw_string(font, Vector2(69, 660), "行动指引", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, AMBER)
	c.draw_string(font, Vector2(69, 683), "WASD / 点击", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GLASS)
	c.draw_string(font, Vector2(69, 704), "方向键移动", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GLASS)
	var index := {"shoal":"01", "wreck":"02", "trench":"03"}
	c.draw_rect(Rect2(76, 160, 232, 23), INK)
	c.draw_string(ThemeDB.fallback_font, Vector2(82,177), "测绘 " + str(index[place]) + "   /   斜纹为不可通行区", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GLASS)
	for i in 23:
		var x := field.position.x + field.size.x * i / 22.0
		c.draw_line(Vector2(x,field.end.y+1),Vector2(x,field.end.y+(6 if i%2 == 0 else 3)),Color("#608d94"),1)
