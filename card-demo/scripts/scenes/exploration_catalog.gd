extends RefCounted
const FUDI_REGIONS = preload("res://scripts/scenes/fudi_maps.gd").IDS
const MaterialArt = preload("res://scripts/scenes/fudi_material_art.gd")
## Resource counts are the actual fixed pickups created by Fudi each round.
const MATERIALS := {
	"wood": {"name": "木料", "color": "#c99b69"},
	"scrap": {"name": "废料", "color": "#a5b5c6"},
	"water": {"name": "清水", "color": "#69d5ed"},
	"fiber": {"name": "纤维", "color": "#97d595"},
	"rope": {"name": "绳索", "color": "#e7cd90"},
	"herb": {"name": "灵草", "color": "#8fe1ac"},
	"ore": {"name": "玄铁", "color": "#9aaee5"},
	"crystal": {"name": "灵晶", "color": "#d6a1f0"},
	"iron": {"name": "旧铁片", "color": "#b6bdcc"},
	"copper": {"name": "细铜丝", "color": "#e3b17e"},
	"resin": {"name": "松脂", "color": "#e7bd70"},
	"sand": {"name": "磨石砂", "color": "#d6c393"},
	"paper_ash": {"name": "回响纸灰", "color": "#dbd3ba"},
	"memory_sand": {"name": "记忆晶砂", "color": "#85dce0"},
	"spirit_stone": {"name": "凝灵石", "color": "#b3a2ed"},
	"bloodgrass": {"name": "止血草", "color": "#a3d6a0"},
	"dewleaf": {"name": "青露叶", "color": "#7ed4bd"},
	"bitterroot": {"name": "苦心根", "color": "#d3c182"},
	"mint": {"name": "清凉薄荷", "color": "#88d9c5"},
	"warmflower": {"name": "暖绒花", "color": "#f0ce84"},
	"wakeleaf": {"name": "醒神叶", "color": "#b9dc94"},
	"restflower": {"name": "安息花", "color": "#baa4db"},
	"moss": {"name": "石缝苔", "color": "#a2b77d"},
	"rush": {"name": "灯芯草", "color": "#b8c97a"},
	"berry": {"name": "甘露莓", "color": "#e99f9e"},
}
static var ITEMS: Dictionary = _all_items()

static func _all_items() -> Dictionary:
	var items := MATERIALS.duplicate(true)
	for id: String in MaterialArt.HERBS:
		if items.has(id):
			items[id]["icon"] = MaterialArt.HERBS[id]
	items.merge(preload("res://scripts/scenes/loot_catalog.gd").ITEMS)
	return items

const REGIONS := {
	"city": {"name": "云庭主城", "game": "灵伴", "point": Vector2(0.18, 0.29), "note": "主城用于漫游、编队和培养，当前没有可采集物品。", "resources": {}},
	"outskirts": {"name": "云庭外缘", "game": "灵伴", "point": Vector2(0.48, 0.22), "note": "外缘连接主城与水门，当前没有可采集物品。", "resources": {}},
	"water_activity": {"name": "漂流浮台", "game": "灵伴", "point": Vector2(0.78, 0.34), "note": "物品随打捞、设施和加工获得，暂无随机掉落稀有度。", "resources": {"wood": "打捞漂浮物；每份 +1", "scrap": "打捞漂浮物；每份 +1", "water": "站点每4秒产出1份", "fiber": "站点每4秒产出1份；工坊建成后转为绳索", "rope": "1纤维加工1绳索；工坊可自动加工"}},
	"grove": {"name": "青岚灶街", "game": "福地", "point": Vector2(0.18, 0.59), "note": "祝婶 · 今天几个人吃饭。沿旧灶台、街坊药圃和迁灶落脚点找回街坊的记忆。", "resources": {"wood": 8, "herb": 5, "ore": 2, "crystal": 1, "resin": 5, "bloodgrass": 6, "dewleaf": 5, "bitterroot": 3, "berry": 4, "fiber": 4}, "enemies": 4, "color": "#253e35"},
	"post": {"name": "旧城邮驿", "game": "福地", "point": Vector2(0.50, 0.59), "note": "阿缄 · 收件人尚未苏醒。穿过邮局与静默巷，前往寻人留言墙；书信不作为耗材。", "resources": {"wood": 4, "herb": 3, "paper_ash": 3, "iron": 5, "fiber": 6, "wakeleaf": 4, "restflower": 3, "berry": 3}, "enemies": 5, "color": "#3b3c35"},
	"quarry": {"name": "赤岩钟楼", "game": "福地", "point": Vector2(0.82, 0.59), "note": "温砚 · 裂缝之下。修复师工坊、旧城钟楼与护像长廊相连。矿材来自岩层，石像受到保护。", "resources": {"wood": 2, "herb": 1, "ore": 8, "crystal": 3, "iron": 8, "copper": 4, "sand": 6, "moss": 4, "warmflower": 3}, "enemies": 5, "color": "#45392f"},
	"ruins": {"name": "灵泉记录站", "game": "福地", "point": Vector2(0.68, 0.85), "note": "陆见微 · 被删去的七分钟。接入台、备份库、观测台保存三段调查线索；隐瞒不等于灾变起因已查明。", "resources": {"wood": 1, "herb": 6, "ore": 3, "crystal": 6, "memory_sand": 5, "copper": 6, "mint": 4, "rush": 4, "dewleaf": 3}, "enemies": 6, "color": "#263a48"},
	"refuge": {"name": "归航救援营", "game": "福地", "point": Vector2(0.30, 0.85), "note": "拾一 · 请修正我的答案。循救援营、中继塔与眺望台追溯失联队伍。十地肃清后仍可自由探索。", "resources": {"wood": 4, "herb": 4, "iron": 5, "spirit_stone": 2, "memory_sand": 3, "warmflower": 4, "bloodgrass": 4, "rush": 4}, "enemies": 6, "color": "#303d47"},
	"wetland": {"name": "雨灯湿地", "game": "福地", "point": Vector2(0.73, 0.36), "note": "祝婶 · 雨夜留一盏灯。循药棚、渡口与长亭调查旧渠沿岸的归家路线。", "resources": {"wood": 4, "fiber": 6, "dewleaf": 8, "mint": 6, "rush": 7, "berry": 4, "herb": 3}, "enemies": 6, "color": "#203f43"},
	"causeway": {"name": "断桥驿路", "game": "福地", "point": Vector2(0.73, 0.49), "note": "阿缄 · 桥另一头的地址。保存未签收的书信，沿绕行路核对彼岸门牌。", "resources": {"wood": 5, "iron": 6, "fiber": 5, "paper_ash": 4, "sand": 6, "wakeleaf": 6, "restflower": 3}, "enemies": 6, "color": "#34474c"},
	"kilnwood": {"name": "松烟炭林", "game": "福地", "point": Vector2(0.73, 0.62), "note": "温砚 · 给裂隙留一点余地。松脂棚、旧炭窑和试材台保存修复师的工作笔记。", "resources": {"wood": 10, "resin": 8, "ore": 4, "sand": 5, "warmflower": 6, "moss": 4, "herb": 4}, "enemies": 7, "color": "#403b2d"},
	"archive": {"name": "镜沙档案馆", "game": "福地", "point": Vector2(0.73, 0.75), "note": "陆见微 · 每一份记录的来处。保留不同版本和署名，核对事实与推测。", "resources": {"crystal": 8, "memory_sand": 8, "copper": 6, "paper_ash": 4, "restflower": 6, "moss": 4, "dewleaf": 3}, "enemies": 7, "color": "#3d3d52"},
	"snowridge": {"name": "霜脊瞭望岭", "game": "福地", "point": Vector2(0.73, 0.88), "note": "拾一 · 下一次一起回来。追溯山麓补给、失联信标和救援队的归队记录。十地肃清后仍可自由探索。", "resources": {"ore": 6, "iron": 6, "spirit_stone": 3, "crystal": 5, "warmflower": 8, "mint": 5, "rush": 4}, "enemies": 8, "color": "#3c515a"},
}

static func scarcity(count: int) -> String:
	if count <= 0:
		return "已采尽"
	if count == 1:
		return "极稀缺"
	if count <= 3:
		return "稀缺"
	if count <= 6:
		return "适中"
	return "丰富"
