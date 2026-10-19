extends RefCounted
## Five authored exploration maps. Coordinates below are normalized to each world's size.
## NPC scenes are short echoes of the existing character drafts, not completed revival arcs.
const IDS := ["grove", "post", "quarry", "ruins", "refuge"]
const MAPS := {
	"grove": {
		"size": Vector2(3600, 2400), "spawn": Vector2(0.15, 0.50), "npc": "祝婶", "chapter": "今天几个人吃饭",
		"ground": "#253e35", "road": "#75674c", "accent": "#e8b770", "terrain": "garden",
		"sites": [
			["旧灶台", Vector2(0.25, 0.50), "祝婶的灶火还亮着。她喊：‘先找菜单，回来一起吃饭。’", "stove"],
			["街坊药圃", Vector2(0.52, 0.25), "菜单背面写着街坊的名字与忌口。祝婶记住的，一直是来吃饭的人。", "garden"],
			["迁灶落脚点", Vector2(0.76, 0.68), "新的餐桌旁留出了帮厨的位置。旧门牌会一起带走，熟客回来仍找得到路。", "table"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.52, 0.25), Vector2(0.76, 0.68), Vector2(0.92, 0.50)]],
		"obstacles": [Rect2(0.34, 0.43, 0.11, 0.12), Rect2(0.59, 0.44, 0.08, 0.10), Rect2(0.17, 0.72, 0.17, 0.06), Rect2(0.70, 0.17, 0.10, 0.09)],
		"exits": [["refuge", Vector2(0.08, 0.50)], ["post", Vector2(0.92, 0.50)]],
	},
	"post": {
		"size": Vector2(3800, 2600), "spawn": Vector2(0.15, 0.50), "npc": "阿缄", "chapter": "收件人尚未苏醒",
		"ground": "#3b3c35", "road": "#857c61", "accent": "#e6d6a3", "terrain": "street",
		"sites": [
			["未寄出的邮局", Vector2(0.24, 0.50), "阿缄从邮袋里探出头：‘三个地址。收件人没醒，也请别替他们签名。’", "post"],
			["静默收信巷", Vector2(0.51, 0.72), "信箱旁的收件人仍是石像。阿缄轻轻放下信，没有模仿签名。", "statue"],
			["寻人留言墙", Vector2(0.77, 0.28), "留给邮局的辞职信写着：想回家陪母亲。阿缄第一次问你，下一站是否真的想去。", "letters"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.51, 0.72), Vector2(0.77, 0.28), Vector2(0.92, 0.50)]],
		"obstacles": [Rect2(0.34, 0.20, 0.09, 0.30), Rect2(0.59, 0.70, 0.12, 0.13), Rect2(0.14, 0.70, 0.17, 0.09), Rect2(0.60, 0.17, 0.08, 0.16)],
		"exits": [["grove", Vector2(0.08, 0.50)], ["quarry", Vector2(0.92, 0.50)]],
	},
	"quarry": {
		"size": Vector2(4000, 2600), "spawn": Vector2(0.15, 0.50), "npc": "温砚", "chapter": "裂缝之下",
		"ground": "#45392f", "road": "#917653", "accent": "#e5bf86", "terrain": "quarry",
		"sites": [
			["修复师工坊", Vector2(0.25, 0.50), "温砚的石像抱着工具箱。拾一扫描到的不是珍宝，而是一枚孩子捏的泥人。", "workshop"],
			["旧城钟楼", Vector2(0.51, 0.25), "钟楼留着一句话：‘爸，我去找你了。’没有足够证据判断她后来的去向。", "tower"],
			["护像长廊", Vector2(0.76, 0.70), "修复日志提醒：石像不是矿材。支撑裂隙、记录姓名，是等待复苏时仍能做的事。", "statue"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.51, 0.25), Vector2(0.76, 0.70), Vector2(0.92, 0.50)]],
		"obstacles": [Rect2(0.34, 0.47, 0.10, 0.16), Rect2(0.58, 0.25, 0.08, 0.20), Rect2(0.12, 0.18, 0.18, 0.09), Rect2(0.54, 0.80, 0.12, 0.07)],
		"exits": [["post", Vector2(0.08, 0.50)], ["ruins", Vector2(0.92, 0.50)]],
	},
	"ruins": {
		"size": Vector2(4200, 2800), "spawn": Vector2(0.15, 0.50), "npc": "陆见微", "chapter": "被删去的七分钟",
		"ground": "#263a48", "road": "#596e7f", "accent": "#94d5e0", "terrain": "archive",
		"sites": [
			["灵泉接入台", Vector2(0.25, 0.50), "设备亮起，陆见微的记忆回响出现：‘请带回备份。互相矛盾的记录也要保留。’", "terminal"],
			["维护备份库", Vector2(0.52, 0.73), "维护日志记下异常，公开通报却说一切正常。它们证明存在隐瞒，尚不能证明灾变由谁造成。", "archive"],
			["七分钟观测台", Vector2(0.76, 0.25), "陆见微在记录上留下署名：‘那份报告是我改的。’后续调查还需要其他证据。", "terminal"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.52, 0.73), Vector2(0.76, 0.25), Vector2(0.92, 0.50)]],
		"obstacles": [Rect2(0.34, 0.18, 0.10, 0.28), Rect2(0.61, 0.67, 0.08, 0.16), Rect2(0.14, 0.73, 0.16, 0.08), Rect2(0.83, 0.17, 0.07, 0.16)],
		"exits": [["quarry", Vector2(0.08, 0.50)], ["refuge", Vector2(0.92, 0.50)]],
	},
	"refuge": {
		"size": Vector2(4400, 3000), "spawn": Vector2(0.15, 0.50), "npc": "拾一", "chapter": "请修正我的答案",
		"ground": "#303d47", "road": "#727d7e", "accent": "#9ddacc", "terrain": "camp",
		"sites": [
			["失联救援营", Vector2(0.24, 0.50), "拾一读出旧指令：‘确保至少一人存活。’救援队失联后，这句话一直没有被解除。", "camp"],
			["旧协议中继塔", Vector2(0.51, 0.25), "备份里保留着队员的名字。拾一开始记录每个人的伤势与返程时间。", "beacon"],
			["归航眺望台", Vector2(0.77, 0.71), "‘本次绕路缺乏收益依据。……已标记避雨路线。’拾一把风险提示交给你，等待你的决定。", "beacon"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.51, 0.25), Vector2(0.77, 0.71), Vector2(0.92, 0.50)]],
		"obstacles": [Rect2(0.33, 0.47, 0.12, 0.14), Rect2(0.59, 0.22, 0.08, 0.22), Rect2(0.17, 0.73, 0.17, 0.08), Rect2(0.56, 0.81, 0.12, 0.07)],
		"exits": [["ruins", Vector2(0.08, 0.50)], ["grove", Vector2(0.92, 0.50)]],
	},
}

static func bounds(id: String) -> Rect2:
	return Rect2(Vector2.ZERO, MAPS[id].size)

static func obstacles(id: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var extent: Vector2 = MAPS[id].size
	for rect: Rect2 in MAPS[id].obstacles:
		result.append(Rect2(rect.position * extent, rect.size * extent))
	return result

static func walkable(id: String, point: Vector2, margin: float = 22.0) -> bool:
	if not bounds(id).grow(-margin).has_point(point):
		return false
	for rect: Rect2 in obstacles(id):
		if rect.grow(margin).has_point(point):
			return false
	return true

static func site_position(id: String, index: int) -> Vector2:
	return MAPS[id].sites[index][1] * MAPS[id].size
