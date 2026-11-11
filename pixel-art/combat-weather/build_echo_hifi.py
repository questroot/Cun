# -*- coding: utf-8 -*-
"""H06-echo high-fidelity 8-frame showcase sequence.

Deliberately NOT a runtime atlas: this uses continuous gradients, glow and soft alpha
to match an AI-reference look. Produced on a 4x canvas with real tonal interpolation,
then downsampled to 96px. The runtime 5-colour binary-alpha atlas is untouched.
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4
SZ = 96 * S
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'showcase', 'echo_hifi8')
os.makedirs(OUT, exist_ok=True)

# bell palette (runtime) extended into continuous ramps
DARK   = (53, 45, 64)
BRONZE = (107, 74, 73)
COPPER = (165, 115, 80)
GOLD   = (216, 170, 99)
PALE   = (242, 214, 151)
IVORY  = (255, 244, 206)
TEAL   = (120, 154, 157)


def rgb(c, a=255):
    return (c[0], c[1], c[2], a)


def ramp(y0, y1, c0, c1):
    """Vertical linear colour ramp over the full canvas as an RGBA image."""
    ys = np.arange(SZ, dtype=np.float32)[:, None] / S
    t = np.clip((ys - y0) / max(1e-6, y1 - y0), 0.0, 1.0)[:, :, None]
    a = np.array(c0, dtype=np.float32)[None, None, :]
    b = np.array(c1, dtype=np.float32)[None, None, :]
    arr = np.empty((SZ, SZ, 4), dtype=np.uint8)
    arr[:, :, :3] = np.repeat((a * (1 - t) + b * t).astype(np.uint8), SZ, axis=1)
    arr[:, :, 3] = 255
    return Image.fromarray(arr, 'RGBA')


def mask_poly(points):
    m = Image.new('L', (SZ, SZ), 0)
    ImageDraw.Draw(m).polygon([(round(x * S), round(y * S)) for x, y in points], fill=255)
    return m


def stamp(base, shape_mask, colour_img):
    base.paste(colour_img, (0, 0), shape_mask)


def ring_mask(cx, cy, rx, ry, thick, a0=0.0, a1=math.tau):
    """Annulus mask, optionally clipped to an angular fan."""
    m = Image.new('L', (SZ, SZ), 0)
    d = ImageDraw.Draw(m)
    def box(rx_, ry_):
        return [round((cx - rx_) * S), round((cy - ry_) * S),
                round((cx + rx_) * S), round((cy + ry_) * S)]
    d.ellipse(box(rx, ry), fill=255)
    d.ellipse(box(max(0.5, rx - thick), max(0.5, ry - thick)), fill=0)
    if a1 - a0 < math.tau - 1e-3:
        fan = Image.new('L', (SZ, SZ), 0)
        pts = [(round(cx * S), round(cy * S))]
        n = 40
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            pts.append((round((cx + math.cos(a) * 70) * S), round((cy + math.sin(a) * 70) * S)))
        ImageDraw.Draw(fan).polygon(pts, fill=255)
        m = ImageChops.multiply(m, fan)
    return m


def bell_shapes(cx, top, w, h):
    mouth = top + h
    half = w / 2
    waist = half - 3
    body = [(cx-half,mouth),(cx-half+1,top+h/2),(cx-waist,top+3),
            (cx-waist+4,top),(cx+waist-4,top),(cx+waist,top+3),
            (cx+half-1,top+h/2),(cx+half,mouth)]
    lit = [(cx-half+1,mouth-1),(cx-half+2,top+h/2),(cx-waist+1,top+4),
           (cx-3,top+1),(cx-4,mouth-2)]
    shade = [(cx+half-2,mouth-1),(cx+half-3,top+h/2),(cx+waist-2,top+4),
             (cx+2,top+1),(cx+3,mouth-2)]
    return body, lit, shade, mouth, half


def draw_frame(f):
    u = f / 7.0
    base = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
    cx = 48

    # --- sound waves: fan spreading down from the mouth, tonally falling off outward
    for k in range(4):
        rr = 12 + u * 17 + k * 6.5
        ry = rr * 0.62
        th = max(1.2, 3.2 - k * 0.6)
        m = ring_mask(cx, 52, rr, ry, th, math.radians(26), math.radians(154))
        c0 = [IVORY, PALE, GOLD, COPPER][k]
        c1 = [PALE, GOLD, COPPER, BRONZE][k]
        stamp(base, m, ramp(40, 80, c0, c1))

    # --- bell body
    body, lit, shade, mouth, half = bell_shapes(cx, 17, 32, 34)
    stamp(base, mask_poly(body), ramp(17, mouth, GOLD, BRONZE))
    stamp(base, mask_poly(lit), ramp(17, mouth, IVORY, PALE))
    stamp(base, mask_poly(shade), ramp(17, mouth, BRONZE, DARK))

    d = ImageDraw.Draw(base)
    def seg(pts, fill, width=1):
        d.line([(round(x*S), round(y*S)) for x, y in pts], fill=rgb(fill), width=max(1,round(width*S)))

    # cast bands: dark groove with a lit lip above it
    for yy in (17 + 34//3 + 3, 17 + 34//2 + 4):
        seg([(cx-half+4, yy), (cx+half-4, yy)], DARK, 1)
        seg([(cx-half+4, yy-1), (cx+half-4, yy-1)], PALE, 1)
    # specular edge on the lit side
    seg([(cx-half+6, 23), (cx-half+5, mouth-3)], IVORY, 1)
    # mouth rim: bright top, dark underside
    d.rectangle([round((cx-half)*S), round((mouth-1)*S),
                 round((cx+half)*S), round((mouth+1)*S)], fill=rgb(GOLD))
    seg([(cx-half, mouth+2), (cx+half, mouth+2)], BRONZE, 1)
    seg([(cx-half, mouth-1), (cx+half, mouth-1)], IVORY, 1)
    # crown loop and clapper
    d.rectangle([round((cx-3)*S), round((17-6)*S), round((cx+3)*S), round((17-1)*S)], fill=rgb(BRONZE))
    d.rectangle([round((cx-2)*S), round((17-5)*S), round((cx+2)*S), round((17-2)*S)], fill=rgb(PALE))
    d.rectangle([round((cx-2)*S), round((mouth+3)*S), round((cx+2)*S), round((mouth+7)*S)], fill=rgb(BRONZE))
    d.ellipse([round((cx-2)*S), round((mouth+6)*S), round((cx+2)*S), round((mouth+10)*S)], fill=rgb(GOLD))

    # --- impact spark on frames 3-4, placed below the mouth (not on the bell face)
    if f in (2, 3):
        seg([(cx, mouth+4), (cx, mouth+12)], IVORY, 1)
        seg([(cx-4, mouth+8), (cx+4, mouth+8)], PALE, 1)

    # --- soft glow: blur the luminance of what we drew and screen it back
    glow = base.filter(ImageFilter.GaussianBlur(radius=2.2 * S))
    glow.putalpha(glow.getchannel('A').point(lambda v: int(v * 0.42)))
    base = Image.alpha_composite(base, glow)

    # --- fine airborne motes near the wave front
    for i in range(7):
        a = math.radians(30 + i * 20 + u * 8)
        r = 18 + u * 16 + (i % 3) * 5
        x = cx + math.cos(a) * r
        y = 52 + math.sin(a) * r * 0.62
        d.ellipse([round(x*S), round(y*S), round((x+1.2)*S), round((y+1.2)*S)],
                  fill=rgb(IVORY if i % 2 else PALE))

    return base.resize((96, 96), Image.LANCZOS)


frames = [draw_frame(f) for f in range(8)]
for i, fr in enumerate(frames, 1):
    fr.save(os.path.join(OUT, 'H06-echo_hifi_%02d.png' % i))

# atlas + strip preview
atlas = Image.new('RGBA', (96 * 8, 96), (0, 0, 0, 0))
for i, fr in enumerate(frames):
    atlas.paste(fr, (i * 96, 0))
atlas.save(os.path.join(OUT, 'H06-echo_hifi_atlas.png'))

cell = 192
strip = Image.new('RGB', (cell * 8, cell), (23, 35, 50))
for i, fr in enumerate(frames):
    bg = Image.new('RGBA', (96, 96), (23, 35, 50, 255))
    bg.alpha_composite(fr)
    strip.paste(bg.convert('RGB').resize((cell, cell), Image.NEAREST), (i * cell, 0))
strip.save(os.path.join(OUT, 'H06-echo_hifi_strip.png'))

# report
import collections
c = collections.Counter()
semi = 0
for fr in frames:
    c.update(px for px in fr.get_flattened_data() if px[3])
    semi += sum(1 for v in fr.getchannel('A').get_flattened_data() if 0 < v < 255)
print('frames', len(frames), 'distinct colours', len(c))
print('semi-transparent px across 8 frames', semi)
print('output', OUT)
