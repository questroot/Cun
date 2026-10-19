extends RefCounted
## Resource counts are the actual fixed pickups created by Fudi each round.
const ITEMS := {
	"wood": {"name": "木料", "color": "#c99b69"},
	"scrap": {"name": "废料", "color": "#a5b5c6"},
	"water": {"name": "清水", "color": "#69d5ed"},
	"fiber": {"name": "纤维", "color": "#97d595"},
	"rope": {"name": "绳索", "color": "#e7cd90"},
	"herb": {"name": "灵草", "color": "#8fe1ac"},
	"ore": {"name": "玄铁", "color": "#9aaee5"},
	"crystal": {"name": "灵晶", "color": "#d6a1f0"},
}
const REGIONS := {
	"city": {"name": "云庭主城", "game": "灵伴", "point": Vector2(0.18, 0.29), "note": "主城用于漫游、编队和培养，当前没有可采集物品。", "resources": {}},
	"outskirts": {"name": "云庭外缘", "game": "灵伴", "point": Vector2(0.48, 0.22), "note": "外缘连接主城与水门，当前没有可采集物品。", "resources": {}},
	"water_activity": {"name": "漂流浮台", "game": "灵伴", "point": Vector2(0.78, 0.34), "note": "物品随打捞、设施和加工获得，暂无随机掉落稀有度。", "resources": {"wood": "打捞漂浮物；每份 +1", "scrap": "打捞漂浮物；每份 +1", "water": "站点每4秒产出1份", "fiber": "站点每4秒产出1份；工坊建成后转为绳索", "rope": "1纤维加工1绳索；工坊可自动加工"}},
	"grove": {"name": "青岚林地", "game": "福地", "point": Vector2(0.20, 0.72), "note": "林木丰饶，灵晶难寻。靠近光点自动采集。", "resources": {"wood": 8, "herb": 5, "ore": 2, "crystal": 1}, "enemies": 4, "color": "#203e37"},
	"quarry": {"name": "赤岩矿谷", "game": "福地", "point": Vector2(0.50, 0.61), "note": "玄铁集中分布，草木相对稀少。", "resources": {"wood": 2, "herb": 1, "ore": 8, "crystal": 3}, "enemies": 5, "color": "#44352e"},
	"ruins": {"name": "灵泉遗迹", "game": "福地", "point": Vector2(0.80, 0.76), "note": "灵晶与灵草丰富，守卫更多。清理三地守卫即可完成本轮。", "resources": {"wood": 1, "herb": 6, "ore": 3, "crystal": 6}, "enemies": 6, "color": "#29344a"},
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
