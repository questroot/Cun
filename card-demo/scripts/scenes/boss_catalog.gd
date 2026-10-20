extends RefCounted
## Runtime names and placements inferred from the supplied silhouettes; not NPC identities.
const SKILLS = preload("res://scripts/scenes/boss_skills.gd").MOVES
const DEFINITIONS := {
	"H01": {"name": "残旗剑士", "region": "causeway", "point": Vector2(0.73, 0.368), "hp": 240, "damage": 18, "speed": 72.0, "reach": 140.0, "radius": 110.0, "windup": 1.05, "cooldown": 3.4, "skill": "断旗斩", "drop": "iron", "count": 3, "color": "#e38e77"},
	"H02": {"name": "荆冠鹿骑", "region": "grove", "point": Vector2(0.78, 0.39), "hp": 220, "damage": 16, "speed": 80.0, "reach": 160.0, "radius": 120.0, "windup": 1.2, "cooldown": 3.6, "skill": "荆棘践踏", "drop": "resin", "count": 3, "color": "#cbad6f"},
	"H03": {"name": "沉潜重装", "region": "refuge", "point": Vector2(0.72, 0.619), "hp": 300, "damage": 20, "speed": 55.0, "reach": 270.0, "radius": 105.0, "windup": 1.4, "cooldown": 4.0, "skill": "高压爆破", "drop": "copper", "count": 3, "color": "#8ec7aa"},
	"H04": {"name": "灰翼审判者", "region": "snowridge", "point": Vector2(0.84, 0.76), "hp": 340, "damage": 22, "speed": 78.0, "reach": 300.0, "radius": 125.0, "windup": 1.5, "cooldown": 4.2, "skill": "落羽裁决", "drop": "spirit_stone", "count": 2, "color": "#e4d4ac"},
	"H05": {"name": "霜典记录者", "region": "archive", "point": Vector2(0.66, 0.443), "hp": 260, "damage": 18, "speed": 60.0, "reach": 360.0, "radius": 100.0, "windup": 1.3, "cooldown": 3.8, "skill": "霜文封印", "drop": "memory_sand", "count": 3, "color": "#9bddf1"},
	"H06": {"name": "锈钟守望者", "region": "quarry", "point": Vector2(0.72, 0.31), "hp": 280, "damage": 20, "speed": 50.0, "reach": 190.0, "radius": 150.0, "windup": 1.5, "cooldown": 4.0, "skill": "震钟回响", "drop": "ore", "count": 4, "color": "#d3bd79"},
}
const ART := {
	"H01": preload("res://assets/characters/bosses/H01.png"),
	"H02": preload("res://assets/characters/bosses/H02.png"),
	"H03": preload("res://assets/characters/bosses/H03.png"),
	"H04": preload("res://assets/characters/bosses/H04.png"),
	"H05": preload("res://assets/characters/bosses/H05.png"),
	"H06": preload("res://assets/characters/bosses/H06.png"),
}
