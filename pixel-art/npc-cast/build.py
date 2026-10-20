"""Local, deterministic NPC art. Run with Codex bundled Python (Pillow).
48x64 native pixels, 12 colors per NPC, shared plum outline, upper-left light.
Design candidates from current fudi_maps.gd roles; no runtime scene changes.
"""
from pathlib import Path
import sys, json, shutil
from PIL import Image, ImageDraw, ImageFont
import os
sys.path.insert(0, str(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills/pixel-art-studio/scripts'))
from pixelstudio import Sprite

ROOT = Path(__file__).resolve().parent
for directory in ('masters', 'display', 'review'):
    (ROOT/directory).mkdir(exist_ok=True)
BASE = ['#292438','#624052','#a6654a','#daa45e','#e7a477','#ffdab0',
        '#24525e','#387d80','#72b4a1','#f5e7c5','#a6a7ae','#bb5254']
CAST = [
 ('zhu-shen','祝婶','灶街掌勺人', ['#793548','#ad5855','#e38c6d']),
 ('a-jian','阿缄','旧城邮差', ['#303f62','#546b99','#91acc0']),
 ('wen-yan','温砚','石像修复师', ['#3d4747','#6a7c69','#a4b38b']),
 ('lu-jianwei','陆见微','记录研究员', ['#453e68','#766a9c','#b1a1ca']),
 ('shi-yi','拾一','救援机偶', ['#254f5d','#427f88','#85c8c0']),
 ('stage-guide','关卡向导','主城引路人', ['#244e56','#347a78','#78b69e']),
]

class Artist:
    def __init__(self, palette):
        self.s=Sprite(48,64,palette=palette)
        self.p=palette
    def poly(self, pts,c): self.s.polygon(pts,self.p[c])
    def r(self,a,b,c,d,col): self.s.rect(a,b,c,d,self.p[col])
    def l(self,a,b,c,d,col): self.s.line(a,b,c,d,self.p[col])
    def dot(self,x,y,c): self.s.px(x,y,self.p[c])
    def face(self, older=False, feminine=False):
        self.poly([(16,12),(28,12),(31,16),(30,23),(27,26),(20,26),(16,22)],4)
        self.poly([(17,14),(25,14),(26,18),(24,21),(18,20),(16,17)],5)
        self.r(14,17,16,20,2); self.r(15,17,16,19,4)
        self.r(30,17,31,20,2)
        self.r(18,17,20,17,1); self.r(26,17,28,17,1)
        self.r(19,18,20,19,0); self.r(27,18,28,19,0)
        self.r(23,19,24,21,4)
        self.l(23,24,25,24,2 if older else 1)
        if older:
            self.l(17,21,19,21,2); self.l(28,21,29,21,2)
        if feminine: self.l(21,23,24,23,11)
    def boots(self):
        self.r(15,47,29,56,6); self.r(16,48,20,55,7)
        self.l(22,49,22,57,0)
        self.poly([(15,55),(20,55),(19,60),(10,60),(11,58)],1)
        self.l(12,57,18,57,2); self.l(11,60,19,60,0)
        self.poly([(25,55),(29,55),(30,58),(33,59),(33,60),(25,60)],1)
        self.l(26,56,29,56,2); self.l(25,60,33,60,0)
    def human_base(self, wide=False):
        left,right=(9,35) if wide else (11,33)
        self.poly([(17,8),(27,8),(31,12),(32,22),(28,26),(right,29),
         (right+2,38),(right,44),(31,50),(30,57),(34,59),(34,61),
         (24,61),(22,54),(20,54),(20,61),(9,61),(9,58),(13,55),
         (13,50),(left,46),(left-2,39),(left,30),(17,26),(13,21),(13,14)],0)
        self.boots()
        self.poly([(16,27),(28,27),(right,31),(right,45),(29,50),(14,50),(left,44),(left,33)],6)
        self.poly([(16,28),(22,29),(20,45),(14,47),(left+1,40),(left+2,33)],7)
        self.poly([(16,29),(18,30),(16,37),(left+2,38),(left+2,34)],8)
        self.poly([(24,29),(29,29),(right-1,33),(right-2,40),(27,47),(23,44)],7)
        self.r(20,24,26,29,2); self.r(20,25,24,28,4)
        self.face()

def zhu(a):
    a.human_base(wide=True)
    # Gray bun and swept hair; coral blouse, broad ivory apron, ladle.
    a.poly([(14,10),(13,6),(15,3),(20,3),(23,6),(22,10)],0)
    a.poly([(15,6),(16,4),(20,4),(21,7),(18,9)],10)
    a.poly([(14,13),(16,10),(21,9),(28,11),(31,14),(29,16),(24,13),(19,14),(16,18),(14,17)],1)
    a.l(16,11,21,10,10); a.face(older=True, feminine=True)
    a.poly([(18,29),(21,30),(22,34),(26,31),(28,29),(30,35),(29,47),(15,47),(14,35)],9)
    a.poly([(23,36),(28,35),(27,46),(22,46)],3)
    a.r(15,36,29,38,2); a.r(16,37,28,37,3)
    a.r(18,40,24,44,1); a.r(18,40,23,43,9)
    a.poly([(9,32),(13,33),(13,41),(11,44),(8,41)],7)
    a.r(9,41,12,44,4); a.l(9,41,11,41,5)
    a.poly([(31,30),(35,32),(37,37),(35,40),(32,37)],7)
    a.r(34,37,37,40,4)
    a.r(38,26,39,45,0); a.r(38,27,38,44,2)
    a.poly([(35,23),(37,21),(40,21),(42,23),(42,26),(40,28),(37,28),(35,26)],0)
    a.poly([(36,23),(38,22),(40,22),(41,24),(40,26),(37,26)],10)
    a.l(37,23,39,23,9)

def ajian(a):
    # Tall pack changes the silhouette before the body is filled.
    a.poly([(29,25),(36,25),(39,29),(39,43),(34,47),(29,44)],0)
    a.r(32,28,37,41,2); a.r(33,29,36,33,3)
    a.human_base()
    a.poly([(16,12),(16,7),(20,5),(29,6),(32,10),(31,13)],0)
    a.poly([(17,10),(19,7),(28,7),(30,10)],7)
    a.l(19,7,26,7,8); a.poly([(15,11),(29,10),(34,13),(30,15),(17,14)],6)
    a.l(17,12,29,12,3); a.r(23,9,25,10,9)
    a.poly([(15,14),(18,14),(16,19),(14,20)],1)
    # Saffron scarf and a long tail beside the bag.
    a.poly([(18,26),(25,27),(29,25),(30,28),(24,31),(18,29)],3)
    a.poly([(19,29),(22,30),(19,37),(16,36)],2)
    a.poly([(28,29),(30,30),(16,44),(14,43)],1)
    a.l(28,30,16,42,3)
    a.poly([(9,41),(17,40),(21,43),(20,50),(10,51),(8,48)],0)
    a.poly([(10,42),(17,42),(19,44),(18,49),(11,49),(9,47)],2)
    a.poly([(10,42),(17,42),(19,44),(14,46),(10,45)],3)
    a.r(14,45,15,47,1)
    # Deliberately visible near hand; far hand holds sealed correspondence.
    a.r(11,38,14,41,4); a.l(11,38,13,38,5)
    a.poly([(32,33),(35,34),(37,38),(35,41),(32,39)],7)
    a.r(33,38,36,41,4)
    a.poly([(31,31),(42,31),(43,38),(32,39)],0)
    a.poly([(32,32),(41,32),(42,37),(33,38)],9)
    a.l(32,32,37,35,3); a.l(37,35,41,32,3); a.r(36,35,38,36,11)

def wen(a):
    a.human_base(wide=True)
    a.poly([(14,15),(14,10),(18,7),(27,7),(31,10),(31,16),(28,15),(26,12),(21,14),(18,13),(16,18)],1)
    a.poly([(16,11),(19,9),(25,9),(27,10),(21,11),(18,13)],2)
    a.r(15,16,16,20,1); a.r(29,17,30,21,1)
    a.poly([(18,28),(20,29),(21,34),(25,34),(27,28),(29,29),(29,47),(15,47),(15,32)],2)
    a.poly([(17,32),(19,34),(19,44),(16,45)],3)
    a.r(20,38,26,42,1); a.l(21,39,25,39,3)
    a.r(17,44,29,46,1); a.r(22,44,24,46,3)
    # Tool roll and miniature mallet behind left hand.
    a.r(7,27,8,40,0); a.r(7,28,7,38,2)
    a.poly([(4,26),(5,23),(12,23),(13,25),(12,28),(5,28)],0)
    a.r(5,24,11,26,10); a.l(5,24,8,24,9)
    a.poly([(9,32),(13,33),(14,38),(11,41),(8,39)],7)
    a.r(7,37,11,40,4); a.l(7,37,10,37,5)
    # Rigid handled tool chest, lowered in right hand.
    a.r(34,39,39,44,0); a.r(35,40,38,43,2); a.r(36,41,37,42,0)
    a.poly([(31,43),(42,43),(44,46),(43,53),(31,53),(29,50)],0)
    a.r(31,45,42,51,2); a.r(31,45,41,47,3)
    a.l(31,48,42,48,1); a.r(36,47,37,49,10)
    a.poly([(32,32),(35,34),(37,38),(36,41),(33,39),(31,36)],7)
    a.r(34,38,37,41,4)

def lu(a):
    # Ponytail before face and long lavender field coat.
    a.poly([(28,11),(33,13),(34,23),(37,28),(34,31),(30,27),(29,20)],0)
    a.poly([(31,15),(32,23),(35,28),(32,26)],1)
    a.human_base()
    a.poly([(15,12),(16,8),(21,6),(28,8),(31,12),(30,16),(27,15),(24,12),(20,13),(16,17)],1)
    a.l(19,9,24,8,10)
    a.face(feminine=True)
    # Glasses: connected bridge, warm face remains visible below.
    a.r(17,17,21,20,0); a.r(25,17,29,20,0)
    a.r(18,18,20,19,5); a.r(26,18,28,19,5)
    a.dot(20,19,0); a.dot(28,19,0); a.l(22,18,24,18,0)
    a.poly([(18,28),(22,30),(25,28),(27,32),(23,42),(19,36)],9)
    a.poly([(14,35),(19,39),(21,45),(19,53),(12,52)],7)
    a.poly([(27,36),(32,34),(33,51),(25,53),(24,44)],6)
    a.l(14,48,18,48,8); a.l(27,50,30,49,8)
    a.r(21,33,23,36,3)
    # Open record folio held forward; both hands grip its bottom corners.
    a.poly([(10,33),(21,34),(25,37),(34,34),(36,35),(36,44),(25,47),(20,44),(10,43)],0)
    a.poly([(12,34),(20,35),(24,38),(24,45),(20,43),(12,42)],9)
    a.poly([(25,38),(34,35),(34,43),(25,45)],3)
    a.l(15,37,20,38,10); a.l(15,40,20,41,10)
    a.l(28,39,32,38,1); a.l(28,42,32,41,1)
    a.r(11,41,14,44,4); a.l(11,41,13,41,5)
    a.r(33,42,36,45,4)

def shiyi(a):
    # Mechanical paired anatomy, antenna, asymmetric rescue pack.
    a.poly([(31,25),(37,25),(40,29),(40,42),(34,44),(30,39)],0)
    a.r(34,28,38,38,2); a.r(35,28,37,31,3)
    a.poly([(14,26),(29,26),(34,30),(36,43),(31,49),(30,57),(34,58),
     (34,61),(24,61),(22,53),(21,53),(20,61),(10,61),(10,58),(14,56),
     (13,49),(8,43),(9,32)],0)
    a.r(14,47,20,56,6); a.r(25,47,30,56,6)
    a.r(15,48,19,51,10); a.r(26,48,29,51,10)
    a.poly([(14,55),(20,55),(19,59),(11,59),(12,57)],7)
    a.poly([(25,55),(30,55),(30,57),(33,58),(33,59),(25,59)],7)
    a.l(12,57,17,57,8); a.l(26,56,29,56,8)
    a.poly([(15,27),(28,27),(32,31),(31,45),(27,49),(16,48),(12,42),(12,32)],6)
    a.poly([(15,28),(21,29),(19,43),(15,44),(13,39),(13,33)],7)
    a.poly([(21,29),(27,29),(30,32),(28,40),(20,40)],9)
    a.poly([(24,31),(26,32),(26,35),(24,37),(22,35),(22,32)],8)
    a.r(16,44,29,46,1); a.r(21,44,24,46,3)
    a.poly([(10,31),(14,32),(14,37),(11,39),(8,37)],10)
    a.r(9,39,12,44,6); a.r(9,40,11,42,7)
    a.poly([(8,43),(12,43),(14,46),(12,48),(8,47)],10)
    a.r(9,44,11,46,9)
    a.poly([(31,31),(35,32),(37,36),(34,39),(31,36)],10)
    a.r(34,39,37,44,6); a.r(35,40,36,42,7)
    a.poly([(34,43),(38,43),(40,46),(38,48),(34,47)],10)
    a.r(35,44,37,46,9)
    a.r(20,22,26,27,0); a.r(21,23,25,26,10)
    a.poly([(14,10),(18,6),(28,6),(33,10),(33,21),(29,25),(17,24),(13,20),(13,13)],0)
    a.poly([(15,11),(19,8),(27,8),(31,11),(31,20),(28,23),(18,22),(15,19)],10)
    a.poly([(16,11),(20,8),(26,8),(28,10),(21,11),(17,14)],9)
    a.poly([(16,14),(29,13),(31,15),(30,20),(17,20),(15,18)],6)
    a.r(18,16,20,18,8); a.r(26,16,28,18,8)
    a.l(18,16,20,16,9); a.l(26,16,28,16,9)
    a.r(22,22,26,22,6)
    a.r(29,3,30,8,0); a.r(29,3,30,5,11)
    # Rescue marker on shoulder, broad clusters rather than tiny lettering.
    a.r(31,30,34,33,11); a.r(32,30,33,33,9)

def guide(a):
    # Long staff and pennant create a distinct silhouette.
    a.r(38,16,40,59,0); a.r(39,17,39,58,2)
    a.poly([(40,17),(46,18),(44,22),(45,24),(40,24)],0)
    a.poly([(41,18),(44,19),(43,21),(44,23),(41,22)],3)
    a.human_base()
    a.poly([(16,29),(20,28),(23,34),(27,28),(31,30),(33,49),(29,55),(24,53),(22,47),(18,54),(11,52)],6)
    a.poly([(16,30),(20,31),(20,42),(17,50),(13,50)],7)
    a.poly([(27,30),(30,31),(31,48),(27,51),(24,44)],7)
    a.poly([(20,29),(23,32),(26,29),(25,37),(22,40),(20,35)],9)
    a.l(16,49,18,45,3); a.l(27,49,29,48,3)
    a.r(14,42,31,44,1); a.r(21,42,24,44,3)
    a.poly([(15,12),(16,7),(22,3),(29,7),(31,13),(28,16),(24,12),(20,14),(15,18)],0)
    a.poly([(16,12),(17,7),(22,4),(28,8),(30,13),(27,15),(24,11),(20,13),(16,17)],9)
    a.poly([(18,9),(22,6),(26,8),(24,10),(20,11)],10)
    a.r(15,16,16,20,10)
    a.poly([(19,22),(22,23),(26,22),(28,23),(26,28),(23,30),(20,27)],9)
    a.l(22,24,24,25,10)
    a.poly([(31,31),(35,33),(37,37),(40,38),(40,41),(35,41),(31,37)],7)
    a.r(37,37,40,40,4); a.l(37,37,39,37,5)
    # Folded map in near hand.
    a.poly([(7,35),(11,34),(15,36),(17,35),(18,43),(14,45),(10,43),(7,44)],0)
    a.poly([(8,36),(11,35),(14,37),(16,36),(17,42),(14,43),(10,42),(8,43)],9)
    a.l(11,37,12,41,3); a.l(14,38,15,41,10)
    a.r(11,43,14,45,4)

DRAWERS=[zhu,ajian,wen,lu,shiyi,guide]
manifest=[]
for (slug,name,role,cloth),drawer in zip(CAST,DRAWERS):
    palette=BASE.copy(); palette[6:9]=cloth
    a=Artist(palette); drawer(a)
    a.s.save_png(str(ROOT/'masters'/f'{slug}.png'))
    a.s.save_png(str(ROOT/'display'/f'{slug}-8x.png'),scale=8)
    a.s.save_silhouette(str(ROOT/'review'/f'{slug}-silhouette.png'))
    stats=a.s.stats(print_=False)
    manifest.append(dict(id=slug,name=name,role=role,canvas=[48,64],foot_anchor=[24,61],
                         master=f'masters/{slug}.png',display=f'display/{slug}-8x.png',stats=stats))

# Retain the already approved merchant, with its existing regenerable source.
merchant=ROOT/'sources'/'merchant.png'
shutil.copy2(merchant,ROOT/'masters'/'merchant.png')
Image.open(merchant).resize((384,512),Image.Resampling.NEAREST).save(ROOT/'display'/'merchant-8x.png')
manifest.append(dict(id='merchant',name='城镇商人',role='通用商人',canvas=[48,64],foot_anchor=[24,61],
                     master='masters/merchant.png',display='display/merchant-8x.png'))

# Presentation sheets use a flat background, never baked checkerboards in masters.
fontpath=Path('C:/Windows/Fonts/msyh.ttc')
font=ImageFont.truetype(str(fontpath),20) if fontpath.exists() else ImageFont.load_default()
small=ImageFont.truetype(str(fontpath),14) if fontpath.exists() else font
sheet=Image.new('RGB',(1008,820),'#ebe3d3')
d=ImageDraw.Draw(sheet)
for i,m in enumerate(manifest):
    col,row=i%4,i//4; x,y=col*252,row*410
    d.rounded_rectangle((x+8,y+8,x+244,y+402),radius=12,fill='#f7f0e1')
    im=Image.open(ROOT/m['master']).convert('RGBA').resize((240,320),Image.Resampling.NEAREST)
    sheet.paste(im,(x+6,y+15),im)
    d.text((x+126,y+344),m['name'],font=font,anchor='mt',fill='#292438')
    d.text((x+126,y+375),m['role'],font=small,anchor='mt',fill='#624052')
sheet.save(ROOT/'npc-cast-overview.png')
sil=Image.new('RGB',(48*4,64*2),'#ebe3d3')
for i,m in enumerate(manifest):
    im=Image.open(ROOT/m['master']).convert('RGBA')
    ink=Image.new('RGBA',im.size,'#292438'); ink.putalpha(im.getchannel('A'))
    sil.paste(ink,((i%4)*48,(i//4)*64),ink)
sil.resize((768,512),Image.Resampling.NEAREST).save(ROOT/'review'/'silhouettes.png')
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
atlas=Image.new('RGBA',(48*7,64))
for i,m in enumerate(manifest):
    atlas.paste(Image.open(ROOT/m['master']).convert('RGBA'),(48*i,0))
atlas.save(ROOT/'npc-atlas.png')
(ROOT/'npc-atlas.json').write_text(json.dumps(dict(image='npc-atlas.png',frames=[
    dict(id=m['id'],name=m['name'],x=i*48,y=0,w=48,h=64,foot_anchor=[24,61])
    for i,m in enumerate(manifest)]),ensure_ascii=False,indent=2),encoding='utf-8')
for m in manifest:
    im=Image.open(ROOT/m['master']).convert('RGBA')
    colors=im.getcolors(48*64)
    opaque=[c for n,c in colors if c[3]]
    assert im.size==(48,64) and len(opaque)<=12
    assert all(c[3] in (0,255) for n,c in colors)
    assert im.getbbox()[0]>0 and im.getbbox()[2]<48
    print(m['id'],len(opaque),'colors',im.getbbox())
print('Saved seven NPCs and overview:',ROOT)
