import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

if (process.argv.length !== 3) {
  throw new Error("Usage: node import-gate-pixelfx.mjs <pixelfx checkout>");
}
const source = resolve(process.argv[2]);
const upstream = (path) => import(pathToFileURL(join(source, path)));
const { createFrame, createFx, composite, painterFor, hex, rgb, smooth, tileNoise, rand, sparkle, TAU } =
  await upstream("src/core/index.js");
const { encodePNG } = await upstream("tools/lib/png.mjs");
const ripples = await upstream("src/fx/water/ripples.js");
const rift = await upstream("src/fx/arcane/portal.js");
const target = new URL("../../card-demo/assets/effects/fudi-pixelfx/", import.meta.url);

const W = 144;
const H = 152;
const FOOT = 126;
const RIPPLE_H = 88;
const COLS = 6;
const RIFT_WIDTH = 29;
const RIFT_HEIGHT = 45;
const jade = ["#061722", "#102936", "#19494e", "#246b68", "#3ba88d", "#7cdbad", "#c5f6ca", "#fff3ca"];
const stone = ["#101e27", "#23343b", "#344b49", "#4c665b", "#719481", "#b3c5a0"].map(hex);
const [deep, , , green, teal, mint, hot, pearl] = jade.map(hex);
const brass = hex("#ddbb7f");

function atlas(name, count, height, render) {
  const rows = Math.ceil(count / COLS);
  const stride = W * COLS * 4;
  const pixels = new Uint8ClampedArray(stride * rows * height);
  for (let index = 0; index < count; index++) {
    const frame = render(index);
    const left = (index % COLS) * W * 4;
    const top = Math.floor(index / COLS) * height;
    for (let y = 0; y < height; y++) {
      pixels.set(frame.subarray(y * W * 4, (y + 1) * W * 4), (top + y) * stride + left);
    }
  }
  writeFileSync(new URL(name + ".png", target), encodePNG(W * COLS, height * rows, pixels));
}

function sample(effect, time, height, foot, options) {
  const frame = createFrame(W, height);
  const fx = createFx(effect, { x: W / 2, y: foot, palette: jade, ...options });
  fx.update(time);
  fx.draw(frame);
  return composite(frame, new Uint8ClampedArray(W * height * 4));
}

function riseColumn(p, height, power, phase) {
  const yTop = -height;
  p.shade(-23, yTop - 3, 23, 3, (x, y, out) => {
    const z = -y / height;
    if (z < 0 || z > 1) return;
    const fade = Math.min(1, (1 - z) * 15) * power;
    const drift = Math.sin(z * 15 - phase * 3) * 1.3;
    const d = Math.abs(x - drift);
    const vein = 0.5 + 0.5 * Math.cos(x * 1.8 + z * 23 - phase * 4);
    if (d < 1.5 - z * 0.65) {
      out.c = vein > 0.65 ? pearl : hot;
      out.a = fade;
    } else if (d < 5.0 - 2.2 * z && vein > 0.57) {
      out.c = vein > 0.9 ? hot : mint;
      out.a = fade * vein;
    }
    out.l = teal;
    out.k = fade * Math.max(0, 1 - d / 22) ** 3 * 0.66;
  });
  p.glow(0, -1, 23, mint, 0.37 * power);
  sparkle(p, 0, yTop + 3, 5, pearl, mint, power * 0.68);
}

// The upstream rift supplies the moving fibres. The jambs and arch reshape its window.
function doorway(p, time, phase, height, halfWidth, spread) {
  const inner = sample(rift, time, H, FOOT, { width: RIFT_WIDTH, height: RIFT_HEIGHT, light: 0.84, seed: 12 });
  const shoulder = Math.min(26, height * 0.36);
  const bevel = 2.4 + spread * 4.2;
  p.shade(-halfWidth - 4, -height - 4, halfWidth + 4, 3, (x, y, out) => {
    const archY = Math.min(0, y + height - shoulder) / shoulder;
    const d = archY < 0
      ? (1 - Math.hypot(x / halfWidth, archY)) * Math.min(halfWidth, shoulder)
      : halfWidth - Math.abs(x);
    const edge = Math.min(d, 0.5 - y);
    if (edge < -2) return;
    if (edge < 0) {
      out.l = teal;
      out.k = (1 + edge / 2) * spread * 0.24;
      return;
    }
    const grain = tileNoise(x * 0.22, y * 0.22, 96, 96, 13);
    const seam = ((Math.floor(-y + (x < 0 ? 4 : 0)) % 14) === 0);
    if (edge < bevel - 1.2) {
      const lit = x < 0 || archY < -0.19;
      const cut = grain > 0.38 || seam;
      out.c = edge < 1.1 || cut ? stone[0] : edge < 2.1 ? stone[lit ? 4 : 2] : stone[lit ? 3 : 2];
      if (edge > 2.5 && edge < 3.8 && Math.sin(y * 0.49 + Math.abs(x) * 0.7) > 0.60) out.c = brass;
      out.a = 0.9 * spread;
      return;
    }
    const sweep = 0.5 + 0.5 * Math.cos(phase * 2 + y * 0.21 + x * 0.17);
    if (edge < bevel + 1.2) {
      out.c = sweep > 0.79 ? pearl : sweep > 0.32 ? hot : mint;
      out.a = spread;
      out.l = mint;
      out.k = spread * 0.35;
      return;
    }
    const v = (1 + 2 * y / height) * 0.93;
    const widthAtY = halfWidth * Math.sqrt(1 - archY * archY);
    const u = x / (widthAtY - bevel + 1.4);
    const sx = Math.floor(W / 2 + u * RIFT_WIDTH * Math.sqrt(1 - v * v) * 0.88);
    const sy = Math.floor(FOOT - RIFT_HEIGHT - 5 + v * RIFT_HEIGHT);
    const i = (sy * W + sx) * 4;
    out.c = inner[i + 3] > 140 ? rgb(inner[i], inner[i + 1], inner[i + 2]) : deep;
    out.a = spread * 0.98;
    out.l = teal;
    out.k = spread * Math.max(0, 1 - (edge - bevel) / 5) * 0.28;
  });
  for (const side of [-1, 1]) {
    const x = side * (halfWidth - 3);
    p.glowLine(x, -height * 0.70, x, -5, 13, teal, 0.34 * spread);
    p.glow(x, -1, 14, mint, 0.31 * spread);
    p.line(x - 5, -2, x + 5, -2, brass, spread);
  }
  sparkle(p, 0, -height + 2, 3.5, pearl, brass, spread * (0.42 + 0.24 * Math.sin(phase)));
}

function doorFrame(time, opening) {
  const frame = createFrame(W, H);
  const p = painterFor(frame).place(W / 2, FOOT);
  const phase = time / rift.meta.duration * TAU;
  const rise = smooth(0.0, 0.38, opening);
  const spread = smooth(0.31, 1.0, opening);
  const height = 94 * rise;
  const width = 3.0 + 26.0 * spread;
  const column = rise * (1 - spread);
  if (spread > 0.035) doorway(p, time, phase, height, width, spread);
  if (column > 0.03) riseColumn(p, height + 12 * column, column, phase);
  for (let i = 0; i < 25; i++) {
    const age = (time / rift.meta.duration * 2 + rand(i, 4)) % 1;
    const drift = (rand(i, 8) - 0.5) * 17 * Math.sin(age * Math.PI);
    const x = (rand(i, 10) - 0.5) * width * 2.75 + drift;
    const y = -2 - age * (height * (0.44 + rand(i, 15) * 0.60));
    const light = Math.sin(age * Math.PI) ** 2 * rise * (0.50 + rand(i, 34) * 0.5);
    const color = i % 5 === 0 ? brass : i % 3 === 0 ? hot : mint;
    p.dot(x, y, color, light);
    if (i % 6 === 0) p.glow(x, y, 5, color, light * 0.41);
  }
  if (rise > 0) {
    p.ellipse(0, 0, width + 4, 2.1, (u) => u < 0.3 ? hot : green, rise * 0.65);
    p.glow(0, 0, 20, teal, rise * 0.42);
  }
  return composite(frame, new Uint8ClampedArray(W * H * 4));
}

atlas("gate-ripples", 48, RIPPLE_H, (index) => sample(ripples, index * ripples.meta.duration / 48, RIPPLE_H, RIPPLE_H / 2, { seed: 4 }));
atlas("gate-opening", 25, H, (index) => doorFrame(rift.meta.duration * (index / 24), index / 24));
atlas("gate-flow", 36, H, (index) => doorFrame(index * rift.meta.duration / 36, 1.0));
