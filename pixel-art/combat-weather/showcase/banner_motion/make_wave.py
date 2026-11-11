# -*- coding: utf-8 -*-
"""Build a looping flag-wave animation from the AI video.

8 wave phases are sampled, cleaned of the corner watermark, and played forward then
backward (0..7..1) so the loop closes without a duplicated endpoint frame.
"""
import os
import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'H01-banner_motion.mp4')
OUT = os.path.join(HERE, 'frames96')
os.makedirs(OUT, exist_ok=True)

PHASES = [0, 13, 27, 41, 54, 68, 82, 95]
cap = cv2.VideoCapture(SRC)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
phases = []
for f in PHASES:
    cap.set(cv2.CAP_PROP_POS_FRAMES, min(f, total - 1))
    ok, fr = cap.read()
    if not ok:
        continue
    # corner watermark: rounded box roughly x28-100 / y22-60; pole starts around x150
    bg = tuple(int(v) for v in fr[90, 10])
    fr[0:72, 0:108] = bg
    phases.append(cv2.cvtColor(fr, cv2.COLOR_BGR2RGB))
cap.release()
print('source frames', total, '| wave phases', len(phases))

small = [Image.fromarray(a).resize((96, 96), Image.LANCZOS) for a in phases]
big = [Image.fromarray(a).resize((256, 256), Image.LANCZOS) for a in phases]
for k, im in enumerate(small, 1):
    im.save(os.path.join(OUT, 'H01-banner_wave_%02d.png' % k))

# ping-pong loop, no duplicated endpoints
order = list(range(len(small))) + list(range(len(small) - 2, 0, -1))
pal = big[0].convert('P', palette=Image.ADAPTIVE, colors=160)
gf = [big[i].quantize(palette=pal, dither=Image.Dither.NONE) for i in order]
dur = 100  # 10 fps, appropriate for stepped pixel animation
gf[0].save(os.path.join(HERE, 'H01-banner_wave_loop.gif'), save_all=True,
           append_images=gf[1:], duration=dur, loop=0, optimize=True)
print('gif', len(gf), 'frames @', dur, 'ms =', len(gf) * dur / 1000, 's loop')

# contact sheet
sheet = Image.new('RGB', (96 * 8, 96), (14, 14, 20))
for k, im in enumerate(small):
    sheet.paste(im, (k * 96, 0))
sheet.save(os.path.join(HERE, 'H01-banner_wave_contact.png'))
print('done')
