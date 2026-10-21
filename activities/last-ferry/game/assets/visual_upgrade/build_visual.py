"""Original hand-authored pixel clusters for Last Ferry shelter, no external images.
Exports editable SVG geometry and production RGBA PNGs with shared anchors.
"""
from pathlib import Path
import json, hashlib, sys
sys.path.insert(0,r'C:\Users\fanzl\.dsh\skills\pixel-art-studio\scripts')
from pixelstudio import Sprite
from PIL import Image
D=Path(__file__).resolve().parent
INK='#293b42'; DEEP='#354c54'; COAT='#586a67'; LIT='#819087'
SKIN='#bba58c'; FACE='#ead1ac'; SKIN_DARK='#927965'
WOOD='#8e7757'; WOOD_D='#554c3e'; WOOD_L='#b7a07b'
class Art:
 def __init__(self,w,h,anchor): self.w=w;self.h=h;self.anchor=anchor;self.shapes=[]
 def p(self,c,*pts): self.shapes.append((c,list(pts)))
 def r(self,c,x,y,w,h): self.p(c,(x,y),(x+w-1,y),(x+w-1,y+h-1),(x,y+h-1))
 def export(self,name,state):
  png=D/(name+'.png');svg=D/(name+'.svg')
  assert not png.exists() and not svg.exists(),'Refuse existing file overwrite'
  sp=Sprite(self.w,self.h,snap=False)
  out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" shape-rendering="crispEdges">',f'<title>Original {name}; anchor {self.anchor}</title>']
  for i,(c,pts) in enumerate(self.shapes):
   sp.polygon(pts,c)
   out.append(f'<polygon id="cluster-{i}" fill="{c}" points="'+ ' '.join(f'{x},{y}' for x,y in pts)+'"/>')
  out.append('</svg>');svg.write_text('\n'.join(out)+'\n',encoding='utf-8');sp.save_png(str(png))
  im=Image.open(png);alpha=im.getchannel('A');assert im.mode=='RGBA' and im.size==(self.w,self.h)
  assert set(alpha.get_flattened_data())=={0,255}
  return {'png':png.name,'svg':svg.name,'size':[self.w,self.h],'anchor':self.anchor,'state':state,'alpha_bounds':alpha.getbbox(),'colors':len(im.getcolors())-1}

def zhou(pose):
 a=Art(48,72,[24,40]); seated=pose=='seated';drag=pose=='dragging';walk=pose=='walking'
 # All local coordinates map to one immutable position anchor.
 # Shoes and bent knees differ for sitting and gait without changing identity.
 if seated:
  a.p(INK,(14,42),(22,42),(22,55),(18,58),(12,57),(12,53))
  a.p(INK,(26,42),(33,43),(36,53),(35,57),(28,57),(26,53))
  a.r(DEEP,14,46,6,8);a.r(DEEP,28,46,5,8)
  a.r('#a2937d',13,53,6,2);a.r('#a2937d',29,53,5,2)
 else:
  ly=59 if walk else 60;ry=61 if walk else 60
  a.p(INK,(15,47),(22,47),(22,ly),(14,ly),(13,ly-3))
  a.p(INK,(26,47),(33,47),(35,ry),(26,ry))
  a.r(DEEP,16,49,5,ly-51);a.r(DEEP,27,49,5,ry-51)
  a.r('#a2937d',14,ly-2,7,1);a.r('#a2937d',27,ry-2,7,1)
 # Silver-haired older river keeper: rounded hunched shoulders, worn olive jacket.
 shift=4 if seated else (2 if drag else 0)
 a.p(INK,(17,25+shift),(29,25+shift),(35,31+shift),(35,49),(30,53),(14,52),(12,32+shift))
 a.p(COAT,(17,27+shift),(29,27+shift),(33,32+shift),(32,49),(28,51),(15,49),(14,33+shift))
 a.p(LIT,(16,30+shift),(19,29+shift),(18,44),(15,47),(14,34+shift))
 a.p(DEEP,(27,30+shift),(32,33+shift),(32,49),(29,49),(26,38))
 # Scarf and jacket opening: muted warm grey echoes cap trim, not full costume repaint.
 a.p('#a2937d',(19,24+shift),(28,24+shift),(29,29+shift),(25,32+shift),(23,42),(20,41),(22,30+shift))
 a.r('#c2b89e',21,26+shift,5,2)
 a.r(INK,24,33+shift,1,12-shift)
 a.r(WOOD_L,25,36+shift,1,1);a.r(WOOD_L,25,42,1,1)
 a.r(DEEP,28,43,4,4)
 # Pose-specific sleeves. Hands are separate small pads, runtime may connect to chair.
 if drag:
  a.p(INK,(14,30),(19,33),(15,42),(9,46),(5,43),(9,35))
  a.p(COAT,(14,32),(17,34),(13,40),(8,43),(7,41),(11,35))
  a.p(LIT,(13,32),(15,34),(10,39),(8,40),(9,36))
  a.p(INK,(31,31),(37,34),(41,42),(37,46),(32,40))
  a.p(COAT,(32,33),(35,35),(38,41),(36,43),(33,39))
  a.r(SKIN,6,43,5,4);a.r(FACE,6,43,4,2)
  a.r(SKIN,35,43,5,4);a.r(FACE,35,43,4,2)
 elif seated:
  a.p(INK,(14,31),(19,35),(18,43),(22,46),(19,49),(13,45),(11,36))
  a.p(COAT,(14,34),(17,36),(16,43),(19,45),(17,46),(13,43))
  a.p(INK,(31,32),(35,35),(36,44),(29,49),(26,46),(32,42))
  a.p(COAT,(31,35),(33,36),(33,43),(29,46),(28,45),(32,41))
  a.r(SKIN,18,44,5,4);a.r(FACE,18,44,4,2)
  a.r(SKIN,26,44,5,4);a.r(FACE,26,44,4,2)
 else:
  a.p(INK,(14,29),(18,32),(13,46),(9,49),(6,45),(9,35))
  a.p(COAT,(14,32),(15,34),(11,44),(8,45),(10,36))
  a.p(INK,(31,29),(36,33),(38,45),(34,49),(30,45))
  a.p(COAT,(32,32),(34,34),(35,44),(33,46),(32,43))
  a.r(SKIN,7,45,5,5);a.r(FACE,7,45,3,2)
  a.r(SKIN,33,45,4,5);a.r(FACE,33,45,3,2)
 # Head grey hair, warm face, no scary features. Shifted down 4px in seated pose.
 y=shift
 a.r(SKIN_DARK,21,22+y,6,5)
 a.p(INK,(18,7+y),(28,7+y),(33,12+y),(33,20+y),(29,26+y),(21,27+y),(16,22+y),(14,16+y))
 a.p(SKIN,(18,10+y),(28,10+y),(31,14+y),(30,21+y),(27,25+y),(21,25+y),(17,21+y),(16,16+y))
 a.p(FACE,(18,13+y),(24,13+y),(24,20+y),(21,23+y),(18,21+y),(16,17+y))
 a.r(SKIN_DARK,27,20+y,3,3)
 a.p('#7f8b88',(15,12+y),(18,7+y),(27,6+y),(32,10+y),(33,16+y),(30,18+y),(28,12+y),(21,11+y),(18,15+y))
 a.p('#bec5b8',(17,11+y),(19,8+y),(26,7+y),(29,9+y),(27,10+y),(20,10+y),(17,14+y))
 a.r('#d5d7c7',21,8+y,5,1)
 a.r(INK,18,17+y,2,1);a.r('#8f8069',17,20+y,4,1)
 a.r('#c5c5b0',23,24+y,4,1)
 return a

st=Art(40,28,[20,14])
st.p(WOOD_D,(4,10),(10,10),(9,25),(4,26),(3,23));st.p(WOOD_D,(29,10),(35,10),(37,24),(32,26))
st.r(WOOD,6,14,3,9);st.r(WOOD,31,14,3,9)
st.r(WOOD_D,8,19,24,3);st.r(WOOD,9,19,22,1)
st.p(INK,(2,3),(34,3),(38,8),(37,14),(3,15),(1,11))
st.p(WOOD,(3,4),(33,4),(36,8),(35,12),(4,13),(2,10))
st.p(WOOD_L,(3,4),(33,4),(35,7),(4,9),(2,8))
st.r(WOOD_D,4,9,31,1);st.r('#9d8664',5,11,27,1)
st.r('#d1b88d',7,5,9,1);st.r('#d1b88d',23,6,7,1)
st.r(WOOD_D,11,6,1,2);st.r(WOOD_D,29,8,3,1)
outputs=[st.export('stool','Any pose: positioned at wait.chair; carried uses same image')]
for pose in ['standing','walking','dragging','seated']:
 outputs.append(zhou(pose).export('zhou_'+pose,'wait.pose == '+pose))
manifest={'schema':1,'scope':'Shelter visual upgrade first pack: actor/prop actual assets, environment pending frontend coordinate confirmation','logical_canvas':[1280,800],'world_rect':[40,175,780,445],'render_scale':1,'filter':'nearest','assets':outputs,'collision':'Keep chair36x20 centered at wait.chair and Zhou24x32 centered at wait.zhou; alpha silhouette is NOT collision.','dragging':'Dynamic arms must join sleeve hand pads at local (-16,5)/(13,5) to actual chair ends; never bake chair into actor.','layering':'Floor/light; chair and actor feet-sorted; independent foreground; runtime marks/text; HUD separate. Seated: chair first then actor.','palette':['#293b42','#354c54','#556d70','#586a67','#819087','#79908d','#bba58c','#ead1ac','#927965','#8e7757','#554c3e','#b7a07b','#7a7968','#45616a','#75a5bb','#e9bd5d'],'origin':{'author':'art operator, original hand-authored pixel clusters','tools':'Existing local Python/Pillow/pixelstudio; editable SVG polygon source','external_images':False,'fonts_embedded':False,'cost':'No paid service, download, installation or network image generation','rights':'Original project art; external distribution subject to project owner rights confirmation'},'source_note':'SVG polygon coordinates editable; PNG authoritative pixelstudio inclusive-boundary raster. Re-export via build script may differ 1px from generic SVG renderer.','qc':{'png':'RGBA with transparent0/opaque255 alpha; sizes and bounds recorded per asset','integration_tested':False},'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in D.iterdir() if p.is_file() and p.name!='manifest.json'}}
assert not (D/'manifest.json').exists()
(D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(outputs,ensure_ascii=False))
