"""Offline cleanup and explicit review bookkeeping for gateway output; no API calls."""
import argparse
import hashlib
import html
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageOps

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/"output/imagegen/fudi-fine"
QUEUE=FOLDER/"queue.json"


def gallery(plan):
    cards=[]
    approved=sum(a["state"]=="approved" for a in plan["assets"])
    thumbs=FOLDER/"thumbnails"
    thumbs.mkdir(exist_ok=True)
    for a in plan["assets"]:
        raw=ROOT/a["raw"]
        if raw.exists():
            thumb=thumbs/raw.name
            if not thumb.exists():
                with Image.open(raw) as im:
                    im.thumbnail((480,340),Image.Resampling.NEAREST)
                    im.convert("RGB").save(thumb)
            art=f'<a href="{raw.name}"><img loading="lazy" src="thumbnails/{raw.name}" alt="{html.escape(a["name"])}"></a>'
        else:
            art='<div class="placeholder">待生成</div>'
        state={"approved":"已检查","pending":"待生成","awaiting_visual_review":"待检查","needs_revision":"待返修"}.get(a["state"],a["state"])
        cards.append(f'<figure>{art}<figcaption>{a["index"]:02d} · 第{a["batch"]}轮 · {html.escape(a["name"])}<small>{state}</small></figcaption></figure>')
    page='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>福地精细像素素材</title>
<style>body{margin:0;background:#112c30;color:#e8e2c7;font:16px system-ui}header{padding:26px 36px;border-bottom:1px solid #49666a}h1{margin:0 0 8px;font-size:28px}p{color:#adc4bc}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:20px;padding:28px}figure{margin:0;background:#1c393d;border:1px solid #476469;border-radius:10px;overflow:hidden}img,.placeholder{display:block;width:100%;height:230px;object-fit:contain;background:#092227}.placeholder{display:grid;place-items:center;color:#617e7d}figcaption{padding:15px}small{display:block;color:#8eaea4;margin-top:5px}a{color:inherit}</style>
<header><h1>福地精细像素素材</h1>'''+f'<p>图像网关 · 高质量 · 已检查 {approved}/54 张 · 当前每轮最多4张，串行生成</p>'+'''<p>点击图片查看原图。地图场景为美术底稿；可行走地图仍需核对碰撞。</p></header><main class="grid">'''+''.join(cards)+'</main>'
    (FOLDER/"gallery.html").write_text(page,encoding="utf-8")


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("index",type=int)
    ap.add_argument("--prepare",action="store_true")
    ap.add_argument("--accept",action="store_true")
    ap.add_argument("--reject",action="store_true")
    ap.add_argument("--notes")
    args=ap.parse_args()
    plan=json.loads(QUEUE.read_text(encoding="utf-8"))
    a=next(e for e in plan["assets"] if e["index"]==args.index)
    raw=ROOT/a["raw"]
    if args.prepare:
        with Image.open(raw) as source:
            source.load()
            im=source.convert("RGBA")
        assert min(im.size)>=512,"Generation returned unexpectedly small output"
        if a["category"]!="maps" and im.getchannel("A").getextrema()[0]==255:
            # Use the asset's explicit key color; default to the original magenta.
            # This remains deterministic and binary-alpha. Always inspect the cutout.
            px=im.load()
            removed=0
            for y in range(im.height):
                for x in range(im.width):
                    r,g,b,alpha=px[x,y]
                    magenta=r>160 and b>150 and g<150 and r-g>65 and b-g>60
                    green=g>150 and g-r>65 and g-b>60
                    is_background=green if a.get("chroma_key")=="green" else magenta
                    if is_background:
                        px[x,y]=(0,0,0,0)
                        removed+=1
            assert removed>im.width*im.height*.05,"No usable chroma background; inspect raw before accepting"
            assert im.getbbox(),"Background extraction removed entire subject"
        candidate=FOLDER/"cutouts"/raw.name
        candidate.parent.mkdir(exist_ok=True)
        im.save(candidate)
        compressed=FOLDER/"compressed"/(raw.stem+".webp")
        compressed.parent.mkdir(exist_ok=True)
        im.save(compressed,format="WEBP",lossless=True,method=6,exact=True)
        with Image.open(compressed) as check:
            assert check.convert("RGBA").tobytes()==im.tobytes(),"Lossless compression changed pixels"
        a.update(compressed=compressed.relative_to(ROOT).as_posix(),
                 compressed_bytes=compressed.stat().st_size,compression="lossless_webp_pixel_verified")
        print("COMPRESSED",raw.stat().st_size,"->",compressed.stat().st_size,"bytes; pixels verified")
        # Both backgrounds reveal accidental holes, fringes and baked checkerboards.
        previews=FOLDER/"review"
        previews.mkdir(exist_ok=True)
        light=Image.new("RGBA",im.size,"#d5d7c3")
        dark=Image.new("RGBA",im.size,"#172f38")
        light.alpha_composite(im);dark.alpha_composite(im)
        light.thumbnail((1100,800),Image.Resampling.NEAREST)
        dark.thumbnail((1100,800),Image.Resampling.NEAREST)
        light.convert("RGB").save(previews/(raw.stem+"_light.png"))
        dark.convert("RGB").save(previews/(raw.stem+"_dark.png"))
        a.update(state="awaiting_visual_review",candidate=candidate.relative_to(ROOT).as_posix(),
                 raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),actual_size=list(im.size))
        print("PREPARED",a["index"],a["name"],im.size,"NOT YET ACCEPTED")
    if args.accept or args.reject:
        if not args.notes:ap.error("Individual visual review notes are required")
        assert raw.is_file(),"Missing generated source"
        a.update(state="approved" if args.accept else "needs_revision",visual_review=args.notes)
        print("REVIEW",a["index"],a["state"])
    QUEUE.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    gallery(plan)


if __name__=="__main__":main()
