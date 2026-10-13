"""Build coordinate-aligned 2.5D city sprites and editable glTF meshes from the city concept palette."""
import json
import math
import struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'outputs' / 'Create_one_original_2D_fantasy_2026-10-03T14-18-23.png'
ART = ROOT / 'assets' / 'backgrounds'
MODELS = ROOT / 'assets' / 'models'
MODELS.mkdir(exist_ok=True)
concept = Image.open(SOURCE).convert('RGB')
# The concept informs texture/palette, not topology or walkability.
samples = [concept.getpixel(p) for p in ((480, 370), (780, 250), (950, 530))]

def tint(color, scale):
    return tuple(max(0, min(255, int(v * scale))) for v in color)

def mix(a, b, ratio):
    return tuple(int(a[i] * (1 - ratio) + b[i] * ratio) for i in range(3))

# Existing map rectangles and IDs: changing their positions would break navigation.
BUILDINGS = [
    ('west_hall', 104, 363, 220, 111, (51, 94, 85)),
    ('market', 403, 367, 153, 76, (105, 93, 69)),
    ('east_hall', 962, 361, 216, 115, (58, 96, 93)),
    ('library', 1310, 365, 245, 116, (45, 83, 87)),
    ('observatory', 1710, 370, 190, 117, (66, 97, 102)),
]

# World-space terrain; softly blurred sky comes from the original concept image itself.
world = Image.new('RGB', (2080, 900), '#a4c7ad')
sky = concept.crop((0, 0, 1536, 420)).resize((2080, 380), Image.Resampling.LANCZOS)
sky = sky.filter(ImageFilter.GaussianBlur(25))
world.paste(Image.blend(sky, Image.new('RGB', sky.size, '#b0cdbc'), 0.53), (0, 0))
d = ImageDraw.Draw(world, 'RGBA')
d.polygon([(0, 363), (135, 286), (274, 342), (430, 277), (610, 352), (850, 269), (1050, 353), (1250, 260), (1440, 348), (1660, 270), (1880, 350), (2080, 285), (2080, 520), (0, 520)], fill=(83, 134, 111, 230))
d.rectangle((0, 343, 2080, 900), fill=(102, 140, 110, 205))
d.rectangle((64, 354, 2016, 784), fill=(153, 179, 135, 255))
d.rectangle((78, 480, 1978, 534), fill=(216, 196, 151, 255))
d.rectangle((274, 518, 1939, 768), fill=(201, 183, 143, 255))
for x, y, w, h in ((739, 526, 209, 206), (1554, 536, 187, 188)):
    d.rectangle((x, y, x+w, y+h), fill=(228, 209, 164, 255), outline=(119, 128, 106, 180), width=4)
    d.ellipse((x+w/2-24, y+h/2-24, x+w/2+24, y+h/2+24), outline=(108, 133, 111, 160), width=3)
for y in range(545, 767, 34):
    for x in range(285+(19 if y//34%2 else 0), 1930, 55):
        d.line((x, y, x+29, y), fill=(127, 112, 87, 92), width=2)
for x in range(50, 2050, 54):
    y = 821 + int(9*math.sin(x*.04))
    d.ellipse((x-15,y-9,x+18,y+12), fill=(53, 114, 74, 195))
    d.ellipse((x+2,y-15,x+19,y), fill=(88, 157, 100, 210))
world.save(ART / 'city_concept_terrain.png')


def building_sprite(name, width, depth, roof):
    # Projection is orthographic 2.5D; contact shadow stays inside the obstacle footprint.
    height = 116 if name != 'market' else 88
    canvas_h = depth + height + 74
    im = Image.new('RGBA', (width+46, canvas_h), (0,0,0,0))
    p = ImageDraw.Draw(im, 'RGBA')
    left, right = 23, width+23
    base = canvas_h-15
    top = base-depth
    wall_top = top-height+35
    p.ellipse((left+10, base-depth*.48, right+18, base+6), fill=(23,49,46,75))
    p.polygon([(left,wall_top),(right,wall_top),(right,base),(left,base)], fill=(228,210,166,255))
    p.polygon([(right-25,wall_top-15),(right+12,wall_top+3),(right+12,base-20),(right,base)], fill=(142,142,112,255))
    p.polygon([(left-14,wall_top+10),(left+width*.5,wall_top-48),(right+14,wall_top+10),(right-2,wall_top+24),(left,wall_top+24)], fill=(*roof,255))
    p.line([(left-14,wall_top+10),(left+width*.5,wall_top-48),(right+14,wall_top+10)], fill=(31,61,59,255), width=4)
    for i in range(1,8):
        px=left+width*i/8
        py=wall_top+12-48*(1-abs(px-(left+width*.5))/(width*.5))
        p.line((px,py,px+16,wall_top+20), fill=(171,173,125,130), width=2)
    p.line((left,wall_top+27,right,wall_top+27),fill=(113,114,89,230),width=5)
    p.line((left+5,base-17,right,base-17),fill=(123,116,82,225),width=5)
    for wx in (left+32,right-57):
        p.rectangle((wx,wall_top+39,wx+29,wall_top+74),fill=(43,93,92,255),outline=(110,86,59,255),width=3)
        p.polygon([(wx+3,wall_top+42),(wx+25,wall_top+42),(wx+23,wall_top+62)],fill=(164,208,185,230))
    door_x=left+width*.5
    p.rectangle((door_x-17,base-60,door_x+18,base-15),fill=(76,72,53,255),outline=(136,97,65,255),width=3)
    p.ellipse((door_x+8,base-38,door_x+13,base-33),fill=(235,194,109,255))
    for px in (left+11,right-13):
        p.line((px,wall_top+27,px,base-16),fill=(144,118,84,255),width=7)
    if name == 'observatory':
        cx = left+width*.5
        p.ellipse((cx-24,wall_top-66,cx+24,wall_top-23),fill=(94,150,140,255),outline=(46,82,83,255),width=4)
    im.save(ART / ('city_' + name + '.png'))
    return canvas_h


def mesh_glb(name, w, depth, roof_rgb):
    # Real geometry: wall box, thick pitched roof and door; positions are local metres.
    verts=[]; normals=[]; colors=[]; indices=[]
    def quad(a,b,c,d,color):
        start=len(verts)
        u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
        n=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]); l=math.sqrt(sum(q*q for q in n)) or 1
        for xyz in (a,b,c,d):
            verts.append(xyz); normals.append(tuple(q/l for q in n)); colors.append((*[q/255 for q in color],1.0))
        indices.extend((start,start+1,start+2,start,start+2,start+3))
    def box(x1,y1,z1,x2,y2,z2,col):
        quad((x1,y1,z1),(x2,y1,z1),(x2,y2,z1),(x1,y2,z1),col)
        quad((x2,y1,z2),(x1,y1,z2),(x1,y2,z2),(x2,y2,z2),col)
        quad((x1,y1,z2),(x1,y1,z1),(x1,y2,z1),(x1,y2,z2),col)
        quad((x2,y1,z1),(x2,y1,z2),(x2,y2,z2),(x2,y2,z1),col)
        quad((x1,y2,z1),(x2,y2,z1),(x2,y2,z2),(x1,y2,z2),col)
        quad((x1,y1,z2),(x2,y1,z2),(x2,y1,z1),(x1,y1,z1),col)
    width=w/42; dep=depth/42
    box(-width/2,0,-dep/2,width/2,2.35,dep/2,(228,210,166))
    # Two genuine sloped roof surfaces and gables.
    a=(-width/2-.18,2.35,-dep/2-.2); b=(width/2+.18,2.35,-dep/2-.2)
    c=(-width/2-.18,2.35,dep/2+.2); dd=(width/2+.18,2.35,dep/2+.2)
    e=(0,3.25,-dep/2-.2); f=(0,3.25,dep/2+.2)
    quad(a,e,f,c,roof_rgb); quad(e,b,dd,f,tint(roof_rgb,.77))
    quad(a,b,e,e,roof_rgb); quad(c,f,dd,dd,roof_rgb)
    box(-.34,.04,-dep/2-.03,.34,1.4,-dep/2+.02,(82,66,48))
    for xpos in (-width*.31,width*.31):
        box(xpos-.21,1.05,-dep/2-.05,xpos+.21,1.7,-dep/2+.02,(100,171,163))
    # One buffer, tightly packed attributes; GLB imports directly into Godot.
    chunks=[]; views=[]
    for data,fmt,component in ((verts,'<3f',5126),(normals,'<3f',5126),(colors,'<4f',5126),(indices,'<I',5125)):
        raw=b''.join(struct.pack(fmt,*v) if isinstance(v,tuple) else struct.pack(fmt,v) for v in data)
        off=sum(len(c) for c in chunks); chunks.append(raw+b'\x00'*((-len(raw))%4))
        views.append({'buffer':0,'byteOffset':off,'byteLength':len(raw),'target':34963 if component==5125 else 34962})
    def acc(i,count,typ,component,extras=None):
        value={'bufferView':i,'componentType':component,'count':count,'type':typ}
        if extras: value.update(extras)
        return value
    mins=[min(v[k] for v in verts) for k in range(3)]
    maxs=[max(v[k] for v in verts) for k in range(3)]
    doc={'asset':{'version':'2.0','generator':'City concept aligned model builder'},'scene':0,'scenes':[{'nodes':[0]}], 'nodes':[{'name':name,'mesh':0}], 'meshes':[{'name':name,'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'COLOR_0':2},'indices':3,'material':0}]}], 'materials':[{'name':'matte_city','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.93},'doubleSided':True}], 'buffers':[{'byteLength':sum(map(len,chunks))}], 'bufferViews':views, 'accessors':[acc(0,len(verts),'VEC3',5126,{'min':mins,'max':maxs}),acc(1,len(normals),'VEC3',5126),acc(2,len(colors),'VEC4',5126),acc(3,len(indices),'SCALAR',5125)]}
    js=json.dumps(doc,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
    binary=b''.join(chunks)
    glb=struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(binary))+struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(binary),b'BIN\x00')+binary
    (MODELS / ('city_'+name+'.glb')).write_bytes(glb)

for name,x,y,w,dep,roof in BUILDINGS:
    building_sprite(name,w,dep,roof)
    mesh_glb(name,w,dep,roof)
print('Created 1 terrain PNG, 5 building PNGs and 5 GLB models; collisions unchanged.')
