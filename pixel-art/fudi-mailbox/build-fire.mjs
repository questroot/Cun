import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

if (process.argv.length !== 3) {
  throw new Error("Usage: node build-fire.mjs <pixelfx checkout>");
}
const source = resolve(process.argv[2]);
const upstream = (path) => import(pathToFileURL(join(source, path)));
const { composite, createFrame, hex, painterFor, TAU } = await upstream("src/core/index.js");
const { LAYERS, BIG_LAYERS, BACK_LAYERS, flameTongue, ember, hotFirst, looped, noiseFor, smokePuff } =
  await upstream("src/fx/fire/_lib.js");
const { encodePNG } = await upstream("tools/lib/png.mjs");

const SIZE = 96;
const FOOT = 86;
const COLS = 6;
const IDLE_FRAMES = 18;
const IDLE_LOOP = 1.25;
const WAVE_FRAMES = 48;
const WAVE_LOOP = 2.5;
const H = hotFirst(["#431d2b", "#762e36", "#ab382e", "#df502f", "#f87337",
  "#ff9d49", "#ffc05e", "#ffdc8c", "#fff1bf"].map(hex));
const idleNoise = noiseFor(IDLE_LOOP);
const waveNoise = noiseFor(WAVE_LOOP);
const embers = [H[1], H[2], H[4], H[6]];
const slot = [[-4, -39, 8, 2.2, 1], [-1, -38, 5, 1.4, -1]];
const rear = [
  [-14, -44, 24, 5.0, -4], [-7, -46, 27, 6.5, -3],
  [4, -48, 20, 5.0, 3], [11, -46, 31, 7.2, 4], [18, -31, 20, 5.5, 4],
  [-17, -24, 22, 5.2, -5], [12, -11, 22, 5.3, 5],
];
const front = [
  [-10, -49, 11, 3.4, -2], [7, -49, 12, 3.1, 3],
  [-15, -28, 14, 3.7, -2], [11, -24, 19, 4.7, 3], [15, -35, 14, 4.4, 3],
  [-6, -23, 14, 4.7, -4], [3, -24, 13, 3.5, 1],
  [-4, -14, 12, 3.6, -1],
  [-9, -3, 12, 4.9, -4], [-3, -5, 15, 5.3, -4], [5, -2, 19, 4.5, 4],
];

function surge(t, x, y) {
  // The crest reaches the lower left first, then crosses the face and climbs over the lid.
  const delay = -y * 0.012 + (x + 16) * 0.006;
  return (0.5 + 0.5 * Math.cos(TAU * (t / WAVE_LOOP - delay))) ** 2;
}

function waveTongues(p, t, layout, seed, layers) {
  const n = (rate, s, off) => waveNoise(t, rate, s, off);
  for (const [i, [x, y, h, width, lean]] of layout.entries()) {
    const s = seed + i * 17;
    const rise = surge(t, x, y);
    const height = h * (0.40 + 0.74 * rise + 0.08 * n(5, s));
    const breadth = width * (0.84 + 0.38 * rise);
    const bend = lean + rise * 5.5 + n(3, s + 1) * 1.7;
    flameTongue(p, x, y, height, breadth, bend, n, s, H, layers, 0.65, 1.7);
  }
}

function paint(p, t, layer) {
  if (layer === 0) {
    const n = (rate, s, off) => idleNoise(t, rate, s, off);
    for (const [i, [x, y, h, width, lean]] of slot.entries()) {
      const s = 90 + i * 17;
      flameTongue(p, x, y, h * (1 + 0.22 * n(4, s)), width,
        lean + n(2.4, s + 1) * 2.4, n, s, H, LAYERS, 0.65, 1.3);
    }
    p.glow(-4, -41, 8, H[3], 0.30);
    return;
  }
  if (layer === 1) {
    looped(t, WAVE_LOOP, 16, 142, (r) => ({
      x: r.range(-13, 16), y: r.range(-61, -48), drift: r.range(-6, 6), life: r.range(0.43, 0.65),
    }), (q, age) => {
      const lift = surge(t - age, q.x, -48);
      smokePuff(p, q.x + age * (q.drift + lift * 8), q.y - 16 * age,
        1 - age / q.life, 2.3 + 1.2 * lift, H[7]);
    });
    waveTongues(p, t, rear, 162, BACK_LAYERS);
    p.glow(2, -53, 25, H[5], 0.18 + 0.32 * surge(t, 2, -48));
    return;
  }
  waveTongues(p, t, front, 297, BIG_LAYERS);
  looped(t, WAVE_LOOP, 39, 470, (r) => ({
    x: r.range(-18, 20), y: r.range(-53, -11), vx: r.range(-10, 10),
    vy: r.range(15, 33), life: r.range(0.20, 0.56), size: r.range(1, 1.65),
  }), (q, age) => {
    const lift = surge(t - age, q.x, q.y);
    if (lift < 0.24) return;
    const x = q.x + (q.vx + lift * 11) * age;
    const y = q.y - (q.vy + lift * 17) * age;
    ember(p, x, y, 1 - age / q.life, q.size, embers, age * 31);
  });
  p.glow(-4, -30, 19, H[4], 0.09 + 0.33 * surge(t, -4, -28));
  p.glow(7, -9, 18, H[5], 0.10 + 0.30 * surge(t, 7, -7));
}

// The sprite draws between the two active fire layers.
const width = COLS * SIZE;
const height = (IDLE_FRAMES + WAVE_FRAMES * 2) / COLS * SIZE;
const pixels = new Uint8ClampedArray(width * height * 4);
const layers = [[IDLE_FRAMES, IDLE_LOOP], [WAVE_FRAMES, WAVE_LOOP], [WAVE_FRAMES, WAVE_LOOP]];
let frameOffset = 0;
for (const [layer, [count, duration]] of layers.entries()) {
  for (let i = 0; i < count; i++) {
    const frame = createFrame(SIZE, SIZE);
    paint(painterFor(frame).place(SIZE / 2, FOOT), i * duration / count, layer);
    const rgba = composite(frame, new Uint8ClampedArray(SIZE * SIZE * 4));
    const left = ((frameOffset + i) % COLS) * SIZE;
    const top = Math.floor((frameOffset + i) / COLS) * SIZE;
    for (let y = 0; y < SIZE; y++) {
      pixels.set(rgba.subarray(y * SIZE * 4, (y + 1) * SIZE * 4), ((top + y) * width + left) * 4);
    }
  }
  frameOffset += count;
}
writeFileSync(new URL("../../card-demo/assets/fudi/mailbox/mailbox-fire.png", import.meta.url),
  encodePNG(width, height, pixels));
