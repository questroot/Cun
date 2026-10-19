extends RefCounted
## Round-only equipment loot, based on the supplied three sets and five weapons.
const MONSTER_CHANCE := 0.35
const BASE_ITEMS := {
	"s1-top": {"name": "追归上衣", "color": "#98c6a8", "icon": preload("res://assets/items/s1-top.png")},
	"s1-legs": {"name": "追归长裤", "color": "#98c6a8", "icon": preload("res://assets/items/s1-legs.png")},
	"s1-boots": {"name": "追归战靴", "color": "#98c6a8", "icon": preload("res://assets/items/s1-boots.png")},
	"s1-necklace": {"name": "追归项链", "color": "#98c6a8", "icon": preload("res://assets/items/s1-necklace.png")},
	"s1-ring": {"name": "追归戒指", "color": "#98c6a8", "icon": preload("res://assets/items/s1-ring.png")},
	"s2-top": {"name": "烽炉胸甲", "color": "#edb079", "icon": preload("res://assets/items/s2-top.png")},
	"s2-legs": {"name": "烽炉护腿", "color": "#edb079", "icon": preload("res://assets/items/s2-legs.png")},
	"s2-boots": {"name": "烽炉战靴", "color": "#edb079", "icon": preload("res://assets/items/s2-boots.png")},
	"s2-necklace": {"name": "烽炉项链", "color": "#edb079", "icon": preload("res://assets/items/s2-necklace.png")},
	"s2-ring": {"name": "烽炉戒指", "color": "#edb079", "icon": preload("res://assets/items/s2-ring.png")},
	"s3-top": {"name": "镜潮长衣", "color": "#a8dff2", "icon": preload("res://assets/items/s3-top.png")},
	"s3-legs": {"name": "镜潮长裤", "color": "#a8dff2", "icon": preload("res://assets/items/s3-legs.png")},
	"s3-boots": {"name": "镜潮战靴", "color": "#a8dff2", "icon": preload("res://assets/items/s3-boots.png")},
	"s3-necklace": {"name": "镜潮项链", "color": "#a8dff2", "icon": preload("res://assets/items/s3-necklace.png")},
	"s3-ring": {"name": "镜潮戒指", "color": "#a8dff2", "icon": preload("res://assets/items/s3-ring.png")},
	"w01-ashen-echo": {"name": "灰烬回响", "color": "#ddd0a1", "icon": preload("res://assets/items/w01-ashen-echo.png")},
	"w02-ruinsplitter": {"name": "裂墟重刃", "color": "#edb079", "icon": preload("res://assets/items/w02-ruinsplitter.png")},
	"w03-prism-saber": {"name": "棱光长刀", "color": "#a8dff2", "icon": preload("res://assets/items/w03-prism-saber.png")},
	"w05-bone-halberd": {"name": "骨枝长戟", "color": "#98c6a8", "icon": preload("res://assets/items/w05-bone-halberd.png")},
	"w06-falling-crag": {"name": "坠岩重锤", "color": "#edb079", "icon": preload("res://assets/items/w06-falling-crag.png")},
}
const MUTATION_SCALE := 1.3
static var ITEMS: Dictionary = _all_items()

static func _all_items() -> Dictionary:
	var result := BASE_ITEMS.duplicate(true)
	for id: String in BASE_ITEMS:
		var upgraded: Dictionary = BASE_ITEMS[id].duplicate()
		upgraded.name = "异变·" + str(upgraded.name)
		upgraded.color = "#daabff"
		upgraded["base_item"] = id
		upgraded["stat_scale"] = MUTATION_SCALE
		result[id + "@mutated"] = upgraded
	return result

static func base_item(item: String) -> String:
	return str(ITEMS[item].get("base_item", item)) if ITEMS.has(item) else item

const SETS := {
	"s1": ["s1-top", "s1-legs", "s1-boots", "s1-necklace", "s1-ring"],
	"s2": ["s2-top", "s2-legs", "s2-boots", "s2-necklace", "s2-ring"],
	"s3": ["s3-top", "s3-legs", "s3-boots", "s3-necklace", "s3-ring"],
}
const REGIONS := {
	"grove": {"set": "s1", "weapon": "w05-bone-halberd", "name": "追归套装 / 骨枝长戟"},
	"post": {"set": "s1", "weapon": "w01-ashen-echo", "name": "追归套装 / 灰烬回响"},
	"quarry": {"set": "s2", "weapon": "w06-falling-crag", "name": "烽炉套装 / 坠岩重锤"},
	"ruins": {"set": "s3", "weapon": "w03-prism-saber", "name": "镜潮套装 / 棱光长刀"},
	"refuge": {"set": "s3", "weapon": "w02-ruinsplitter", "name": "镜潮套装 / 裂墟重刃"},
	"wetland": {"set": "s3", "weapon": "w03-prism-saber", "name": "镜潮套装 / 棱光长刀"},
	"causeway": {"set": "s1", "weapon": "w01-ashen-echo", "name": "追归套装 / 灰烬回响"},
	"kilnwood": {"set": "s2", "weapon": "w05-bone-halberd", "name": "烽炉套装 / 骨枝长戟"},
	"archive": {"set": "s3", "weapon": "w03-prism-saber", "name": "镜潮套装 / 棱光长刀"},
	"snowridge": {"set": "s2", "weapon": "w06-falling-crag", "name": "烽炉套装 / 坠岩重锤"},
}
const BOSSES := {
	"H01": {"region": "post", "set": "s1", "weapon": "w01-ashen-echo"},
	"H02": {"region": "grove", "set": "s1", "weapon": "w05-bone-halberd"},
	"H03": {"region": "refuge", "set": "s2", "weapon": "w02-ruinsplitter"},
	"H04": {"region": "refuge", "set": "s3", "weapon": "w03-prism-saber"},
	"H05": {"region": "ruins", "set": "s3", "weapon": "w03-prism-saber"},
	"H06": {"region": "quarry", "set": "s2", "weapon": "w06-falling-crag"},
}

static func pool(config: Dictionary) -> Array:
	var result: Array = SETS[config.set].duplicate()
	result.append(config.weapon)
	return result

static func roll_monster(region: String, rng: RandomNumberGenerator) -> String:
	if not REGIONS.has(region) or rng.randf() >= MONSTER_CHANCE:
		return ""
	var choices := pool(REGIONS[region])
	return choices[rng.randi_range(0, choices.size() - 1)]

static func roll_boss(id: String, rng: RandomNumberGenerator) -> String:
	if not BOSSES.has(id):
		return ""
	var choices := pool(BOSSES[id])
	return choices[rng.randi_range(0, choices.size() - 1)]

static func summary(region: String) -> String:
	if not REGIONS.has(region):
		return ""
	return "小怪35%%掉落1件装备：%s（池内等概率）；触发时附带当前天气药材。首领100%%掉落1件对应装备，另保留原材料奖励。靠近拾取，B查看图片，C穿戴装备；本轮有效。" % REGIONS[region].name
