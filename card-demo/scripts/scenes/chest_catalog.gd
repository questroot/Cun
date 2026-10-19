extends RefCounted
const NORMAL_PER_REGION := 2
const MUTATION_CHANCE := 0.35
const GUARD_COUNT := 4
const BOSS_DROP_CHANCE := 0.60
const BOSS_HP_SCALE := 0.60
const BOSS_DAMAGE_SCALE := 0.60
const REGION_BOSS := {
	"grove": "H02", "post": "H01", "quarry": "H06", "ruins": "H05", "refuge": "H03",
	"wetland": "H03", "causeway": "H01", "kilnwood": "H02", "archive": "H05", "snowridge": "H04",
}

static func rules() -> String:
	return "金色普通宝箱：E领取1件区域装备和3份材料。紫色异变宝箱：E触发4只小怪和弱化首领，清除后再按E领奖。守箱首领生命/伤害为原版60%，60%掉落异变装备；原非零属性+30%（向上取整）。"
