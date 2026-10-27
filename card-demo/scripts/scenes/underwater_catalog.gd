extends RefCounted

const OXYGEN := 90.0
const RATES := {"shoal": 1.0, "wreck": 1.25, "trench": 1.6}
const ASCENT_SECONDS := 1.5
const RECOVERY_SECONDS := 180.0
const MAX_STOCK := 3
# 候选初值：品质、开启秒数、件数、地点第二资源概率，待真人试玩校准。
const CHESTS := [
	{"name": "普通", "seconds": 0.0, "count": 1, "rare": 0.15, "color": Color("#c9ae86")},
	{"name": "精良", "seconds": 3.0, "count": 1, "rare": 0.4, "color": Color("#78d9bd")},
	{"name": "稀有", "seconds": 6.0, "count": 2, "rare": 0.75, "color": Color("#c29afa")}
]
const POOLS := {"shoal": ["coral", "shell"], "wreck": ["timber", "copper"], "trench": ["algae", "pearl"]}

static func chest_quality(map: String, id: String) -> int:
	for i in NODES[map].size():
		if NODES[map][i][0] == id: return i % CHESTS.size()
	return 0

static func chest_slots(map: String, id: String) -> int:
	var largest := 0
	for item in POOLS[map]: largest = maxi(largest, int(ITEMS[item][1]))
	return largest * int(CHESTS[chest_quality(map, id)].count)

static func chest_loot(map: String, id: String, stock: int, timestamp: float) -> Array:
	# 同一存量代次固定种子：保存失败、取消及重新下潜都不能重抽。
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s/%d/%.6f" % [map, id, stock, timestamp])
	var config: Dictionary = CHESTS[chest_quality(map, id)]
	var result: Array = []
	for i in int(config.count):
		result.append(POOLS[map][1 if rng.randf() < float(config.rare) else 0])
	return result

const BASE_CAPACITY := 8
const RESOURCE_LIMIT := 1000000
const ITEMS := {
	"coral": ["珊瑚枝", 1], "shell": ["贝群", 1],
	"timber": ["船料", 2], "copper": ["铜件", 2],
	"algae": ["发光藻", 1], "pearl": ["深水珍珠", 3]
}
const EQUIPMENT := {"mask": "潜水面具", "tank": "氧气瓶", "fins": "脚蹼", "wrist": "护腕（暂未开放）"}
const WORKSHOP_COST := Vector2i(2, 2)
const SAFETY_RADIUS := 56.0
const RECIPES := {
	"mask": [{"coral": 3, "wood": 2}, {"pearl": 1, "copper": 2}],
	"tank": [{"copper": 2, "scrap": 2}, {"pearl": 1, "timber": 2}],
	"fins": [{"shell": 3, "fiber": 2}, {"algae": 3, "rope": 1}],
	"net_expansion": [{"coral": 2, "rope": 1}, {"coral": 2, "rope": 1}]
}
const USES := {"coral": "面具L1 / 网袋扩容", "shell": "脚蹼L1", "timber": "氧气瓶L2", "copper": "氧气瓶L1 / 面具L2", "algae": "脚蹼L2", "pearl": "深处目标：面具与氧气瓶二级"}

static func equipment() -> Dictionary:
	return {"mask": {"id": "mask", "level": 0}, "tank": {"id": "tank", "level": 0}, "fins": {"id": "fins", "level": 0}, "wrist": {"id": "wrist", "level": 0}}

const NODES := {
	"shoal": [["s1", "coral", Vector2(270, 300)], ["s2", "shell", Vector2(340, 560)], ["s3", "coral", Vector2(740, 520)], ["s4", "shell", Vector2(970, 370)]],
	"wreck": [["w1", "timber", Vector2(270, 350)], ["w2", "copper", Vector2(550, 485)], ["w3", "timber", Vector2(620, 290)], ["w4", "copper", Vector2(850, 490)], ["w5", "timber", Vector2(980, 350)]],
	"trench": [["t1", "algae", Vector2(300, 370)], ["t2", "algae", Vector2(440, 450)], ["t3", "pearl", Vector2(580, 370)], ["t4", "algae", Vector2(720, 450)], ["t5", "pearl", Vector2(870, 350)]]
}

static func defaults(now: float = Time.get_unix_time_from_system()) -> Dictionary:
	var states := {}
	for map in NODES:
		states[map] = {}
		for node in NODES[map]:
			states[map][node[0]] = {"stock": MAX_STOCK, "timestamp": now}
	return states

static func resources() -> Dictionary:
	var result := {}
	for id in ITEMS: result[id] = 0
	return result

static func integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and value == floor(value)

static func valid_equipment(state: Dictionary) -> bool:
	for key in ["core_reward_claimed", "dive_workshop_unlocked", "dive_workshop_built"]:
		if not state.get(key) is bool: return false
	if state.core_reward_claimed != state.dive_workshop_unlocked: return false
	if state.core_reward_claimed and not state.get("dive_archived", false): return false
	if state.dive_workshop_built and not state.dive_workshop_unlocked: return false
	if not state.get("equipment") is Dictionary or state.equipment.size() != EQUIPMENT.size(): return false
	for slot in EQUIPMENT:
		var item: Variant = state.equipment.get(slot)
		if not item is Dictionary or item.size() != 2 or item.get("id") != slot or not integer(item.get("level"), 0 if slot == "wrist" else 2): return false
		if item.level > 0 and not state.dive_workshop_built: return false
	return true

static func valid(state: Dictionary) -> bool:
	if not state.get("resources") is Dictionary or state.resources.size() != ITEMS.size(): return false
	for id in ITEMS:
		if not integer(state.resources.get(id), RESOURCE_LIMIT): return false
	if not integer(state.get("net_expansion"), 2): return false
	if not state.get("node_states") is Dictionary or state.node_states.size() != NODES.size(): return false
	for map in NODES:
		var nodes: Variant = state.node_states.get(map)
		if not nodes is Dictionary or nodes.size() != NODES[map].size(): return false
		for node in NODES[map]:
			var entry: Variant = nodes.get(node[0])
			if not entry is Dictionary or entry.size() != 2 or not integer(entry.get("stock"), MAX_STOCK): return false
			var stamp: Variant = entry.get("timestamp")
			if not (stamp is int or stamp is float) or not is_finite(float(stamp)) or stamp <= 0 or stamp > 253402300799.0: return false
	return true

static func recover(entry: Dictionary, now: float) -> void:
	if not is_finite(now) or now <= 0: return
	var stamp := float(entry.timestamp)
	if stamp > now or int(entry.stock) == MAX_STOCK:
		entry.timestamp = now
		return
	var count := mini(MAX_STOCK, int(minf(now - stamp, RECOVERY_SECONDS * MAX_STOCK) / RECOVERY_SECONDS))
	if count > 0:
		entry.stock = mini(MAX_STOCK, int(entry.stock) + count)
		entry.timestamp = now if int(entry.stock) == MAX_STOCK else stamp + count * RECOVERY_SECONDS
