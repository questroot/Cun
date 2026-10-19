extends RefCounted
## Regional climate and ecology rules. Times are seconds of unpaused exploration.
const PERIOD := 75.0
const WEATHER := {
	"rain": {"name": "润雨", "attribute": "水", "color": "#80cce5", "monster": "沐雨石灵", "speed": 66.0, "damage": 9, "hp": 60, "drop": "dewleaf"},
	"clear": {"name": "晴光", "attribute": "木", "color": "#d4e99b", "monster": "逐光木灵", "speed": 80.0, "damage": 8, "hp": 52, "drop": "bloodgrass"},
	"fog": {"name": "灵雾", "attribute": "阴", "color": "#baaadd", "monster": "雾隐石灵", "speed": 90.0, "damage": 8, "hp": 48, "drop": "restflower"},
	"wind": {"name": "疾风", "attribute": "风", "color": "#b7ded2", "monster": "巡风石灵", "speed": 108.0, "damage": 8, "hp": 50, "drop": "wakeleaf"},
	"heat": {"name": "炎阳", "attribute": "火", "color": "#efb276", "monster": "熔火石灵", "speed": 60.0, "damage": 15, "hp": 80, "drop": "warmflower"},
	"storm": {"name": "雷雨", "attribute": "雷", "color": "#b9b1f4", "monster": "鸣雷石灵", "speed": 88.0, "damage": 13, "hp": 64, "drop": "rush"},
	"snow": {"name": "霜雪", "attribute": "冰", "color": "#c6e8f5", "monster": "霜甲石灵", "speed": 48.0, "damage": 12, "hp": 90, "drop": "mint"},
}
const CLIMATES := {
	"grove": {"cycle": ["rain", "clear", "fog"], "plants": ["bloodgrass", "dewleaf", "berry"]},
	"post": {"cycle": ["fog", "wind", "rain"], "plants": ["wakeleaf", "restflower", "berry"]},
	"quarry": {"cycle": ["heat", "wind", "clear"], "plants": ["herb", "warmflower", "moss"]},
	"ruins": {"cycle": ["storm", "rain", "fog"], "plants": ["mint", "rush", "dewleaf"]},
	"refuge": {"cycle": ["snow", "clear", "wind"], "plants": ["warmflower", "bloodgrass", "rush"]},
	"wetland": {"cycle": ["rain", "storm", "fog"], "plants": ["dewleaf", "mint", "rush"]},
	"causeway": {"cycle": ["wind", "rain", "fog"], "plants": ["wakeleaf", "restflower", "berry"]},
	"kilnwood": {"cycle": ["clear", "heat", "wind"], "plants": ["bloodgrass", "warmflower", "herb"]},
	"archive": {"cycle": ["fog", "snow", "storm"], "plants": ["restflower", "moss", "dewleaf"]},
	"snowridge": {"cycle": ["snow", "wind", "clear"], "plants": ["warmflower", "mint", "rush"]},
}
const PLANTS := {
	"bloodgrass": {"weather": ["rain", "clear"], "time": 18.0},
	"dewleaf": {"weather": ["rain", "fog"], "time": 24.0},
	"berry": {"weather": ["rain", "clear"], "time": 28.0},
	"wakeleaf": {"weather": ["wind", "fog"], "time": 22.0},
	"restflower": {"weather": ["fog", "snow"], "time": 26.0},
	"herb": {"weather": ["heat", "wind", "rain", "clear"], "time": 20.0},
	"warmflower": {"weather": ["heat", "snow", "clear"], "time": 25.0},
	"moss": {"weather": ["wind", "fog", "snow"], "time": 20.0},
	"mint": {"weather": ["rain", "storm", "snow"], "time": 22.0},
	"rush": {"weather": ["rain", "storm", "snow"], "time": 24.0},
}

static func weather_at(id: String, elapsed: float) -> String:
	var cycle: Array = CLIMATES[id].cycle
	return cycle[int(floor(maxf(0.0, elapsed) / PERIOD)) % cycle.size()]

static func compatible(item: String, weather: String) -> bool:
	return PLANTS.has(item) and weather in PLANTS[item].weather

static func weather_names(keys: Array) -> String:
	var names := PackedStringArray()
	for key: String in keys:
		names.append(WEATHER[key].name)
	return " / ".join(names)

static func describe(id: String, elapsed: float = 0.0) -> String:
	var weather: Dictionary = WEATHER[weather_at(id, elapsed)]
	return "%s · %s属性 · %.0f秒后转%s" % [weather.name, weather.attribute, PERIOD - fmod(elapsed, PERIOD), WEATHER[weather_at(id, elapsed + PERIOD)].name]
