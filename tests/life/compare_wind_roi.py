"""Read-only fixed-camera pure ROI comparison; use isolated-tree fixture only.
PixelWorldView render bounds: crown y[-94,-21], fixed trunk y[-21,12].
Do not reuse this as proof on the dense f6b scene with neighbor overdraw.
"""
import argparse,json
from pathlib import Path
from PIL import Image,ImageChops
p=argparse.ArgumentParser();p.add_argument('states');p.add_argument('--out',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];rows=json.JSONDecoder().raw_decode(Path(a.states).read_text())[0]
base=rows[0];x,y=base['screen']['x'],base['screen']['y'];zoom=base['camera']['zoom'];out=[]
for region,ext in [('crown',[-32,-80,32,-24]),('trunk',[-10,-18,10,9])]:
 box=tuple(round(v) for v in [x+ext[0]*zoom,y+ext[1]*zoom,x+ext[2]*zoom,y+ext[3]*zoom]);im=Image.open(root/base['path']).convert('RGB').crop(box)
 for other in rows[1:-1]:
  assert other['camera']==base['camera'],'Camera drift invalidates pixel comparison'
  diff=ImageChops.difference(im,Image.open(root/other['path']).convert('RGB').crop(box))
  out.append(dict(region=region,box=box,first=base['path'],second=other['path'],changed=sum(any(v) for v in diff.getdata())))
x,y=rows[-2:];diff=ImageChops.difference(Image.open(root/x['path']).convert('RGB'),Image.open(root/y['path']).convert('RGB'))
out.append(dict(region='pausedFullFrame',first=x['path'],second=y['path'],changed=sum(any(v)for v in diff.getdata())))
Path(a.out).write_text(json.dumps(out,indent=2));print(json.dumps(out))
