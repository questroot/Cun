export function sceneEffects({ hex, rand, sparkle, TAU, tileNoise, WHITE }) {
  const blue = hex("#c4e4f8");
  const violet = hex("#c28ff8");
  const amber = hex("#ffc583");
  const cool = hex("#769fb3");
  const sage = hex("#adc985");
  const loop = draw => ({ meta: { size: [96, 96], origin: [48, 48], duration: 1, loop: true }, draw });
  const once = draw => ({ meta: { size: [96, 96], origin: [48, 48], duration: 1, loop: false }, draw });
  const rust = hex("#684035"), copper = hex("#b47a4b"), ivory = hex("#fff0c5");

  function chain(p, t, split) {
    const tension = Math.sin(Math.min(1, t * 2.3) * Math.PI * .5);
    const power = 1 - Math.max(0, (t - .58) / .42);
    const links = split ? 6 : 12;
    for (const direction of split ? [-1, 1] : [1]) {
      for (let i = 0; i < links; i++) {
        const u = i / (links - 1);
        const x = split ? direction * u * 38 * tension : -38 + u * 76 * tension;
        const y = Math.sin(u * TAU - t * 15) * (1 - tension) * 10;
        const tall = i % 2 ? 1.9 : 4.2;
        p.shade(x - 5, y - tall - 1, x + 5, y + tall + 1, (px, py, out) => {
          const d = Math.hypot((px - x) / 4.8, (py - y) / tall);
          if (d > 1 || d < .53) return;
          out.c = d > .87 ? rust : py < y ? ivory : copper;
          out.a = power;
        });
      }
      const x = split ? 38 * tension * direction : -38 + 76 * tension;
      sparkle(p, x, 0, 4 + 3 * power, ivory, amber, power);
      p.glow(x, 0, 8, amber, power * .38);
    }
  }

  return {
    "rain": loop((p, t) => {
      for (let i = 0; i < 3; i++) {
        const phase = (t + i * .33) % 1;
        const x = (i - 1) * 18 - phase * 8, y = phase * 32 - 20;
        const strength = Math.sin(Math.PI * phase);
        p.line(x - 4, y + 18, x, y, blue, u => strength * (1 - u * .75));
        p.blend(x - 4, y + 18, WHITE, strength * .72);
      }
      const ripple = (t + .3) % 1;
      p.ellipse(4, 23, 3 + 13 * ripple, 1.5 + 4 * ripple, blue, .08 * (1 - ripple));
    }),
    "snow": loop((p, t) => {
      for (let i = 0; i < 3; i++) {
        const phase = TAU * (t + i / 3);
        const x = (i - 1) * 15 + 4 * Math.sin(phase), y = (i - 1) * 11 + 7 * Math.cos(phase);
        const radius = i === 1 ? 7 : 4;
        for (let arm = 0; arm < 6; arm++) {
          const angle = arm * TAU / 6 + t * TAU / 6;
          const dx = Math.cos(angle), dy = Math.sin(angle);
          p.line(x, y, x + radius * dx, y + radius * dy, i === 1 ? WHITE : blue, .76);
          if (i === 1) for (const side of [-1, 1]) {
            p.line(x + 4 * dx, y + 4 * dy, x + 2 * dx - side * dy * 2, y + 2 * dy + side * dx * 2, blue, .60);
          }
        }
        p.glow(x, y, radius + 3, blue, .24);
      }
    }),
    "fog": loop((p, t) => {
      p.shade(-40, -12, 40, 12, (x, y, out) => {
        const bend = 3 * Math.sin(x * .08 + t * TAU) + 2 * Math.sin(x * .17 - t * TAU);
        const spread = Math.max(0, 1 - Math.abs(x) / 40);
        const band = Math.max(0, 1 - Math.abs(y - bend) / (4 + spread * 6));
        const texture = .32 + .68 * tileNoise(x * .16 + t * 8, y * .16, 8, 64, 12);
        out.c = band > .75 ? blue : cool;
        out.a = band * spread * texture * .87;
      });
    }),
    "wind": loop((p, t) => {
      for (let i = 0; i < 3; i++) {
        const phase = TAU * (t + i / 3), x = (i - 1) * 21 + 7 * Math.sin(phase), y = (i - 1) * 9 + 4 * Math.cos(phase);
        const curl = Math.sin(phase), length = 6 + i * 3;
        p.line(x - length * 2, y + 3, x, y, sage, u => .42 * u);
        p.ellipse(x + 2, y - 1, 4 + 2 * Math.abs(curl), 2 + Math.abs(curl), sage, .85);
        p.line(x - 2, y + 1, x + 5, y - 2, amber, .58);
      }
    }),
    "embers": loop((p, t) => {
      for (let i = 0; i < 6; i++) {
        const age = (t + rand(i, 8)) % 1, power = Math.sin(age * Math.PI);
        const x = (rand(i, 21) - .5) * 47 + 6 * Math.sin(age * TAU), y = 19 - age * (18 + rand(i, 9) * 26);
        p.line(x - 2, y + 4, x, y, amber, u => .52 * power * u);
        p.blend(x, y, amber, power);
        p.glow(x, y, 6, amber, power * .47);
      }
    }),
    "sun-motes": loop((p, t) => {
      for (let i = 0; i < 3; i++) {
        const phase = TAU * (t + i / 3), x = (i - 1) * 20 + 4 * Math.sin(phase), y = 9 * Math.cos(phase + i);
        const power = .40 + .35 * Math.cos(phase);
        sparkle(p, x, y, 3 + 4 * power, WHITE, amber, power);
        p.glow(x, y, 10, amber, .26 * power);
      }
    }),
    "loot-glint": loop((p, t) => {
      const phase = t * TAU;
      sparkle(p, 0, -3, 7 + 3 * Math.cos(phase), WHITE, violet, .8);
      p.glow(0, -3, 12, violet, .53);
      for (let i = 0; i < 4; i++) {
        const angle = phase + i * TAU / 4;
        p.blend(Math.cos(angle) * 13, Math.sin(angle) * 11 - 3, violet, .9);
      }
    }),
    "stone-shot": loop((p, t) => {
      const phase = TAU * t;
      const shift = Math.cos(phase) * 2;
      p.shade(-18, -13, 18, 13, (x, y, out) => {
        const d = Math.hypot((x - shift) / 12, y / 9);
        if (d > 1) return;
        const facet = tileNoise(x * .3 + t * 8, y * .32, 8, 64, 19);
        out.c = d > .87 ? hex("#53392d") : y + facet * 7 < 0 ? hex("#c68956") : hex("#966345");
      });
      for (let i = 0; i < 6; i++) {
        const age = (t * 2 + i / 6) % 1, x = -14 - 28 * age, y = Math.sin(i + phase) * (3 + age * 7);
        p.line(x - 4, y + 1, x, y, amber, .75 * (1 - age));
      }
      p.glow(-17, 0, 13, amber, .35);
    }),
    "rust-chain": once((p, t) => chain(p, t, false)),
    "pendulum-chain": once((p, t) => chain(p, t, true)),
    "seed-burst": once((p, t) => {
      const split = Math.max(0, Math.min(1, (t - .29) / .53));
      const power = 1 - Math.max(0, (t - .64) / .36);
      const y = 14 - 31 * Math.max(0, 1 - t / .36);
      for (const side of [-1, 1]) {
        const cx = side * (3 + split * 9), cy = y - split * 7;
        p.shade(cx - 11, cy - 14, cx + 11, cy + 14, (x, y, out) => {
          const sy = (y - cy) / 12;
          const sx = (x - cx - sy * side * split * 6) / 8;
          const d = Math.hypot(sx, sy);
          if (d > 1) return;
          out.c = d > .86 ? hex("#344437") : sx + sy < -.28 ? sage : hex("#698456");
          out.a = power;
        });
      }
      for (let i = 0; i < 12; i++) {
        const angle = i * TAU / 12;
        const distance = split * (18 + rand(i, 13) * 15);
        p.blend(Math.cos(angle) * distance, y + Math.sin(angle) * distance * .67, sage, split * power);
      }
      if (split > 0) p.glow(0, y, 14 + split * 12, sage, (1 - split) * .65);
    }),
    "war-flag": {
      meta: { size: [96, 96], origin: [48, 56], duration: 1, loop: false },
      draw(p, t) {
        const raise = Math.min(1, t * 8);
        const heat = Math.sin(t * Math.PI);
        const top = 12 - raise * 49;
        p.line(-8, 13, -8, top, hex("#713d48"), 1);
        p.line(-9, 13, -9, top, amber, .72);
        p.shade(-7, top, 28, top + 27, (x, y, out) => {
          const fold = Math.sin(x * .19 - t * 19);
          const cloth = y - top - Math.max(0, x) * .12 - fold * 3;
          if (cloth < 0 || cloth > 22 - Math.max(0, x - 15) * .40) return;
          out.c = cloth < 2 || cloth > 18 ? hex("#db8b5d") : fold > .2 ? hex("#bc504f") : hex("#752e43");
          if (Math.abs(x - 5) + Math.abs(cloth - 10) < 5) out.c = amber;
        });
        sparkle(p, -8, top, 4, WHITE, amber, .50 + .4 * heat);
        p.glow(-8, 12, 22, hex("#ef6656"), .48 * heat);
      },
    },
    "warning-pattern": loop((p, t) => {
      p.shade(-45, -45, 45, 45, (x, y, out) => {
        const vein = Math.sin(x * .13 + y * .20 + Math.sin(y * .075 + t * TAU) * .65);
        const detail = tileNoise(x * .23, y * .23, 96, 96, 31);
        out.c = WHITE;
        out.a = .61 + .19 * Math.max(0, vein) + .16 * detail;
      });
    }),
  };
}
