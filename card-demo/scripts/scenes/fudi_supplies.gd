extends Node
const Items = preload("res://scripts/scenes/exploration_catalog.gd")
var game

func _ready() -> void:
	game = get_parent()

func can_craft(id: String) -> bool:
	for material: String in Items.SUPPLIES[id].cost:
		if game.inventory[material] < Items.SUPPLIES[id].cost[material]: return false
	return true

func craft(id: String) -> bool:
	if not game.journal.visible or game.finished or not can_craft(id): return false
	for material: String in Items.SUPPLIES[id].cost:
		game.inventory[material] -= Items.SUPPLIES[id].cost[material]
	game.inventory[id] = int(game.inventory.get(id, 0)) + 1
	changed()
	return true

func use(id: String) -> bool:
	if not game.journal.visible or not can_use(id): return false
	consume(id)
	return true

func can_use(id: String) -> bool:
	return not game.finished and int(game.inventory.get(id, 0)) > 0 and needs_recovery(Items.SUPPLIES[id].resource)

func needs_recovery(resource: String) -> bool:
	return game.health < 100 if resource == "health" else game.mana < game.MAX_MANA

func quick_count(resource: String) -> int:
	var total := 0
	for id: String in Items.SUPPLIES:
		if Items.SUPPLIES[id].resource == resource:
			total += int(game.inventory.get(id, 0))
	return total

func use_quick(resource: String) -> void:
	if game._paused() or game.finished or not needs_recovery(resource): return
	for id: String in Items.SUPPLIES:
		if Items.SUPPLIES[id].resource == resource and int(game.inventory.get(id, 0)) > 0:
			consume(id)
			return

func consume(id: String) -> void:
	var recipe: Dictionary = Items.SUPPLIES[id]
	game.inventory[id] -= 1
	if recipe.resource == "health":
		game.health = mini(100, game.health + recipe.restore)
	else:
		game.mana = minf(game.MAX_MANA, game.mana + recipe.restore)
	changed()

func can_repair() -> bool:
	return game.states[game.region].rested and game.player_foot.distance_to(game.Maps.MAPS[game.region].spawn * game.Maps.MAPS[game.region].size) <= 95 and game.inventory.wood >= 3 and game.inventory.resin >= 1

func repair() -> bool:
	if not game.journal.visible or game.finished or not can_repair(): return false
	game.inventory.wood -= 3
	game.inventory.resin -= 1
	game.states[game.region].rested = false
	changed()
	return true

func changed() -> void:
	game.sound_requested.emit("discovery")
	game.persistence.request_save()
	game._refresh_ui()
	game.book.refresh()
