"""Post-process generated original image plates into runtime-friendly PNG atlases.
Build-only tool; the shipped game remains entirely GDScript/Godot.
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2] / "assets"


def source(folder: str) -> Image.Image:
    paths = [p for p in (ROOT / folder).glob("*.png") if p.name not in {"battle_garden.png", "city_garden.png", "unit_atlas.png", "fx_atlas.png", "ui_frame.png", "menu_garden.png"}]
    if not paths:
        raise FileNotFoundError(folder)
    return Image.open(sorted(paths)[0]).convert("RGB")


def remove_white(image: Image.Image, limit: int = 236) -> Image.Image:
    """Key near-white paper away, leaving soft antialiased edges."""
    rgb = image.convert("RGB")
    alpha = Image.new("L", rgb.size)
    rgb_pixels = rgb.load()
    mask = alpha.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = rgb_pixels[x, y]
            distance = max(0, 255 - min(r, g, b))
            mask[x, y] = max(0, min(255, int((distance - (255 - limit)) * 255 / 52)))
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha.filter(ImageFilter.GaussianBlur(0.55)))
    return rgba


battle = source("backgrounds")
battle.resize((1280, 720), Image.Resampling.LANCZOS).save(ROOT / "backgrounds" / "battle_garden.png", optimize=True)
city = battle.resize((1280, 720), Image.Resampling.LANCZOS)
city.save(ROOT / "backgrounds" / "city_garden.png", optimize=True)
menu = city.filter(ImageFilter.GaussianBlur(4))
menu.save(ROOT / "backgrounds" / "menu_garden.png", optimize=True)

characters = source("characters")
atlas = Image.new("RGBA", (768, 256))
for index in range(6):
    column = index % 3
    row = index // 3
    tile = characters.crop((column * 512 + 48, row * 512 + 32, column * 512 + 464, row * 512 + 496))
    tile = remove_white(tile)
    bounds = tile.getbbox()
    if bounds:
        tile = tile.crop(bounds)
    tile.thumbnail((112, 116), Image.Resampling.LANCZOS)
    atlas.alpha_composite(tile, (column * 128 + (128 - tile.width) // 2 + (row * 384), row * 128 + (128 - tile.height) // 2))
atlas.save(ROOT / "characters" / "unit_atlas.png", optimize=True)

fx_image = source("fx")
fx_atlas = Image.new("RGBA", (512, 512))
for i in range(4):
    col = i % 2
    row = i // 2
    fx = fx_image.crop((col * 512 + 16, row * 512 + 16, (col + 1) * 512 - 16, (row + 1) * 512 - 16))
    fx = remove_white(fx, limit=222)
    fx.thumbnail((242, 242), Image.Resampling.LANCZOS)
    fx_atlas.alpha_composite(fx, (col * 256 + (256 - fx.width) // 2, row * 256 + (256 - fx.height) // 2))
fx_atlas.save(ROOT / "fx" / "fx_atlas.png", optimize=True)

# The original UI plate is used directly by the main menu; do not crop it.
print("Built original PNG atlases and background plates")
