import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { sceneEffects } from "./scene-pixelfx.mjs";

if (process.argv.length !== 3) {
  throw new Error("Usage: node import-pixelfx.mjs <pixelfx checkout>");
}
const source = resolve(process.argv[2]);
const core = await import(pathToFileURL(join(source, "src/core/index.js")));
const { createFrame, clearFrame, createFx, composite } = core;
const localEffects = sceneEffects(core);
const { encodePNG } = await import(pathToFileURL(join(source, "tools/lib/png.mjs")));
const repo = fileURLToPath(new URL("../../", import.meta.url));
const target = join(repo, "card-demo/assets/effects/fudi-pixelfx");
const original = JSON.parse(readFileSync(join(repo, "card-demo/assets/effects/pixel/manifest.json"), "utf8"));
const byKey = new Map(original.effects.map(entry => [entry.key, entry]));
const red = ["#3e2439", "#8d374c", "#c4515a", "#ed8671", "#ffba8e", "#ffe2bd", "#fff2d5"];
const green = ["#263022", "#425535", "#62864b", "#9dbe63", "#c6e589", "#eef9b9", "#fafbe1"];
const gold = ["#362334", "#684731", "#9c6949", "#d39c58", "#ffce82", "#ffe9b5", "#fff6db"];
const spirit = ["#1d1743", "#363184", "#5555bd", "#7a7de7", "#a4a6fa", "#c7d1ff", "#e3efff", "#ffffff"];

// key: [upstream effect, rendered width limit, height limit, sampling window, options, X offset]
const replacements = {
  "H01-slash": ["melee/sword-slash", 77, 73, [.015, .40], { palette: red }],
  "H01-thrust": ["melee/thrust", 79, 26, [.035, .32], { palette: red }],
  "H01-banner": ["melee/heavy-cleave", 65, 57, [.19, .85], { palette: red }, 12],
  "H01-spin": ["melee/spin-slash", 88, 78, [.075, .69], { palette: red, sparks: gold }],
  "H01-flag": ["local/war-flag", 59, 82, [.04, .94]],
  "H02-stomp": ["nature/earth-spike", 81, 76, [.25, 1.96], { palette: green }],
  "H02-vine": ["nature/thorns", 82, 26, [.21, 1.88], { palette: green }],
  "H02-charge": ["nature/leaf-storm", 69, 66, [.25, 2.03], { palette: green }, 10],
  "H02-seed": ["local/seed-burst", 72, 75, [.03, .94]],
  "H02-grove": ["nature/root-snare", 56, 65, [.22, 1.92], { palette: green }],
  "H03-burst": ["water/geyser", 66, 76, [1.08, 4.38]],
  "H03-jet": ["water/water-jet", 71, 24, [.04, .91]],
  "H03-mine": ["water/splash", 60, 69, [.26, 2.12], { stone: false }],
  "H03-surge": ["water/wave-crash", 69, 65, [.69, 2.25], {}, 11],
  "H03-tide": ["water/wave-crash", 74, 67, [.74, 2.42]],
  "H04-feather": ["holy/feather-burst", 75, 71, [.04, 1.75]],
  "H04-wing": ["melee/scythe-reap", 64, 58, [.2, .83], { palette: gold }, 13],
  "H04-verdict": ["holy/smite", 76, 76, [.54, 1.47]],
  "H04-spears": ["ice/ice-lance", 86, 20, [.04, .74], { palette: gold }],
  "H04-halo": ["holy/heal-aoe", 86, 62, [.36, 1.86], { palette: gold }],
  "H05-seal": ["arcane/rune-circle", 72, 65, [.04, 2.2], {
    palette: ["#23305b", "#334c8d", "#5874bb", "#75a6db", "#a5ddff", "#e8f7ff"],
  }],
  "H05-icicle": ["ice/ice-lance", 73, 23, [.02, .72]],
  "H05-spike": ["ice/icicle-fall", 57, 70, [.53, 2.12]],
  "H05-script": ["arcane/arcane-beam", 88, 23, [.06, 1.16], { palette: spirit }],
  "H05-frost": ["ice/frost-nova", 84, 72, [.37, 2.47]],
  "H06-hammer": ["melee/hammer-smash", 64, 63, [.06, 1.14], { palette: gold }, 11],
  "H06-echo": ["impacts/ground-slam", 85, 70, [.06, 1.48], { palette: gold }],
  "H06-chain": ["local/rust-chain", 88, 24, [.04, .91]],
  "H06-resonance": ["nature/quake", 75, 54, [.09, 1.65], { palette: gold, glow: gold }],
  "H06-pendulum": ["local/pendulum-chain", 87, 25, [.16, .91]],

  "player-w01": ["fire/fire-ring", 78, 65, [.29, 2.52]],
  "player-w02": ["melee/heavy-cleave", 73, 67, [.19, .83], { palette: gold }],
  "player-w03": ["melee/sword-slash", 78, 77, [.015, .43]],
  "player-w05": ["melee/thrust", 79, 46, [.035, .34], { palette: gold }],
  "player-w06": ["impacts/ground-slam", 77, 66, [.04, 1.45], { palette: gold }],
  "attack-slash": ["melee/sword-slash", 79, 76, [.015, .43], { palette: gold }],
  "attack-cast": ["arcane/mana-burst", 73, 64, [.19, .85], { palette: spirit }],
  "attack-bolt": ["projectiles/plasma-shot", 53, 32, undefined, { palette: spirit, size: 9 }, -17],
  "attack-quake": ["lightning/thunderclap", 85, 78, [.195, .96], { palette: spirit }],

  "impact-enemy": ["impacts/hit-spark", 54, 70, [.005, .43], { palette: gold }, 17],
  "impact-player": ["impacts/blunt-hit", 77, 65, [.015, .68], { palette: red }],
  "impact-fallen": ["spawn/poof", 82, 72, [.015, 1.29]],

  "guard-clear": ["nature/leaf-storm", 61, 60, [.2, 2.02]],
  "guard-fog": ["shadow/shadow-flames", 58, 67, [.14, 2.12]],
  "guard-heat": ["fire/flame-pillar", 61, 73, [.85, 3.94]],
  "guard-rain": ["water/splash", 69, 58, [.22, 2.13], { stone: false }],
  "guard-snow": ["ice/ice-spikes", 67, 64, [.32, 2.53]],
  "guard-storm": ["lightning/lightning-strike", 64, 81, [.75, 1.43]],
  "guard-wind": ["nature/tornado", 59, 74, [.2, 1.65]],
  "guard-stone": ["local/stone-shot", 58, 35, undefined, undefined, -12],

  "status-buff": ["holy/blessing", 51, 66],
  "status-burn": ["fire/spirit-flame", 53, 65, undefined, { palette: red }],
  "status-freeze": ["ice/snowflake-burst", 68, 68, [.24, 2.9]],
  "status-heal": ["holy/heal-aoe", 69, 65, [.27, 1.95], { reach: 46 }],
  "status-poison": ["nature/poison-cloud", 67, 62, undefined, {
    spread: .36,
    palette: ["#231432", "#3d2259", "#563277", "#7949a2", "#a16bc6", "#c28de3", "#daa7f4", "#eed0ff"],
  }],
  "status-shield": ["holy/divine-shield", 62, 66, undefined, {
    palette: ["#20245b", "#30438b", "#4d72bf", "#639ee1", "#9edfff", "#def5ff"],
  }],
  "status-stun": ["lightning/zap-hit", 63, 62, [.055, .49]],
  "weather-storm": ["lightning/lightning-strike", 39, 84, [.77, 1.49]],
  "weather-rain": ["local/rain", 52, 62],
  "weather-snow": ["local/snow", 46, 48],
  "weather-fog": ["local/fog", 82, 32],
  "weather-wind": ["local/wind", 68, 49],
  "weather-heat": ["local/embers", 52, 58],
  "weather-clear": ["local/sun-motes", 54, 38],
  "loot-glint": ["local/loot-glint", 38, 36],
  "pickup-flash": ["pickups/collect-burst", 62, 62, [.015, 1.05]],
  "building-ripple": ["water/ripples", 87, 35, undefined, {
    palette: ["#161721", "#32363d", "#53616a", "#758785", "#9fb4af", "#bccfc9", "#ecf6eb", "#fffef1"],
  }],
  "stove-flame": ["fire/campfire", 67, 82],
  "trap-spores": ["nature/spore-burst", 77, 71, [.58, 2.18]],
  "trap-fissure": ["nature/quake", 82, 62, [.08, 2.0]],
  "trap-debris": ["explosions/dirt-explosion", 80, 75, [.24, 2.1]],
};

const size = 96;
const count = 8;
const opacityFloor = 42;
mkdirSync(target, { recursive: true });
const effects = [];
for (const [key, [id, width, height, window, options, dx = 0]] of Object.entries(replacements)) {
  const originalEntry = byKey.get(key);
  const mod = id.startsWith("local/") ? localEffects[id.slice(6)] : await import(pathToFileURL(join(source, "src/fx", id + ".js")));
  const { size: [w, h], origin: [x, y], duration, loop } = mod.meta;
  const [start, end] = window ?? [0, duration];
  const fullLoop = loop && window === undefined;
  const fx = createFx(mod, { x, y, light: .72, ...options });
  const frame = createFrame(w, h);
  const samples = [];
  let left = w, top = h, right = 0, bottom = 0;
  for (let n = 0; n < count; n++) {
    fx.update(start + (end - start) * n / (fullLoop ? count : count - 1) - fx.t);
    clearFrame(frame);
    // The source strike darkens its demo backdrop in the back layer.
    fx.draw(frame, id === "lightning/lightning-strike" ? "front" : undefined);
    const rgba = composite(frame, new Uint8ClampedArray(w * h * 4));
    samples.push(rgba);
    for (let row = 0; row < h; row++) {
      for (let col = 0; col < w; col++) {
        if (rgba[(row * w + col) * 4 + 3] < opacityFloor) continue;
        left = Math.min(left, col);
        top = Math.min(top, row);
        right = Math.max(right, col + 1);
        bottom = Math.max(bottom, row + 1);
      }
    }
  }
  if (right <= left || bottom <= top) throw new Error(`${key}: no visible frames`);
  const scale = Math.min(width / (right - left), height / (bottom - top));
  const outW = Math.round((right - left) * scale);
  const outH = Math.round((bottom - top) * scale);
  const outX = Math.floor((size - outW) / 2) + dx;
  const outY = Math.floor((size - outH) / 2);
  if (outX < 2 || outY < 2 || outX + outW > size - 2 || outY + outH > size - 2) {
    throw new Error(`${key}: placement crosses the transparent margin`);
  }
  const sheet = new Uint8ClampedArray(size * size * count * 4);
  for (const [index, rgba] of samples.entries()) {
    const opacity = fullLoop ? 1 : [0.88, 1, 1, 1, 0.9, 0.72, 0.48, 0.26][index];
    for (let row = 0; row < outH; row++) {
      for (let col = 0; col < outW; col++) {
        const srcX = left + Math.floor((col + .5) * (right - left) / outW);
        const srcY = top + Math.floor((row + .5) * (bottom - top) / outH);
        const si = (srcY * w + srcX) * 4;
        if (rgba[si + 3] < opacityFloor) continue;
        const di = ((outY + row) * size * count + index * size + outX + col) * 4;
        sheet.set(rgba.subarray(si, si + 4), di);
        sheet[di + 3] *= opacity;
      }
    }
  }
  writeFileSync(join(target, key + ".png"), encodePNG(size * count, size, sheet));
  const durations = originalEntry?.durations ?? (fullLoop ? Array(count).fill(120) : original.effects[0].durations);
  effects.push({ key, source: id, durations });
}
const pattern = localEffects["warning-pattern"];
const indicator = createFrame(96, 96);
createFx(pattern, { x: 48, y: 48 }).draw(indicator);
writeFileSync(join(target, "warning-pattern.png"), encodePNG(96, 96, composite(indicator, new Uint8ClampedArray(96 * 96 * 4))));
writeFileSync(join(target, "manifest.json"), JSON.stringify({
  source: "https://github.com/patch-gg/pixelfx",
  revision: "5294518ce7c72e48b6100a744596e0acf57f2826",
  filter: "nearest",
  frameSize: [size, size],
  pivot: [48, 48],
  frameCount: count,
  effects,
  cueTexture: { file: "warning-pattern.png", source: "local/warning-pattern" },
}, null, 2) + "\n");
console.log(`Wrote ${effects.length} pixelfx sheets to ${target}`);
