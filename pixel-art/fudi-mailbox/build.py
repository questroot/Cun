"""Draw the post-office landmark at its native 48×64 pixel size."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path.home() / ".codex/skills/pixel-art-studio/scripts"))
from pixelstudio import Sprite

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "card-demo/assets/fudi/mailbox"
PALETTES = {
    "gray": ("#272727", "#494949", "#676767", "#8b8b8b", "#b0b0b0", "#dedede"),
    "color": ("#252430", "#4b333e", "#793f47", "#b15b50", "#d58065", "#f2cc91"),
}


def mailbox(palette):
    s = Sprite(48, 64, palette=list(palette))
    ink, shade, side, front, light, brass = palette
    s.polygon([(12, 56), (17, 53), (32, 53), (38, 55), (38, 59),
               (34, 61), (14, 61), (10, 59)], ink)
    s.polygon([(14, 56), (20, 54), (32, 54), (36, 56), (32, 58),
               (15, 58)], side)
    s.rect(18, 38, 28, 56, ink)
    s.rect(19, 39, 24, 55, shade)
    s.line(20, 42, 20, 54, light)
    s.rect(25, 40, 27, 55, side)
    s.line(16, 58, 30, 58, shade)

    s.polygon([(7, 17), (9, 13), (13, 9), (18, 7), (30, 5), (35, 6),
               (39, 9), (42, 14), (42, 33), (40, 36), (31, 42),
               (8, 42), (6, 39), (6, 19)], ink)
    s.polygon([(30, 14), (39, 12), (41, 15), (41, 32), (39, 35),
               (31, 40), (29, 36)], shade)
    s.polygon([(33, 16), (39, 14), (40, 16), (40, 28), (38, 32),
               (33, 35)], side)
    s.polygon([(9, 18), (12, 14), (16, 12), (25, 12), (29, 15),
               (31, 20), (31, 38), (29, 40), (9, 40), (8, 37), (8, 20)], front)
    s.polygon([(8, 19), (12, 13), (16, 10), (30, 7), (35, 7), (39, 10),
               (40, 13), (31, 17), (29, 14), (26, 12), (17, 12), (13, 15),
               (11, 19)], light)
    s.line(18, 9, 31, 6, brass)
    s.line(30, 18, 30, 36, side)
    s.line(9, 24, 9, 36, light)
    s.line(10, 38, 28, 38, side)
    s.line(13, 39, 26, 39, shade)
    s.rect(12, 19, 28, 24, side)
    s.rect(13, 20, 27, 22, ink)
    s.line(14, 23, 26, 23, brass)
    s.rect(15, 28, 25, 35, side)
    s.rect(16, 28, 24, 33, brass)
    s.line(16, 29, 20, 31, side)
    s.line(20, 31, 24, 29, side)
    s.px(37, 24, light)
    s.px(37, 28, front)
    return s


if __name__ == "__main__":
    TARGET.mkdir(parents=True, exist_ok=True)
    for state, palette in PALETTES.items():
        sprite = mailbox(palette)
        sprite.save_png(TARGET / f"mailbox-{state}.png")
        sprite.save_png(ROOT / ".local" / f"fudi-mailbox-{state}-4x.png", scale=4)
        print(state, sprite.used_colors())
