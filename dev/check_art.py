#!/usr/bin/env python3
"""Check hand-painted asset import before a Maker build; does not change files."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
plan = json.loads((root / 'docs/art/handpaint-layout.json').read_text())
images = root / plan['destination']
sprites = [name for atlas in plan['atlases'].values() for name in atlas['outputs']]
names = sprites + list(plan['singleImages'].values())
issues = []
for name in names:
    path = images / (name + '.png')
    if not path.is_file():
        issues.append(f'{name}: missing PNG')
        continue
    try:
        with Image.open(path) as image:
            image.load()
            if min(image.size) < 16:
                issues.append(f'{name}: image too small {image.size}')
            if name in sprites:
                if 'A' not in image.getbands() or image.getchannel('A').getextrema()[0] == 255:
                    issues.append(f'{name}: transparent background missing')
            if name.startswith('ground-') and abs(image.width / image.height - 2) > 0.03:
                issues.append(f'{name}: expected 2:1 terrain diamond, got {image.size}')
    except Exception as exc:
        issues.append(f'{name}: unreadable PNG: {exc}')
    if not Path(str(path) + '.meta').is_file():
        issues.append(f'{name}: official resource metadata missing')
if plan.get('review') != 'reviewed':
    issues.append('Actual source images / atlas bindings have not passed visual review')
print(f'Art import: {len(names)} expected images; {len(issues)} issues')
for issue in issues[:12]:
    print(' - ' + issue)
if len(issues) > 12:
    print(f' - ... {len(issues)-12} additional issues')
raise SystemExit(1 if issues else 0)
