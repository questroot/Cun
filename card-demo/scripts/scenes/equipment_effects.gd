extends Node
## Combat-only timers use active game time; secondary damage never triggers procs.
const Catalog = preload("res://scripts/scenes/equipment_catalog.gd")
const PixelVFX = preload("res://scripts/scenes/pixel_vfx.gd")
var gear
var game
var elapsed := 0.0
var heal_ready := 0.0
var heal_glow := 0.0
var echo_ready := 0.0
var shield_charge := 0.0
var shield_points := 0
var pending: Array[Dictionary] = []
var burns: Array[Dictionary] = []
var slowed: Array[Dictionary] = []
var visuals: Array[Dictionary] = []
var banner: Label
var notice := ""
var notice_left := 0.0

func _ready() -> void:
	gear = get_parent()
	game = gear.game
	game.world_canvas.draw.connect(draw_world)
	banner = Label.new()
	banner.position = Vector2(350, 191)
	banner.add_theme_font_size_override("font_size", 15)
	banner.add_theme_color_override("font_color", Color("#f0d28e"))
	game.add_child(banner)

func count(id: String) -> int:
	return int(Catalog.set_counts(gear.equipped).get(id, 0))

func weapon() -> String:
	return Catalog.Loot.base_item(gear.equipped.get("weapon", ""))

func cooldown_scale() -> float:
	return 0.85 if count("s1") >= 4 else 1.0

func attack_radius(kind: String, base: float) -> float:
	return base + (70.0 if kind == "j" and weapon() == "w05-bone-halberd" else 0.0) + (50.0 if kind == "l" and count("s2") >= 5 else 0.0)

func direct_damage(target: Dictionary, amount: int, kind: String) -> int:
	if kind == "l" and count("s2") >= 5:
		amount += 12
	if weapon() == "w02-ruinsplitter" and kind != "" and float(target.hp) / float(target.get("max_hp", 60)) <= 0.35:
		amount = ceili(amount * 1.6)
		pulse(target.position, "破墟斩", Color("#ffc391"))
	return amount

func incoming_damage(amount: int) -> int:
	var damage := maxi(1, amount - int(gear.bonuses().defense))
	if count("s3") >= 4:
		damage = maxi(1, ceili(damage * 0.8))
	if shield_points > 0 and count("s3") >= 5:
		var absorbed := mini(shield_points, damage)
		shield_points -= absorbed
		damage -= absorbed
		pulse(game.player_foot, "镜潮吸收 %d" % absorbed, Color("#9ae7ff"))
	return damage

func after_hit(target: Dictionary, kind: String) -> void:
	if kind == "" or game.health <= 0:
		return
	if count("s1") >= 5 and elapsed + 0.000001 >= heal_ready and game.health < 100:
		var healing := mini(4, 100 - int(game.health))
		game.health = mini(100, game.health + 4)
		heal_ready = elapsed + 1.0
		heal_glow = 0.8
		pulse(game.player_foot, "追归 +%d生命" % healing, Color("#9fe0ad"))
	if int(target.hp) <= 0:
		return
	if count("s2") >= 4:
		var found := false
		for burn: Dictionary in burns:
			if is_same(burn.target, target):
				# Refresh duration without postponing the next damage tick.
				burn.until = elapsed + 3.0
				found = true
		if not found:
			burns.append({"target": target, "next": elapsed + 1.0, "until": elapsed + 3.0})
	if kind == "j" and weapon() == "w01-ashen-echo" and elapsed + 0.000001 >= echo_ready:
		echo_ready = elapsed + 2.0
		pending.append({"kind": "echo", "target": target, "at": elapsed + 0.35})
	if kind == "j" and weapon() == "w05-bone-halberd":
		target["gear_slow_until"] = elapsed + 2.0
		var found := false
		for other: Dictionary in slowed:
			found = found or is_same(other, target)
		if not found:
			slowed.append(target)
		pulse(target.position, "骨枝缚根", Color("#a9db9a"))

func after_attack(kind: String, radius: float) -> void:
	if kind == "l" and weapon() == "w06-falling-crag":
		pending.append({"kind": "quake", "position": game.player_foot, "radius": radius, "at": elapsed + 0.45})

func enemy_speed_scale(target: Dictionary) -> float:
	return 0.65 if float(target.get("gear_slow_until", 0.0)) > elapsed else 1.0

func loadout_changed() -> void:
	clear_transients()
	game.projectiles.clear()
	if count("s3") < 5:
		shield_points = 0
		shield_charge = 0.0

func clear_transients() -> void:
	pending.clear()
	burns.clear()
	for target: Dictionary in slowed:
		target.erase("gear_slow_until")
	slowed.clear()
	visuals.clear()
	heal_glow = 0.0
	notice_left = 0.0
	if banner != null:
		banner.text = ""

func tick(delta: float) -> void:
	if delta <= 0 or game.finished or game._paused():
		return
	elapsed += delta
	if count("s3") >= 5:
		shield_charge += delta
		if shield_charge + 0.000001 >= 8.0:
			shield_charge = maxf(0.0, shield_charge - floor((shield_charge + 0.000001) / 8.0) * 8.0)
			shield_points = 18
			pulse(game.player_foot, "镜潮护盾 +18", Color("#9ae7ff"))
	for i in range(pending.size() - 1, -1, -1):
		var effect: Dictionary = pending[i]
		if elapsed + 0.000001 < float(effect.at):
			continue
		if effect.kind == "echo":
			secondary_damage(effect.target, 10, "余烬回响", Color("#f6b576"))
		else:
			pulse(effect.position, "坠岩余震", Color("#e8bf87"), effect.radius)
			for target: Dictionary in game.combat_targets():
				if Vector2(target.position).distance_to(effect.position) <= float(effect.radius):
					secondary_damage(target, 18, "余震 -18", Color("#e8bf87"))
		pending.remove_at(i)
	for i in range(burns.size() - 1, -1, -1):
		var burn: Dictionary = burns[i]
		# Catch up all due ticks, including the final one at exactly three seconds.
		while float(burn.next) <= elapsed + 0.00001 and float(burn.next) <= float(burn.until) + 0.00001 and int(burn.target.hp) > 0:
			secondary_damage(burn.target, 6, "烽炉灼烧 -6", Color("#ff9e67"))
			burn.next += 1.0
		if elapsed >= float(burn.until) or int(burn.target.hp) <= 0:
			burns.remove_at(i)
	for i in range(visuals.size() - 1, -1, -1):
		visuals[i].life -= delta
		if float(visuals[i].life) <= 0:
			visuals.remove_at(i)
	heal_glow = maxf(0.0, heal_glow - delta)
	notice_left = maxf(0.0, notice_left - delta)
	banner.text = notice if notice_left > 0 else ("镜潮护盾 %d / 18" % shield_points if count("s3") >= 5 else "")
	game._remove_dead()
	game.world_canvas.queue_redraw()

func secondary_damage(target: Dictionary, amount: int, label: String, color: Color) -> void:
	if int(target.hp) <= 0:
		return
	target.hp = maxi(0, int(target.hp) - amount)
	target.flash = 0.14
	pulse(target.position, label, color)

func pulse(point: Vector2, label: String, color: Color, radius: float = 38.0) -> void:
	visuals.append({"position": point, "text": label, "color": color, "radius": radius, "life": 0.75})
	if visuals.size() > 30:
		visuals.pop_front()
	notice = label
	notice_left = 1.5
	if banner != null:
		banner.text = label

func draw_world() -> void:
	# Status auras: shield while it holds, heal on trigger, burn and root on their targets.
	if shield_points > 0 and count("s3") >= 5:
		PixelVFX.draw(game.world_canvas, "status-shield", game.player_foot - Vector2(0, 34), elapsed, Vector2.ONE * 1.7, 0.0, Color(1, 1, 1, 0.85), true)
	if heal_glow > 0.0:
		PixelVFX.draw(game.world_canvas, "status-heal", game.player_foot - Vector2(0, 34), elapsed, Vector2.ONE * 1.7, 0.0, Color(1, 1, 1, minf(1.0, heal_glow / 0.8)), true)
	for burn: Dictionary in burns:
		if int(burn.target.hp) > 0:
			PixelVFX.draw(game.world_canvas, "status-burn", Vector2(burn.target.position) - Vector2(0, 24), elapsed, Vector2.ONE * 1.4, 0.0, Color(1, 1, 1, 0.85), true)
	for target: Dictionary in slowed:
		if float(target.get("gear_slow_until", 0.0)) > elapsed and int(target.hp) > 0:
			PixelVFX.draw(game.world_canvas, "status-freeze", Vector2(target.position) - Vector2(0, 24), elapsed, Vector2.ONE * 1.4, 0.0, Color(1, 1, 1, 0.85), true)
	for effect: Dictionary in visuals:
		var color: Color = effect.color
		color.a = clampf(float(effect.life) / 0.75, 0, 1)
		var radius := float(effect.radius) * (1.15 - float(effect.life) * 0.4)
		game.world_canvas.draw_arc(effect.position - Vector2(0, 22), radius, 0, TAU, 36, color, 3.0, true)
		game.world_canvas.draw_string(ThemeDB.fallback_font, effect.position + Vector2(-45, -85 - (0.75 - float(effect.life)) * 30), effect.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
