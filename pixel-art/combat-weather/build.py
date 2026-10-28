"""Deterministic native pixel VFX. Run with the bundled Python; Pillow only."""
from pathlib import Path
import sys, math, json
from PIL import Image, ImageDraw, ImageFont
import os
sys.path.insert(0, str(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills/pixel-art-studio/scripts'))
from pixelstudio import Sprite

ROOT = Path(__file__).resolve().parent
DEST = ROOT.parents[1] / 'card-demo/assets/effects/pixel'
DEST.mkdir(parents=True, exist_ok=True)
PALETTES = {
 'sword': ['#30243e','#70394f','#ba535e','#ed9572','#ffd5a0','#fff2d5','#8d7184'],
 'thorn': ['#23393d','#38554e','#64815a','#a4bb6d','#e5dfa0','#fff1cc','#ac784f'],
 'water': ['#24334c','#315b72','#408b98','#80c8c3','#c6f0dc','#f5fff0','#8b9eb3'],
 'holy': ['#35334e','#685469','#ac8b82','#dbbd91','#f7e4b7','#fff8e1','#a9bfd1'],
 'ice': ['#293251','#435887','#5f94b8','#92d6e0','#d6f4ef','#fbffff','#9b80c3'],
 'bell': ['#352d40','#6b4a49','#a57350','#d8aa63','#f2d697','#fff4ce','#789a9d'],
 'rain': ['#23374e','#395f84','#5f9fbd','#93cee0','#d5f3ed','#f5fff7','#779bb1'],
 'clear': ['#2e3b3d','#626e50','#9eae64','#cdd58a','#f1e4b1','#fff7d6','#6c9c88'],
 'fog': ['#302c4e','#514667','#7a7291','#afa1bd','#d8c9d8','#f1e3ed','#7a9fb2'],
 'wind': ['#263e46','#40716d','#72a395','#a6cdb2','#d8e8cc','#f5f6df','#96a7b5'],
 'heat': ['#40283d','#80414b','#bf624f','#ed9d63','#ffd88d','#fff1c1','#ad794f'],
 'storm': ['#2e2b50','#544580','#8273b4','#afa8e0','#ded9fb','#fff8ea','#669eb3'],
 'snow': ['#2a3550','#46658a','#739fc0','#abcfdf','#dceff1','#fbffff','#8f96bd'],
 # Player kit and status sets stay visually apart from the six boss identities.
 'hero': ['#1e2a3a','#3f5a76','#7d9ab0','#c9d8e2','#f2f6f8','#e8b06a','#8a6a4a'],
 'heal': ['#1d3b34','#2f6b56','#4f9e78','#8fd6a8','#c9f0d4','#f2fff6','#6b8f7a'],
 'shield': ['#1f2c44','#38527a','#5f7fae','#93b3d6','#cfe3f2','#f4fbff','#c9a15a'],
 'buff': ['#33283c','#5f4a52','#9a7a5c','#d8ab63','#f4d79a','#fff3d2','#8a6fa0'],
 'poison': ['#241f3d','#4a3a63','#7a5f8a','#a98fb0','#d6c2c8','#f0e6ea','#6f9a5a'],
 'stun': ['#2e2a1e','#5c5230','#94823f','#c9b45c','#f2e39a','#fffbd0','#8a7ab0'],
}
NAMES = {
 'H01': ('残旗剑士','sword', [('slash','断旗斩'),('thrust','破阵穿刺'),('banner','血旗横扫'),('spin','回身剑轮')]),
 'H02': ('荆冠鹿骑','thorn', [('stomp','荆棘践踏'),('vine','地脉藤枪'),('seed','飞种围猎'),('grove','森冠禁环')]),
 'H03': ('沉潜重装','water', [('burst','高压爆破'),('jet','深潜水炮'),('mine','浮雷列阵'),('tide','逆潮冲环')]),
 'H04': ('灰翼审判者','holy', [('feather','落羽裁决'),('wing','灰翼肃清'),('spears','十字圣枪'),('verdict','天秤终审')]),
 'H05': ('霜典记录者','ice', [('seal','霜文封印'),('icicle','冰页穿心'),('script','禁典十字'),('frost','零度书环')]),
 'H06': ('锈钟守望者','bell', [('echo','震钟回响'),('hammer','铜锤撼地'),('chain','锈链贯击'),('resonance','暮钟禁域')]),
}
WEATHER_NAMES = dict(rain='润雨',clear='晴光',fog='灵雾',wind='疾风',heat='炎阳',storm='雷雨',snow='霜雪')
MINION_NAMES = dict(rain='沐雨石灵',clear='逐光木灵',fog='雾隐石灵',wind='巡风石灵',heat='熔火石灵',storm='鸣雷石灵',snow='霜甲石灵')
# Fifth boss moves reuse a shape the same boss does not already own, so dodging stays readable.
NAMES5 = {
 'H01': ('残旗剑士','sword', ('flag','血旗三插','multi',105.0,300.0,1.45,20,4.0,'离开三面旗桩')),
 'H02': ('荆冠鹿骑','thorn', ('charge','荆冠冲撞','sector',175.0,200.0,1.35,19,3.9,'绕至鹿骑身后')),
 'H03': ('沉潜重装','water', ('surge','铁壁激流','sector',180.0,205.0,1.55,22,4.3,'绕到重装侧后')),
 'H04': ('灰翼审判者','holy', ('halo','裁决光环','ring',185.0,100.0,1.75,24,4.6,'贴近或远离审判者')),
 'H05': ('霜典记录者','ice', ('spike','霜钉标记','multi',62.0,330.0,1.5,20,4.2,'离开三处霜钉')),
 'H06': ('锈钟守望者','bell', ('pendulum','钟摆十字','cross',33.0,320.0,1.6,23,4.4,'走进十字夹角')),
}
# One swing per real weapon id in equipment_catalog.gd; nothing here can be un-triggerable.
WEAPON_NAMES = [('w03','棱光横斩','sword'),('w02','裂墟劈砍','cleave'),('w05','骨枝突刺','halberd'),
                ('w01','余烬回响','echo'),('w06','坠岩余震','crag')]
STATUS_NAMES = [('heal','治疗','heal'),('shield','护盾','shield'),('buff','增益','buff'),
                ('burn','灼烧','heat'),('poison','中毒','poison'),('freeze','冰冻','ice'),('stun','麻痹','stun')]

def path(s, pts, c, thickness=1):
    for a,b in zip(pts,pts[1:]):
        for dy in range(thickness): s.line(round(a[0]),round(a[1])+dy,round(b[0]),round(b[1])+dy,c)

def arc(s,cx,cy,rx,ry,a,b,c,thickness=1):
    n=max(8,int(abs(b-a)*max(rx,ry)*0.85))
    pts=[(cx+math.cos(a+(b-a)*i/n)*rx,cy+math.sin(a+(b-a)*i/n)*ry) for i in range(n+1)]
    path(s,pts,c,thickness)

def star(s,x,y,c,r=3):
    s.line(x-r,y,x+r,y,c); s.line(x,y-r,x,y+r,c)
    if r>2: s.rect(x-1,y-1,x+1,y+1,c)

def shard(s,x,y,h,p,lean=0):
    s.polygon([(x-4,y),(x-2+lean,y-h+5),(x+lean,y-h),(x+4,y-3),(x+3,y+2)],p[1])
    s.polygon([(x-2,y-1),(x+lean,y-h+2),(x+2,y-3)],p[3])
    s.line(x+lean,y-h+4,x-1,y-3,p[5])

def ring(s,f,p,double=False):
    r=[8,13,21,29,34,37,40,42][f]
    arc(s,48,51,r,r*.62,0,math.tau,p[1],3 if f<5 else 1)
    arc(s,48,50,r,r*.62,math.pi,math.tau,p[4],2)
    if double: arc(s,48,51,max(3,r-9),max(2,r*.62-6),0,math.tau,p[2],2)
    for i in range(6):
        a=i*math.tau/6+.18*f; x=round(48+math.cos(a)*r); y=round(51+math.sin(a)*r*.62)
        if f<6: star(s,x,y,p[5],2)

def boss(s,kind,f,p):
    # The source pivot stays (48,48); bounds always retain >=2px transparent margin.
    t=[.22,.38,.64,1,.92,.80,.63,.42][f]
    if kind in ('slash','banner','spin','wing'):
        start=-2.7+f*.16; end=start+(3.9 if kind=='spin' else 2.8)
        r=12+int(t*28)
        for band,c in [(0,p[1]),(-3,p[2]),(-6,p[4]),(-7,p[5])]:
            arc(s,48,48,r+band,(r+band)*(.67 if kind!='wing' else .9),start,end,c,3 if band==0 else 2)
        if kind=='banner':
            s.polygon([(20,49),(39,26),(37,43),(65,28),(51,51),(75,49),(47,64)],p[2])
            path(s,[(23,48),(39,37),(43,49),(61,42)],p[4],2)
        if kind=='wing':
            for side in (-1,1):
                for i in range(4):
                    x=48+side*(12+i*7); y=38+i*5
                    s.polygon([(48+side*6,56),(x,20+i*7),(x+side*5,y+11)],p[2+i%2])
                    s.line(48+side*8,53,x,24+i*7,p[4])
        if kind=='spin': ring(s,f,p)
    elif kind in ('thrust','vine','jet','icicle','chain'):
        x=18+int(t*59); y=48
        if kind=='vine':
            path(s,[(8,55),(23,42),(37,53),(54,41),(x,48)],p[2],5)
            for k in range(3): s.polygon([(24+k*16,48),(31+k*16,31),(34+k*16,46)],p[3])
        elif kind=='chain':
            for k in range(9,int(x),9):
                s.ellipse(k-3,44,k+4,51,p[1],False); s.line(k-1,44,k+3,44,p[4])
        else:
            s.polygon([(7,53),(x-16,40),(x+7,48),(x-16,57)],p[1])
            s.polygon([(15,49),(x-12,44),(x+7,48),(x-13,51)],p[3])
            s.line(20,48,x+5,48,p[5])
        s.polygon([(x-11,37),(x+8,48),(x-11,59),(x-3,48)],p[4])
        if kind=='icicle':
            for k in range(3): shard(s,23+k*19,55,16+k*3,p,12)
        if kind=='jet':
            for k in range(4): arc(s,22+k*15,48,4,8,-1.5,1.5,p[4])
    elif kind in ('stomp','hammer'):
        ring(s,f,p)
        for i in range(5):
            x=22+i*13; y=59+(i%2)*7
            path(s,[(48,49),(x,y),(x-3,y+7),(x-9,y+9)],p[2],2)
            if f in range(2,6): shard(s,x,y,round((12+i%3*5)*t),p,3 if i%2 else -3)
        if kind=='hammer' and f<5:
            s.polygon([(36,18),(51,11),(63,25),(48,32)],p[1]); s.polygon([(36,18),(50,13),(57,20),(44,25)],p[4])
            s.polygon([(46,29),(51,26),(65,47),(61,51)],p[2]); star(s,51,51,p[5],8 if f==3 else 4)
    elif kind in ('burst','mine'):
        ring(s,f,p)
        if kind=='mine' and f<5:
            s.circle(48,49,12,p[1]); s.circle(46,47,9,p[2]); s.circle(44,44,4,p[3]); star(s,48,32,p[5],3)
            s.rect(44,45,51,51,p[4]); s.rect(46,47,49,49,p[5])
            for a in range(4):
                ang=a*math.pi/2; s.rect(46+math.cos(ang)*13,47+math.sin(ang)*13,49+math.cos(ang)*13,50+math.sin(ang)*13,p[2])
        else:
            for i in range(9):
                a=i*math.tau/9; x=round(48+math.cos(a)*25*t); y=round(45+math.sin(a)*24*t)
                shard(s,x,y,round((12+i%3*5)*t),p,(-1 if i%2 else 1)*5)
            s.circle(47,44,max(2,int(9*t)),p[4]); star(s,46,42,p[5],round(9*t))
    elif kind=='seed':
        # Burst seedpods differ from the upright grove wall in silhouette, not just color.
        for i in range(5):
            a=i*math.tau/5+f*.11; x=round(48+math.cos(a)*31*t); y=round(49+math.sin(a)*23*t)
            s.polygon([(x-7,y),(x-3,y-9),(x+4,y-7),(x+7,y),(x+3,y+7),(x-4,y+6)],p[1])
            s.polygon([(x-5,y-1),(x-2,y-7),(x+2,y-6),(x+1,y+4)],p[3])
            s.line(x,y-6,x-1,y+4,p[4]); s.polygon([(x,y-6),(x+5,y-13),(x+8,y-11),(x+3,y-5)],p[2])
            if f in (2,3): star(s,x+8,y+3,p[5],2)
    elif kind=='grove':
        ring(s,f,p,True)
        for i in range(5):
            a=i*math.tau/5+f*.06; x=round(48+math.cos(a)*29*t); y=round(54+math.sin(a)*19*t)
            s.polygon([(x-6,y+5),(x-3,y-10*t),(x+3,y-20*t),(x+5,y+5)],p[1])
            s.line(x,y+3,x+2,y-14*t,p[3])
            s.polygon([(x,y-7),(x-11,y-14),(x-7,y-4)],p[3]); s.line(x-8,y-12,x,y-6,p[4])
            if kind=='seed': star(s,x,y-20*t,p[5],3)
    elif kind in ('feather','verdict'):
        ring(s,f,p)
        for i in range(5):
            x=24+i*12; y=18+((f*7+i*9)%44)
            s.polygon([(x,y-8),(x+6,y-3),(x+3,y+7),(x-4,y+12),(x-3,y+1)],p[2])
            s.line(x-4,y+12,x+4,y-4,p[5]); s.line(x,y+3,x+5,y+1,p[3])
        if kind=='verdict':
            path(s,[(25,33),(48,22),(71,33)],p[4],2); s.line(48,22,48,58,p[5])
            for x in (26,70):
                s.line(x,33,x,47,p[3]); arc(s,x,47,10,5,0,math.pi,p[4],2)
    elif kind in ('spears','script'):
        r=round(36*t)
        for a in (0,math.pi/2,math.pi,math.pi*1.5):
            x=round(48+math.cos(a)*r); y=round(48+math.sin(a)*r)
            path(s,[(48,48),(x,y)],p[2],5); path(s,[(48,47),(x,y-1)],p[5],2)
            star(s,x,y,p[4],4)
            if kind=='spears':
                dx,dy=math.cos(a),math.sin(a)
                s.polygon([(x+dx*5,y+dy*5),(x-dx*8-dy*4,y-dy*8+dx*4),(x-dx*5,y-dy*5),(x-dx*8+dy*4,y-dy*8-dx*4)],p[4])
        if kind=='script':
            for i in range(4):
                x=24+i*14; y=23+(i%2)*45
                s.rect(x,y,x+7,y+9,p[1]); path(s,[(x+1,y+2),(x+6,y+2),(x+3,y+6),(x+6,y+7)],p[4])
    elif kind in ('seal','frost'):
        ring(s,f,p,True)
        for i in range(6):
            a=i*math.tau/6; x=round(48+math.cos(a)*25); y=round(49+math.sin(a)*16)
            if kind=='frost': shard(s,x,y,round(22*t),p)
            else:
                s.rect(x-3,y-7,x+3,y+2,p[1]); path(s,[(x-2,y-6),(x+2,y-6),(x-1,y-2),(x+2,y+1)],p[4])
        star(s,48,45,p[5],round(10*t))
    elif kind in ('echo','resonance','tide'):
        ring(s,f,p,True)
        if kind=='tide':
            for i in range(3): arc(s,48,48,12+9*i,7+6*i,-2.8+f*.2,.4+f*.2,p[4],2)
        else:
            for i in range(3):
                x=28+i*20; y=32+(i%2)*10
                s.polygon([(x-5,y+6),(x-4,y-5),(x,y-10),(x+5,y-5),(x+6,y+6)],p[2])
                s.line(x-4,y+6,x+6,y+6,p[4]); s.rect(x-1,y+7,x+1,y+9,p[5])
            if kind=='resonance':
                for i in range(6):
                    a=i*math.tau/6; star(s,round(48+36*math.cos(a)),round(50+23*math.sin(a)),p[4],3)
    else: raise ValueError(kind)
    if f in (2,3) and kind not in ('spin','grove','tide','frost','resonance'):
        star(s,45,43,p[5],4)

def minion(s,kind,f,p):
    # Compact elemental attacks: distinct water / leaves / curse / gust / fire / bolt / ice.
    t=[.3,.5,.8,1,.8,.6,.4,.2][f]; x=48; y=52
    if kind in ('rain','heat','snow'):
        for i in range(5):
            dx=(i-2)*8; h=round((20-abs(i-2)*3)*t)
            if kind=='rain':
                path(s,[(x+dx,y+6),(x+dx-4,y-h),(x+dx-7,y-h-2)],p[2],3)
                s.ellipse(x+dx-9,y-h-7,x+dx-4,y-h-2,p[4])
            elif kind=='heat':
                s.polygon([(x+dx-6,y+7),(x+dx-5,y-3),(x+dx+2,y-h-8),(x+dx+6,y-2),(x+dx+4,y+6)],p[2])
                s.polygon([(x+dx-2,y+5),(x+dx+1,y-h+1),(x+dx+3,y+5)],p[4])
            else: shard(s,x+dx,y+4,h+6,p,3)
        arc(s,48,60,25*t,9*t,0,math.tau,p[3],2)
    elif kind in ('wind','fog'):
        for i in range(3):
            arc(s,48,44+i*8,15+8*t-i*2,5+i,-2.8+f*.3,1.7+f*.3,p[2+i],2)
        if kind=='fog':
            s.circle(48,47,7,p[1]); s.rect(44,44,46,46,p[5]); s.rect(50,44,52,46,p[5])
            s.line(46,51,50,51,p[4])
    elif kind=='storm':
        pts=[(37,23),(51,35),(44,44),(58,53),(50,62),(59,72)]
        path(s,pts,p[1],5); path(s,pts,p[3],3); path(s,pts,p[5])
        star(s,50,53,p[4],round(10*t)); arc(s,50,63,20*t,7*t,0,math.tau,p[3],2)
    else:
        for i in range(5):
            a=i*math.tau/5+f*.25; x=round(48+math.cos(a)*25*t); y=round(48+math.sin(a)*19*t)
            s.polygon([(x-7,y),(x+2,y-5),(x+8,y-3),(x+1,y+5)],p[2]); s.line(x-5,y,x+5,y-2,p[4])

def weather(s,kind,f,p):
    # Small reusable particles occupy a 96px cell, with no baked backdrop.
    if kind=='rain':
        for i in range(3):
            x=28+i*17; y=21+(f*43/8+i*13)%43
            path(s,[(x+5,y-10),(x,y+3)],p[2+i%2],2); s.line(x+3,y-6,x,y+2,p[4])
        if f>3: arc(s,48,75,6+(f-4)*5,2+(f-4)*2,0,math.tau,p[3])
    elif kind=='snow':
        x=48+round(math.sin(f*math.tau/8)*3); y=46
        for a in range(6):
            angle=a*math.tau/6; dx=math.cos(angle); dy=math.sin(angle)
            s.line(x,y,x+dx*13,y+dy*13,p[3]);
            for side in (-1,1): s.line(x+dx*8,y+dy*8,x+dx*7-dy*side*4,y+dy*7+dx*side*4,p[4])
        star(s,x,y,p[5],2)
    elif kind=='wind':
        for i in range(3):
            sway=math.sin(f*math.tau/8)*.3
            arc(s,42+i*5,41+i*8,21,5,-2.7+sway,1+sway,p[2+i],1)
        x=48+round(math.sin(f*math.tau/8)*9); s.polygon([(x-4,63),(x+4,58),(x+8,59),(x,65)],p[3])
    elif kind=='fog':
        for i in range(4):
            x=21+i*15+round(math.sin(f*math.tau/8+i)*3); y=43+(i%2)*8
            s.ellipse(x-12,y-5,x+16,y+5,p[1+i%2])
            s.rect(x-5,y-5,x+13,y-3,p[3])
    elif kind=='heat':
        for i in range(3):
            x=33+i*16; y=61-(f*35/8+i*13)%35
            s.polygon([(x-3,y+4),(x-3,y),(x+1,y-6),(x+3,y),(x+2,y+4)],p[2]); s.rect(x,y,x+1,y+2,p[4])
    elif kind=='storm':
        if f in (2,3,4):
            pts=[(53,14),(42,35),(52,35),(39,57),(49,54),(42,77)]
            path(s,pts,p[2],5); path(s,pts,p[4],3); path(s,pts,p[5])
        else:
            path(s,[(39,32+f*3),(35,43+f*3)],p[2],2); path(s,[(62,28+f*2),(58,39+f*2)],p[3],2)
    else:
        star(s,48,47,p[4] if f in (2,3,4) else p[3],3+min(f,7-f))
        s.rect(29,62,31,64,p[2]); s.rect(65,29,67,31,p[3])

def boss5(s,kind,f,p):
    # Fifth moves: a silhouette the same boss does not already own, so dodging stays readable.
    t=[.22,.38,.64,1,.92,.80,.63,.42][f]
    if kind=='flag':
        ring(s,f,p)
        for i in range(3):
            x=26+i*22; y=52-(6 if i==1 else 0); h=round((26+(8 if i==1 else 0))*t)
            path(s,[(x,y+8),(x,y-h)],p[1],3)
            s.polygon([(x+1,y-h),(x+10,y-h+5),(x+8,y-h+13),(x+1,y-h+9)],p[2])
            s.line(x+2,y-h+2,x+8,y-h+8,p[4])
            if f in (2,3): star(s,x+6,y-h+7,p[5],2)
    elif kind=='charge':
        start=-2.5+f*.15; end=start+2.9; r=14+int(t*26)
        for band,c in [(0,p[1]),(-3,p[2]),(-6,p[4])]:
            arc(s,48,48,r+band,(r+band)*.7,start,end,c,3 if band==0 else 2)
        for i in range(5):
            a=start+.35+i*.55; x=round(48+math.cos(a)*(r-2)); y=round(48+math.sin(a)*(r-2)*.7)
            s.polygon([(x-4,y),(x-1,y-9),(x+3,y-7),(x+4,y+2)],p[3]); s.line(x-2,y,x+1,y-6,p[5])
    elif kind=='surge':
        start=-2.6+f*.14; end=start+3.0; r=16+int(t*26)
        for band,c in [(0,p[1]),(-4,p[2]),(-7,p[3]),(-9,p[4])]:
            arc(s,48,50,r+band,(r+band)*.72,start,end,c,4 if band==0 else 2)
        for i in range(6):
            a=start+.3+i*.5; x=round(48+math.cos(a)*(30*t)); y=round(48+math.sin(a)*(22*t))
            s.polygon([(x-3,y+4),(x,y-7),(x+3,y+3)],p[3]); s.line(x-2,y,x+2,y-3,p[5])
    elif kind=='halo':
        ring(s,f,p,True)
        for i in range(4):
            x=26+i*15; h=round(30*t)
            path(s,[(x,58),(x,58-h)],p[4],3); path(s,[(x,58),(x,58-h)],p[5],1); star(s,x,58-h,p[5],2)
        star(s,48,44,p[5],round(9*t))
    elif kind=='spike':
        ring(s,f,p)
        for i in range(3):
            x=28+i*20; shard(s,x,56,round(30*t),p,6 if i!=1 else -6)
            s.circle(x-1,58,max(2,round(7*t)),p[3])
    elif kind=='pendulum':
        r=round(34*t)
        for a in (0,math.pi/2,math.pi,math.pi*1.5):
            x=round(48+math.cos(a)*r); y=round(48+math.sin(a)*r)
            path(s,[(48,48),(x,y)],p[2],4); path(s,[(48,47),(x,y-1)],p[4],2)
            s.circle(x,y,4,p[1]); s.circle(x-1,y-1,2,p[3])
        s.circle(48,48,5,p[1]); s.circle(47,47,3,p[4]); star(s,48,48,p[5],round(6*t))
    else: raise ValueError(kind)
    if f in (2,3): star(s,45,43,p[5],4)

def weapon(s,kind,f,p):
    # Player hits read lighter and tighter than boss casts: thinner bands, brighter steel.
    t=[.25,.45,.7,1,.85,.65,.45,.3][f]
    ph=math.tau*f/8
    if kind=='sword':
        start=-2.4+f*.18; end=start+2.4; r=13+int(t*22)
        for band,c in [(0,p[2]),(-3,p[3]),(-5,p[4]),(-6,p[5])]:
            arc(s,48,48,r+band,(r+band)*.72,start,end,c,3 if band==0 else 2)
        for band,c in [(-9,p[3]),(-13,p[2])]:
            arc(s,48,48,r+band,(r+band)*.72,start-.35,end-.5,c,2)
        if f in (2,3): star(s,round(48+math.cos(end)*(r+2)),round(48+math.sin(end)*(r+2)*.72),p[5],3)
    elif kind=='echo':
        # Delayed aftershock: rings lagging behind each other, embers drifting off the hit.
        for k in range(4):
            tt=max(0.0,math.sin(ph-k*.55)); r=6+round(32*tt)
            if r>8:
                arc(s,48,48,r,round(r*.72),0,math.tau,[p[5],p[4],p[3],p[2]][k],[6,4,2,1][k])
        for i in range(2):
            rr=6+round(34*max(0.0,math.sin(ph-1.95)))
            if rr>10: arc(s,48,48,rr,round(rr*.72),ph*.5+i*math.pi,ph*.5+i*math.pi+1.5,p[2],1)
        for i in range(6):
            a=ph*.7+i*math.tau/6; rr=16+10*math.sin(ph+i)
            star(s,round(48+math.cos(a)*rr),round(48+math.sin(a)*rr*.72),p[5],3)
        s.circle(48,48,max(3,round(7*t)),p[5],fill=True); s.circle(48,48,max(2,round(4*t)),p[4],fill=True)
    elif kind=='cleave':
        start=-2.3+f*.16; end=start+2.2; r=12+int(t*20)
        for band,c in [(0,p[5]),(-3,p[4]),(-6,p[6])]:
            arc(s,48,50,r+band,(r+band)*.75,start,end,c,4 if band==0 else 2)
        for i in range(6):
            a=start+.25+i*.36; x=round(48+math.cos(a)*(r+8)); y=round(50+math.sin(a)*(r+8)*.75)
            s.polygon([(x-3,y),(x+2,y-4),(x+4,y+1),(x-1,y+4)],p[3]); s.line(x-2,y+1,x+2,y-2,p[5])
    elif kind=='halberd':
        x=16+int(t*60)
        s.polygon([(5,52),(x-14,44),(x+8,52),(x-14,60)],p[2])
        s.polygon([(13,49),(x-10,47),(x+6,52),(x-11,56)],p[4]); s.line(18,52,x+6,52,p[5])
        s.polygon([(x-9,43),(x+7,52),(x-9,61),(x-2,52)],p[3])
        # Bone shaft: knobs and joints, then forked twigs. A plain thrust never read as 骨枝.
        for k in range(3):
            bx=14+k*max(4,(x-22)//3)
            s.ellipse(bx-4,45,bx+4,59,p[6]); s.ellipse(bx-2,47,bx+2,57,p[4]); s.line(bx,45,bx,59,p[2])
        for side in (-1,1):
            s.polygon([(x-6,52),(x-16,52+side*13),(x-9,52+side*15)],p[5])
            s.line(x-4,52,x-14,52+side*10,p[4])
        for k in range(3): arc(s,20+k*12,52,4,7,-1.5,1.5,p[3])
    elif kind=='crag':
        # Falling mass first, ground shock after; rings only once it lands.
        cy=26+round(30*t)
        s.polygon([(44,4),(52,4),(54,cy-14),(42,cy-14)],p[2])
        for k in range(2): s.line(37+k*22,8,37+k*22,cy-16,p[3])
        for i in range(3):
            dy=(f*11+i*23)%40
            s.polygon([(40+i*11,8+dy),(47+i*11,12+dy),(44+i*11,19+dy),(37+i*11,14+dy)],p[3])
        s.polygon([(48,cy-18),(66,cy-4),(61,cy+13),(35,cy+13),(30,cy-4)],p[2])
        s.polygon([(48,cy-13),(59,cy-3),(56,cy+9),(40,cy+9),(37,cy-3)],p[3])
        s.polygon([(46,cy-8),(53,cy-2),(51,cy+5),(43,cy+5)],p[4])
        if t>=.6:
            for k in range(3):
                rr=12+k*10+round(10*t)
                arc(s,48,74,rr,max(3,round(rr*.30)),0,math.tau,[p[5],p[6],p[4]][k],4 if k==0 else 2)
        for i in range(5):
            a=math.tau*i/5+ph
            star(s,round(48+math.cos(a)*32),round(74+math.sin(a)*9),p[5],2)
    else: raise ValueError(kind)

def status(s,kind,f,p):
    # Looping auras: frame 7 must flow back into frame 0, so everything is driven by a phase.
    ph=math.tau*f/8; t=.55+.45*math.sin(ph)
    if kind=='heal':
        # One big pulsing cross; four drifting motes on their own read as noise, not healing.
        a=22+int(6*t); w=7
        s.rect(48-w,48-a,48+w,48+a,p[2]); s.rect(48-a,48-w,48+a,48+w,p[2])
        s.rect(48-w+2,48-a+2,48+w-2,48+a-2,p[3]); s.rect(48-a+2,48-w+2,48+a-2,48+w-2,p[3])
        s.rect(48-w+4,48-a+4,48+w-4,48+a-4,p[4]); s.rect(48-a+4,48-w+4,48+a-4,48+w-4,p[4])
        s.rect(48-2,48-a+6,48+2,48+a-6,p[5]); s.rect(48-a+6,48-2,48+a-6,48+2,p[5])
        for i in range(4):
            ang=ph+i*math.tau/4
            star(s,round(48+math.cos(ang)*(a+8)),round(48+math.sin(ang)*(a+8)),p[4],2)
    elif kind=='shield':
        # Heraldic shield silhouette; a bare ring never read as "shield".
        w=22+int(4*t); top=24; bot=76
        s.polygon([(48-w,top),(48+w,top),(48+w,47),(48,bot),(48-w,47)],p[2])
        s.polygon([(48-w+4,top+4),(48+w-4,top+4),(48+w-4,46),(48,bot-7),(48-w+4,46)],p[3])
        s.polygon([(48-w+8,top+8),(48+w-8,top+8),(48+w-8,45),(48,bot-14),(48-w+8,45)],p[4])
        s.rect(48-2,31,48+2,57,p[6]); s.rect(48-10,42,48+10,46,p[6])
        for i in range(4):
            a=ph+i*math.tau/4
            star(s,round(48+math.cos(a)*(w+8)),round(50+math.sin(a)*(w+8)),p[5],2)
    elif kind=='buff':
        # Three fat rising chevrons; the old narrow arrows were too small to carry the frame.
        for i in range(3):
            y=64-((f*10+i*27)%48)
            s.polygon([(48,y-11),(67,y+5),(48,y+1),(29,y+5)],p[3])
            s.polygon([(48,y-6),(60,y+3),(48,y),(36,y+3)],p[4])
        arc(s,48,70,24,8,0,math.tau,p[2],2)
    elif kind=='burn':
        # Three wide flame tongues; the old narrow ones left the frame half empty.
        for i in range(3):
            x=26+i*22; h=26+((f+i*3)%4)*6
            s.polygon([(x-8,66),(x-6,66-h*.45),(x-1,66-h),(x+5,66-h*.5),(x+8,66)],p[2])
            s.polygon([(x-4,66),(x-3,66-h*.5),(x+1,66-h*.72),(x+4,66)],p[3])
            s.polygon([(x-2,66),(x-1,66-h*.4),(x+1,66-h*.5),(x+2,66)],p[4])
        arc(s,48,70,30,8,math.pi,math.tau,p[3],2)
    elif kind=='poison':
        # A solid bubbling pool reads as poison; scattered dots did not.
        s.ellipse(26,54,70,76,p[1]); s.ellipse(30,57,66,72,p[2]); s.ellipse(36,60,60,68,p[3])
        s.line(32,60,64,60,p[4])
        for i in range(4):
            x=32+i*11; y=58-((f*9+i*17)%40); r=7-((i+f)%2)*2
            s.circle(x,y,r,p[2],fill=True); s.circle(x-2,y-2,max(3,r-3),p[4],fill=True)
            s.line(x-r,y+r-1,x+r,y+r-1,p[1])
        for i in range(3):
            a=ph*.5+i*math.tau/3; ex=round(48+math.cos(a)*16); ey=round(64+math.sin(a)*6)
            s.ellipse(ex-11,ey-5,ex+11,ey+5,p[1])
    elif kind=='freeze':
        # A big frozen hex-crystal; small symmetric snowflakes collided with weather-snow.
        r=24+int(5*t)
        s.polygon([(round(48+math.cos(i*math.tau/6)*r),round(48+math.sin(i*math.tau/6)*r)) for i in range(6)],p[3])
        s.polygon([(round(48+math.cos(i*math.tau/6)*(r-5)),round(48+math.sin(i*math.tau/6)*(r-5))) for i in range(6)],p[4])
        for i in range(6):
            a=i*math.tau/6; dx=math.cos(a); dy=math.sin(a)
            s.line(48,48,round(48+dx*(r+6)),round(48+dy*(r+6)),p[2])
            s.line(48,48,round(48+dx*(r+5)),round(48+dy*(r+5)),p[4])
            s.line(round(48+dx*r),round(48+dy*r),round(48+dx*(r-7)-dy*6),round(48+dy*(r-7)+dx*6),p[5])
            s.line(round(48+dx*r),round(48+dy*r),round(48+dx*(r-7)+dy*6),round(48+dy*(r-7)-dx*6),p[5])
        star(s,48,48,p[5],3)
    elif kind=='stun':
        # One dominant bolt down the middle; three small ones scattered too thin to read.
        sx=48+round(math.sin(ph)*3)
        pts=[(sx+4,20),(sx-8,44),(sx+2,44),(sx-10,72)]
        path(s,pts,p[3],5); path(s,pts,p[4],3); path(s,pts,p[5],1)
        arc(s,48,48,30,19,0,math.tau,p[2],4); arc(s,48,48,30,19,0,math.tau,p[3],2)
        for i in range(3):
            a=ph+i*math.tau/3; star(s,round(48+math.cos(a)*28),round(48+math.sin(a)*17),p[4],2)
    else: raise ValueError(kind)

LOOPING = ('weather','status')

def make(key,label,palette,draw,kind,category):
    s=Sprite(96,96,palette=palette)
    looping = category in LOOPING
    for f in range(8):
        if f: s.add_frame(copy=False)
        draw(s,kind,f,palette)
        s.set_duration(([120]*8 if looping else [90,70,50,100,80,80,100,130])[f])
    s.tag('loop' if looping else 'cast',1,8)
    s.save_spritesheet(str(ROOT/f'{key}.png'),layout='horizontal')
    s.save_spritesheet(str(DEST/f'{key}.png'),layout='horizontal')
    s.save_png(str(ROOT/f'{key}-master.png'),frame=4)
    s.save_png(str(ROOT/f'{key}-4x.png'),frame=4,scale=4)
    s.save_gif(str(ROOT/f'{key}.gif'),scale=4,bg='#172332')
    # Check actual full frame union, binary alpha and palette on every export.
    frames=[s.composite(i+1) for i in range(8)]
    used=set()
    for im in frames:
        bb=im.getbbox()
        assert bb and bb[0]>=2 and bb[1]>=2 and bb[2]<=94 and bb[3]<=94,(key,bb)
        used.update(c for c in im.get_flattened_data() if c[3])
        assert set(im.getchannel('A').get_flattened_data()) <= {0,255},key
    assert len(used)<=7,(key,len(used))
    stats=s.stats(print_=False)
    assert stats['semi_alpha_px']==0 and not stats['near_duplicate_colors'],(key,stats)
    return dict(key=key,label=label,category=category,frame_size=[96,96],pivot=[48,48],frames=8,
                durations=[fr.duration for fr in s.frames],palette=palette,colors_used=len(used),
                semi_alpha_px=stats['semi_alpha_px'],near_duplicate_colors=stats['near_duplicate_colors'],
                isolated_px_last_frame=stats['isolated_px']),frames

def plate(entries,filename,cols=4):
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',12)
    w=cols*246; h=58+math.ceil(len(entries)/cols)*248
    im=Image.new('RGB',(w,h),'#101b28'); d=ImageDraw.Draw(im)
    d.text((19,16),'福地 · 像素攻击与天气特效',font=font,fill='#f4dfb5')
    for i,(meta,frames) in enumerate(entries):
        x=(i%cols)*246+12; y=58+(i//cols)*248
        d.rounded_rectangle((x,y,x+230,y+236),8,fill='#1a2b3b',outline='#3b5265')
        d.text((x+12,y+9),meta['label'],font=font,fill='#ecdab5')
        im.paste(frames[3].resize((192,192),Image.Resampling.NEAREST),(x+19,y+32),frames[3].resize((192,192),Image.Resampling.NEAREST))
        d.text((x+12,y+217),meta['key'],font=small,fill='#8eacba')
    im.save(ROOT/filename)

def main():
    entries=[]
    for bid,(name,pal,kinds) in NAMES.items():
        for kind,label in kinds: entries.append(make(f'{bid}-{kind}',label,PALETTES[pal],boss,kind,'boss'))
    for bid,(name,pal,spec) in NAMES5.items():
        kind=spec[0]; entries.append(make(f'{bid}-{kind}',spec[1],PALETTES[pal],boss5,kind,'boss'))
    for wid,label,kind in WEAPON_NAMES: entries.append(make(f'player-{wid}',label,PALETTES['hero'],weapon,kind,'player'))
    for kind,label in MINION_NAMES.items(): entries.append(make(f'guard-{kind}',label,PALETTES[kind],minion,kind,'guard'))
    for kind,label,pal in STATUS_NAMES: entries.append(make(f'status-{kind}',label,PALETTES[pal],status,kind,'status'))
    for kind,label in WEATHER_NAMES.items(): entries.append(make(f'weather-{kind}',label,PALETTES[kind],weather,kind,'weather'))
    manifest={'version':1,'pixel_size':1,'filter':'nearest','frame_count':8,'frame_size':[96,96],
              'effects':[meta for meta,frames in entries]}
    for dest in (ROOT,DEST): (dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    plate(entries[:30],'boss-preview.png')
    plate(entries[30:35],'player-preview.png',cols=5)
    plate(entries[35:],'elements-preview.png',cols=4)
    motion=Image.new('RGB',(8*192,3*192),'#172332')
    for row,index in enumerate((0,30,35)):
        for f,im in enumerate(entries[index][1]):
            im=im.resize((192,192),Image.Resampling.NEAREST)
            motion.paste(im,(f*192,row*192),im)
    motion.save(ROOT/'motion-preview.png')
    # Combined animation is a preview, individual sheets are the runtime masters.
    for label,group,cols in [('boss',entries[:30],6),('player',entries[30:35],5),('elements',entries[35:],7)]:
        animation=[]
        for f in range(8):
            im=Image.new('RGBA',(cols*96,math.ceil(len(group)/cols)*96),'#172332')
            for i,(_,frames) in enumerate(group): im.alpha_composite(frames[f],((i%cols)*96,(i//cols)*96))
            animation.append(im.convert('RGB').resize((im.width*2,im.height*2),Image.Resampling.NEAREST))
        animation[0].save(ROOT/f'{label}-animation.gif',save_all=True,append_images=animation[1:],duration=[90,70,50,100,80,80,100,500],loop=0)
    print(f'Built {len(entries)} effects / {len(entries)*8} native frames; palette, margins and alpha verified.')

if __name__=='__main__': main()
