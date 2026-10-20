"""Ten NPCs from the user's merchant / trades / theology character draft.
All shapes drawn at 48x64 with pixelstudio; 12-color budgets, upper-left light.
"""
from pathlib import Path
import sys,json,ast
from PIL import Image,ImageDraw,ImageFont
import os
sys.path.insert(0, str(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills/pixel-art-studio/scripts'))
from pixelstudio import Sprite

ROOT=Path(__file__).resolve().parent
for p in ('masters','display','review','sources'): (ROOT/p).mkdir(exist_ok=True)
# Vendor only the shared drawing class and palette, keeping this collection standalone.
common=ROOT/'sources'/'artist.py'
if not common.exists():
    tree=ast.parse((ROOT.parent/'npc-cast'/'build.py').read_text(encoding='utf-8-sig'))
    nodes=[n for n in tree.body if (isinstance(n,ast.ClassDef) and n.name=='Artist') or
           (isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='BASE' for t in n.targets))]
    common.write_text('from pixelstudio import Sprite\n'+ast.unparse(ast.Module(body=nodes,type_ignores=[]))+'\n',encoding='utf-8')
sys.path.insert(0,str(ROOT/'sources'))
from artist import Artist,BASE

CAST=[
 ('lu-yan','路盐','旧路行商',['#594b43','#92845e','#c5bd88']),
 ('jin-suanpan','金算盘','寄售与仓储装置',['#584060','#936852','#85c8c0']),
 ('shen-heng','沈衡','续灯商会发起人',['#303f62','#526b8a','#91aeb1']),
 ('luo-zhu','洛铸','救援铁匠',['#713348','#985054','#d48266']),
 ('ye-ting','叶汀','复苏照护药剂师',['#2b5154','#4a8777','#8ebca1']),
 ('qiao-huang','乔簧','维修人偶机关师',['#4a485b','#8e7657','#c6b178']),
 ('cen-chi','岑尺','旧测绘站回响',['#30495d','#577e91','#94c2c1']),
 ('xie-tingzhou','谢停舟','守灯会司灯人',['#404354','#666e80','#bec4d1']),
 ('wen-zhou','闻昼','神学研究者',['#49385e','#7c5e85','#b496b0']),
 ('changdaozhe','长祷者','祈愿无名异灵',['#3f3a5c','#6d678d','#ada1bb']),
]

def hair(a,gray=False):
    a.poly([(14,16),(14,11),(17,8),(26,7),(30,10),(31,15),(28,16),(25,12),(21,14),(18,13),(16,18)],0)
    a.poly([(15,13),(18,9),(25,8),(28,10),(28,12),(23,11),(20,13),(17,14)],10 if gray else 1)
    a.l(18,10,23,9,9 if gray else 2)

def belt(a):
    a.r(14,43,31,45,1); a.r(22,43,25,45,3); a.r(23,44,24,44,0)

def hands(a):
    a.r(10,39,13,43,4); a.l(10,39,12,39,5)
    a.r(32,39,35,43,4); a.l(32,39,34,39,5)

def luyan(a):
    # A compact handcart, integrated in the same native-size cell.
    a.poly([(31,33),(43,33),(45,38),(45,54),(39,57),(31,53)],0)
    a.r(32,36,43,51,2); a.r(32,36,42,38,3)
    a.l(34,40,34,49,1); a.l(39,40,39,50,1); a.l(32,47,43,47,1)
    a.poly([(32,29),(38,28),(42,31),(42,35),(32,35)],3)
    a.r(35,29,36,35,9); a.r(39,31,44,35,7)
    a.poly([(35,52),(40,52),(42,54),(42,58),(40,60),(36,60),(33,57),(33,54)],0)
    a.poly([(36,53),(39,53),(41,55),(41,57),(39,59),(36,59),(34,56)],1)
    a.r(37,55,38,57,3)
    a.human_base()
    a.poly([(15,28),(20,30),(18,46),(13,49),(11,42)],7)
    a.poly([(25,29),(30,30),(31,46),(26,49),(23,43)],6)
    a.poly([(18,27),(25,28),(29,26),(29,29),(23,32),(18,30)],11)
    a.poly([(19,31),(22,32),(19,39),(16,38)],2)
    hair(a)
    # Weathered broad conical hat.
    a.poly([(6,13),(11,10),(20,4),(24,4),(33,10),(37,13),(36,16),(25,17),(15,16),(6,16)],0)
    a.poly([(8,13),(20,5),(24,5),(33,12),(35,13),(24,15),(15,14)],3)
    a.poly([(10,13),(20,6),(22,6),(18,12)],9)
    a.l(18,12,29,13,2); a.l(8,15,18,15,1)
    a.poly([(10,31),(14,32),(14,38),(12,42),(9,41)],7)
    a.r(10,40,13,43,4)
    a.poly([(31,32),(34,34),(35,40),(38,41),(38,44),(33,44),(30,38)],7)
    a.r(35,40,38,43,4); belt(a)
    a.r(8,43,15,49,0); a.r(9,44,14,48,2); a.l(10,44,13,44,3)

def abacus(a):
    # A sentient abacus, not a human with an abacus accessory.
    a.poly([(12,13),(32,13),(35,16),(35,36),(31,40),(13,40),(10,36),(10,16)],0)
    a.r(12,15,32,36,2); a.r(14,17,30,34,0)
    a.l(13,15,31,15,3); a.l(12,16,12,33,3)
    for y in (20,25,30):
        a.l(14,y,30,y,10)
        for x in ((16,22,28) if y!=25 else (18,24,28)):
            a.r(x-1,y-1,x+1,y+1,3)
            a.dot(x-1,y-1,9)
    a.r(18,18,20,20,8); a.r(26,18,28,20,8)
    a.l(20,33,26,33,8)
    a.r(16,39,29,43,6); a.r(18,40,27,42,7)
    a.poly([(14,43),(29,43),(33,48),(30,54),(13,54),(10,49)],0)
    a.poly([(15,44),(28,44),(31,48),(28,51),(14,51),(12,48)],7)
    a.r(18,46,26,49,3); a.r(20,47,24,48,6)
    a.r(14,53,18,58,1); a.r(26,53,30,58,1)
    a.r(11,58,19,61,0); a.r(24,58,33,61,0)
    a.l(12,58,17,58,3); a.l(25,58,30,58,3)
    a.poly([(9,30),(12,31),(10,40),(7,43),(5,40),(7,34)],0)
    a.r(7,34,8,39,2); a.r(5,40,8,43,3)
    a.poly([(33,29),(37,29),(39,34),(41,37),(39,41),(35,38),(34,34)],0)
    a.r(35,31,36,36,2); a.r(36,36,40,39,3)
    # Ledger hologram, hard-edged to preserve usable alpha.
    a.poly([(34,23),(43,24),(44,33),(34,32)],0)
    a.poly([(35,24),(42,25),(43,32),(35,31)],8)
    a.l(37,26,41,26,6); a.l(37,29,41,29,6)

def shen(a):
    a.human_base(); hair(a)
    a.poly([(15,28),(19,28),(22,34),(20,44),(14,48),(12,43)],7)
    a.poly([(27,28),(30,29),(32,45),(26,48),(24,35)],7)
    a.poly([(20,29),(23,31),(26,29),(25,39),(22,42),(20,36)],9)
    a.poly([(23,31),(25,33),(24,38),(22,36)],11)
    a.l(16,30,20,35,8); a.l(28,30,25,35,8)
    belt(a); hands(a)
    # Light warehouse dust on one cuff, plus dispatch clipboard.
    a.r(10,37,14,39,10); a.r(11,37,12,38,9)
    a.poly([(29,32),(39,30),(42,45),(31,47)],0)
    a.poly([(30,33),(38,32),(40,44),(32,45)],2)
    a.poly([(31,34),(37,33),(39,43),(33,44)],9)
    a.r(33,32,36,34,10)
    a.l(33,37,37,37,1); a.l(34,40,38,40,1)
    a.r(31,43,34,46,4)
    a.r(16,35,18,37,3)

def luo(a):
    a.human_base(wide=True)
    hair(a,gray=True)
    a.poly([(17,22),(20,23),(25,23),(28,21),(28,25),(24,28),(20,27)],1)
    a.poly([(14,28),(17,28),(19,33),(26,33),(28,28),(31,30),(31,48),(14,48)],2)
    a.poly([(16,34),(20,34),(20,44),(16,46)],3)
    a.r(20,37,27,41,1); a.l(21,38,26,38,3)
    belt(a)
    # Rolled sleeves and bare strong forearms.
    a.poly([(9,31),(14,32),(14,36),(9,37),(7,35)],10)
    a.poly([(8,37),(13,37),(13,43),(10,45),(7,42)],4)
    a.l(8,38,10,38,5)
    a.poly([(31,31),(35,33),(36,37),(32,38),(30,35)],10)
    a.poly([(32,38),(36,37),(38,43),(35,46),(32,43)],4)
    a.l(33,39,35,39,5)
    # Long-handled rescue sledge and forged tongs.
    a.r(6,26,8,54,0); a.r(7,27,7,53,2)
    a.poly([(3,22),(5,20),(13,20),(15,23),(14,27),(4,27)],0)
    a.r(4,22,13,25,10); a.l(5,21,11,21,9)
    a.poly([(34,43),(36,43),(38,47),(40,52),(39,53),(36,48),(35,46)],0)
    a.poly([(38,43),(40,43),(38,48),(36,53),(34,53),(36,47)],0)
    a.l(35,44,39,51,10); a.l(39,44,35,52,10)

def ye(a):
    # Long tied hair, compact medicine case, medicinal flask.
    a.poly([(28,10),(33,13),(34,24),(37,28),(33,31),(29,24)],0)
    a.poly([(31,15),(32,24),(34,28),(31,26)],1)
    a.human_base(); hair(a); a.face(feminine=True)
    a.poly([(18,28),(21,30),(24,30),(27,28),(31,34),(29,48),(16,48),(14,35)],9)
    a.poly([(16,29),(18,30),(19,38),(16,44),(12,47),(12,34)],7)
    a.poly([(28,29),(31,30),(33,47),(29,50),(26,40)],7)
    a.l(15,33,15,38,8); a.r(17,43,29,45,2)
    a.r(22,43,24,45,3)
    a.r(9,40,12,44,4); a.l(9,40,11,40,5)
    a.r(8,44,13,47,0); a.r(9,45,12,46,3)
    a.r(6,47,17,54,0); a.r(7,48,16,53,2)
    a.r(10,48,13,52,9); a.r(9,49,14,51,9)
    a.poly([(32,33),(35,33),(36,38),(39,40),(39,45),(32,45),(31,42),(33,38)],0)
    a.r(33,34,35,36,3)
    a.poly([(34,37),(35,37),(35,39),(38,41),(38,44),(33,44),(32,42),(34,39)],8)
    a.l(33,41,33,43,9)
    a.r(32,39,35,42,4)
    # Tiny herb sprig in hair, leaves form three-pixel clusters.
    a.l(28,10,31,14,6); a.r(28,9,30,10,8); a.r(31,11,33,12,7)

def qiao(a):
    # An enormous articulated tool pack establishes identity.
    a.poly([(9,22),(34,20),(40,26),(41,46),(35,51),(11,49),(7,43)],0)
    a.poly([(11,24),(33,22),(38,27),(39,43),(34,48),(12,46),(9,41)],2)
    a.r(32,24,36,28,3); a.l(36,30,37,41,1)
    a.r(10,18,12,29,0); a.r(11,19,11,27,10)
    a.poly([(8,17),(8,13),(10,12),(10,16),(13,16),(13,12),(15,13),(15,18),(12,20)],0)
    a.l(9,17,13,17,10)
    a.poly([(16,29),(28,29),(33,34),(32,48),(29,53),(16,53),(12,47),(12,35)],0)
    a.poly([(17,31),(27,31),(30,35),(29,48),(26,51),(17,50),(14,45),(14,36)],7)
    a.poly([(17,32),(21,32),(20,44),(16,46),(15,39)],8)
    a.r(20,37,26,43,1); a.r(21,38,25,42,3); a.r(22,39,24,41,6)
    a.r(15,51,20,57,1); a.r(25,51,30,57,1)
    a.r(16,53,19,55,10); a.r(26,53,29,55,10)
    a.poly([(14,56),(20,56),(20,61),(10,61),(10,59)],0)
    a.poly([(25,56),(30,56),(33,59),(33,61),(24,61)],0)
    a.r(12,58,18,59,7); a.r(26,58,30,59,7)
    a.poly([(16,11),(21,8),(29,10),(32,15),(31,24),(27,28),(17,26),(13,21),(13,15)],0)
    a.poly([(17,13),(22,10),(28,12),(30,16),(29,23),(26,26),(18,24),(15,20),(15,16)],3)
    a.poly([(17,14),(21,12),(25,12),(23,15),(17,18)],9)
    a.r(17,17,21,21,0); a.r(25,17,29,21,0)
    a.r(18,18,20,20,8); a.r(26,18,28,20,8)
    a.l(21,19,24,19,1); a.l(21,24,25,24,1)
    a.poly([(10,33),(14,33),(14,38),(10,39),(8,37)],10)
    a.r(9,39,12,44,1); a.r(10,40,11,43,3)
    a.poly([(8,44),(13,44),(14,48),(11,50),(8,48)],0)
    a.r(9,45,12,47,3)
    a.poly([(31,34),(35,35),(37,40),(34,42),(31,39)],10)
    a.r(34,42,37,46,1); a.r(35,43,36,45,3)
    a.r(34,46,38,49,0); a.r(35,47,37,48,3)

def cen(a):
    a.human_base(); hair(a,gray=True)
    a.poly([(14,27),(18,27),(21,33),(25,31),(29,27),(33,30),(31,38),(25,40),(18,38),(12,34)],6)
    a.poly([(14,29),(18,29),(21,35),(25,34),(28,30),(29,33),(24,38),(18,36)],8)
    belt(a)
    # Compass pendant and rolled survey chart.
    a.l(23,34,23,39,3); a.r(21,38,25,42,0); a.r(22,39,24,41,3)
    a.dot(23,39,9); a.r(9,39,12,43,4)
    a.poly([(7,35),(10,34),(15,43),(12,46),(9,42)],0)
    a.poly([(8,36),(10,35),(14,43),(12,44)],9)
    a.l(10,39,12,42,3)
    # Folded survey tripod, fully separate from the torso.
    a.poly([(36,28),(39,28),(40,33),(38,36),(42,59),(40,60),(37,40),(35,59),(33,59),(36,35),(34,33)],0)
    a.r(35,30,39,32,10); a.r(36,30,38,30,9)
    a.l(37,36,34,58,3); a.l(38,37,41,58,2)
    a.poly([(31,32),(34,33),(37,37),(37,40),(34,41),(31,37)],7)
    a.r(35,37,38,40,4)
    # Split translucent-looking cloth remains binary-alpha for sprites.
    a.poly([(15,46),(19,47),(18,52),(14,54),(12,51)],8)
    a.poly([(26,47),(30,46),(31,52),(27,54),(25,51)],7)

def xie(a):
    a.human_base(); hair(a)
    a.poly([(15,28),(19,28),(22,34),(26,29),(29,28),(33,45),(32,55),(27,57),(23,53),(19,57),(11,55),(11,44)],0)
    a.poly([(16,29),(19,30),(21,35),(20,49),(17,54),(13,53),(13,43)],7)
    a.poly([(27,30),(29,30),(31,44),(30,53),(27,54),(23,50),(23,36)],6)
    a.poly([(21,29),(24,30),(26,29),(25,37),(22,40),(20,35)],9)
    a.l(17,30,18,35,8); a.l(14,52,18,52,8)
    a.r(14,43,29,45,1); a.r(22,43,24,45,3)
    # Visible mended hem, square patch with a small stitch.
    a.r(14,46,18,50,2); a.l(15,47,17,49,3)
    a.r(10,38,13,42,4)
    a.poly([(30,32),(34,34),(36,38),(39,39),(38,42),(34,42),(30,37)],7)
    a.r(35,38,38,41,4)
    # Oil lantern: handle, framed glass, single warm flame.
    a.poly([(37,41),(40,41),(42,44),(42,47),(35,47),(35,44)],0)
    a.l(37,42,40,42,3); a.l(36,44,36,46,3); a.l(41,44,41,46,2)
    a.poly([(34,47),(43,47),(44,50),(43,57),(34,57),(33,50)],0)
    a.r(35,49,42,55,3); a.r(37,50,40,54,2)
    a.poly([(38,50),(39,49),(40,52),(39,54),(37,53)],9)
    a.l(34,48,42,48,10); a.l(34,56,42,56,2)
    a.l(35,49,35,55,1); a.l(42,49,42,55,1)

def wenzhou(a):
    a.poly([(28,10),(33,13),(33,22),(36,27),(33,30),(29,25)],0)
    a.human_base(); hair(a)
    a.poly([(15,28),(20,28),(23,33),(27,28),(30,29),(33,49),(29,55),(23,53),(17,55),(11,52)],6)
    a.poly([(16,30),(20,31),(21,44),(18,52),(13,50)],7)
    a.poly([(27,30),(30,32),(31,47),(27,51),(24,44)],7)
    a.poly([(20,28),(23,30),(26,28),(26,35),(23,38),(20,34)],9)
    a.l(20,37,21,47,3); a.l(26,37,26,47,3)
    a.r(15,45,30,47,1); a.r(22,45,24,47,3)
    # Narrow spectacles, readable under dark brows.
    a.l(17,18,21,18,0); a.l(25,18,29,18,0); a.l(22,18,24,18,0)
    a.r(18,19,20,20,10); a.r(26,19,28,20,10)
    # Closed annotated codex clasped at chest, multiple paper tabs.
    a.poly([(11,33),(24,31),(29,35),(29,46),(15,48),(10,44)],0)
    a.poly([(12,34),(24,33),(27,36),(27,45),(15,46),(12,43)],2)
    a.poly([(12,34),(16,34),(17,45),(15,46),(12,43)],3)
    a.l(18,35,24,35,9); a.r(20,38,23,41,3)
    a.r(25,35,28,36,9); a.r(26,40,29,41,9); a.r(25,44,28,45,9)
    a.r(11,42,14,45,4); a.r(27,41,30,44,4)

def prayer(a):
    # Hood encloses a deliberate faceless void; hands and feet under broad robe.
    a.poly([(23,4),(28,6),(33,12),(34,21),(31,27),(35,31),(38,44),
      (36,51),(38,57),(34,60),(28,59),(24,61),(19,59),(12,60),
      (9,56),(12,49),(9,43),(12,32),(17,27),(13,22),(13,14),(17,8)],0)
    a.poly([(23,6),(27,8),(31,14),(32,21),(28,26),(19,26),(15,21),(15,15),(18,10)],7)
    a.poly([(22,8),(25,8),(21,13),(18,20),(16,20),(17,14)],8)
    a.poly([(22,13),(26,12),(29,16),(29,22),(26,25),(20,24),(18,20),(19,16)],0)
    a.poly([(20,25),(28,25),(32,30),(35,43),(33,49),(35,56),(28,57),(24,59),(19,57),(12,57),(14,48),(12,41),(15,32)],6)
    a.poly([(18,29),(22,31),(20,43),(17,51),(16,56),(13,56),(15,46),(13,40),(16,33)],7)
    a.poly([(26,29),(30,31),(33,41),(30,48),(32,55),(27,56),(24,48)],7)
    a.l(19,32,17,38,8); a.l(27,48,28,53,8)
    # Gloved hands fold around an empty prayer cord, both visible.
    a.poly([(14,33),(18,35),(20,39),(19,42),(15,41),(12,37)],8)
    a.poly([(29,34),(32,36),(31,41),(26,43),(24,41),(26,38)],7)
    a.r(19,39,22,42,10); a.r(23,39,26,42,10)
    a.l(22,42,23,47,3)
    # Hanging prayer papers: broad, varied ivory/gold clusters; no fake text.
    for x,y,w,h in [(16,26,3,6),(28,27,3,7),(12,43,3,6),(28,44,3,7),(19,49,3,7),(32,51,3,6)]:
        a.r(x,y,x+w,y+h,0); a.r(x+1,y,x+w-1,y+h-1,9)
        a.l(x+1,y+2,x+w-1,y+2,3)
    a.poly([(13,57),(18,57),(18,60),(11,60)],0)
    a.poly([(27,57),(32,57),(35,60),(26,60)],0)

DRAW=[luyan,abacus,shen,luo,ye,qiao,cen,xie,wenzhou,prayer]
manifest=[]
for (slug,name,role,cloth),draw in zip(CAST,DRAW):
    p=BASE.copy(); p[6:9]=cloth
    a=Artist(p); draw(a)
    a.s.save_png(str(ROOT/'masters'/f'{slug}.png'))
    a.s.save_png(str(ROOT/'display'/f'{slug}-8x.png'),scale=8)
    a.s.save_silhouette(str(ROOT/'review'/f'{slug}-silhouette.png'))
    stats=a.s.stats(print_=False)
    manifest.append(dict(id=slug,name=name,role=role,master=f'masters/{slug}.png',
      display=f'display/{slug}-8x.png',size=[48,64],foot_anchor=[24,61],stats=stats))
    print(slug,'colors',stats['colors_used'],'isolated',stats['isolated_px'],'duplicates',stats['near_duplicate_colors'])

font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)
sheet=Image.new('RGB',(252*5,410*2),'#ebe3d3'); d=ImageDraw.Draw(sheet)
sil=Image.new('RGB',(48*5,64*2),'#ebe3d3')
atlas=Image.new('RGBA',(48*5,64*2))
for i,m in enumerate(manifest):
    x,y=(i%5)*252,(i//5)*410
    d.rounded_rectangle((x+8,y+8,x+244,y+402),radius=12,fill='#f7f0e1')
    im=Image.open(ROOT/m['master']).convert('RGBA')
    large=im.resize((240,320),Image.Resampling.NEAREST)
    sheet.paste(large,(x+6,y+15),large)
    d.text((x+126,y+344),m['name'],font=font,anchor='mt',fill='#292438')
    d.text((x+126,y+375),m['role'],font=small,anchor='mt',fill='#624052')
    ink=Image.new('RGBA',im.size,'#292438'); ink.putalpha(im.getchannel('A'))
    sil.paste(ink,((i%5)*48,(i//5)*64),ink)
    atlas.paste(im,((i%5)*48,(i//5)*64))
    opaque=[c for n,c in im.getcolors(3072) if c[3]]
    assert im.size==(48,64) and len(opaque)<=12
    assert set(im.getchannel('A').get_flattened_data())<={0,255}
    box=im.getbbox(); assert box[0]>0 and box[1]>0 and box[2]<48 and box[3]<64
sheet.save(ROOT/'npc-ten-overview.png')
sil.resize((960,512),Image.Resampling.NEAREST).save(ROOT/'review'/'silhouettes.png')
atlas.save(ROOT/'npc-ten-atlas.png')
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'npc-ten-atlas.json').write_text(json.dumps(dict(image='npc-ten-atlas.png',frames=[
    dict(id=m['id'],name=m['name'],x=(i%5)*48,y=(i//5)*64,w=48,h=64,foot_anchor=[24,61])
    for i,m in enumerate(manifest)]),ensure_ascii=False,indent=2),encoding='utf-8')
print('TEN NPCs exported:',ROOT)
