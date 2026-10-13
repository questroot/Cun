"""Convert approved concept imagery into runtime character and stage assets; no previews."""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
TEMP = Path('C:/Users/Administrator/AppData/Local/Temp')
SHEET = TEMP / 'Original_production_game_chara_2026-10-03T17-40-42.png'
STAGES = {
    'stage_1': 'Wide_horizontal_16_9_game_comb_2026-10-03T17-41-03.png',
    'stage_2': 'Wide_horizontal_16_9_game_comb_2026-10-03T17-41-25.png',
    'stage_3': 'Wide_horizontal_16_9_original__2026-10-03T17-41-50.png',
}
SHEET_IDS = ('hero', 'sprout', 'ember', 'pebble', 'mist', 'guide')
char_dir = ROOT / 'assets' / 'characters'
bg_dir = ROOT / 'assets' / 'backgrounds'
source = Image.open(SHEET).convert('RGB')
assert source.size == (1536, 1024)

for i, name in enumerate(SHEET_IDS):
    col, row = i % 3, i // 3
    # Center crop avoids mixing neighboring character silhouettes.
    img = source.crop((col * 512 + 32, row * 512 + 25, (col + 1) * 512 - 32, (row + 1) * 512 - 20)).convert('RGBA')
    rgb = img.convert('RGB')
    pix = rgb.load()
    alpha = Image.new('L', img.size, 0)
    a = alpha.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = pix[x, y]
            # Remove nearly white backing and preserve colored antialiasing.
            delta = 255 - min(r, g, b)
            a[x, y] = max(0, min(255, int((delta - 12) * 255 / 60)))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.35))
    mask = alpha.point(lambda value: 255 if value > 30 else 0)
    box = mask.getbbox()
    assert box is not None, name
    img.putalpha(alpha)
    img = img.crop(box)
    img.thumbnail((190, 220), Image.Resampling.LANCZOS)
    tile = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    tile.alpha_composite(img, ((256 - img.width) // 2, 244 - img.height))
    tile.save(char_dir / ('pet_' + name + '.png'), optimize=True)
    print('character', name, 'content', box, 'output', img.size)

# Render enemies as deliberately distinct marked variants, not aliases of allies.
from PIL import ImageDraw
for base, name in [('sprout', 'enemy_seed'), ('ember', 'enemy_flame'), ('pebble', 'enemy_stone'), ('mist', 'enemy_wisp')]:
    tile = Image.open(char_dir / ('pet_' + base + '.png')).convert('RGBA')
    halo = Image.new('RGBA', tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(halo)
    draw.ellipse((30, 20, 226, 244), outline=(144, 88, 95, 190), width=5)
    draw.ellipse((204, 31, 229, 56), fill=(255, 224, 163, 235))
    halo.alpha_composite(tile)
    halo.save(char_dir / ('pet_' + name + '.png'), optimize=True)

for name, filename in STAGES.items():
    src = Image.open(TEMP / filename).convert('RGB')
    stage = ImageOps.fit(src, (1280, 720), Image.Resampling.LANCZOS, centering=(0.5, 0.54))
    stage = ImageEnhance.Contrast(stage).enhance(0.95)
    stage.save(bg_dir / ('battle_' + name + '.png'), optimize=True)
    print('background', name, stage.size)

# Interface backdrop is a softened, darker crop of the same city world; no independent incompatible art.
city = Image.open(bg_dir / 'city_pet_panorama.png').convert('RGB')
interface = ImageOps.fit(city, (1280, 720), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(7))
interface = ImageEnhance.Color(interface).enhance(0.76)
interface.save(bg_dir / 'menu_pet_garden.png', optimize=True)
print('interface', interface.size)

# Four transparent spell glyphs share the same jade, pale gold and warm coral palette.
import math
from PIL import ImageDraw
sheet = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
for index in range(4):
    cell = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(cell)
    colors = [(117, 213, 180), (255, 207, 136), (149, 221, 225), (245, 174, 123)]
    c = colors[index]
    for radius in (90, 74, 55):
        d.arc((128-radius, 128-radius, 128+radius, 128+radius), 20, 325, fill=(*c, 150 if radius == 90 else 220), width=6)
    if index == 2:
        d.polygon([(128, 58), (181, 87), (169, 157), (128, 197), (87, 157), (75, 87)], fill=(*c, 128), outline=(255, 234, 179, 230), width=6)
    else:
        for ray in range(8):
            theta = ray * math.tau / 8 + index * 0.21
            x, y = math.cos(theta), math.sin(theta)
            d.line((128+x*23, 128+y*23, 128+x*77, 128+y*77), fill=(*c, 215), width=8 if index == 1 else 5)
            d.ellipse((128+x*80-5, 128+y*80-5, 128+x*80+5, 128+y*80+5), fill=(255, 239, 199, 238))
        d.ellipse((101, 101, 155, 155), fill=(*c, 180))
    sheet.alpha_composite(cell, ((index % 2) * 256, (index // 2) * 256))
sheet.save(ROOT / 'assets/fx/fx_pet_atlas.png', optimize=True)
print('effects', sheet.size)
