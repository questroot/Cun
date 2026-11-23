extends AcceptDialog
## Read-only briefing: the host owns all progression and inventory.
const Icons = preload("res://scripts/scenes/sea_station_icons.gd")
var pages: TabContainer

func open_board(sea) -> void:
	title = "海上任务板 / 值班简报"
	theme = sea.theme
	exclusive = true
	get_label().hide()
	get_ok_button().text = "返回甲板"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var frame := Control.new()
	add_child(frame)
	var root := VBoxContainer.new()
	frame.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(Icons.make("build", 48))
	_text(head, "浮台值班簿", &"HarborHeading")
	_text(head, "　核心 Lv.%d　/　甲板 %d 块　/　交单 %d 次" % [sea.core_level, sea.raft_tiles, sea.orders_completed], &"HarborCaption")
	pages = TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	var dock := _page("港务任务")
	_card(dock, "当前目标", sea._guide_step())
	_card(dock, "后勤清单", "木料 %d　废料 %d　清水 %d　绳索 %d\n集水站 %d 座　·　待领清水 %d / 纤维 %d" % [sea.wood, sea.scrap, sea.water, sea.rope, sea.collectors, sea.pending_water, sea.pending_fiber])
	_card(dock, "订单核对", "每单清水 %d、绳索 %d　·　%s" % [sea.ORDER_WATER, sea.ORDER_ROPE, "物资齐备，可至经营台交付" if sea.water >= sea.ORDER_WATER and sea.rope >= sea.ORDER_ROPE else "尚缺清水 %d、绳索 %d" % [maxi(0, sea.ORDER_WATER - sea.water), maxi(0, sea.ORDER_ROPE - sea.rope)]])
	var dive := _page("下潜调查")
	_card(dive, "下一项调查", sea._dive_summary())
	var marks := PackedStringArray()
	for pair: Array in [["浅滩光迹", sea.dive_shoal], ["沉船声呐", sea.dive_sonar], ["回声核心", sea.dive_core or sea.dive_archived], ["浮台归档", sea.dive_archived]]:
		marks.append(("已记录　" if pair[1] else "待调查　") + str(pair[0]))
	_card(dive, "调查签注", "\n".join(marks))
	_card(dive, "返航规则", "安全光柱上浮才入库；氧气耗尽会丢失整袋和本潜新核心。")
	var manual := _page("操作索引")
	_card(manual, "甲板 / 拾荒", "WASD、方向键或点击水面移动；靠近漂浮物打捞，近岸每 6 秒补充。B 查看库存、材料用途和待领产出。")
	_card(manual, "经营 / 出航", "从经营台查看建造、生产、居民、航行。建造先预览再确认；集水站每 4 秒产出，首次须手领。")
	_card(manual, "仪器 / 快捷键", "M 查看水域地图，C 打开潜水工坊，F11 切换全屏。")
	_text(root, "← → 切换栏目　·　PgUp / PgDn 翻页　·　Esc 返回", &"HarborCaption")
	window_input.connect(_keys)
	var available := Vector2i(sea.get_viewport_rect().size).min(sea.get_window().size) - Vector2i(36, 64)
	popup_centered(Vector2i(780, 530).min(available))
	pages.get_tab_bar().grab_focus()

func _page(caption: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	return stack

func _card(stack: Control, caption: String, value: String) -> void:
	var panel := PanelContainer.new()
	stack.add_child(panel)
	var lines := VBoxContainer.new()
	panel.add_child(lines)
	_text(lines, caption, &"HarborCaption")
	_text(lines, value)

func _text(parent: Control, value: String, style: StringName = &"") -> void:
	var line := Label.new()
	line.text = value
	line.theme_type_variation = style
	if parent is VBoxContainer: line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(line)

func _keys(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var scroll := pages.get_current_tab_control() as ScrollContainer
		scroll.scroll_vertical += int(scroll.size.y) * (-1 if event.keycode == KEY_PAGEUP else 1)
		set_input_as_handled()
	elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
		pages.current_tab = posmod(pages.current_tab + (-1 if event.keycode == KEY_LEFT else 1), pages.get_tab_count())
		pages.get_tab_bar().grab_focus()
		set_input_as_handled()
