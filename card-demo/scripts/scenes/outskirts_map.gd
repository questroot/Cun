extends Node2D
## Companion region using the same jade, warm stone and ink palette as the city.
func _draw() -> void:
	var world_art := load("res://assets/backgrounds/menu_pet_garden.png") as Texture2D
	if world_art != null:
		draw_texture_rect(world_art, Rect2(0, 0, 1280, 720), false, Color("#cde6d5"))
	else:
		draw_rect(Rect2(0, 0, 1280, 720), Color("#b4d8cc"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 353), Vector2(135, 261), Vector2(297, 347), Vector2(449, 248), Vector2(646, 344), Vector2(851, 253), Vector2(1069, 342), Vector2(1280, 249), Vector2(1280, 460), Vector2(0, 460)]), Color("#72a992"))
	draw_rect(Rect2(0, 345, 1280, 375), Color("#88ad8c"))
	draw_rect(Rect2(58, 340, 1155, 315), Color("#bdd2a7"))
	draw_colored_polygon(PackedVector2Array([Vector2(48, 493), Vector2(545, 445), Vector2(1208, 456), Vector2(1210, 647), Vector2(539, 619), Vector2(48, 635)]), Color("#d6c3a2"))
	for x in range(132, 1200, 65):
		for y in range(476, 625, 40):
			draw_line(Vector2(x, y), Vector2(x + 23, y + 3), Color("#bda687", 0.55), 2)
	for x in [110, 268, 470, 691, 915, 1133]:
		draw_line(Vector2(x, 385), Vector2(x, 451), Color("#4b7169"), 7)
		draw_circle(Vector2(x, 361), 35, Color("#39755f"))
		draw_circle(Vector2(x + 18, 348), 27, Color("#59a080"))
		draw_circle(Vector2(x - 16, 359), 22, Color("#79ad88"))
	for x in range(122, 1180, 112):
		draw_circle(Vector2(x, 669), 13, Color("#5e986f"))
		draw_circle(Vector2(x + 9, 665), 5, Color("#f0c782"))
	draw_rect(Rect2(58, 480, 58, 155), Color("#edce8d", 0.66))
	draw_rect(Rect2(58, 480, 58, 155), Color("#527970"), false, 3)
	# 海底水世界改由游戏选择进入，原水门绘制保留但停用。
	# var portal := Rect2(1000, 500, 88, 115)
	# draw_circle(portal.get_center(), 72, Color("#45c6d2", 0.22))
	# draw_rect(portal.grow(6), Color("#e7d3a4"))
	# draw_rect(portal, Color("#146d80"))
	# draw_arc(portal.get_center(), 37, 0, TAU, 48, Color("#9ff1ee"), 7)
	# draw_circle(portal.get_center(), 18, Color("#d0fcf3", 0.8))
