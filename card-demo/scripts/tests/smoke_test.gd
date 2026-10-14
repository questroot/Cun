extends SceneTree
## --headless --path PROJECT --script res://scripts/tests/smoke_test.gd
var failures := 0
var animation_events := 0
var chase_events := 0
var started_events := 0
var premature_hits := 0
var model_motion_seen := false

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	await process_frame
	var data := root.get_node("DataManager")
	var game := root.get_node("GameManager")
	var battle := root.get_node("BattleManager")
	root.add_child(Node2D.new())
	current_scene = root.get_child(root.get_child_count() - 1)
	var formation: Array = data.save_data["formation"]
	check(formation.size() == 9, "阵位为九宫格")
	check((data.save_data["levels"] as Dictionary).has("metal") and (data.save_data["exp"] as Dictionary).has("metal"), "新旧存档均为金犼预留独立成长数据")
	var gold_data: Dictionary = data.get_entry("units", "metal")
	check(gold_data.get("name") == "金犼" and gold_data.get("species") == "金毛犼", "金犼名称与金毛犼物种分离且保留 metal ID")
	check(gold_data.get("portrait") == "res://assets/characters/pet_metal.png" and gold_data.get("portrait") != data.get_entry("units", "pebble").get("portrait"), "金犼使用独立于岩球的美术资源")
	var gold_art: Texture2D = load("res://scripts/battle/sprite_atlas.gd").pet_texture("metal")
	check(gold_art != null and gold_art.get_size() == Vector2(256, 256), "金犼头像可供编队和战斗实际加载")
	check(formation.has("hero"), "主角在阵")
	check(data.available_pets().size() == 5 and data.available_pets().has("metal"), "金木水火土五只宠物可选")
	check(data.valid_team(data.save_data["team"], formation), "旧阵容兼容五人上阵验证")
	var invalid_team: Array = (data.save_data["team"] as Array).duplicate()
	invalid_team[4] = invalid_team[1]
	check(not data.valid_team(invalid_team, formation), "重复宠物阵容不可入场")
	for pet_id: String in data.available_pets():
		var pet_config: Dictionary = data.get_entry("units", pet_id)
		check((pet_config.get("skills", []) as Array).size() == 1 and (pet_config.get("passives", []) as Array).size() == 4, "宠物配置含一主动四被动: " + pet_id)
	var unit_script: GDScript = load("res://scripts/battle/battle_unit.gd")
	var wood: BattleUnit = unit_script.new("sprout", "ally", 1, 0)
	var earth: BattleUnit = unit_script.new("pebble", "enemy", 0, 0)
	var fire: BattleUnit = unit_script.new("ember", "enemy", 1, 1)
	var water: BattleUnit = unit_script.new("mist", "enemy", 2, 2)
	var metal: BattleUnit = unit_script.new("hero", "ally", 0, 4)
	metal.elements = ["metal"]
	var owner_skill: Dictionary = data.get_entry("skills", "sprout_burst")
	check(is_equal_approx(battle.element_multiplier(wood, earth, owner_skill), 1.25), "五行木克土增伤")
	check(is_equal_approx(battle.element_multiplier(earth, wood, owner_skill), 0.8), "五行土被木克减伤")
	check(is_equal_approx(battle.element_multiplier(water, fire, owner_skill), 1.25), "五行水克火增伤")
	check(is_equal_approx(battle.element_multiplier(metal, wood, owner_skill), 1.25), "五行金克木可扩展")
	check(is_equal_approx(battle.element_multiplier(wood, fire, owner_skill), 1.0), "五行无克制不加成")
	check(data.get_entry("skills", "mist_arc").get("apply") == "damage_down", "雾刃降低目标输出而非给目标增伤")
	var hero_support: Dictionary = data.get_entry("skills", "hero_mend")
	check((data.get_entry("units", "hero").get("skills", []) as Array).has("hero_mend") and hero_support.get("target") == "ally" and hero_support.get("apply") == "heal", "主角新增可装备的友方治疗奥义")
	var first_friend: BattleUnit = unit_script.new("hero", "ally", 0, 0)
	var second_friend: BattleUnit = unit_script.new("sprout", "ally", 1, 1)
	var third_friend: BattleUnit = unit_script.new("ember", "ally", 2, 2)
	first_friend.hp = first_friend.max_hp / 2
	second_friend.hp = second_friend.max_hp / 4
	third_friend.hp = 0
	var friends: Array[BattleUnit] = [first_friend, second_friend, third_friend]
	check(battle.pick_wounded_ally(friends) == second_friend, "支援技能选择生命比例最低的存活友方")
	var health_before: int = second_friend.hp
	battle.apply_status(second_friend, "heal", hero_support)
	check(second_friend.hp == mini(second_friend.max_hp, health_before + int(hero_support.get("value", 0))) and third_friend.hp == 0, "治疗只给目标增加生命且不复活死者")
	second_friend.hp = second_friend.max_hp - 2
	battle.apply_status(second_friend, "heal", hero_support)
	check(second_friend.hp == second_friend.max_hp, "治疗被最大生命值截断")
	battle.apply_status(third_friend, "heal", hero_support)
	check(third_friend.hp == 0 and battle.pick_wounded_ally(friends) == first_friend, "死亡目标不会被治疗或选为援护目标")
	var cleanse_skill: Dictionary = data.get_entry("skills", "hero_cleanse")
	check((data.get_entry("units", "hero").get("skills", []) as Array).has("hero_cleanse") and cleanse_skill.get("target") == "ally" and cleanse_skill.get("apply") == "cleanse", "净化奥义接入主角装备数据")
	first_friend.add_effect("stun", 1)
	second_friend.add_effect("air", 1)
	second_friend.add_effect("damage_down", 2, 0.25)
	second_friend.add_effect("damage_up", 2, 0.2)
	second_friend.shields = 25
	third_friend.add_effect("down", 2)
	check(battle.pick_afflicted_ally(friends) == second_friend, "优先净化有效负面状态最多的存活友方")
	var cleanse_hp: int = second_friend.hp
	battle.apply_status(second_friend, "cleanse", cleanse_skill)
	check(battle.last_cleansed == ["air", "damage_down"] and not second_friend.has_effect("air") and not second_friend.has_effect("damage_down"), "一次命中只移除目标有效负面状态并报告实际两项")
	check(second_friend.has_effect("damage_up") and second_friend.shields == 25 and second_friend.hp == cleanse_hp, "净化保留增益护盾与血量")
	check(battle.pick_afflicted_ally(friends) == first_friend, "死亡友方不会抢占净化目标")
	battle.apply_status(first_friend, "cleanse", cleanse_skill)
	check(battle.pick_afflicted_ally(friends) == null and battle.last_cleansed == ["stun"], "清除末个有效负面状态后没有净化目标")
	first_friend.add_effect("down", 0)
	battle.apply_status(first_friend, "cleanse", cleanse_skill)
	check(first_friend.effects.has("down") and battle.last_cleansed.is_empty(), "过期负面状态不计入实际净化结果")
	var stunned: BattleUnit = unit_script.new("enemy_seed", "enemy", 0, 0)
	stunned.add_effect("stun", 1)
	stunned.tick()
	check(stunned.has_effect("stun"), "目标本轮已行动时眩晕不会在轮末过期")
	var passive_events: Array[String] = []
	battle.passive_triggered.connect(func(unit: BattleUnit, passive_id: String, effect: String, amount: int) -> void:
		passive_events.append("%s:%s:%s:%d" % [unit.id, passive_id, effect, amount])
	)
	var passive_probe: BattleUnit = unit_script.new("sprout", "ally", 1, 0)
	passive_probe.passives = ["renew", "sprout_guard", "sprout_growth", "sprout_focus"]
	passive_probe.hp = passive_probe.max_hp
	battle.trigger_passive(passive_probe, "round_start")
	check(not passive_events.has("sprout:renew:heal:8") and not passive_events.has("sprout:sprout_focus:heal:4") and passive_events.has("sprout:sprout_growth:damage_up:6"), "满血不冒充治疗触发，真实增伤被动按名称与数值发事件")
	passive_probe.hp -= 15
	battle.trigger_passive(passive_probe, "round_start")
	check(passive_events.has("sprout:renew:heal:8") and passive_events.has("sprout:sprout_focus:heal:4"), "多条回合治疗被动各自报告实际回血")
	battle.trigger_passive(passive_probe, "enter")
	check(passive_events.has("sprout:sprout_guard:shield:9"), "入场护盾被动只在触发时通知")
	var cooldown_unit: BattleUnit = unit_script.new("hero", "ally", 0, 0)
	cooldown_unit.cooldowns["hero_strike"] = 3
	cooldown_unit.tick()
	cooldown_unit.tick()
	check(cooldown_unit.cooldowns["hero_strike"] == 1, "配置冷却2的奥义完整经过两次轮末仍不可释放")
	cooldown_unit.tick()
	check(cooldown_unit.cooldowns["hero_strike"] == 0, "配置冷却2的奥义在第三次轮末解锁")
	var shielded: BattleUnit = unit_script.new("enemy_flame", "enemy", 0, 0)
	shielded.shields = 10000
	var shield_hp: int = shielded.hp
	battle.rng.seed = 12
	var absorbed_damage: int = battle.deal_damage(wood, shielded, data.get_entry("skills", "basic"))
	check(absorbed_damage == 0 and shielded.hp == shield_hp and shielded.shields < 10000, "护盾优先吸收伤害且实际生命伤害为零")
	var weakened: BattleUnit = unit_script.new("sprout", "ally", 1, 0)
	weakened.crit = 0.0
	var normal_target: BattleUnit = unit_script.new("enemy_flame", "enemy", 0, 0)
	normal_target.crit = 0.0
	var weaker_target: BattleUnit = unit_script.new("enemy_flame", "enemy", 0, 0)
	weaker_target.crit = 0.0
	weakened.add_effect("damage_down", 2, 0.25)
	battle.rng.seed = 12
	var weakened_damage: int = battle.deal_damage(weakened, weaker_target, data.get_entry("skills", "basic"))
	battle.rng.seed = 12
	var normal_damage: int = battle.deal_damage(wood, normal_target, data.get_entry("skills", "basic"))
	check(weakened_damage < normal_damage, "降低输出只作用于出手者")
	var targets: Array[BattleUnit] = [wood, earth, fire]
	battle.rng.seed = 773
	var first_draws: Array[String] = []
	for draw in range(12):
		first_draws.append(battle.pick_target(targets).id)
	battle.rng.seed = 773
	var repeated_draws: Array[String] = []
	for draw in range(12):
		repeated_draws.append(battle.pick_target(targets).id)
	check(first_draws == repeated_draws, "固定种子重放目标抽取顺序")
	battle.running = true
	battle.expected_action_id = 9021
	battle.expected_phase = "windup"
	battle.acknowledged = false
	battle.animation_completed.emit(9020, "windup")
	battle.animation_completed.emit(9021, "impact")
	check(not battle.acknowledged, "迟到或错误阶段演出回执不解锁当前动作")
	battle.animation_completed.emit(9021, "windup")
	check(battle.acknowledged, "匹配动作与阶段的演出回执被接受")
	battle.acknowledged = false
	var timeout_started: int = Time.get_ticks_msec()
	await battle.wait_for_animation(9021, "windup", battle.battle_serial)
	check(Time.get_ticks_msec() - timeout_started < 4000 and battle.expected_action_id == -1, "缺失演出回执后不永久卡住")
	battle.running = false
	game.current_stage = "stage_1"
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainCity.tscn", "启动直接进入主城")
	var prior_stage: String = game.current_stage
	game.select_stage("stage_999")
	check(game.current_stage == prior_stage and not game.stage_pending, "未解锁副本不能绕过独立关卡页进入战斗")
	var scene_paths := ["res://scenes/MainMenu.tscn", "res://scenes/MainCity.tscn", "res://scenes/StageSelect.tscn", "res://scenes/Outskirts.tscn", "res://scenes/TeamSelect.tscn", "res://scenes/Battle.tscn"]
	for path in scene_paths:
		var scene: PackedScene = load(path)
		check(scene != null, "场景可加载: " + path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		root.add_child(instance)
		await process_frame
		if path.ends_with("MainMenu.tscn"):
			check(instance.get_child_count() >= 3, "菜单背景和界面可见")
			var artwork: TextureRect = instance.get_node_or_null("FullMenuArtwork")
			check(artwork != null and artwork.texture != null and artwork.texture.resource_path == "res://assets/backgrounds/menu_pet_garden.png" and artwork.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "主菜单完整原图按比例显示")
		elif path.ends_with("MainCity.tscn"):
			check(instance.npc != null and instance.actor_layer.get_node_or_null("VisiblePlayerModel") != null, "主城程序绘制角色与可交互 NPC 可见")
			check(instance.npc.get_node_or_null("VisibleNpcModel") != null and instance.actor_layer.get_node_or_null("VisiblePlayerModel") != null, "主城向导与玩家具有无残留文字的人物模型")
			check(instance.npc.get_node("VisibleNpcModel") is Sprite2D and instance.actor_layer.get_node("VisiblePlayerModel") is Sprite2D, "主城玩家与向导使用新美术形象")
			check(instance.header != null and instance.status_panel != null and instance.nav_panel != null and instance.party_panel != null, "主城四区 HUD 与状态栏加载")
			check(instance.bag_button != null and instance.pet_bag != null and not instance.pet_bag.visible, "宠物背包入口与关闭态")
			instance.toggle_pet_bag()
			var player_model: Sprite2D = instance.actor_layer.get_node("VisiblePlayerModel")
			check(instance.pet_bag.visible and instance.pet_bag.z_index > maxi(instance.npc.z_index, player_model.z_index), "宠物背包始终绘制在 NPC 和玩家角色上方")
			check(instance.pet_bag.visible and instance.pet_list.get_child_count() == data.owned_pets().size(), "已拥有宠物全部进入背包列表")
			for pet_id: String in data.owned_pets():
				var pet_card: Button = instance.pet_list.get_node_or_null("PetCard_" + pet_id)
				var card_portrait: TextureRect = pet_card.get_node_or_null("PetCardContent/Portrait") if pet_card != null else null
				check(card_portrait != null and card_portrait.texture != null and card_portrait.custom_minimum_size.x >= 64, "背包宠物卡片具备独立可见缩略图: " + pet_id)
				if card_portrait != null:
					check(card_portrait.get_global_rect().size.x >= 64 and card_portrait.get_global_rect().size.y >= 64 and pet_card.get_global_rect().encloses(card_portrait.get_global_rect()), "背包缩略图实际绘制区域位于卡片内: " + pet_id)
				if pet_id == "metal" and card_portrait != null:
					check(card_portrait.texture.resource_path == gold_data["portrait"] and pet_card.icon == null, "金犼缩略图单独绘制而非挤入文字按钮")
			if data.owned_pets().has("metal"):
				instance._select_pet("metal")
				var species_found := false
				for detail in instance.pet_detail.get_children():
					if detail is Label and detail.text.contains("物种：金毛犼"):
						species_found = true
				check(species_found and (instance.pet_detail.get_child(0) as TextureRect).texture.resource_path == gold_data["portrait"], "宠物背包展示金毛犼物种与专属形象")
				var gold_skill_ids: Array = (gold_data.get("skills", []) as Array) + (gold_data.get("passives", []) as Array) + [gold_data.get("chase", "")]
				for skill_id: Variant in gold_skill_ids:
					var card: PanelContainer = instance.pet_detail.get_node_or_null("SkillCard_" + str(skill_id))
					var heading: Label = card.get_node_or_null("SkillCardContent/SkillCardHeading/SkillName") if card != null else null
					var icon: Control = card.get_node_or_null("SkillCardContent/SkillCardHeading/SkillTypeIcon") if card != null else null
					var info: Label = card.get_node_or_null("SkillCardContent/SkillInfo") if card != null else null
					check(card != null and heading != null and icon != null and info != null, "金犼每条技能有独立卡片和分类图标: " + str(skill_id))
					if heading != null and icon != null and info != null:
						var passive: bool = (gold_data.get("passives", []) as Array).has(skill_id)
						check(icon.kind == ("passive" if passive else "chase" if str(skill_id) == str(gold_data.get("chase", "")) else "active") and heading.text.contains(str(data.get_entry("passives" if passive else "skills", str(skill_id)).get("name", skill_id))), "主动被动及追打图标类型与技能名匹配: " + str(skill_id))
						check(info.text.contains("触发：") if passive else info.text.contains("威力系数") and info.text.contains("能量") and info.text.contains("冷却"), "技能原有效果和消耗信息保留: " + str(skill_id))
			if not data.owned_pets().is_empty():
				check(instance.selected_pet_id == ("metal" if data.owned_pets().has("metal") else data.owned_pets()[0]) and instance.pet_detail.get_child_count() > 2, "选中宠物展示形象和技能详情")
			var original_owned: Variant = data.save_data.get("owned_pets", [])
			data.save_data["owned_pets"] = []
			instance._refresh_pet_bag()
			check(instance.pet_list.get_child_count() == 1 and instance.selected_pet_id == "", "空宠物背包显示引导")
			data.save_data["owned_pets"] = original_owned
			var original_sprout: Dictionary = data.get_entry("units", "sprout")
			if original_owned is Array and (original_owned as Array).has("sprout"):
				(data.tables["units"] as Dictionary)["sprout"]["skills"] = []
				(data.tables["units"] as Dictionary)["sprout"]["passives"] = []
				(data.tables["units"] as Dictionary)["sprout"]["chase"] = ""
				instance._select_pet("sprout")
				check((instance.pet_detail.get_child(instance.pet_detail.get_child_count() - 1) as Label).text.contains("暂未拥有技能"), "无技能宠物显示空技能提示")
				(data.tables["units"] as Dictionary)["sprout"] = original_sprout
			instance.toggle_pet_bag()
			check(instance.city_map.get_node_or_null("ConceptModelLayer") == null, "旧三维视口贴图已从主城移除")
			check(instance.city_map.get_node_or_null("ConceptTerrain") == null and instance.city_map.get_node_or_null("CityModel0") == null, "旧主城贴图已移除")
			check(load("res://assets/backgrounds/city_pet_panorama.png") != null, "新版萌宠主城美术贴图已导入")
			check(instance.city_map.OBSTACLES.size() == 10 and instance.city_map.BOUNDS.size.y > 500, "俯视地图建筑与广场布局加载")
			check(instance.status_label.text.contains("Lv.") and instance.status_label.text.contains("历练"), "角色等级与关卡状态可见")
			for icon in [instance.header.get_child(0).get_child(0), instance.status_panel.get_child(0).get_child(0), instance.nav_panel.get_child(0).get_child(0), instance.party_panel.get_child(0).get_child(0)]:
				check(icon.get_script() != null, "主城功能图标已接入")
			for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540), Vector2i(640, 480)]:
				root.content_scale_size = viewport_size
				DisplayServer.window_set_size(viewport_size)
				await process_frame
				instance._layout_hud()
				var bounds: Rect2 = instance.party_panel.get_global_rect()
				var heading_bounds: Rect2 = instance.header.get_global_rect()
				var nav_bounds: Rect2 = instance.nav_panel.get_global_rect()
				var status_bounds: Rect2 = instance.status_panel.get_global_rect()
				check(not heading_bounds.intersects(bounds) and not status_bounds.intersects(bounds) and nav_bounds.position.y > bounds.end.y and bounds.end.x <= viewport_size.x + 1.0, "主城布局不遮挡 %s" % viewport_size)
				var dialogue_bounds: Rect2 = instance.dialogue.get_global_rect()
				check(dialogue_bounds.position.x >= -1.0 and dialogue_bounds.end.x <= viewport_size.x + 1.0 and dialogue_bounds.end.y <= viewport_size.y + 1.0, "对话层位于屏幕内 %s (实际 %s)" % [viewport_size, dialogue_bounds])
			root.content_scale_size = Vector2i(1280, 720)
			DisplayServer.window_set_size(Vector2i(1280, 720))
			await process_frame
			check(instance.city_map.bodies.size() == instance.city_map.OBSTACLES.size(), "所有建筑和花坛均有实体碰撞体")
			for obstacle: Rect2 in instance.city_map.OBSTACLES:
				check(not instance.city_map.is_walkable(obstacle.get_center()), "障碍中心不可通行")
			check(instance.city_map.is_walkable(Vector2(340, 550)) and instance.city_map.is_walkable(Vector2(760, 660)) and instance.city_map.is_walkable(Vector2(920, 510)), "道路采样均可通行")
			check(instance.city_map.is_walkable(Vector2(810, 625)) and instance.city_map.is_walkable(Vector2(920, 700)) and instance.city_map.is_walkable(Vector2(1610, 640)), "新增广场中心与边缘保持可通行")
			var plaza_route: Array[Vector2] = instance.city_map.find_path(Vector2(370, 560), Vector2(1660, 702))
			check(plaza_route.size() > 0 and instance.city_map.is_walkable(plaza_route.back()), "主路连通东侧广场")
			check(instance.city_map.WORLD_SIZE.x > 1280.0 and instance.city_map.is_walkable(Vector2(1620, 685)), "扩展地图超过一屏且东侧道路可探索")
			instance.player_foot = Vector2(1530, 685)
			instance._update_camera()
			check(instance.camera_offset.x > 0.0 and instance.city_map.position.x < 0.0, "向东移动时跟随镜头滚动")
			instance.player_foot = Vector2(334, 558)
			instance._update_camera()
			var gate: Rect2 = instance.city_map.EXIT_REGIONS[0]["area"]
			check(instance.city_map.EXIT_REGIONS.size() == 1 and instance.city_map.is_walkable(gate.get_center()), "东侧出口位于可到达的石路内")
			check(instance.city_map.is_walkable(gate.position + Vector2(2, 2)) and instance.city_map.is_walkable(gate.end - Vector2(2, 2)), "城门触发区全域均可站立")
			check(gate.get_center().y < 500.0 and gate.get_center().x > 1880.0 and not Rect2(1950, 682, 44, 94).has_point(gate.get_center()), "传送点位于原画右上城门而不是旧东南角")
			check(instance.city_map.is_walkable(Vector2(550, 475)) and instance.city_map.is_walkable(Vector2(1925, 490)), "画面道路北沿与城门引道开放")
			check(instance.city_map.is_walkable(Vector2(650, 565)) and instance.city_map.is_walkable(Vector2(746, 580)) and instance.city_map.is_walkable(Vector2(1060, 585)) and instance.city_map.is_walkable(Vector2(1155, 580)), "花坛喷泉周围的图上道路不再被宽碰撞框封堵")
			var screenshot_obstacles := [Vector2(215, 365), Vector2(510, 375), Vector2(1095, 365), Vector2(690, 585), Vector2(1105, 595)]
			for marker: Vector2 in screenshot_obstacles:
				check(not instance.city_map.is_walkable(marker), "截图建筑和花坛不可穿越 %s" % marker)
			check(not instance.city_map.is_walkable(Vector2(550, 400)) and not instance.city_map.is_walkable(Vector2(550, 840)) and not instance.city_map.is_walkable(Vector2(2020, 730)), "建筑背后、道路下方与画面外侧均不可走")
			var edge_spawn: Vector2 = instance.city_map.nearest_walkable(Vector2(2020, 730))
			check(instance.city_map.is_walkable(edge_spawn), "越界主城出生点回退到道路内")
			var gate_route: Array[Vector2] = instance.city_map.find_path(Vector2(334, 558), gate.get_center())
			check(not gate_route.is_empty() and gate.has_point(gate_route.back()), "主路寻路终点进入东侧传送范围")
			instance.player_foot = Vector2(1955, 585)
			check(instance.city_map.is_walkable(instance.player_foot), "城门引道起点避开东侧花坛")
			instance.set_destination(gate.get_center())
			for approach_frame in range(110):
				if not instance.exit_armed:
					break
				instance._process(0.02)
			check(not instance.exit_armed, "点击城门沿引道前进可触发传送")
			instance.exit_armed = true
			instance.has_destination = false
			instance.path_points.clear()
			instance.player_foot = Vector2(334, 558)
			var original_foot: Vector2 = instance.player_foot
			instance.player_foot = Vector2(630, 590)
			instance.move_with_collision(Vector2(180, 0))
			check(instance.player_foot.x < 655 and instance.city_map.is_walkable(instance.player_foot), "角色不能穿过喷泉中央脚印")
			instance.player_foot = Vector2(550, 490)
			instance.move_with_collision(Vector2(0, -180))
			check(instance.player_foot.y >= 466 and instance.city_map.is_walkable(instance.player_foot), "WASD 不能越过主路北侧边界")
			instance.player_foot = Vector2(550, 785)
			instance.move_with_collision(Vector2(0, 180))
			check(instance.player_foot.y <= 799 and instance.city_map.is_walkable(instance.player_foot), "WASD 不能越过主路南侧边界")
			instance.player_foot = original_foot
			var around: Array[Vector2] = instance.city_map.find_path(Vector2(580, 500), Vector2(733, 620))
			check(around.size() > 0, "点击道路可绕过喷泉规划路线")
			for waypoint: Vector2 in around:
				check(instance.city_map.is_walkable(waypoint), "自动寻路节点位于可行走区域")
			check(not instance.dialogue.visible and instance.player_foot.distance_to(instance.NPC_FOOT) > instance.TALK_DISTANCE, "关卡对话不能在远处开启")
			var start: Vector2 = instance.player_foot
			instance.set_destination(start + Vector2(90, 40))
			instance._process(0.1)
			check(instance.player_foot.distance_to(start) > 0.0 and instance.has_destination, "鼠标目的地支持地面自动移动")
			instance.request_npc_conversation()
			check(not instance.dialogue.visible and instance.waiting_for_npc, "点击远处 NPC 先接近后对话")
			for move_frame in range(130):
				instance._process(0.02)
			check(instance.dialogue.visible, "靠近向导自动触发对话")
			instance.close_dialogue()
			check(not instance.dialogue.visible, "取消 NPC 对话保持主城")
		elif path.ends_with("StageSelect.tscn"):
			check(instance.stage_buttons.size() == 3, "独立关卡场景包含三关")
			check(instance.get_child(0).texture.resource_path == "res://assets/backgrounds/menu_pet_garden.png", "关卡页使用统一背景")
			for i in range(3):
				check(instance.stage_buttons[i].disabled == (i + 1 > int(data.save_data["unlocked_stage"])), "关卡解锁状态匹配存档 %d" % (i + 1))
		elif path.ends_with("Outskirts.tscn"):
			check(instance.model != null and instance.player_foot.distance_to(Vector2(140, 576)) < 2.0, "邻接区域成功加载并显示人物")
			check(instance.RETURN.has_point(Vector2(84, 570)), "邻接区域包含可返回主城的出口")
			check(instance.model.texture.resource_path == "res://assets/characters/pet_hero.png", "外缘玩家复用主角美术")
		elif path.ends_with("TeamSelect.tscn"):
			check(instance.grid_buttons.size() == 9, "阵容九格可见")
			var support_in_picker := false
			for option_index in range(instance.skill_picker.item_count):
				if instance.skill_picker.get_item_metadata(option_index) == "hero_mend":
					support_in_picker = true
			check(support_in_picker, "编队页可选择新支援奥义")
			var cleanse_in_picker := false
			for option_index in range(instance.skill_picker.item_count):
				if instance.skill_picker.get_item_metadata(option_index) == "hero_cleanse":
					cleanse_in_picker = true
			check(cleanse_in_picker, "编队页可装备净化奥义")
			var initial_skill_id: String = str(instance.skill_picker.get_item_metadata(instance.skill_picker.selected))
			check(instance.skill_description.text.contains(str(data.get_entry("skills", initial_skill_id).get("name", ""))) and instance.skill_description.text.contains("目标：") and instance.skill_description.text.contains("效果：") and instance.skill_description.text.contains("冷却："), "编队页展示当前主角奥义说明")
			for option_index in range(instance.skill_picker.item_count):
				if instance.skill_picker.get_item_metadata(option_index) == "hero_mend":
					instance.skill_picker.select(option_index)
					instance.skill_picker.item_selected.emit(option_index)
					break
			check(instance.skill_description.text.contains("复苏援护") and instance.skill_description.text.contains("友方单体") and instance.skill_description.text.contains("治疗 36 生命") and instance.skill_description.text.contains("40 能量"), "切换主角奥义时同步展示实际效果与消耗")
			check(instance.get_child(0).texture.resource_path == "res://assets/backgrounds/menu_pet_garden.png", "编队页使用统一背景")
			check(not game.stage_pending, "主城直接编队时不会误入旧副本")
			var before: int = formation.find("hero")
			instance.move_unit("hero", 8)
			check(instance.formation[8] == "hero", "主角可换位")
			instance.move_unit("hero", before)
			instance.selected_id = "metal"
			instance.replace_pet("mist")
			check(instance.team.has("metal") and not instance.team.has("mist") and instance.formation.has("metal") and data.valid_team(instance.team, instance.formation), "候选金宠替换当前上阵宠物")
			instance.refresh()
			var gold_cell: Button = instance.grid_buttons[instance.formation.find("metal")]
			check(gold_cell.text.contains("金犼") and gold_cell.icon != null and gold_cell.icon.resource_path == gold_data["portrait"], "编队阵位显示金犼名称与专属美术")
			var gold_slot: Button = instance.roster_buttons[instance.team.find("metal")]
			check(gold_slot.text.contains("金犼") and gold_slot.icon != null, "编队名单显示金犼形象")
		else:
			check(battle.allies.size() == 5, "五名我方单位创建")
			check(instance.card_for(battle.allies[0]) != null, "战斗使用实际格位")
			check(instance.actors.size() == battle.allies.size() + battle.enemies.size(), "每个参战单位均有独立角色模型")
			var ally_model: BattleActor = instance.actor_for(battle.allies[0])
			var enemy_model: BattleActor = instance.actor_for(battle.enemies[0])
			check(ally_model.facing == 1.0 and enemy_model.facing == -1.0, "敌我角色初始相向站立")
			check(ally_model.portrait != null and ally_model.portrait.resource_path == "res://assets/characters/pet_hero.png", "战斗模型预载立绘避免每帧查询贴图")
			check(ally_model.anticipation == 0.0 and ally_model.impact_jolt == 0.0 and ally_model.cast_charge == 0.0, "角色蓄力、施法与受击姿态初始中性")
			var roster_clear: bool = true
			for roster_unit: BattleUnit in battle.allies + battle.enemies:
				var roster_card: Control = instance.card_for(roster_unit)
				var roster_actor: BattleActor = instance.actor_for(roster_unit)
				var actor_zone := Rect2(roster_actor.home + Vector2(-68, -143), Vector2(136, 154))
				if roster_card.get_global_rect().intersects(actor_zone) or roster_card.get_global_rect().end.y > 550.0 or roster_card.get_global_rect().end.x > 1270.0 or not roster_card.clip_contents:
					roster_clear = false
			check(roster_clear, "双方名称血量状态卡位于战场下沿且不遮挡角色立绘")
			check(instance.skill_banner.position.y > instance.target_label.get_global_rect().end.y and instance.skill_banner.position.y + instance.skill_banner.size.y < 240, "技能横幅避开顶部提示与角色主要区域")
			check(instance.effect_index("basic", data.get_entry("skills", "basic"), 0, false) == 1 and instance.effect_index("metal_edge", data.get_entry("skills", "metal_edge"), 0, false) == 1 and instance.effect_index("hero_mend", data.get_entry("skills", "hero_mend"), 0, true) == 2 and instance.effect_index("chase_down", data.get_entry("skills", "chase_down"), 1, false) == 3, "普攻、奥义、援护、追打特效按技能分类并保持出手命中一致")
			var signatures: Array[String] = []
			for visual_skill_id: String in (data.tables["skills"] as Dictionary).keys():
				if visual_skill_id == "basic":
					continue
				var visual_skill: Dictionary = data.get_entry("skills", visual_skill_id)
				var signature: String = instance.skill_signature(visual_skill_id, visual_skill)
				check(signature != "basic" and signature != "", "主动或追打具备独立视觉签名: " + visual_skill_id)
				signatures.append(signature)
			check(instance.skill_signature("chase_air", data.get_entry("skills", "chase_air")) != instance.skill_signature("chase_down", data.get_entry("skills", "chase_down")), "浮空和倒地追打轮廓不同")
			var passive_signatures: Array[String] = []
			for visual_passive_id: String in (data.tables["passives"] as Dictionary).keys():
				var visual_passive: Dictionary = data.get_entry("passives", visual_passive_id)
				var passive_signature: String = instance.skill_signature(visual_passive_id, visual_passive)
				check(passive_signature != "" and passive_signature != "basic", "被动可辨效果及触发时机: " + visual_passive_id)
				passive_signatures.append(passive_signature)
			check(instance.skill_signature("bulwark", data.get_entry("passives", "bulwark")) != instance.skill_signature("sprout_guard", data.get_entry("passives", "sprout_guard")), "受击护盾与入场护盾视觉时机不同")
			check(instance.pending_passives.is_empty() and not instance.recent_passives.is_empty() and instance.passive_notice != null, "入场被动在角色创建后显示并保留独立名称")
			var fire_skill: Dictionary = data.get_entry("skills", "ember_flare")
			var water_skill: Dictionary = data.get_entry("skills", "mist_arc")
			check(instance.effect_color(fire, fire_skill, 0, false) != instance.effect_color(water, water_skill, 0, false), "火与水技能的施法和命中颜色可辨")
			check(instance.effect_color(battle.allies[0], data.get_entry("skills", "hero_mend"), 0, true) == instance.effect_color(battle.allies[0], data.get_entry("skills", "hero_cleanse"), 0, true), "同类援护技能保持玉色视觉语言")
			var no_element: BattleUnit = unit_script.new("hero", "ally", 0, 0)
			no_element.elements.clear()
			check(instance.effect_color(no_element, data.get_entry("skills", "hero_strike"), 0, false).a > 0.0, "缺失角色属性时技能着色安全回退")
			var facing_probe: BattleActor = load("res://scenes/BattleActor.tscn").instantiate()
			instance.actors_layer.add_child(facing_probe)
			facing_probe.configure(battle.enemies[0], enemy_model.home)
			facing_probe.face_toward(enemy_model.home + Vector2(110, 0))
			check(facing_probe.facing == 1.0, "敌方移动攻击前能转向实际目标")
			facing_probe.face_opponent()
			check(facing_probe.facing == -1.0, "敌方返回站位后面向我方")
			facing_probe.queue_free()
			var battle_background: TextureRect = instance.get_node("BattleBackground") as TextureRect
			check(battle_background.texture.resource_path == "res://assets/backgrounds/battle_courtyard_universal.png" and battle_background.texture.get_size() == Vector2(1280, 720), "战斗场景加载通用云庭背景并匹配设计视口")
			check(battle_background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED and battle_background.mouse_filter == Control.MOUSE_FILTER_IGNORE and battle_background.get_index() < instance.stage_layer.get_index(), "背景等比铺满且位于角色与交互界面之下")
			for battle_size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540), Vector2i(640, 480)]:
				root.content_scale_size = battle_size
				await process_frame
				check(battle_background.get_global_rect().size == Vector2(battle_size), "通用战斗背景适配视口 %s" % battle_size)
			root.content_scale_size = Vector2i(1280, 720)
			await process_frame
			check(load("res://scripts/battle/sprite_atlas.gd").effect_for(0) != null, "统一技能效果图集可加载")
			check(load("res://scripts/battle/sprite_atlas.gd").pet_texture("hero") != null, "战斗角色贴图已接入")
			var gold_battle_unit: BattleUnit = unit_script.new("metal", "ally", 0, 0)
			var gold_battle_actor: BattleActor = load("res://scenes/BattleActor.tscn").instantiate()
			gold_battle_actor.unit = gold_battle_unit
			check(gold_battle_actor.unit.name == "金犼" and load("res://scripts/battle/sprite_atlas.gd").pet_texture(gold_battle_actor.unit.id).resource_path == gold_data["portrait"], "金犼战斗角色读取专属美术和名称")
			gold_battle_actor.free()
			check(instance.actor_for(battle.allies[0]) != null and instance.actor_for(battle.allies[0]) is BattleActor, "主角为可独立运动的角色")
			check(not instance.card_for(battle.allies[0]).get_meta("parts").has("face"), "血条界面不再使用静态人物图片")
			check(instance.camera_layer != null and instance.fx_particles.process_material != null, "镜头和特效组件已加载")
			check(instance.round_label.text.contains("/ 20 回合") and instance.order_label.text.contains("后续"), "回合上限与后续行动队列可读")
			check(instance.action_hint.text.contains("点击目标") and instance.target_label != null, "目标选择提示和锁定反馈区域可见")
			var targeting_hero: BattleUnit = battle.allies[0]
			var front_enemy: BattleUnit = battle.enemies[0]
			var middle_enemy: BattleUnit = battle.enemies[2]
			var back_enemy: BattleUnit = battle.enemies[3]
			var original_actor: BattleUnit = battle.active_unit
			var original_targeting_energy: int = targeting_hero.energy
			battle.active_unit = targeting_hero
			instance.refresh()
			var equipped_skill: String = instance.active_skill_id(targeting_hero)
			check(instance.shortcut_hint.visible and instance.shortcut_hint.text.contains("主键盘 / 小键盘 1 普攻") and instance.shortcut_hint.text.contains("2 主动技能") and instance.shortcut_hint.text.contains("选后点目标"), "面板关闭时仍显示主键盘与小键盘快捷键指南")
			check(instance.summary_toggle.get_parent().get_parent().get_parent() == instance.skill_detail and not instance.summary_toggle.button_pressed and not instance.skill_detail.visible and instance.get_node_or_null("BasicSummary") == null, "简洁说明仅在默认关闭的技能描述面板内")
			check(instance.skill_detail_text("basic", targeting_hero).contains("消耗：") and instance.skill_summary("basic").contains("威力系数 1.00"), "普攻提供详细与简洁两种描述")
			check(instance.skill_detail_text("basic", targeting_hero).contains("最前排") and instance.skill_detail_text(equipped_skill, targeting_hero).contains("消耗：") and instance.skill_detail_text("hero_mend", targeting_hero).contains("治疗 36生命"), "详细说明区分目标、效果数值与资源")
			var key_one := InputEventKey.new()
			key_one.pressed = true
			key_one.keycode = KEY_1
			instance._unhandled_key_input(key_one)
			check(instance.pending_skill_id == "basic", "快捷键 1 选择普攻")
			var key_two := InputEventKey.new()
			key_two.pressed = true
			key_two.keycode = KEY_2
			instance._unhandled_key_input(key_two)
			check(instance.pending_skill_id == equipped_skill, "快捷键 2 选择当前单位主动技能")
			key_one.keycode = KEY_KP_1
			instance._unhandled_key_input(key_one)
			check(instance.pending_skill_id == "basic", "小键盘 1 选择普攻")
			key_two.keycode = KEY_KP_2
			instance._unhandled_key_input(key_two)
			check(instance.pending_skill_id == equipped_skill, "小键盘 2 选择主动技能")
			instance.pending_skill_id = ""
			key_one.echo = true
			instance._unhandled_key_input(key_one)
			check(instance.pending_skill_id == "", "长按快捷键不会重复选择")
			key_one.echo = false
			battle.active_unit = front_enemy
			instance._unhandled_key_input(key_one)
			check(instance.pending_skill_id == "", "敌方回合不能使用快捷键选择行动")
			battle.active_unit = targeting_hero
			targeting_hero.energy = 0
			instance.refresh()
			instance._unhandled_key_input(key_two)
			check(instance.pending_skill_id == "" and instance.ultimate_button.disabled and instance.skill_detail_text(equipped_skill, targeting_hero).contains("能量不足"), "禁用技能仍可查看详情但快捷键无法绕过资源校验")
			var hold_press := InputEventMouseButton.new()
			hold_press.button_index = MOUSE_BUTTON_LEFT
			hold_press.pressed = true
			hold_press.position = instance.ultimate_button.get_global_rect().get_center()
			instance._input(hold_press)
			check(instance.held_skill_button == instance.ultimate_button and instance.skill_hold_timer.time_left > 0, "禁用按钮仍由全局输入识别长按")
			instance.skill_hold_timer.stop()
			instance.detail_skill_id = equipped_skill
			instance.detail_actor = targeting_hero
			instance.long_press_consumed = true
			instance.refresh_skill_detail()
			instance.skill_detail.show()
			check(instance.skill_detail_label.text.contains("消耗：") and instance.skill_detail_label.text.contains("能量不足"), "长按默认显示当前技能详细说明")
			var hold_release := InputEventMouseButton.new()
			hold_release.button_index = MOUSE_BUTTON_LEFT
			hold_release.pressed = false
			instance._input(hold_release)
			check(instance.skill_detail.visible and instance.held_skill_button == null and instance.pending_skill_id == "", "松开后描述保持可操作且未选择技能")
			instance.activate_skill_button("ultimate")
			check(instance.pending_skill_id == "", "长按释放不误触技能按钮")
			instance.summary_toggle.button_pressed = true
			check(instance.skill_detail_label.text.contains(str(data.get_entry("skills", equipped_skill).get("name", ""))) and not instance.skill_detail_label.text.contains("消耗："), "面板内切换简洁说明立即更新当前技能")
			instance.close_skill_detail()
			instance.detail_skill_id = "basic"
			instance.detail_actor = targeting_hero
			instance.refresh_skill_detail()
			instance.skill_detail.show()
			check(instance.skill_detail_label.text.contains("威力系数 1.00") and not instance.skill_detail_label.text.contains("冷却："), "简洁模式对随后打开的普攻生效")
			instance.summary_toggle.button_pressed = false
			check(instance.skill_detail_label.text.contains("目标：") and instance.skill_detail_label.text.contains("冷却："), "面板内可切回详细模式")
			instance.skill_detail.get_child(0).get_child(1).get_child(1).emit_signal("pressed")
			check(not instance.skill_detail.visible, "关闭按钮可关闭描述面板")
			instance.detail_actor = targeting_hero
			instance.detail_skill_id = "basic"
			instance.skill_detail.show()
			var outside_press := InputEventMouseButton.new()
			outside_press.button_index = MOUSE_BUTTON_LEFT
			outside_press.pressed = true
			outside_press.position = Vector2(700, 300)
			instance._input(outside_press)
			check(not instance.skill_detail.visible, "点击面板外部可关闭技能说明")
			targeting_hero.energy = original_targeting_energy
			instance.refresh()
			check(battle.valid_targets(targeting_hero, "basic").has(front_enemy) and not battle.valid_targets(targeting_hero, "basic").has(middle_enemy) and not battle.valid_targets(targeting_hero, "basic").has(back_enemy), "普通攻击仅允许选最前方存活列")
			check(battle.valid_targets(targeting_hero, "hero_strike").has(front_enemy) and not battle.valid_targets(targeting_hero, "hero_strike").has(back_enemy), "未标记自由选目标的奥义也受前排限制")
			check(bool(data.get_entry("skills", "hero_wave").get("free_target", false)) and bool(data.get_entry("skills", "mist_arc").get("free_target", false)) and battle.valid_targets(targeting_hero, "hero_wave").has(back_enemy), "明确标记自由目标的技能可跨排选后排")
			instance.begin_targeting("basic")
			instance.refresh()
			check(instance.pending_skill_id == "basic" and instance.card_for(front_enemy).tooltip_text.contains("点击选择") and instance.card_for(back_enemy).tooltip_text.contains("不可选择"), "前排优先规则同步显示在目标界面")
			check((instance.target_buttons[front_enemy] as Button).mouse_filter == Control.MOUSE_FILTER_STOP and (instance.target_buttons[back_enemy] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE, "角色立绘热区仅允许点击合法目标")
			instance.choose_target_cell(1, back_enemy.cell)
			check(not battle.busy and battle.selected_target == null and instance.pending_skill_id == "basic", "点击不可选后排不会发起普攻")
			var enemy_health_before: int = back_enemy.hp
			battle.player_action("basic", back_enemy)
			check(not battle.busy and back_enemy.hp == enemy_health_before, "直接提交不合法目标也不会绕过攻击判定")
			instance.pending_skill_id = ""
			var hero_wave_added: bool = not targeting_hero.skills.has("hero_wave")
			if hero_wave_added:
				targeting_hero.skills.append("hero_wave")
			targeting_hero.energy = 100
			targeting_hero.cooldowns.erase("hero_wave")
			instance.begin_targeting("hero_wave")
			instance.refresh()
			check(instance.card_for(back_enemy).tooltip_text.contains("点击选择") and (instance.target_buttons[back_enemy] as Button).mouse_filter == Control.MOUSE_FILTER_STOP, "自由目标技能同步解锁后排角色及名册点击")
			instance.pending_skill_id = ""
			if hero_wave_added:
				targeting_hero.skills.erase("hero_wave")
			for front_unit: BattleUnit in battle.enemies:
				if front_unit.cell % 3 == 0:
					front_unit.hp = 0
			check(battle.valid_targets(targeting_hero, "basic").has(middle_enemy) and not battle.valid_targets(targeting_hero, "basic").has(back_enemy), "前排列全灭后普通攻击开放下一存活列")
			var middle_hp: int = middle_enemy.hp
			middle_enemy.hp = 0
			check(battle.valid_targets(targeting_hero, "basic").has(back_enemy), "前中排全灭后后排可选")
			middle_enemy.hp = middle_hp
			for front_unit: BattleUnit in battle.enemies:
				if front_unit.cell % 3 == 0:
					front_unit.hp = front_unit.max_hp
			targeting_hero.energy = original_targeting_energy
			battle.active_unit = original_actor
			instance.refresh()
			check(instance.has_method("spawn_support") and instance.ultimate_reason(battle.allies[0], "hero_mend") == "未装备该主动技能", "援护奥义保留装备限制与单独支援反馈")
			check((data.get_entry("units", "hero").get("skills", []) as Array).has("hero_mend"), "编队奥义选择器的数据源含复苏援护")
			check(instance.target_label.get_global_rect().end.y < 220 and instance.action_hint.get_global_rect().end.y <= 720, "目标提示与操作说明未越出战斗主界面")
			var status_parts: Dictionary = instance.card_for(battle.allies[0]).get_meta("parts")
			check(status_parts.has("status") and (status_parts["status"] as Label).text.contains("护盾"), "角色卡状态行展示进场护盾")
			var initial_hero: BattleUnit = battle.allies[0]
			var saved_active_unit: BattleUnit = battle.active_unit
			battle.active_unit = initial_hero
			var initial_skill: String = str(data.save_data["hero_skill"])
			var initial_energy: int = initial_hero.energy
			initial_hero.energy = 0
			instance.refresh()
			check(instance.action_hint.text.contains("能量不足") and instance.ultimate_button.disabled, "能量不足时 UI 告知禁用原因")
			initial_hero.energy = initial_energy
			initial_hero.cooldowns[initial_skill] = 2
			instance.refresh()
			check(instance.action_hint.text.contains("冷却中"), "技能冷却时 UI 告知禁用原因")
			initial_hero.cooldowns.erase(initial_skill)
			instance.refresh()
			var pet: BattleUnit = battle.allies[1]
			var pet_energy_before: int = pet.energy
			var pet_skill: String = instance.active_skill_id(pet)
			check(pet.id != "hero" and pet_skill != "" and pet.skills.has(pet_skill) and pet_skill != initial_skill, "宠物按钮读取自身主动技能而非主角装备")
			battle.active_unit = pet
			pet.energy = 100
			pet.cooldowns.erase(pet_skill)
			instance.summary_toggle.button_pressed = true
			instance.detail_skill_id = pet_skill
			instance.detail_actor = pet
			instance.refresh_skill_detail()
			instance.skill_detail.show()
			instance.refresh()
			check(instance.summary_toggle.button_pressed and instance.skill_detail_label.text.contains(str(data.get_entry("skills", pet_skill).get("name", ""))) and not instance.skill_detail_label.text.contains(str(data.get_entry("skills", initial_skill).get("name", ""))) and not instance.skill_detail_label.text.contains("消耗："), "切换我方单位时简洁说明持续生效并显示新单位技能")
			instance.close_skill_detail()
			check(not instance.basic_button.disabled and not instance.ultimate_button.disabled and instance.basic_button.text.contains(pet.name) and instance.ultimate_button.text.contains(str(data.get_entry("skills", pet_skill).get("name", ""))), "宠物回合可手动选择普通攻击或自身主动技能")
			pet.energy = 0
			instance.refresh()
			check(instance.ultimate_button.disabled and not instance.basic_button.disabled and instance.action_hint.text.contains("能量不足"), "宠物能量不足仅禁用主动技能")
			pet.energy = 100
			pet.cooldowns[pet_skill] = 2
			instance.refresh()
			check(instance.ultimate_button.disabled and instance.action_hint.text.contains("冷却中"), "宠物主动技能保持冷却限制")
			var pet_energy_locked: int = pet.energy
			battle.player_action(pet_skill)
			check(not battle.busy and pet.energy == pet_energy_locked, "宠物冷却期间手动提交技能被拒绝")
			pet.cooldowns.erase(pet_skill)
			pet.energy = pet_energy_before
			battle.active_unit = saved_active_unit
			instance.refresh()
			battle.action_started.connect(func(_a: BattleUnit, _t: BattleUnit, _s: String, _c: int, _id: int) -> void:
				started_events += 1
			)
			battle.action_impact.connect(func(_a: BattleUnit, _t: BattleUnit, _s: String, _d: int, combo: int, _id: int) -> void:
				animation_events += 1
				if animation_events > started_events:
					premature_hits += 1
				if combo > 0:
					chase_events += 1
			)
			var hero: BattleUnit = battle.allies[0]
			var hero_skill: String = str(data.save_data["hero_skill"])
			var required_energy: int = int(data.get_entry("skills", hero_skill).get("cost", 0))
			var saved_energy: int = hero.energy
			var saved_cooldowns: Dictionary = hero.cooldowns.duplicate()
			hero.energy = required_energy - 1
			check(not battle.can_cast(hero, hero_skill), "能量不足时奥义不可释放")
			hero.energy = required_energy
			hero.cooldowns[hero_skill] = 2
			check(not battle.can_cast(hero, hero_skill), "冷却中奥义不可释放")
			hero.cooldowns[hero_skill] = 0
			check(battle.can_cast(hero, hero_skill), "能量充足且冷却结束时奥义可释放")
			hero.energy = saved_energy
			hero.cooldowns = saved_cooldowns
			var eliminated: BattleUnit = battle.enemies[0]
			var old_hp: int = eliminated.hp
			eliminated.hp = 0
			var dead_only: Array[BattleUnit] = [eliminated]
			check(battle.pick_target(dead_only) == null, "死亡目标不能再次选中")
			eliminated.hp = old_hp
			battle.rng.seed = 12
			# 固定的首击追打探针：敌方保留足够生命，使手动宠物回合不改变追打覆盖率。
			for probe_enemy: BattleUnit in battle.enemies:
				probe_enemy.max_hp = maxi(probe_enemy.max_hp, 500)
				probe_enemy.hp = probe_enemy.max_hp
			if battle.active_unit != hero and battle.active_unit != null:
				battle.queue.push_front(battle.active_unit)
			battle.active_unit = hero
			hero.energy = 100
			hero.cooldowns.erase("hero_strike")
			battle.player_action("hero_strike", battle.valid_targets(hero, "hero_strike")[0])
			for n in range(3000):
				await process_frame
				for unit in battle.allies:
					var model: BattleActor = instance.actor_for(unit)
					if model != null and model.action_name != "idle":
						model_motion_seen = true
				if battle.active_unit != null and battle.active_unit.side == "ally" and not battle.busy:
					var acting_unit: BattleUnit = battle.active_unit
					var selected_skill: String = "hero_strike" if acting_unit.id == "hero" else instance.active_skill_id(acting_unit)
					var chosen_skill: String = selected_skill if battle.can_cast(acting_unit, selected_skill) else "basic"
					var options: Array[BattleUnit] = battle.valid_targets(acting_unit, chosen_skill)
					if not options.is_empty():
						battle.player_action(chosen_skill, options[0])
			check(animation_events > 0, "战斗命中动画回执")
			# 停止战斗后的独立冲击环检查，避免与实战中短效对象竞争计数。
			battle.running = false
			await create_timer(0.45).timeout
			var fx_before: int = instance.active_fx
			instance.spawn_impact_ring(Vector2(400, 250), Color("#ffa579"), false)
			check(instance.active_fx == fx_before + 1, "实际命中冲击环短时生成")
			await create_timer(0.30).timeout
			check(instance.active_fx == fx_before, "冲击环结束自动回收不累积")
			for phase: String in ["startup", "release", "impact"]:
				instance.spawn_phase_aura(Vector2(400, 250), Color("#ffa579"), phase, false)
				var aura: Node2D = instance.fx_layer.get_node_or_null("PhaseAura_" + phase) as Node2D
				check(aura != null and str(aura.get_meta("phase")) == phase, "三段式局部光效阶段可辨: " + phase)
				check(instance.active_fx == fx_before + 1, "三段式光效计入短效预算: " + phase)
				await create_timer(0.34).timeout
				check(instance.active_fx == fx_before and instance.fx_layer.get_node_or_null("PhaseAura_" + phase) == null, "三段式光效结束自动回收: " + phase)
			var fx_cap: int = instance.MAX_DECORATIVE_FX
			instance.active_fx = fx_cap
			instance.spawn_phase_aura(Vector2(400, 250), Color.WHITE, "impact")
			check(instance.active_fx == fx_cap and instance.fx_layer.get_node_or_null("PhaseAura_impact") == null, "特效密集时保留主体与浮字预算")
			instance.active_fx = fx_before
			check(chase_events > 0, "追打逐段动画回执")
			check(instance.last_hit_damage >= 0 and instance.target_label.text != "", "战斗中逐段目标与伤害反馈实际更新")
			check(model_motion_seen, "战斗角色独立运动")
			check(premature_hits == 0 and started_events >= animation_events, "出手演出早于伤害结算")
			# 停止自动推进后独立验证宠物技能从玩家入口进入原有结算链。
			battle.running = true
			battle.busy = false
			battle.queue.clear()
			battle.active_unit = pet
			pet.hp = pet.max_hp
			pet.effects.erase("stun")
			for probe_enemy: BattleUnit in battle.enemies:
				probe_enemy.hp = probe_enemy.max_hp
			pet.energy = 100
			pet.cooldowns.erase(pet_skill)
			var pet_energy_precast: int = pet.energy
			battle.player_action("basic", battle.valid_targets(pet, "basic")[0])
			check(battle.busy and pet.energy == pet_energy_precast and not pet.cooldowns.has(pet_skill), "宠物普通攻击经手动入口释放且不消耗技能资源")
			battle.busy = false
			battle.player_action(pet_skill, battle.valid_targets(pet, pet_skill)[0])
			check(battle.busy and pet.energy == pet_energy_precast - int(data.get_entry("skills", pet_skill).get("cost", 0)) and pet.cooldowns.has(pet_skill), "宠物主动技能经手动入口消耗能量并进入冷却")
			battle.running = false
			var chase_unique := true
			for chaser: BattleUnit in battle.chase_used:
				if battle.chase_used.count(chaser) != 1:
					chase_unique = false
			check(battle.chase_count <= int(battle.stage.get("chase_limit", 3)) and chase_unique, "追打上限及同一连击追打者去重")
			battle.running = true
			battle.finish(false)
			check(not battle.running and game.last_result == "失败" and instance.target_label.text.contains("失败"), "战斗失败结算和场景反馈一致")
			var prior_hero_hp: int = hero.hp
			battle.player_action("basic")
			check(not battle.busy and hero.hp == prior_hero_hp, "战斗停止后不再接受行动")
			var popup: Control = root.get_node("UIManager").popup
			check(popup != null and popup.get_child(0).get_child(0).get_child(2).text == "返回主城", "终局弹窗提供原流程返回入口")
			root.get_node("UIManager").close_popup()
		instance.queue_free()
		await process_frame
	# 独立战斗场景验证取消与确认逃跑，不干扰原有结算回归。
	var escape_scene: Control = load("res://scenes/Battle.tscn").instantiate()
	root.add_child(escape_scene)
	await process_frame
	check(escape_scene.escape_button.visible and escape_scene.escape_button.text == "逃跑", "战斗中显示逃跑入口")
	escape_scene.escape_button.emit_signal("pressed")
	check(escape_scene.escape_confirmation.visible, "逃跑需要二次确认")
	escape_scene.escape_confirmation.emit_signal("canceled")
	escape_scene.escape_confirmation.hide()
	check(battle.running and not battle.busy and escape_scene.escape_button.visible, "取消逃跑继续战斗")
	var escape_hero: BattleUnit = battle.allies[0]
	var escape_enemy: BattleUnit = battle.enemies[0]
	battle.queue.clear()
	battle.active_unit = escape_hero
	var escape_hp: int = escape_enemy.hp
	var escape_result: String = game.last_result
	var escape_exp: Dictionary = (data.save_data["exp"] as Dictionary).duplicate(true)
	battle.player_action("basic", battle.valid_targets(escape_hero, "basic")[0])
	check(battle.busy, "逃跑前存在等待演出的旧动作")
	var serial_before_escape: int = battle.battle_serial
	escape_scene.escape_confirmation.emit_signal("confirmed")
	check(not battle.running and not battle.busy and battle.battle_serial == serial_before_escape + 1 and battle.active_unit == null and battle.queue.is_empty() and battle.selected_target == null and escape_scene.pending_skill_id == "", "确认逃跑清理战斗与选招状态")
	for escape_frame in range(5):
		await process_frame
	check(escape_enemy.hp == escape_hp and game.last_result == escape_result and (data.save_data["exp"] as Dictionary) == escape_exp and (root.get_node("UIManager").popup == null or not root.get_node("UIManager").popup.visible), "逃跑中断旧协程、不发经验且不出现战败弹窗")
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/MainCity.tscn", "逃跑返回主城")
	escape_scene.queue_free()
	# 在真正的战斗场景中验证支援奥义仅治疗一次，不写入玩家存档。
	var original_skill: String = str(data.save_data["hero_skill"])
	data.save_data["hero_skill"] = "hero_mend"
	var support_scene: Control = load("res://scenes/Battle.tscn").instantiate()
	root.add_child(support_scene)
	# 在下一帧自动 AI 推进前提交主角行动，避免测试与排队行动竞争。
	var support_hero: BattleUnit = battle.allies[0]
	var support_friend: BattleUnit = battle.allies[1]
	support_friend.hp = maxi(1, support_friend.max_hp - 70)
	var support_before: int = support_friend.hp
	support_hero.energy = 100
	for ally: BattleUnit in battle.allies:
		if ally != support_friend:
			ally.hp = ally.max_hp
	battle.queue.clear()
	battle.active_unit = support_hero
	support_scene.refresh()
	battle.player_action("hero_mend", support_friend)
	for support_frame in range(180):
		await process_frame
		if not battle.busy:
			break
	check(support_friend.hp == mini(support_friend.max_hp, support_before + 36) and support_scene.last_hit_damage == -36, "真实场景中援护奥义按命中时点治疗一次")
	check(support_scene.target_label.text.contains("治疗") and support_hero.energy == 60, "援护目标、治疗反馈与能量消耗一致")
	battle.running = false
	support_scene.queue_free()
	data.save_data["hero_skill"] = "hero_cleanse"
	var cleanse_scene: Control = load("res://scenes/Battle.tscn").instantiate()
	root.add_child(cleanse_scene)
	var cleanse_hero: BattleUnit = battle.allies[0]
	var cleanse_friend: BattleUnit = battle.allies[1]
	cleanse_friend.add_effect("stun", 1)
	cleanse_friend.add_effect("damage_down", 2, 0.2)
	cleanse_friend.add_effect("damage_up", 2, 0.2)
	cleanse_friend.shields = 18
	cleanse_hero.energy = 100
	battle.queue.clear()
	battle.active_unit = cleanse_hero
	cleanse_scene.refresh()
	check(battle.can_cast(cleanse_hero, "hero_cleanse") and not cleanse_scene.ultimate_button.disabled, "真实战斗存在负面状态时净化按钮可用")
	cleanse_hero.energy = 39
	check(not battle.can_cast(cleanse_hero, "hero_cleanse"), "净化能量不足时不可释放")
	cleanse_hero.energy = 100
	cleanse_hero.cooldowns["hero_cleanse"] = 1
	check(not battle.can_cast(cleanse_hero, "hero_cleanse"), "净化冷却中不可释放")
	cleanse_hero.cooldowns.erase("hero_cleanse")
	battle.player_action("hero_cleanse", cleanse_friend)
	for cleanse_frame in range(180):
		await process_frame
		if not battle.busy:
			break
	check(not cleanse_friend.has_effect("stun") and not cleanse_friend.has_effect("damage_down") and battle.last_cleansed == ["stun", "damage_down"], "真实场景一次命中净化两项有效负面状态")
	check(cleanse_friend.has_effect("damage_up") and cleanse_friend.shields == 18 and cleanse_scene.target_label.text.contains("净化 2 项"), "净化反馈实际数量且保留增益护盾")
	check(cleanse_hero.energy == 60 and cleanse_hero.cooldowns.get("hero_cleanse", 0) == 3, "净化只扣一次能量且进入冷却")
	cleanse_scene.refresh()
	check(cleanse_scene.ultimate_reason(cleanse_hero, "hero_cleanse").contains("冷却中"), "净化冷却原因在战斗界面可见")
	cleanse_hero.cooldowns.erase("hero_cleanse")
	cleanse_scene.refresh()
	check(not battle.can_cast(cleanse_hero, "hero_cleanse") and cleanse_scene.ultimate_button.disabled and cleanse_scene.action_hint.text.contains("无可净化"), "无有效负面状态时禁用净化且提示原因")
	battle.running = false
	cleanse_scene.queue_free()
	data.save_data["hero_skill"] = original_skill
	await process_frame
	# Exercise the actual scene router, not only the rectangle and path data.
	var city_scene: PackedScene = load("res://scenes/MainCity.tscn")
	var city = city_scene.instantiate()
	root.add_child(city)
	current_scene = city
	await process_frame
	var outbound_gate: Rect2 = city.city_map.EXIT_REGIONS[0]["area"]
	city.player_foot = outbound_gate.get_center()
	city._process(0.0)
	for frame in range(4):
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/Outskirts.tscn", "踏入东侧传送点实际切换到云庭外缘")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/Outskirts.tscn":
		var outskirts = current_scene
		outskirts.player_foot = outskirts.RETURN.get_center()
		outskirts._process(0.0)
		for frame in range(4):
			await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://scenes/MainCity.tscn", "外缘左侧传送点实际切换回主城")
		if current_scene != null and current_scene.scene_file_path == "res://scenes/MainCity.tscn":
			check(current_scene.player_foot.distance_to(Vector2(1900, 729)) < 2.0, "返城到达点位于东侧道路")
	print("SMOKE RESULT: %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
