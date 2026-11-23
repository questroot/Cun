extends RefCounted
## Local icon atlas for the two sea-station consoles; not a global theme override.
const PLATES := preload("res://assets/ui/sea_station/field_instruments.svg")
const ORDER := [&"mask", &"tank", &"fins", &"net_expansion", &"capture_net", &"wrist", &"research", &"machine", &"build", &"pack"]

static func make(id: String, pixels: int = 48) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index := ORDER.find(StringName(id))
	if index >= 0:
		var atlas := AtlasTexture.new()
		atlas.atlas = PLATES
		var w := PLATES.get_width() / float(ORDER.size())
		atlas.region = Rect2(index * w, 0, w, PLATES.get_height())
		atlas.filter_clip = true
		icon.texture = atlas
	return icon
