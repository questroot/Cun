extends RefCounted
const Art = preload("res://scripts/scenes/fudi_map_art.gd")
## Ten authored exploration maps. Coordinates below are normalized to each world's size.
## NPC scenes are short echoes of the existing character drafts, not completed revival arcs.
const IDS := ["grove", "post", "quarry", "ruins", "refuge", "wetland", "causeway", "kilnwood", "archive", "snowridge"]
## Clockwise order; each spoke joins matching indices in the two rings.
const INNER_RING := ["grove", "post", "quarry", "ruins", "refuge"]
const OUTER_RING := ["wetland", "causeway", "kilnwood", "archive", "snowridge"]
const ORIGINAL_MAPS := {
	"grove": {
		"size": Vector2(3600, 2400), "spawn": Vector2(0.15, 0.50), "npc": "祝婶", "chapter": "今天几个人吃饭",
		"ground": "#253e35", "road": "#75674c", "accent": "#e8b770", "terrain": "garden",
		"sites": [
			["旧灶台", Vector2(0.25, 0.50), "祝婶的灶火还亮着。她喊：‘先找菜单，回来一起吃饭。’", "stove"],
			["街坊药圃", Vector2(0.52, 0.25), "菜单背面写着街坊的名字与忌口。祝婶记住的，一直是来吃饭的人。", "garden"],
			["迁灶落脚点", Vector2(0.76, 0.68), "新的餐桌旁留出了帮厨的位置。旧门牌会一起带走，熟客回来仍找得到路。", "table"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.52, 0.25), Vector2(0.76, 0.68), Vector2(0.92, 0.50)], [Vector2(0.52, 0.25), Vector2(0.50, 0.08)]],
		"obstacles": [Rect2(0.34, 0.58, 0.11, 0.12), Rect2(0.59, 0.68, 0.08, 0.10), Rect2(0.17, 0.72, 0.17, 0.06), Rect2(0.70, 0.17, 0.10, 0.09)],
		"exits": [["refuge", Vector2(0.08, 0.50)], ["post", Vector2(0.92, 0.50)], ["wetland", Vector2(0.50, 0.08)]],
	},
	"post": {
		"size": Vector2(3800, 2600), "spawn": Vector2(0.15, 0.50), "npc": "阿缄", "chapter": "收件人尚未苏醒",
		"ground": "#3b3c35", "road": "#857c61", "accent": "#e6d6a3", "terrain": "street",
		"sites": [
			["未寄出的邮局", Vector2(0.24, 0.50), "阿缄从邮袋里探出头：‘三个地址。收件人没醒，也请别替他们签名。’", "post"],
			["静默收信巷", Vector2(0.51, 0.72), "信箱旁的收件人仍是石像。阿缄轻轻放下信，没有模仿签名。", "statue"],
			["寻人留言墙", Vector2(0.77, 0.28), "留给邮局的辞职信写着：想回家陪母亲。阿缄第一次问你，下一站是否真的想去。", "letters"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.51, 0.72), Vector2(0.77, 0.28), Vector2(0.92, 0.50)], [Vector2(0.51, 0.72), Vector2(0.50, 0.92)]],
		"obstacles": [Rect2(0.34, 0.20, 0.09, 0.30), Rect2(0.59, 0.70, 0.12, 0.13), Rect2(0.14, 0.70, 0.17, 0.09), Rect2(0.60, 0.17, 0.08, 0.16)],
		"exits": [["grove", Vector2(0.08, 0.50)], ["quarry", Vector2(0.92, 0.50)], ["causeway", Vector2(0.50, 0.92)]],
	},
	"quarry": {
		"size": Vector2(4000, 2600), "spawn": Vector2(0.15, 0.50), "npc": "温砚", "chapter": "裂缝之下",
		"ground": "#45392f", "road": "#917653", "accent": "#e5bf86", "terrain": "quarry",
		"sites": [
			["修复师工坊", Vector2(0.25, 0.50), "温砚的石像抱着工具箱。拾一扫描到的不是珍宝，而是一枚孩子捏的泥人。", "workshop"],
			["旧城钟楼", Vector2(0.51, 0.25), "钟楼留着一句话：‘爸，我去找你了。’没有足够证据判断她后来的去向。", "tower"],
			["护像长廊", Vector2(0.76, 0.70), "修复日志提醒：石像不是矿材。支撑裂隙、记录姓名，是等待复苏时仍能做的事。", "statue"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.51, 0.25), Vector2(0.76, 0.70), Vector2(0.92, 0.50)], [Vector2(0.51, 0.25), Vector2(0.50, 0.08)]],
		"obstacles": [Rect2(0.34, 0.47, 0.10, 0.16), Rect2(0.65, 0.15, 0.08, 0.17), Rect2(0.12, 0.18, 0.18, 0.09), Rect2(0.54, 0.80, 0.12, 0.07)],
		"exits": [["post", Vector2(0.08, 0.50)], ["ruins", Vector2(0.92, 0.50)], ["kilnwood", Vector2(0.50, 0.08)]],
	},
	"ruins": {
		"size": Vector2(4200, 2800), "spawn": Vector2(0.15, 0.50), "npc": "陆见微", "chapter": "被删去的七分钟",
		"ground": "#263a48", "road": "#596e7f", "accent": "#94d5e0", "terrain": "archive",
		"sites": [
			["灵泉接入台", Vector2(0.25, 0.50), "设备亮起，陆见微的记忆回响出现：‘请带回备份。互相矛盾的记录也要保留。’", "terminal"],
			["维护备份库", Vector2(0.52, 0.73), "维护日志记下异常，公开通报却说一切正常。它们证明存在隐瞒，尚不能证明灾变由谁造成。", "archive"],
			["七分钟观测台", Vector2(0.76, 0.25), "陆见微在记录上留下署名：‘那份报告是我改的。’后续调查还需要其他证据。", "terminal"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.52, 0.73), Vector2(0.76, 0.25), Vector2(0.92, 0.50)], [Vector2(0.52, 0.73), Vector2(0.50, 0.92)]],
		"obstacles": [Rect2(0.34, 0.18, 0.10, 0.28), Rect2(0.61, 0.67, 0.08, 0.16), Rect2(0.14, 0.73, 0.16, 0.08), Rect2(0.83, 0.17, 0.07, 0.16)],
		"exits": [["quarry", Vector2(0.08, 0.50)], ["refuge", Vector2(0.92, 0.50)], ["archive", Vector2(0.50, 0.92)]],
	},
	"refuge": {
		"size": Vector2(4400, 3000), "spawn": Vector2(0.15, 0.50), "npc": "拾一", "chapter": "请修正我的答案",
		"ground": "#303d47", "road": "#727d7e", "accent": "#9ddacc", "terrain": "camp",
		"sites": [
			["失联救援营", Vector2(0.24, 0.50), "拾一读出旧指令：‘确保至少一人存活。’救援队失联后，这句话一直没有被解除。", "camp"],
			["旧协议中继塔", Vector2(0.51, 0.25), "备份里保留着队员的名字。拾一开始记录每个人的伤势与返程时间。", "beacon"],
			["归航眺望台", Vector2(0.77, 0.71), "‘本次绕路缺乏收益依据。……已标记避雨路线。’拾一把风险提示交给你，等待你的决定。", "beacon"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.51, 0.25), Vector2(0.77, 0.71), Vector2(0.92, 0.50)], [Vector2(0.51, 0.25), Vector2(0.50, 0.08)]],
		"obstacles": [Rect2(0.33, 0.47, 0.12, 0.14), Rect2(0.65, 0.12, 0.08, 0.15), Rect2(0.17, 0.73, 0.17, 0.08), Rect2(0.56, 0.81, 0.12, 0.07)],
		"exits": [["ruins", Vector2(0.08, 0.50)], ["grove", Vector2(0.92, 0.50)], ["snowridge", Vector2(0.50, 0.08)]],
	},
	"wetland": {
		"size": Vector2(4600, 3000), "spawn": Vector2(0.15, 0.50), "npc": "祝婶", "chapter": "雨夜留一盏灯",
		"ground": "#203f43", "road": "#7d8668", "accent": "#b9e0b6", "terrain": "wetland",
		"sites": [
			["旧渠药棚", Vector2(0.26, 0.50), "药棚里留着祝婶写的便条：雨天先给晚归的人备热汤，药草另装一篮。", "garden"],
			["雨灯渡口", Vector2(0.50, 0.22), "灯芯草编成的灯绳伸向旧渡口。留下灯的人希望迷路的街坊能循光回家。", "beacon"],
			["避雨长亭", Vector2(0.78, 0.62), "亭中菜单注明‘晚到也留饭’。你把渡口的位置记下来，留待下一次回灶街时告诉祝婶。", "table"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.26, 0.50), Vector2(0.50, 0.22), Vector2(0.78, 0.62), Vector2(0.92, 0.50)], [Vector2(0.78, 0.62), Vector2(0.50, 0.92)]],
		"obstacles": [Rect2(0.32, 0.47, 0.11, 0.18), Rect2(0.58, 0.14, 0.12, 0.16), Rect2(0.15, 0.73, 0.20, 0.12), Rect2(0.77, 0.78, 0.10, 0.11)],
		"exits": [["snowridge", Vector2(0.08, 0.50)], ["causeway", Vector2(0.92, 0.50)], ["grove", Vector2(0.50, 0.92)]],
	},
	"causeway": {
		"size": Vector2(4800, 2800), "spawn": Vector2(0.15, 0.50), "npc": "阿缄", "chapter": "桥另一头的地址",
		"ground": "#34474c", "road": "#9a9279", "accent": "#e3d5b2", "terrain": "causeway",
		"sites": [
			["换马驿亭", Vector2(0.25, 0.50), "阿缄在旧路线册边添了箭头：桥坏了，地址还在。请先核对路，再替别人决定去向。", "post"],
			["断桥守信箱", Vector2(0.48, 0.76), "防水信箱中保存着未签收的信。你只抄下门牌和受损路段，没有拆开任何一封。", "letters"],
			["彼岸路标", Vector2(0.79, 0.30), "桥头的绕行标记连向旧城。阿缄可以据此更新送信路线，失联收件人的下落仍未得到证实。", "beacon"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.48, 0.76), Vector2(0.79, 0.30), Vector2(0.92, 0.50)], [Vector2(0.25, 0.50), Vector2(0.25, 0.12), Vector2(0.50, 0.08)]],
		"obstacles": [Rect2(0.33, 0.18, 0.08, 0.26), Rect2(0.59, 0.71, 0.17, 0.13), Rect2(0.12, 0.72, 0.15, 0.14), Rect2(0.65, 0.12, 0.08, 0.15)],
		"exits": [["wetland", Vector2(0.08, 0.50)], ["kilnwood", Vector2(0.92, 0.50)], ["post", Vector2(0.50, 0.08)]],
	},
	"kilnwood": {
		"size": Vector2(4600, 3200), "spawn": Vector2(0.15, 0.50), "npc": "温砚", "chapter": "给裂隙留一点余地",
		"ground": "#403b2d", "road": "#9b7951", "accent": "#e4c184", "terrain": "kilnwood",
		"sites": [
			["松脂采集棚", Vector2(0.24, 0.50), "温砚的旧笔记列着松脂与磨石砂的用量。裂口要先清理，再判断是否适合填补。", "workshop"],
			["封火旧炭窑", Vector2(0.49, 0.24), "窑边的木牌记着街坊借炭的名字。这里留下的是生活用料，没有拿任何石像当作燃料或矿材。", "stove"],
			["护像试材台", Vector2(0.77, 0.67), "修复样板上标着承重方向。你记下安全的加固方法；它能保护裂隙，却不能替代复苏研究。", "statue"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.49, 0.24), Vector2(0.77, 0.67), Vector2(0.92, 0.50)], [Vector2(0.77, 0.67), Vector2(0.50, 0.92)]],
		"obstacles": [Rect2(0.34, 0.47, 0.12, 0.12), Rect2(0.59, 0.17, 0.09, 0.19), Rect2(0.13, 0.73, 0.18, 0.08), Rect2(0.77, 0.79, 0.10, 0.10)],
		"exits": [["causeway", Vector2(0.08, 0.50)], ["archive", Vector2(0.92, 0.50)], ["quarry", Vector2(0.50, 0.92)]],
	},
	"archive": {
		"size": Vector2(5000, 3200), "spawn": Vector2(0.15, 0.50), "npc": "陆见微", "chapter": "每一份记录的来处",
		"ground": "#3d3d52", "road": "#8b8296", "accent": "#cec2ee", "terrain": "archive",
		"sites": [
			["镜沙索引台", Vector2(0.25, 0.50), "陆见微的回响要求先记录备份来源和时间，再阅读内容。缺页不应被推测悄悄补上。", "terminal"],
			["异本保管库", Vector2(0.49, 0.74), "同一份通报保留了两个版本。你分别编号，等待与灵泉维护日志交叉核对。", "archive"],
			["署名校验室", Vector2(0.78, 0.26), "签名能证明谁处理过记录，无法单独证明谁引发灾变。调查清单又多了一条可以验证的问题。", "terminal"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.25, 0.50), Vector2(0.49, 0.74), Vector2(0.78, 0.26), Vector2(0.92, 0.50)], [Vector2(0.25, 0.50), Vector2(0.25, 0.10), Vector2(0.50, 0.08)]],
		"obstacles": [Rect2(0.34, 0.18, 0.09, 0.25), Rect2(0.58, 0.71, 0.14, 0.12), Rect2(0.13, 0.72, 0.17, 0.10), Rect2(0.65, 0.10, 0.08, 0.13)],
		"exits": [["kilnwood", Vector2(0.08, 0.50)], ["snowridge", Vector2(0.92, 0.50)], ["ruins", Vector2(0.50, 0.08)]],
	},
	"snowridge": {
		"size": Vector2(5200, 3400), "spawn": Vector2(0.15, 0.50), "npc": "拾一", "chapter": "下一次一起回来",
		"ground": "#3c515a", "road": "#9da9a4", "accent": "#cfecf1", "terrain": "snowridge",
		"sites": [
			["山麓补给棚", Vector2(0.24, 0.50), "拾一找到了救援队的补给登记。队员曾为返程保留物资，而不是只计算出发时能带走多少。", "camp"],
			["霜脊信标", Vector2(0.50, 0.22), "失联信标保存着集合位置，未保存最终返程结果。拾一将它标成待查，没有再次写下‘唯一幸存者’。", "beacon"],
			["归队望远台", Vector2(0.78, 0.68), "‘返程路线已更新。名单按姓名排列。’拾一在报告末尾留出了下一次共同归来的记录栏。", "tower"],
		],
		"roads": [[Vector2(0.08, 0.50), Vector2(0.24, 0.50), Vector2(0.50, 0.22), Vector2(0.78, 0.68), Vector2(0.92, 0.50)], [Vector2(0.78, 0.68), Vector2(0.50, 0.92)]],
		"obstacles": [Rect2(0.34, 0.46, 0.11, 0.15), Rect2(0.59, 0.15, 0.09, 0.18), Rect2(0.12, 0.73, 0.18, 0.11), Rect2(0.77, 0.80, 0.10, 0.10)],
		"exits": [["archive", Vector2(0.08, 0.50)], ["wetland", Vector2(0.92, 0.50)], ["refuge", Vector2(0.50, 0.92)]],
	},
}

static var MAPS: Dictionary = Art.apply_layouts(ORIGINAL_MAPS)

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
	if Art.has_art(id):
		return Art.on_ground(MAPS[id], point, margin)
	for rect: Rect2 in obstacles(id):
		if rect.grow(margin).has_point(point):
			return false
	return true

static func arrival_point(id: String, previous: String) -> Vector2:
	for exit: Array in MAPS[id].exits:
		if exit[0] != previous:
			continue
		var gate: Vector2 = exit[1] * MAPS[id].size
		for road: Array in MAPS[id].roads:
			if Vector2(road[0]).is_equal_approx(exit[1]):
				return gate + (Vector2(road[1]) * MAPS[id].size - gate).normalized() * 100
			if Vector2(road[-1]).is_equal_approx(exit[1]):
				return gate + (Vector2(road[-2]) * MAPS[id].size - gate).normalized() * 100
		return gate + (MAPS[id].size * 0.5 - gate).normalized() * 100
	return MAPS[id].spawn * MAPS[id].size

static func site_position(id: String, index: int) -> Vector2:
	return MAPS[id].sites[index][1] * MAPS[id].size

static func site_total() -> int:
	var count := 0
	for id: String in IDS:
		count += MAPS[id].sites.size()
	return count
