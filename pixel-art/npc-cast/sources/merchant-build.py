from pathlib import Path
import sys
import os
sys.path.insert(0, str(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'skills/pixel-art-studio/scripts'))
from pixelstudio import Sprite

OUT = Path(__file__).resolve().parent
# 48 x 64, twelve colors, upper-left light, plum colored outlines.
C = dict(ink='#292438', brown='#624052', leather='#a6654a', gold='#daa45e',
         skin='#e7a477', light='#ffdab0', tealDark='#24525e', teal='#387d80',
         tealLight='#72b4a1', cream='#f5e7c5', gray='#a6a7ae', red='#bb5254')
s = Sprite(48, 64, palette=list(C.values()))
def poly(points, c): s.polygon(points, C[c])
def rect(a,b,c,d,col): s.rect(a,b,c,d,C[col])
def line(a,b,c,d,col): s.line(a,b,c,d,C[col])

# Asymmetric silhouette: cap, extended offering hand, shoulder bag, two boots.
poly([(16,5),(27,5),(31,8),(32,14),(34,17),(32,22),(29,25),
 (33,27),(36,32),(38,34),(41,34),(43,37),(42,41),(37,42),
 (34,39),(34,49),(31,52),(31,57),(33,58),(33,61),(24,61),
 (23,58),(22,53),(20,53),(19,58),(19,61),(9,61),(9,58),
 (12,56),(12,49),(8,46),(7,36),(10,29),(15,26),(14,23),
 (12,19),(12,12),(14,10)],'ink')
s.save_silhouette(str(OUT/'silhouette.png'))
# Boots and trousers.
rect(13,47,29,55,'brown'); rect(14,48,20,55,'gray')
rect(23,49,28,56,'tealDark'); line(21,49,21,56,'ink')
poly([(13,55),(18,55),(18,59),(10,59),(11,57)],'leather')
rect(10,60,18,60,'brown'); line(12,56,16,56,'gold')
poly([(24,56),(29,56),(29,58),(32,59),(32,60),(25,60)],'brown')
line(25,57,28,57,'leather')
# Coat, cream shirt, and sleeves.
poly([(15,26),(28,26),(33,30),(33,47),(29,50),(12,49),(10,43),(10,32)],'tealDark')
poly([(14,28),(20,28),(20,46),(13,47),(11,41),(12,32)],'teal')
poly([(15,29),(17,29),(16,38),(13,40),(13,33)],'tealLight')
poly([(20,27),(25,27),(26,35),(22,39),(19,33)],'cream')
poly([(26,28),(30,29),(32,33),(30,44),(25,47),(23,41)],'teal')
line(27,32,26,38,'tealLight')
# Far sleeve and open hand holding a coin.
poly([(31,30),(34,32),(36,36),(39,37),(38,40),(34,39),(31,35)],'teal')
poly([(37,35),(40,35),(42,37),(41,39),(38,39),(36,38)],'skin')
line(38,35,40,35,'light'); rect(39,32,41,34,'gold'); s.px(40,32,C['cream'])
# Near sleeve and hand.
poly([(10,32),(14,33),(14,40),(12,43),(9,41),(9,36)],'teal')
line(10,33,10,37,'tealLight')
rect(10,41,13,45,'skin'); line(10,41,12,41,'light')
# Belt and apron split.
rect(14,43,31,45,'brown'); rect(22,43,25,45,'gold'); rect(23,44,24,44,'ink')
line(21,47,20,51,'ink'); line(14,48,18,48,'tealLight')
# Cross-body leather strap and satchel.
poly([(28,26),(30,27),(17,43),(15,42)],'brown')
line(28,28,17,41,'gold')
poly([(9,43),(17,42),(20,45),(19,51),(10,51),(8,48)],'ink')
poly([(10,44),(16,43),(18,45),(18,49),(11,50),(9,47)],'leather')
poly([(10,44),(16,44),(18,45),(15,47),(11,47)],'gold')
rect(14,46,15,48,'brown')
# Neck, ears, face.
rect(20,23,26,28,'leather'); rect(20,24,24,27,'skin')
poly([(15,13),(29,12),(31,16),(30,23),(27,26),(20,25),(16,22)],'skin')
poly([(17,14),(25,14),(26,18),(24,21),(18,20),(16,17)],'light')
rect(13,17,15,20,'leather'); rect(14,17,15,19,'skin')
rect(30,17,32,20,'leather'); s.px(31,18,C['skin'])
# Hair and friendly moustache, readable paired eyes.
poly([(14,12),(19,11),(28,12),(30,15),(28,16),(26,14),(18,15),(16,18),(14,17)],'brown')
rect(18,17,20,17,'brown'); rect(26,17,28,17,'brown')
rect(19,18,20,19,'ink'); rect(27,18,28,19,'ink')
rect(23,19,24,21,'skin')
poly([(20,22),(22,21),(24,22),(26,21),(28,22),(26,24),(23,23),(21,24)],'brown')
line(23,24,25,24,'cream')
# Soft merchant cap and contrasting band.
poly([(13,12),(14,8),(17,5),(25,5),(29,7),(31,11),(29,13),(17,14)],'tealDark')
poly([(15,10),(17,7),(25,6),(28,8),(28,10),(23,11)],'teal')
line(18,7,23,7,'tealLight')
poly([(13,12),(21,11),(30,11),(32,13),(29,15),(20,14),(13,14)],'brown')
line(15,12,29,12,'gold'); rect(27,11,28,13,'red')

# Second pass: clarify the hanging coat panel and the far boot's upper plane.
poly([(26,47),(30,46),(29,49),(25,50)],'tealDark')
line(25,48,28,48,'teal')
rect(25,56,28,56,'leather')
line(26,58,29,58,'leather')

s.save_png(str(OUT/'npc-merchant.png'))
s.save_png(str(OUT/'npc-merchant-8x.png'), scale=8)
s.preview(str(OUT/'preview.png'), scale=8)
s.stats()
