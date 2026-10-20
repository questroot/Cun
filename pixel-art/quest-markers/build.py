from pathlib import Path
import sys,json
from PIL import Image,ImageDraw,ImageFont
import os
sys.path.insert(0, str(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills/pixel-art-studio/scripts'))
from pixelstudio import Sprite
ROOT=Path(__file__).resolve().parent
DEST=ROOT.parents[1]/'card-demo/assets/ui/quest-markers'
DEST.mkdir(parents=True,exist_ok=True)
COLORS={'red':['#292438','#9e354e','#ef6b69','#ffd0ad'],
        'yellow':['#292438','#a76a36','#f4c65d','#fff1bf'],
        'blue':['#292438','#365789','#6cbaee','#d3f4ff']}
sheet=Image.new('RGBA',(16*6,20))
for i,(tone,palette) in enumerate(COLORS.items()):
  for j,kind in enumerate(('exclamation','question')):
    s=Sprite(16,20,palette=palette)
    if kind=='exclamation':
      s.polygon([(6,2),(9,2),(10,3),(10,7),(9,12),(6,12),(5,7),(5,3)],palette[1])
      s.rect(6,3,8,8,palette[2]); s.rect(6,3,6,5,palette[3]); s.rect(7,8,8,11,palette[2])
    else:
      s.polygon([(5,2),(9,2),(12,5),(12,8),(9,11),(9,12),(6,12),(6,9),(9,6),(8,5),(6,5),(4,7),(2,5)],palette[1])
      s.polygon([(5,3),(9,3),(11,5),(11,7),(8,10),(8,11),(7,11),(7,9),(10,6),(8,4),(5,4),(4,6),(3,5)],palette[2])
      s.rect(5,3,8,3,palette[3])
    s.rect(6,15,9,17,palette[1]); s.rect(6,15,8,16,palette[2]); s.rect(6,15,7,15,palette[3])
    s.outline(palette[0],where='outside')
    filename=f'{tone}-{kind}.png'
    s.save_png(str(ROOT/filename)); s.save_png(str(DEST/filename))
    s.save_png(str(ROOT/f'{tone}-{kind}-8x.png'),scale=8)
    im=Image.open(ROOT/filename).convert('RGBA'); sheet.paste(im,((i*2+j)*16,0))
    print(filename,s.stats(print_=False))
sheet.resize((768,160),Image.Resampling.NEAREST).save(ROOT/'markers-preview.png')
