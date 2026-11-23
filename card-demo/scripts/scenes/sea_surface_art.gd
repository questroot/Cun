extends RefCounted
## Harbor chart symbology. Draws only; state and hit regions belong to WaterActivity.

const INK := Color("#102c38")
const SHADOW := Color("#09222c")
const GLASS := Color("#8ed6ca")
const BRASS := Color("#edc57e")
const PAPER := Color("#eee5c9")
const STEEL := Color("#799997")
const PANEL := Color("#112d39")

static func text(c: CanvasItem, pos: Vector2, caption: String, px: int, tint: Color) -> void:
	c.draw_string(ThemeDB.fallback_font, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)

static func frame(c: CanvasItem, extent: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, extent), SHADOW)
	# Information stays above the chart; only actions live on the lower console.
	c.draw_rect(Rect2(24, 8, 1232, 91), Color("#102c3b"))
	c.draw_rect(Rect2(24, 8, 4, 91), BRASS)
	text(c, Vector2(41, 29), "01   /   HARBOR WATCH", 14, BRASS)
	text(c, Vector2(41, 87), "WASD 或点击海面移动", 15, GLASS)
	for x in [237, 890]:
		c.draw_line(Vector2(x, 20), Vector2(x, 86), Color("#47616a"))
	c.draw_rect(Rect2(249, 10, 626, 35), Color("#26434b"))
	c.draw_rect(Rect2(249, 10, 3, 35), BRASS)
	text(c, Vector2(259, 34), "当前任务", 16, BRASS)
	text(c, Vector2(849, 34), "›", 22, GLASS)
	text(c, Vector2(254, 75), "港务日志", 16, GLASS)
	c.draw_line(Vector2(254, 47), Vector2(874, 47), Color("#354f59"))
	text(c, Vector2(907, 32), "值班台   /   CHART DESK", 16, GLASS)
	c.draw_rect(Rect2(24, 661, 545, 55), Color("#253c44"))
	c.draw_rect(Rect2(24, 661, 4, 55), BRASS)
	text(c, Vector2(39, 683), "出航站", 18, PAPER)
	text(c, Vector2(39, 703), "01  /  DIVE", 13, BRASS)
	c.draw_rect(Rect2(579, 661, 677, 55), PANEL)
	c.draw_rect(Rect2(579, 661, 3, 55), GLASS)
	text(c, Vector2(593, 683), "浮台后勤", 18, PAPER)
	text(c, Vector2(593, 703), "02  /  PORT", 13, GLASS)

static func location(c: CanvasItem, region: String, detail: String, number: String) -> void:
	c.draw_rect(Rect2(36, 118, 232, 65), Color("#102c38ed"))
	c.draw_rect(Rect2(36, 118, 3, 65), GLASS)
	text(c, Vector2(49, 141), region, 19, PAPER)
	text(c, Vector2(187, 139), "CH / " + number, 13, GLASS)
	c.draw_line(Vector2(49, 149), Vector2(256, 149), Color("#466563"))
	text(c, Vector2(49, 171), detail, 15, GLASS)

static func deck(c: CanvasItem, at: Vector2, dims: Vector2) -> void:
	var rect := Rect2(at, dims)
	c.draw_rect(Rect2(at + Vector2(3, 7), dims), Color("#092d38ac"))
	c.draw_rect(Rect2(at + Vector2(0, 5), dims), Color("#583f32"))
	for x in range(7,int(dims.x)-3,19):
		c.draw_line(at+Vector2(x,dims.y),at+Vector2(x,dims.y+5),Color("#b38d62"),2)
	c.draw_rect(rect, INK)
	c.draw_rect(rect.grow(-2), Color("#886b50"))
	c.draw_rect(rect.grow(-5), Color("#b6996f"))
	for y in range(10, int(dims.y)-5, 8):
		c.draw_line(at + Vector2(5, y), at + Vector2(dims.x - 5, y), Color("#867357"), 1)
	for x: float in [4.0, dims.x - 4]:
		for y: float in [4.0, dims.y - 4]:
			c.draw_circle(at + Vector2(x, y), 2.2, INK)
			c.draw_circle(at + Vector2(x, y - .5), 1.2, BRASS)

static func cast_shadow(c:CanvasItem, p:Vector2, radius:float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(p + Vector2(6+radius*cos(a),2+0.36*radius*sin(a)))
	c.draw_colored_polygon(pts, Color("#10262d70"))

static func plot(c:CanvasItem, p:Vector2, dims:Vector2, built:bool) -> void:
	deck(c,p,dims)
	if built:
		cast_shadow(c,p+Vector2(dims.x*0.5,dims.y*0.67),dims.x*0.38)
		return
	# Flagged pilings and loose framing mark a reserved footprint, not a completed house.
	var inset := Rect2(p+Vector2(14,10),dims-Vector2(28,29))
	c.draw_rect(inset,Color("#293c3b7d"))
	for x:float in [inset.position.x,inset.end.x]:
		for y:float in [inset.position.y,inset.end.y]:
			var foot:=Vector2(x,y)
			c.draw_line(foot,foot+Vector2(0,-11),INK,4)
			c.draw_circle(foot+Vector2(0,-11),2.6,BRASS)
	c.draw_line(inset.position-Vector2(0,9),Vector2(inset.end.x,inset.position.y)-Vector2(0,9),BRASS,1.6)
	c.draw_line(inset.position+Vector2(7,5),inset.end-Vector2(8,9),Color("#ddbd89"),4)
	c.draw_line(inset.position+Vector2(13,3),inset.end-Vector2(4,12),Color("#916846"),3)

static func facility(c: CanvasItem, origin: Vector2, research: bool, built: bool) -> void:
	var rect := Rect2(origin, Vector2(110, 66))
	var metal := BRASS if built else STEEL
	c.draw_rect(Rect2(origin + Vector2(2, 4), rect.size), Color("#092d38ac"))
	c.draw_rect(rect, PANEL)
	c.draw_rect(rect.grow(-1), metal, false, 1)
	c.draw_rect(Rect2(origin + Vector2(3, 2), Vector2(104, 29)), Color("#234854"))
	for dx in range(9, 104, 12):
		c.draw_line(origin + Vector2(dx, 2), origin + Vector2(dx, 30), Color("#2a525b"))
	c.draw_circle(origin + Vector2(99, 12), 3, GLASS if built else BRASS)
	text(c, origin + Vector2(7, 15), "R–01" if research else "S–02", 10, GLASS)
	var p := origin + Vector2(54, 19)
	if research:
		# Triangulation table and a brass gimballed survey dish.
		c.draw_line(p + Vector2(-12, 11), p + Vector2(-2, 3), metal, 2)
		c.draw_line(p + Vector2(7, 11), p + Vector2(-2, 3), metal, 2)
		c.draw_arc(p + Vector2(-3, -8), 11, 0, PI, 16, metal, 2, true)
		c.draw_line(p + Vector2(-14, -8), p + Vector2(8, -8), metal, 1)
		c.draw_line(p + Vector2(-3, 2), p + Vector2(8, -14), metal, 1.5)
		c.draw_circle(p + Vector2(8, -14), 2, BRASS)
	else:
		# Deck crane with an actual hook silhouette, not another building thumbnail.
		c.draw_line(p + Vector2(-19, 10), p + Vector2(0, 10), metal, 3)
		c.draw_line(p + Vector2(-13, 9), p + Vector2(-12, -7), metal, 4)
		c.draw_line(p + Vector2(-12, -7), p + Vector2(12, -14), metal, 3)
		c.draw_line(p + Vector2(-12, 5), p + Vector2(12, -14), metal, 1)
		c.draw_line(p + Vector2(12, -14), p + Vector2(12, 3), metal, 1)
		c.draw_arc(p + Vector2(9, 3), 3, 0, PI, 8, BRASS, 1.5)
	text(c, origin + Vector2(7, 46), ("研究台" if research else "打捞器") + (" · 已建" if built else " · 待建"), 13, PAPER)
	text(c, origin + Vector2(7, 62), "进入 · " + ("研究台账" if research else "作业台"), 13, GLASS)

static func shoal(c: CanvasItem, p: Vector2, wide: float) -> void:
	var shoal_shape := PackedVector2Array([p+Vector2(-wide,3), p+Vector2(-wide*.48,-4), p+Vector2(wide*.25,-7), p+Vector2(wide,0), p+Vector2(wide*.4,6), p+Vector2(-wide*.56,7)])
	c.draw_colored_polygon(shoal_shape, Color("#78969195"))
	c.draw_polyline(shoal_shape, Color("#bdc8b6a8"), 1, true)
	c.draw_line(p+Vector2(-wide*.5,0), p+Vector2(wide*.26,-5), Color("#d9d8c1bc"), 1.5)

static func hulk(c: CanvasItem, p: Vector2) -> void:
	# Ribbed, listing hulls are scenery; rust-coloured loose salvage remains distinct.
	var hull := PackedVector2Array([p+Vector2(-29,6),p+Vector2(-12,-4),p+Vector2(28,-13),p+Vector2(18,-2),p+Vector2(-11,9)])
	c.draw_colored_polygon(hull, Color("#153843"))
	c.draw_polyline(hull, STEEL, 1, true)
	for i in 4:
		var r := p + Vector2(-16+i*9,3-i*2)
		c.draw_line(r, r+Vector2(-4,-6), Color("#798581"), 1.5)
	c.draw_line(p,p+Vector2(10,-24), Color("#8c9790"), 2)
	c.draw_line(p+Vector2(10,-24),p+Vector2(22,-6), Color("#8c9790"), 1)

static func flotsam(c: CanvasItem, at: Vector2, clock: float) -> void:
	var p := at + Vector2(0, 2 * sin(clock * 1.6 + at.x))
	c.draw_arc(at + Vector2(0, 3), 21, .18, 1.08, 10, Color("#b2dccc96"), 1, true)
	c.draw_arc(at + Vector2(0, 2), 23, 2.48, 3.16, 9, Color("#b2dccc96"), 1, true)
	var plank := PackedVector2Array([p+Vector2(-21, 0), p+Vector2(12, -9), p+Vector2(21, -3), p+Vector2(20, 5), p+Vector2(-12, 13), p+Vector2(-21, 7)])
	c.draw_colored_polygon(plank, Color("#634e40"))
	c.draw_colored_polygon(PackedVector2Array([plank[0], plank[1], plank[2], p+Vector2(-13, 6)]), Color("#d5ab72"))
	c.draw_line(p+Vector2(-11,-2), p+Vector2(-4,3), BRASS, 3)
	c.draw_line(p+Vector2(-4,3), p+Vector2(-4,10), Color("#cdab77"), 3)
	c.draw_line(p+Vector2(5,-7), p+Vector2(11,-2), GLASS, 3)
	c.draw_line(p+Vector2(11,-2), p+Vector2(11,7), Color("#78aaa0"), 3)
