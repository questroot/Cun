extends RefCounted
## Four authored moves per boss. Geometry is shared by telegraphs, damage and observations.
const MOVES := {
	"H01": [
		{"name":"断旗斩", "fx":"H01-slash", "shape":"circle", "radius":110.0, "reach":140.0, "windup":1.05, "damage":18, "cooldown":3.4, "hint":"退出红圈"},
		{"name":"破阵穿刺", "fx":"H01-thrust", "shape":"line", "radius":34.0, "reach":330.0, "windup":1.15, "damage":21, "cooldown":3.6, "hint":"向侧面躲避"},
		{"name":"血旗横扫", "fx":"H01-banner", "shape":"sector", "radius":165.0, "reach":180.0, "windup":1.3, "damage":19, "cooldown":3.8, "hint":"绕到剑士身后"},
		{"name":"回身剑轮", "fx":"H01-spin", "shape":"ring", "radius":180.0, "inner":92.0, "reach":240.0, "windup":1.5, "damage":22, "cooldown":4.2, "hint":"贴近或远离剑士"},
		{"name":"血旗三插", "fx":"H01-flag", "shape":"multi", "radius":105.0, "reach":300.0, "windup":1.45, "damage":20, "cooldown":4.0, "hint":"离开三面旗桩"}],
	"H02": [
		{"name":"荆棘践踏", "fx":"H02-stomp", "shape":"circle", "radius":120.0, "reach":160.0, "windup":1.2, "damage":16, "cooldown":3.6, "hint":"退出红圈"},
		{"name":"地脉藤枪", "fx":"H02-vine", "shape":"line", "radius":30.0, "reach":310.0, "windup":1.25, "damage":18, "cooldown":3.7, "hint":"横移避开藤枪"},
		{"name":"飞种围猎", "fx":"H02-seed", "shape":"multi", "radius":58.0, "reach":320.0, "windup":1.6, "damage":17, "cooldown":4.1, "hint":"离开三处种荚"},
		{"name":"森冠禁环", "fx":"H02-grove", "shape":"ring", "radius":190.0, "inner":95.0, "reach":250.0, "windup":1.55, "damage":20, "cooldown":4.3, "hint":"进入内圈空地"},
		{"name":"荆冠冲撞", "fx":"H02-charge", "shape":"sector", "radius":175.0, "reach":200.0, "windup":1.35, "damage":19, "cooldown":3.9, "hint":"绕至鹿骑身后"}],
	"H03": [
		{"name":"高压爆破", "fx":"H03-burst", "shape":"circle", "radius":105.0, "reach":270.0, "windup":1.4, "damage":20, "cooldown":4.0, "hint":"离开锁定落点"},
		{"name":"深潜水炮", "fx":"H03-jet", "shape":"line", "radius":42.0, "reach":370.0, "windup":1.45, "damage":23, "cooldown":4.2, "hint":"向水炮两侧移动"},
		{"name":"浮雷列阵", "fx":"H03-mine", "shape":"multi", "radius":65.0, "reach":340.0, "windup":1.8, "damage":21, "cooldown":4.5, "hint":"离开三处浮雷"},
		{"name":"逆潮冲环", "fx":"H03-tide", "shape":"ring", "radius":200.0, "inner":100.0, "reach":260.0, "windup":1.6, "damage":22, "cooldown":4.4, "hint":"贴近重装避开潮环"},
		{"name":"铁壁激流", "fx":"H03-surge", "shape":"sector", "radius":180.0, "reach":205.0, "windup":1.55, "damage":22, "cooldown":4.3, "hint":"绕到重装侧后"}],
	"H04": [
		{"name":"落羽裁决", "fx":"H04-feather", "shape":"circle", "radius":125.0, "reach":300.0, "windup":1.5, "damage":22, "cooldown":4.2, "hint":"离开羽落圈"},
		{"name":"灰翼肃清", "fx":"H04-wing", "shape":"sector", "radius":190.0, "reach":210.0, "windup":1.4, "damage":23, "cooldown":4.0, "hint":"绕至灰翼身后"},
		{"name":"十字圣枪", "fx":"H04-spears", "shape":"cross", "radius":32.0, "reach":330.0, "windup":1.65, "damage":24, "cooldown":4.5, "hint":"走进十字夹角"},
		{"name":"天秤终审", "fx":"H04-verdict", "shape":"multi", "radius":72.0, "reach":360.0, "windup":1.9, "damage":25, "cooldown":4.8, "hint":"离开三处审判落点"},
		{"name":"裁决光环", "fx":"H04-halo", "shape":"ring", "radius":185.0, "inner":100.0, "reach":260.0, "windup":1.75, "damage":24, "cooldown":4.6, "hint":"贴近或远离审判者"}],
	"H05": [
		{"name":"霜文封印", "fx":"H05-seal", "shape":"circle", "radius":100.0, "reach":360.0, "windup":1.3, "damage":18, "cooldown":3.8, "hint":"离开霜文圈"},
		{"name":"冰页穿心", "fx":"H05-icicle", "shape":"line", "radius":30.0, "reach":390.0, "windup":1.25, "damage":20, "cooldown":3.7, "hint":"侧移避开冰页"},
		{"name":"禁典十字", "fx":"H05-script", "shape":"cross", "radius":29.0, "reach":340.0, "windup":1.55, "damage":21, "cooldown":4.1, "hint":"走进符文夹角"},
		{"name":"零度书环", "fx":"H05-frost", "shape":"ring", "radius":195.0, "inner":100.0, "reach":270.0, "windup":1.7, "damage":22, "cooldown":4.4, "hint":"贴近记录者避开冰环"},
		{"name":"霜钉标记", "fx":"H05-spike", "shape":"multi", "radius":62.0, "reach":330.0, "windup":1.5, "damage":20, "cooldown":4.2, "hint":"离开三处霜钉"}],
	"H06": [
		{"name":"震钟回响", "fx":"H06-echo", "shape":"circle", "radius":150.0, "reach":190.0, "windup":1.5, "damage":20, "cooldown":4.0, "hint":"退出钟声圈"},
		{"name":"铜锤撼地", "fx":"H06-hammer", "shape":"sector", "radius":185.0, "reach":205.0, "windup":1.6, "damage":24, "cooldown":4.3, "hint":"绕至铜锤身后"},
		{"name":"锈链贯击", "fx":"H06-chain", "shape":"line", "radius":36.0, "reach":350.0, "windup":1.4, "damage":22, "cooldown":4.0, "hint":"横移避开锈链"},
		{"name":"暮钟禁域", "fx":"H06-resonance", "shape":"ring", "radius":210.0, "inner":110.0, "reach":280.0, "windup":1.8, "damage":25, "cooldown":4.6, "hint":"进入钟下安全区"},
		{"name":"钟摆十字", "fx":"H06-pendulum", "shape":"cross", "radius":33.0, "reach":320.0, "windup":1.6, "damage":23, "cooldown":4.4, "hint":"走进十字夹角"}],
}
const HALF_ANGLE := PI * 0.36
const SHAPE_NAMES := {"circle":"圆形","ring":"环形","line":"直线","sector":"扇形","multi":"多点","cross":"十字"}

static func current(boss: Dictionary) -> Dictionary:
	return MOVES[boss.id][int(boss.get("skill_index", 0)) % 5]

static func lock(boss: Dictionary, player: Vector2) -> void:
	var skill := current(boss)
	var direction: Vector2 = boss.position.direction_to(player)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	boss["direction"] = direction
	boss["cast_origin"] = boss.position
	boss.target = player if skill.shape in ["multi", "cross"] or (skill.shape == "circle" and float(skill.reach) >= 250) else boss.position
	boss["zones"] = [boss.target]
	if skill.shape == "multi":
		var side := direction.orthogonal()
		boss.zones = [boss.target, boss.target + side * 130 + direction * 45, boss.target - side * 130 + direction * 45]

static func hits(boss: Dictionary, point: Vector2) -> bool:
	var s := current(boss)
	var d: Vector2 = boss.get("direction", Vector2.RIGHT)
	var origin: Vector2 = boss.get("cast_origin", boss.position)
	var relative: Vector2 = point - boss.target
	match str(s.shape):
		"line": return point.distance_to(Geometry2D.get_closest_point_to_segment(point, origin, origin + d * float(s.reach))) <= float(s.radius)
		"cross":
			for axis: Vector2 in [d, d.orthogonal()]:
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, boss.target - axis * 180, boss.target + axis * 180)) <= float(s.radius): return true
			return false
		"sector": return relative.length() <= float(s.radius) and absf(d.angle_to(relative)) <= HALF_ANGLE
		"ring": return relative.length() <= float(s.radius) and relative.length() >= float(s.inner)
		"multi":
			for zone: Vector2 in boss.get("zones", [boss.target]):
				if point.distance_to(zone) <= float(s.radius): return true
			return false
	return relative.length() <= float(s.radius)

static func polygons(boss: Dictionary) -> Array[PackedVector2Array]:
	var s := current(boss)
	var d: Vector2 = boss.get("direction", Vector2.RIGHT)
	var origin: Vector2 = boss.get("cast_origin", boss.position)
	var result: Array[PackedVector2Array] = []
	if s.shape in ["line", "cross"]:
		var axes: Array[Vector2] = [d]
		if s.shape == "cross": axes.append(d.orthogonal())
		for axis: Vector2 in axes:
			var a: Vector2 = origin if s.shape == "line" else boss.target - axis * 180
			var b: Vector2 = origin + axis * float(s.reach) if s.shape == "line" else boss.target + axis * 180
			# Rounded capsules exactly match closest-point collision, including both caps.
			var pts := PackedVector2Array()
			for i in range(17): pts.append(b + Vector2.from_angle(axis.angle() - PI/2 + PI*i/16.0) * float(s.radius))
			for i in range(17): pts.append(a + Vector2.from_angle(axis.angle() + PI/2 + PI*i/16.0) * float(s.radius))
			result.append(pts)
	elif s.shape == "ring":
		# Annulus as quads keeps the safe center transparent.
		for i in range(64):
			var a := Vector2.from_angle(TAU*i/64.0)
			var b := Vector2.from_angle(TAU*(i+1)/64.0)
			result.append(PackedVector2Array([boss.target+a*float(s.inner),boss.target+a*float(s.radius),boss.target+b*float(s.radius),boss.target+b*float(s.inner)]))
	else:
		for zone: Vector2 in boss.get("zones", [boss.target]):
			var pts := PackedVector2Array()
			var sector: bool = s.shape == "sector"
			if sector: pts.append(zone)
			for i in range(65):
				var a: float = d.angle() - HALF_ANGLE + HALF_ANGLE*2*i/64.0 if sector else TAU*i/64.0
				pts.append(zone + Vector2.from_angle(a)*float(s.radius))
			result.append(pts)
	return result

static func bounds(boss: Dictionary) -> Rect2:
	var rect := Rect2(boss.target, Vector2.ZERO)
	for polygon: PackedVector2Array in polygons(boss):
		for p: Vector2 in polygon: rect = rect.expand(p)
	return rect

static func draw_warning(canvas: Control, boss: Dictionary) -> void:
	var s := current(boss)
	var progress := 1.0 - float(boss.windup) / float(s.windup)
	for polygon: PackedVector2Array in polygons(boss):
		canvas.draw_colored_polygon(polygon, Color(0.94,0.18,0.12,0.18+progress*0.16))
		if s.shape != "ring":
			var outline := polygon.duplicate()
			outline.append(polygon[0])
			canvas.draw_polyline(outline,Color("#ffae78"),2.0,false)
	if s.shape == "ring":
		for radius: float in [s.inner,s.radius]: canvas.draw_arc(boss.target,radius,0,TAU,64,Color("#ffae78"),2,false)
	canvas.draw_arc(boss.target,18,-PI/2,-PI/2+maxf(.02,progress*TAU),24,Color("#fff1c9"),3,false)
