extends RefCounted
## Equipment rules are separate from the shared drop tables and original save.
const Loot = preload("res://scripts/scenes/loot_catalog.gd")
const SLOTS := ["weapon", "top", "legs", "boots", "necklace", "ring"]
const NAMES := {"weapon": "武器", "top": "上衣", "legs": "护腿", "boots": "战靴", "necklace": "项链", "ring": "戒指"}
const ARMOR := {
	"top": {"attack": 0, "defense": 3, "speed": 0},
	"legs": {"attack": 0, "defense": 2, "speed": 0},
	"boots": {"attack": 0, "defense": 0, "speed": 15},
	"necklace": {"attack": 3, "defense": 0, "speed": 0},
	"ring": {"attack": 2, "defense": 0, "speed": 0},
}
const WEAPONS := {
	"w01-ashen-echo": {"attack": 12, "defense": 2, "speed": 0},
	"w02-ruinsplitter": {"attack": 18, "defense": 0, "speed": 0},
	"w03-prism-saber": {"attack": 14, "defense": 0, "speed": 10},
	"w05-bone-halberd": {"attack": 15, "defense": 1, "speed": 0},
	"w06-falling-crag": {"attack": 20, "defense": 0, "speed": 0},
}
const SET_EFFECTS := {
	"s1": {"name": "追归", "tiers": {2: "移速额外 +20", 4: "J/K/L 冷却缩短15%", 5: "攻击命中恢复4生命，间隔1秒"}},
	"s2": {"name": "烽炉", "tiers": {2: "伤害额外 +6", 4: "命中附加灼烧，每秒6伤害，持续3秒；刷新不叠加", 5: "L 震荡半径 +50，伤害额外 +12"}},
	"s3": {"name": "镜潮", "tiers": {2: "减伤额外 +3", 4: "固定减伤后再减少20%伤害，向上取整", 5: "每8秒补充18护盾，吸收伤害；护盾不叠加"}},
}
const WEAPON_EFFECTS := {
	"w01-ashen-echo": "余烬回响：J命中后0.35秒追加10伤害，间隔2秒。",
	"w02-ruinsplitter": "破墟斩：命中时目标生命≤35%，该次直接伤害提高60%，向上取整。",
	"w03-prism-saber": "棱光分流：K发射三向灵弹，每颗独立命中；近距离可命中同一目标。",
	"w05-bone-halberd": "骨枝缚根：J范围+70；命中使目标移速降低35%，持续2秒，刷新不叠加。",
	"w06-falling-crag": "坠岩余震：L施放后0.45秒在原地追加范围18伤害。",
}

static func set_counts(loadout: Dictionary) -> Dictionary:
	var counts := {"s1": 0, "s2": 0, "s3": 0}
	for item: String in loadout.values():
		var id := item.get_slice("-", 0)
		if counts.has(id):
			counts[id] += 1
	return counts

static func loadout_stats(loadout: Dictionary) -> Dictionary:
	var total := {"attack": 0, "defense": 0, "speed": 0}
	for item: String in loadout.values():
		var values := stats(item)
		for key: String in total:
			total[key] += values[key]
	var counts := set_counts(loadout)
	if counts.s1 >= 2:
		total.speed += 20
	if counts.s2 >= 2:
		total.attack += 6
	if counts.s3 >= 2:
		total.defense += 3
	return total

static func effect_text(item: String) -> String:
	var original := item
	item = Loot.base_item(item)
	var prefix := "异变品质：原非零属性提高30%（向上取整）。\n" if original != item else ""
	if WEAPON_EFFECTS.has(item):
		return prefix + WEAPON_EFFECTS[item]
	var id := item.get_slice("-", 0)
	return prefix + SET_EFFECTS[id].name + "套装：2 / 4 / 5 件生效，点击上方“套装与特效”查看。" if SET_EFFECTS.has(id) else prefix

static func slot(item: String) -> String:
	if not Loot.ITEMS.has(item):
		return ""
	item = Loot.base_item(item)
	return "weapon" if WEAPONS.has(item) else item.get_slice("-", 1)

static func stats(item: String) -> Dictionary:
	var base := Loot.base_item(item)
	if base != item:
		var enhanced := stats(base)
		for key: String in enhanced:
			enhanced[key] = ceili(float(enhanced[key]) * Loot.MUTATION_SCALE)
		return enhanced
	if WEAPONS.has(item):
		return WEAPONS[item].duplicate()
	var key := slot(item)
	if not ARMOR.has(key):
		return {"attack": 0, "defense": 0, "speed": 0}
	var values: Dictionary = ARMOR[key].duplicate()
	match item.get_slice("-", 0):
		"s1": values.speed += 3
		"s2": values.attack += 1
		"s3": values.defense += 1
	return values

static func text(values: Dictionary, signed: bool = false) -> String:
	var parts: Array[String] = []
	for key: String in ["attack", "defense", "speed"]:
		var amount := int(values[key])
		var label: String = {"attack": "伤害", "defense": "减伤", "speed": "移速"}[key]
		parts.append("%s %s%d" % [label, "+" if signed and amount >= 0 else "", amount])
	return "   ".join(parts)
