"""Render the authored orchestral score using GeneralUser GS 2.0.3.

Dependencies: numpy scipy tinysoundfont==0.3.7 soundfile.
SoundFont path is explicit; no network access or automatic downloads.
Default output is a staging directory, never the live assets. --publish replaces
only the sixteen music files and their metadata after all renders succeed.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import html
import json
import math
from pathlib import Path
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
if (ROOT / '.local/audio-tools').is_dir():
    sys.path.insert(0, str(ROOT / '.local/audio-tools'))
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
import soundfile as sf
import tinysoundfont
from fudi_orchestra_scores import SCORES

SR = 44100
SF_HASH = '9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe'
# name: channel, zero-based GM program, pan, volume. Actual sampled instruments.
INSTRUMENTS = {
    'strings': (0, 48, 43, 76), 'violin': (1, 40, 35, 83),
    'viola': (2, 41, 54, 65), 'cello': (3, 42, 76, 83),
    'bass': (4, 43, 83, 74), 'flute': (5, 73, 49, 87),
    'oboe': (6, 68, 58, 81), 'clarinet': (7, 71, 69, 85),
    'bassoon': (8, 70, 78, 86), 'timpani': (15, 47, 84, 86),
    'horn': (10, 60, 88, 77), 'trombone': (11, 57, 96, 72),
    'harp': (12, 46, 28, 86), 'celesta': (13, 8, 60, 77),
    'glock': (14, 9, 70, 70), 'percussion': (9, 48, 83, 75),
    'piano': (-1, 0, 58, 100), 'nylon_guitar': (-1, 24, 37, 102),
    'steel_guitar': (-1, 25, 45, 96), 'clean_guitar': (-1, 27, 39, 96),
    'distortion_guitar': (-1, 30, 40, 82), 'electric_bass': (-1, 33, 66, 103),
    'overdrive_guitar': (-1, 29, 84, 77),
}
SECTIONS = [('序奏', 8, .50, .96), ('主题A', 16, .74, 1),
            ('展开与对答', 8, .65, 1.015), ('主题B', 16, .88, 1.025),
            ('再现与高潮', 8, 1, 1.015), ('尾声与回环', 8, .55, .97)]


def parse_theme(text, beats):
    result = []
    for bar in text.split('|'):
        notes = []
        for token in bar.split():
            degree, duration = token.split(':')
            notes.append((None if degree == 'r' else int(degree), float(duration)))
        assert abs(sum(n[1] for n in notes) - beats) < 1e-9, bar
        result.append(notes)
    assert len(result) == 8
    return result


def arrange(score):
    """Musically timed note score; no audio or random melody generation here."""
    rng = np.random.default_rng(20261021 + sum(ord(c) for c in score['id']))
    a = parse_theme(score['theme_a'], score['beats'])
    b = parse_theme(score['theme_b'], score['beats'])
    sections = list(SECTIONS)
    if score['boss']:
        sections[4] = ('再现与交响高潮', 16, 1.12, 1.045)
    events, notes, marks = [], [], []
    beat_cursor, sec_cursor, bar_number = 0., 0., 0
    counts = Counter()
    instruments = {}
    free_channels = iter(ch for ch in range(16) if ch != 9)
    scale, tonic, meter = score['scale'], score['tonic'], score['beats']
    def pitch(degree, octave=0):
        octv, index = divmod(degree, 7)
        return tonic + scale[index] + 12 * (octv + octave)
    def near(midi, center):
        return midi + 12 * round((center - midi) / 12)

    for section_index, (name, bars, energy, tempo_factor) in enumerate(sections):
        marks.append(dict(name=name, bar=bar_number, seconds=round(sec_cursor, 3), bpm=round(score['bpm']*tempo_factor, 3)))
        for local in range(bars):
            # Long, subtle phrase breathing rather than sample-accurate repetition.
            qsec = 60 / (score['bpm'] * tempo_factor * (1 + .012 * math.sin(local * math.pi / 4)))
            if section_index == 5 and local >= bars - 2:
                qsec *= 1.035
            bar_start, bar_beat = sec_cursor, beat_cursor
            harmony = score['harmony_b'] if section_index in (2, 3) else score['harmony_a']
            degree = harmony[local % 8]
            if section_index == 5 and local >= bars - 2:
                degree = 4 if local == bars - 2 else 0
            chord = [pitch(degree + d) for d in (0, 2, 4)]
            phrase_swell = .85 + .15 * math.sin((local % 8 + .5) * math.pi / 8)
            dynamic = energy * phrase_swell

            def put(instrument, midi, offset, duration, velocity=70, articulation=.93, exposed=False):
                if midi is None:
                    return
                if section_index == 0 and local < 4 and not exposed:
                    return
                if instrument not in instruments:
                    _, program, pan, volume = INSTRUMENTS[instrument]
                    ch = 9 if instrument == 'percussion' else next(free_channels)
                    if instrument == 'percussion' and score['boss']:
                        program = 0  # Standard rock kit, not the orchestral bank's kit.
                    instruments[instrument] = (ch, program, pan, volume)
                ch = instruments[instrument][0]
                assert 24 <= midi <= 104, (score['id'], instrument, midi)
                offset = max(0, offset)
                human = float(rng.uniform(0, .014))
                start = bar_start + offset * qsec + human
                end = start + max(.065, duration*qsec*articulation)
                # Exposed instruments need foreground velocity; a decaying bell
                # otherwise disappears under the later orchestra's peak scaling.
                note_dynamic = max(dynamic, 1.0 if instrument == 'glock' else .82) if exposed else dynamic
                vel = int(np.clip(velocity * note_dynamic + rng.normal(0, 2.4), 20, 117))
                events.extend([(start, 1, ch, int(midi), vel), (end, 0, ch, int(midi), 0)])
                notes.append((bar_beat + offset, duration*articulation, ch, int(midi), vel))
                counts[instrument] += 1

            # Double bass and cello form separate bass and tenor voices.
            bass_note = near(chord[0], 42)
            if not score['boss']:
                put('bass', bass_note, 0, meter, 65)
            elif score['lead'] != 'electric_bass':
                steps = [0, 1.5] if meter == 3 else [0, 1, 2.5] if meter == 3.5 else [0, 1.5, 3] if meter == 5 else [0, 1.5, 2, 3.5]
                for t in steps:
                    if t < meter:
                        put('electric_bass', bass_note, t, min(.7, meter-t), 90, .8)
            if score['boss']:
                pass  # The guitar and electric bass supply the rhythm section below.
            elif score['texture'] in ('waltz', 'boat', 'bells', 'hunt'):
                put('cello', near(chord[0], 50), 0, 1.4, 76)
                put('cello', near(chord[2], 51), meter/2, meter/2-.08, 61)
            elif score['texture'] in ('blades', 'siege', 'judgement', 'journey') and section_index not in (0, 5):
                for t in np.arange(0, meter, .5 if score['boss'] else 1):
                    put('cello', near(chord[int(t)%3], 50), float(t), .4, 78, .67)
            else:
                put('cello', near(chord[0], 51), 0, meter, 69)
            # Sustained orchestral voicing; two harmonic positions per long bar.
            if score['texture'] == 'waltz' and section_index not in (0, 5):
                for t in (1, 2):
                    for n in chord:
                        put('strings', near(n, 65), t, .68, 56, .85)
            else:
                for i, n in enumerate(chord):
                    put('strings' if i != 1 else 'viola', near(n, 65 if i != 1 else 57), 0, meter+.10, 57 if section_index < 4 else 69)

            # Harp patterns differ by place: water rolls, town waltz, open snow air.
            if score['texture'] in ('boat', 'ripples'):
                offsets = np.arange(0, meter, .5)
            elif score['texture'] in ('waltz', 'counterpoint', 'fugue'):
                offsets = [0, meter/2, meter-.5]
            elif score['texture'] in ('forge', 'siege', 'bells', 'embers'):
                offsets = [0, meter-.5] if local % 2 == 0 else []
            else:
                offsets = [0, 1, meter-1] if section_index in (1, 3, 4) else [0]
            for i, offset in enumerate(offsets):
                n = near(chord[(i + local) % 3], 70) + (12 if i % 4 == 3 else 0)
                if not score['boss']:
                    put('harp', n, float(offset), 1.6, 66)

            # Written melodies: exposed solos, new second theme, developed restatement.
            theme = b if section_index in (2, 3) else a
            melody = theme[local % 8]
            lead = score['lead']
            if section_index == 0:
                lead = score['opener'] if local < 4 else score['lead']
            elif section_index == 3:
                lead = score['partner'] if (local//4) % 2 == 0 else score['lead']
            elif section_index == 4:
                lead = 'strings' if score['lead'] != 'horn' else 'horn'
            cursor = 0.
            for index, (d, duration) in enumerate(melody):
                play = True
                play = play and not (section_index == 5 and local >= 4)
                if d is not None and play:
                    # In the development, sequence the motif then answer down a third.
                    shift = (2 if local % 4 < 2 else -2) if section_index == 2 else 0
                    # Phrase endings in the A' restatement are rewritten towards the cadence.
                    if section_index == 1 and local >= 8 and index == len(melody)-1:
                        shift = (1 if local % 4 == 0 else -1) if local % 4 < 2 else 0
                    center = {'bassoon':60, 'cello':60, 'horn':65, 'trombone':58, 'oboe':73, 'clarinet':70,
                              'electric_bass':48, 'distortion_guitar':59, 'nylon_guitar':66,
                              'steel_guitar':67, 'clean_guitar':69, 'piano':69, 'glock':85}.get(lead, 76)
                    register = 12 * round((center - (tonic + 5)) / 12)
                    n = pitch(d+shift) + register
                    put(lead, n, cursor, duration, 105 if score['boss'] else 94,
                        .72 if lead == 'distortion_guitar' else .93,
                        exposed=section_index == 0 and local < 4)
                    if section_index == 4 and local >= 4:
                        put('horn' if lead != 'horn' else 'violin', near(n, 68 if lead != 'horn' else 80), cursor+.025, duration, 57)
                cursor += duration

            # Six deliberately different guitar/drum grooves; the orchestra joins
            # after the exposed solo, retaining the individual Boss motif.
            if score['boss'] and section_index != 5:
                guitar = score['rhythm_guitar']
                if score['texture'] == 'hunt':
                    strokes = [(0,.7), (1,.35), (1.5,.7), (2.5,.35)]
                elif score['texture'] == 'siege':
                    strokes = [(0,.6), (.75,.2), (1.5,.3), (3,.7)]
                elif score['texture'] == 'judgement':
                    strokes = [(float(t),.42) for t in np.arange(0,meter,.5)]
                elif score['texture'] == 'fugue':
                    strokes = [(0,.4), (.75,.2), (1.5,.4), (2.5,.4), (3,.4)]
                elif score['texture'] == 'bells':
                    strokes = [(0,2.7)]
                else:
                    strokes = [(0,.2), (.5,.4), (1.5,.4), (2.5,.2), (3,.4), (4,.7)]
                for i,(t,dur) in enumerate(strokes):
                    root = near(chord[0], 52)
                    if guitar == 'clean_guitar':
                        put(guitar, near(chord[i%3],64), t, dur, 83)
                    else:
                        # Power fifths for the electric guitar; full acoustic triads.
                        voicing = [near(n,58) for n in chord] if guitar == 'nylon_guitar' else [root,root+7]
                        for j,n in enumerate(voicing):
                            put(guitar,n,t+j*.018,dur,85,.8)
                if section_index in (1,2,3,4) or (section_index == 0 and local >= 6):
                    if score['texture'] == 'hunt':
                        kicks,snares,hats = [0,2], [1.5], np.arange(0,meter,.5)
                    elif score['texture'] == 'siege':
                        kicks,snares,hats = [0,.75,3.5], [2], np.arange(0,meter,.5)
                    elif score['texture'] == 'judgement':
                        kicks,snares,hats = [0,.5,2,2.5], [1,3], np.arange(0,meter,.5)
                    elif score['texture'] == 'fugue':
                        kicks,snares,hats = [0,1.5,3], [1,2.5], np.arange(0,meter,.5)
                    elif score['texture'] == 'bells':
                        kicks,snares,hats = [0], [2], [0,1,2]
                    else:
                        kicks,snares,hats = [0,.5,2.5,4], [1.5,3.5], np.arange(0,meter,.5)
                    for t in kicks:put('percussion',36,t,.12,108)
                    for t in snares:put('percussion',38,t,.12,103)
                    for i,t in enumerate(hats):
                        put('percussion',51 if score['texture']=='bells' else 42,float(t),.09,58+(i%2)*13)

            # Independent woodwind/bowed countermelody in gaps or across the bar.
            if section_index in (1, 2, 3, 4) and (local % 2 or score['texture'] in ('counterpoint', 'fugue')):
                partner = score['partner'] if score['partner'] != lead else ('flute' if lead != 'flute' else 'oboe')
                count = 3 if score['texture'] in ('counterpoint', 'fugue') else 2
                for i in range(count):
                    at = .5 + i*(meter-1)/count
                    n = near(pitch(degree + [4, 2, 1][i]), 66 if partner in ('horn','cello','bassoon') else 77)
                    put(partner, n, at, (meter-1)/count*.94, 62)

            # Brass chorales and carefully spaced percussion build the concert arc.
            if section_index in (3, 4) and local % 4 in (0, 2):
                for n in chord[:2]:
                    put('horn', near(n, 63), .05, meter-.2, 57 if not score['boss'] else 76)
                if score['boss'] or score['texture'] in ('forge', 'mountain', 'hymn'):
                    put('trombone', near(chord[0], 51), .05, meter-.2, 62)
            if score['boss'] and section_index not in (0, 5):
                accents = [0, 1.5] if meter == 3 else [0, 2] if meter == 3.5 else [0, 2, 3.5] if meter == 5 else [0, 2]
                for t in accents:
                    put('timpani', near(chord[0], 43), t, .5, 82, .8)
                if local % 8 == 0:
                    put('percussion', 49, .03, 2, 63)
                if local % 8 == 7:
                    for t in np.arange(max(0, meter-1), meter, .25):
                        put('timpani', near(chord[0],43), float(t), .16, 55+int(t/meter*30), .7)
            elif score['texture'] in ('forge','bells') and local % 4 == 0:
                put('timpani', near(chord[0],43), 0, 1, 55)
            if score['texture'] in ('ripples','counterpoint','fugue','bells','forge'):
                if local % (2 if score['texture'] in ('forge','bells') else 4) == 0:
                    put('glock' if score['texture'] in ('bells','forge') else 'celesta', near(chord[2],86), meter-.5, 2, 53)
            elif score['texture'] in ('boat','waltz','mountain') and local % 8 == 6:
                put('percussion', 81, meter/2, 1.5, 49)
            # Closing dominant-to-tonic cadence thins back to the opening ensemble.
            if section_index == 5 and local >= bars-2:
                for n in chord:
                    put(score['partner'], near(n,67), 0, meter-.08, 63)
            sec_cursor += meter*qsec
            beat_cursor += meter
            bar_number += 1
    return dict(events=sorted(events), notes=notes, sections=marks, seconds=sec_cursor, instruments=instruments,
                bars=bar_number, counts=dict(counts), total_beats=beat_cursor)


def vlq(value):
    out = [value & 127]
    while value >> 7:
        value >>= 7
        out.insert(0, (value & 127) | 128)
    return bytes(out)


def write_midi(path, score, arrangement):
    """Editable multitrack MIDI with instrument names, meter and section tempi."""
    tracks = []
    num, den = map(int,score['meter'].split('/'))
    conductor = [(0, b'\xff\x58\x04'+bytes([num,int(math.log2(den)),24,8]))]
    for section in arrangement['sections']:
        tick = round(section['bar']*score['beats']*480)
        tempo = round(60000000/section['bpm'])
        label = section['name'].encode('utf-8')
        conductor.extend([(tick,b'\xff\x51\x03'+tempo.to_bytes(3,'big')), (tick,b'\xff\x06'+vlq(len(label))+label)])
    def chunk(events):
        data, previous = bytearray(), 0
        for tick, payload in sorted(events,key=lambda x:x[0]):
            data.extend(vlq(tick-previous)+payload);previous=tick
        data.extend(b'\x00\xff\x2f\x00')
        return b'MTrk'+len(data).to_bytes(4,'big')+data
    tracks.append(chunk(conductor))
    for name,(ch,prog,pan,vol) in arrangement['instruments'].items():
        label=name.encode()
        ev=[(0,b'\xff\x03'+vlq(len(label))+label),(0,bytes([0xb0+ch,0,0])),
            (0,bytes([0xc0+ch,prog])),(0,bytes([0xb0+ch,10,pan])),(0,bytes([0xb0+ch,7,vol]))]
        for start,duration,channel,midi,vel in arrangement['notes']:
            if channel==ch:
                ev.extend([(round(start*480),bytes([0x90+ch,midi,vel])),(round((start+duration)*480),bytes([0x80+ch,midi,0]))])
        tracks.append(chunk(ev))
    path.write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(tracks),480)+b''.join(tracks))


def render(score, arrangement, bank, folder):
    synth=tinysoundfont.Synth(gain=-10,samplerate=SR)
    # Bytes support Unicode workspaces, unlike the native narrow-path loader.
    sfid=synth.sfload(bank,max_voices=512)
    for name,(ch,prog,pan,vol) in arrangement['instruments'].items():
        synth.program_select(ch,sfid,128 if name=='percussion' else 0,prog)
        synth.control_change(ch,10,pan)
        synth.control_change(ch,7,vol)
    count=round(arrangement['seconds']*SR)
    tail=SR*3
    buf=np.zeros((count+tail,2),np.float32)
    position=0
    for sec,kind,ch,midi,vel in arrangement['events']:
        at=min(len(buf),round(sec*SR))
        if at>position:
            buf[position:at]=np.frombuffer(synth.generate(at-position),np.float32).reshape(-1,2)
            position=at
        if kind:synth.noteon(ch,midi,vel)
        else:synth.noteoff(ch,midi)
    if position<len(buf):
        buf[position:]=np.frombuffer(synth.generate(len(buf)-position),np.float32).reshape(-1,2)
    synth.sounds_off()
    synth.sfunload(sfid)
    # Broad concert dynamics: swell into the returning tutti, then let it recede.
    # Smooth time anchors avoid audible level steps at structural boundaries.
    anchors,levels=[0.0],[.88]
    for i,section in enumerate(arrangement['sections']):
        target=[.88,1.0,.96,1.04,1.48,.88][i]
        at=section['seconds']
        if at>0:
            anchors.extend([max(anchors[-1]+.01,at-1.2),at+1.2])
            levels.extend([levels[-1],target])
    anchors.append(len(buf)/SR);levels.append(.88)
    envelope=np.interp(np.arange(len(buf))/SR,anchors,levels).astype(np.float32)
    buf*=envelope[:,None]
    # Concert-room early reflections and diffuse reverb, never a rhythmic delay.
    room_rng=np.random.default_rng(91021)
    irlen=round(SR*1.45)
    t=np.arange(irlen)/SR
    for channel in range(2):
        ir=(room_rng.standard_normal(irlen)*np.exp(-t*5.6)*.00032).astype(np.float32)
        ir[:round(.035*SR)]=0
        for delay,gain in [(.043,.10),(.071,.07),(.109,.045),(.173,.025)]:
            ir[round((delay+channel*.007)*SR)]+=gain
        buf[:,channel]+=fftconvolve(buf[:,channel],ir,mode='full')[:len(buf)]
    buf=sosfilt(butter(2,35,'highpass',fs=SR,output='sos'),buf,axis=0).astype(np.float32)
    # Keep the opening solo clean: no closing orchestra folded into its first notes.
    # A short release at the resolved cadence connects back to the next solo attack.
    buf=buf[:count]
    fade=round(.65*SR)
    buf[-fade:]*=np.linspace(1,0,fade,dtype=np.float32)[:,None]
    peak=float(np.max(np.abs(buf)))
    assert peak>.001,score['id']
    # Gentle saturation controls tutti transients without flattening quiet sections.
    buf=np.tanh(buf*(.90/peak))
    buf*=.78/max(float(np.max(np.abs(buf))),.001)
    seam=round(.018*SR)
    join=np.zeros(2,dtype=np.float32)
    ramp=np.linspace(0,1,seam)[:,None]
    buf[:seam]=join*(1-ramp)+buf[:seam]*ramp
    buf[-seam:]=buf[-seam:]*(1-ramp)+join*ramp
    path=folder/(score['id']+'.ogg')
    # libvorbis on Windows uses stack scratch space proportional to write size.
    with sf.SoundFile(str(path),'w',SR,2,format='OGG',subtype='VORBIS',compression_level=.8) as writer:
        for start in range(0,len(buf),8192):
            writer.write(buf[start:start+8192])
    decoded,rate=sf.read(str(path),dtype='float32')
    assert rate==SR and abs(len(decoded)-len(buf))<=1
    assert np.isfinite(decoded).all() and np.max(np.abs(decoded))<.95
    # Measure different eight-bar sections; retain values for human review.
    section_rms=[]
    for i,section in enumerate(arrangement['sections']):
        start=round(section['seconds']*SR)
        end=round(arrangement['sections'][i+1]['seconds']*SR) if i+1<len(arrangement['sections']) else len(decoded)
        rms=float(np.sqrt(np.mean(decoded[start:end]**2)))
        section_rms.append(round(20*np.log10(max(rms,1e-9)),2))
    return dict(id=score['id'],title=score['title'],path='music/'+path.name,
                seconds=round(len(decoded)/SR,3),sample_rate=SR,channels=2,
                codec='Vorbis',peak_db=round(20*np.log10(float(np.max(np.abs(decoded)))),2),
                rms_db=round(20*np.log10(float(np.sqrt(np.mean(decoded**2)))),2),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bpm=score['bpm'],bars=arrangement['bars'],
                meter=score['meter'],loop=True,revision='hybrid-v3',scene=score['scene'],
                opener=score['opener'],solo_opening_bars=4,genre=score['genre'],
                lead=score['lead'],partner=score['partner'],texture=score['texture'],
                sections=arrangement['sections'],section_rms_db=section_rms,
                instruments=arrangement['counts'],note_count=len(arrangement['notes']),
                midi='tools/audio/scores/'+score['id']+'.mid',soundfont='GeneralUser GS 2.0.3')


def write_listening_page(records):
    names={'strings':'弦乐群','violin':'小提琴','viola':'中提琴','cello':'大提琴','bass':'低音提琴',
           'flute':'长笛','oboe':'双簧管','clarinet':'单簧管','bassoon':'巴松',
           'horn':'圆号','trombone':'长号','harp':'竖琴','glock':'钟琴','celesta':'钢片琴',
           'timpani':'定音鼓','percussion':'鼓组/打击乐','piano':'钢琴','nylon_guitar':'尼龙弦木吉他',
           'steel_guitar':'钢弦木吉他','clean_guitar':'清音电吉他','distortion_guitar':'失真电吉他',
           'overdrive_guitar':'过载电吉他','electric_bass':'电贝斯'}
    cards=[]
    for group,title in [('map_','十域 · 风景与人物'),('boss_','六首领 · 战斗交响')]:
        cards.append('<h2>'+title+'</h2><div class="grid">')
        for r in records:
            if not r['id'].startswith(group):continue
            esc=html.escape
            duration=f"{int(r['seconds'])//60}:{int(r['seconds'])%60:02d}"
            sections=''.join(f'<button class="chapter" data-player="{r["id"]}" data-at="{s["seconds"]}">{int(s["seconds"])//60}:{int(s["seconds"])%60:02d} {esc(s["name"])}</button>' for s in r['sections'])
            cards.append(f'<article><div class="tag">{r["meter"]} · {r["bpm"]} BPM · {duration} · {len(r["instruments"])}种乐器</div>'
                         f'<h3>{esc(r["title"])}</h3><p>{esc(r["scene"])}</p>'
                         f'<p>开场：{names[r["opener"]]}独奏 · {esc(r["genre"])}</p>'
                         f'<div class="parts">{esc(" / ".join(names[n] for n in r["instruments"]))}</div>'
                         f'<audio id="{r["id"]}" controls preload="none" src="../../card-demo/assets/audio/{esc(r["path"])}"></audio>'
                         f'<details><summary>乐章进程 · 点击跳转试听</summary><p>{sections}</p></details>'
                         f'<a href="../../{r["midi"]}" download>下载分轨 MIDI</a></article>')
        cards.append('</div>')
    text='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>福地 · 十域交响与摇滚曲集 V3</title><style>
*{box-sizing:border-box}body{margin:0;background:#101a20;color:#e9ece7;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}
main{max-width:1180px;margin:auto;padding:56px 28px}header{border-bottom:1px solid #405159;padding-bottom:28px;margin-bottom:38px}
.eyebrow,.tag{color:#d4bd82;font-size:13px;letter-spacing:.08em}h1{font-size:clamp(30px,5vw,54px);margin:8px 0 12px;font-weight:600}
header p{max-width:750px;color:#b8c9ca}h2{font-size:24px;margin:40px 0 20px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:20px}
article{background:#1a2b32;border:1px solid #344a51;border-radius:16px;padding:24px}h3{font-size:21px;margin:8px 0 12px}article p{color:#c2d0d0;margin:8px 0}.parts{color:#9fb6b9;font-size:13px;min-height:48px}
audio{width:100%;margin:18px 0 10px;height:40px}details{font-size:13px;color:#aabec0;margin-bottom:12px}summary{cursor:pointer}a{color:#dfc68d;font-size:13px}footer{margin-top:45px;color:#8ba2a7;font-size:13px}
.chapter{display:block;border:1px solid #405961;border-radius:7px;background:#14242b;color:#cbd9d8;padding:7px 10px;margin:5px 0;text-align:left;cursor:pointer;width:100%}.chapter:hover{border-color:#dfc68d;color:#dfc68d}
</style><main><header><div class="eyebrow">CUN / FUDI · ORCHESTRA × ROCK · V3</div><h1>十六种开场，六种交锋</h1>
<p>每曲以不同乐器独奏四小节，再逐层加入乐团。六位首领分别采用硬摇滚、民谣摇滚、工业重拍、钢琴交响、七拍前卫与厄运摇滚，独立谱写旋律及鼓点。点选任一播放器即可试听，播放另一首会自动停止前一首。</p></header>'''
    text+=''.join(cards)
    text+='''<footer>原创旋律与编配：Cun / Codex。乐器音源：S. Christian Collins 及贡献者的 GeneralUser GS 2.0.3；虚拟乐团采样渲染，非现场录音。<a href="GENERALUSER-LICENSE.txt">音源许可原文</a> · <a href="../../docs/fudi-audio.md">配乐说明</a></footer></main>
<script>document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})));document.querySelectorAll('.chapter').forEach(b=>b.addEventListener('click',()=>{const a=document.getElementById(b.dataset.player);a.currentTime=Number(b.dataset.at);a.play()}))</script></html>'''
    page=ROOT/'assets/audio/orchestra-listening.html'
    page.parent.mkdir(exist_ok=True,parents=True)
    page.write_text(text,encoding='utf8')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--soundfont',type=Path,required=True)
    p.add_argument('--output',type=Path,default=ROOT/'.local/fudi-hybrid-v3')
    p.add_argument('--only',nargs='*')
    p.add_argument('--publish',action='store_true')
    args=p.parse_args()
    bank=args.soundfont.read_bytes()
    if hashlib.sha256(bank).hexdigest()!=SF_HASH:
        raise SystemExit('SoundFont does not match the reviewed GeneralUser GS 2.0.3 hash')
    args.output.mkdir(parents=True,exist_ok=True)
    records=[]
    for score in SCORES:
        if args.only and score['id'] not in args.only:continue
        arrangement=arrange(score)
        record=render(score,arrangement,bank,args.output)
        write_midi(args.output/(score['id']+'.mid'),score,arrangement)
        records.append(record)
        (args.output/(score['id']+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        print(f"{score['id']}: {record['seconds']:.1f}s, {record['bars']} bars, {len(record['instruments'])} instruments, {record['note_count']} notes",flush=True)
    if args.publish:
        if len(records)!=16:raise SystemExit('Publishing requires all sixteen scores')
        assets=ROOT/'card-demo/assets/audio'
        manifest=json.loads((assets/'manifest.json').read_text(encoding='utf8'))
        backup=args.output/'previous-score'
        backup.mkdir(exist_ok=True)
        if not (backup/'manifest.json').exists():
            shutil.copy2(assets/'manifest.json',backup/'manifest.json')
        registry_path=ROOT/'assets/registry.json'
        if not (backup/'registry.json').exists():
            shutil.copy2(registry_path,backup/'registry.json')
        for record in records:
            name=record['id']
            for source in (assets/'music'/(name+'.ogg'), ROOT/'tools/audio/scores'/(name+'.mid')):
                if source.exists() and not (backup/source.name).exists():
                    shutil.copy2(source,backup/source.name)
            for suffix in ('.wav','.wav.import'):
                old=assets/'music'/(name+suffix)
                if old.exists():
                    shutil.copy2(old,backup/old.name)
                    old.unlink()
            shutil.copy2(args.output/(name+'.ogg'),assets/'music'/(name+'.ogg'))
            midi=ROOT/record['midi'];midi.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(args.output/(name+'.mid'),midi)
        keep=[r for r in manifest['assets'] if not r['path'].startswith('music/')]
        manifest.update(version=2,music_revision='hybrid-v3',
                        source='Music: original solo openings, orchestral and hybrid rock scores rendered with GeneralUser GS 2.0.3 / TinySoundFont 0.3.7. Foley/ambience: unchanged original procedural v1.',
                        assets=records+keep)
        manifest.pop('sample_rate',None)
        manifest.pop('bits',None)
        (assets/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        registry=json.loads(registry_path.read_text(encoding='utf8'))
        for r in records:
            paths={'card-demo/assets/audio/music/'+r['id']+ext for ext in ('.wav','.ogg')}
            entry=next(x for x in registry['assets'] if x['path'] in paths)
            entry.update(path='card-demo/assets/audio/'+r['path'],sha256=r['sha256'],
                         name=r['title'],source='Original score: tools/fudi_orchestra_scores.py; GeneralUser GS 2.0.3; see assets/audio/GENERALUSER-LICENSE.txt',
                         author='Cun / Codex original composition; instrument samples: S. Christian Collins / GeneralUser GS contributors',
                         tags=['fudi','orchestral-music','hybrid-v3'],
                         notes=f"{r['genre']}; solo opener: {r['opener']}; {r['meter']}; {r['bars']} bars; {len(r['instruments'])} instrumental parts; editable MIDI: {r['midi']}; human listening review pending")
        registry_path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        write_listening_page(records)
        print('Published sixteen OGG scores; 22 environment/SFX WAVs preserved.',flush=True)


if __name__=='__main__':main()
