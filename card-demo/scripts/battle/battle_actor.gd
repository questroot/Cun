class_name BattleActor
extends Node2D
const AtlasScript = preload("res://scripts/battle/sprite_atlas.gd")
const PixelVFX = preload("res://scripts/scenes/pixel_vfx.gd")
## 独立 2D 立绘角色；在现有透明贴图上用轻量变形、位移和光效表达动作，贴图缺失时回退矢量部件。
var unit: BattleUnit
var home := Vector2.ZERO
var facing := 1.0
var pose := 0.0
var lean := 0.0
var lift := 0.0
var flash := 0.0
var stride := 0.0
var aura := 0.0
var defeated := false
var elapsed := 0.0
var body_color := Color.WHITE
var rim_color := Color.WHITE
var action_name := "idle"
var motion: Tween
var portrait: Texture2D
var impact_jolt: float = 0.0
var anticipation: float = 0.0
var cast_charge: float = 0.0

func configure(battle_unit: BattleUnit, at: Vector2) -> void:
	unit = battle_unit
	home = at
	position = at
	facing = 1.0 if unit.side == "ally" else -1.0
	body_color = unit.color
	rim_color = body_color.lightened(0.4)
	portrait = AtlasScript.pet_texture(unit.id)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if unit != null:
		queue_redraw()

func _draw() -> void:
	if unit == null:
		return
	var bob := sin(elapsed * (3.1 + float(unit.slot) * 0.13)) * 2.6 if action_name == "idle" else 0.0
	var origin := Vector2(0, bob - lift)
	var dark: Color = body_color.darkened(0.43)
	var highlight := rim_color.lerp(Color.WHITE, flash * 0.9)
	var stretch := 1.0 + pose * 0.20 - anticipation * 0.10 + impact_jolt * 0.10
	var squash := 1.0 - pose * 0.14 + anticipation * 0.11 - impact_jolt * 0.17
	var leg_swing := sin(elapsed * 13.0) * stride * 11.0
	# 影子随起跳收缩；施法光环采用角色属性色且只在动作窗口内出现。
	var shadow_width: float = 27.0 - minf(9.0, maxf(0.0, home.y - position.y) * 0.25)
	draw_ellipse_shape(Vector2(0, 5), Vector2(shadow_width, 5), Color(0.02, 0.13, 0.14, 0.27))
	if aura > 0.01:
		draw_arc(origin + Vector2(0, -37), 34.0 + aura * 8.0, 0.0, TAU, 28, Color(body_color.lightened(0.45), aura * 0.6), 2.5)
	if cast_charge > 0.01:
		var pulse: float = sin(elapsed * 24.0) * 2.0
		draw_arc(origin + Vector2(0, -37), 31.0 + cast_charge * 12.0 + pulse, -PI * 0.18, PI * 1.18, 24, Color(body_color.lightened(0.55), cast_charge * 0.8), 2.5)
	# 状态光环取当前第一个生效状态；光环只是表现，回合数仍由战斗管理器结算。
	var status_key: String = PixelVFX.status_for(unit)
	if status_key != "":
		PixelVFX.draw(self, status_key, origin + Vector2(0, -32), elapsed, Vector2.ONE, 0.0, Color(1, 1, 1, 0.8), true)
	# 只镜像角色本体，不翻转接地阴影和场景 UI；PNG 原画统一以朝右为正面。
	var t := Transform2D(Vector2(facing, 0.0), Vector2(lean * facing * 0.19, 1.0), origin + Vector2((lean * 12.0 - anticipation * 6.0 - impact_jolt * 5.0) * facing, -35 + anticipation * 5.0))
	draw_set_transform_matrix(t)
	if portrait != null:
		var dimensions := Vector2(112.0 * stretch, 112.0 * squash)
		var rect := Rect2(Vector2(-dimensions.x * 0.5, -dimensions.y * 0.74), dimensions)
		# 细微轮廓辉光沿用原画透明边缘，不另加模糊/大尺寸纹理。
		if aura > 0.1:
			var glow := Color(body_color.lightened(0.55), aura * 0.27)
			draw_texture_rect(portrait, rect.grow(3.0 + aura * 2.0), false, glow)
		draw_texture_rect(portrait, rect, false, Color(1.0, 0.84, 0.77, 1.0) if flash > 0.1 else Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	match unit.id:
		"hero":
			_draw_hero(dark, highlight, stretch, squash, leg_swing)
		"pebble", "enemy_stone":
			_draw_stone(dark, highlight, stretch, squash, leg_swing)
		"ember", "enemy_flame":
			_draw_ember(dark, highlight, stretch, squash, leg_swing)
		"mist", "enemy_wisp":
			_draw_mist(dark, highlight, stretch, squash, leg_swing)
		_:
			_draw_sprout(dark, highlight, stretch, squash, leg_swing)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _eye(at: Vector2, radius: float = 2.5) -> void:
	draw_circle(at, radius, Color("#142e36"))
	draw_circle(at + Vector2(-0.6, -0.8), 0.75, Color.WHITE)

func _limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)
	draw_circle(b, width * 0.48, color)

func _draw_hero(dark: Color, light: Color, sx: float, sy: float, swing: float) -> void:
	var forward := 1.0
	_limb(Vector2(-8, 12), Vector2(-12 + swing, 35), 10, dark)
	_limb(Vector2(8, 12), Vector2(10 - swing, 35), 10, dark)
	# 披风、躯干、围巾、头发是独立部件，随出手姿态改变。
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -19), Vector2(-24 - pose * 9, 3), Vector2(-22 - pose * 15, 19), Vector2(4, 14)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -17), Vector2(13, -17), Vector2(14 * sx, 17), Vector2(-12 * sx, 17)]), body_color)
	_limb(Vector2(-11, -13), Vector2(-19 - pose * 8, 7), 8, dark)
	_limb(Vector2(10, -12), Vector2(21 * forward + pose * 16 * forward, -12 - pose * 11), 8, body_color)
	draw_circle(Vector2(0, -30), 15.0 * sx, Color("#eac49c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -34), Vector2(-9, -48), Vector2(3, -42), Vector2(15, -48), Vector2(16, -30), Vector2(6, -36)]), dark)
	draw_line(Vector2(-11, -18), Vector2(12 + pose * 6, -13), Color("#efb571"), 6, true)
	_eye(Vector2(5 * forward, -29))
	draw_arc(Vector2(0, -5), 7.0, PI * 0.12, PI * 0.9, 10, light, 2.0)

func _draw_sprout(dark: Color, light: Color, sx: float, sy: float, swing: float) -> void:
	_limb(Vector2(-9, 12), Vector2(-15 + swing, 29), 7, dark)
	_limb(Vector2(9, 12), Vector2(15 - swing, 29), 7, dark)
	_limb(Vector2(-15, -2), Vector2(-24 - pose * 6, 4), 7, dark)
	_limb(Vector2(15, -2), Vector2(24 + pose * 14, -9), 7, dark)
	draw_ellipse_shape(Vector2(0, 0), Vector2(21 * sx, 23 * sy), body_color)
	draw_ellipse_shape(Vector2(-6, -23), Vector2(11, 5), light)
	draw_ellipse_shape(Vector2(8, -27), Vector2(12, 5), light)
	_limb(Vector2(0, -18), Vector2(pose * 8, -34), 5, dark)
	_eye(Vector2(-7, -4))
	_eye(Vector2(7, -4))

func _draw_ember(dark: Color, light: Color, sx: float, sy: float, swing: float) -> void:
	_limb(Vector2(-8, 13), Vector2(-15 + swing, 29), 8, dark)
	_limb(Vector2(8, 13), Vector2(15 - swing, 29), 8, dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -9), Vector2(-8, -28 - pose * 9), Vector2(0, -19), Vector2(8, -37 - pose * 7), Vector2(19, -7)]), Color("#ffd47c"))
	draw_circle(Vector2(0, 0), 20.0 * sx, body_color)
	_limb(Vector2(-15, -2), Vector2(-26 - pose * 5, -10), 7, dark)
	_limb(Vector2(16, -2), Vector2(26 + pose * 13, -13), 7, body_color)
	draw_circle(Vector2(0, 5), 10.0 * sy, Color(light, 0.55))
	_eye(Vector2(-7, -6))
	_eye(Vector2(7, -6))

func _draw_stone(dark: Color, light: Color, sx: float, sy: float, swing: float) -> void:
	_limb(Vector2(-12, 12), Vector2(-15 + swing, 28), 13, dark)
	_limb(Vector2(12, 12), Vector2(15 - swing, 28), 13, dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -11), Vector2(-14, -24), Vector2(12, -24), Vector2(25, -8), Vector2(18 * sx, 20), Vector2(-17 * sx, 20)]), body_color)
	_limb(Vector2(-19, -13), Vector2(-28 - pose * 4, 5), 13, dark)
	_limb(Vector2(20, -12), Vector2(29 + pose * 10, -10), 13, dark)
	draw_line(Vector2(-11, -17), Vector2(13, -17), light, 2, true)
	_eye(Vector2(-7, -6))
	_eye(Vector2(8, -6))

func _draw_mist(dark: Color, light: Color, sx: float, sy: float, swing: float) -> void:
	var sway := sin(elapsed * 4.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 9), Vector2(-25 - sway, 12), Vector2(-35 - sway, 1), Vector2(-23, -6), Vector2(-5, -11)]), Color(light, 0.62))
	_limb(Vector2(-9, 9), Vector2(-18 + swing, 27), 7, dark)
	_limb(Vector2(9, 9), Vector2(18 - swing, 27), 7, dark)
	draw_ellipse_shape(Vector2(0, -3), Vector2(22 * sx, 19 * sy), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -15), Vector2(-19, -39), Vector2(-5, -25), Vector2(3, -29), Vector2(13, -40), Vector2(15, -14)]), body_color)
	draw_ellipse_shape(Vector2(0, -3), Vector2(13, 9), Color(light, 0.62))
	_eye(Vector2(-7, -13))
	_eye(Vector2(7, -13))

func draw_ellipse_shape(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func face_toward(target_at: Vector2) -> void:
	# 同列援护不改变视线；完成动作后仍保持阵营默认的对阵方向。
	if absf(target_at.x - position.x) > 1.0:
		facing = 1.0 if target_at.x > position.x else -1.0
		queue_redraw()

func face_opponent() -> void:
	if unit != null:
		facing = 1.0 if unit.side == "ally" else -1.0
		queue_redraw()

func _stop_motion() -> void:
	if motion != null and motion.is_running():
		motion.kill()

## 独立关节蓄力 / 突进：按技能类别选择不同力度与轨迹，返回时角色停在命中前姿态。
func play_attack(kind: String, target_at: Vector2, is_support: bool = false) -> void:
	_stop_motion()
	action_name = kind
	if is_support:
		face_opponent()
	else:
		face_toward(target_at)
	var dash := clampf(absf(target_at.x - home.x) * 0.30, 32.0, 105.0)
	if is_support:
		dash = 14.0
	if kind == "ultimate":
		dash *= 0.9
	if kind == "chase":
		dash *= 1.17
	var charging: bool = kind == "ultimate" or is_support
	var windup: float = 0.19 if charging else 0.10
	motion = create_tween()
	motion.tween_property(self, "anticipation", 0.65 if charging else 1.0, windup).set_trans(Tween.TRANS_QUAD)
	motion.parallel().tween_property(self, "lean", -0.5 if charging else -0.7, windup)
	motion.parallel().tween_property(self, "aura", 1.0 if kind != "basic" else 0.45, windup)
	if charging:
		motion.parallel().tween_property(self, "cast_charge", 1.0, windup)
	if is_support:
		# 支援施法不撞向队友；向上跃起并在原位释放。
		motion.tween_property(self, "position", home + Vector2(facing * dash, -20), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		motion.tween_property(self, "position", home + Vector2(facing * dash, -17 if kind == "chase" else -8), 0.18 if kind != "chase" else 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.parallel().tween_property(self, "cast_charge", 0.0, 0.14)
	motion.parallel().tween_property(self, "anticipation", 0.0, 0.12)
	motion.parallel().tween_property(self, "pose", 0.8 if kind == "basic" else 1.0, 0.12).set_trans(Tween.TRANS_BACK)
	motion.parallel().tween_property(self, "lean", 0.8, 0.14)
	motion.parallel().tween_property(self, "stride", 0.45 if is_support else 1.0, 0.14)
	await motion.finished

## 命中时由战斗管理器结算，再播放独立受击姿态并回到站位。
func play_hit() -> void:
	_stop_motion()
	action_name = "hit"
	motion = create_tween()
	motion.tween_property(self, "position", home + Vector2(-facing * 20, -9), 0.055)
	motion.parallel().tween_property(self, "lean", -0.85, 0.055)
	motion.parallel().tween_property(self, "impact_jolt", 1.0, 0.055)
	motion.parallel().tween_property(self, "flash", 1.0, 0.055)
	motion.tween_property(self, "position", home, 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(self, "lean", 0.0, 0.19)
	motion.parallel().tween_property(self, "impact_jolt", 0.0, 0.19)
	motion.parallel().tween_property(self, "flash", 0.0, 0.19)
	await motion.finished
	face_opponent()
	action_name = "idle"

func return_home() -> void:
	_stop_motion()
	motion = create_tween()
	motion.tween_property(self, "position", home, 0.23).set_trans(Tween.TRANS_CUBIC)
	motion.parallel().tween_property(self, "pose", 0.0, 0.23)
	motion.parallel().tween_property(self, "lean", 0.0, 0.23)
	motion.parallel().tween_property(self, "aura", 0.0, 0.23)
	motion.parallel().tween_property(self, "stride", 0.0, 0.23)
	motion.parallel().tween_property(self, "anticipation", 0.0, 0.23)
	motion.parallel().tween_property(self, "impact_jolt", 0.0, 0.23)
	motion.parallel().tween_property(self, "cast_charge", 0.0, 0.23)
	await motion.finished
	face_opponent()
	action_name = "idle"

func set_defeated() -> void:
	if defeated:
		return
	defeated = true
	_stop_motion()
	action_name = "defeated"
	motion = create_tween()
	motion.tween_property(self, "rotation", -facing * 0.9, 0.28)
	motion.parallel().tween_property(self, "modulate:a", 0.35, 0.36)
