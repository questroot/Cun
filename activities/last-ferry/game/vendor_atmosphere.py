"""Run from any directory: exact portable copy of the shared addon, no logic edits."""
from pathlib import Path
import hashlib
import shutil
import json
root = Path(__file__).resolve().parents[3]
source = root / 'shared/godot/atmosphere2d/addon'
target = Path(__file__).resolve().parent / 'addons/cun_atmosphere2d'
expected = '7f00bc9c7687dbf3dde1390e2172d81957a0eafb0d3426bd23dc6244750da67b'
assert hashlib.sha256((source/'atmosphere.gd').read_bytes()).hexdigest() == expected
shutil.copytree(source,target,dirs_exist_ok=True)
(target/'vendor_source.json').write_text(json.dumps({'source':'shared/godot/atmosphere2d/addon','atmosphere_sha256':expected},indent=2),encoding='utf8')
