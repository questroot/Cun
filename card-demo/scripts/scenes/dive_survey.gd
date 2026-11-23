extends RefCounted
## Shared between collision / interactions and the harbor's read-only survey sheets.
const FIELD := Rect2(70, 155, 1130, 470)

static func obstacles(place: String, narrow_wreck: bool = false) -> Array[Rect2]:
	match place:
		"shoal": return [Rect2(430, 155, 65, 190), Rect2(430, 435, 65, 190)]
		"wreck": return [Rect2(390, 155, 90, 300 if narrow_wreck else 280), Rect2(390, 535, 90, 90), Rect2(480, 155, 570, 70), Rect2(480, 555, 570, 70)]
		"trench": return [Rect2(70, 155, 1130, 175), Rect2(70, 490, 1130, 135), Rect2(960, 155, 240, 470)]
	return []

static func sites(place: String) -> Array:
	match place:
		"shoal": return [["光迹", Vector2(650, 390)], ["船尾航路", Vector2(1080, 490)], ["上浮出口", Vector2(145, 520)]]
		"wreck": return [["声呐台", Vector2(720, 375)], ["海沟入口", Vector2(1080, 480)], ["返回浅滩", Vector2(145, 490)], ["上浮出口", Vector2(1100, 290)]]
		"trench": return [["回声核心", Vector2(875, 410)], ["返回沉船", Vector2(145, 410)], ["上浮出口", Vector2(350, 410)]]
	return []
