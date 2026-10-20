extends RefCounted
## Large landmarks reuse existing solid ground, keeping every road and exit intact.
const Maps = preload("res://scripts/scenes/fudi_maps.gd")
const DURATION := 60.0
const RADIUS := 100.0
const EFFECTS := {
	"haste": {"name": "顺风", "positive": true, "description": "移速 +20%", "speed": 1.2},
	"vigor": {"name": "振奋", "positive": true, "description": "JKL伤害 +25%", "attack": 1.25},
	"ward": {"name": "庇佑", "positive": true, "description": "受击伤害 -25%", "incoming": 0.75},
	"renewal": {"name": "复苏", "positive": true, "description": "每秒恢复 2 生命", "healing": 2.0},
	"heavy": {"name": "滞重", "positive": false, "description": "移速 -20%", "speed": 0.8},
	"weaken": {"name": "衰弱", "positive": false, "description": "JKL伤害 -20%", "attack": 0.8},
	"fragile": {"name": "易伤", "positive": false, "description": "受击伤害 +25%", "incoming": 1.25},
	"fatigue": {"name": "灵滞", "positive": false, "description": "技能冷却 +25%", "cooldown": 1.25},
}
const REGIONS := {
	"grove": {"name": "青岚百味大食堂", "kind": "hall", "wall": "#79654d", "roof": "#426d59", "pool": ["renewal", "vigor", "weaken", "heavy"]},
	"post": {"name": "旧城总邮驿", "kind": "gate", "wall": "#877b65", "roof": "#68675a", "pool": ["haste", "vigor", "fatigue", "fragile"]},
	"quarry": {"name": "赤岩铸造大殿", "kind": "forge", "wall": "#846349", "roof": "#704b3b", "pool": ["vigor", "ward", "heavy", "fragile"]},
	"ruins": {"name": "灵泉水镜圣所", "kind": "sanctum", "wall": "#587c87", "roof": "#3e6579", "pool": ["ward", "renewal", "fatigue", "weaken"]},
	"refuge": {"name": "归航救援总厅", "kind": "clinic", "wall": "#677c77", "roof": "#476c64", "pool": ["ward", "haste", "fragile", "heavy"]},
	"wetland": {"name": "雨灯临水长榭", "kind": "dock", "wall": "#6e7d64", "roof": "#416b65", "pool": ["renewal", "haste", "heavy", "weaken"]},
	"causeway": {"name": "断桥守望关楼", "kind": "gate", "wall": "#7f837b", "roof": "#565f66", "pool": ["haste", "ward", "fatigue", "fragile"]},
	"kilnwood": {"name": "松烟封火大窑", "kind": "kiln", "wall": "#82664c", "roof": "#574b3e", "pool": ["vigor", "renewal", "fragile", "fatigue"]},
	"archive": {"name": "镜沙星穹档案馆", "kind": "archive", "wall": "#7c718e", "roof": "#57546f", "pool": ["ward", "vigor", "weaken", "fatigue"]},
	"snowridge": {"name": "霜脊观星高台", "kind": "observatory", "wall": "#869c9d", "roof": "#607b91", "pool": ["ward", "haste", "heavy", "fragile"]},
}

static func footprint(region: String) -> Rect2:
	var ground: Rect2 = Maps.obstacles(region)[2]
	var extent := Vector2(minf(620, ground.size.x - 24), minf(140, ground.size.y - 24))
	return Rect2(Vector2(ground.get_center().x - extent.x * 0.5, ground.end.y - extent.y), extent)

static func entrance(region: String) -> Vector2:
	if Maps.Art.has_art(region):
		var door: Array = Maps.Art.layouts[region].door
		return Vector2(door[0], door[1]) * Maps.MAPS[region].size
	var rect := footprint(region)
	return Vector2(rect.get_center().x, rect.end.y + 65)

static func color(effect: String) -> Color:
	return Color("#98e7b0") if EFFECTS[effect].positive else Color("#e8a0cb")
