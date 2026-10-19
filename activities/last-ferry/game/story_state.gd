extends RefCounted
## All facts here are obtained by actions, never by reading author-only story text.
const VERSION := 1
const PLACES := {"street":"杂货铺 / 街口", "shelter":"候船棚", "house":"许家旧屋", "steps":"旧石阶", "boat":"夜船·靠岸侧舷"}
const EVIDENCE := {
	"timetable":"旧通航告示：白灯招呼登船；夜间停航，应收白灯。",
	"lamp":"亲眼所见：白色外罩内有未干透的蓝漆，两根新接线绕着一只旧灯；罩内下缘挂着一截铜片。白罩与内灯不是一同做成的。",
	"bell":"亲眼所见：钟腹挂孔空着，挂钩断口发亮，桌下有新木屑。推钟只能听见绳结碰钟壁，没有从前那种响声。",
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

func missing_sources() -> String:
	var missing: Array[String] = []
	for pair in [["timetable","旧通航告示"],["lamp","白灯罩"],["bell","缺舌铜钟"],["covenant","黄灯底座与周伯的旧约"]]:
		if not has(pair[0]): missing.append(pair[1])
	return "、".join(missing) if not missing.is_empty() else "无；现在可以直接向周伯说明所见。"

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
		"ge_talk":
			if p != "street": return false
			set_flag("ge_met")
			note("老葛蹲在围挡旁补鞋。\n‘昨晚有人叫我吃饭，是我妈的声音。’他用锥子比了一下河边，‘她活着呢，今早还骂我裤脚没洗干净。可昨晚那一声，跟小时候一样。’\n他没说河上全是假的，只说自己的工具袋还挂在旧阶低处，天亮以后才敢去拿。")
		"tool_retrieve":
			if p != "steps" or not flag("ge_met"): return refuse("台阶低处挂着一只布袋，不是无主的东西。先问清楚再拿。")
			if flag("tool_returned") or item("老葛的工具袋"): return refuse("袋子已经拿上来了，不会再多出一份。")
			give("老葛的工具袋")
			note("你不踩湿苔，用上一级石缝里的旧竹竿挑起布袋。袋底破了一个口，少了把扳手；袋绳却还完整。水里有一声很近的‘回来’，没有人因你捡起工具就获准拉你下去。")
		"tool_return":
			if p != "street" or not item("老葛的工具袋"): return refuse("你还没取回工具袋。老葛说不急：鞋还没补好。")
			take("老葛的工具袋")
			set_flag("tool_returned")
			note("老葛接过袋子，数了数工具，没有说谢谢就立刻消失。\n‘扳手没了，别下去找。我还有一把。’他把长凳让出一半，继续缝鞋，‘白灯本来是让活人上船的，这几天周伯拿它照一整夜。我以为他眼睛坏了。你要问就好好问，他听得见。’\n围挡后有人喊他明早量桥。他答应一声，这里的活还没做完。")
		"roof_listen":
			if p != "house": return false
			set_flag("heard_drip")
			note("滴水不在盆里响。水从屋梁裂缝斜落，落在旧桌的脚边；盆的位置是照着上一场雨摆的。" + ("许宁记得弟弟小时候总嫌她挪盆太慢。如今屋里只有自己的脚步。" if s.identity == "xu" else "阿禾见许宁盯着旧盆，没催她。屋子不是待人搜完线索就能丢下的地方。"))
		"basin_take":
			if p != "house" or flag("basin_placed"): return false
			if not flag("heard_drip"): return refuse("先停下来听听。盆里没有新水，漏的地方也许变了。")
			set_flag("basin_carried")
			note("你端起旧搪瓷盆，盆底冰凉。桌脚边有新湿痕，墙下那圈水印却早干了。")
		"basin_wrong":
			if p != "house" or not flag("basin_carried"): return false
			note("你在旧水印下试放盆。水声仍在桌旁响，盆里没有接到水。没有东西受损，你重新端起来。")
		"basin_place":
			if p != "house" or not flag("basin_carried"): return refuse("桌脚边湿着。手里没有能接水的容器。")
			s.flags.erase("basin_carried")
			set_flag("basin_placed")
			note("你把盆挪到桌脚，滴水终于落在盆里。" + ("许宁没有突然释然。她把屋梁的裂缝记在纸背：明天找人来，不再等‘下回’。铜哨在口袋里碰了一下钥匙，像小时候弟弟嫌她磨蹭时敲的两下门。" if s.identity == "xu" else "许宁说：我本来只打算回来签个字。阿禾问要不要找修屋的人，她点了头。你们说了一会儿工钱与瓦片，没有人提河上的声音。"))
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
		"zhou_memory":
			if p != "shelter": return false
			set_flag("heard_zhou")
			note("周伯把灯放在膝上，拇指停在一道旧划痕上。\n‘小满小时候坐船晕，非说盯着岸上这点黄光就不难受。她下船以后，第一件事是骂我没接稳。’\n他笑了一下，又看向桥的围挡。\n‘你们说桥好了，渡口没用了。我也知道。可她要是照旧回来，岸上连个认得的地方都没有，谁告诉她搬哪儿了？’\n" + ("许宁没有说自己也失去过弟弟就一定懂他。她只把半哨攥在手里，等他把话说完。" if s.identity == "xu" else "阿禾本来想说以后自己也能买灯芯，话到嘴边停了：替人守一年，与替人答应一辈子，不是一回事。"))
		"signal_guess":
			if p != "shelter" or not has("lamp") or not has("timetable"): return refuse("先看过白罩和通航告示，猜测才有亲眼所见的依据。")
			set_flag("signal_compared")
			note("你指着告示：‘白灯说可以上船，黄灯说有人在等。如果船看见的是白罩，它会不会以为岸上还有人要走？’\n周伯没有立刻让开：‘我只是想让她看清。你说得像有道理，可你还得告诉我，收了白灯以后，留下什么。’")
		"promise_forever":
			if p != "shelter": return false
			set_flag("promised_forever")
			note("你说可以一直替他守灯。周伯望了你一会儿：‘你明天不回家？后天呢？阿禾也好，许宁也好，都还有自己的事。别为了让我松手，先把自己答进去。’\n他把灯往旁边挪了一点，但没有交给你。这不是一次说错话就失去所有机会；你仍可换一种真实做得到的提议。")
		"waiting_plan":
			if p != "shelter" or not core(): return refuse("先查清你准备动的是什么，再谈怎样留下它。仍缺：" + missing_sources())
			if not flag("heard_zhou"): return refuse("周伯：你讲的是灯，可你还没问过我为什么要守。先听他说完，不必先许诺。")
			if not flag("signal_compared"): return refuse("周伯：黄灯可以留下，但为什么非拆白罩？请把你认为两种灯各在招呼谁说清楚。")
			set_flag("consent")
			note("你没有承诺永远守灯。\n‘今晚让黄灯照旧留在等候的位置。白罩收下，钟舌还回去。明年谁愿意来，可以再商量；不能让今晚路过的人被当成要上船。’\n周伯摸了一下白罩的卡扣：‘收的是这个，不是她。’\n你说是。他没有说想通了，只把手从灯上移开：‘拆的时候扶住底下。旧灯架经不起拧。钟，我来敲。’")
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
			if p != "shelter" or s.identity != "he" or not item("手提黄灯") or not flag("consent"): return refuse(("黄灯已备，但周伯还没有同意。要解释信号冲突，先分别看过通航告示、灯罩、缺舌铜钟与黄灯底座，再与他谈；你现在还没查看：" + missing_sources()) if item("手提黄灯") else "你手里没有借来的黄灯，可先回陶记询问。")
			set_flag("swapped")
			note("阿禾把手提黄灯安在棚边，换下外层白罩；周伯不再举白灯。铜舌仍须归钟才能完成旧约。")
		"board":
			if p != "steps" or s.phase != "night" or s.identity != "xu": return refuse("阿禾没有登船资格，可以在岸上协作。")
			change_place("boat")
			note("许宁踏上仍靠着旧阶的局部船舷。旧物没有姓名。随时可从舷侧返回岸上；登船不自动提供灯钟答案。")
		"listen_river":
			if s.phase != "night" or not p in ["steps", "boat"]: return false
			set_flag("river_heard")
			note("先是一声‘回家吃饭’，像隔着雨从很远的厨房传来；随后有人急急喊‘把东西带来’。两句之间还有很轻的一声抱怨：‘又慢了。’\n水面没有给每个声音配上名字。你可以只听，不回应，也可以退回岸上。");
		"whistle_memory":
			if p != "house" or s.identity != "xu": return refuse("这段往事不是你凭空拥有的。可以向许宁问，而不能替她想起。")
			set_flag("whistle_rhythm")
			note("许宁在旧桌边轻吹半哨。小时候她总吹两短一长，叫许澄回来；弟弟嫌她催，偏要回一长两短，再说‘又慢了’。\n这不是一句神奇口令。她怕自己记错，重试了一遍，最后一声仍有点破。")
		"call_paper":
			if s.phase != "night" or not p in ["steps", "boat"] or not flag("river_heard"): return false
			note("你照着湿纸问要带什么。河上好几处一起回答‘过来’，没有一个先叫你的名字。你停住，没有往前走。\n那张没有署名的纸至少不能替任何一个人表达意愿。回应一次普通问话没有增加侵入。")
		"answer_whistle":
			if s.phase != "night" or not p in ["steps", "boat"]: return false
			if s.identity == "he":
				if not flag("xu_help"): return refuse("你没有许宁的旧约定。若她愿意，可以与她交换亲眼所见，请她自己辨认。")
			elif not flag("whistle_rhythm"):
				return refuse("你吹了一下，水面仍有许多回声。她需要的不是更响的声音，而是自己与弟弟真正约定过的回答；旧屋可能还留着回忆的起点。")
			set_flag("xu_identified")
			note(("许宁在你身旁吹了两短一长。" if s.identity == "he" else "你吹出两短一长，等着，不再跟河上每一声呼唤说话。") + "\n一长，两短。有人说‘又慢了’。随后是一阵很轻的笑。\n‘我以为你听不出来了。’这一次，声音在回答你们之间的事，没有催人上船。你还可以问他想问的，也可以先离开。")
		"ask_roof":
			if not flag("xu_identified") or not p in ["steps", "boat"]: return false
			set_flag("xu_roof_talk")
			note("许澄问屋顶还漏不漏。许宁说还漏。\n‘你不是说下回回来就修？’\n‘我知道。’\n他停了一会儿，说小时候下雨，他其实喜欢拿盆接水：不用被催着出门。许宁说现在没人替他倒盆了。\n他没有因为她回来，就把十四年的缺席说成没关系。两个人暂时都没提船什么时候开。")
		"ask_departure":
			if not flag("xu_identified") or not p in ["steps", "boat"]: return false
			# The older direct rule action stays for compatibility tests, never exposed in UI.
			return act("xu_voice")
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
		if not id is String or not id in ["铜哨", "新灯芯", "手提黄灯", "拆下的铜舌", "老葛的工具袋"]: return false
	if data.identity == "he" and "铜哨" in data.items: return false
	for line in data.journal:
		if not line is String: return false
	for key in data.flags:
		if not key is String or not data.flags[key] is bool: return false
	if data.ending == "flood" and (data.pollution != 2 or data.place in ["steps", "boat"]): return false
	if data.pollution == 2 and data.ending != "flood": return false
	if data.ending in ["light", "untie"] and data.pollution > 1: return false
	return true
