#!/usr/bin/env python3
"""Cun asset registry; Python 3.10+, standard library only."""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
KINDS = {'.png':'image', '.jpg':'image', '.jpeg':'image', '.webp':'image', '.svg':'image', '.gif':'image', '.wav':'audio', '.ogg':'audio', '.mp3':'audio', '.glb':'model', '.gltf':'model', '.blend':'source', '.aseprite':'source', '.psd':'source', '.ttf':'font', '.otf':'font'}
STATUSES = ('draft', 'review', 'approved', 'deprecated')
FIELDS = ('name', 'source', 'license', 'author', 'status', 'notes', 'tags')


def safe_path(root, value):
    if not isinstance(value, str) or not value or '\\' in value:
        raise ValueError('路径必须是仓库相对路径，使用 /')
    p = Path(value)
    if p.is_absolute() or '..' in p.parts or ':' in value:
        raise ValueError('禁止绝对路径或越界路径')
    resolved = (root / p).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError('路径逃逸仓库（含符号链接）')
    return resolved


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def load(path):
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('assets'), list):
        raise ValueError('不支持的资源清单，要求 version=1 和 assets 数组')
    return data


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    # Same-directory atomic replacement; a failed write leaves the prior registry intact.
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as f:
        f.write(text)
        temp = Path(f.name)
    try:
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def scan(root, data, directory):
    folder = safe_path(root, directory)
    if not folder.is_dir():
        raise ValueError('扫描目录不存在')
    old = {a['path']: a for a in data['assets']}
    ids = {a['id'] for a in data['assets']}
    added = 0
    for p in sorted(folder.rglob('*')):
        if not p.is_file() or p.suffix.lower() not in KINDS:
            continue
        rel = p.relative_to(root).as_posix()
        safe_path(root, rel)
        if rel in old:
            continue  # Never silently accept a changed file or overwrite metadata.
        base = 'asset_' + hashlib.sha256(rel.encode()).hexdigest()[:16]
        if base in ids:
            raise ValueError('资源 ID 冲突，请人工检查')
        data['assets'].append(dict(id=base, name=p.stem, path=rel, kind=KINDS[p.suffix.lower()], tags=[], source='unknown', license='unknown', author='unknown', status='draft', notes='', sha256=digest(p)))
        ids.add(base)
        added += 1
    return added


def validate(root, data, release=False):
    errors, warnings, ids, paths, hashes = [], [], set(), set(), {}
    for i, a in enumerate(data['assets']):
        label = f'assets[{i}]'
        if not isinstance(a, dict):
            errors.append(f'{label}: 不是对象')
            continue
        missing = set(('id', 'path', 'kind', 'sha256') + FIELDS) - set(a)
        if missing:
            errors.append(f'{label}: 缺少 {sorted(missing)}')
            continue
        if not all(isinstance(a[k], str) for k in ('id', 'path', 'kind', 'sha256') + FIELDS[:-1]):
            errors.append(f'{label}: 字段类型错误')
            continue
        label = a['id']
        if not re.fullmatch(r'asset_[a-z0-9_]+', label):
            errors.append(f'{label}: 非法 ID')
        if label in ids or a['path'].casefold() in paths:
            errors.append(f'{label}: 重复 ID 或路径')
        ids.add(label)
        paths.add(a['path'].casefold())
        if a['status'] not in STATUSES or a['kind'] not in set(KINDS.values()):
            errors.append(f'{label}: 非法分类或状态')
        if not isinstance(a['tags'], list) or not all(isinstance(t, str) for t in a['tags']):
            errors.append(f'{label}: tags 必须是字符串数组')
        if not re.fullmatch(r'[a-f0-9]{64}', a['sha256']):
            errors.append(f'{label}: 无效 SHA256')
        try:
            p = safe_path(root, a['path'])
            if not p.is_file():
                errors.append(f'{label}: 文件缺失 {a["path"]}')
            elif digest(p) != a['sha256']:
                errors.append(f'{label}: 文件内容变化；核验后 refresh')
        except ValueError as e:
            errors.append(f'{label}: {e}')
        if a['sha256'] in hashes:
            warnings.append(f'{label}: 与 {hashes[a["sha256"]]} 内容重复（不自动删除）')
        hashes[a['sha256']] = label
        unknown = any(a[k].strip().lower() in ('', 'unknown', 'todo', '待确认') for k in ('source', 'license', 'author'))
        if unknown:
            (errors if release else warnings).append(f'{label}: 来源/许可/作者待核验')
        if release and a['status'] != 'approved':
            errors.append(f'{label}: 发布要求 approved')
    return errors, warnings


def catalog(root, data, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    cards = []
    for a in data['assets']:
        p = safe_path(root, a['path'])
        url = quote(os.path.relpath(p, output.parent).replace('\\', '/'), safe='/')
        # Do not render SVG, HTML or unknown files as active content.
        preview = f'<img loading="lazy" src="{url}" alt="">' if p.suffix.lower() in ('.png','.jpg','.jpeg','.gif','.webp') else '<div class="placeholder">' + html.escape(a['kind']) + '</div>'
        esc = lambda value: html.escape(str(value), quote=True)
        tags = ', '.join(a['tags'])
        cards.append(f'<article data-kind="{esc(a["kind"])}" data-status="{esc(a["status"])}">{preview}<h2>{esc(a["name"])}</h2><p>{esc(a["id"])}</p><p>{esc(a["path"])}</p><p>{esc(a["kind"])} · {esc(a["status"])} · {esc(tags)}</p><p>许可：{esc(a["license"])}<br>来源：{esc(a["source"])}<br>作者：{esc(a["author"])}</p><p>{esc(a["notes"])}</p><a href="{url}" target="_blank" rel="noopener">打开文件</a></article>')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cun 资源图册</title><style>
body{margin:0;background:#101725;color:#e4eaf5;font:15px system-ui}header{padding:28px;position:sticky;top:0;background:#182238;z-index:1}h1{margin:0 0 10px;color:#86e6cc}input,select{padding:10px;margin:6px;border:1px solid #485970;background:#101725;color:white;border-radius:6px}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:18px}article{background:#1b263b;padding:16px;border-radius:10px;overflow-wrap:anywhere}article[hidden]{display:none}img,.placeholder{width:100%;height:180px;object-fit:contain;background:#101725;border-radius:6px}.placeholder{display:grid;place-items:center;color:#86e6cc}h2{font-size:18px}p{color:#bdc9dd;font-size:13px}a{color:#86e6cc}#count{margin-left:12px}</style><header><h1>Cun / 资源图册</h1><div>本地图册只读；用 tools/assets.py 维护元数据。draft / unknown 不代表可发布。</div><input id="q" aria-label="搜索" placeholder="名称、路径、标签、许可"><select id="kind" aria-label="分类"><option value="">全部分类</option>image<option>audio</option><option>model</option><option>source</option><option>font</option></select><select id="status" aria-label="状态"><option value="">全部状态</option><option>draft</option><option>review</option><option>approved</option><option>deprecated</option></select><span id="count"></span></header><main>CARDS</main><script>
const q=document.querySelector('#q'),kind=document.querySelector('#kind'),status=document.querySelector('#status'),cards=[...document.querySelectorAll('article')];function filter(){let n=0;for(const c of cards){c.hidden=!(c.textContent.toLowerCase().includes(q.value.toLowerCase())&&(!kind.value||kind.value===c.dataset.kind)&&(!status.value||status.value===c.dataset.status));if(!c.hidden)n++;}document.querySelector('#count').textContent=n+' / '+cards.length;}[q,kind,status].forEach(e=>e.addEventListener('input',filter));filter();</script></html>'''
    page = page.replace('<option value="">全部分类</option>image', '<option value="">全部分类</option><option>image</option>')
    output.write_text(page.replace('CARDS', '\n'.join(cards)), encoding='utf-8')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--manifest', default='assets/registry.json')
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('scan'); p.add_argument('directory')
    p = sub.add_parser('check'); p.add_argument('--release', action='store_true')
    p = sub.add_parser('catalog'); p.add_argument('--output', default='assets/catalog.html')
    p = sub.add_parser('set'); p.add_argument('id')
    for field in FIELDS:
        p.add_argument('--' + field)
    p = sub.add_parser('refresh'); p.add_argument('id')
    p = sub.add_parser('remove'); p.add_argument('id')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        manifest = safe_path(root, args.manifest)
        if not manifest.exists() and args.command != 'scan':
            raise ValueError('资源清单不存在；先 scan 登记资源')
        data = load(manifest) if manifest.exists() else {'version':1, 'assets':[]}
        if args.command == 'scan':
            print(f'新增 {scan(root, data, args.directory)} 项；已有记录不覆盖')
            save(manifest, data)
        elif args.command == 'check':
            errors, warnings = validate(root, data, args.release)
            for w in warnings: print('WARN ' + w)
            for e in errors: print('ERROR ' + e)
            print(f'{len(data["assets"])} assets; {len(errors)} errors; {len(warnings)} warnings')
            return bool(errors)
        elif args.command == 'catalog':
            errors, _ = validate(root, data)
            if errors: raise ValueError('清单检查失败：' + '; '.join(errors))
            output = safe_path(root, args.output)
            if output == manifest or output.suffix.lower() != '.html':
                raise ValueError('输出必须是独立 .html 文件')
            if output.exists() and not output.read_text(encoding='utf-8').startswith('<!doctype html><html lang="zh-CN">'):
                raise ValueError('拒绝覆盖非本工具生成的文件')
            catalog(root, data, output)
            print(output)
        else:
            a = next((a for a in data['assets'] if a['id'] == args.id), None)
            if a is None: raise ValueError('资源 ID 不存在')
            if args.command == 'remove':
                data['assets'].remove(a)  # Metadata only: original file is never deleted.
            elif args.command == 'refresh':
                a['sha256'] = digest(safe_path(root, a['path']))
                a['status'] = 'review'  # Changed content invalidates approval.
            else:
                for field in FIELDS:
                    value = getattr(args, field)
                    if value is not None:
                        if field == 'status' and value not in STATUSES: raise ValueError('非法状态')
                        a[field] = [t.strip() for t in value.split(',') if t.strip()] if field == 'tags' else value
            save(manifest, data)
        return 0
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as e:
        print('ERROR ' + str(e), file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
