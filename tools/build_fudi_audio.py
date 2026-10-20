"""Reproducible original synth score and Foley. Requires numpy; no samples/network.

Legacy v1 only: python tools/build_fudi_audio.py --legacy-v1
Current orchestral music: tools/build_fudi_orchestra.py (preserves Foley).
PCM stereo WAVs are directly editable/importable in Godot. All echo tails wrap
around the musical period, so loops retain their ambience across the seam.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'card-demo/assets/audio'
SR = 22050
TAU = 2 * np.pi
RNG = np.random.default_rng(20261020)
RECORDS = []
# id, Chinese title, bpm, tonic MIDI, lead timbre, contour (scale degrees)
MAPS = [
    ('grove', '灶火与青岚', 80, 62, 'pluck', [0, 1, 2, 4, 2, 1, 0, -1]),
    ('post', '未寄出的信', 76, 57, 'felt', [2, 4, 5, 4, 1, 2, 0, -1]),
    ('quarry', '赤岩晚钟', 84, 50, 'bell', [0, 2, 1, -1, 0, 4, 2, 1]),
    ('ruins', '灵泉旧记录', 78, 60, 'glass', [4, 2, 5, 4, 1, 0, 2, 1]),
    ('refuge', '循光归航', 86, 55, 'felt', [0, 2, 4, 5, 4, 2, 1, 0]),
    ('wetland', '雨灯浮水', 72, 65, 'glass', [2, 1, 0, 4, 2, 5, 4, 1]),
    ('causeway', '断桥彼岸', 88, 59, 'pluck', [0, 2, 1, 4, 5, 4, 2, -1]),
    ('kilnwood', '松烟余温', 82, 53, 'wood', [0, 1, 4, 2, 0, -1, 1, 2]),
    ('archive', '镜沙残页', 74, 61, 'glass', [4, 5, 2, 1, 4, 2, 0, -1]),
    ('snowridge', '霜脊信标', 70, 58, 'felt', [0, 4, 5, 2, 4, 1, 0, -1]),
]
BOSSES = [
    ('H01', '残旗急阵', 132, 50, 'strings', [0, 0, 4, 3, 1, 0, -1, 1]),
    ('H02', '荆冠逐猎', 124, 57, 'wood', [0, 2, 4, 2, 5, 4, 2, 1]),
    ('H03', '沉潜铁潮', 112, 46, 'brass', [0, -1, 0, 3, 1, 0, 4, 3]),
    ('H04', '灰翼裁决', 144, 55, 'strings', [0, 4, 7, 6, 4, 3, 1, 0]),
    ('H05', '霜文封印', 120, 60, 'glass', [0, 1, 4, 3, 6, 4, 1, -1]),
    ('H06', '锈钟震鸣', 116, 48, 'bell', [0, 0, 3, 1, -1, 0, 4, 3]),
]


def tone(midi, duration, voice):
    t = np.arange(max(1, round(duration * SR))) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    phase = TAU * f * t
    if voice in ('pluck', 'wood', 'felt'):
        y = sum(np.sin(phase * h) * np.exp(-t * (1.7 + h * 0.8)) / h ** 1.6 for h in range(1, 7))
        y *= np.exp(-t * (1.0 if voice == 'felt' else 2.6))
    elif voice in ('bell', 'glass'):
        ratios = (1, 2.01, 3.98, 5.41) if voice == 'bell' else (1, 2, 3, 6.02)
        y = sum(np.sin(phase * r) * np.exp(-t * (1.2 + i * 1.4)) / (i + 1) ** 1.7 for i, r in enumerate(ratios))
    elif voice == 'pad':
        y = (np.sin(phase) + .3 * np.sin(phase * 1.002) + .18 * np.sin(phase * 2)) * np.sin(np.pi * np.minimum(t / duration, 1)) ** .7
    else:
        y = sum(np.sin(phase * h + .018 * h * np.sin(TAU * 4.1 * t)) / h ** 1.4 for h in range(1, 8))
        y *= np.exp(-t * (3.5 if voice == 'strings' else 2.0))
    edge = min(.035 if voice == 'pad' else .008, duration / 4)
    y *= np.minimum(1, t / edge) * np.minimum(1, np.maximum(0, duration - t) / .045)
    return y.astype(np.float32)


def add(buf, sound, at, gain=.1, pan=0):
    idx = (np.arange(len(sound)) + round(at * SR)) % len(buf)
    buf[idx, 0] += sound * gain * np.sqrt((1 - pan) / 2)
    buf[idx, 1] += sound * gain * np.sqrt((1 + pan) / 2)


def drum(kind, duration=.3):
    t = np.arange(round(SR * duration)) / SR
    noise = RNG.standard_normal(len(t))
    if kind == 'kick':
        return (.85 * np.sin(TAU * (46 * t + 3.2 * (1 - np.exp(-t * 25)))) * np.exp(-t * 17)).astype(np.float32)
    if kind == 'rim':
        return ((np.sin(TAU * 430 * t) + .5 * noise) * np.exp(-t * 65) * np.minimum(t * 2000, 1)).astype(np.float32)
    return ((noise - np.roll(noise, 1)) * np.exp(-t * 90) * .14).astype(np.float32)


def save(name, title, buf, category, **meta):
    peak = float(np.max(np.abs(buf)))
    buf *= (.72 if category == 'music' else .56) / max(peak, .001)
    # Avoid a discontinuity at the PCM boundary without fading the whole phrase.
    if meta.get('loop'):
        n = min(220, len(buf) // 4)
        join = (buf[-1] + buf[0]) / 2
        ramp = np.linspace(0, 1, n)[:, None]
        buf[:n] = join * (1 - ramp) + buf[:n] * ramp
        buf[-n:] = buf[-n:] * (1 - ramp) + join * ramp
    else:
        n = min(220, len(buf) // 4)
        buf[:n] *= np.linspace(0, 1, n)[:, None]
        buf[-n:] *= np.linspace(1, 0, n)[:, None]
    target = OUT / category / (name + '.wav')
    target.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(buf, -.99, .99) * 32767).astype('<i2')
    with wave.open(str(target), 'wb') as w:
        w.setparams((2, 2, SR, 0, 'NONE', 'not compressed'))
        w.writeframes(pcm.tobytes())
    RECORDS.append(dict(id=name, title=title, path=target.relative_to(OUT).as_posix(), seconds=round(len(buf)/SR, 3),
                        peak_db=round(20*np.log10(max(float(np.max(np.abs(buf))), 1e-9)), 2),
                        rms_db=round(20*np.log10(max(float(np.sqrt(np.mean(buf**2))), 1e-9)), 2),
                        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), **meta))
    print(f'{name}: {len(buf)/SR:.1f}s', flush=True)


def score(spec, boss=False):
    ident, title, bpm, tonic, voice, melody = spec
    beat = 60 / bpm
    buf = np.zeros((round(64 * beat * SR), 2), np.float32)
    scale = [0, 2, 3, 5, 7, 8, 10] if boss else [0, 2, 4, 7, 9]
    def note(degree):
        octv, ix = divmod(degree, len(scale))
        return tonic + scale[ix] + octv * 12
    chords = [0, -2, 1, -1] if boss else [0, -1, 2, 1]
    for bar in range(16):
        base = chords[(bar // 2) % 4]
        start = bar * 4 * beat
        for deg in (base, base + 2, base + 4):
            add(buf, tone(note(deg), 5 * beat, 'pad'), start, .054 if boss else .08, (deg - base - 2) * .24)
        for b in range(4 if boss else 2):
            add(buf, tone(note(base) - 24, beat * 1.6, 'felt'), start + b * (beat if boss else beat*2), .2 if boss else .12)
        for step in range(8):
            if not boss and step % 3 == 2:
                continue
            deg = base + [0, 2, 4, 2, 1, 2, 4, 2][(step + bar % 2) % 8]
            add(buf, tone(note(deg)+12, beat * 1.8, 'pluck'), start + step * beat / 2, .065 if boss else .07, (-1 if step % 2 else 1) * .38)
        for part in range(2):
            deg = melody[(bar * 2 + part) % 8]
            if bar >= 8:
                deg += 2 if bar % 4 == 2 else 0
            add(buf, tone(note(deg) + 12, beat * (1.4 if boss else 2.8), voice), start + part * 2 * beat, .19 if boss else .14, .14)
        if boss:
            for b in (0, 1.5, 2, 3.5):
                add(buf, drum('kick'), start + b * beat, .4)
            for b in (1, 3):
                add(buf, drum('rim'), start + b * beat, .2, -.12)
            for b in range(8):
                add(buf, drum('hat', .1), start + b * beat / 2, .12, .5)
        elif bar % 2 == 0:
            add(buf, drum('rim'), start + 3 * beat, .055, -.4)
    dry = buf.copy()
    for delay, gain in [(beat * .75, .19), (beat * 1.5, .10), (beat * 2.25, .05)]:
        buf += np.roll(dry[:, ::-1], round(delay * SR), axis=0) * gain
    save(('boss_' if boss else 'map_') + ident, title, buf, 'music', bpm=bpm, bars=16, loop=True)


def ambience(kind):
    duration = 12
    n = duration * SR
    noise = RNG.standard_normal(n)
    # Periodic FFT filtering creates continuous, band limited environmental beds.
    freq = np.fft.rfftfreq(n, 1/SR)
    spectrum = np.fft.rfft(noise)
    low = np.fft.irfft(spectrum / (1 + (freq/360)**2), n=n)
    high = np.fft.irfft(spectrum * (freq/(freq+900)) / (1+(freq/6500)**4), n=n)
    t = np.arange(n)/SR
    if kind == 'rain':
        y = high*.45 + low*.12
    elif kind == 'water':
        y = low * (.5+.16*np.sin(TAU*t/4)) + high*.035
    elif kind == 'fire':
        y = low*.55 + high * np.maximum(0, np.sin(TAU*t*7/12))**28 * .25
    elif kind == 'forest':
        y = low*.22 + high*.025
    else:
        y = low * (.5+.22*np.sin(TAU*t/12)) + high*.015
    buf = np.stack((y, np.roll(y, 137)), axis=1).astype(np.float32)
    if kind == 'forest':
        for at in (1.3, 4.1, 8.7):
            tt = np.arange(round(.24*SR))/SR
            chirp = np.sin(TAU*(2100*tt+230*tt**2))*np.sin(np.pi*tt/.24)**2
            add(buf, chirp, at, .055, -.5)
    save('amb_'+kind, kind, buf, 'ambience', loop=True)


def sfx():
    for kind in ('step_grass','step_stone','step_water','step_snow','slash','cast','slam','hit','hurt','pickup','warning','boss_down','chest','discovery','victory','defeat','thunder'):
        duration = 2.8 if kind in ('victory','defeat','thunder') else 1.5 if kind in ('boss_down','discovery','chest') else .65 if kind in ('slam','cast','warning') else .22
        buf = np.zeros((round(duration*SR), 2), np.float32)
        t = np.arange(len(buf))/SR
        noise = RNG.standard_normal(len(t))
        if kind in ('pickup','cast','warning','chest','discovery','victory','defeat','boss_down'):
            notes = {'pickup':[81,88], 'cast':[74,86], 'warning':[70,70,70], 'chest':[62,69,74,78], 'discovery':[69,74,78,81], 'victory':[62,66,69,74,78], 'defeat':[62,60,57,50], 'boss_down':[57,64,69,76]}[kind]
            for i, pitch in enumerate(notes):
                at = i*duration/(len(notes)+2)
                add(buf, tone(pitch, duration-at, 'bell' if kind=='warning' else 'felt'), at, .4, (i/len(notes)-.5)*.5)
        else:
            rate = 40 if kind.startswith('step') else 24 if kind in ('slash','hit') else 5
            filtered = np.convolve(noise, np.ones(13 if kind in ('thunder','slam','step_snow') else 3)/ (13 if kind in ('thunder','slam','step_snow') else 3), mode='same')
            y = filtered*np.exp(-t*rate)
            if kind in ('slam','hurt','boss_down','thunder','step_stone'):
                y += np.sin(TAU*(55*t+1.4*(1-np.exp(-25*t))))*np.exp(-t*rate*.7)*.6
            if kind == 'step_water':
                y += np.sin(TAU*(900*t+110*t*t))*np.exp(-t*35)*.12
            buf[:,0] = y
            buf[:,1] = y*.94
        save(kind, kind, buf, 'sfx', loop=False)


if __name__ == '__main__':
    import sys
    if '--legacy-v1' not in sys.argv:
        raise SystemExit('This is the legacy short-loop synthesizer. Use tools/build_fudi_orchestra.py for the current score. --legacy-v1 explicitly restores the old audio set.')
    for spec in MAPS:
        score(spec)
    for spec in BOSSES:
        score(spec, True)
    for kind in ('forest','rain','water','fire','wind'):
        ambience(kind)
    sfx()
    (OUT/'manifest.json').write_text(json.dumps({'version':1,'sample_rate':SR,'channels':2,'bits':16,
        'source':'Original procedural composition and synthesis; tools/build_fudi_audio.py; seed 20261020; no external samples.',
        'assets':RECORDS}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
