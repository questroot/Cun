extends RefCounted
## All facts here are obtained by actions, never by reading author-only story text.
const VERSION := 1
const PLACES := {"street":"杂货铺 / 街口", "shelter":"候船棚", "house":"许家旧屋", "steps":"旧石阶", "boat":"夜船·靠岸侧舷"}
const EVIDENCE := {
	"timetable":"旧通航告示：白灯招呼登船；夜间停航，应收白灯。",
	"lamp":"白灯罩内有蓝色新漆与接线，里面套着旧船灯。等候与通航的信号被混用。",
	"bell":"铜钟缺了铜舌，断口很新，棚桌下还有木屑。拆钟与改灯发生在同一时期。",
	"inscription":"黄灯铭文：黄灯等候，钟声归岸；活人不登船，灯灭即离岸。须找周伯核实。",
	"covenant":"周伯核实旧约：铜舌维系停靠约定。他把它装入白罩船灯，怕拆渡口后小满找不到岸。",
	"invitation":"旧屋湿纸：今晚，带上你没给我的东西。它是邀请，不是安全保证。",
	"whistle":"半只铜哨能让许澄辨认姐姐，不会驱邪，也不能证明其他声音可信。",
	"purchases":"灯芯账：周伯已经买过一卷，今晚却又要一卷。阿禾亲手送到棚内。",
	"xu_wish":"许澄认出铜哨。他不愿带姐姐走，只问旧屋屋顶修好了没有；愿意归还旧物后离岸。",
	"xiaoman_wish":"周伯用父女共有的旧事辨认小满；她不要求他忘记，也不要求被永远留在渡口。",
	"shen_wish":"沈渡愿意结束这次渡程，但须两岸表达意愿、归还旧物，解开尚有人没接到便不能走的约。",
	"mark":"钟座背后的陌生刻记，与旅途到来时的一样。只证明有联系，尚不解释世界。"
}
var s: Dictionary = {}
var notice := ""
var save_path := "user://journey.json"

func fresh(identity: String) -> void:
	s = {"version":VERSION, "identity":identity, "phase":"dusk", "place":"house" if identity == "xu" else "street", "x":450.0, "y":410.0, "evidence":[], "items":["铜哨"] if identity == "xu" else ["新灯芯"], "flags":{}, "pollution":0, "ending":"", "journal":[], "left":false}
	note("你体验%s的处境，为其作决定；当地人有自己的生活，并非被你接管的躯壳。" % who())
	if identity == "xu":
		learn("whistle")
	else:
		note("陶婶托你送一卷新灯芯给周伯。先在街口看看账本。")

func who() -> String:
	return "许宁（返乡者）" if s.identity == "xu" else "阿禾（杂货铺学徒）"

func has(id: String) -> bool:
	return id in s.evidence

func flag(id: String) -> bool:
	return bool(s.flags.get(id, false))

func set_flag(id: String) -> void:
	s.flags[id] = true

func item(id: String) -> bool:
	return id in s.items

func give(id: String) -> void:
	if not item(id): s.items.append(id)

func take(id: String) -> void:
	s.items.erase(id)

func note(text: String) -> void:
	notice = text
	s.journal.append(text)

func learn(id: String) -> void:
	if not has(id):
		s.evidence.append(id)
		note(EVIDENCE[id])
	else:
		notice = EVIDENCE[id]

func core() -> bool:
	return has("timetable") and has("lamp") and has("bell") and has("covenant")

func farewell_ready() -> bool:
	return core() and has("xu_wish") and has("xiaoman_wish") and has("shen_wish") and flag("returned") and flag("zhou_farewell")

func change_place(place: String) -> void:
	if not PLACES.has(place): return
	if place == "boat" and (s.identity != "xu" or s.phase != "night"): return
	if s.ending == "flood" and place in ["steps", "boat"]: return
	s.place = place
	s.x = 450.0
	s.y = 440.0

## id is supplied only by nearby world interaction buttons, or by the isolated test.
## Each consequential action still checks its own location, phase and prerequisites.
func act(id: String) -> bool:
	var p: String = s.place
	if s.left:
		notice = "本段体验已结束。可读取离开前的存档，或重新选择身份。"
		return false
	if s.phase == "epilogue":
		if id == "leave" and p == "street":
			s.left = true
			note("旅途记录：%s。保留经历，不带走当地人的财物与身份。许宁与阿禾仍会继续自己的生活。" % ending_name())
			return true
		if id == "epilogue":
			var lines := {
				"street":"陶婶仍在盘点。" + ("她把停航告示钉在门外，暂不再借渡口的工具。" if s.ending == "flood" else "她说今年的灯芯她来买，不是替谁承诺一生。阿禾还要清点货物。"),
				"house":"许宁决定先找人修漏雨的屋顶。卖不卖房，不必在今早一次决定。",
				"shelter":("周伯已随居民撤走。普通渡船停航。" if s.ending == "flood" else ("周伯坐在棚下。普通渡船照常开航。" if s.ending == "light" else "周伯没在第一班船旁，陶婶说他今天睡晚了。普通渡船照常开航，夜船不再回来。")),
				"steps":"旧阶留下" + ("过街水痕，渡口封闭。" if s.ending == "flood" else ("一盏只供等候的黄灯。夜间误唤停止，来年是否等候由当地人决定。" if s.ending == "light" else "安静的系缆石。铜钟还能报时，不再唤回夜船。"))}
			note(lines.get(p, "夜船已经离岸。"))
			return true
		notice = "天已经亮了。可以走访各处，再从街口确认离开。"
		return false
	match id:
		"ledger":
			if p != "street" or s.identity != "he": return refuse("这不是你能核对的店内账目。")
			learn("purchases")
		"yellow":
			if p != "street" or s.identity != "he": return refuse("请在店里以学徒身份向陶婶借灯。")
			give("手提黄灯")
			note("陶婶借出手提黄灯：只供等候，不招呼人上船。你答应天亮归还。")
		"paper":
			if p != "house": return false
			if s.identity == "xu": learn("invitation")
			else: note("许宁把湿纸收在包内。她没说的内容不会自动进入你的记录。可选择明确交换线索，或尊重她的沉默。")
		"exchange":
			if p != "house" or s.identity != "he": return false
			if not has("lamp") or not has("bell"): return refuse("先查到灯罩与钟的异常，才有具体线索交给许宁。拒绝交换也不妨碍恢复旧约。")
			set_flag("xu_help")
			learn("invitation")
			learn("whistle")
			note("你向许宁说明亲眼所见的灯钟变化。她自愿说出纸条与铜哨，答应入夜后在旧阶从岸上核实弟弟；铜哨仍由她保管。")
		"timetable", "bell":
			if p != "shelter": return false
			learn(id)
		"lamp":
			if p != "shelter": return false
			learn("lamp")
		"inscription":
			if p != "shelter": return false
			learn("inscription")
		"verify":
			if p != "shelter": return false
			if not has("inscription"): return refuse("周伯：别凭河上的传言。先看黄灯底座，再来问我。")
			learn("covenant")
		"deliver":
			if p != "shelter" or s.identity != "he" or not item("新灯芯"): return refuse("你已经交过灯芯，不能重复领取。")
			take("新灯芯")
			set_flag("delivered")
			note("阿禾把新灯芯交给周伯。周伯说今夜要让船看得更清楚；你记住这不是平日的用量。")
		"consent":
			if p != "shelter": return false
			if not core(): return refuse("周伯护住灯：你说拆就拆，女儿以后怎么找岸？先核实告示、灯罩、铜钟和旧约，再解释区别。")
			set_flag("consent")
			note("你逐项指出白灯招呼活人、黄灯才是等候，铜舌应归钟。周伯明白恢复边界不等于彻底告别，愿意亲手归还钟舌。")
		"force":
			if p != "shelter" or not core(): return refuse("先弄清灯钟的作用。强夺也不是一把万能钥匙。")
			set_flag("consent")
			set_flag("forced")
			note("你坚持先阻止误唤，周伯最终让开，但不再愿意替你完成告别。恢复边界仍可做；可再认真向他道歉解释。")
		"apologize":
			if p != "shelter" or not flag("forced"): return false
			s.flags.erase("forced")
			note("你向周伯道歉，并承认见女儿的意义。信任不能瞬间恢复，但他愿意重新听取她的意愿。")
		"night":
			if s.phase != "dusk": return false
			s.phase = "night"
			note("你确认结束傍晚。风向变了，夜船靠近旧阶。人物可能移动；遗漏的核心线索和工具仍可补查，没有倒计时。")
		"swap":
			if p != "shelter" or s.identity != "he" or not item("手提黄灯") or not flag("consent"): return refuse("须先借陶婶的黄灯，并让周伯同意区分信号。")
			set_flag("swapped")
			note("阿禾把手提黄灯安在棚边，换下外层白罩；周伯不再举白灯。铜舌仍须归钟才能完成旧约。")
		"board":
			if p != "steps" or s.phase != "night" or s.identity != "xu": return refuse("阿禾没有登船资格，可以在岸上协作。")
			change_place("boat")
			note("许宁踏上仍靠着旧阶的局部船舷。旧物没有姓名。随时可从舷侧返回岸上；登船不自动提供灯钟答案。")
		"xu_voice":
			if s.phase != "night" or not p in ["steps", "boat"]: return false
			if s.identity == "xu" and not item("铜哨"): return refuse("没有铜哨，混合呼唤不能被当作许澄。")
			if s.identity == "he" and not flag("xu_help"): return refuse("你尚未与许宁交换信息、获得协助，不能替她确认弟弟。")
			learn("xu_wish")
			note("铜哨隔开混杂呼唤。许澄问：屋顶还漏吗？许宁答：还没修，我会先找人补。许澄说：我只叫你，不是叫你上船；后来声音太多，不能把那张没有姓名的湿纸当成我的意愿。你明确问他是否想让这一程结束，他说愿意，但不替姐姐决定以后。")
		"xiaoman":
			if p != "steps" or s.phase != "night" or not flag("consent"): return refuse("先与周伯谈妥，他才愿意到旧阶核实女儿的声音。")
			learn("xiaoman_wish")
		"shen":
			if not p in ["steps", "boat"] or s.phase != "night" or not has("covenant"): return refuse("先核实旧约，才知道要向摆渡人询问什么。")
			if s.identity == "he" and (not flag("xu_help") or not has("xu_wish")): return refuse("先主动与许宁合作，并请她携问题核实后回报。阿禾不能读取船上对白。")
			learn("shen_wish")
			if s.identity == "he": note("许宁自愿从靠岸侧舷核实，归岸后明确转述沈渡的答复：愿意结束，但要两岸归还旧物、解除未接到便不能走的约。你只记录她已说出的信息。")
		"return":
			if p != "steps" or not has("xu_wish") or not has("xiaoman_wish") or not has("shen_wish"): return refuse("先分别询问许澄、小满、沈渡。不要把混杂声音当成所有人的共同意愿。")
			set_flag("returned")
			if s.identity == "xu": take("铜哨")
			note("经本人同意，许宁把半哨放回弟弟手边；周伯归还女儿留下的红绳。阿禾只传话，不拿走许宁的物品。旧物不是销毁祭品。")
		"farewell_consent":
			if p != "shelter" or not flag("returned") or flag("forced"): return refuse("先补齐本人意愿与旧物归还；如果强夺伤了信任，请先道歉解释。")
			set_flag("zhou_farewell")
			note("你带回两岸的明确答复，说明这是结束渡程，不是让他忘记。周伯愿意敲最后一次钟，解除沈渡的承诺。")
		"remove_shade":
			if p != "shelter" or not flag("consent"): return refuse("这不是你的灯。先弄清白罩为何被加上，并与周伯谈妥。")
			set_flag("shade_off")
			note("你扶稳旧灯，松开新装白罩的两只卡扣。罩内露出一截用棉线扎住的铜片，河上混杂的呼唤低了下去；钟仍然不响。")
		"retrieve_tongue":
			if p != "shelter" or not flag("shade_off"): return refuse("外层灯罩还扣着，先别硬拉接线。")
			if flag("tongue_home"): return refuse("铜舌已装回钟里。")
			give("拆下的铜舌")
			set_flag("tongue_taken")
			note("你解开棉线，取出铜片。边缘的新断口与钟下的缺口相仿。旧灯还在，但不再兼着一只不该有的钟。")
		"install_tongue":
			if p != "shelter" or not item("拆下的铜舌"): return refuse("钟内的挂孔空着。你手里还没有能装回去的东西。")
			take("拆下的铜舌")
			set_flag("tongue_home")
			note("铜片挂回钟腹，你轻推一下，只响了一声。周伯伸手扶住钟沿，没再替河上的声音应答。黄灯还暗着。")
		"light_yellow":
			if p != "shelter" or s.phase != "night": return refuse("傍晚仍看得清路。等天暗后再决定怎样摆灯。")
			if not core() or not flag("consent") or not flag("shade_off") or not flag("tongue_home"): return refuse("你点起黄灯，白罩与缺舌的钟却还未分清各自的位置。周伯说：一边等，一边招手，船还是会误会。")
			set_flag("yellow_lit")
			finish("light")
		"restore":
			if p != "shelter" or s.phase != "night" or not core() or not flag("consent"): return refuse("留灯需要入夜、告示/灯罩/铜钟/旧约证据，以及周伯对恢复边界的同意。")
			set_flag("shade_off")
			set_flag("tongue_home")
			set_flag("yellow_lit")
			finish("light")
		"untie":
			if p != "steps" or s.phase != "night" or not farewell_ready(): return refuse("解缆未完成：须了解灯钟因果、询问三方意愿、归还旧物，再征得周伯最后敲钟的同意。")
			set_flag("tongue_home")
			set_flag("released")
			finish("untie")
		"danger":
			if p != "shelter" or s.phase != "night": return false
			if flag("swapped"): return refuse("白灯罩已由阿禾安全换下，不能再用它误唤。")
			s.pollution += 1
			if s.pollution == 1:
				change_place("street")
				note("白灯刚举起，河声与水迹越过棚门。你退到街口，白灯放下后侵入停止：通航信号正在招来不该来的乘客。仍可回棚查证修复。")
			else: finish("flood")
		"break":
			if p != "shelter" or s.phase != "night": return false
			s.pollution = 2
			finish("flood")
		"mark":
			if p != "shelter": return false
			learn("mark")
		_:
			return false
	return true

func refuse(text: String) -> bool:
	notice = text
	return false

func finish(result: String) -> void:
	if not s.ending.is_empty(): return
	s.ending = result
	s.phase = "epilogue"
	# The mark is physically seen while handling the bell, or on the exposed base during retreat.
	if not has("mark"):
		s.evidence.append("mark")
		s.journal.append("修灯时 / 撤离经过钟座时，你看见并记下：" + EVIDENCE.mark)
	if result == "flood":
		change_place("street")
		note("漫水：水迹越过街口，周伯与居民撤离，渡口关闭。没有人因一次试探被永久杀死。旅途记下未恢复边界，暂失当地帮助；仍可走访安全区域并离开。")
	elif result == "light":
		change_place("shelter")
		note("留灯：白罩取下，铜舌归钟，黄灯重亮。周伯亲手敲钟：船靠旧阶，活人不登船，灯灭即离岸。沈渡认出旧约，夜间误唤停止。次日到了，你可以自由走访。")
	else:
		change_place("steps")
		note("解缆：周伯敲最后一次钟，沈渡解除尚有人未接到的承诺，亲自解开系缆。话说不完，船仍要离岸。这不是高于留灯的真结局。天明后请走访，再离开。")
	if item("手提黄灯"):
		take("手提黄灯")
		note(notice + " 你把借来的手提黄灯还给陶婶。")

func ending_name() -> String:
	return {"light":"留灯·恢复边界", "untie":"解缆·结束渡程", "flood":"漫水·渡口停航，未恢复边界"}.get(s.ending, "尚未完成")

func save_game() -> bool:
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: return refuse("保存失败：无法写入独立用户目录。")
	file.store_string(JSON.stringify(s))
	file.close()
	var err := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if err != OK: return refuse("保存失败，旧存档保留：%s" % error_string(err))
	notice = "已保存：%s" % ProjectSettings.globalize_path(save_path)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return refuse("尚无此活动的存档，不读取原型存档。")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return refuse("存档JSON损坏，未覆盖当前进度。")
	var data = parser.data
	if not valid_save(data): return refuse("存档格式或状态不合法，未覆盖当前进度。")
	data.version = int(data.version)
	data.pollution = int(data.pollution)
	s = data
	notice = "已读取独立活动存档。"
	return true

func valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in ["version", "identity", "phase", "place", "x", "y", "evidence", "items", "flags", "pollution", "ending", "journal", "left"]:
		if not data.has(key): return false
	if data.version != VERSION or not data.identity in ["xu", "he"]: return false
	if not data.phase in ["dusk", "night", "epilogue"] or not PLACES.has(data.place): return false
	if not data.evidence is Array or not data.items is Array or not data.flags is Dictionary or not data.journal is Array: return false
	if not (data.x is float or data.x is int) or not (data.y is float or data.y is int): return false
	if not is_finite(float(data.x)) or not is_finite(float(data.y)): return false
	if not (data.pollution is float or data.pollution is int): return false
	if not is_finite(float(data.pollution)) or float(data.pollution) != floorf(float(data.pollution)): return false
	if not int(data.pollution) in [0, 1, 2] or not data.ending in ["", "light", "untie", "flood"]: return false
	if (data.phase == "epilogue") != (not data.ending.is_empty()): return false
	if data.place == "boat" and (data.identity != "xu" or data.phase != "night"): return false
	if not data.left is bool or (data.left and data.phase != "epilogue"): return false
	for id in data.evidence:
		if not id is String or not EVIDENCE.has(id): return false
	for id in data.items:
		if not id is String or not id in ["铜哨", "新灯芯", "手提黄灯", "拆下的铜舌"]: return false
	if data.identity == "he" and "铜哨" in data.items: return false
	for line in data.journal:
		if not line is String: return false
	for key in data.flags:
		if not key is String or not data.flags[key] is bool: return false
	if data.ending == "flood" and (data.pollution != 2 or data.place in ["steps", "boat"]): return false
	if data.pollution == 2 and data.ending != "flood": return false
	if data.ending in ["light", "untie"] and data.pollution > 1: return false
	return true
