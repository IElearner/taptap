"""Register generated life artwork; nearest-neighbour packing only.

Source art is retained intact. Cell padding is for tools, not larger people.
"""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).parent / 'sources'
OUT = ROOT / 'assets/art/pixel-v1/life'
OUT.mkdir(parents=True, exist_ok=True)
SOURCES = {
    'fisher-actions': '2408ecec-d74c-490e-b934-357e8923a0f4',
    'props': '171edcc1-a7f2-47d8-b1ce-eff3f5d974e3',
    'fisher-ns': 'f6545017-dfd1-4a7d-8835-8cdb535fbe97',
    'coalmine': '05bc38b4-46c6-4488-bf61-4eb1ba452245',
    'ironmine': 'f911fbc0-38c9-425a-9896-a2ed10ac01be',
    'goldmine': 'f9a726cb-9111-4d12-b1ee-fd415fa29e92',
    'mason': '78675529-e4bd-4325-a10f-0b2a5f912ab3',
    'quarry': '5e0706f4-588b-410c-938b-2d3c334b159e',
    'fisher-rocker': '925f58a8-87af-4a42-918e-4d5c0bfd0fab',
    'rocker-empty': 'b9974cb5-202d-4b64-a95a-60a38224a24f',
    'chef-lean': '2d3df6bc-ae33-4f50-854e-3e7c56bfcc0a',
    'fisher-vertical': '2d070dcc-740e-47fb-8ebe-3cd9a87510fd',
}
record = {'provider': 'OpenAI image_gen, user approved', 'atlases': {}, 'buildings': {}}
for name, source in SOURCES.items():
    dest = SRC / (name + '.png')
    if not dest.exists():
        shutil.copyfile('/workspace/generated_images/exec-' + source + '.png', dest)

def crisp(im, scale):
    im = im.resize((max(1, round(im.width*scale)), max(1, round(im.height*scale))), Image.Resampling.NEAREST)
    a = im.getchannel('A').point(lambda v: 255 if v > 128 else 0)
    im = im.convert('RGB').quantize(colors=40, dither=Image.Dither.NONE).convert('RGBA')
    im.putalpha(a)
    return im

def pack(name, spans, scales, rows, actor=False):
    im = Image.open(SRC / (name+'.png')).convert('RGBA')
    atlas = Image.new('RGBA', (320, len(spans)*72))
    entries = []
    for row, (top, bottom) in enumerate(spans):
        for col in range(4):
            region = (round(col*im.width/4), top, round((col+1)*im.width/4), bottom)
            cell = im.crop(region)
            alpha = np.array(cell.getchannel('A')) > 128
            box = cell.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
            if actor:
                # Body occupies the central dense columns; the rod is deliberately
                # excluded when establishing the foot. One scale for the sheet.
                counts = alpha.sum(axis=0)
                dense = np.flatnonzero(counts > max(8, counts.max()*.48))
                center = float(np.median(dense))
                band = alpha[:,max(0,round(center-35)):min(cell.width,round(center+35))]
                occupied = np.flatnonzero(band.sum(axis=1)>3)
                foot = int(occupied[-1])+1
                anchor = (center, foot)
            else:
                anchor = ((box[0]+box[2])/2, box[3])
            scale = scales[row]
            sprite = crisp(cell, scale)
            origin = (40-round(anchor[0]*scale), 64-round(anchor[1]*scale))
            frame = Image.new('RGBA',(80,72)); frame.alpha_composite(sprite,origin)
            atlas.alpha_composite(frame,(col*80,row*72))
            entries.append({'row':row,'frame':col,'source_region':region,'source_anchor':anchor,'scale':scale,'origin':origin,'alpha_bounds':frame.getbbox()})
    atlas.save(OUT/(name+'.png'))
    record['atlases'][name] = {'cell':[80,72],'anchor':[40,64],'columns':4,'rows':rows,'frames':entries,'contact_status':'native review required'}

pack('fisher-actions',[(120,264),(352,518),(576,774),(827,1031),(1124,1274)],[.16]*5,['rest','rise','cast','reel','stow'],True)
pack('fisher-ns',[(35,254),(307,510),(571,765),(803,995),(1049,1247),(1331,1497)],[.145]*6,['cast-N','reel-N','wait-N','cast-S','reel-S','wait-S'],True)
pack('props',[(73,259),(299,485),(516,715),(727,943),(957,1114)],[.14,.14,.14,.16,.16],['rocker','tank-0-1-3-5','cart-empty-miner-stone-gold','rail-and-shaft','cutting-bench'])

# These matched occupied/empty recliners use the SAME global source scale.
# Their floor anchor is the runner, rather than the sleeper's raised shoes.
for name in ['fisher-rocker','rocker-empty']:
    source=Image.open(SRC/(name+'.png')).convert('RGBA')
    atlas=Image.new('RGBA',(320,72)); frames=[]
    for col in range(4):
        region=(round(col*source.width/4),0,round((col+1)*source.width/4),source.height)
        part=source.crop(region)
        bounds=part.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
        scale=.09
        anchor=((bounds[0]+bounds[2])/2,bounds[3])
        sprite=crisp(part,scale);origin=(40-round(anchor[0]*scale),64-round(anchor[1]*scale))
        frame=Image.new('RGBA',(80,72));frame.alpha_composite(sprite,origin)
        atlas.alpha_composite(frame,(col*80,0))
        frames.append({'row':0,'frame':col,'source_region':region,'source_anchor':anchor,'scale':scale,'origin':origin,'alpha_bounds':frame.getbbox()})
    atlas.save(OUT/(name+'.png'))
    record['atlases'][name]={'cell':[80,72],'anchor':[40,64],'columns':4,'rows':['recline-rocking' if name=='fisher-rocker' else 'empty-rocker'],'frames':frames,'contact_status':'occupied contact baked correctly; native placement pending'}

for name in ['mason','quarry','ironmine','coalmine','goldmine']:
    original=Image.open(ROOT/'assets/art/pixel-v1/buildings'/(name+'.png')).convert('RGBA')
    edited=Image.open(SRC/(name+'.png')).convert('RGBA')
    box=edited.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
    target=original.getbbox()
    # Match the retained outer structure's existing registered screen bounds.
    sprite=edited.crop(box).resize((target[2]-target[0],target[3]-target[1]),Image.Resampling.NEAREST)
    sprite=crisp(sprite,1)
    canvas=Image.new('RGBA',original.size);canvas.alpha_composite(sprite,target[:2])
    canvas.save(OUT/(name+'.png'))
    record['buildings'][name]={'canvas':[256,224],'anchor':[192,176],'source_bounds':box,'registered_bounds':target,'registration':'outer structure bounds, native door contact pending'}

source=Image.open(SRC/'chef-lean.png').convert('RGBA')
parts=[source.crop((round(c*source.width/4),0,round((c+1)*source.width/4),source.height))for c in range(4)]
boxes=[p.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()for p in parts]
scale=24/max(b[3]-b[1]for b in boxes)
atlas=Image.new('RGBA',(160,48));frames=[]
for col,(part,box)in enumerate(zip(parts,boxes)):
    # Crossed ankles establish a stable floor contact, while the upper body
    # and shoulder remain inclined toward the kitchen wall.
    anchor=((box[0]+box[2])/2,box[3]);sprite=crisp(part,scale)
    origin=(20-round(anchor[0]*scale),44-round(anchor[1]*scale))
    frame=Image.new('RGBA',(40,48));frame.alpha_composite(sprite,origin)
    atlas.alpha_composite(frame,(col*40,0))
    frames.append({'row':0,'frame':col,'scale':scale,'origin':origin,'source_anchor':anchor,'alpha_bounds':frame.getbbox()})
atlas.save(OUT/'chef-lean.png')
record['atlases']['chef-lean']={'cell':[40,48],'anchor':[20,44],'columns':4,'rows':['idle-lean'],'frames':frames,'contact_status':'shoulder wall contact requires native placement'}

source=Image.open(SRC/'fisher-vertical.png').convert('RGBA')
atlas=Image.new('RGBA',(320,768));frames=[]
for row,(top,bottom)in enumerate([(20,254),(299,517),(552,763),(810,1032),(1081,1259),(1321,1501)]):
    for col in range(4):
        region=(col*256,top,(col+1)*256,bottom)
        part=source.crop(region);mask=np.array(part.getchannel('A'))>128
        weights=mask.sum(axis=1)
        # A dangling hook below the boots must not become the foot anchor.
        bodyrows=np.flatnonzero(weights>max(weights)*.44)
        bodytop,foot=int(bodyrows[0]),int(bodyrows[-1])+1
        core=mask[bodytop:foot,:].sum(axis=0)
        dense=np.flatnonzero(core>max(core)*.5)
        anchor=(float(np.median(dense)),foot)
        scale=.24;sprite=crisp(part,scale)
        origin=(40-round(anchor[0]*scale),64-round(anchor[1]*scale))
        frame=Image.new('RGBA',(80,128));frame.alpha_composite(sprite,origin)
        atlas.alpha_composite(frame,(col*80,row*128))
        frames.append({'row':row,'frame':col,'source_region':region,'source_anchor':anchor,'scale':scale,'origin':origin,'alpha_bounds':frame.getbbox()})
atlas.save(OUT/'fisher-vertical.png')
record['atlases']['fisher-vertical']={'cell':[80,128],'anchor':[40,64],'columns':4,'rows':['cast-N','reel-N','wait-N','cast-S','reel-S','wait-S'],'frames':frames,'contact_status':'real bank-edge/hook alignment pending native'}

(OUT/'life-import.json').write_text(json.dumps(record,indent=2))
(Path(__file__).parent/'import-records.json').write_text(json.dumps(record,indent=2))
