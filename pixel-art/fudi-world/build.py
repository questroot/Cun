"""Draw the complete Fudi pixel set locally. Three assets per batch; no network.

Requires Pillow and the pixel-art-studio skill's scripts/pixelstudio.py.
Master PNGs are 1x. Previews use integer nearest-neighbor enlargement only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import sys

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "card-demo/assets/pixel/fudi"
WORK = Path(__file__).resolve().parent
STUDIO = Path(os.environ.get("PIXEL_STUDIO_PATH", str(Path.home() / ".codex/skills/pixel-art-studio/scripts")))
sys.path.insert(0, str(STUDIO))
from pixelstudio import Sprite  # noqa: E402

# Shared cool shadows / warm highlights. No automatic antialiasing or alpha gradients.
PAL = ["#17252d", "#283a43", "#40535a", "#657477", "#9caaa1", "#d7d9bb",
       "#49372e", "#71503a", "#a17249", "#c89c64", "#ebcf91",
       "#203d3b", "#2f5948", "#50805a", "#7da366", "#b6c984",
       "#214a58", "#367487", "#61acb3", "#ade0d1",
       "#393754", "#62547d", "#9476aa", "#d3afcb",
       "#653b40", "#ad5552", "#de8970", "#bc7a3d", "#efa94f", "#ffe1a0",
       "#7e9da9", "#e9f2dd"]
D, INK, STONE, STONE_L, SILVER, CREAM = PAL[:6]
WOOD_D, WOOD, WOOD_L, TAN, GOLD = PAL[6:11]
GREEN_D, GREEN_S, GREEN, LEAF, LEAF_L = PAL[11:16]
WATER_D, TEAL, AQUA, ICE = PAL[16:20]
PURPLE_D, PURPLE, LILAC, PINK = PAL[20:24]
RED_D, RED, CORAL, BRONZE, FIRE, GLOW, FROST, WHITE = PAL[24:]
REGIONS = [
    ("grove", "青岚灶街", "青岚百味大食堂", "hall", GREEN_S, TEAL, WOOD_L),
    ("post", "旧城邮驿", "旧城总邮驿", "post", STONE, STONE, TAN),
    ("quarry", "赤岩钟楼", "赤岩铸造大殿", "forge", WOOD_D, RED_D, WOOD_L),
    ("ruins", "灵泉记录站", "灵泉水镜圣所", "sanctum", WATER_D, TEAL, FROST),
    ("refuge", "归航救援营", "归航救援总厅", "clinic", INK, GREEN_S, SILVER),
    ("wetland", "雨灯湿地", "雨灯临水长榭", "dock", GREEN_D, TEAL, TAN),
    ("causeway", "断桥驿路", "断桥守望关楼", "gate", STONE, STONE, SILVER),
    ("kilnwood", "松烟炭林", "松烟封火大窑", "kiln", WOOD_D, WOOD, BRONZE),
    ("archive", "镜沙档案馆", "镜沙星穹档案馆", "archive", PURPLE_D, PURPLE, LILAC),
    ("snowridge", "霜脊瞭望岭", "霜脊观星高台", "observatory", FROST, TEAL, SILVER),
]
HERBS = [("bloodgrass", "止血草"), ("dewleaf", "青露叶"), ("berry", "甘露莓"),
         ("wakeleaf", "醒神叶"), ("restflower", "安息花"), ("herb", "灵草"),
         ("warmflower", "暖绒花"), ("moss", "石缝苔"), ("mint", "清凉薄荷"),
         ("rush", "灯芯草"), ("bitterroot", "苦心根")]
SCENERY = [("camphor", "樟树"), ("pine", "松树"), ("charred_pine", "炭松"),
           ("snow_pine", "雪松"), ("reeds", "芦苇丛"), ("lotus", "荷叶莲花"), ("shrub", "野莓灌木")]
CHESTS = [("normal_closed", "普通宝箱·关闭"), ("normal_open", "普通宝箱·已领取"),
          ("mutated_closed", "异变宝箱·封印"), ("mutated_guarding", "异变宝箱·守卫中"),
          ("mutated_cleared", "异变宝箱·可领奖"), ("mutated_open", "异变宝箱·已领取")]
ASSETS = []
for row in REGIONS:
    ASSETS.append({"category": "maps", "id": row[0], "name": row[1] + "地形图集", "size": [128, 128], "budget": 20})
for row in REGIONS:
    ASSETS.append({"category": "buildings", "id": row[0], "name": row[2], "size": [320, 192], "budget": 28})
for key, name in CHESTS:
    ASSETS.append({"category": "chests", "id": key, "name": name, "size": [48, 48], "budget": 16})
for key, name in HERBS:
    ASSETS.append({"category": "herbs", "id": key, "name": name, "size": [32, 32], "budget": 16})
for key, name in HERBS[:-1]:
    ASSETS.append({"category": "plants", "id": key, "name": name + "·萌芽/生长/成熟", "size": [96, 48], "budget": 20})
for key, name in SCENERY:
    ASSETS.append({"category": "scenery", "id": key, "name": name, "size": [64, 96], "budget": 20})
assert len(ASSETS) == 54


def box(s, x, y, w, h, c):
    if w > 0 and h > 0:
        s.rect(int(x), int(y), int(x + w - 1), int(y + h - 1), c)


def poly(s, points, c):
    s.polygon([(int(x), int(y)) for x, y in points], c)


def leaf(s, x, y, direction, size=8, light=LEAF, shade=GREEN_S):
    dx = direction * size
    poly(s, [(x, y), (x + dx, y - size // 2), (x + dx, y - size), (x + dx // 2, y - size + 1)], GREEN_D)
    poly(s, [(x, y - 1), (x + dx - direction, y - size + 1), (x + dx // 2, y - size + 2)], light)
    s.line(x, y, x + dx - direction, y - size + 2, shade)


def flower(s, x, y, color=LILAC, center=GOLD, r=4):
    # Five clustered petals with a deliberately brighter top-left lobe.
    for dx, dy in [(-r, 0), (-r // 2, -r), (r // 2 + 1, -r), (r, 0), (0, r)]:
        s.ellipse(x + dx - 2, y + dy - 2, x + dx + 2, y + dy + 2, PURPLE_D if color == LILAC else RED_D)
        box(s, x + dx - 1, y + dy - 1, 3, 3, color)
    box(s, x - 1, y - 1, 3, 3, center)
    s.px(x - 1, y - 2, WHITE)


def sparkle(s, x, y, c=GLOW):
    s.line(x - 2, y, x + 2, y, c)
    s.line(x, y - 2, x, y + 2, c)


def tiles(s, row, refined):
    key, _, _, _, ground, roof, wall = row
    rng = random.Random(928 + [r[0] for r in REGIONS].index(key))
    for ty in range(4):
        for tx in range(4):
            x, y = tx * 32, ty * 32
            base = [ground, STONE if key in ("ruins", "archive", "causeway", "snowridge") else WOOD,
                    WATER_D if key in ("wetland", "causeway") else wall, WATER_D][ty]
            box(s, x, y, 32, 32, base)
            if ty == 0:
                # Quiet two-pixel edge ring guarantees opposite edges match exactly.
                for n in range(12 if refined else 6):
                    px, py = x + rng.randrange(3, 27), y + rng.randrange(3, 28)
                    color = (SILVER if key == "snowridge" else
                             GREEN if key in ("grove", "wetland", "refuge") else
                             PURPLE if key == "archive" else STONE_L if key in ("post", "causeway", "ruins") else WOOD)
                    box(s, px, py, 3, 1, color)
                    if n % 3 == 0:
                        s.line(px + 1, py, px + 2, py - 2, color)
                if key == "snowridge":
                    poly(s, [(x+8,y+11),(x+17,y+8),(x+23,y+13),(x+21,y+19),(x+12,y+19)], CREAM)
                if key == "wetland":
                    s.line(x+8,y+18,x+19,y+18,TEAL)
            elif ty == 1:
                # Four seamless cobble/earth variants. No borders on the outermost pixels.
                for by in range(3, 30, 8):
                    offset = (by // 8 + tx) % 2 * 5
                    for bx in range(3, 27, 11):
                        xx = x + (bx + offset) % 25 + 1
                        box(s, xx, y+by, min(6, x+29-xx), 4, STONE_L if base == STONE else WOOD_L)
                        if refined:
                            box(s, xx, y+by+4, min(6, x+29-xx), 1, INK if base == STONE else WOOD_D)
            elif ty == 2:
                if key in ("wetland", "causeway"):
                    for n in range(3):
                        yy = y+7+n*8
                        s.line(x+5+n*3, yy, x+17+n*3, yy, TEAL)
                        if refined:
                            s.line(x+7+n*3,yy-1,x+12+n*3,yy-1,AQUA)
                elif key in ("grove", "kilnwood"):
                    for xx in range(x+5,x+29,7):
                        box(s,xx,y+3,2,26,WOOD_D)
                        for yy in range(y+8,y+28,8):
                            leaf(s,xx+1,yy,1,4,GREEN if key=="grove" else LEAF,GREEN_S)
                else:
                    for yy in range(y+2,y+30,8):
                        s.line(x+2,yy,x+29,yy,STONE if key=="snowridge" else WOOD_D)
                        xx=x+5+((yy//8+tx)%2)*9
                        s.line(xx,yy,xx,yy+7,STONE if key=="snowridge" else WOOD_D)
                    if refined:
                        box(s,x+3,y+3,15,2,CREAM if key=="snowridge" else TAN)
            else:
                for n in range(5 if refined else 3):
                    px=x+rng.randrange(4,24);py=y+rng.randrange(4,28)
                    s.line(px,py,px+5,py,TEAL)
                    if n%2==0: s.line(px+1,py-1,px+3,py-1,AQUA)
    # Reset the quiet perimeter after every interior motif, including overhanging leaves.
    for ty in range(4):
        base = [ground, STONE if key in ("ruins", "archive", "causeway", "snowridge") else WOOD,
                WATER_D if key in ("wetland", "causeway") else wall, WATER_D][ty]
        for tx in range(4):
            x,y=tx*32,ty*32
            box(s,x,y,32,2,base);box(s,x,y+30,32,2,base)
            box(s,x,y,2,32,base);box(s,x+30,y,2,32,base)


def roof_plane(s, x, y, w, h, color, refined):
    outline=[(x-3,y),(x+10,y-5),(x+w//4,y-h+8),(x+w//2,y-h),
             (x+w*3//4,y-h+8),(x+w-10,y-5),(x+w+3,y),(x+w,y+6),(x,y+6)]
    poly(s, outline, D)
    poly(s, [(x,y),(x+13,y-4),(x+w//4,y-h+10),(x+w//2,y-h+3),
             (x+w*3//4,y-h+10),(x+w-13,y-4),(x+w,y)], color)
    poly(s, [(x+13,y-4),(x+w//4,y-h+10),(x+w//2,y-h+3),(x+w//2,y-3)], TEAL if color==GREEN_S else STONE_L if color==STONE else PURPLE if color==PURPLE else WOOD_L if color==WOOD else color)
    if refined:
        for n in range(1, 22):
            xx=x+n*w//22
            start_y=y-h+3+abs(xx-(x+w//2))*h//(w//2)
            s.line(xx, max(y-h+5,start_y), xx, y-2, INK if color in (STONE,TEAL,GREEN_S) else PURPLE_D if color==PURPLE else WOOD_D)
        for yy in range(y-h+12,y,9):
            ww=int((yy-(y-h))*w/h)
            s.line(x+w//2-ww//2,yy,x+w//2+ww//2,yy,color)
    box(s,x-3,y+1,w+6,3,TAN)
    box(s,x-5,y+4,w+10,2,WOOD)
    box(s,x+4,y+2,w//2,1,GOLD)
    # Upturned eaves and ceramic end caps.
    for xx,dr in [(x-5,-1),(x+w+5,1)]:
        box(s,xx-2,y-2,5,4,GOLD)
        s.line(xx,y,xx+dr*4,y-5,TAN)


def building(s, row, refined):
    key, _, _, kind, _, roof, wall = row
    # Common 2:1 game scale: 640px facade, 140px collision depth.
    s.ellipse(22,168,305,187,INK)
    box(s,33,151,254,20,D)
    box(s,30,150,254,15,STONE)
    box(s,31,150,251,3,SILVER)
    for n in range(4):
        box(s,118-n*6,162+n*5,84+n*12,6,STONE)
        box(s,118-n*6,162+n*5,84+n*12,1,SILVER)
    box(s,41,86,238,65,WOOD_D)
    box(s,43,87,232,60,wall)
    box(s,43,132,232,16,WOOD)
    box(s,52,94,213,3,TAN)
    if refined:
        for yy in range(99,145,12):
            for xx in range(48+(yy//12%2)*9,271,20):
                box(s,xx,yy,10,1,WOOD if wall!=SILVER else STONE_L)
    # Differently sized central doors keep each function legible.
    for xx in [57,88,119,195,226,257]:
        box(s,xx,103,17,26,D)
        box(s,xx+2,105,13,20,AQUA if kind in ("archive","sanctum","observatory") else GOLD)
        box(s,xx+3,107,10,17,TEAL if kind in ("archive","sanctum","observatory") else WOOD)
        s.line(xx+8,106,xx+8,124,TAN)
        s.line(xx+2,116,xx+14,116,TAN)
    box(s,139,100,42,51,D)
    poly(s,[(139,103),(145,95),(175,95),(181,103)],D)
    box(s,143,102,34,48,WOOD_D)
    s.line(160,102,160,148,TAN)
    for xx in (153,166): box(s,xx,126,2,3,GOLD)
    for xx in (48,81,114,187,220,253,271):
        box(s,xx,91,5,62,WOOD_D)
        box(s,xx,93,2,58,TAN)
        box(s,xx-2,149,9,4,STONE_L)
    roof_plane(s,31,97,258,46,roof,refined)
    if kind not in ("dock", "kiln"):
        roof_plane(s,91,58,138,30,roof,refined)
    # Functional silhouettes: each building has its own silhouette and fittings.
    if kind in ("post","gate"):
        for xx in (43,247):
            box(s,xx,47,30,58,WOOD_D)
            box(s,xx+2,47,26,54,wall)
            box(s,xx+9,58,12,16,D)
            box(s,xx+11,60,8,12,GOLD)
            roof_plane(s,xx-6,49,42,25,roof,refined)
        box(s,150,17,2,22,WOOD)
        poly(s,[(152,18),(176,21),(170,26),(152,26)],RED if kind=="post" else AQUA)
        if kind=="post":
            box(s,246,132,17,22,RED_D);box(s,248,134,13,16,RED)
            box(s,250,138,9,2,D)
            box(s,144,68,32,14,CREAM)
            s.line(144,68,160,77,WOOD);s.line(176,68,160,77,WOOD)
        else:
            for xx in range(142,180,6): box(s,xx,104,2,42,STONE)
            box(s,138,103,44,4,SILVER)
    elif kind in ("forge","kiln"):
        for xx,yy in ((62,31),(236,19)):
            box(s,xx,yy,16,61,D);box(s,xx+2,yy+2,12,57,WOOD)
            box(s,xx-3,yy-3,22,7,STONE_L)
            # Smoke is clustered and uses solid palette values.
            for cx,cy,rr in ((xx+7,yy-10,6),(xx+12,yy-19,8),(xx+5,yy-30,9)):
                if cy-rr>1: s.ellipse(cx-rr,cy-rr,cx+rr,cy+rr,STONE)
        if kind=="kiln":
            s.ellipse(108,55,211,135,WOOD_D)
            s.ellipse(112,55,205,128,BRONZE)
            box(s,108,93,104,46,WOOD)
            for yy in range(72,132,11): s.line(117,yy,203,yy,WOOD_D)
            s.ellipse(139,98,181,144,D);box(s,139,123,43,25,D)
        box(s,145,120,30,26,RED_D)
        poly(s,[(147,143),(152,128),(157,135),(161,114),(168,129),(172,125),(175,143)],FIRE)
        poly(s,[(154,142),(160,130),(166,141)],GLOW)
        box(s,68,145,30,6,STONE);box(s,74,138,17,8,STONE_L)
        box(s,72,136,27,3,SILVER)
    elif kind in ("sanctum","archive","observatory"):
        # Roof dome, ribs and a different instrument above each institutional hall.
        s.ellipse(124,25,196,81,D)
        s.ellipse(127,27,192,78,roof)
        s.ellipse(130,29,176,74,TEAL if key!="archive" else LILAC)
        box(s,123,59,74,23,roof)
        for xx in (135,147,160,173,185):
            s.line(xx,37,xx,64,TAN if kind=="archive" else AQUA)
        box(s,121,70,78,4,TAN)
        if kind=="sanctum":
            poly(s,[(160,8),(171,22),(160,35),(149,22)],ICE)
            poly(s,[(160,11),(160,30),(153,22)],WHITE)
            for xx in (36,271):
                box(s,xx,132,12,22,STONE);s.ellipse(xx-4,127,xx+15,134,AQUA)
        elif kind=="archive":
            box(s,149,9,22,12,D);box(s,151,10,8,9,CREAM);box(s,161,10,8,9,GOLD)
            s.line(160,10,160,20,WOOD)
            for xx in (63,240):
                box(s,xx,136,18,17,WOOD_D)
                for n,c in enumerate((RED,AQUA,GOLD,LILAC)): box(s,xx+2+n*4,138,3,12,c)
        else:
            s.ellipse(144,7,175,27,GOLD,fill=False)
            s.line(144,25,177,9,SILVER)
            box(s,155,25,6,8,STONE_L)
            box(s,169,4,15,7,TEAL);box(s,181,3,4,9,GOLD)
            for xx in (34,275): box(s,xx,120,10,34,STONE_L)
    elif kind=="clinic":
        box(s,146,31,28,25,CREAM)
        box(s,157,34,6,19,RED);box(s,151,41,18,6,RED)
        for xx in (49,252):
            box(s,xx,136,16,13,CREAM);box(s,xx+6,138,4,9,RED);box(s,xx+3,141,10,3,RED)
        for xx in (100,205):
            box(s,xx,139,12,14,GREEN_S);leaf(s,xx+6,141,-1,6);leaf(s,xx+6,140,1,6)
    elif kind=="dock":
        for xx in range(38,285,22):
            box(s,xx,154,5,19,WOOD_D);box(s,xx,154,2,19,TAN)
        for xx in (68,115,205,252):
            s.line(xx,101,xx,116,WOOD_D)
            box(s,xx-5,112,11,12,RED_D);box(s,xx-4,113,8,9,FIRE)
            box(s,xx-1,113,2,9,GLOW);s.line(xx,124,xx,129,GOLD)
        box(s,39,147,242,3,TAN)
    else:
        box(s,132,59,56,20,WOOD_D)
        # Food symbol: bowl, rice and rising steam, no baked text.
        s.ellipse(145,64,175,72,CREAM)
        poly(s,[(143,69),(177,69),(172,79),(149,79)],RED)
        for xx in (152,161,169): s.line(xx,58,xx-2,54,CREAM)
        box(s,55,142,25,11,WOOD_D);box(s,57,140,21,4,GOLD)
    # Asymmetrical left light and grounded props finish the refined pass.
    if refined:
        box(s,34,155,75,1,TAN)
        box(s,184,164,66,1,SILVER)
        box(s,227,146,16,8,WOOD_D)
        box(s,228,145,14,2,TAN)
        for xx in (229,234,239): s.line(xx,148,xx,152,WOOD_L)
        if key=="snowridge":
            for xx,yy,ww in [(40,95,51),(101,91,34),(188,93,44),(254,96,28),(129,55,24)]:
                box(s,xx,yy,ww,3,SILVER)
                box(s,xx+3,yy-1,ww-8,2,WHITE)
                box(s,xx+ww-7,yy+2,3,4,FROST)


def chest(s, key, refined):
    mutated = key.startswith("mutated")
    opened = key.endswith("open")
    guarding = key.endswith("guarding")
    cleared = key.endswith("cleared")
    metal, shine, wood = (LILAC,PINK,PURPLE) if mutated else (BRONZE,GOLD,WOOD)
    s.ellipse(5,37,44,43,D)
    # Open lid has an empty dark inner mouth; closed lid has a domed top.
    if opened:
        poly(s,[(8,25),(6,11),(12,6),(37,6),(42,11),(40,25)],D)
        box(s,9,11,30,11,wood);box(s,11,9,25,3,metal)
        box(s,12,13,23,7,WOOD_D if not mutated else PURPLE_D)
    else:
        poly(s,[(6,24),(6,18),(11,12),(37,12),(42,18),(42,25)],D)
        poly(s,[(8,23),(8,18),(12,14),(36,14),(40,18),(40,23)],wood)
        box(s,11,14,25,3,metal)
    box(s,6,24,37,15,D);box(s,8,25,33,11,wood)
    box(s,8,25,33,2,metal);box(s,9,35,31,2,metal)
    for xx in (11,34):
        box(s,xx,16 if not opened else 10,4,22 if not opened else 12,metal)
        box(s,xx,26,4,10,metal)
        if refined: s.line(xx,27,xx,33,shine)
    if opened:
        box(s,10,24,29,4,PURPLE_D if mutated else WOOD_D)
        box(s,21,30,7,4,STONE)
    else:
        box(s,20,23,9,10,D);box(s,21,24,7,8,shine)
        if mutated:
            poly(s,[(24,24),(27,28),(24,31),(22,28)],AQUA if cleared else RED if guarding else PURPLE_D)
        else:
            box(s,24,27,2,4,WOOD_D)
    if refined:
        s.line(17,29,19,29,WOOD_L if not mutated else LILAC)
        s.line(29,32,32,32,WOOD_D if not mutated else PURPLE_D)
        box(s,8,19,3,1,shine)
    if guarding:
        poly(s,[(5,19),(2,15),(5,9),(8,14)],LILAC)
        poly(s,[(39,12),(42,5),(45,14),(42,19)],LILAC)
        box(s,22,17,3,2,RED);box(s,30,17,3,2,RED)
    if cleared:
        sparkle(s,9,9,ICE);sparkle(s,40,6,GOLD)
        s.line(20,6,23,9,ICE);s.line(23,9,29,3,ICE)
    if mutated and not opened and not guarding and not cleared:
        s.line(15,20,32,34,STONE_L);s.line(32,20,15,34,STONE_L)


def herb_shape(s, key, ox=0, oy=0, stage=2, refined=True):
    """Single authored species, upright 32x48; smaller stages use fewer branches."""
    x,y=ox+16,oy+42
    if key=="moss":
        poly(s,[(ox+4,y),(ox+6,y-11),(ox+15,y-18),(ox+26,y-11),(ox+29,y)],D)
        poly(s,[(ox+6,y-2),(ox+7,y-11),(ox+15,y-15),(ox+25,y-10),(ox+26,y-2)],STONE)
        for px,py in [(8,-10),(12,-14),(18,-12),(22,-8),(13,-6)][:2+stage*2]:
            box(s,ox+px,y+py,6,3,GREEN)
            box(s,ox+px,y+py,4,1,LEAF_L)
        return
    if key=="bitterroot":
        poly(s,[(x-3,y-20),(x+4,y-20),(x+5,y-9),(x+11,y-3),(x+8,y),(x+2,y-7),(x,y-2),(x-3,y-1),(x-1,y-13),(x-8,y-7),(x-10,y-10)],WOOD_D)
        s.line(x,y-19,x+2,y-8,TAN);s.line(x+2,y-9,x+9,y-3,TAN)
        s.line(x,y-16,x-8,y-9,GOLD)
        leaf(s,x,y-19,-1,8);leaf(s,x,y-19,1,7)
        return
    height=[12,23,32][stage]
    s.line(x,y,x,y-height,GREEN_D)
    s.line(x-1,y-1,x-1,y-height,LEAF)
    if key=="rush":
        for dx,h in [(-8,height-5),(-3,height),(4,height+2),(9,height-3)][:2+stage]:
            s.line(x+dx//2,y,x+dx,y-h,GREEN)
            s.line(x+dx//2+1,y,x+dx+1,y-h,LEAF)
            if stage>0: box(s,x+dx-1,y-h-5,3,7,GOLD if stage==2 else WOOD)
        return
    count=1+stage
    for n in range(count):
        yy=y-5-n*7
        leaf(s,x,yy,-1,6+stage+(n%2),AQUA if key in ("dewleaf","mint") else LEAF,TEAL if key in ("dewleaf","mint") else GREEN_S)
        leaf(s,x,yy-3,1,5+stage,AQUA if key in ("dewleaf","mint") else LEAF_L,TEAL if key in ("dewleaf","mint") else GREEN_S)
    if key=="bloodgrass":
        for dx in (-9,-4,3,8):
            poly(s,[(x,y),(x+dx,y-15-stage*5),(x+dx+2,y-17-stage*5),(x+2,y)],GREEN_S)
            s.line(x+dx,y-15-stage*5,x+dx+1,y-9-stage*4,RED if stage==2 else LEAF)
    if stage==2:
        if key in ("restflower","warmflower","herb"):
            flower(s,x,y-height,LILAC if key=="restflower" else FIRE if key=="warmflower" else ICE,GOLD,4 if key!="warmflower" else 5)
            if key=="warmflower" and refined:
                for dx,dy in [(-6,-3),(6,-3),(-3,5),(3,5)]:box(s,x+dx,y-height+dy,2,2,GLOW)
        elif key=="berry":
            for dx,dy in [(-7,-18),(6,-22),(-2,-28),(8,-11)]:
                s.ellipse(x+dx-3,y+dy-3,x+dx+3,y+dy+3,RED_D)
                s.ellipse(x+dx-3,y+dy-3,x+dx+2,y+dy+1,CORAL)
                if refined: box(s,x+dx-2,y+dy-2,2,1,PINK)
        elif key=="dewleaf":
            poly(s,[(x+7,y-26),(x+10,y-21),(x+9,y-17),(x+5,y-18),(x+4,y-21)],TEAL)
            box(s,x+6,y-21,2,3,ICE)
        elif key=="wakeleaf":
            poly(s,[(x,y-22),(x-8,y-32),(x-2,y-35),(x+2,y-28),(x+10,y-31),(x+6,y-21)],GREEN_S)
            s.line(x,y-23,x-2,y-32,LEAF_L)
            s.line(x,y-23,x+7,y-29,GOLD)
        elif key=="mint":
            box(s,x-1,y-35,3,8,PURPLE);box(s,x-2,y-34,5,2,LILAC)
    elif stage==1 and key in ("restflower","warmflower","herb","berry"):
        box(s,x-2,y-height-2,5,5,GREEN_S);box(s,x-1,y-height-2,3,2,LEAF_L)


def herb(s,key,refined):
    # Reposition the complete mature plant, without resampling: same 1px grid.
    temp=Sprite(32,48,palette=PAL)
    herb_shape(temp,key,stage=2,refined=refined)
    im=temp.composite()
    bounds=im.getbbox()
    crop=im.crop(bounds)
    # Herb icons use cropped clusters; long stems are shortened, never noninteger scaled.
    if crop.height>28:
        top=crop.crop((0,0,crop.width,24))
        bottom=crop.crop((0,crop.height-4,crop.width,crop.height))
        merged=Image.new('RGBA',(crop.width,28))
        merged.paste(top,(0,0));merged.paste(bottom,(0,24))
        crop=merged
    # paste_png requires a file; draw into Sprite via deliberate exact pixel coordinates.
    x0=(32-crop.width)//2;y0=(32-crop.height)//2
    for yy in range(crop.height):
        for xx in range(crop.width):
            c=crop.getpixel((xx,yy))
            if c[3]:s.px(x0+xx,y0+yy,c)


def plant(s,key,refined):
    for stage in range(3):
        x=stage*32
        s.ellipse(x+5,39,x+28,46,WOOD_D)
        box(s,x+10,43,13,2,WOOD)
        herb_shape(s,key,x,0,stage,refined)


def scenery(s,key,refined):
    s.ellipse(7,82,57,92,INK)
    if key in ("pine","snow_pine","charred_pine"):
        box(s,28,56,8,31,WOOD_D);box(s,29,57,3,29,TAN if key!="charred_pine" else WOOD)
        for cx,yy,w,h in [(32,79,51,26),(31,62,43,25),(32,44,31,31)]:
            poly(s,[(cx-w//2,yy),(cx-7,yy-h+9),(cx,yy-h),(cx+8,yy-h+12),(cx+w//2,yy),(cx+12,yy+4),(cx-9,yy+3)],D)
            poly(s,[(cx-w//2+3,yy-2),(cx-5,yy-h+10),(cx,yy-h+3),(cx+8,yy-h+14),(cx+w//2-3,yy-2)],GREEN_S if key!="charred_pine" else WOOD_D)
            poly(s,[(cx-w//2+4,yy-3),(cx-5,yy-h+10),(cx,yy-h+3),(cx,yy-5)],GREEN if key!="charred_pine" else STONE)
            if key=="snow_pine":
                poly(s,[(cx-w//2+4,yy-8),(cx,yy-h+3),(cx+8,yy-h+14),(cx+w//2-7,yy-7),(cx+8,yy-9),(cx-1,yy-6),(cx-8,yy-10)],SILVER)
                s.line(cx-6,yy-h+12,cx,yy-h+4,WHITE)
            elif key=="charred_pine" and refined:
                box(s,cx+10,yy-4,4,2,FIRE)
            elif refined:
                for dx in (-8,0,9):s.line(cx+dx-4,yy-6,cx+dx+1,yy-8,LEAF)
    elif key=="camphor":
        poly(s,[(24,86),(28,48),(23,35),(28,35),(33,49),(40,41),(42,46),(35,55),(38,86)],WOOD_D)
        s.line(29,80,31,43,TAN)
        for cx,cy,r in [(18,48,14),(43,46,15),(32,30,19),(19,32,12),(43,29,12),(30,53,17)]:
            s.ellipse(cx-r,cy-r,cx+r,cy+r,GREEN_D)
            s.ellipse(cx-r+1,cy-r+1,cx+r-3,cy+r-4,GREEN_S)
            s.ellipse(cx-r+2,cy-r+2,cx+5,cy+2,GREEN)
            if refined:box(s,cx-5,cy-r+4,6,2,LEAF)
    elif key=="reeds":
        for dx,h in [(-21,41),(-13,54),(-6,39),(2,61),(10,48),(18,36)]:
            x=32+dx;y=85
            s.line(32+dx//3,y,x,y-h,GREEN_S);s.line(33+dx//3,y,x+1,y-h,LEAF)
            box(s,x-2,y-h-8,5,13,WOOD_D);box(s,x-1,y-h-7,2,9,TAN)
            leaf(s,32+dx//3,y-12,1 if dx>0 else -1,11,LEAF,GREEN)
    elif key=="lotus":
        # Broad notched lily pads and one upright blossom.
        for x,y in [(19,78),(41,81),(29,63)]:
            s.ellipse(x-13,y-6,x+13,y+5,GREEN_D)
            s.ellipse(x-12,y-6,x+11,y+2,GREEN)
            poly(s,[(x,y-1),(x+12,y-3),(x+8,y+3)],WATER_D)
            if refined:s.line(x-8,y-2,x,y-4,LEAF_L)
        s.line(33,68,35,49,GREEN_S)
        for dx,dy in [(-9,0),(-5,-5),(0,-9),(5,-5),(9,0)]:
            poly(s,[(35,55),(35+dx-4,48+dy),(35+dx,41+dy),(35+dx+4,48+dy)],RED_D)
            poly(s,[(35,53),(35+dx-2,48+dy),(35+dx,43+dy),(35+dx+2,48+dy)],PINK)
        box(s,32,51,7,3,GOLD)
    else:
        for x,y,r in [(19,71,13),(42,70,15),(31,59,15),(30,78,17)]:
            s.ellipse(x-r,y-r,x+r,y+r,GREEN_D)
            s.ellipse(x-r+1,y-r+1,x+r-4,y+r-5,GREEN)
            if refined:box(s,x-6,y-r+4,6,2,LEAF)
        for x,y in [(17,67),(38,62),(31,76),(47,73)]:
            s.ellipse(x-3,y-3,x+3,y+3,RED_D);box(s,x-2,y-2,4,3,CORAL)
            if refined:box(s,x-1,y-2,2,1,PINK)


def render(asset,refined):
    s=Sprite(*asset["size"],palette=PAL)
    cat,key=asset["category"],asset["id"]
    if cat=="maps":tiles(s,next(r for r in REGIONS if r[0]==key),refined)
    elif cat=="buildings":building(s,next(r for r in REGIONS if r[0]==key),refined)
    elif cat=="chests":chest(s,key,refined)
    elif cat=="herbs":herb(s,key,refined)
    elif cat=="plants":plant(s,key,refined)
    else:scenery(s,key,refined)
    return s


def check(s,asset):
    im=s.composite()
    colors=len({p[:3] for p in im.get_flattened_data() if p[3]})
    alpha={p[3] for p in im.get_flattened_data()}
    assert alpha <= {0,255},f"soft alpha: {asset}"
    assert colors<=asset["budget"],(asset["id"],colors,asset["budget"])
    assert im.getbbox(),f"empty: {asset}"
    if asset["category"]=="maps":
        # Opposite edges must match for each of the 16 independent tiles.
        for ty in range(4):
            for tx in range(4):
                t=im.crop((tx*32,ty*32,tx*32+32,ty*32+32))
                assert t.crop((0,0,1,32)).tobytes()==t.crop((31,0,32,32)).tobytes()
                assert t.crop((0,0,32,1)).tobytes()==t.crop((0,31,32,32)).tobytes()
    elif asset["category"]!="plants":
        x0,y0,x1,y1=im.getbbox()
        assert x0>=1 and y0>=1 and x1<im.width and y1<im.height,(asset["id"],im.getbbox())
    return {"colors":colors,"alpha":"binary","size":list(im.size),"bbox":list(im.getbbox())}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--batch",type=int)
    ap.add_argument("--pass",dest="phase",choices=["draft","refined"],default="refined")
    ap.add_argument("--audit",action="store_true")
    ap.add_argument("--review-batch",type=int)
    ap.add_argument("--notes",help="Three individual visual review notes, separated by |")
    args=ap.parse_args()
    manifest_path=OUT/"manifest.json"
    if args.review_batch:
        notes=(args.notes or "").split("|")
        if len(notes)!=3 or not all(notes):ap.error("Review requires three individual notes after viewing the previews")
        data=json.loads(manifest_path.read_text(encoding="utf-8"))
        selected=ASSETS[(args.review_batch-1)*3:args.review_batch*3]
        for a,note in zip(selected,notes):
            entry=next(e for e in data["assets"] if e["category"]==a["category"] and e["id"]==a["id"])
            entry.update(reviewed=True,visual_review=note,passes=["draft","refined"])
        manifest_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(f"REVIEWED batch {args.review_batch}: 3 individual previews; SHIP")
        return
    if args.audit:
        data=json.loads(manifest_path.read_text(encoding="utf-8"))
        for a in ASSETS:
            path=OUT/a["category"]/(a["id"]+".png")
            s=render(a,True)
            metrics=check(s,a)
            assert Image.open(path).convert("RGBA").tobytes()==s.composite().tobytes(),path
            entry=next(e for e in data["assets"] if e["category"]==a["category"] and e["id"]==a["id"])
            assert hashlib.sha256(path.read_bytes()).hexdigest()==entry["sha256"],path
            assert entry.get("reviewed"),f"not reviewed: {path}"
        print("PIXEL_AUDIT: 54 masters; palette/alpha/edges/regen/hash/review all PASS")
        return
    if args.batch is None or not 1<=args.batch<=18:ap.error("--batch must be 1..18 (3 images maximum)")
    data=json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {
        "version":1,"style":"Fudi 32-color pixel art; top-left light; 1x masters; 2x world scale",
        "source":"pixel-art/fudi-world/build.py; local deterministic drawing, no gateway requests",
        "palette":PAL,"assets":[]}
    for a in ASSETS[(args.batch-1)*3:args.batch*3]:
        s=render(a,args.phase=="refined")
        metrics=check(s,a)
        target=OUT/a["category"]/(a["id"]+".png")
        target.parent.mkdir(parents=True,exist_ok=True)
        dest=target if args.phase=="refined" else WORK/"drafts"/f'{a["category"]}_{a["id"]}.png'
        dest.parent.mkdir(parents=True,exist_ok=True)
        s.save_png(str(dest))
        preview=WORK/"previews"/args.phase/f'{a["category"]}_{a["id"]}.png'
        preview.parent.mkdir(parents=True,exist_ok=True)
        s.preview(str(preview),scale=3 if a["category"] in ("maps","buildings") else 6,labels=False)
        # Silhouette is an inspection aid, not a game asset.
        silhouette=WORK/"silhouettes"/f'{a["category"]}_{a["id"]}.png'
        silhouette.parent.mkdir(parents=True,exist_ok=True)
        s.save_silhouette(str(silhouette),scale=2)
        if args.phase=="refined":
            entry=dict(a,**metrics,path=target.relative_to(ROOT).as_posix(),batch=args.batch,
                       sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),reviewed=False)
            old=next((i for i,e in enumerate(data["assets"]) if e["category"]==a["category"] and e["id"]==a["id"]),None)
            if old is None:data["assets"].append(entry)
            else:data["assets"][old]=entry
        print(json.dumps({"batch":args.batch,"pass":args.phase,"asset":a["category"]+"/"+a["id"],**metrics},ensure_ascii=False))
    if args.phase=="refined":
        manifest_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":main()
