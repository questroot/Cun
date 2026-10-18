"""Remove the supplied portrait's magenta backdrop and align it to walk frames.

Run: python tools/prepare_hero_idle.py (requires Pillow; no game dependency).
The original RGB artwork is preserved in idle/source/.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'card-demo/assets/characters/hero/idle'


def build():
    source = Image.open(DEST / 'source/boss-03-celestial-executioner.png').convert('RGB')
    # Backdrop hue is around 333 degrees; the cape is red, gold and near-black.
    # Key all matching pixels, including enclosed gaps in the weapon and cape.
    hsv = source.convert('HSV')
    alpha = Image.new('L', source.size)
    alpha.putdata([0 if 225 <= h <= 245 and s >= 55 else 255
                   for h, s, v in hsv.get_flattened_data()])
    cutout = source.convert('RGBA')
    cutout.putalpha(alpha)
    bounds = cutout.getbbox()
    assert bounds is not None
    cutout = cutout.crop(bounds)
    height = 496
    width = round(cutout.width * height / cutout.height)
    assert width <= 432
    cutout = cutout.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (448, 512))
    canvas.paste(cutout, (224 - width // 2, 504 - height))
    output = DEST / 'hero_idle.png'
    canvas.save(output)
    print(f'{output.relative_to(ROOT)}: {canvas.size}; source bounds {bounds}')


if __name__ == '__main__':
    build()
