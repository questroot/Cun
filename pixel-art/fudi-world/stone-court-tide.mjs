import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export const meta = {
  name: "Stone Court Tide",
  desc: "Jade shallows wash over wet sand, with broken foam and drifting ripples.",
  tags: ["water", "shore", "tide"],
  size: [320, 334],
  origin: [0, 0],
  duration: 4,
  loop: true,
  fps: 12,
  bg: "ground",
  options: { seed: 27, palette: ["#244a5e", "#2c5c70", "#356f7d", "#43848b", "#589b98", "#8ab7a7", "#c8dfcd", "#f0eddb"] },
};

export function makeTide({ hex, fit, blend, noise2, smooth, TAU }) {
  const [width, height] = meta.size;
  const sand = ["#92765b", "#aa8b68", "#bea278", "#cab083", "#d7bd8f", "#e3c99c", "#edd3a7"].map(hex);
  const shell = ["#a37963", "#ebc5a4", "#f5dfb5"].map(hex);

  return function draw(p, time, { palette, seed }) {
    const water = fit(palette, 8);
    const slopes = Array.from({ length: 17 }, (_, i) => blend(water.slice(0, 6), i / 16));
    const phase = TAU * ((time % meta.duration) / meta.duration);
    const slideX = Math.cos(phase), slideY = Math.sin(phase);
    const coast = Array.from({ length: height }, (_, y) => {
      const shore = 188 + 16 * Math.sin(y * 0.024 - 0.8) + 6 * Math.sin(y * 0.057 + 1.2);
      const run = phase - 0.82 * Math.sin(y * 0.019) - y * 0.012;
      const swell = 14 * Math.sin(run) - 4 * Math.sin(2 * run + 0.5);
      const fray = 2.4 * noise2(y * 0.22 + 1.2 * slideY, slideX, seed);
      return { shore, edge: shore + swell + fray, push: Math.cos(run) };
    });

    p.shade(0, 0, width - 1, height - 1, (x, y, out) => {
      const { shore, edge, push } = coast[Math.floor(y)];
      const fromWater = x - edge;
      if (fromWater > 1.5) {
        const grain = noise2(x * 0.9, y * 0.9, seed + 10);
        const dunes = noise2(x * 0.063, y * 0.05, seed + 11);
        const wash = shore + 20 + 3 * noise2(y * 0.13, 7, seed);
        if (x < wash) return sand[grain > 0.4 ? 3 : (fromWater < 6 ? 1 : 2)];
        const ripple = Math.cos(x * 0.52 + 1.1 * Math.sin(y * 0.07) + y * 0.052);
        out.c = sand[grain < -0.63 ? 3 : grain > 0.72 ? 6 : dunes + ripple * 0.18 > 0.27 ? 5 : 4];
        out.a = 1 - smooth(307, 319.5, x);
        return;
      }

      const depth = -fromWater;
      const waterGrain = noise2(x * 0.13 - slideX, y * 0.09 + 1.2 * slideY, seed + 2);
      const lacing = noise2(x * 0.29 - slideY, y * 0.23 + slideX, seed + 3);
      const shoreFoam = 1.8 + 1.5 * Math.max(0, push) + waterGrain * 2;
      if (depth < shoreFoam && lacing > -0.29) return water[lacing > 0.02 ? 7 : 6];
      if (depth < 10 && Math.abs(lacing + 0.12) < 0.12 + 0.08 * Math.max(0, push)) return water[6];

      const wave = Math.sin(depth * 0.165 + phase * 2 + 0.74 * Math.sin(y * 0.049) + waterGrain * 0.42);
      if (depth < 97 && wave > 0.965 && waterGrain > -0.23) return water[depth < 42 ? 6 : 4];
      const current = Math.sin(x * 0.137 + y * 0.105 - phase)
        + 0.76 * Math.sin(x * 0.21 - y * 0.16 + phase + waterGrain);
      const depthBase = shore - x + (edge - shore) * (1 - smooth(0, 95, depth));
      const base = 2.7 + 12 * (1 - smooth(2, 178, depthBase));
      return slopes[Math.max(0, Math.min(16, Math.round(base + 0.8 * waterGrain + 0.65 * current)))];
    });

    for (let i = 0; i < 64; i++) {
      const y = 9 + (i * 53) % 315;
      const x = 12 + (i * 79) % 176;
      if (x > coast[y].edge - 21) continue;
      const shine = Math.max(0, Math.sin(phase * (1 + i % 2) + 1.759 * i)) ** 3;
      if (shine < 0.15) continue;
      for (let j = 0; j <= 3 + i % 5; j++) {
        p.blend(x + j, y + Math.floor(j / 5), water[5], shine * (j === 0 ? 0.19 : 0.36));
      }
    }

    for (let i = 0; i < 35; i++) {
      const y = 8 + (i * 71) % 318;
      const x = 228 + (i * 49) % 76;
      p.line(x - 1, y + 1, x + 2, y + 1, shell[0], 0.55);
      p.line(x, y, x + (i % 3), y - 1, shell[1]);
      p.px(x + 1, y - 1, shell[2]);
    }
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv.length !== 3) throw new Error("Usage: node stone-court-tide.mjs <pixelfx checkout>");
  const source = resolve(process.argv[2]);
  const upstream = (path) => import(pathToFileURL(join(source, path)));
  const draw = makeTide(await upstream("src/core/index.js"));
  const { renderFrames, spriteSheet } = await upstream("tools/lib/fxlib.mjs");
  const effect = { id: "water/stone-court-tide", meta, mod: { meta, draw } };
  const sheet = spriteSheet(effect, renderFrames(effect), "stone-court-tide");
  writeFileSync(new URL("../../card-demo/assets/stone-court/stone-court-tide.png", import.meta.url), sheet.png);
  console.log(JSON.stringify(sheet.json.meta.pixelfx));
}
