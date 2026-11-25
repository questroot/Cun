import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const meta = {
  name: "Stone Court Water Phoenix",
  desc: "A sea vortex throws up a crested phoenix that arches across the shore and dives into a crown of spray.",
  tags: ["water", "vortex", "phoenix", "splash"],
  size: [352, 228],
  origin: [46, 176],
  duration: 3.95,
  loop: false,
  fps: 20,
  bg: "ground",
  options: { seed: 41, palette: ["#18384c", "#386878", "#578f9c", "#83b7bf", "#afd9d9", "#d7f0e8", "#f7f6dd"] },
};

const TAKEOFF = 0.72, CONTACT = 2.54, SPAN = 745 / 3;
const WING = [[6,2],[13,-3],[20,-13],[25,-19],[34,-25],[42,-38],[43,-30],[38,-21],[47,-29],[46,-21],[40,-14],[46,-18],[43,-10],[35,-5],[41,-6],[36,1],[29,3],[32,5],[24,8],[16,7],[9,5]];
const BODY = [[-8,-8],[-3,-14],[-4,-19],[0,-23],[6,-23],[12,-20],[13,-14],[9,-9],[11,-1],[9,8],[5,14],[-3,16],[-9,12],[-13,4],[-11,-5]];
const CREST = [[-5,-17],[-7,-23],[-12,-28],[-10,-29],[-4,-26],[-3,-32],[-7,-38],[-2,-36],[2,-30],[3,-34],[1,-41],[7,-37],[9,-32],[8,-27],[12,-29],[16,-35],[16,-29],[13,-23],[17,-26],[16,-21],[11,-17]];

export function makePhoenix({ TAU, clamp, smooth, ease, fit, hex, rand }) {
  const gold = hex("#ffdf9a");

  function flight(time) {
    const u = clamp((time - TAKEOFF) / (CONTACT - TAKEOFF));
    const angle = Math.PI * u;
    return [(1 - Math.cos(angle)) * SPAN * 0.5, -Math.sin(angle) * SPAN * 0.5, angle - Math.PI * 0.5];
  }

  function whirl(p, time, color) {
    const power = smooth(0, 0.25, time) * (1 - smooth(0.76, 1.18, time));
    if (power <= 0) return;
    const radius = 5 + 24 * power;
    p.shade(-radius * 0.78, -radius * 0.45, radius * 0.78, radius * 0.45, (x, y) => {
      const r = Math.hypot(x / 0.78, y * 2.35) / radius;
      if (r < 1) p.blend(x, y, color[0], (1 - r * r) * 0.62 * power);
    });
    for (let arm = 0; arm < 4; arm++) {
      let previous = null;
      for (let i = 0; i < 37; i++) {
        const u = i / 37, angle = arm * TAU / 4 + time * 6.4 + u * 4.6;
        const r = radius * (0.18 + 0.82 * u);
        const x = Math.cos(angle) * r * 0.78, y = Math.sin(angle) * r * 0.38;
        const alpha = power * (0.35 + 0.65 * Math.sin(Math.PI * u));
        p.blend(x, y + 1, color[2], alpha * 0.7);
        if (previous) p.line(...previous, x, y, color[i % 11 < 6 ? 6 : 4], alpha);
        previous = [x, y];
      }
    }
    p.ellipse(0, 0, 5, 2.6, color[0], power);
    p.glow(0, 0, 22, color[3], power * 0.18);
  }

  function ribbons(p, time, color) {
    for (let strand = 0; strand < 3; strand++) {
      let previous = null;
      for (let i = 0; i < 22; i++) {
        const age = i * 0.014, past = time - age;
        if (past < TAKEOFF || past > CONTACT) continue;
        const [x, y, angle] = flight(past);
        const sway = (strand - 1) * (2 + age * 28) + 2.5 * Math.sin(i * 0.43 + time * 9);
        const point = [x - Math.sin(angle) * sway, y + Math.cos(angle) * sway];
        const alpha = (1 - i / 22) ** 1.7 * (1 - smooth(CONTACT, CONTACT + 0.26, time));
        if (previous) p.beam(...previous, ...point, 1.4 + (1 - i / 22), color[strand === 1 ? 5 : 3], alpha);
        if (i % 4 === strand) p.blend(point[0], point[1] + 2, color[6], alpha * 0.7);
        previous = point;
      }
    }
  }

  function bird(p, time, color) {
    const [x, y, heading] = flight(time);
    const age = time - TAKEOFF;
    const emerge = smooth(0, 0.20, age);
    const tuck = smooth(CONTACT - 0.34, CONTACT, time);
    const beat = Math.sin(age * TAU * 2.75 + 0.2);
    const pitch = heading * (0.33 + 0.54 * tuck);
    const size = (0.62 + 0.23 * emerge) * (1 - 0.13 * tuck);
    const cs = Math.cos(pitch) * size, sn = Math.sin(pitch) * size;
    const point = ([u, v]) => [x + u * cs - v * sn, y + u * sn + v * cs];
    const shape = (points, c, alpha = 1) => p.poly(points.map(point), c, alpha * emerge);
    const line = (a, b, c, alpha = 1) => p.line(...point(a), ...point(b), c, alpha * emerge);

    p.glow(x, y, 28, color[3], 0.31 * emerge);
    for (let i = 0; i < 4; i++) {
      const sweep = (i - 1.5) * 7.8;
      const sway = Math.sin(age * 10 + i * 0.7) * 4;
      const bend = -12 + sweep + sway;
      const rib = clamp((3 - i) / 3) * 7;
      const tail = [[-3,9],[-6,19],[-14 + sweep * 0.5,25], [bend - 4,35 + rib], [bend - 3,42 + rib],[bend + 3,44 + rib],[bend,38 + rib],[bend + 2,32 + rib],[-7 + sweep * 0.4,25],[5,13]];
      shape(tail, color[i % 2 ? 3 : 2]);
      p.polyline(tail.slice(0, 6).map(point), color[0], emerge * 0.80);
      p.polyline([[-3,17],[-10 + sweep * 0.5,25],[bend - 1,34 + rib],[bend - 1,41 + rib]].map(point), color[i % 2 ? 5 : 4], emerge * 0.85);
    }
    for (const side of [-1, 1]) {
      const pose = ([u, v]) => [
        side * (6 + (u - 6) * (1 - 0.58 * tuck)) * (side < 0 ? 1 : 0.93) - tuck * (u - 6) * 0.31,
        v * (0.90 + 0.19 * beat) + (u - 6) * (0.44 * beat + 0.48 * tuck),
      ];
      const wing = WING.map(pose);
      shape(wing, color[2]);
      p.polyline([...wing, wing[0]].map(point), color[0], emerge * 0.85);
      for (const [tip, notch, root] of [[5, 7, [20,-10]], [8,10,[20,-5]], [11,13,[17,-2]], [14,16,[16,2]], [17,19,[11,4]]]) {
        const base = pose(root);
        const ridge = pose([root[0] + 6, root[1] - 5]);
        shape([base, ridge, wing[tip], wing[notch]], color[tip === 5 ? 4 : 3]);
        line(ridge, wing[tip], color[5], 0.85);
      }
      shape([[6,2],[12,-3],[21,-12],[23,-7],[19,-2],[24,-3],[22,2],[17,5],[11,6]].map(pose), color[4]);
      line(pose([8,2]), pose([18,-6]), color[5], 0.80);
    }
    shape(CREST, color[3]);
    p.polyline([...CREST, CREST[0]].map(point), color[0], emerge * 0.85);
    line([1,-40],[5,-32], color[6]);
    line([-10,-28],[-3,-23], color[5]);
    line([15,-33],[12,-25], color[5]);
    shape(BODY, color[3]);
    p.polyline([...BODY, BODY[0]].map(point), color[0], emerge);
    shape([[-8,-8],[-3,-13],[-3,-18],[2,-22],[8,-21],[11,-18],[8,-13],[5,-11],[8,-6],[5,3],[1,10],[-4,12],[-8,8],[-5,4],[-9,2],[-6,-3]], color[5]);
    shape([[-1,-21],[3,-22],[7,-20],[5,-16],[1,-15],[-1,-17]], color[6]);
    line([-8,5],[-4,13],color[2]);
    shape([[10,-17],[17,-14],[12,-12],[10,-13]], gold);
    line([7,-18],[10,-17],color[0]);
    p.blend(...point([8,-17]), color[0], emerge);
    p.blend(...point([8,-18]), color[6], emerge);
  }

  function splash(p, age, x, size, color, seed) {
    if (age < 0 || age > 1.35) return;
    const flash = 1 - smooth(0.02, 0.32, age);
    p.glow(x, -2, 34 * size, color[4], flash * 0.56);
    const rise = ease.outCubic(clamp(age / 0.14)) * (1 - smooth(0.15, 0.42, age));
    for (let i = 0; i < 9; i++) {
      const a = i * TAU / 9;
      const side = Math.cos(a), front = Math.sin(a);
      const foot = x + side * (8 + age * 24) * size;
      const baseY = front * (3 + age * 9) * size;
      const topX = foot + side * 11 * size * rise;
      const topY = baseY - (17 + rand(i, seed) * 13) * size * rise;
      if (rise < 0.015) continue;
      const shoulder = [foot + (topX - foot) * 0.36, (baseY + topY) * 0.5];
      p.beam(foot, baseY, ...shoulder, 8 * size, color[front > 0 ? 4 : 2], rise);
      p.beam(...shoulder, topX, topY, 3.2 * size, color[5], rise);
      p.disc(topX, topY, 2.4 * size, color[6], rise);
    }
    for (let i = 0; i < 43; i++) {
      const delay = 0.018 + rand(i, seed + 1) * 0.18;
      const life = 0.42 + rand(i, seed + 2) * 0.49;
      const u = (age - delay) / life;
      if (u < 0 || u > 1.28) continue;
      const angle = i * 2.39996, length = (8 + rand(i, seed + 3) * 22) * size;
      const spread = Math.min(u, 1) * length;
      const h = (14 + 27 * rand(i, seed + 4)) * size;
      const yy = Math.sin(angle) * spread * 0.34 - 4 * h * Math.max(0, u * (1 - u));
      const xx = x + Math.cos(angle) * spread;
      if (u < 1) {
        p.beam(xx, yy - 1, xx - Math.cos(angle) * 1.7 * size, yy - (2 * u - 1) * 5 * size, i % 4 === 0 ? 2.2 : 1.25, color[i % 5 === 0 ? 6 : 4], 0.9);
      } else {
        p.ellipse(xx, yy, 1 + (u - 1) * 7, 0.85, color[5], (1.28 - u) * 3.5);
      }
    }
    const wet = smooth(0, 0.12, age) * (1 - smooth(0.58, 1.35, age));
    const pool = (8 + age * 21) * size, depth = (2.5 + age * 8) * size;
    p.shade(x - pool, 1 - depth, x + pool, 1 + depth, (px, py) => {
      const r = Math.hypot((px - x) / pool, (py - 1) / depth);
      if (r < 1) p.blend(px, py, color[2], wet * 0.46 * (1 - r * r));
    });
    p.arc(x, 0, (7 + age * 16) * size, 1.8, 0.6, 2.7, color[5], wet * 0.64);
  }

  return function draw(p, time, { seed, palette }) {
    if (time >= meta.duration) return;
    const color = fit(palette, 7);
    whirl(p, time, color);
    splash(p, time - TAKEOFF, 0, 0.50, color, seed + 7);
    if (time >= TAKEOFF) ribbons(p, time, color);
    if (time >= TAKEOFF && time < CONTACT) bird(p, time, color);
    splash(p, time - CONTACT, SPAN, 1.1, color, seed);
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv.length !== 3) throw new Error("Usage: node stone-court-phoenix.mjs <pixelfx checkout>");
  const source = resolve(process.argv[2]);
  const upstream = (path) => import(pathToFileURL(join(source, path)));
  const draw = makePhoenix(await upstream("src/core/index.js"));
  const { renderFrames, spriteSheet } = await upstream("tools/lib/fxlib.mjs");
  const effect = { id: "water/stone-court-phoenix", meta, mod: { meta, draw } };
  const sheet = spriteSheet(effect, renderFrames(effect), "stone-court-phoenix");
  writeFileSync(new URL("../../card-demo/assets/stone-court/stone-court-phoenix.png", import.meta.url), sheet.png);
  console.log(JSON.stringify(sheet.json.meta.pixelfx));
}
