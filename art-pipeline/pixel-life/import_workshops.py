"""Stage workshop atlas candidates without changing the frozen runtime.

Use --output explicitly during an authorized asset update window to import.
"""
from pathlib import Path
import argparse
import json
import shutil
import statistics
import numpy as np
from PIL import Image

p=argparse.ArgumentParser();p.add_argument('--output',default='/workspace/work/life-v1/workshop-candidates');args=p.parse_args()
OUT=Path(args.output);OUT.mkdir(parents=True,exist_ok=True)
SRC=Path(__file__).parent/'sources'
SPECS={
    'miller':('7dae734b-1295-43d5-bb3a-843d95972bb0',8),
    'baker':('e28202d5-6316-4660-8e3e-2334e2e26663',8),
    'butcher':('1e00e49c-78e5-4d15-b38d-c27f39dd9509',8),
    'carpenter':('af464cbc-e58a-4b2b-8605-8abdd1b0aee6',4),
    'smith':('cfdc1e9c-02be-4e26-814c-9d8ffd6869e4',4),
    'leatherworker':('fb025fd2-45e5-40b5-9650-75d00049da11',4),
}
record={'provider':'OpenAI image_gen original, explicitly approved','atlases':{}}
for name,(source,rows)in SPECS.items():
    dest=SRC/('workshop-'+name+'.png')
    if not dest.exists():shutil.copyfile('/workspace/generated_images/exec-'+source+'.png',dest)
    im=Image.open(dest).convert('RGBA')
    cuts=[round(r*im.height/rows)for r in range(rows+1)]
    if name=='miller':cuts=[0,197,382,553,719,891,1062,1223,1330]
    regions=[]
    for row in range(rows):
        for col in range(4):
            bounds=(round(col*im.width/4),cuts[row],round((col+1)*im.width/4),cuts[row+1])
            cell=im.crop(bounds);mask=np.array(cell.getchannel('A'))>128
            occupied=np.flatnonzero(mask.sum(axis=1)>5)
            top,bottom=int(occupied[0]),int(occupied[-1])+1
            # Head centre is independent of a tool extending to the right.
            head=mask[top:min(bottom,top+round((bottom-top)*.36)),:].sum(axis=0)
            center=float((head*np.arange(len(head))).sum()/max(1,head.sum()))
            dense=mask[:,max(0,round(center-35)):min(cell.width,round(center+35))]
            feet=np.flatnonzero(dense.sum(axis=1)>2)
            foot=int(feet[-1])+1
            regions.append({'row':row,'frame':col,'region':bounds,'anchor':[center,foot],'body_height':foot-top})
    # Reference idle rows establish one scale for each original appearance.
    scales={}
    for look in range(rows//4):
        heights=[r['body_height']for r in regions if r['row']==look*4]
        scales[look]=24/statistics.median(heights)
    atlas=Image.new('RGBA',(320,rows*72))
    for entry in regions:
        cell=im.crop(entry['region']);scale=scales[entry['row']//4]
        sprite=cell.resize((max(1,round(cell.width*scale)),max(1,round(cell.height*scale))),Image.Resampling.NEAREST)
        alpha=sprite.getchannel('A').point(lambda v:255 if v>128 else 0)
        sprite=sprite.convert('RGB').quantize(colors=32,dither=Image.Dither.NONE).convert('RGBA');sprite.putalpha(alpha)
        origin=(40-round(entry['anchor'][0]*scale),64-round(entry['anchor'][1]*scale))
        frame=Image.new('RGBA',(80,72));frame.alpha_composite(sprite,origin)
        atlas.alpha_composite(frame,(entry['frame']*80,entry['row']*72))
        entry.update(scale=scale,origin=origin,alpha_bounds=frame.getbbox())
    atlas.save(OUT/('workshop-'+name+'.png'))
    record['atlases'][name]={'file':'workshop-'+name+'.png','cell':[80,72],'anchor':[40,64],'columns':4,'rowCount':rows,'rows':['idle','prepare','work','finish']*(rows//4),'looks':rows//4,'frames':regions,'status':'candidate; native contact and lifecycle review pending'}
(OUT/'workshop-import.json').write_text(json.dumps(record,indent=2))
