"""Package the nine approved map paintings and their reviewed navigation routes.

Run with Pillow; source PNGs and the image-generation queue are never modified.
Coordinates follow the visible roads, bridges and entrances in the finished images.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/imagegen/fudi-fine'
TARGET = ROOT / 'card-demo/assets/backgrounds/fudi'
# First road: previous/next gate; second road ends at the cross-ring gate.
# Other roads are accessible lanes to existing painted buildings and courtyards.
LAYOUTS = {
    'grove': dict(spawn=[.14,.50], sites=[[.25,.48],[.50,.27],[.80,.39]], door=[.29,.34], half_width=125,
        roads=[[[.08,.50],[.24,.50],[.50,.27],[.64,.40],[.92,.38]], [[.50,.27],[.50,.08]], [[.50,.80],[.53,.68],[.53,.51],[.50,.43],[.50,.27]], [[.29,.44],[.29,.34]], [[.24,.50],[.29,.44]]],
        obstacles=[[.36,.43,.12,.21],[.59,.63,.11,.14],[.12,.04,.26,.22],[.68,.07,.15,.18]]),
    'post': dict(spawn=[.14,.50], sites=[[.24,.50],[.49,.70],[.77,.27]], door=[.21,.30], half_width=130,
        roads=[[[.08,.50],[.24,.50],[.49,.70],[.77,.27],[.92,.50]], [[.49,.70],[.50,.92]], [[.24,.50],[.21,.40],[.21,.30]]],
        obstacles=[[.34,.17,.09,.27],[.59,.70,.12,.14],[.05,.05,.14,.20],[.62,.15,.08,.16]]),
    'quarry': dict(spawn=[.14,.50], sites=[[.25,.50],[.51,.26],[.77,.70]], door=[.76,.31], half_width=130,
        roads=[[[.08,.50],[.25,.50],[.51,.26],[.77,.70],[.92,.50]], [[.51,.26],[.50,.08]], [[.55,.33],[.68,.31],[.76,.31]], [[.76,.31],[.76,.42]]],
        obstacles=[[.35,.44,.11,.18],[.60,.73,.13,.11],[.68,.04,.18,.20],[.10,.12,.17,.13]]),
    'ruins': dict(spawn=[.14,.49], sites=[[.24,.49],[.50,.70],[.77,.25]], door=[.21,.40], half_width=130,
        roads=[[[.08,.49],[.24,.49],[.50,.70],[.77,.25],[.92,.49]], [[.50,.70],[.50,.92]], [[.24,.49],[.21,.40]], [[.21,.40],[.21,.51]]],
        obstacles=[[.35,.18,.10,.27],[.61,.67,.10,.18],[.04,.08,.15,.25],[.82,.12,.10,.20]]),
    'refuge': dict(spawn=[.14,.50], sites=[[.24,.50],[.50,.26],[.77,.70]], door=[.22,.34], half_width=130,
        roads=[[[.08,.50],[.24,.50],[.50,.26],[.77,.70],[.92,.50]], [[.50,.26],[.50,.08]], [[.24,.50],[.22,.43],[.22,.34]]],
        obstacles=[[.34,.45,.11,.17],[.62,.12,.10,.17],[.05,.05,.15,.23],[.57,.80,.13,.10]]),
    'wetland': dict(spawn=[.14,.49], sites=[[.25,.49],[.50,.13],[.77,.57]], door=[.62,.326], half_width=115,
        roads=[[[.08,.49],[.25,.49],[.50,.13],[.77,.57],[.92,.44]], [[.77,.57],[.68,.66],[.61,.77],[.52,.89]]],
        obstacles=[[.33,.43,.12,.20],[.78,.74,.13,.15],[.58,.04,.18,.20],[.06,.65,.26,.16]]),
    'causeway': dict(spawn=[.14,.46], sites=[[.25,.46],[.49,.68],[.78,.29]], door=[.275,.25], half_width=105,
        roads=[[[.08,.46],[.25,.46],[.47,.68],[.53,.68],[.78,.29],[.92,.47]], [[.25,.46],[.27,.08],[.43,.08]]],
        obstacles=[[.33,.18,.10,.25],[.63,.72,.16,.13],[.35,.18,.09,.22],[.12,.72,.15,.13]]),
    'kilnwood': dict(spawn=[.14,.48], sites=[[.24,.48],[.50,.17],[.77,.65]], door=[.66,.29], half_width=130,
        roads=[[[.08,.48],[.24,.48],[.50,.17],[.77,.65],[.92,.46]], [[.77,.65],[.50,.91]], [[.58,.31],[.66,.29]]],
        obstacles=[[.35,.43,.10,.13],[.57,.69,.10,.10],[.61,.03,.17,.19],[.10,.73,.18,.09]]),
    'archive': dict(spawn=[.14,.50], sites=[[.24,.50],[.50,.70],[.78,.25]], door=[.118,.255], half_width=130,
        roads=[[[.08,.50],[.24,.50],[.50,.70],[.78,.25],[.92,.48]], [[.24,.50],[.24,.09],[.50,.09]], [[.14,.50],[.14,.42],[.14,.34],[.118,.33],[.118,.255]]],
        obstacles=[[.34,.17,.10,.26],[.61,.68,.12,.18],[.025,.005,.17,.21],[.66,.10,.09,.14]]),
}


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    records = {}
    for index, (region, layout) in enumerate(LAYOUTS.items(), 1):
        source = SOURCE / f'{index:02}_maps_{region}.png'
        with Image.open(source) as im:
            rgba = im.convert('RGBA')
            target = TARGET / f'{region}.webp'
            rgba.save(target, lossless=True, method=6, exact=True)
            with Image.open(target) as packed:
                if packed.convert('RGBA').tobytes() != rgba.tobytes():
                    raise ValueError(f'Lossless verification failed: {region}')
            records[region] = dict(layout, source=str(source.relative_to(ROOT)).replace('\\','/'),
                texture=f'res://assets/backgrounds/fudi/{region}.webp',
                source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                sha256=hashlib.sha256(target.read_bytes()).hexdigest(), size=list(im.size))
            print(f'{region}: {source.stat().st_size} -> {target.stat().st_size} bytes; decoded pixels identical')
    (TARGET / 'manifest.json').write_text(json.dumps(dict(version=1, maps=records), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
