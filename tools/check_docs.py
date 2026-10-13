#!/usr/bin/env python3
"""Check local file links in foundation Markdown (not legacy prototype docs)."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT):
    files = [root / name for name in ('README.md', 'CONTRIBUTING.md', 'AGENTS.md', 'PROJECT_STATUS.md')]
    for directory in ('docs', 'assets', 'launcher', '.setup/Godot'):
        files.extend(sorted((root / directory).rglob('*.md')))
    errors = []
    total = 0
    for file in files:
        text = file.read_text(encoding='utf-8')
        text = re.sub(r'```.*?```', '', text, flags=re.S)
        for raw in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            target = raw.strip().strip('<>')
            if urlsplit(target).scheme or target.startswith('//'):
                continue
            path = unquote(target.split('#', 1)[0])
            dest = file.parent / path if path else file
            total += 1
            if not dest.exists():
                # The local catalog is generated on demand and intentionally not committed.
                if dest.resolve() == (root / 'assets/catalog.html').resolve():
                    continue
                errors.append(f'{file.relative_to(root)}: missing {target}')
    return total, errors


if __name__ == '__main__':
    total, errors = check()
    for error in errors: print('ERROR ' + error)
    print(f'{total} local links; {len(errors)} errors')
    sys.exit(bool(errors))
