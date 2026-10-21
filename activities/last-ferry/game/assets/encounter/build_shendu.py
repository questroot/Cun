"""Original Shendu pixel geometry. No external art; exports editable SVG and PNG.
Run with bundled Python; pixelstudio path is a local build dependency, not runtime.
Fails rather than overwriting any deliverable.
"""
from pathlib import Path
import sys, json, hashlib
sys.path.insert(0, r'C:\Users\fanzl\.dsh\skills\pixel-art-studio\scripts')
from pixelstudio import Sprite
from PIL import Image, ImageChops
OUT = Path(__file__).resolve().parent
NAMES = ['shendu_offer.png','shendu_rest.png','shendu_offer.svg','shendu_rest.svg','manifest.json']
assert not any((OUT/n).exists() for n in NAMES), 'Existing outputs: refusing overwrite'
INK='#293b42'; DARK='#354c54'; COAT='#556d70'; LIGHT='#79908d'
SKIN='#bba58c'; WARM='#ead1ac'; SKIN_SHADE='#927965'; HAT='#3f535b'; BAND='#aa9677'

def geometry(offer):
    shapes=[]
    def p(color, pts): shapes.append((color, pts))
    def r(c,x0,y0,x1,y1): p(c,[(x0,y0),(x1,y0),(x1,y1),(x0,y1)])
    # Two separated boots, no baked shadow or world base.
    r(INK,15,46,22,51); r(INK,26,46,33,51)
    r(DARK,16,44,22,48); r(DARK,26,44,32,48)
    # Cold river-work jacket, body x=13..35, y=24..51.
    p(INK,[(17,23),(30,23),(35,28),(35,48),(31,51),(14,50),(13,29)])
    p(COAT,[(17,24),(29,24),(33,29),(33,47),(29,49),(15,48),(15,30)])
    p(LIGHT,[(17,25),(21,25),(20,44),(16,46),(16,29)])
    p(DARK,[(28,26),(32,29),(32,47),(28,48),(26,30)])
    r(BAND,17,39,31,41); r(DARK,24,28,26,39)
    # Right sleeve held close; left silhouette is pose-specific.
    p(INK,[(31,26),(36,29),(37,39),(34,44),(30,42)])
    p(COAT,[(32,28),(34,30),(35,38),(33,41),(31,40)])
    r(SKIN,32,40,35,44); r(WARM,32,40,34,42)
    if offer:
        p(INK,[(16,26),(19,31),(13,39),(7,42),(3,42),(3,37),(10,35)])
        p(COAT,[(15,28),(17,31),(11,37),(6,39),(5,37),(10,34)])
        p(LIGHT,[(14,29),(15,31),(9,36),(6,37),(5,36),(10,32)])
        p(SKIN,[(4,38),(7,39),(8,41),(6,43),(1,43),(0,41),(1,39)])
        p(WARM,[(1,39),(4,39),(6,40),(6,41),(1,41)])
        r(SKIN_SHADE,1,43,5,44)
    else:
        # Elbow down, folded forearm across waist; palm closed vertically.
        p(INK,[(15,26),(18,31),(11,37),(13,42),(7,46),(3,44),(5,38),(10,30)])
        p(COAT,[(14,28),(16,31),(9,37),(11,41),(7,43),(5,42),(7,37)])
        p(LIGHT,[(13,29),(14,31),(7,38),(7,41),(5,41),(6,37)])
        p(SKIN,[(4,41),(7,42),(8,45),(6,48),(3,47),(2,44)])
        r(WARM,3,42,5,46)
        r(SKIN_SHADE,6,44,7,47)
    # Short neck, left-facing head, cap and warm cheek.
    r(SKIN_SHADE,21,20,27,26)
    p(INK,[(18,4),(28,4),(33,9),(33,16),(29,22),(21,23),(17,19),(14,14),(16,10)])
    p(SKIN,[(18,7),(28,7),(31,10),(31,16),(27,21),(21,21),(18,18),(16,14)])
    p(WARM,[(17,10),(24,10),(24,17),(21,19),(18,17),(15,14)])
    r(SKIN_SHADE,26,15,30,19); r(INK,17,12,19,13)
    # Asymmetric boat-worker cap, not a horror silhouette.
    p(INK,[(17,2),(28,1),(33,5),(33,9),(13,10),(11,8),(15,6)])
    p(HAT,[(17,3),(27,2),(31,5),(31,7),(15,8)])
    r(LIGHT,19,3,26,4); r(BAND,16,7,31,8)
    p(DARK,[(12,8),(28,8),(26,10),(13,10)])
    return shapes

for state in ['offer','rest']:
    shapes=geometry(state=='offer')
    sprite=Sprite(48,64,snap=False)
    svg=['<svg xmlns="http://www.w3.org/2000/svg" width="48" height="64" viewBox="0 0 48 64" shape-rendering="crispEdges">', '<title>Original Shendu '+state+' pose; anchor 24,21</title>']
    for i,(color,pts) in enumerate(shapes):
        sprite.polygon(pts,color)
        # Pixelstudio includes the polygon boundary; SVG keeps integer source vertices.
        svg.append('<polygon id="cluster-%02d" fill="%s" points="%s"/>'%(i,color,' '.join('%s,%s'%p for p in pts)))
    svg.append('</svg>')
    (OUT/f'shendu_{state}.svg').write_text('\n'.join(svg)+'\n',encoding='utf-8')
    sprite.save_png(str(OUT/f'shendu_{state}.png'))

checks={}
for state in ['offer','rest']:
    with Image.open(OUT/f'shendu_{state}.png') as im:
        assert im.size==(48,64) and im.mode=='RGBA'
        alpha=im.getchannel('A')
        assert alpha.getextrema()==(0,255)
        assert set(alpha.getdata())=={0,255}
        assert alpha.getbbox()[3]<=52
        checks[state]={'mode':im.mode,'size':list(im.size),'alpha_extrema':list(alpha.getextrema()),'opaque_bounds':list(alpha.getbbox()),'palette_colors':len(im.getcolors())-1}
a=Image.open(OUT/'shendu_offer.png'); b=Image.open(OUT/'shendu_rest.png')
changed=sum(p!=q for p,q in zip(a.getdata(),b.getdata()))
assert changed>50
hashes={n:hashlib.sha256((OUT/n).read_bytes()).hexdigest() for n in NAMES if n!='manifest.json'}
hashes['build_shendu.py']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
manifest={'schema':1,'character':'沈渡','canvas':[48,64],'anchor_px':[24,21],'scale':1,'poses':{'offer':'未quiet且未持有/归还旧渡牌：摊掌向左','rest':'quiet或已持有/归还旧渡牌：屈臂收手'},'placement':{'steps_pos':[765,265],'boat_pos':[790,365],'texture_top_left':'pos - Vector2(24,21)','legacy_bounds_including_label':[-25,-21,50,72],'body_local_contract':[-11,3,22,27]},'layers':'Replace Shendu body/gesture only in existing actor pass. Keep name, plaque, rings and dialogue as runtime drawing. Frontend owns integration/occlusion/collision.','source':{'author':'art operator, project-directed original polygon/pixel drawing','date':'2026-10-21','tools':'Bundled Python + Pillow + installed pixelstudio.py; editable SVG polygons; no downloaded or generated third-party images','license':'Original project-commissioned artwork; no third-party image inputs. External publication rights remain subject to project owner confirmation.'},'svg_note':'Editable integer polygon source uses crispEdges; PNG is authoritative pixelstudio raster (inclusive boundary). No font/text/image nodes.','validation':{'png_checks':checks,'differing_pixels':changed,'game_integration_tested':False},'sha256':hashes}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(manifest['validation'],ensure_ascii=False))
