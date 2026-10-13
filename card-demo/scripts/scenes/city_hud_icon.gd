extends Control
## Compact vector icons share the city's ink, jade and warm-gold palette.
@export_enum("compass", "party", "guide", "route", "rank", "active", "passive", "chase") var kind := "compass"

func _ready() -> void:
	custom_minimum_size = Vector2(28, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var ink := Color("#204c50")
	var gold := Color("#edcf90")
	var jade := Color("#83b5a5")
	draw_circle(center, 12, ink)
	draw_arc(center, 11, 0, TAU, 28, gold, 1.4)
	match kind:
		"compass":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(5, 5), center, center + Vector2(2, 1)]), gold)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, 9), center + Vector2(-5, -5), center, center + Vector2(-2, -1)]), jade)
		"party":
			draw_circle(center + Vector2(-5, -3), 3, gold)
			draw_circle(center + Vector2(5, -3), 3, jade)
			draw_arc(center + Vector2(-5, 8), 6, PI, TAU, 12, gold, 2)
			draw_arc(center + Vector2(5, 8), 6, PI, TAU, 12, jade, 2)
		"guide":
			draw_rect(Rect2(center + Vector2(-6, -7), Vector2(12, 15)), jade)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 8), ink, 1.5)
			draw_line(center + Vector2(-4, -3), center + Vector2(-1, -3), gold, 1)
		"route":
			draw_line(center + Vector2(-7, 5), center + Vector2(6, -6), gold, 2.5)
			draw_colored_polygon(PackedVector2Array([center + Vector2(4, -8), center + Vector2(9, -8), center + Vector2(9, -3)]), gold)
		"rank":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)]), gold)
			draw_circle(center, 2, jade)
		"active":
			# 金色刃芒：主动释放。
			draw_colored_polygon(PackedVector2Array([center + Vector2(3, -9), center + Vector2(-5, 1), center + Vector2(0, 1), center + Vector2(-3, 9), center + Vector2(7, -2), center + Vector2(1, -2)]), gold)
		"passive":
			# 玉色护纹：常驻与触发类被动。
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(8, -5), center + Vector2(7, 3), center + Vector2(0, 9), center + Vector2(-7, 3), center + Vector2(-8, -5)]), jade)
			draw_line(center + Vector2(-4, 0), center + Vector2(-1, 3), gold, 2)
			draw_line(center + Vector2(-1, 3), center + Vector2(5, -4), gold, 2)
		"chase":
			# 双重弧线：独立追打类型。
			draw_arc(center + Vector2(-2, 0), 6, -PI * 0.65, PI * 0.48, 14, gold, 2.4)
			draw_colored_polygon(PackedVector2Array([center + Vector2(5, 1), center + Vector2(10, 3), center + Vector2(5, 6)]), jade)
