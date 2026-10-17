extends Control
## 原创 2D 美术战斗舞台：三线九宫格、镜头推拉、角色起手和逐段追打。
const AtlasScript = preload("res://scripts/battle/sprite_atlas.gd")
const ACTOR_SCENE = preload("res://scenes/BattleActor.tscn")
var actors: Dictionary = {}
var target_buttons: Dictionary = {}
var actors_layer: Node2D
var fx_layer: Node2D
var selected_actor: BattleActor
var ally_cards: Array[Control] = []
var enemy_cards: Array[Control] = []
var order_label: Label
var round_label: Label
var log_label: Label
var combo_label: Label
var target_label: Label
var action_hint: Label
var focused_target: BattleUnit
var pending_skill_id: String = ""
var last_hit_damage := -1
var basic_button: Button
var ultimate_button: Button
var fx_player: AnimationPlayer
var fx_particles: GPUParticles2D
var float_layer: Control
var impact_flash: ColorRect
var stage_layer: Control
var camera_layer: Control
var skill_banner: Label
var active_fx := 0
const MAX_DECORATIVE_FX := 12 # 留出 6 个名额给伤害/治疗浮字与技能主体。
var camera_tween: Tween
var pending_passives: Array[Dictionary] = []
var passive_notice: Label
var passive_notice_tween: Tween
var recent_passives: Array[String] = []

func _ready() -> void:
	build_ui()
	BattleManager.state_changed.connect(refresh)
	BattleManager.action_logged.connect(show_action)
	BattleManager.action_started.connect(on_action_started)
	BattleManager.action_impact.connect(on_action_impact)
	BattleManager.turn_requested.connect(on_turn)
	BattleManager.battle_finished.connect(on_finished)
	BattleManager.passive_triggered.connect(on_passive_triggered)
	BattleManager.status_applied.connect(on_status_applied)
	BattleManager.start(GameManager.current_stage)
	if BattleManager.allies.is_empty() or BattleManager.enemies.is_empty():
		UIManager.show_popup("数据错误", "阵容或关卡配置无效。", "返回主城", func() -> void: GameManager.goto_scene("city"))
		return
	create_actors()
	# 入场被动同帧批量结算：每条都有实际事件记录与单位局部符号，仅显示末项浮字。
	for event: Dictionary in pending_passives:
		show_passive(event["unit"] as BattleUnit, str(event["id"]), str(event["effect"]), int(event["amount"]), false)
	if not pending_passives.is_empty():
		var final_event: Dictionary = pending_passives.back()
		show_passive(final_event["unit"] as BattleUnit, str(final_event["id"]), str(final_event["effect"]), int(final_event["amount"]), true, false)
	pending_passives.clear()
	refresh()

func make_panel(base: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(6)
	return style

func build_ui() -> void:
	# 通用云庭战场作为最底层背景；canvas_items 随视口等比适配，避免独立拉伸角色和文字。
	var bg := TextureRect.new()
	bg.name = "BattleBackground"
	bg.texture = preload("res://assets/backgrounds/battle_courtyard_universal.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage_layer = Control.new()
	stage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_layer)
	camera_layer = Control.new()
	camera_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera_layer.pivot_offset = Vector2(640, 360)
	camera_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_layer.add_child(camera_layer)
	for lane in range(3):
		var lane_mark := ColorRect.new()
		lane_mark.position = Vector2(29, 166 + lane * 127)
		lane_mark.size = Vector2(1215, 115)
		lane_mark.color = Color(0.03, 0.19, 0.16, 0.12 if lane % 2 == 0 else 0.2)
		lane_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		camera_layer.add_child(lane_mark)
	actors_layer = Node2D.new()
	actors_layer.name = "Actors"
	camera_layer.add_child(actors_layer)
	fx_layer = Node2D.new()
	fx_layer.name = "ActionEffects"
	camera_layer.add_child(fx_layer)
	for side in range(2):
		for cell in range(9):
			var card := PanelContainer.new()
			# 信息卡稍后按参战顺序移入战场下沿，不再盖住下一排角色。
			card.position = Vector2(-200, -200)
			card.size = Vector2(112 if side == 0 else 132, 54)
			card.custom_minimum_size = card.size
			card.clip_contents = true
			card.pivot_offset = card.size * 0.5
			card.set_meta("base_border", Color("#91c6a5") if side == 0 else Color("#d4ab83"))
			var roster_style: StyleBoxFlat = make_panel(Color(0.04, 0.18, 0.19, 0.90), card.get_meta("base_border"), 8)
			roster_style.set_content_margin_all(3)
			card.add_theme_stylebox_override("panel", roster_style)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			camera_layer.add_child(card)
			card.gui_input.connect(_on_target_card_input.bind(side, cell))
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 0)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(box)
			var title := Label.new()
			title.add_theme_color_override("font_color", Color.WHITE)
			title.add_theme_font_size_override("font_size", 12)
			title.clip_text = true
			title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(title)
			var hp := ProgressBar.new()
			hp.show_percentage = false
			hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp.custom_minimum_size.y = 6
			box.add_child(hp)
			var energy := ProgressBar.new()
			energy.show_percentage = false
			energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			energy.max_value = int((DataManager.tables.get("rules", {}) as Dictionary).get("max_energy", 100))
			energy.custom_minimum_size.y = 3
			box.add_child(energy)
			var status := Label.new()
			status.add_theme_font_size_override("font_size", 10)
			status.add_theme_color_override("font_color", Color("#ffdf97"))
			status.clip_text = true
			status.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(status)
			card.set_meta("parts", {"name": title, "hp": hp, "energy": energy, "status": status})
			if side == 0:
				ally_cards.append(card)
			else:
				enemy_cards.append(card)
	float_layer = Control.new()
	float_layer.name = "FloatLayer"
	float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_layer.add_child(float_layer)
	impact_flash = ColorRect.new()
	impact_flash.name = "ImpactFlash"
	impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_flash.color = Color(1.0, 0.87, 0.55, 0.0)
	impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(impact_flash)
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(22, 12)
	top_bar.size = Vector2(1235, 89)
	top_bar.add_theme_stylebox_override("panel", make_panel(Color(0.02, 0.12, 0.14, 0.88), Color("#d4b773")))
	add_child(top_bar)
	round_label = Label.new()
	round_label.position = Vector2(47, 18)
	round_label.add_theme_font_size_override("font_size", 27)
	round_label.add_theme_color_override("font_color", Color("#fce5ae"))
	add_child(round_label)
	order_label = Label.new()
	order_label.position = Vector2(48, 58)
	order_label.add_theme_color_override("font_color", Color("#e4f9ed"))
	add_child(order_label)
	combo_label = Label.new()
	combo_label.position = Vector2(533, 108)
	combo_label.add_theme_font_size_override("font_size", 33)
	combo_label.add_theme_color_override("font_color", Color("#ffd374"))
	add_child(combo_label)
	target_label = Label.new()
	target_label.name = "TargetFeedback"
	target_label.position = Vector2(348, 140)
	target_label.size = Vector2(580, 30)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 17)
	target_label.add_theme_color_override("font_color", Color("#fff1ce"))
	add_child(target_label)
	skill_banner = Label.new()
	skill_banner.position = Vector2(440, 176)
	skill_banner.size = Vector2(400, 52)
	skill_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_banner.add_theme_font_size_override("font_size", 31)
	skill_banner.add_theme_color_override("font_color", Color("#ffdf97"))
	skill_banner.modulate.a = 0.0
	add_child(skill_banner)
	passive_notice = Label.new()
	passive_notice.name = "PassiveNotice"
	passive_notice.position = Vector2(440, 228)
	passive_notice.size = Vector2(400, 27)
	passive_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_notice.add_theme_font_size_override("font_size", 18)
	passive_notice.add_theme_color_override("font_color", Color("#b9ffce"))
	passive_notice.modulate.a = 0.0
	passive_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(passive_notice)
	var footer := PanelContainer.new()
	footer.position = Vector2(25, 550)
	footer.size = Vector2(1230, 145)
	footer.add_theme_stylebox_override("panel", make_panel(Color(0.02, 0.12, 0.14, 0.92), Color("#d4b773")))
	add_child(footer)
	var footer_content := VBoxContainer.new()
	footer_content.add_theme_constant_override("separation", 5)
	footer.add_child(footer_content)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	footer_content.add_child(controls)
	basic_button = Button.new()
	basic_button.text = "普通攻击 · 无消耗"
	basic_button.custom_minimum_size = Vector2(225, 68)
	basic_button.add_theme_stylebox_override("normal", make_panel(Color("#276b68"), Color("#a9e8d1")))
	controls.add_child(basic_button)
	basic_button.pressed.connect(func() -> void: begin_targeting("basic"))
	ultimate_button = Button.new()
	ultimate_button.custom_minimum_size = Vector2(260, 68)
	ultimate_button.add_theme_stylebox_override("normal", make_panel(Color("#965d38"), Color("#f9d588")))
	controls.add_child(ultimate_button)
	ultimate_button.pressed.connect(func() -> void:
		var unit: BattleUnit = BattleManager.active_unit
		if unit != null and unit.side == "ally":
			begin_targeting(active_skill_id(unit))
	)
	log_label = Label.new()
	log_label.custom_minimum_size = Vector2(645, 90)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", Color("#f4f7e9"))
	controls.add_child(log_label)
	action_hint = Label.new()
	action_hint.name = "ActionHint"
	action_hint.add_theme_font_size_override("font_size", 14)
	action_hint.add_theme_color_override("font_color", Color("#ffe2a8"))
	footer_content.add_child(action_hint)
	fx_player = AnimationPlayer.new()
	add_child(fx_player)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 0.23
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("ImpactFlash:color:a"))
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, 0.035, 0.32)
	animation.track_insert_key(track, 0.23, 0.0)
	library.add_animation("impact", animation)
	fx_player.add_animation_library("", library)
	fx_particles = GPUParticles2D.new()
	fx_particles.amount = 24
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 10.0
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 110.0
	particle_material.initial_velocity_min = 45.0
	particle_material.initial_velocity_max = 115.0
	particle_material.gravity = Vector3(0, 140, 0)
	particle_material.color = Color("#ffe0a2")
	fx_particles.process_material = particle_material
	fx_particles.lifetime = 0.24
	fx_particles.one_shot = true
	fx_particles.emitting = false
	camera_layer.add_child(fx_particles)

## 每名战斗单位独立实例化角色场景，阵位信息卡只负责数值 UI。
func create_actors() -> void:
	for unit in BattleManager.allies + BattleManager.enemies:
		var model: BattleActor = ACTOR_SCENE.instantiate() as BattleActor
		var column: int = unit.cell % 3
		var lane: int = int(unit.cell / 3)
		var at := Vector2((123 if unit.side == "ally" else 786) + column * 174, 212 + lane * 127)
		actors_layer.add_child(model)
		model.configure(unit, at)
		actors[unit] = model
		var hitbox := Button.new()
		hitbox.name = "TargetHitbox_%s_%d" % [unit.side, unit.cell]
		hitbox.position = at + Vector2(-52, -119)
		hitbox.size = Vector2(104, 114)
		hitbox.flat = true
		hitbox.focus_mode = Control.FOCUS_NONE
		hitbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hitbox.pressed.connect(choose_target_cell.bind(0 if unit.side == "ally" else 1, unit.cell))
		camera_layer.add_child(hitbox)
		target_buttons[unit] = hitbox
	layout_team_cards()

## 底部两侧各一条轻量名册；卡片不随角色攻击位移，保持战场中心无文字遮挡。
func layout_team_cards() -> void:
	for side in range(2):
		var team: Array[BattleUnit] = BattleManager.allies if side == 0 else BattleManager.enemies
		var cards: Array[Control] = ally_cards if side == 0 else enemy_cards
		var start_x: float = 36.0 if side == 0 else 738.0
		var spacing: float = 121.0 if side == 0 else 128.0
		for index in range(team.size()):
			cards[team[index].cell].position = Vector2(start_x + float(index) * spacing, 492.0)

func actor_for(unit: BattleUnit) -> BattleActor:
	if unit == null:
		return null
	return actors.get(unit) as BattleActor

func card_for(unit: BattleUnit) -> Control:
	if unit == null or unit.cell < 0 or unit.cell >= 9:
		return null
	return ally_cards[unit.cell] if unit.side == "ally" else enemy_cards[unit.cell]

## 先选择行动，再在同一合法目标池内点击角色立绘或名册卡。
func begin_targeting(skill_id: String) -> void:
	var actor: BattleUnit = BattleManager.active_unit
	if not BattleManager.running or actor == null or actor.side != "ally" or not actor.alive() or BattleManager.busy:
		return
	if skill_id != "basic" and not BattleManager.can_cast(actor, skill_id):
		return
	pending_skill_id = skill_id
	var options: Array[BattleUnit] = BattleManager.valid_targets(actor, skill_id)
	if options.size() == 1 and str(DataManager.get_entry("skills", skill_id).get("target", "enemy")) == "self":
		pending_skill_id = ""
		BattleManager.player_action(skill_id, actor)
	else:
		BattleManager.selected_target = null
		refresh()

func _on_target_card_input(event: InputEvent, side: int, cell: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		choose_target_cell(side, cell)

func choose_target_cell(side: int, cell: int) -> void:
	if pending_skill_id == "" or BattleManager.busy:
		return
	var team: Array[BattleUnit] = BattleManager.allies if side == 0 else BattleManager.enemies
	for candidate: BattleUnit in team:
		if candidate.cell == cell and BattleManager.select_target(candidate, pending_skill_id):
			var skill_id: String = pending_skill_id
			pending_skill_id = ""
			BattleManager.player_action(skill_id, candidate)
			return


func status_text(unit: BattleUnit) -> String:
	if not unit.alive():
		return "已倒下"
	var tags: Array[String] = []
	if unit.shields > 0:
		tags.append("◇护盾 %d" % unit.shields)
	var labels := {"stun": "眩晕", "air": "浮空", "down": "倒地", "damage_up": "增伤", "damage_down": "减攻"}
	for key: String in labels:
		if unit.has_effect(key):
			tags.append("●%s" % labels[key])
	return "  ".join(tags) if not tags.is_empty() else "状态正常"

## 主角使用当前装备的奥义；宠物从自己的技能表选择主动技能，不读取主角装备。
func active_skill_id(unit: BattleUnit) -> String:
	if unit == null:
		return ""
	if unit.id == "hero":
		return str(DataManager.save_data.get("hero_skill", ""))
	for candidate: Variant in unit.skills:
		var skill_id: String = str(candidate)
		if str(DataManager.get_entry("skills", skill_id).get("type", "")) == "ultimate":
			return skill_id
	return ""

func ultimate_reason(unit: BattleUnit, skill_id: String) -> String:
	if unit == null or not unit.alive():
		return "当前单位无法行动"
	var skill: Dictionary = DataManager.get_entry("skills", skill_id)
	if not unit.skills.has(skill_id) or skill.get("type", "") != "ultimate":
		return "未装备该主动技能"
	var remaining: int = int(unit.cooldowns.get(skill_id, 0))
	if remaining > 0:
		return "冷却中：%d 轮" % remaining
	var cost: int = int(skill.get("cost", 0))
	if unit.energy < cost:
		return "能量不足：还差 %d" % (cost - unit.energy)
	if str(skill.get("apply", "")) == "cleanse" and BattleManager.pick_afflicted_ally(BattleManager.allies) == null:
		return "无可净化的友方目标"
	return "可释放"

func refresh() -> void:
	if pending_skill_id != "" and (not BattleManager.running or BattleManager.busy or BattleManager.active_unit == null or BattleManager.active_unit.side != "ally"):
		pending_skill_id = ""
	round_label.text = "第 %d / %d 回合 · %s" % [BattleManager.round_number, int(BattleManager.stage.get("max_rounds", 20)), str(BattleManager.stage.get("name", ""))]
	var names: Array[String] = []
	for unit in BattleManager.queue:
		if unit.alive():
			names.append(("我" if unit.side == "ally" else "敌") + "·" + unit.name)
	var current: BattleUnit = BattleManager.active_unit
	order_label.text = "当前  " + (("我" if current.side == "ally" else "敌") + "·" + current.name if current != null and current.alive() else "轮次准备") + "     后续  " + ("  →  ".join(names) if not names.is_empty() else "本轮即将结束")
	if focused_target != null and last_hit_damage >= 0:
		target_label.text = "%s  ·  命中 -%d  ·  %s" % [focused_target.name, last_hit_damage, status_text(focused_target)]
	for side in range(2):
		var team: Array[BattleUnit] = BattleManager.allies if side == 0 else BattleManager.enemies
		var cards: Array[Control] = ally_cards if side == 0 else enemy_cards
		for card in cards:
			card.visible = false
		for unit in team:
			var card: Control = cards[unit.cell]
			card.visible = true
			var parts: Dictionary = card.get_meta("parts")
			var model := actor_for(unit)
			if model != null and not unit.alive():
				model.set_defeated()
			(parts["name"] as Label).text = unit.name + "  %d/%d" % [unit.hp, unit.max_hp]
			(parts["name"] as Label).tooltip_text = "%s · 生命 %d/%d" % [unit.name, unit.hp, unit.max_hp]
			(parts["hp"] as ProgressBar).max_value = unit.max_hp
			(parts["hp"] as ProgressBar).value = unit.hp
			(parts["energy"] as ProgressBar).value = unit.energy
			(parts["status"] as Label).text = status_text(unit)
			(parts["status"] as Label).tooltip_text = status_text(unit)
			var selectable: bool = pending_skill_id != "" and BattleManager.valid_targets(BattleManager.active_unit, pending_skill_id).has(unit)
			var highlighted: bool = unit.alive() and (unit == focused_target or unit == BattleManager.active_unit or unit == BattleManager.selected_target)
			var border: Color = Color("#89f4da") if selectable else Color("#ffe087") if highlighted else card.get_meta("base_border")
			var roster_style: StyleBoxFlat = make_panel(Color(0.12, 0.22, 0.18, 0.96) if highlighted or selectable else Color(0.04, 0.18, 0.19, 0.90), border, 8)
			card.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_ARROW
			card.tooltip_text = "点击选择目标" if selectable else "该技能不可选择此目标" if pending_skill_id != "" else ""
			var hitbox: Button = target_buttons.get(unit) as Button
			if hitbox != null:
				hitbox.position = model.position + Vector2(-52, -119) if model != null else hitbox.position
				hitbox.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
				hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hitbox.tooltip_text = "点击选择 %s" % unit.name if selectable else ""
			roster_style.set_content_margin_all(3)
			card.add_theme_stylebox_override("panel", roster_style)
	var unit: BattleUnit = BattleManager.active_unit
	var allowed: bool = BattleManager.running and not BattleManager.busy and unit != null and unit.side == "ally" and unit.alive() and not unit.has_effect("stun")
	basic_button.disabled = not allowed
	basic_button.text = "%s · 普通攻击" % unit.name if allowed else "普通攻击 · 无消耗"
	var skill_id: String = active_skill_id(unit) if allowed else ""
	var skill: Dictionary = DataManager.get_entry("skills", skill_id) if skill_id != "" else {}
	var reason: String = ultimate_reason(unit, skill_id) if allowed else "等待我方行动"
	ultimate_button.text = "%s · %s能量" % [str(skill.get("name", "主动技能")), str(skill.get("cost", 0))] if allowed else "主动技能 · 等待行动"
	ultimate_button.disabled = not allowed or not BattleManager.can_cast(unit, skill_id)
	if BattleManager.running:
		action_hint.text = ("点击高亮目标释放 %s · 仅高亮目标可选" % str(DataManager.get_entry("skills", pending_skill_id).get("name", "攻击"))) if pending_skill_id != "" else "当前操作：%s · 选择普攻或技能后点击目标    技能：%s    当前能量 %d" % [unit.name, reason, unit.energy] if allowed else "等待我方单位行动 · 敌方行动与追打自动执行"
	else:
		action_hint.text = "战斗已结束 · 请在结算弹窗返回主城"

func on_turn(unit: BattleUnit) -> void:
	pending_skill_id = ""
	log_label.text = "轮到%s行动，选择普通攻击或主动技能，再点击高亮目标。" % unit.name
	var pulse := create_tween()
	pulse.tween_property(ultimate_button, "modulate", Color("#fff0c6"), 0.16)
	pulse.tween_property(ultimate_button, "modulate", Color.WHITE, 0.2)
	refresh()

## 起手：演出技能横幅、角色蓄力前冲及镜头偏移；等待所有前摇结束。
func on_action_started(actor: BattleUnit, target: BattleUnit, skill_id: String, combo: int, action_id: int) -> void:
	basic_button.disabled = true
	ultimate_button.disabled = true
	focused_target = target if target != actor else null
	last_hit_damage = -1
	var support: bool = str(DataManager.get_entry("skills", skill_id).get("target", "enemy")) != "enemy"
	target_label.text = ("援护目标  " if support else "目标锁定  ") + target.name + ("  ·  追打第 %d 段" % combo if combo > 0 else "  ·  即将生效") if target != actor else "自身技能  ·  " + actor.name
	refresh()
	var model := actor_for(actor)
	var target_model := actor_for(target)
	if model == null or target_model == null:
		BattleManager.animation_completed.emit(action_id, "windup")
		return
	selected_actor = model
	pending_skill_id = ""
	var skill := DataManager.get_entry("skills", skill_id)
	log_label.text = ("追打 · " if combo > 0 else "出手 · ") + actor.name + " → " + str(skill.get("name", ""))
	combo_label.text = ("浮空 → 倒地" if str(skill.get("trigger", "")) == "air" else "倒地 → 浮空") + " · %d 连击!" % (combo + 1) if combo > 0 else ""
	combo_label.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.19).set_trans(Tween.TRANS_BACK)
	skill_banner.text = ("追打  " if combo > 0 else "奥义  " if skill_id != "basic" else "") + str(skill.get("name", ""))
	skill_banner.modulate.a = 1.0
	skill_banner.scale = Vector2(0.87, 0.87)
	var banner_tween := create_tween()
	banner_tween.tween_property(skill_banner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	banner_tween.tween_property(skill_banner, "modulate:a", 0.0, 0.35)
	if camera_tween != null and camera_tween.is_running():
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.tween_property(camera_layer, "scale", Vector2(1.055, 1.055) if combo > 0 else Vector2(1.025, 1.025), 0.2)
	camera_tween.parallel().tween_property(camera_layer, "position", Vector2(-16, -10) if actor.side == "ally" else Vector2(13, -10), 0.2)
	var skill_type: String = str(skill.get("type", "basic"))
	var kind := "chase" if combo > 0 else "ultimate" if skill_type == "ultimate" else "basic"
	var support_fx: bool = str(skill.get("target", "enemy")) != "enemy"
	var action_fx: int = effect_index(skill_id, skill, combo, support_fx)
	var tint: Color = effect_color(actor, skill, combo, support_fx)
	skill_banner.add_theme_color_override("font_color", tint.lightened(0.42))
	spawn_effect(action_fx, model.position + Vector2(0, -39), Vector2(92, 92), tint)
	spawn_signature(skill_id, skill, model.position + Vector2(0, -43), tint, false)
	spawn_phase_aura(model.position + Vector2(0, -43), tint, "startup", combo > 0)
	model.play_attack(kind, target_model.home, support_fx)
	await model.motion.finished
	# 爆发只在前摇已完成后出现，仍等待投射物抵达才回执伤害判定。
	spawn_phase_aura(model.position + Vector2(0, -43), tint, "release", combo > 0)
	if target != actor and (kind == "ultimate" or kind == "chase"):
		await launch_skill_effect(model.position + Vector2(0, -52), target_model.position + Vector2(0, -45), action_fx, tint)
	# 若技能为自我护盾，角色蓄力后仍等待相同的命中时点执行状态结算。
	BattleManager.animation_completed.emit(action_id, "windup")

## 命中：技能特效、受击弹跳、短时停顿与镜头回位；此时血量已结算。
func on_action_impact(actor: BattleUnit, target: BattleUnit, skill_id: String, damage: int, combo: int, action_id: int) -> void:
	var target_model := actor_for(target)
	var model := actor_for(actor)
	if target_model == null or model == null:
		BattleManager.animation_completed.emit(action_id, "impact")
		return
	var support: bool = str(DataManager.get_entry("skills", skill_id).get("target", "enemy")) != "enemy"
	if not support and damage > 0:
		fx_player.stop()
		fx_player.play("impact")
	fx_particles.position = target_model.position + Vector2(0, -37)
	var skill: Dictionary = DataManager.get_entry("skills", skill_id)
	var tint: Color = effect_color(actor, skill, combo, support)
	fx_particles.modulate = tint
	fx_particles.restart()
	var skill_fx: int = effect_index(skill_id, skill, combo, support)
	spawn_effect(skill_fx, target_model.position + Vector2(0, -42), Vector2(118, 118), tint)
	spawn_signature(skill_id, skill, target_model.position + Vector2(0, -43), tint, true)
	spawn_phase_aura(target_model.position + Vector2(0, -43), tint, "impact", combo > 0)
	if not support and damage > 0:
		spawn_impact_ring(target_model.position + Vector2(0, -45), tint, combo > 0)
	var cleansed: bool = support and str(skill.get("apply", "")) == "cleanse"
	# 净化没有伤害，不能让通用伤害刷新把实际净化反馈覆盖成“命中 -0”。
	last_hit_damage = -1 if cleansed else damage
	if support:
		spawn_support(target_model.position + Vector2(0, -55), skill_id, maxi(0, -damage))
		var result: String = "净化 %d 项" % BattleManager.last_cleansed.size() if cleansed else "治疗 +%d" % maxi(0, -damage) if damage < 0 else "援护生效"
		target_label.text = "%s  ·  %s  ·  %s" % [target.name, result, status_text(target)]
	else:
		spawn_damage(target_model.position + Vector2(0, -55), damage, combo)
		target_label.text = "%s  ·  命中 -%d  ·  %s" % [target.name, damage, status_text(target)]
	if not support and damage > 0:
		target_model.face_toward(model.position)
		target_model.play_hit()
	model.return_home()
	var tween := create_tween()
	tween.tween_interval(0.25)
	if camera_tween != null and camera_tween.is_running():
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.tween_property(camera_layer, "position", Vector2(8, 0) if target.side == "ally" else Vector2(-8, 0), 0.05)
	camera_tween.tween_property(camera_layer, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BOUNCE)
	camera_tween.parallel().tween_property(camera_layer, "scale", Vector2.ONE, 0.22)
	await tween.finished
	BattleManager.animation_completed.emit(action_id, "impact")
	focused_target = null
	refresh()

## 视觉签名按技能的实际功能区分：光刃、波纹、藤蔓、火焰、岩击、水弧、金芒及两类追打。
func skill_signature(skill_id: String, skill: Dictionary) -> String:
	match skill_id:
		"hero_strike": return "slash"
		"hero_wave": return "wave"
		"hero_guard": return "shield"
		"sprout_burst": return "vine"
		"ember_flare": return "flame"
		"pebble_ram": return "stone"
		"enemy_burst": return "enemy_burst"
		"mist_arc": return "mist"
		"hero_mend": return "heal"
		"hero_cleanse": return "cleanse"
		"metal_edge": return "metal"
		"chase_air": return "chase_air"
		"chase_down": return "chase_down"
		_:
			if (DataManager.tables.get("passives", {}) as Dictionary).has(skill_id):
				return str(skill.get("effect", "")) + "_" + str(skill.get("trigger", ""))
			return str(skill.get("apply", "basic")) if not skill.is_empty() else "basic"

## 不增加贴图/粒子预算，使用 2-5 条短线组成每种技能独有轮廓。
func spawn_signature(skill_id: String, skill: Dictionary, at: Vector2, tint: Color, impact: bool) -> void:
	if skill_id == "basic" or active_fx >= 18:
		return
	var shape: String = skill_signature(skill_id, skill)
	var points: PackedVector2Array = PackedVector2Array()
	match shape:
		"slash", "metal": points = PackedVector2Array([Vector2(-28, 14), Vector2(15, -19), Vector2(30, -22)])
		"wave": points = PackedVector2Array([Vector2(-33, 6), Vector2(-16, -12), Vector2(0, 6), Vector2(16, -12), Vector2(33, 6)])
		"vine": points = PackedVector2Array([Vector2(-24, 21), Vector2(-9, 3), Vector2(-16, -16), Vector2(9, -5), Vector2(21, -22)])
		"flame": points = PackedVector2Array([Vector2(-18, 23), Vector2(-10, 0), Vector2(0, 11), Vector2(8, -25), Vector2(19, 19)])
		"stone": points = PackedVector2Array([Vector2(-25, 15), Vector2(-18, -16), Vector2(11, -25), Vector2(26, 4), Vector2(-25, 15)])
		"enemy_burst": points = PackedVector2Array([Vector2(-20, -18), Vector2(0, 16), Vector2(20, -18), Vector2(0, -5)])
		"mist": points = PackedVector2Array([Vector2(-30, 5), Vector2(-15, -9), Vector2(0, 3), Vector2(15, -12), Vector2(30, 4)])
		"shield": points = PackedVector2Array([Vector2(0, -27), Vector2(23, -12), Vector2(19, 15), Vector2(0, 27), Vector2(-19, 15), Vector2(-23, -12), Vector2(0, -27)])
		"heal": points = PackedVector2Array([Vector2(0, -24), Vector2(0, 24), Vector2(0, 0), Vector2(-22, 0), Vector2(22, 0)])
		"cleanse": points = PackedVector2Array([Vector2(-23, 0), Vector2(-10, 16), Vector2(23, -19)])
		"chase_air": points = PackedVector2Array([Vector2(-20, 18), Vector2(0, -26), Vector2(20, 18)])
		"chase_down": points = PackedVector2Array([Vector2(-22, -16), Vector2(0, 25), Vector2(22, -16)])
		"shield_enter": points = PackedVector2Array([Vector2(-23, 10), Vector2(-18, -13), Vector2(0, -23), Vector2(18, -13), Vector2(23, 10)])
		"shield_hit": points = PackedVector2Array([Vector2(-27, 10), Vector2(-15, -16), Vector2(0, 3), Vector2(15, -16), Vector2(27, 10)])
		"heal_round_start": points = PackedVector2Array([Vector2(-20, 8), Vector2(-6, 8), Vector2(-6, -15), Vector2(6, -15), Vector2(6, 8), Vector2(20, 8)])
		"damage_up_enter": points = PackedVector2Array([Vector2(-17, 18), Vector2(0, -20), Vector2(17, 18)])
		"damage_up_round_start": points = PackedVector2Array([Vector2(-22, 14), Vector2(0, -20), Vector2(22, 14), Vector2(0, -5)])
		_: points = PackedVector2Array([Vector2(-15, 10), Vector2(0, -15), Vector2(15, 10)])
	active_fx += 1
	var trace := Line2D.new()
	trace.points = points
	trace.width = 4.0 if impact else 2.5
	trace.default_color = tint.lightened(0.24)
	trace.antialiased = true
	trace.position = at
	trace.scale = Vector2(0.65, 0.65)
	fx_layer.add_child(trace)
	var anim := create_tween()
	anim.tween_property(trace, "scale", Vector2(1.65, 1.65) if impact else Vector2.ONE, 0.27)
	anim.parallel().tween_property(trace, "modulate:a", 0.0, 0.27)
	anim.finished.connect(func() -> void:
		trace.queue_free()
		active_fx -= 1
	)

## 同一行动的蓄力、飞行与命中沿用同一图形；支援独立用玉色法纹。
func effect_index(skill_id: String, skill: Dictionary, combo: int, support: bool) -> int:
	if combo > 0:
		return 3
	if support:
		return 2
	if skill_id == "basic":
		return 1
	return 0 if str(skill.get("apply", "")) == "air" else 1

## 投射效果完成后才允许 BattleManager 计算命中，不影响技能伤害或追打规则。
## 根据施法属性统一着色起手、飞行与命中；普通攻击保留暖白，援护固定玉色。
func effect_color(actor: BattleUnit, skill: Dictionary, combo: int, support: bool) -> Color:
	if support:
		return Color("#8fe8ba")
	if combo > 0:
		return Color("#ffce79")
	if str(skill.get("type", "basic")) == "basic":
		return Color("#ffdfb2")
	var element: String = str(skill.get("element", "owner"))
	if element == "owner":
		element = actor.elements[0] if not actor.elements.is_empty() else "none"
	match element:
		"metal": return Color("#fff1a2")
		"wood": return Color("#9bea99")
		"water": return Color("#90dffa")
		"fire": return Color("#ffa579")
		"earth": return Color("#e4be89")
		_: return Color("#ffe0ae")

## 三段式局部光纹：轮廓内留空以保留角色与关键目标，单容器控制密度与回收。
func spawn_phase_aura(at: Vector2, tint: Color, phase: String, combo: bool = false) -> void:
	if active_fx >= MAX_DECORATIVE_FX or not ["startup", "release", "impact"].has(phase):
		return
	active_fx += 1
	var aura := Node2D.new()
	aura.name = "PhaseAura_" + phase
	aura.position = at
	aura.set_meta("phase", phase)
	fx_layer.add_child(aura)
	var radius: float = 45.0 if phase == "startup" else 54.0 if phase == "release" else 39.0
	for band in range(2):
		var ring := Line2D.new()
		ring.width = 2.0 if band == 0 else 1.2
		ring.antialiased = true
		ring.default_color = Color(tint.r, tint.g, tint.b, 0.72 if band == 0 else 0.45)
		for point in range(33):
			var angle: float = TAU * float(point) / 32.0
			ring.add_point(Vector2(cos(angle), sin(angle)) * (radius + float(band) * 13.0))
		aura.add_child(ring)
	# 每条射线均始于环外；多段断线用独立子节点，避免连到角色中心。
	for ray in range(8 if combo else 6):
		var angle: float = TAU * float(ray) / float(8 if combo else 6)
		var direction := Vector2(cos(angle), sin(angle))
		var shard := Line2D.new()
		shard.width = 2.4 if combo else 1.7
		shard.default_color = Color(tint.r, tint.g, tint.b, 0.7)
		shard.antialiased = true
		shard.add_point(direction * (radius + 18.0))
		shard.add_point(direction * (radius + 34.0))
		aura.add_child(shard)
	aura.scale = Vector2.ONE * (1.35 if phase == "startup" else 0.55)
	var duration: float = 0.24 if phase == "startup" else 0.19 if phase == "release" else 0.26
	var end_scale: float = 0.72 if phase == "startup" else 1.85 if phase == "release" else 2.05
	var tween := create_tween()
	tween.tween_property(aura, "scale", Vector2.ONE * end_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(aura, "modulate:a", 0.0, duration)
	tween.finished.connect(func() -> void:
		aura.queue_free()
		active_fx -= 1
	)

## 轻量本地冲击环仅在实际扣血时生成；护盾吸收与治疗不触发伤害冲击。
func spawn_impact_ring(at: Vector2, tint: Color, combo: bool) -> void:
	if active_fx >= 18:
		return
	active_fx += 1
	var ring := Line2D.new()
	ring.antialiased = true
	ring.width = 4.0 if combo else 3.0
	ring.default_color = tint.lightened(0.25)
	for i in range(25):
		var angle: float = TAU * float(i) / 24.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * 24.0)
	ring.position = at
	ring.scale = Vector2(0.35, 0.35)
	fx_layer.add_child(ring)
	var burst := create_tween()
	burst.tween_property(ring, "scale", Vector2(1.75, 1.75), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	burst.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	burst.finished.connect(func() -> void:
		ring.queue_free()
		active_fx -= 1
	)

func launch_skill_effect(from: Vector2, to: Vector2, index: int, tint: Color = Color.WHITE) -> void:
	var projectile := TextureRect.new()
	projectile.texture = AtlasScript.effect_for(index)
	projectile.modulate = tint
	projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	projectile.size = Vector2(74, 74)
	projectile.pivot_offset = projectile.size * 0.5
	projectile.position = from - projectile.pivot_offset
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(projectile)
	var flight := create_tween()
	flight.tween_property(projectile, "position", to - projectile.pivot_offset, 0.16).set_trans(Tween.TRANS_CUBIC)
	flight.parallel().tween_property(projectile, "rotation", 0.6, 0.16)
	await flight.finished
	projectile.queue_free()

func spawn_effect(index: int, at: Vector2, dimensions: Vector2, tint: Color = Color.WHITE) -> void:
	if active_fx >= 18:
		return
	active_fx += 1
	var effect := TextureRect.new()
	effect.texture = AtlasScript.effect_for(index)
	effect.modulate = tint
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = dimensions
	effect.pivot_offset = dimensions * 0.5
	effect.position = at - effect.pivot_offset
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(effect)
	effect.scale = Vector2(0.55, 0.55)
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector2(1.23, 1.23), 0.23).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.36)
	tween.finished.connect(func() -> void:
		effect.queue_free()
		active_fx -= 1
	)

func spawn_support(at: Vector2, skill_id: String, actual_heal: int = 0) -> void:
	var skill: Dictionary = DataManager.get_entry("skills", skill_id)
	var effect: String = str(skill.get("apply", ""))
	var text: String = "+%d 治疗" % actual_heal if effect == "heal" else "净化 %d 项" % BattleManager.last_cleansed.size() if effect == "cleanse" else "护盾 +%d" % int(skill.get("value", 0))
	spawn_floating_text(at, text, Color("#ffe4a4") if effect == "shield" else Color("#b9ffce"))

func spawn_floating_text(at: Vector2, text: String, color: Color) -> void:
	if active_fx >= 18:
		return
	active_fx += 1
	var popup := Label.new()
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_shadow_color", Color("#213c35"))
	popup.add_theme_font_size_override("font_size", 27)
	popup.position = at
	float_layer.add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 75, 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func() -> void:
		popup.queue_free()
		active_fx -= 1
	)

func spawn_damage(at: Vector2, damage: int, combo: int) -> void:
	if active_fx >= 18:
		return
	active_fx += 1
	var popup := Label.new()
	popup.text = "-%d" % damage if damage > 0 else "护盾"
	popup.add_theme_color_override("font_color", Color("#ffe3a4") if combo > 0 else Color("#fff9e5"))
	popup.add_theme_color_override("font_shadow_color", Color("#3a211c"))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 3)
	popup.add_theme_font_size_override("font_size", 34 if combo > 0 else 28)
	popup.position = at
	float_layer.add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 75, 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func() -> void:
		popup.queue_free()
		active_fx -= 1
	)

## 每条被动具有独立名称；治疗仅在实际回血时通知，入场事件延迟到角色就绪。
func on_passive_triggered(unit: BattleUnit, passive_id: String, effect: String, amount: int) -> void:
	if actor_for(unit) == null:
		pending_passives.append({"unit": unit, "id": passive_id, "effect": effect, "amount": amount})
		return
	show_passive(unit, passive_id, effect, amount)

func show_passive(unit: BattleUnit, passive_id: String, effect: String, amount: int, announce: bool = true, record: bool = true) -> void:
	var passive: Dictionary = DataManager.get_entry("passives", passive_id)
	var name: String = str(passive.get("name", passive_id))
	var text: String = "护盾 +%d" % amount if effect == "shield" else "生命 +%d" % amount if effect == "heal" else "增伤 +%d%%" % amount if effect == "damage_up" else "减攻 %d%%" % amount
	var tint: Color = Color("#ffe1a2") if effect == "shield" else Color("#a6edb7") if effect == "heal" else Color("#ffbd87")
	var model: BattleActor = actor_for(unit)
	if model == null:
		return
	if record:
		recent_passives.append("%s:%s:%d" % [unit.id, passive_id, amount])
		if recent_passives.size() > 24:
			recent_passives.pop_front()
	if announce:
		passive_notice.text = "%s · %s【%s】%s" % ["我方" if unit.side == "ally" else "敌方", unit.name, name, text]
		passive_notice.add_theme_color_override("font_color", tint)
		if passive_notice_tween != null and passive_notice_tween.is_running():
			passive_notice_tween.kill()
		passive_notice.modulate.a = 1.0
		passive_notice_tween = create_tween()
		passive_notice_tween.tween_property(passive_notice, "modulate:a", 0.0, 1.25)
	spawn_signature(passive_id, passive, model.position + Vector2(0, -46), tint, true)
	if announce:
		spawn_floating_text(model.position + Vector2(-26, -77), name, tint)

func on_status_applied(unit: BattleUnit, effect: String) -> void:
	var model: BattleActor = actor_for(unit)
	if model == null:
		return
	var name: String = "浮空" if effect == "air" else "倒地" if effect == "down" else "眩晕" if effect == "stun" else "减攻" if effect == "damage_down" else "增伤"
	var tint: Color = Color("#a6dffa") if effect == "air" else Color("#e4be89") if effect == "down" else Color("#f5d27c")
	spawn_floating_text(model.position + Vector2(-32, -86), name, tint)

func show_action(message: String, _target: BattleUnit, damage: int) -> void:
	log_label.text = message + ("  -%d" % damage if damage > 0 else "  +%d 治疗" % -damage if damage < 0 else "")

func on_finished(won: bool) -> void:
	focused_target = null
	target_label.text = "战斗结束  ·  " + ("胜利" if won else "失败")
	refresh()
	var message := "经验已发放至上阵单位。" if won else "可调整站位与技能后重试。"
	UIManager.show_popup("战斗胜利" if won else "战斗失败", message, "返回主城", func() -> void: GameManager.goto_scene("city"))
