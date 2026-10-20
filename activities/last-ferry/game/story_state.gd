extends RefCounted
## All facts here are obtained by actions, never by reading author-only story text.
const VERSION := 1
const PLACES := {"lane":"修桥绕行巷", "arrival":"桥头落客点", "street":"杂货铺 / 街口", "shelter":"候船棚", "house":"许家旧屋", "steps":"旧石阶", "boat":"夜船·靠岸侧舷"}
const EVIDENCE := {
	"timetable":"旧通航告示：白灯招呼登船；夜间停航，应收白灯。",
	"lamp":"亲眼所见：白色外罩内有未干透的蓝漆，两根新接线绕着一只旧灯；罩内下缘挂着一截铜片。白罩与内灯不是一同做成的。",
	"bell":"亲眼所见：钟腹挂孔空着，挂钩断口发亮，桌下有新木屑。推钟只能听见绳结碰钟壁，没有从前那种响声。",
	"inscription":"黄灯铭文：黄灯等候，钟声归岸；活人不登船，灯灭即离岸。须找周伯核实。",
	"covenant":"周伯核实旧约：铜舌维系停靠约定。他把它装入白罩船灯，怕拆渡口后小满找不到岸。",
	"invitation":"旧屋湿纸：今晚，带上你没给我的东西。它是邀请，不是安全保证。",
	"whistle":"半只铜哨能让许澄辨认姐姐，不会驱邪，也不能证明其他声音可信。",
	"purchases":"灯芯账：周伯已经买过一卷，今晚却又要一卷；新包的这卷记在阿禾经手栏，是否交付须另记。",
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

func lane_water_description() -> String:
	if s.ending == "flood" or s.pollution >= 2: return "水线越过上格，旧蓝字已被淹湿"
	if s.pollution == 1: return "新水线升到中格，傍晚低格的蓝记仍在"
	return "蓝字今日日期与低处湿线"

func roof_visit_active() -> bool:
	return s.phase == "epilogue" and s.ending != "flood" and flag("roof_visit_arranged")

func current_questions() -> String:
	if s.phase == "epilogue": return "天已亮，可以走访当地人，再从街口确认离开。借来的物品仍可亲手归还。"
	var lines: Array[String] = []
	if has("covenant") and not core(): lines.append("你已听过旧约，但还没亲眼核对：" + missing_sources())
	if flag("signal_compared") and not flag("consent"):
		lines.append("你已提出两种信号的区别。" + ("还没有听周伯为什么放不下这处等候；可以直接问他。" if not flag("heard_zhou") else "可以向周伯提出自己做得到的安排，不必许诺守一辈子。"))
	if flag("handover_seen") and not flag("handover_matched"):
		lines.append("交接单把灯与钟分在两处，又留了一笔‘暂夹铜件待修’。纸没说夹的是什么；现场还留没留痕迹？")
	elif flag("handover_matched") and not flag("handover_discussed"):
		lines.append("夹痕与钟架能对上，只能支持物件曾相连。谁借来、后来为什么没还，仍是没问过的经过。")
	elif flag("handover_discussed"):
		lines.append("周伯承认自己借铜舌、拖延归还并举起白罩。这是经管人的说明，不是声音身份的证明，也不是今夜意愿。")
	if s.phase == "night":
		lines.append("旧阶系缆石旁是河声传到岸上的位置；不登船也可在那儿听、辨认或传话。")
		if has("xu_wish") or has("shen_wish") or has("xiaoman_wish"):
			if not has("xu_wish"): lines.append("许宁还没有明确问过弟弟对这程的意愿。")
			if not has("xiaoman_wish"): lines.append("周伯还没有在旧阶辨认女儿、听她谈以后并明确询问这次渡程。")
			if not has("shen_wish"): lines.append("摆渡人的答复尚未确认；阿禾须由许宁明确转述，不能替她读到船上说话。")
			if has("xu_wish") and has("xiaoman_wish") and has("shen_wish") and not flag("returned"): lines.append("三方已作答，旧物还没有经本人同意归还；可在旧阶谈此事。")
			if flag("returned") and not flag("zhou_farewell"): lines.append("旧物已归还。周伯还在候船棚，须带回答复，不能替他答应最后敲钟。")
	if lines.is_empty(): return "你还可以按自己的顺序了解街口、旧屋与候船棚。记录只保存亲眼所见和已经听到的话。"
	return "\n\n".join(lines)

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
	if id == "shelter_dry_stand":
		if s.left or p != "shelter" or s.ending == "flood" or not flag("awning_tied") or flag("shelter_dry_stood") or not Rect2(590,365,135,75).has_point(Vector2(s.x,s.y)): return false
		set_flag("shelter_dry_stood")
		note("你走进拉起的棚布下，肩头终于不再挨那几股滴水。绳端还系在木桩上，积水落在外侧；你在这块干地站了站，再走也不必找人批准。河声仍听得见，没有谁催你立刻去问灯的事。这只是避开棚布滴水，不是能挡住涨水的地方。")
		return true
	if not s.left and id == "lane_level_revisit" and p == "lane" and Vector2(s.x,s.y).distance_to(Vector2(650,300)) < 48:
		var stage := 2 if s.ending == "flood" or s.pollution >= 2 else (1 if s.pollution == 1 else 0)
		var observed_flag := "lane_level_seen_%d" % stage
		var first_visit := not flag("lane_today_level")
		if (stage == 0 and not first_visit) or flag(observed_flag): return false
		set_flag("lane_today_level")
		set_flag(observed_flag)
		note(("首次查看施工水尺：" if first_visit else "回访施工水尺：") + lane_water_description() + "。这是此刻站在尺旁看见的水线，未见过的早先水位不补记。")
		return true
	if s.left:
		notice = "本段体验已结束。可读取离开前的存档，或重新选择身份。"
		return false
	if id == "handover_revisit":
		if p != "house" or not flag("handover_updated"): return false
		note("旧交接单仍有缺角，‘暂夹铜件待修’没有被涂掉。旁边今日附记写着：铜舌归钟，白罩取下。\n两张纸各说自己那一天发生的事。后来的修复不使当年的拖延没发生，也不替将来的人预先作出选择。")
		return true
	if id == "handover_update":
		if p != "house" or not flag("handover_discussed") or not flag("drawer_open"): return false
		if not flag("tongue_home") or not flag("shade_off"): return refuse("还不能记成完成：须亲眼完成铜舌归钟、取下通航白罩。问清经过不等于修好。")
		if flag("handover_updated"): return refuse("今日附记已经留好，不改写旧单。")
		set_flag("handover_updated")
		note("你另取一小张纸，写下今日亲手确认的两件事：铜舌归钟，白罩取下。没有替当年的残姓补名字，也没划掉原单上的‘待修’。\n" + ("许宁把自己的名字写在今日附记下，将两张纸并放。旧屋留下的不再只有一件拖着没做的事。" if s.identity == "xu" else "阿禾把附记递给许宁；她看过后自己放进下层抽屉。获准查看旧单，不等于替屋主改写它。") + "\n这不是给谁结清一生的账，只让下次打开抽屉的人知道，今天做到了哪一步。")
		return true
	if id == "ferry_tag_return":
		if s.left or p != "shelter" or not item("旧渡牌") or flag("ferry_tag_returned") or Vector2(s.x,s.y).distance_to(Vector2(175,320)) >= 96: return false
		take("旧渡牌")
		set_flag("ferry_tag_returned")
		note("你把渡牌挂回告示旁的空钩，刻字朝外。木牌碰了两下棚柱，晃动停了。交班物回到岸上，不表示你已替船上的人答应结束，也不改变灯和钟的状态。")
		return true
	if s.phase == "epilogue":
		if id == "basin_place" and p == "house" and flag("basin_carried") and s.ending != "flood":
			s.flags.erase("basin_carried")
			set_flag("basin_placed")
			note("你把端着的盆放回桌脚漏点。滴水重新落进盆里，瓦片和梁还没有修好。")
			return true
		if id == "leave" and p == "street":
			s.left = true
			note("旅途记录：%s。保留经历，不带走当地人的财物与身份。许宁与阿禾仍会继续自己的生活。" % ending_name())
			return true
		if id == "stock_morning" and p == "street" and s.pollution == 1:
			note(("你昨晚搬上干台的箱子还在。" if flag("stock_dried") else "门边的箱子已不在水里，陶婶后半夜自己搬上了干台。") + "纸包摊开晾着，有几盒火柴仍不能卖。\n陶婶把损耗记进店账，没有在你名字旁画一个勾或叉：‘白天还有人来买盐，这里不能一直停在昨晚。’\n灯的边界修好了，已经湿过的东西却不会因此自动变干。")
			return true
		if id == "return_lamp" and p == "street" and s.identity == "he":
			if not item("手提黄灯"): return refuse("借来的灯已经还了，不必再交一次。")
			take("手提黄灯")
			set_flag("lamp_returned")
			if s.ending == "flood":
				note("阿禾把借来的黄灯递还陶婶。她擦掉提柄上的泥，把它交给领人过桥的邻居。\n‘先照脚下，别朝河上举。’她没结灯油的账，收好铺门钥匙，等街坊都走到干处再走。")
				return true
			note("阿禾把灯放回柜台，擦干提柄上的水。陶婶先看灯，再看他的手：‘没烫着吧？’\n她没有问河上到底来了谁。阿禾说灯芯用了些，账记自己名下。\n陶婶拿起笔，又放下：‘先吃饭，账晚点再算。’")
			return true
		if id in ["roof_commission", "leave_contact"] and p == "house" and s.identity == "xu":
			if flag("morning_decided"): return refuse("许宁已留下今早的安排。不必为了穷尽选项，把刚作的决定反复改写。")
			set_flag("morning_decided")
			if s.ending == "flood":
				set_flag("contact_left")
				note("许宁把联络方式交给陶婶，说明屋里的家信还在上层抽屉，等能安全回来时自己收拾。\n老葛没答应午后就带师傅来：路和水势要先确认。她把修屋写成日后的安排，不让任何人为今天进屋冒险。")
				return true
			if id == "roof_commission":
				set_flag("roof_commissioned")
				s.flags.erase("basin_carried")
				set_flag("basin_placed")
				var opening := "许宁在门边等到老葛路过，问他认不认识补瓦的师傅。老葛说午后可带人来，只看屋顶，不替她决定房子的事。"
				if flag("roof_inspected"):
					opening = "许宁把老葛留下的两项工序抄进纸背，确认午后可带人来先看瓦；梁另请木工，不把勘看当作已经修好。"
				elif flag("roof_visit_arranged"):
					opening = "许宁把昨晚约好的门牌纸放在桌边。老葛还没进屋勘看，她留话先看漏点，再谈午后可带人来的安排，不让口头约定变成已完的工。"
				note(opening + "\n她把钥匙留给陶婶保管，写下自己的电话。盆里的水还没倒，先做能做完的一件。她确认盆放在桌脚新湿处，不再把它挪回滴不到水的老位置。")
			else:
				set_flag("contact_left")
				note("许宁还不能答应自己会留下。她写了电话号码，压在陶婶以前给的糖纸下面，请有屋顶消息就联系她。\n没写‘永不再走’，也没把房子交给河上的声音。关门时，她回头确认窗扣上了。")
			return true
		if id == "morning_ge" and p == "street" and s.ending == "flood":
			note("老葛把鞋摊收进木箱，用补鞋的粗线替邻居扎紧撤离包。渡口今天不营业，他也没说河里的人会替活人收拾。\n‘先上桥那头借一晚屋。等水退了，少什么，再回来一件件认。’他留着回来的打算，不把停航说成一切都结束。")
			set_flag("morning_ge_seen")
			return true
		if id == "morning_ge" and p == "street":
			note(("老葛接过昨晚归还的工具袋，翻出锥子继续补鞋：‘等鞋干了，我去桥上看看。’" if flag("tool_returned") else "老葛把缺了工具的位置空在脚边，先用借来的锥子补鞋：‘袋子晚些再找，今天也得开张。’") + "\n他母亲从巷里喊他吃饭。他应了一声，回头问你要不要加双鞋垫。昨晚听到的声音没有替今早过日子。")
			set_flag("morning_ge_seen")
			return true
		if id == "roof_admit" and p == "house" and flag("roof_visit_arranged") and s.ending != "flood":
			if flag("roof_guest_admitted") or flag("roof_inspected"): return refuse("老葛已经应邀进屋，不必重新开一次门。")
			set_flag("roof_guest_admitted")
			note("你走到门口，老葛收起量桥的绳尺：‘现在方便？’你点头让开门。他擦掉鞋底的泥才进来，停在干地上，等你指漏点。钥匙没有交出去。")
			return true
		if id == "roof_guide" and p == "house" and roof_visit_active() and flag("roof_guest_admitted") and not flag("roof_inspected"):
			set_flag("roof_guiding")
			note("老葛握着竹竿等你带路：‘你先站到桌脚湿痕旁的干处，我跟过去。不踩水，也别站到梁正下。’")
			return true
		if id == "roof_show" and p == "house" and flag("roof_guiding") and roof_visit_active():
			if Vector2(s.x,s.y).distance_to(Vector2(510,370)) > 75: return false
			if flag("roof_leak_shown"): return false
			set_flag("roof_leak_shown")
			note("你站在桌脚旁的干处，指给老葛看这次的新湿痕。他跟到近处停下：‘看见了，水是斜落的。你让开些，我从这里看瓦缝，不上梁。’靠近他便可继续勘看。")
			return true
		if id == "roof_inspect" and p == "house" and flag("roof_visit_arranged") and s.ending != "flood":
			if not flag("roof_guest_admitted") and not flag("roof_inspected"): return refuse("老葛还在门口等，先去招呼他，不能替屋主开门。")
			if flag("roof_inspected"): return refuse("工序纸已经留在桌边。瓦片和梁仍待分项处理，不必重演一遍勘看。")
			if not flag("roof_leak_shown"): return refuse("先带老葛到桌脚湿痕旁的干处，指清这次的漏点。")
			set_flag("roof_inspected")
			note("老葛在门口叫过你，才进屋。他站在干地上顺着水痕看梁，用竹竿指了指错开的两片瓦，没有往朽梁上搭梯。\n‘这边瓦能先补，梁得叫木工看过。午后我带补瓦的人来，你人在就一起看；不在得另约，钥匙别随便塞门缝。’\n他把门牌纸翻过来写下两项工序，留在旧桌边。" + ("盆还要留着接水。" if flag("basin_placed") else "他指着桌脚滴水：先把盆放回漏点，别让水一直落在地上。") + "修屋不是已经完成。")
			return true
		if id == "roof_note_read" and p == "house" and flag("roof_inspected"):
			note("门牌纸背面分着两栏：\n一、错开的瓦片，午后先由补瓦师傅看，人在再商量开工。\n二、梁缝与朽处，另请木工判断，不能把补瓦当换梁。\n两栏都没有完工勾记。纸留在桌边。" + ("盆继续接水。" if flag("basin_placed") else "滴水仍落在桌脚，盆还没有放回漏点。"))
			return true
		if id == "epilogue":
			var lines := {
				"street":"陶婶仍在盘点。" + ("她把停航告示钉在门外，暂不再借渡口的工具。" if s.ending == "flood" else "她说今年的灯芯她来买，不是替谁承诺一生。阿禾还要清点货物。" + ("他把昨晚留店的那卷重新包好，是否送货的决定也写在自己账下。" if flag("wick_kept") else "")),
				"house":"许宁决定先找人修漏雨的屋顶。卖不卖房，不必在今早一次决定。",
				"shelter":("周伯已随居民撤走。普通渡船停航。" if s.ending == "flood" else ("周伯坐在棚下。普通渡船照常开航。" if s.ending == "light" else "周伯没在第一班船旁，陶婶说他今天睡晚了。普通渡船照常开航，夜船不再回来。")),
				"steps":"旧阶留下" + ("过街水痕，渡口封闭。" if s.ending == "flood" else ("一盏只供等候的黄灯。夜间误唤停止，来年是否等候由当地人决定。" if s.ending == "light" else "安静的系缆石。铜钟还能报时，不再唤回夜船。"))}
			note(lines.get(p, "夜船已经离岸。"))
			return true
		notice = "天已经亮了。可以走访各处，再从街口确认离开。"
		return false
	if (flag("closing_light") or flag("closing_release")) and id in ["light_yellow", "restore", "untie", "danger", "break", "swap", "remove_shade", "retrieve_tongue", "install_tongue", "return", "farewell_consent"]:
		return refuse("今晚已经点灯恢复边界，周伯在旧阶等着兑现敲钟的承诺。可以继续走动、交谈或保存，不必重做装置或把另一个结局叠在上面。")
	if flag("released") and flag("closing_release") and id in ["board", "xu_voice", "answer_whistle", "listen_river", "ask_departure", "ask_roof", "xiaoman", "xiaoman_recognize", "xiaoman_wait", "xiaoman_ask", "shen", "whistle_short", "whistle_long", "whistle_listen"]:
		return refuse("船已离岸。不能隔着已经结束的渡程继续索要回答；仍可陪岸上的人站一会儿，再迎接天明。")
	match id:
		"awning_tie":
			if p != "shelter" or flag("awning_tied") or Vector2(s.x,s.y).distance_to(Vector2(690,350+float(s.get("awning_pull",0.0)))) > 100: return false
			if float(s.get("awning_pull",0.0)) < 85: return refuse("绳端还没拉到木桩旁，你暂时松手；棚布仍低垂，可以再握住继续拉。")
			set_flag("awning_tied")
			note("你把拉紧的绳绕在木桩上，低垂的棚布抬起，积水从外侧落下。棚下多出一块可站的干处。" + ("周伯的凳子空着，他还在旧阶；你把凳脚挪离积水，没喊他回来。" if flag("closing_light") or flag("closing_release") else "周伯挪了挪凳脚：‘这边不滴了。你歇脚就站这里。’") + "灯与钟仍是原来的样子。")
		"lane_old_level":
			if p != "lane" or flag("lane_old_level") or Vector2(s.x,s.y).distance_to(Vector2(200,300)) >= 48: return false
			set_flag("lane_old_level")
			note("桥墩旧洪痕：一道褐色横线已经干裂，旁边刻着旧年份。它记的是过去涨到这里的水，不是今天正在上涨的水位。")
		"lane_today_level":
			if p != "lane" or flag("lane_today_level") or Vector2(s.x,s.y).distance_to(Vector2(650,300)) >= 48: return false
			set_flag("lane_today_level")
			note("施工水尺：" + lane_water_description() + "。傍晚读数的蓝记和此刻水线分开留着，不能拿桥墩旧洪痕代替今天的读数；也不能只凭旧照片猜现在的水深。")
		"ledger":
			if p != "street" or s.identity != "he": return refuse("这不是你能核对的店内账目。")
			learn("purchases")
		"wick_keep":
			if p != "street" or s.identity != "he" or not item("新灯芯"): return refuse("只有经手这卷灯芯的阿禾能重新安排这份货。")
			take("新灯芯")
			set_flag("wick_kept")
			note("阿禾把未送出的灯芯放回干货抽屉，在周伯名字旁划掉‘再送一卷’，写明‘今晚未交，留店待用’。\n陶婶问是不是忘了送。他说不是，想先看看棚里已有的灯为什么还不够。她把账推回来：‘那这笔就由你自己跟他说。’\n这不替周伯决定要不要等谁，也不禁止你以后去找他。")
		"wick_explain":
			if p != "shelter" or s.identity != "he" or not flag("wick_kept"): return false
			set_flag("wick_explained")
			note("阿禾直说今晚没有再带一卷灯芯，不是忘送，也不是代陶婶拒收账。\n周伯看了他空着的手一眼：‘你也会自己拿主意了。’\n他没因此把灯交给你。你仍得问明白他为什么要照这一整夜；不多供一卷货，也不能替他收起女儿回来的位置。")
		"yellow":
			if p != "street" or s.identity != "he": return refuse("请在店里以学徒身份向陶婶借灯。")
			give("手提黄灯")
			note("陶婶借出手提黄灯：只供等候，不招呼人上船。你答应天亮归还。")
		"root_view", "stairs_view", "socket_view":
			if p != "steps": return false
			set_flag(id)
			var descriptions := {"root_view":"柳树上半截已经锯掉，老根仍从干阶斜向河面。从现在站的干阶能看清根须扎向水边；照片里写的左右取决于拍摄者站在哪边，不能直接当成眼前屏幕的左右。", "stairs_view":"新岸沿高高压在旧岸后面，下面三道窄阶只容半只脚。石面上水磨出的弧线连着，不是新棚前那段后来浇出的宽台。你没有为数阶踏进湿苔。", "socket_view":"方槽里没有宝物，只有方木留下的压痕和两枚锈钉。槽口朝旧阶开，离如今系缆石很近。曾有一根柱子在这里站过；现灯在上游，并不能把这段石头也搬过去。"}
			note(descriptions[id])
		"drawer_permission":
			if p != "house" or s.identity != "he": return false
			set_flag("drawer_allowed")
			note("阿禾问能否看看旧桌。许宁把自己的信收回包里，只指下层抽屉：‘渡口公用东西的单子在那层。别翻上面的家信。看完留在屋里。’")
		"drawer_open":
			if p != "house": return false
			if s.identity == "he" and not flag("drawer_allowed"): return refuse("这是许家的抽屉，先问屋主。没得到许可，不替别人决定哪些旧物可以公开。")
			set_flag("drawer_open")
			note("下层抽屉被潮气卡住。你托着底板慢慢拉开，露出一张折起的公用物件交接单；上层家信没有动。")
		"handover_read":
			if p != "house" or not flag("drawer_open"): return false
			set_flag("handover_seen")
			note("纸上分两栏：‘迁到新棚：候船凳二、灯柱一、白色通航灯罩一。’‘暂留旧阶：铜钟一，报班照旧；新棚不另设钟。’\n收讫栏是周伯的姓，另一行只剩许字，日期边缘缺了一块。背面补记‘灯罩裂，暂夹铜件固定，待修’；没写铜件是什么，也没写后来谁动过。\n纸折回原来的痕里，仍留在下层抽屉。上层家信没有动。")
		"photo_view":
			if p != "house": return false
			set_flag("photo_seen")
			note("窗边旧照片边角粘着修屋时的灰。照片上有三道矮阶，一棵向河面斜生的柳树；灯挂在最上一级靠左的木柱上。\n照片背面写着‘新棚启用前，最后一班日渡’。远处没有如今桥梁的围挡。人脸已褪了，不足以凭相貌认出谁；你记下的是岸的位置。")
		"photo_same", "photo_shift":
			if p != "steps" or not flag("photo_seen"): return refuse("手边还没有可对照的旧照片。")
			if id == "photo_same":
				note("你先把照片里的灯对准如今棚内的亮处。可照片里柳树在台阶右侧，眼前同一段老根却在左后方；顺着新棚方向看，三道矮阶也对不上。\n你换一个站位再看。灯可以挪，岸边留下的石缝未必跟着挪。这个猜测没让河上多来什么，也不用向任何人道歉。")
			else:
				if not flag("root_view") or not flag("stairs_view") or not flag("socket_view"):
					var gaps: Array[String] = []
					if not flag("root_view"): gaps.append("柳根的朝向是否与你站的位置有关")
					if not flag("stairs_view"): gaps.append("照片里三道矮阶是否真在新岸下面")
					if not flag("socket_view"): gaps.append("旧柱究竟留下了什么痕迹")
					return refuse("这个想法可以先留着，但还没有亲眼核对：" + "、".join(gaps) + "。\n照片不是一张答案纸；先在干阶边看清，再回来比较。夜里也能补查，不必赶时间。")
				set_flag("photo_compared")
				note("你不追着灯找位置，先沿老柳根向下数三道矮阶，再转身。照片里的木柱原来立在现在的系缆石旁。\n新棚移到了上游的干地，旧等候的位置却留在这里。周伯所说‘回来找不到岸’不只是怕看不见亮光，也可能是在怕认得的地方被换走。\n这不能替他表达意愿，更不能证明船上的每个声音都可信；你只是终于站在了旧照片拍摄的岸上。")
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
		"roof_help":
			if p != "street" or not flag("heard_drip"): return false
			set_flag("roof_help_asked")
			note("陶婶放下杯子：‘先别往梁上爬。老葛会看瓦，他明早量桥前还能走一趟。你把漏在哪儿告诉他，别只说屋顶坏了。’\n她指了指檐下补鞋的人，没有替他应下工钱。")
		"roof_recall":
			if p != "street" or not flag("roof_visit_arranged"): return false
			note("老葛敲了敲针线盒下的门牌纸：‘记着呢，明早量桥前，先在门口叫你。只看漏点，不是已经开工。今晚先让盆接着。’")
		"roof_arrange":
			if p != "street" or not flag("heard_drip"): return false
			if flag("roof_visit_arranged"): return refuse("明早看瓦已经约好，可以核对安排，不必再记一次门牌。")
			set_flag("roof_visit_arranged")
			note("你说清水从梁缝斜落到桌脚，旧水印已经干了。老葛在包鞋纸背记下许家门牌。\n‘明早量桥前，我从门口叫你。先看瓦，梁要是朽了得另请人。今晚别自己上去。’\n他把纸压在针线盒下，接着收最后一段鞋线。没有报价，也还没有动屋顶。")
		"roof_arrangement":
			if p != "house" or not flag("roof_visit_arranged"): return false
			note("裂缝旁添着一行自己的字：明早等老葛来门口叫，先看瓦，再定工。" + ("盆仍在接水。" if flag("basin_placed") else "滴水仍落在桌脚，盆没有在漏点下。") + "梁缝没有变小。钥匙留在自己手里。")
		"roof_listen":
			if p != "house": return false
			set_flag("heard_drip")
			note("滴水不在盆里响。水从屋梁裂缝斜落，落在旧桌的脚边；盆的位置是照着上一场雨摆的。" + ("许宁记得弟弟小时候总嫌她挪盆太慢。如今屋里只有自己的脚步。" if s.identity == "xu" else "阿禾见许宁盯着旧盆，没催她。屋子不是待人搜完线索就能丢下的地方。"))
		"basin_take":
			if p != "house" or flag("basin_carried"): return false
			if s.phase == "epilogue": return refuse("先让盆留在滴水处；屋顶还没有修好。")
			if not flag("heard_drip"): return refuse("先停下来听听。盆里没有新水，漏的地方也许变了。")
			var was_catching := flag("basin_placed")
			s.flags.erase("basin_placed")
			set_flag("basin_carried")
			note("你重新端起接水的盆。滴水又落在桌脚边，盆暂时没有接住。" if was_catching else "你端起旧搪瓷盆，盆底冰凉。桌脚边有新湿痕，墙下那圈水印却早干了。")
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
		"handover_lamp", "handover_bell":
			if p != "shelter" or not flag("handover_seen"): return false
			learn("lamp" if id == "handover_lamp" else "bell")
			if has("lamp") and has("bell"): return act("handover_compare")
			note("白罩内缘的夹痕露出来了，压进去的薄边留下浅浅亮线。折单没画尺寸，钟架那头还没核对。" if id == "handover_lamp" else "你按折单看钟架的挂孔，孔沿有新木屑和亮断口。灯罩那头还没核对，暂时只记下这里。")
		"handover_compare":
			if p != "shelter" or not flag("handover_seen"): return false
			if not has("lamp") or not has("bell"): return refuse("折单只说暂夹铜件。还没亲眼看过灯罩的夹痕与钟架缺口，不能把两个空白直接连成一件事。")
			set_flag("handover_matched")
			note("你把记下的两栏分别对着现场看：白罩内缘留着夹压亮痕，" + ("归位铜舌的薄边与它相合。" if flag("tongue_home") else "钟架挂孔宽度与它相近。") + "亮痕旁没有刻名字。单上的‘待修’也没有划掉。\n棚外传来周伯挪凳子的声音，木脚在地上擦了一下。")
		"handover_zhou":
			if p != "shelter" or not flag("handover_matched"): return false
			set_flag("handover_discussed")
			note("周伯接着你说的‘待修’，没有把责任推给纸上缺掉的名字。\n‘罩裂那天是我借的铜舌，够薄，能卡住。我说等新扣件到了就还。凳子搬了，班照常报；后来不报了，我就老想着明天。’\n他说最后一次把白罩朝水举起，是想让等的人看得见，不是旧交接单叫他这样做的。‘不是谁留下的一条规矩，是我把几件事混在一起，拖到今天。’\n周伯用拇指抹了抹凳沿的灰，把话停在那里。棚里还能听见灯芯偶尔噼的一声。")
		"zhou_memory":
			if p != "shelter": return false
			set_flag("heard_zhou")
			note("周伯把灯放在膝上，拇指停在一道旧划痕上。\n‘小满小时候坐船晕，非说盯着岸上这点黄光就不难受。她下船以后，第一件事是骂我没接稳。’\n他笑了一下，又看向桥的围挡。\n‘你们说桥好了，渡口没用了。我也知道。可她要是照旧回来，岸上连个认得的地方都没有，谁告诉她搬哪儿了？’\n" + ("许宁没有说自己也失去过弟弟就一定懂他。她只把半哨攥在手里，等他把话说完。" if s.identity == "xu" else "阿禾本来想说以后自己也能买灯芯，话到嘴边停了：替人守一年，与替人答应一辈子，不是一回事。"))
		"hypothesis_voices":
			if p != "shelter": return false
			set_flag("guessed_all_false")
			note("你说河上的声音可能全是假的，索性一概不听。\n周伯问：‘老葛他娘还活着，他听到旧时候的声音，这说明有假的。可你怎么拿它证明，这里没有一个真的？’\n他没有因为你怀疑就发火：‘不听可以是你的选择，不能拿来替别人说他们等的谁都不存在。你要修的，是这盏灯怎么把人招上船。’")
		"hypothesis_brightness":
			if p != "shelter" or not has("lamp"): return refuse("先走近看过灯，再谈它哪里不对。")
			set_flag("guessed_brightness")
			note("你指着白罩，说也许只是太亮，遮暗些就好。\n周伯捻了一下灯芯：‘若只讲亮，黄灯拨旺也亮。旧告示上说的白灯，是照路，还是叫人做什么？’\n他没有给你记一次错。罩子的颜色、挂的位置、朝哪边开，不只是火有多大；你可以拿告示再比较。")
		"hypothesis_signals":
			if p != "shelter" or not has("lamp") or not has("timetable"): return refuse("这种解释需要你亲眼看过白罩与通航告示。两者都可以回现场补看。")
			return act("signal_guess")
		"signal_guess":
			if p != "shelter" or not has("lamp") or not has("timetable"): return refuse("先看过白罩和通航告示，猜测才有亲眼所见的依据。")
			set_flag("signal_compared")
			note("你指着告示：‘白灯说可以上船，黄灯说有人在等。如果船看见的是白罩，它会不会以为岸上还有人要走？’\n周伯没有立刻让开：‘我只是想让她看清。你说得像有道理，可你还得告诉我，收了白灯以后，留下什么。’")
		"photo_zhou":
			if p != "shelter" or not flag("photo_compared"): return refuse("还没有亲眼核对旧岸，不能替照片补一个结论。")
			set_flag("photo_discussed")
			note("你说了老柳根、三道窄阶和柱槽的位置，没有把相片里的人脸当作证据。\n周伯把手掌摊在膝上：‘新棚是我跟人一起挪的。那年水上来，旧阶湿得站不住。我以为只要灯还在，她就知道往哪儿回。’\n" + ("许宁说旧屋东西没怎么动，回来却也有不认识的地方。她没有借这句话替他决定搬走。" if s.identity == "xu" else "阿禾想起陶记柜台换过位置，熟客还会伸手去够原来的糖罐。熟悉不是把一切钉死，搬动也不等于谁都马上认得。") + "\n周伯说：‘你能替我指出老地方，不能替她说要站在哪儿。’他愿意继续谈，但恢复信号与问本人意愿仍是后面的事。")
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
			set_flag("boat_arrival_pending")
			note("你确认结束傍晚。风向变了，夜船靠近旧阶。人物可能移动；遗漏的核心线索和工具仍可补查，没有倒计时。")
		"swap":
			if p != "shelter" or s.identity != "he" or not item("手提黄灯") or not flag("consent"): return refuse(("黄灯已备，但周伯还没有同意。要解释信号冲突，先分别看过通航告示、灯罩、缺舌铜钟与黄灯底座，再与他谈；你现在还没查看：" + missing_sources()) if item("手提黄灯") else "你手里没有借来的黄灯，可先回陶记询问。")
			set_flag("swapped")
			set_flag("shade_off")
			note("阿禾把借来的黄灯安在等候的位置，白罩放在灯旁；周伯不再举白灯。" + ("铜舌已挂回钟里。黄灯尚未点亮，可以在底座旁等到入夜再点。" if flag("tongue_home") else "灯内的铜片还需取出，挂回铜钟。"))
		"ferry_tag_take":
			if p != "boat" or s.identity != "xu" or flag("released") or flag("ferry_tag_taken") or Vector2(s.x,s.y).distance_to(Vector2(685,420)) >= 96: return false
			set_flag("ferry_tag_taken")
			give("旧渡牌")
			note("沈渡把舷边一块木牌翻过来，背面刻着‘末班交回岸棚’。‘这块不是谁的遗物，是交班的。岸上的空钩还在，就帮我挂回去；不在也别往水里扔。’你接过他递来的牌，边角摸得发亮。")
		"board":
			if flag("boat_arrival_pending"): return refuse("船还在靠近，侧舷与干阶之间尚有水隙。先留在岸上，不必抢着跨过去。")
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
		"whistle_short", "whistle_long":
			if s.identity != "xu" or not item("铜哨") or s.phase != "night" or not p in ["steps", "boat"]: return refuse("这不是你手里的物品；阿禾可以请许宁自己回应，不必模仿她的回忆。")
			if not flag("river_heard"): return refuse("先听一听，再决定朝哪个方向吹。")
			var count := 0
			for n in range(3):
				if flag("whistle_note_" + str(n)): count += 1
			if count >= 3: return refuse("已吹完三声。先停下听，或重新来，不必一直吹。")
			set_flag("whistle_note_" + str(count))
			if id == "whistle_long": set_flag("whistle_long_" + str(count))
			note("铜哨：" + ("——（长音）" if id == "whistle_long" else "·（短音）") + "\n这是第%s声。你还可以接着吹，或停下听。" % (count + 1))
		"whistle_reset":
			if s.phase != "night" or not p in ["steps", "boat"]: return false
			for n in range(3):
				s.flags.erase("whistle_note_" + str(n))
				s.flags.erase("whistle_long_" + str(n))
			note("你放下哨子，等回声消失。可以重新试，不必跟着每个声音回答。")
		"whistle_listen":
			if s.identity != "xu" or s.phase != "night" or not p in ["steps", "boat"]: return false
			if not flag("whistle_note_2") or flag("whistle_long_0") or flag("whistle_long_1") or not flag("whistle_long_2"):
				note("水面把你吹过的声音原样送回来。没有那句熟悉的抱怨。许宁没有往前走；可以想想旧屋里练过的回答，再试一次。")
				return true
			if not flag("whistle_rhythm"): return refuse("回声与记忆似乎相像，但你还不能只凭巧合认人。旧屋里留下的往事，可先亲自想一遍。")
			return act("answer_whistle")
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
		"xiaoman_recognize":
			if p != "steps" or s.phase != "night" or not flag("consent"): return refuse("先与周伯谈妥，他才愿意一起到旧阶听清楚。")
			set_flag("xiaoman_known")
			note("周伯没有朝每一声‘爹’应答。他问：‘上回摔坏了什么，还赖我没接稳？’\n声音答：‘不是碗，是你给我装的那面小镜子。你说旧船晃，怪不得你。’\n周伯低头笑了一下：‘是我装歪了。’\n水面还黑着，他不再催你判断眼前究竟算什么。至少这句话，是他们之间的。")
		"xiaoman_wait":
			if p != "steps" or not flag("xiaoman_known"): return false
			set_flag("xiaoman_heard")
			note("周伯问来年还点不点灯。小满先问桥修好后，他是不是终于能去城里看腿。\n‘你不是一直说坐车头晕？’\n‘我会挑慢一点的车。’\n她没有叫他忘记，也没让他证明愿意等多久。周伯说那盏灯也不是只给她一个人看的。\n你还没有替他们问出最终答案，可以先听着，或明确谈这条夜船往后怎么办。")
		"xiaoman_ask":
			if p != "steps" or not flag("xiaoman_known"): return refuse("先让周伯辨认他女儿的回应，别向一片河声索要同意。")
			if not flag("xiaoman_heard"): return refuse("她还没有讲完以后想怎样过。先听听，不要把辨认当作同意。")
			learn("xiaoman_wish")
			note("你问的是这一次渡程要不要结束，不是她还爱不爱父亲。\n小满说：‘可以。我不想每次见面，都得先让他担心又没接到谁。’\n周伯没有马上点头，问她那根红绳呢。她说愿意自己拿着，打结总比他打得好。这回他说，好。")
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
			set_flag("closing_light")
			note("黄灯芯接住火，白罩仍放在旁边。周伯试了试钟绳，没有敲。\n‘棚里听得见，河上不一定。到旧阶去吧——钟我来敲。’\n他提起钟绳另一端的小铜柄，沿棚边走下去。夜晚还没有结束，你可以跟到旧阶，也可以先看看灯。")
		"closing_ring":
			if p != "steps" or not flag("closing_light") or flag("closing_rang"): return false
			set_flag("closing_rang")
			note("周伯站在干阶上，拉直通往棚里的钟绳。第一下响得短，他松开手，等水面那声回音过去，再敲第二下。\n‘船靠旧阶，活人不登船。’\n船边有人应：‘听见了。’\n有个很轻的声音叫了声爹。周伯抬头，没有举起白灯。黄光只落在岸上的空位，不再替过路人招手。")
		"closing_speak", "closing_silent":
			if p != "steps" or not flag("closing_rang"): return false
			set_flag("closing_answered")
			if id == "closing_speak":
				set_flag("closing_spoke")
				note("你说：‘灯还在。不是让谁上船的灯。’\n周伯嗯了一声：‘我知道。’\n他没有说以后再也不会等，只把钟柄放下。沈渡扶正船边原本朝岸伸出的踏板：‘今夜没有新客。’混在一起的呼唤渐渐分开，不再从街口传来。")
			else:
				note("你没有替父女补一句告别的话。周伯的手在钟柄上停了一会儿，然后慢慢放开。\n船边那个声音也没有再催。沈渡把朝岸伸出的踏板收回去：‘今夜没有新客。’\n你们站在各自的位置，听见普通的水声重新露出来。")
		"closing_watch":
			if p != "steps" or not flag("closing_rang"): return false
			note("棚里的黄光隔着水汽摇了一下，并没有熄。周伯把坐惯的矮凳拖到干处，给后来人留出路。\n没有声音宣布一切已经好了。街口有人落下店门的木栓；今夜先到这里。你可以再站一会儿，也可以亲自结束夜晚。")
		"closing_dawn":
			if p != "steps" or not flag("closing_rang"): return refuse("先到旧阶，听周伯把钟敲完。不是多找一件东西，是把已经答应的事做完。")
			finish("light")
		"restore":
			if p != "shelter" or s.phase != "night" or not core() or not flag("consent"): return refuse("留灯需要入夜、告示/灯罩/铜钟/旧约证据，以及周伯对恢复边界的同意。")
			set_flag("shade_off")
			set_flag("tongue_home")
			set_flag("yellow_lit")
			finish("light")
		"begin_release":
			if p != "steps" or s.phase != "night" or not farewell_ready() or flag("closing_light"): return refuse("先让两岸的人分别作答、归还旧物，再带回周伯愿意敲最后一次钟的答复。不是由你替他们断开联系。")
			var repair := ""
			if not flag("tongue_home"):
				repair = "周伯先把钟提到干阶边。" + ("你把随身带着的铜舌交给他。" if item("拆下的铜舌") else "他卸下白罩，取出压在灯内的铜舌。") + "他当面挂回钟腹，轻试一下，确认金属能碰响。白灯不再招人上船；最后一声由他来敲。\n"
				set_flag("shade_off")
				set_flag("tongue_taken")
				set_flag("tongue_home")
				take("拆下的铜舌")
			set_flag("closing_release")
			note(repair + "你把最后的答复带到干阶上。周伯没有举灯，而是把红绳剩下的线头收进衣袋。\n‘这次不是谁没接到。’他说。\n沈渡听完，低头看了一眼系缆石：‘那就由我解。你们留在岸上。’\n他没有把绳索递给你。你可以看着他做完，也可以先和岸上的人站一会儿。")
		"release_rope":
			if p != "steps" or not flag("closing_release") or flag("released"): return false
			s.flags["boat_arrival_pending"] = false
			set_flag("released")
			set_flag("tongue_home")
			note("周伯敲钟。沈渡把缆绳从石上绕回来，慢慢解开被水泡紧的结；中间卡了一下，他换了只手。\n‘这边已到齐。’岸上传过去。\n‘那边也应了。’他回答。\n船离开半尺，没再把踏板伸出来。不是水面突然变得空白，而是那盏旧船灯终于有了离岸的方向。")
		"release_watch":
			if p != "steps" or not flag("released"): return false
			note("许宁把空下来的手放进口袋。周伯拣起落在石缝里的短线头，没往河里抛。\n有人像还想说一句，船上却只传来一声知道了。水仍在流，你们不用站到所有话都说完才回去。")
		"release_dawn":
			if p != "steps" or not flag("closing_release") or not flag("released"): return refuse("缆绳还在石上，等沈渡自己完成解约。")
			finish("untie")
		"untie":
			if p != "steps" or s.phase != "night" or not farewell_ready(): return refuse("解缆未完成：须了解灯钟因果、询问三方意愿、归还旧物，再征得周伯最后敲钟的同意。")
			set_flag("tongue_home")
			s.flags["boat_arrival_pending"] = false
			set_flag("released")
			finish("untie")
		"stock_take":
			if p != "street" or s.phase != "night" or s.pollution != 1 or flag("stock_dried") or flag("stock_carried"): return false
			set_flag("stock_carried")
			note("你托住箱底，湿纸贴住手背。干台就在柜台右边，先把箱子送到那里，再放下；也可以原地放回。")
		"stock_put_back":
			if p != "street" or not flag("stock_carried"): return false
			s.flags.erase("stock_carried")
			note("你把箱子放回门边稳住，没有把搬到一半写成已经晾干。")
		"move_wet_stock":
			if p != "street" or s.phase != "night" or s.pollution != 1: return false
			if flag("stock_dried"): return refuse("箱子已搬到干台，不必来回折腾货物。")
			if not flag("stock_carried"): return refuse("先托起门边的箱子，再送到干台。")
			s.flags.erase("stock_carried")
			set_flag("stock_dried")
			note("你托住浸湿的箱底，把门边的货箱挪上干台。纸边已经软了，里面的火柴另摊开，不能假装没湿过。\n陶婶没问你是不是故意的。她说：‘这箱我来收。先别再举那盏白的，棚里到底怎么回事，你去看清。’\n搬箱没有使侵入数变回零，也没替任何人原谅你；只是眼下这点水不再泡着明天要卖的东西。")
		"danger":
			if p != "shelter" or s.phase != "night": return false
			if flag("swapped") or flag("shade_off"): return refuse("白灯罩已经取下，不能再用它误唤。")
			s.pollution += 1
			if s.pollution == 1:
				change_place("street")
				note("白灯刚举起，河声与水迹越过棚门。你退到街口，白灯放下后侵入停止：通航信号正在招来不该来的乘客。仍可回棚查证修复。")
			else: finish("flood")
		"break":
			if p != "shelter" or s.phase != "night": return false
			if flag("tongue_taken") or flag("tongue_home"): return refuse("铜舌已不在灯内，不能砸坏一件不存在于这里的东西。")
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
	s.flags["boat_arrival_pending"] = false
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
		note(notice + " 借来的手提黄灯还在你手边，天亮后可亲自回陶记归还，不会隔空自动交付。")

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
		if not id is String or not id in ["铜哨", "新灯芯", "手提黄灯", "拆下的铜舌", "老葛的工具袋", "旧渡牌"]: return false
	if data.identity == "he" and "铜哨" in data.items: return false
	for line in data.journal:
		if not line is String: return false
	if data.has("awning_pull"):
		if not (data.awning_pull is float or data.awning_pull is int) or not is_finite(float(data.awning_pull)) or data.awning_pull < 0 or data.awning_pull > 90: return false
	if data.has("cart_x"):
		if not (data.cart_x is float or data.cart_x is int) or not is_finite(float(data.cart_x)) or data.cart_x < 250 or data.cart_x > 430: return false
	for key in data.flags:
		if not key is String or not data.flags[key] is bool: return false
	if data.ending == "flood" and (data.pollution != 2 or data.place in ["steps", "boat"]): return false
	if data.pollution == 2 and data.ending != "flood": return false
	if data.ending in ["light", "untie"] and data.pollution > 1: return false
	return true
