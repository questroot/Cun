"""Original shelter layer art; geometry confirmed via PM/frontend 2026-10-21.
Local pixelstudio/Pillow; never changes runtime source. Refuses output overwrite.
"""
from pathlib import Path
import sys,json,hashlib
sys.path.insert(0,r'C:\Users\fanzl\.dsh\skills\pixel-art-studio\scripts')
from pixelstudio import Sprite
from PIL import Image,ImageDraw
D=Path(__file__).resolve().parent
class Art:
 def __init__(self,w,h):self.w=w;self.h=h;self.shapes=[]
 def p(self,c,*pts):self.shapes.append((c,pts))
 def r(self,c,x,y,w,h):self.p(c,(x,y),(x+w-1,y),(x+w-1,y+h-1),(x,y+h-1))
 def export(self,name,anchor,placement,layer):
  assert not (D/(name+'.png')).exists() and not (D/(name+'.svg')).exists()
  sp=Sprite(self.w,self.h,snap=False);s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" shape-rendering="crispEdges">']
  for i,(c,pts) in enumerate(self.shapes):
   sp.polygon(pts,c);s.append(f'<polygon id="cluster-{i}" fill="{c}" points="'+' '.join(f'{x},{y}' for x,y in pts)+'"/>')
  s.append('</svg>');(D/(name+'.svg')).write_text('\n'.join(s),encoding='utf-8');sp.save_png(str(D/(name+'.png')))
  return {'png':name+'.png','svg':name+'.svg','size':[self.w,self.h],'anchor':anchor,'placement':placement,'layer':layer}
A=[]
for wet in [False,True]:
 a=Art(64,64);base='#45616a' if wet else '#7a7968';dark='#344c54' if wet else '#676d61';light='#66858b' if wet else '#94927b'
 a.r(base,0,0,64,64)
 # Offset paving, seamless rect edges; sparse highlights rather than random noise.
 for y in [0,31,63]: a.r(dark,0,y,64,1)
 for x,y in [(22,1),(53,1),(6,32),(38,32)]:a.r(dark,x,y,1,30)
 for x,y,w in [(2,3,17),(25,3,24),(1,34,3),(10,34,23),(41,34,20)]:a.r(light,x,y,w,1)
 if wet:
  for x,y,w in [(8,19,12),(42,47,14),(26,13,5),(18,55,10)]:a.r('#75a5bb',x,y,w,1)
  a.r('#91b1b7',10,18,4,1)
 else:
  a.r('#858574',30,22,5,1);a.r('#858574',47,50,4,1)
 A.append(a.export('stone_wet' if wet else 'stone_dry',[0,0],'Tile within world (40,175,780,445); wet/dry masks come ONLY from actual state','ground'))
# Separate damp-edge strip, not an invented route marker.
a=Art(64,16)
a.p('#45616a',(0,8),(6,6),(16,8),(23,5),(34,7),(44,4),(53,7),(63,5),(63,15),(0,15))
a.p('#66858b',(0,8),(6,6),(16,8),(23,5),(34,7),(44,4),(53,7),(63,5),(63,6),(53,8),(44,5),(34,8),(23,6),(16,9),(6,7),(0,9))
A.append(a.export('wet_edge',[0,8],'Optional only along true dry-region border; do not rotate into fake obstacles','ground_detail'))
# Main beam and narrow front columns. Maintain exact coordinate system.
a=Art(704,20);a.r('#354039',0,6,704,12);a.r('#6b5a46',1,4,702,11);a.r('#ad9672',1,3,702,3);a.r('#897858',2,9,700,2);a.r('#554c3e',0,15,704,3)
for x in [8,690]:
 a.r('#b7a07b',x,4,4,12);a.r('#554c3e',x+1,6,1,7)
for x in range(36,670,79):a.r('#a08c6b',x,7,25,1)
A.append(a.export('shelter_beam',[4,10],'Anchor world(76,190), ends near x770','back_structure'))
a=Art(16,272);a.r('#354039',1,0,14,270);a.r('#6b5a46',2,1,12,265);a.r('#a38c65',3,3,3,258);a.r('#897554',7,4,2,255);a.r('#554c3e',11,1,3,267);a.r('#927d59',2,37,12,4);a.r('#554c3e',2,40,12,2)
for y in [66,124,203]:a.r('#554c3e',7,y,2,11)
a.r('#b7a07b',3,43,2,9);a.r('#454e44',0,263,16,9)
A.append(a.export('shelter_post',[8,6],'Anchor(80,190)/(770,190); same PNG may be split by runtime into back/top and narrow front sections','split_structure'))
# Fabric separately deformed as a quad; never scale a whole baked shelter.
a=Art(160,64);a.r('#354c54',0,0,160,64);a.r('#526b70',2,2,156,59)
for x in [4,42,82,122,155]:
 a.r('#79908d',x,3,1,54);a.r('#405961',min(x+2,158),3,1,56)
a.r('#91a29a',3,2,154,1);a.r('#354c54',2,58,156,3)
for x,y in [(20,20),(98,35),(142,15)]:a.r('#5f7879',x,y,8,2)
A.append(a.export('awning_panel',[0,0],'UV full image to quad (575,195),(735,195),(735,270-45t),(575,280-45t); t=awning_pull/90','back_fabric'))
a=Art(160,12);a.r('#354c54',0,0,160,10);a.r('#79908d',0,1,160,2);a.r('#526b70',0,4,160,4)
for x in range(3,160,20):a.r('#91a29a',x,3,2,4)
A.append(a.export('awning_hem',[0,0],'Map top corners to dynamic lower edge of awning quad; extend down <=8px; never conceal rope end','front_fabric'))
# Lamp hardware independent of state glows, no labels, no baked illumination.
for state in ['white','warm','yellow_off','yellow_on']:
 a=Art(40,48);lit=state!='yellow_off';glass='#e5edf0' if state=='white' else ('#e9bd5d' if lit else '#77654a')
 a.r('#554c3e',17,2,7,6);a.r('#b49b6c',18,2,4,2)
 a.p('#354c54',(12,9),(28,9),(32,16),(31,34),(25,40),(15,40),(9,34),(8,16))
 a.p(glass,(13,14),(27,14),(29,18),(28,31),(25,35),(15,35),(12,31),(11,18))
 a.r('#fff0c3' if state!='white' and lit else '#c3cfca',14,16,3,15)
 a.r('#8e7757',9,11,23,4);a.r('#b7a07b',10,11,21,2);a.r('#8e7757',11,34,19,4);a.r('#554c3e',13,39,15,3)
 a.r('#354c54',19,15,2,19)
 A.append(a.export('lamp_'+state,[20,24],'white/warm at(250,360), yellow_off/on at(620,390). Keep tongue/shade states runtime; local sprite not collision','prop'))
# Soft pool with explicit alpha; each ring is one original ellipse, no external image.
name='light_pool';assert not (D/(name+'.png')).exists();im=Image.new('RGBA',(96,96));dr=ImageDraw.Draw(im)
for margin,alpha in [(0,3),(6,5),(12,8),(20,12),(28,16),(36,22)]:dr.ellipse((margin,margin,95-margin,95-margin),fill=(233,189,93,alpha))
im.save(D/(name+'.png'))
svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'+''.join(f'<ellipse cx="48" cy="48" rx="{48-m}" ry="{48-m}" fill="#e9bd5d" fill-opacity="{al/255:.5f}"/>' for m,al in [(0,3),(6,5),(12,8),(20,12),(28,16),(36,22)])+'</svg>'
(D/(name+'.svg')).write_text(svg,encoding='utf-8');A.append({'png':name+'.png','svg':name+'.svg','size':[96,96],'anchor':[48,48],'placement':'Center at lit lamp only; under actors, alpha not additive flash','layer':'ground_light'})
for asset in A:
 im=Image.open(D/asset['png']);assert im.mode=='RGBA' and list(im.size)==asset['size'];asset['alpha_bounds']=im.getchannel('A').getbbox();asset['sha256']=hashlib.sha256((D/asset['png']).read_bytes()).hexdigest()
manifest={'schema':1,'frontend_confirmation':'PM relayed fixed main coordinates and tension contract, sessions-message-72c73de2-dbec-4754-b5f9-63d392f5e097','assets':A,'source':'Original hand-authored pixel polygons, existing local pixelstudio/Pillow; no third-party images/fonts, downloads/install/fees. Same palette as Shendu and Zhou.','rules':'All independent. No baked UI/collision/actors in background. Rope/drops/water-level/sealed-state remain runtime. Clamp tile and light rendering to world.','qc':'RGBA dimensions checked; actual resources read_image reviewed separately; game integration NOT tested','sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in D.iterdir() if p.is_file() and p.name not in ['environment_manifest.json','manifest.json']}}
assert not (D/'environment_manifest.json').exists();(D/'environment_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('Environment assets:',len(A))
