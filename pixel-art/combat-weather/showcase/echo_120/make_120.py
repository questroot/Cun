# -*- coding: utf-8 -*-
"""Build a clean 120-frame animation from the AI video.

The source video degrades from frame ~51 onward (purple triangular artifacts spread
across the background). Only the first 50 usable frames are kept and temporally
resampled to 120 frames with nearest-neighbour timing, which keeps pixel edges crisp
and matches the stepped feel of pixel animation.
"""
import os
import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'H06-echo_120f.mp4')
FRAMES_DIR = os.path.join(HERE, 'frames96')
os.makedirs(FRAMES_DIR, exist_ok=True)

CLEAN_FRAMES = 34      # sampled probe: frames 2-35 clean; from ~40 corner silhouettes glow purple
TARGET = 120
FIRST = 2              # skip 2 intro frames
FPS = 24

cap = cv2.VideoCapture(SRC)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
clean = []
for i in range(FIRST, FIRST + CLEAN_FRAMES):
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(i))
    ok, fr = cap.read()
    if not ok:
        break
    # watermark: rounded box at x10-92 / y10-48; sample a dark pixel just below it
    bg = tuple(int(v) for v in fr[56, 60])
    fr[4:53, 4:99] = bg
    clean.append(cv2.cvtColor(fr, cv2.COLOR_BGR2RGB))
cap.release()
print('source frames', total, '| clean segment', len(clean))

# nearest-neighbour temporal resample: each source frame is held 2-3 times
seq = [clean[min(len(clean) - 1, t * len(clean) // TARGET)] for t in range(TARGET)]
small = [Image.fromarray(a).resize((96, 96), Image.LANCZOS) for a in seq]
big = [Image.fromarray(a).resize((256, 256), Image.LANCZOS) for a in seq]
print('sequence', len(small), '| unique pictures', len(clean))

for k, im in enumerate(small, 1):
    im.save(os.path.join(FRAMES_DIR, 'H06-echo_%03d.png' % k))

atlas = Image.new('RGB', (96 * TARGET, 96))
for k, im in enumerate(small):
    atlas.paste(im, (k * 96, 0))
atlas.save(os.path.join(HERE, 'H06-echo_120f_atlas.png'))

cols, rows, cell = 10, 12, 96
sheet = Image.new('RGB', (cols * cell, rows * cell), (14, 14, 20))
for k, im in enumerate(small):
    sheet.paste(im, ((k % cols) * cell, (k // cols) * cell))
sheet.save(os.path.join(HERE, 'H06-echo_120f_contact.png'))

pal = big[0].convert('P', palette=Image.ADAPTIVE, colors=160)
gf = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in big]
dur = round(1000 / FPS)
gf[0].save(os.path.join(HERE, 'H06-echo_120f.gif'), save_all=True,
           append_images=gf[1:], duration=dur, loop=0, optimize=True)
print('gif', len(gf), 'frames @', dur, 'ms =', round(len(gf) * dur / 1000, 2), 's')

# verification: noise stays low, no sudden jumps
noise = []
for im in small:
    a = np.asarray(im, np.float32)
    r, b = a[:, :, 0], a[:, :, 2]
    noise.append(int(((b > r * 1.35) & (b > 55) & (r < 110)).sum()))
print('purple-noise px: min %d max %d' % (min(noise), max(noise)))
diffs = [float(np.abs(np.asarray(a, np.float32) - np.asarray(b, np.float32)).mean())
         for a, b in zip(small[:-1], small[1:])]
print('adjacent diff: mean %.2f max %.2f' % (np.mean(diffs), np.max(diffs)))
print('done')
