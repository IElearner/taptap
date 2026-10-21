"""Register independent empty outdoor stations. No stock is baked into props."""
from pathlib import Path
import shutil,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SRC=Path(__file__).parent/'sources/ground-props.png'
OUT=ROOT/'assets/art/pixel-v1/life'
if not SRC.exists():shutil.copyfile('/workspace/generated_images/exec-642f4168-8bc0-46e9-b665-03ef1c4b74d5.png',SRC)
im=Image.open(SRC).convert('RGBA');atlas=Image.new('RGBA',(320,144));entries=[]
specs=[('mill',30,[40,47],[35,51]),('kneading',36,None,[40,52]),('chopping',26,None,[40,51]),('sawhorse',36,None,[40,52]),('forge-anvil',40,[31,53],[53,50]),('scraping',36,None,[42,50]),('empty-rack',36,None,[40,55]),('steps',34,None,[40,52])]
for i,(name,width,device,contact)in enumerate(specs):
    row,col=divmod(i,4);top,bottom=[(380,650),(680,950)][row]
    region=(col*384,top,(col+1)*384,bottom);part=im.crop(region)
    bounds=part.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
    scale=width/(bounds[2]-bounds[0]);anchor=((bounds[0]+bounds[2])/2,bounds[3])
    sprite=part.resize((max(1,round(part.width*scale)),max(1,round(part.height*scale))),Image.Resampling.NEAREST)
    alpha=sprite.getchannel('A').point(lambda v:255 if v>128 else 0)
    sprite=sprite.convert('RGB').quantize(colors=40,dither=Image.Dither.NONE).convert('RGBA');sprite.putalpha(alpha)
    origin=(40-round(anchor[0]*scale),64-round(anchor[1]*scale))
    frame=Image.new('RGBA',(80,72));frame.alpha_composite(sprite,origin);atlas.alpha_composite(frame,(col*80,row*72))
    entries.append({'name':name,'row':row,'frame':col,'source_region':region,'source_anchor':anchor,'scale':scale,'origin':origin,'alpha_bounds':frame.getbbox(),'surfaceCandidate':contact,'deviceCandidate':device,'contact_status':'source pixel candidate; native actor/prop contact required'})
atlas.save(OUT/'ground-props.png')
(OUT/'ground-props-import.json').write_text(json.dumps({'cell':[80,72],'anchor':[40,64],'columns':4,'rows':2,'source':'art-pipeline/pixel-life/sources/ground-props.png','frames':entries,'empty_stock':True},indent=2))
