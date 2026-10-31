"""Build transparent Fudi fine-material runtime art from generated sources.

The generated source PNGs use flat green or magenta chroma backgrounds. This
script keys those backgrounds, removes the generated-corner watermark, trims
transparent padding, and writes stable, downscaled runtime images.

Run from any directory:
    python tools/prepare_fudi_fine_materials.py

Requires Pillow. The game itself does not require Python.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen/fudi-fine"
DEST = ROOT / "card-demo/assets/fudi/fine"

CHESTS = {
    "normal_closed": "21_chests_normal_closed.png",
    "normal_open": "22_chests_normal_open.png",
    "mutated_closed": "23_chests_mutated_closed.png",
    "mutated_guarding": "24_chests_mutated_guarding.png",
    "mutated_cleared": "25_chests_mutated_cleared.png",
    "mutated_open": "26_chests_mutated_open.png",
}

HERBS = {
    "bloodgrass": "27_herbs_bloodgrass.png",
    "dewleaf": "28_herbs_dewleaf.png",
    "berry": "29_herbs_berry.png",
    "wakeleaf": "30_herbs_wakeleaf.png",
    "restflower": "31_herbs_restflower.png",
    "herb": "32_herbs_herb.png",
    "warmflower": "33_herbs_warmflower.png",
    "moss": "34_herbs_moss.png",
    "mint": "35_herbs_mint.png",
    "rush": "36_herbs_rush.png",
    "bitterroot": "37_herbs_bitterroot.png",
}

PLANTS = {
    "bloodgrass": "38_plants_bloodgrass.png",
    "dewleaf": "39_plants_dewleaf.png",
    "berry": "40_plants_berry.png",
    "wakeleaf": "41_plants_wakeleaf.png",
    "restflower": "42_plants_restflower.png",
    "herb": "43_plants_herb.png",
    "warmflower": "44_plants_warmflower.png",
    "moss": "45_plants_moss.png",
    "mint": "46_plants_mint.png",
    "rush": "47_plants_rush.png",
}

CHEST_SIZE = 256
HERB_SIZE = 128
PLANT_CELL = 192
PLANT_FRAMES = 3
PADDING = 8


def _mask_from_channels(expression: Image.Image, threshold: int) -> Image.Image:
    return expression.point(lambda value: 255 if value > threshold else 0)


def _background_mask(image: Image.Image) -> Image.Image:
    """Return a mask for the saturated chroma background."""
    red, green, blue = image.split()
    border = Image.new("RGB", (image.width, image.height))
    border.paste(image.crop((0, 0, image.width, 8)), (0, 0))
    border.paste(image.crop((0, image.height - 8, image.width, image.height)), (0, image.height - 8))
    border.paste(image.crop((0, 0, 8, image.height)), (0, 0))
    border.paste(image.crop((image.width - 8, 0, image.width, image.height)), (image.width - 8, 0))
    mean = ImageStat.Stat(border).mean
    green_screen = mean[1] > mean[0] and mean[1] > mean[2]

    if green_screen:
        red_green = _mask_from_channels(ImageChops.subtract(green, red), 55)
        blue_green = _mask_from_channels(ImageChops.subtract(green, blue), 55)
        bright = _mask_from_channels(green, 140)
    else:
        red_green = _mask_from_channels(ImageChops.subtract(red, green), 55)
        blue_green = _mask_from_channels(ImageChops.subtract(blue, green), 55)
        red_bright = _mask_from_channels(red, 170)
        blue_bright = _mask_from_channels(blue, 150)
        green_dark = ImageChops.invert(_mask_from_channels(green, 170))
        bright = ImageChops.darker(ImageChops.darker(red_bright, blue_bright), green_dark)

    mask = ImageChops.darker(ImageChops.darker(red_green, blue_green), bright)
    # The generated watermark sits in the lower-right corner; artwork never
    # reaches this patch. Removing it here avoids re-introducing baked text.
    mask.paste(255, (image.width - 300, image.height - 100, image.width, image.height))
    # Expand the key by two source pixels so blended chroma fringes disappear.
    return mask.filter(ImageFilter.MaxFilter(5))


def keyed_rgba(path: Path) -> Image.Image:
    original = Image.open(path).convert("RGBA")
    existing_alpha = original.getchannel("A")
    if existing_alpha.getextrema()[0] < 250:
        # A few approved sources already carry a transparent background.
        # Keep their antialiased alpha instead of treating RGB black as art.
        alpha = existing_alpha.point(lambda value: 0 if value < 12 else value)
        alpha.paste(0, (original.width - 300, original.height - 100, original.width, original.height))
        result = original.copy()
        result.putalpha(alpha)
        return result
    source = original.convert("RGB")
    alpha = ImageChops.invert(_background_mask(source))
    result = source.convert("RGBA")
    result.putalpha(alpha)
    return result


def _fit(image: Image.Image, max_width: int, max_height: int) -> Image.Image:
    scale = min(max_width / image.width, max_height / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def _trim(image: Image.Image) -> Image.Image:
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("Chroma keying produced an empty image")
    return image.crop(bounds)


def build_chests() -> list[dict]:
    source_images: dict[str, Image.Image] = {}
    for asset_id, filename in CHESTS.items():
        source_images[asset_id] = _trim(keyed_rgba(SOURCE / filename))

    max_width = max(image.width for image in source_images.values())
    max_height = max(image.height for image in source_images.values())
    scale = min((CHEST_SIZE - PADDING * 2) / max_width, (CHEST_SIZE - PADDING * 2) / max_height)
    entries = []
    destination = DEST / "chests"
    destination.mkdir(parents=True, exist_ok=True)
    for asset_id, image in source_images.items():
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        scaled = image.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (CHEST_SIZE, CHEST_SIZE))
        x = (CHEST_SIZE - size[0]) // 2
        y = CHEST_SIZE - PADDING - size[1]
        canvas.alpha_composite(scaled, (x, y))
        output = destination / f"{asset_id}.png"
        canvas.save(output, optimize=True)
        entries.append({"id": asset_id, "path": output.relative_to(ROOT).as_posix(), "size": list(canvas.size), "source": CHESTS[asset_id]})
    return entries


def build_herbs() -> list[dict]:
    destination = DEST / "herbs"
    destination.mkdir(parents=True, exist_ok=True)
    entries = []
    for item_id, filename in HERBS.items():
        image = _trim(keyed_rgba(SOURCE / filename))
        image = _fit(image, HERB_SIZE - 12, HERB_SIZE - 12)
        canvas = Image.new("RGBA", (HERB_SIZE, HERB_SIZE))
        canvas.alpha_composite(image, ((HERB_SIZE - image.width) // 2, (HERB_SIZE - image.height) // 2))
        output = destination / f"{item_id}.png"
        canvas.save(output, optimize=True)
        entries.append({"id": item_id, "path": output.relative_to(ROOT).as_posix(), "size": list(canvas.size), "source": HERBS[item_id]})
    return entries


def build_plants() -> list[dict]:
    destination = DEST / "plants"
    destination.mkdir(parents=True, exist_ok=True)
    entries = []
    for item_id, filename in PLANTS.items():
        keyed = keyed_rgba(SOURCE / filename)
        cell_width = keyed.width // PLANT_FRAMES
        crops = []
        for frame in range(PLANT_FRAMES):
            cell = keyed.crop((frame * cell_width, 0, (frame + 1) * cell_width, keyed.height))
            crops.append(_trim(cell))

        max_width = max(image.width for image in crops)
        max_height = max(image.height for image in crops)
        scale = min((PLANT_CELL - PADDING * 2) / max_width, (PLANT_CELL - PADDING * 2) / max_height)
        atlas = Image.new("RGBA", (PLANT_CELL * PLANT_FRAMES, PLANT_CELL))
        for frame, image in enumerate(crops):
            size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
            scaled = image.resize(size, Image.Resampling.LANCZOS)
            x = frame * PLANT_CELL + (PLANT_CELL - size[0]) // 2
            y = PLANT_CELL - PADDING - size[1]
            atlas.alpha_composite(scaled, (x, y))
        output = destination / f"{item_id}.png"
        atlas.save(output, optimize=True)
        entries.append({"id": item_id, "path": output.relative_to(ROOT).as_posix(), "size": list(atlas.size), "frames": PLANT_FRAMES, "source": filename})
    return entries


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build() -> None:
    assets = {
        "chests": build_chests(),
        "herbs": build_herbs(),
        "plants": build_plants(),
    }
    for group in assets.values():
        for entry in group:
            entry["sha256"] = sha256(ROOT / entry["path"])
    manifest = {
        "version": 1,
        "style": "Fudi fine pixel art; chroma-keyed transparent runtime PNGs",
        "source_directory": "output/imagegen/fudi-fine",
        "assets": assets,
    }
    (DEST / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {sum(len(group) for group in assets.values())} runtime assets to {DEST.relative_to(ROOT)}")


if __name__ == "__main__":
    build()
