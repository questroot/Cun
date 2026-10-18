"""Rebuild hero walk atlases from the preserved raw sheets. Requires Pillow.

Run from any directory: python tools/prepare_hero_walk.py
Several capes cross a nominal 384x512 cell. Explicit component bounds preserve
those silhouettes without including neighbouring sprites.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'card-demo/assets/characters/hero/walk'
# Bounding boxes of the eight main alpha components, in reading order.
BOUNDS = {
    'E': [(8,11,366,496),(388,14,741,495),(761,11,1117,496),(1148,10,1492,496),(17,512,384,993),(401,514,751,995),(775,514,1132,996),(1152,514,1501,992)],
    'N': [(28,19,360,502),(407,15,741,498),(792,10,1119,502),(1174,10,1495,496),(26,523,369,1000),(394,523,749,1000),(784,525,1126,999),(1158,522,1507,999)],
    'NE': [(16,13,394,502),(408,11,770,503),(777,13,1150,501),(1166,3,1526,501),(14,514,387,1003),(403,514,767,1001),(785,514,1153,999),(1166,515,1527,992)],
    'NW': [(43,17,377,499),(426,16,764,499),(815,16,1136,499),(1185,16,1525,494),(27,529,370,1005),(418,528,766,1005),(801,527,1163,1006),(1206,523,1520,1004)],
    'S': [(26,6,386,501),(408,6,769,503),(793,6,1157,500),(1184,5,1529,497),(21,516,392,1012),(412,516,769,1012),(795,516,1150,1012),(1174,516,1528,994)],
    'SE': [(16,9,385,504),(392,9,757,504),(766,9,1139,506),(1152,9,1521,506),(13,518,382,1006),(394,517,764,1011),(779,517,1150,1008),(1159,517,1526,992)],
    'SW': [(31,15,411,495),(397,14,795,495),(771,13,1181,495),(1166,12,1528,495),(16,509,436,987),(397,511,802,991),(767,511,1189,990),(1169,512,1529,991)],
    'W': [(46,15,447,497),(417,14,813,498),(767,14,1173,498),(1137,14,1526,498),(44,506,450,991),(421,505,823,994),(789,505,1206,990),(1173,505,1532,990)],
}
CELL = (448, 512)
FOOT = (224, 504)


def build():
    for direction, boxes in BOUNDS.items():
        source = Image.open(DEST / 'source' / f'{direction}.png').convert('RGBA')
        assert source.size == (1536, 1024), f'Unexpected source size: {direction}'
        atlas = Image.new('RGBA', (CELL[0] * 4, CELL[1] * 2))
        for index, (left, top, right, bottom) in enumerate(boxes):
            # Keep two pixels of the original antialiased edge around each body.
            crop = source.crop((left-2, top-2, right+2, bottom+2))
            alpha = crop.getchannel('A')
            component = alpha.point(lambda value: 255 if value > 127 else 0)
            seed = (crop.width // 2, crop.height // 2)
            assert component.getpixel(seed) == 255, (direction, index, 'missing body')
            ImageDraw.floodfill(component, seed, 128)
            component = component.point(lambda value: 255 if value == 128 else 0)
            assert component.getbbox() == (2, 2, crop.width-2, crop.height-2)
            edge_mask = component.filter(ImageFilter.MaxFilter(5))
            crop.putalpha(Image.composite(alpha, Image.new('L', crop.size), edge_mask))
            x = FOOT[0] - crop.width // 2
            y = FOOT[1] - (crop.height - 2)
            assert x >= 0 and y >= 0 and x+crop.width <= CELL[0] and y+crop.height <= CELL[1]
            atlas.paste(crop, ((index % 4)*CELL[0]+x, (index // 4)*CELL[1]+y))
        output = DEST / f'walk_{direction}.png'
        atlas.save(output)
        print(f'{output.relative_to(ROOT)}: {atlas.size}, 8 frames')


if __name__ == '__main__':
    build()
