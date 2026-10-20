"""Check the audible-score requirements and published music, not just titles.

Requires the same local dependencies as build_fudi_orchestra.py.
"""
import hashlib
import json
from itertools import combinations
from pathlib import Path

from build_fudi_orchestra import ROOT, SCORES, SR, arrange, parse_theme, np, sf


def motif(score, theme):
    """Pitch intervals in semitones, with note lengths and rests; key independent."""
    previous = None
    result = []
    for bar in parse_theme(score[theme], score['beats']):
        for degree, duration in bar:
            if degree is None:
                result.append(('rest', duration))
                continue
            octave, index = divmod(degree, 7)
            pitch = score['scale'][index] + octave * 12
            result.append((None if previous is None else pitch - previous, duration))
            previous = pitch
    return result


def main():
    assets = ROOT / 'card-demo/assets/audio'
    manifest = json.loads((assets / 'manifest.json').read_text(encoding='utf8'))
    registry = json.loads((ROOT / 'assets/registry.json').read_text(encoding='utf8'))
    records = {r['id']: r for r in manifest['assets']}
    backup = ROOT / '.local/fudi-hybrid-v3/previous-score/manifest.json'
    previous = json.loads(backup.read_text(encoding='utf8')) if backup.exists() else None
    assert len(records) == 38 and manifest['music_revision'] == 'hybrid-v3'
    assert len({s['opener'] for s in SCORES}) == 16
    programs = set()
    rows = []
    for score in SCORES:
        a = arrange(score)
        opener = score['opener']
        ch, prog, _, _ = a['instruments'][opener]
        programs.add(prog)
        # Inspect actual scheduled notes: no hidden bass, strings or closing tail.
        opening = [n for n in a['notes'] if n[0] < score['beats'] * 4]
        assert opening and all(n[2] == ch for n in opening), score['id']
        assert min(e[0] for e in a['events'] if e[1]) < .03
        assert len({v[0] for v in a['instruments'].values()}) == len(a['instruments']) <= 16
        assert a['instruments'].get('percussion', (9,))[0] == 9
        if score['boss']:
            assert a['instruments']['percussion'][1] == 0, 'rock drum kit'
            assert score['rhythm_guitar'] in a['counts'] and 'electric_bass' in a['counts']
        record = records[score['id']]
        path = assets / record['path']
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        entry = next(r for r in registry['assets'] if r['path'] == 'card-demo/assets/audio/' + record['path'])
        assert digest == record['sha256'] == entry['sha256']
        assert record['opener'] == opener and record['solo_opening_bars'] == 4
        assert record['instruments'] == a['counts']
        audio, rate = sf.read(str(path), dtype='float32', always_2d=True)
        assert rate == SR and audio.shape[1] == 2 and np.isfinite(audio).all()
        assert abs(len(audio) / rate - record['seconds']) < .002
        peak = float(np.max(np.abs(audio)))
        rms = float(np.sqrt(np.mean(audio**2)))
        solo_rms = float(np.sqrt(np.mean(audio[:rate*4]**2)))
        seam = float(np.max(np.abs(audio[-1] - audio[0])))
        assert .03 < rms and peak < .95 and solo_rms > .003 and seam < .03, (score['id'], rms, peak, solo_rms, seam)
        midi = ROOT / record['midi']
        assert midi.read_bytes()[:4] == b'MThd'
        rows.append(dict(id=score['id'], opener=opener, program=prog, instruments=len(a['counts']),
                         peak=round(peak,5), rms=round(rms,5), solo_rms=round(solo_rms,5), seam=round(seam,6)))
    assert len(programs) == 16, 'different names must actually use different patches'
    bosses = [s for s in SCORES if s['boss']]
    comparisons = []
    for left, right in combinations(bosses, 2):
        lm, rm = motif(left, 'theme_a'), motif(right, 'theme_a')
        assert lm[:12] != rm[:12], 'transposed copies are not independent themes'
        assert [d for _,d in lm[:12]] != [d for _,d in rm[:12]], 'opening rhythm reused'
        maximum = 0
        # Search both A/B themes for shared six-event interval/rhythm phrases.
        for lt in ('theme_a','theme_b'):
            for rt in ('theme_a','theme_b'):
                l, r = motif(left,lt)[1:], motif(right,rt)[1:]
                for i in range(len(l)):
                    for j in range(len(r)):
                        count = 0
                        while i+count<len(l) and j+count<len(r) and l[i+count]==r[j+count]:
                            count += 1
                        maximum = max(maximum,count)
        assert maximum < 6, (left['id'], right['id'], maximum)
        comparisons.append(dict(left=left['id'],right=right['id'],max_shared_interval_rhythm_events=maximum))
    effects = [r for r in manifest['assets'] if not r['path'].startswith('music/')]
    assert len(effects) == 22
    for record in effects:
        assert hashlib.sha256((assets/record['path']).read_bytes()).hexdigest() == record['sha256']
        if previous:
            old = next(r for r in previous['assets'] if r['id'] == record['id'])
            assert old == record, 'environment/SFX metadata or content changed'
    report = dict(revision='hybrid-v3',tracks=rows,boss_comparisons=comparisons,
                  unchanged_effects=22, previous_manifest_checked=previous is not None,
                  limits='Score and signal checks do not replace human listening.')
    evidence = ROOT / '.local/fudi-hybrid-v3/verification.json'
    evidence.parent.mkdir(parents=True,exist_ok=True)
    evidence.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'PASS: 16 distinct audible solo patches, 15 Boss pairs, 16 decoded OGG/MIDI/hash checks, 22 unchanged effects. {evidence}')


if __name__ == '__main__':
    main()
