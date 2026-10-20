extends RefCounted
## Prices use the existing round-local crystal material. No new currency or save.
const ROLES := {
	"lu-yan": "行商 · 地方材料", "jin-suanpan": "交易所 · 登记货品",
	"shen-heng": "续灯商会 · 运输调度", "luo-zhu": "铁匠 · 护具与金属材料",
	"ye-ting": "药剂师 · 照护药材", "qiao-huang": "机关师 · 维修材料",
	"cen-chi": "测绘师 · 道路勘察", "xie-tingzhou": "司灯人 · 守夜与照护",
	"wen-zhou": "学者 · 古籍与异文", "changdaozhe": "巡游商人 · 高阶与稀有物品",
}
const NOTES := {
	"lu-yan": "欠人一趟路，也算。车上的现货按件算，不售代送物品。",
	"jin-suanpan": "只出售登记可交易的货品。仍有人寻找的寄存物，不在货架上。",
	"shen-heng": "救援需求单列登记；运输如何安排，依据要留给大家查。",
	"luo-zhu": "支撑先做牢，再开通道。这里备护具和材料，救援工具另按需要商量。",
	"ye-ting": "药草用于照护，不能直接解除石化。买回的药材会放进行囊。",
	"qiao-huang": "零件按规格拿。能安全工作的结构，比唯一的原装答案要紧。",
	"cen-chi": "旧图没有的路要重新测。图上的空白，暂时别当成安全。",
	"xie-tingzhou": "我替他们留灯，不能替他们回答。留下的话，也要一起听。",
	"wen-zhou": "先核对抄本和署名。缺失的部分，不急着用推测填上。",
	"changdaozhe": "稀有之物也应说清来处和价钱。我带来的装备能用，祈愿仍需你自己分辨。",
}
# Each row is [item ID, crystals per item, stock for this round].
const STOCK := {
	"lu-yan": [["wood",1,4],["resin",1,3],["iron",1,3],["s1-boots",3,1]],
	"jin-suanpan": [["copper",1,4],["sand",1,4],["s1-ring",3,1],["s1-necklace",3,1]],
	"luo-zhu": [["ore",1,4],["iron",1,4],["s2-top",4,1],["s2-legs",4,1]],
	"ye-ting": [["herb",1,4],["bloodgrass",1,3],["dewleaf",1,3],["restflower",2,2]],
	"qiao-huang": [["copper",1,4],["iron",1,4],["spirit_stone",3,1]],
	"changdaozhe": [["w03-prism-saber@mutated",12,1],["w02-ruinsplitter@mutated",12,1],
		["s3-top@mutated",8,1],["s3-ring@mutated",7,1],["spirit_stone",4,2],["memory_sand",3,3]],
}

static func is_merchant(id: String) -> bool:
	return STOCK.has(id)
