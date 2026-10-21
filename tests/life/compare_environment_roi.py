"""Read-only pixel differences on held fixed-camera machine/smoke frames.
ROI changes are evidence to inspect, never automatic proof of correct animation.
"""
import argparse,json
from pathlib import Path
from PIL import Image,ImageChops
p=argparse.ArgumentParser();p.add_argument('states');p.add_argument('--out',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2]
data=json.JSONDecoder().raw_decode(Path(a.states).read_text())[0]
rows=data['records'];groups={}
for r in rows:
    label=r['label']
    if '-work-' in label: group=r['kind']+'-working'
    elif '-stopped-' in label: group=r['kind']+'-stopped'
    elif '-missing-' in label: group=r['kind']+'-missing'
    elif 'cooking-smoke-' in label: group='kitchen-smoke'
    else: continue
    if 'buildingScreen' not in r: continue
    groups.setdefault(group,[]).append(r)
results=[]
for group,records in groups.items():
    if len(records)<2: continue
    first=records[0];kind=first['kind'];spec=first['spriteSpec']
    point={'mill':[160,164],'smelter':spec.get('workPoint',[128,174]),'sawmill':spec.get('sawPoint',[104,160]),'bakery':spec.get('ovenPoint',[83,164]),'kitchen':spec.get('chimney',[210,89])}[kind]
    extents={'mill':[-13,-6,13,6],'smelter':[-12,-12,2,1],'sawmill':[-19,0,19,5],'bakery':[-5,-4,7,6],'kitchen':[-1,-28,6,0]}[kind]
    scale=first['camera']['zoom'];bx=first['buildingScreen']['x'];by=first['buildingScreen']['y']
    cx=bx+(point[0]-spec['anchorX'])*scale;cy=by+(point[1]-spec['anchorY'])*scale
    if kind in ('mill','smelter') and first.get('workScreen'):
        cx=first['workScreen']['x'];cy=first['workScreen']['y']
        extents= [-10,-22,10,-12] if kind=='mill' else [-14,-35,2,-6]
    box=tuple(round(v)for v in [cx+extents[0]*scale,cy+extents[1]*scale,cx+extents[2]*scale,cy+extents[3]*scale])
    base=Image.open(root/first['path']).convert('RGBA').crop(box)
    for other in records[1:]:
        if first['camera']!=other['camera']:raise ValueError('camera changed; do not compare this pair')
        crop=Image.open(root/other['path']).convert('RGBA').crop(box)
        diff=ImageChops.difference(base.convert('RGB'),crop.convert('RGB'))
        changed=sum(1 for pixel in diff.getdata() if any(pixel))
        results.append({'group':group,'first':first['path'],'second':other['path'],'roi':box,'pixels':base.width*base.height,'changed':changed,'firstTime':first['time'],'secondTime':other['time'],'firstTimer':first['timer'],'secondTimer':other['timer'],'firstRate':first.get('workRate'),'secondRate':other.get('workRate'),'interpretation':'Inspect original frames and ROI; changing pixels alone are not acceptance'})
Path(a.out).write_text(json.dumps(results,ensure_ascii=False,indent=2));print(json.dumps(results,ensure_ascii=False))
