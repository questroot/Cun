extends RefCounted
## Per-map hazards: warning time always precedes a single hit; weather affects selection.
# 暂时停用地图随机陷阱；恢复时改为 true，原机制与配置保留。
const ENABLED := false
const MIN_INTERVAL := 8.0
const MAX_INTERVAL := 14.0
const ENTRY_GRACE := 3.0
const REGIONS := {
	"grove": ["thorns", "spores"],
	"post": ["floor", "sign"],
	"quarry": ["rockfall", "fissure"],
	"ruins": ["surge", "geyser"],
	"refuge": ["frost", "debris"],
	"wetland": ["geyser", "spores"],
	"causeway": ["floor", "debris"],
	"kilnwood": ["thorns", "fissure"],
	"archive": ["surge", "sign"],
	"snowridge": ["frost", "rockfall"],
}
const TRAPS := {
	"thorns": {"name": "蔓刺突生", "radius": 64.0, "warning": 1.4, "active": 1.5, "damage": 8, "slow": 0.65, "duration": 2.5, "push": 0.0, "weather": ["rain"], "color": "#a5cd73"},
	"spores": {"name": "孢子喷发", "radius": 78.0, "warning": 1.6, "active": 1.8, "damage": 6, "slow": 0.75, "duration": 3.0, "push": 0.0, "weather": ["fog"], "color": "#c3a5dd"},
	"floor": {"name": "朽板塌陷", "radius": 60.0, "warning": 1.4, "active": 1.2, "damage": 10, "slow": 0.6, "duration": 2.0, "push": 0.0, "weather": ["rain"], "color": "#ccae7b"},
	"sign": {"name": "悬牌坠落", "radius": 56.0, "warning": 1.5, "active": 0.8, "damage": 12, "slow": 1.0, "duration": 0.0, "push": 70.0, "weather": ["wind"], "color": "#d9c290"},
	"rockfall": {"name": "崩岩落石", "radius": 66.0, "warning": 1.7, "active": 0.9, "damage": 16, "slow": 1.0, "duration": 0.0, "push": 85.0, "weather": ["wind"], "color": "#d5a484"},
	"fissure": {"name": "灼热地裂", "radius": 72.0, "warning": 1.5, "active": 1.8, "damage": 12, "slow": 0.7, "duration": 2.0, "push": 0.0, "weather": ["heat"], "color": "#eea16f"},
	"surge": {"name": "灵泉电涌", "radius": 70.0, "warning": 1.3, "active": 1.0, "damage": 14, "slow": 0.65, "duration": 1.5, "push": 0.0, "weather": ["storm"], "color": "#b4b9fb"},
	"geyser": {"name": "失控水压", "radius": 74.0, "warning": 1.6, "active": 1.2, "damage": 10, "slow": 1.0, "duration": 0.0, "push": 100.0, "weather": ["rain"], "color": "#8dd6ee"},
	"frost": {"name": "薄冰碎裂", "radius": 68.0, "warning": 1.5, "active": 1.5, "damage": 10, "slow": 0.55, "duration": 2.5, "push": 0.0, "weather": ["snow"], "color": "#c4eafa"},
	"debris": {"name": "狂风卷物", "radius": 72.0, "warning": 1.4, "active": 1.2, "damage": 10, "slow": 1.0, "duration": 0.0, "push": 100.0, "weather": ["wind"], "color": "#b4d5ca"},
}

static func names(id: String) -> String:
	var result := PackedStringArray()
	for key: String in REGIONS[id]:
		result.append(TRAPS[key].name)
	return " / ".join(result)

static func describe(id: String) -> String:
	if not ENABLED:
		return "地图随机陷阱暂已停用。"
	return "随机陷阱：%s\n黄色圈预警1.3–1.7秒后爆发，离开范围可闪避。每次爆发最多命中一次；安全点不生成陷阱。" % names(id)
