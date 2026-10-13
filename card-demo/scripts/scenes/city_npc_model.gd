extends Node2D
## Original draw-command character silhouette: distinct head, robe, arms and staff.
@export var robe_color := Color("#426b84")
@export var hair_color := Color("#354457")
@export var carries_staff := true

func _draw() -> void:
	_draw_shadow(Vector2(0, -5), Vector2(34, 9), Color(0.02, 0.12, 0.11, 0.35))
	draw_line(Vector2(-9, -27), Vector2(-11, -7), Color("#302f41"), 9)
	draw_line(Vector2(8, -27), Vector2(11, -7), Color("#302f41"), 9)
	draw_line(Vector2(-11, -7), Vector2(-20, -6), Color("#684d42"), 5)
	draw_line(Vector2(11, -7), Vector2(20, -6), Color("#684d42"), 5)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -83), Vector2(17, -83), Vector2(27, -26), Vector2(-25, -26)]), robe_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -79), Vector2(3, -73), Vector2(-4, -30), Vector2(-17, -30)]), Color("#dfba75"))
	draw_line(Vector2(0, -78), Vector2(1, -34), Color("#d4e4d4", 0.8), 2)
	draw_line(Vector2(-22, -27), Vector2(23, -27), Color("#d5aa67"), 4)
	draw_circle(Vector2(0, -56), 5, Color("#e7d59d"))
	draw_circle(Vector2(0, -56), 2, Color("#7caaa2"))
	draw_line(Vector2(-15, -74), Vector2(-31, -44), Color("#bca28a"), 11)
	draw_line(Vector2(15, -73), Vector2(28, -48), Color("#bca28a"), 11)
	if carries_staff:
		draw_line(Vector2(28, -49), Vector2(38, -10), Color("#8b6542"), 5)
		draw_circle(Vector2(28, -53), 6, Color("#e9c78d"))
	draw_circle(Vector2(0, -101), 18, Color("#eac8a7"))
	draw_arc(Vector2(0, -101), 18, 0.1, PI - 0.1, 16, Color("#ae8472"), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -106), Vector2(-14, -125), Vector2(12, -129), Vector2(21, -106), Vector2(10, -112), Vector2(-6, -114)]), hair_color)
	draw_circle(Vector2(-5, -101), 2, Color("#253847"))
	draw_circle(Vector2(7, -101), 2, Color("#253847"))
	draw_line(Vector2(-4, -91), Vector2(6, -91), Color("#ad7b6b"), 2)
	draw_line(Vector2(-20, -73), Vector2(-12, -81), Color("#f2d595"), 3)
	draw_line(Vector2(18, -72), Vector2(12, -81), Color("#f2d595"), 3)

func _draw_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, radii)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)
