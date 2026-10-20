"""Write prompts and a resumable review queue. Makes no network/API calls.

Generation uses the installed imagegen skill CLI directly, one asset at a time.
"""
import json
from pathlib import Path
import re

from build import ASSETS, REGIONS, ROOT, HERBS

DEST = ROOT / "output/imagegen/fudi-fine"
STYLE = """Premium hand-crafted 16-bit / 32-bit JRPG pixel art, highly detailed and polished,
consistent crisp square pixel clusters, selective dark outlines, layered cool shadows,
warm top-left light, jade and teal, aged gold, cedar brown and muted plum palette.
Rich material-specific pixel texture, deliberate clustered highlights, tasteful weathering.
Authentic game asset, not vector art, not a flat geometric diagram, not a 3D render,
not photorealistic, no smooth gradients, no blur, no anti-aliased painted edges.
No characters, no monsters, no interface, no frame, no labels, no letters, no numbers,
no watermark, no logos, no signature. Maintain a consistent art direction across this set."""
THEMES = {
    "grove": "lush old Chinese cooking street and medicinal gardens, jade shrubs, worn ochre flagstones, tiled communal kitchens, bamboo baskets, gentle warm cooking smoke",
    "post": "quiet abandoned Chinese postal town, grey green paving, weathered cedar mail houses, red postboxes, faded paper envelopes and crimson pennants without writing, ivy and low stone walls",
    "quarry": "red sandstone quarry settlement with bronze clockwork, terracotta roofs, ancient stone retaining walls, rust red mineral strata, stacked rock slabs, amber forge glow, restrained moss",
    "ruins": "ancient spring research sanctuary, dark blue stone, glowing turquoise channels, water basins and crystalline data relics, cracked teal tile floors, weathered observation platforms",
    "refuge": "mountain rescue encampment, grey green stone and canvas supply shelters, healing herb gardens, amber lanterns, teal rescue banners, humble wooden fences, protective mountain woodland",
    "wetland": "rain-lantern marsh, shallow jade water, dense reeds, lotus leaves, wooden waterside pavilions and raised plank footpaths, old stone irrigation banks, warm hanging amber lanterns",
    "causeway": "broken stone bridge postal road, slate grey masonry, separated bridge fragments across dark teal canals, safe looping old stone roads, wind-worn gate towers, pale blue pennants, sparse hardy grass",
    "kilnwood": "pine charcoal woodland and old brick kilns, sooty brown ground, burnt cedar bark, dark moss, amber pine resin, warm ember hearths, carefully contained smoke, dense deep green pine clusters",
    "archive": "mysterious mirror-sand archive campus, muted plum stone floors, lavender domed repositories, pale cyan crystal sand pools, bronze astronomical devices, weathered book storage alcoves, restrained violet flowers",
    "snowridge": "snowy mountain observatory ridge, wind-swept powder snow, icy blue stone paths, frosted pines, slate blue roofs capped with snow, small amber rescue lights, pale turquoise ice and exposed mountain rock",
}
BUILDINGS = {
    "grove": "a grand communal Chinese dining hall with broad two-tier curved jade tile roofs, deep cedar columns, latticed amber windows, a carved bowl-and-rice emblem without writing, a sheltered cooking alcove, pottery and vegetable baskets",
    "post": "a grand fortified postal relay hall with twin watchtowers, grey green upturned tile roofs, weathered wood columns, central arch entrance, an envelope emblem without writing, red metal postbox, mail sacks and a small crimson pennant",
    "quarry": "a monumental red-rock forge hall, copper red tiled roof, two tall worn brick chimneys with compact pixel smoke, broad blackened furnace arch with amber fire, side anvil and tools, iron-bound cedar doors and stone stairs",
    "ruins": "a grand spring mirror sanctuary, turquoise ribbed dome over curved blue tile roofs, a floating pale cyan crystal above the dome, stone water basins on both sides, cedar colonnade, luminous inset windows, wide stone stairs",
    "refuge": "a grand mountain rescue headquarters with jade curved tile roof, a tasteful herb-leaf healing emblem, green banners, sheltered medicine crates, orderly supplies, stone and cedar columns, amber lattice windows and broad accessible stairs",
    "wetland": "a grand open-sided waterside pavilion on visible wooden stilts, long jade curved tile roof, layered cedar beams, many hanging warm lanterns, plank verandas and front stairs, carved railing, dock ropes and mooring posts",
    "causeway": "a monumental fortified bridge gatehouse with two slate stone watchtowers, layered grey blue upturned tiled roofs, central heavy wooden portcullis and arch, pale blue pennants, worn stone columns, bronze rivets and broad stone stairs",
    "kilnwood": "a monumental old pine charcoal kiln complex: large central brick barrel kiln with round black furnace arch and warm ember glow, two sooty chimneys, cedar side galleries, worn brown tiles, stacked logs, resin jars and broad stone stairs",
    "archive": "a grand mystical archive hall, large lavender ribbed dome and plum curved tile roofs, carved bronze ribs, an open-book emblem without text, recessed book alcoves, cool cyan lattice windows, cedar columns and wide stone stairs",
    "snowridge": "a grand snowy ridge astronomical observatory with blue tile roofs and broad snow caps, ribbed dome, large bronze armillary sphere and telescope on top, warm small windows, slate columns, frost-tipped eaves and broad stone stairs",
}
SPECIES = {
    "bloodgrass": "hemostatic grass with long narrow jade blades, reddish purple tips and fine bright leaf veins, tufted rosette silhouette",
    "dewleaf": "dewleaf plant with round heart-shaped turquoise leaves, thick pale central veins and large clean pale cyan dew droplets",
    "berry": "sweet dew berry shrub sprig with rounded serrated leaves and clearly visible clusters of ripe coral pink berries with tiny warm glints",
    "wakeleaf": "awakening herb with branching stems and star-shaped pointed lime jade leaves, small amber vein highlights, wind-curled pointed leaf tips",
    "restflower": "restflower with drooping violet five-petal blossoms, delicate pale gold centers, slender dark stems and narrow muted jade leaves",
    "herb": "spirit herb with a graceful teal leafy stem, white cyan star-like flower, tiny clustered luminous cyan buds and clear broad leaf silhouettes",
    "warmflower": "warm fleece flower with fluffy layered amber gold pompom petals, coral heart, broad jade leaves and a robust short stem, cozy snow-resistant plant",
    "moss": "a patch of tiny lush olive and jade moss cushions growing from a rough dark grey split stone, tiny fern-like fronds and pale green top-left highlights",
    "mint": "cool mint with paired serrated turquoise leaves and prominent pale center veins, upright purple bud spikes, fresh crisp broad silhouette",
    "rush": "lampwick rush tuft with long slender olive green reeds, pale gold cylindrical seed heads, curved leaves and clustered roots",
    "bitterroot": "bitterheart medicinal root with a gnarled forked honey tan root, woody grooves, fine smaller rootlets and a small fan of deep jade leaves",
}
SCENERY = {
    "camphor": "a mature camphor tree with a broad asymmetric layered jade canopy, sturdy twisting cedar-brown trunk, clustered leaves lit from top left, some hanging roots",
    "pine": "a mature Chinese pine with a sinuous aged trunk and tiered wind-shaped dark jade needle canopies, compact olive highlights, visible lower bark",
    "charred_pine": "a weathered partly charred pine with dark brown cracked bark, asymmetrical blackened branches, remaining muted olive needle clusters and a few amber resin knots, no uncontrolled fire",
    "snow_pine": "a hardy blue jade pine with layered boughs carrying thick white snow caps, icy blue shadow clusters and visible warm dark trunk",
    "reeds": "a dense natural clump of marsh reeds, several graceful curved olive leaves, upright thin stems and warm tan fluffy seed heads with varied heights",
    "lotus": "a small lush cluster of overlapping broad notched lotus leaves with visible veins, one elegant pink lotus flower and two closed buds, no surrounding pond",
    "shrub": "a compact asymmetric wild berry shrub with layered jade foliage, rounded serrated leaves and small coral berry clusters, visible slender stems",
}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    prompts=DEST/"prompts"
    prompts.mkdir(exist_ok=True)
    maps_text=(ROOT/"card-demo/scripts/scenes/fudi_maps.gd").read_text(encoding="utf-8")
    queue=[]
    for i,a in enumerate(ASSETS):
        cat,key=a["category"],a["id"]
        opening=f"Use case: stylized-concept\nAsset type: finished pixel-art game {cat} asset\n"
        size="1024x1024"
        if cat=="maps":
            section=maps_text.split('"'+key+'": {',1)[1].split('\n\t},',1)[0]
            roads=re.search(r'"roads": (.+)',section).group(1)
            obstacles=re.search(r'"obstacles": (.+)',section).group(1)
            subject=f"""A beautifully detailed top-down orthographic playable region map of {THEMES[key]}.
Landscape canvas, game terrain fills all edges. Strict overhead camera, no horizon and no isometric tilt.
The map is a large coherent game playfield, not a world globe and not a decorative parchment.
Terrain and props are small relative to the whole scene so there is plenty of open walking space.
Keep the authored road route clear, 3 percent of map width, with normalized coordinates (x right, y down):
{roads}
Four non-walkable terrain blocks at these normalized Rect2(x,y,width,height) positions:
{obstacles}
Place region-themed walls/water/rock/garden only in those blocks and visually low scenery elsewhere.
Do not add a central hero, boss, treasure chest, UI or labels. Keep roads open and legible.
The large interactive building is added separately at runtime, so leave the third block understated.
Ground-level pixel texture with readable cobbles, moss, grass blades and small material clusters.
Use understated decorative details off the roads; preserve strong readability of the road network."""
            size="1536x1024"
        elif cat=="buildings":
            subject=f"""A single complete standalone exterior game sprite of {BUILDINGS[key]}.
Three-quarter overhead RPG building view, front entrance faces the bottom of the image.
Full building and all roof ornaments are visible, no cropped towers, generous 8 percent empty margin.
Broad majestic silhouette, central doorway and stairs land exactly at horizontal center.
Highly detailed individual roof tiles, joinery, masonry courses, carved brackets, worn corners,
material color variation and grounded architectural depth. Keep clear chunky pixel clusters.
No enclosing landscape, no grass field, no square pedestal, no unrelated objects.
Solid perfectly flat bright magenta #ff00ff background for chroma-key extraction, no checkerboard,
no gradient, no colored reflected magenta on the subject, no cast shadow on the magenta background."""
            size="1536x1024"
        elif cat=="chests":
            mutated=key.startswith("mutated")
            state=("open, lid lifted high, clearly empty dark interior, dull metal" if key.endswith("open") else
                   "closed, awakened, angular violet crystals and small red glowing eye slits, dangerous" if key.endswith("guarding") else
                   "closed, seals broken, cyan crystal lock and tiny golden reward glints, safe to claim" if key.endswith("cleared") else
                   "closed, locked and sealed with crisscross old silver chains" if mutated else
                   "closed, simple gold latch, welcoming treasure chest")
            subject=f"""A single standalone {'mysterious mutated violet' if mutated else 'ordinary warm cedar and aged gold'} treasure chest game sprite.
State: {state}. Three-quarter overhead front view with visible top, front and right side.
Beautiful chunky silhouette, individual carved planks, iron corner caps, rivets, a clear large central lock,
strong restrained clustered highlights, aged wood grain, readable at small size.
Entire object centered and uncropped with 12 percent margin. No props outside chest fittings.
Solid perfectly flat bright magenta #ff00ff background, no ground, no shadow, no checkerboard, no glow fog."""
        elif cat=="herbs":
            subject=f"""A single exquisite standalone collectible medicinal herb inventory icon: {SPECIES[key]}.
Whole plant specimen, compact elegant centered silhouette, beautifully structured leaves, crisp botanical detail,
subtle cool shadows and warm top-left glints. Clearly identifiable at small game icon scale.
No bottle, no bag, no frame, no pedestal, no circle behind it, no soil bed, no scenery.
Entire herb fits with 15 percent clear margin and no clipped leaves.
Solid perfectly flat bright magenta #ff00ff background, no shadow or checkerboard."""
        elif cat=="plants":
            subject=f"""An exact three-cell horizontal sprite sheet for one medicinal plant species: {SPECIES[key]}.
Exactly three separate clearly spaced plants LEFT TO RIGHT: tiny sprout, medium leafy plant with buds,
fully mature flowering or fruiting plant. Each occupies its own equal one-third of the canvas.
Each plant stands at the same bottom baseline with a tiny dark soil root clump.
No extra plants and no overlapping cells. Keep all silhouettes well inside their cells, at least 15 percent cell margin.
Fixed three-quarter overhead RPG perspective. Beautiful crisp leaf veins, flowers and roots, game-readable clusters.
Solid perfectly flat bright magenta #ff00ff background, no ground plane, no gridlines or cell borders,
no text labels, no staged arrows, no checkerboard. Full plant is visible in each cell."""
            size="1536x1024"
        else:
            subject=f"""A single standalone environmental vegetation sprite: {SCENERY[key]}.
Three-quarter overhead RPG view, full plant including its root contact, centered with 10 percent margin.
Rich layered foliage, intentional leaf clusters, natural asymmetric silhouette, beautiful bark or stem textures,
dark cool inner canopy and warm top-left light. Strong clean pixel-art silhouette at game scale.
No enclosing landscape, no ground plane, no pot, no square pedestal, no cast shadow.
Solid perfectly flat bright magenta #ff00ff background, no checkerboard and no gradient."""
        prompt=opening+subject+"\nStyle/medium:\n"+STYLE+"\n"
        stem=f"{i+1:02d}_{cat}_{key}"
        file=prompts/(stem+".txt")
        file.write_text(prompt,encoding="utf-8")
        queue.append({"index":i+1,"batch":i//3+1,"category":cat,"id":key,"name":a["name"].replace("地形图集","像素场景") if cat=="maps" else a["name"],
                      "prompt":file.relative_to(ROOT).as_posix(),"raw":(DEST/(stem+".png")).relative_to(ROOT).as_posix(),
                      "size":size,"model":"gpt-image-2","quality":"high","state":"pending"})
    plan=DEST/"queue.json"
    if plan.exists():
        old=json.loads(plan.read_text(encoding="utf-8"))
        for a,b in zip(queue,old["assets"]):
            if a["id"]==b["id"] and a["category"]==b["category"]:
                a.update({k:v for k,v in b.items() if k not in a or k=="state"})
    plan.write_text(json.dumps({"version":1,"batch_size":3,"concurrency":1,"assets":queue},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("GATEWAY_PLAN: 54 assets, 18 rounds, concurrency 1; no calls made by planner")


if __name__=="__main__":main()
