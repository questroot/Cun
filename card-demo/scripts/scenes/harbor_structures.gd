extends Node2D
## The plate's bottom edge sits on its original playable footprint. Sea-space is
## stretched by the map, so draw the elevation in screen units, not tile units.
const DECK = preload("res://assets/buildings/harbor/deck_buildings.svg")
const STATIONS = preload("res://assets/buildings/harbor/station_buildings.svg")
const ORDER := ["core", "collector", "workshop", "tide", "filter", "research", "machine", "dive_workshop"]
const TITLES := ["航站核心", "集水站", "简易工坊", "潮测台", "过滤架", "研究台", "打捞器", "潜水工坊"]
var sea
var foreground := false
var entries: Array = []
var masks := {}

func rebuild() -> void:
	entries.clear()
	if sea.at_salt or sea.at_wreck: return
	for i in mini(sea.raft_tiles,sea.MAX_TILES):
		var k := ORDER.find(sea.building_slots[i])
		if k < 0: continue
		var p := Vector2(360 + (i % 4) * 81, 374 + floori(i / 4.0) * 78)
		_add(k,p+Vector2(36,53),Vector2(116,135),true)
	_add(5,Vector2(297,310),Vector2(128,115),sea.technology.state.research_built)
	_add(6,Vector2(667,310),Vector2(128,115),sea.technology.state.machine_built)
	if sea.dive_workshop_unlocked: _add(7,Vector2(159,428),Vector2(134,121),sea.dive_workshop_built)
	entries.sort_custom(func(a,b): return a.foot.y < b.foot.y)

func _add(k:int,foot:Vector2,extent:Vector2,built:bool) -> void:
	var p:Vector2 = sea.world_to_screen(foot)
	var base := 105.0/112 if k<5 else 101.0/108
	if k in [5,6]: extent *= minf(1.0,(p.y-sea.SEA_VIEW.position.y-2)/(base*extent.y))
	entries.append({"k":k,"built":built,"foot":p,"rect":Rect2(p-Vector2(extent.x*0.5,extent.y*base),extent)})

func _source(k:int) -> Rect2:
	var tex: Texture2D = DECK if k<5 else STATIONS
	var w := tex.get_width()/float(5 if k<5 else 3)
	return Rect2((k if k<5 else k-5)*w,0,w,tex.get_height())

func pick(at:Vector2) -> String:
	# Transparent roof corners aren't extra buttons. Fall back to the old tile
	# hit regions in the caller so vacant plots still behave just as before.
	for j in range(entries.size()-1,-1,-1):
		var e: Dictionary = entries[j]
		var r:Rect2=e.rect
		if not e.built or not r.has_point(at): continue
		var k:int=e.k
		var tex: Texture2D=DECK if k<5 else STATIONS
		if not masks.has(tex):
			var mask := BitMap.new()
			var image := tex.get_image()
			if image == null or image.is_empty(): continue
			mask.create_from_image_alpha(image,0.18)
			masks[tex]=mask
		var src:=_source(k)
		var uv:=Vector2i(src.position+(at-r.position)/r.size*src.size)
		if masks[tex].get_bitv(uv): return ORDER[k]
	return ""

func _draw() -> void:
	if sea == null or not is_instance_valid(sea.model): return
	for e in entries:
		var p:Vector2=e.foot
		if (p.y > sea.model.position.y) != foreground: continue
		var k:int=e.k
		if e.built:
			var r:Rect2=e.rect
			var alpha:=0.76 if foreground and r.has_point(sea.model.position-Vector2(0,35)) else 1.0
			draw_texture_rect_region(DECK if k<5 else STATIONS,r,_source(k),Color(1,1,1,alpha))
		if k>=5 or k==0:
			var caption:String=TITLES[k]
			caption += (" %d" % sea.core_level) if k==0 else ("" if e.built else " · 待建")
			var width:=ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var pos:=p+Vector2(-width*0.5,16)
			draw_rect(Rect2(pos-Vector2(5,14),Vector2(width+10,19)),Color("#132c34df"))
			draw_string(ThemeDB.fallback_font,pos,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#f1dfb6"))
