"""Build compact loot icons from supplied art without changing the originals.

Run with Python + Pillow. Equipment retains its painted dark background;
weapons retain their transparency. The game has no Python dependency.
"""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "card-demo/assets/items"


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    sources = sorted((ROOT / "美术/物品").rglob("*.png"))
    sources += sorted((ROOT / "美术/武器").glob("*.png"))
    for source in sources:
        art = Image.open(source).convert("RGBA")
        art = ImageOps.contain(art, (152, 152), Image.Resampling.LANCZOS)
        icon = Image.new("RGBA", (160, 160))
        icon.paste(art, ((160 - art.width) // 2, (160 - art.height) // 2))
        icon.save(DEST / source.name)
    print(f"Built {len(sources)} loot icons; original artwork preserved.")


if __name__ == "__main__":
    build()
