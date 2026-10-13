class_name SpriteAtlas
extends RefCounted
## All scene and battle portraits use the same pet asset family; skills use a matching atlas.
const FX_ART := preload("res://assets/fx/fx_pet_atlas.png")
const PET_ART := {
	"hero": preload("res://assets/characters/pet_hero.png"),
	"sprout": preload("res://assets/characters/pet_sprout.png"),
	"ember": preload("res://assets/characters/pet_ember.png"),
	"pebble": preload("res://assets/characters/pet_pebble.png"),
	"metal": preload("res://assets/characters/pet_metal.png"),
	"mist": preload("res://assets/characters/pet_mist.png"),
	"enemy_seed": preload("res://assets/characters/pet_enemy_seed.png"),
	"enemy_flame": preload("res://assets/characters/pet_enemy_flame.png"),
	"enemy_stone": preload("res://assets/characters/pet_enemy_stone.png"),
	"enemy_wisp": preload("res://assets/characters/pet_enemy_wisp.png")
}

static func pet_texture(id: String) -> Texture2D:
	var configured: String = ""
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var manager: Node = tree.root.get_node_or_null("DataManager")
		if manager != null:
			var unit: Dictionary = manager.get_entry("units", id)
			configured = str(unit.get("portrait", ""))
	if configured != "" and ResourceLoader.exists(configured):
		return load(configured) as Texture2D
	return PET_ART.get(id) as Texture2D
static var fx_sheet: Texture2D

static func texture_for(id: String) -> Texture2D:
	return pet_texture(id)

static func effect_for(index: int) -> AtlasTexture:
	if fx_sheet == null:
		fx_sheet = FX_ART
	var tile := AtlasTexture.new()
	tile.atlas = fx_sheet
	tile.region = Rect2((index % 2) * 256, int(index / 2) * 256, 256, 256)
	return tile

