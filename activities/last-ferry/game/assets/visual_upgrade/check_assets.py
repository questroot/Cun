"""Read-only validation of the delivered pack. Does not launch/capture the game."""
from pathlib import Path
import json,hashlib,xml.etree.ElementTree as ET
from PIL import Image
D=Path(__file__).resolve().parent
assets=[]
for mf in ['manifest.json','environment_manifest.json']:
 m=json.loads((D/mf).read_text(encoding='utf-8'));assets+=m['assets']
 for name,sha in m['sha256'].items():
  assert hashlib.sha256((D/name).read_bytes()).hexdigest()==sha,name
for a in assets:
 im=Image.open(D/a['png']);assert im.mode=='RGBA' and list(im.size)==a['size']
 alpha=im.getchannel('A');assert alpha.getextrema()[1]>0
 # Full-surface stone tiles and the UV-deformed fabric panel must be opaque.
 if a['png'] in ['stone_dry.png','stone_wet.png','awning_panel.png']: assert alpha.getextrema()==(255,255)
 else: assert alpha.getextrema()[0]==0,a['png']
 tree=ET.parse(D/a['svg']);assert not any(n.tag.split('}')[-1] in ['text','image','script'] for n in tree.iter())
 assert a['anchor'][0]>=0 and a['anchor'][1]>=0
assert len(assets)==17
assert len({Image.open(D/f'zhou_{s}.png').tobytes() for s in ['standing','walking','dragging','seated']})==4
print('PASS: 17 PNG sizes/RGBA, independent SVG without text/image/script, stored SHA256, four distinct actor states. No game integration asserted.')
