"""Author the village's original mesh library and export through Maker's Blender exporter.

Run: blender --background --python dev/create_village_models.py
All dimensions are game metres (X/right, Y/up, Z/back). No image billboards.
"""
import bpy, math, sys, importlib.util, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/model/village-v3'
PREFIX='model/village-v3'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
MATS={}
AUTHORED={}
COLORS={
 'Wood':((.72,.56,.37),'wood'), 'DarkWood':((.40,.31,.22),'wood'),
 'PaleWood':((.90,.79,.59),'wood'), 'Roof':((.73,.80,.86),'roof'),
 'Plaster':((.98,.94,.82),'plaster'), 'Stone':((.85,.85,.79),'stone'),
 'Earth':((.47,.36,.22),None),'Grain':((.73,.52,.20),None),
 'Wheat':((.83,.64,.25),None),'Leaf':((.34,.46,.20),None),
 'Skin':((.69,.47,.31),None),'Hair':((.12,.095,.07),None),'GreyHair':((.46,.44,.37),None),
 'Ivory':((.84,.80,.67),None),'Indigo':((.20,.29,.38),'cloth'),
 'Ochre':((.59,.40,.20),'cloth'),'Grey':((.40,.38,.32),'cloth'),
 'Green':((.26,.37,.26),'cloth'),'Russet':((.43,.23,.14),'cloth'),
 'Pants':((.17,.18,.16),'cloth'),'Leather':((.22,.15,.10),None),
 'Iron':((.23,.26,.25),None),'Red':((.48,.15,.10),'cloth'),
 'Pig':((.56,.38,.28),None),'Bowl':((.62,.64,.55),None)}
for name,(rgb,style) in COLORS.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=.88
 MATS[name]=m

class Mesh:
 def __init__(self):self.v=[];self.f=[];self.mi=[];self.uv=[];self.smooth=[]
 def face(self,points,mat,uv=None,smooth=False):
  n=len(self.v);self.v.extend(points);self.f.append(tuple(range(n,n+len(points))))
  self.mi.append(list(MATS).index(mat));self.uv.append(uv or [(0,0),(1,0),(1,1),(0,1)][:len(points)]);self.smooth.append(smooth)
 def box(self,center,size,mat):
  x,y,z=center;a,b,c=[v/2 for v in size]
  vs=[(x+i*a,y+j*b,z+k*c) for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
  for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]:self.face([vs[i] for i in ids],mat)
 def beam(self,a,b,r,mat,segments=6,r2=None):
  a,b=Vector(a),Vector(b);d=(b-a).normalized();u=d.cross(Vector((0,0,1)))
  if u.length<.1:u=d.cross(Vector((1,0,0)))
  u.normalize();v=d.cross(u).normalized();r2=r if r2 is None else r2
  rings=[[tuple(p+u*math.cos(i*2*math.pi/segments)*rr+v*math.sin(i*2*math.pi/segments)*rr) for i in range(segments)] for p,rr in [(a,r),(b,r2)]]
  for i in range(segments):
   j=(i+1)%segments;self.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],mat,[(i/segments,0),(j/segments,0),(j/segments,1),(i/segments,1)],segments>8)
  for ring,reverse in [(rings[0],True),(rings[1],False)]:
   for i in range(1,segments-1):
    ids=[0,i+1,i] if reverse else [0,i,i+1];self.face([ring[k] for k in ids],mat,[(0,0),(1,0),(1,1)])
 def ellipsoid(self,c,s,mat,n=12,rings=8):
  x,y,z=c;rx,ry,rz=s
  for j in range(rings):
   for i in range(n):
    ps=[];uv=[]
    for ii,jj in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]:
     t=2*math.pi*ii/n;p=math.pi*(jj+.001)/(rings+.002)
     ps.append((x+rx*math.sin(p)*math.cos(t),y+ry*math.cos(p),z+rz*math.sin(p)*math.sin(t)));uv.append((ii/n,jj/rings))
    self.face(ps,mat,uv,True)
 def loft(self,rings,mat,n=16,fold=.0):
  # y, half-width, half-depth, forward offset; folded cloth is actual relief.
  for j in range(len(rings)-1):
   for i in range(n):
    ps=[]
    for ii,jj in [(i,j),(i,j+1),(i+1,j+1),(i+1,j)]:
     y,rx,rz,z=rings[jj];a=ii*2*math.pi/n;f=1+fold*math.cos(a*8+jj*.9)
     ps.append((math.cos(a)*rx*f,y,math.sin(a)*rz*f+z))
    uv=[(i/n,j/(len(rings)-1)),(i/n,(j+1)/(len(rings)-1)),((i+1)/n,(j+1)/(len(rings)-1)),((i+1)/n,j/(len(rings)-1))]
    if rings[j+1][0]<rings[j][0]:ps.reverse();uv.reverse()
    self.face(ps,mat,uv,True)
 def object(self,name):
  AUTHORED[name]=self
  mesh=bpy.data.meshes.new(name)
  # Maker's exporter converts Blender XYZ to game YZX.
  mesh.from_pydata([(z,x,y) for x,y,z in self.v],[],self.f);mesh.update()
  for mat in MATS.values():mesh.materials.append(mat)
  layer=mesh.uv_layers.new(name='UVMap')
  for p,mi,coords,smooth in zip(mesh.polygons,self.mi,self.uv,self.smooth):
   p.material_index=mi;p.use_smooth=smooth
   for i,loop in enumerate(p.loop_indices):layer.data[loop].uv=coords[i%len(coords)]
  ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
  weld=ob.modifiers.new('Join continuous sculpted surfaces','WELD');weld.merge_threshold=.000001
  return ob

def plinth(m,x,z,w,d):
 m.box((x,.055,z),(w,.11,d),'Stone')
 # Staggered stone base courses, without dozens of scene objects.
 for side in [-1,1]:
  for i in range(max(2,int(w/.3))):
   xx=x-w/2+(i+.5)*w/max(2,int(w/.3));m.box((xx,.10,z+side*(d/2-.018)),(w/max(2,int(w/.3))-.016,.10,.055),'Stone')

def roof(m,x,z,w,d,eave,rise,stage=1):
 # Curved Chinese gable surface with lifted eave tips, bounded inside the plot.
 for side in [-1,1]:
  count=max(1,int(12*stage));nx=max(6,int(w/.12))
  def point(u,v):
   tip=.055*(abs(u*2-1)**8)
   return (x+(u-.5)*w,eave+rise*(1-v)**1.45+.045*v**8+tip,z+side*v*d/2)
  for j in range(count):
   for i in range(nx):
    u0,u1=i/nx,(i+1)/nx;v0,v1=j/12,(j+1)/12
    p=[point(u0,v0),point(u1,v0),point(u1,v1),point(u0,v1)]
    if side==1:p.reverse()
    m.face(p,'Roof',[(u0*5,v0*3),(u1*5,v0*3),(u1*5,v1*3),(u0*5,v1*3)])
   # Tile course lip and border really cast a narrow shadow.
   a=point(0,(j+1)/12);b=point(1,(j+1)/12);m.beam(a,b,.012,'Roof',6)
  for i in range(nx+1):
   u=i/nx
   for j in range(0,count,2):
    a=point(u,j/12);b=point(u,min(count,j+2)/12)
    m.beam(a,b,.012,'Roof',6)
  for end in [0,1]:
   for j in range(count):m.beam(point(end,j/12),point(end,(j+1)/12),.025,'DarkWood',6)
 m.beam((x-w/2,eave+rise+.025,z),(x+w/2,eave+rise+.025,z),.038,'Roof',10)
 for side in [-1,1]:
  m.beam((x+side*w/2,eave+rise+.02,z),(x+side*(w/2+.035),eave+rise+.12,z),.023,'Roof',8)

def windows(m,x,z,w,level=.57):
 m.box((x,level,z),(w,.30,.035),'DarkWood')
 for dx in [-w/2,w/2]:m.box((x+dx,level,z-.018),(.025,.34,.035),'PaleWood')
 for yy in [level-.17,level,level+.17]:m.box((x,yy,z-.025),(w+.05,.025,.035),'PaleWood')
 for i in range(1,5):m.box((x-w/2+i*w/5,level,z-.035),(.012,.30,.025),'Wood')

def hall(m,x,z,w,d,phase,door=None,open_front=False,loft=False,cutaway=False):
 plinth(m,x,z,w,d)
 if phase==0:return
 wall_h=1.05 if loft else .87
 bays=max(2,round(w/.75));xs=[x-w/2+i*w/bays for i in range(bays+1)]
 for xx in xs:
  for zz in [z-d/2,z+d/2]:
   if cutaway and zz<z:continue
   m.box((xx,.12+wall_h/2,zz),(.065,wall_h,.065),'DarkWood')
   m.box((xx,.13,zz),(.095,.065,.095),'Stone')
 for zz in [z-d/2,z+d/2]:
  if cutaway and zz<z:continue
  m.box((x,.12+wall_h,zz),(w+.08,.075,.09),'DarkWood')
  for xx in xs[1:-1]:
   m.beam((xx-.16,.12+wall_h,zz),(xx,.12+wall_h-.19,zz),.025,'Wood',4)
 if phase>=2:
  m.box((x,.12+wall_h/2,z+d/2),(w-.05,wall_h-.05,.055),'Plaster')
  for side in [-1,1]:m.box((x+side*w/2,.12+wall_h/2,z),(.055,wall_h-.04,d),'Plaster')
  for a,b in zip(xs[:-1],xs[1:]):
   cx=(a+b)/2
   is_door=door is not None and a<=door<=b
   if not open_front and not is_door:
    m.box((cx,.12+wall_h/2,z-d/2),((b-a)-.055,wall_h-.05,.055),'Plaster')
    windows(m,cx,z-d/2-.035,min(.35,b-a-.15),.59)
   if not open_front:
    m.box((cx,.35,z-d/2-.035),(b-a,.035,.04),'DarkWood')
  if door is not None:
   m.box((door,.48,z-d/2+.018),(.37,.70,.025),'Hair')
   for side in [-1,1]:m.box((door+side*.195,.49,z-d/2-.03),(.04,.75,.07),'DarkWood')
   # Open leaves leave a real passage instead of a closed image under the actor.
   for side in [-1,1]:m.box((door+side*.17,.47,z-d/2-.07),(.045,.66,.18),'Wood')
   m.box((door,.88,z-d/2-.04),(.46,.07,.095),'DarkWood')
   for i in range(2):m.box((door,.08-i*.035,z-d/2-.11-i*.10),(.51+i*.09,.06,.19),'Stone')
 if phase>=1 and not cutaway:
  for xx in [x-w/2,x,x+w/2]:
   for side in [-1,1]:
    for j in range(6):
     a,b=j/6,(j+1)/6
     m.beam((xx,.12+wall_h+.39*(1-a)**1.45-.04,z+side*a*d/2),
            (xx,.12+wall_h+.39*(1-b)**1.45-.04,z+side*b*d/2),.022,'Wood',6)
  m.box((x,.12+wall_h+.39,z),(w,.055,.055),'DarkWood')
 if phase>=3:
  roof(m,x,z,w+.10,d+.12,.12+wall_h,.39,.5 if phase==3 else 1)
  if phase>=4:
   for side in [-1,1]:
    xx=x+side*w/2
    m.face([(xx,.12+wall_h,z-d/2),(xx,.12+wall_h+.35,z),(xx,.12+wall_h,z+d/2)],'Plaster',[(0,0),(.5,1),(1,0)])
    for k in [-1,0,1]:m.box((xx,.12+wall_h+.13,z+k*d*.16),(.035,.23,.025),'DarkWood')

def fence(m,x,z,w,d):
 for side in [-1,1]:
  for i in range(int(w/.3)+1):m.beam((x-w/2+i*w/int(w/.3),.08,z+side*d/2),(x-w/2+i*w/int(w/.3),.39,z+side*d/2),.025,'Wood',5)
  for y in [.21,.34]:m.box((x,y,z+side*d/2),(w,.035,.035),'PaleWood')
  for i in range(int(d/.3)+1):m.beam((x+side*w/2,.08,z-d/2+i*d/int(d/.3)),(x+side*w/2,.39,z-d/2+i*d/int(d/.3)),.025,'Wood',5)
  for y in [.21,.34]:m.box((x+side*w/2,y,z),(.035,.035,d),'PaleWood')

def barrel(m,x,z):
 m.loft([(.12,.10,.10,z),(.16,.12,.12,z),(.35,.12,.12,z),(.40,.10,.10,z)],'Wood',12)
 # loft is centered on zero x; translate this new component if needed by using beam.
 for y in [.17,.35]:m.beam((x,y-.009,z),(x,y+.009,z),.123,'Iron',12)

SIZES={'store':(2,2),'house':(3,2),'mill':(2,3),'kitchen':(3,2),'woodcutter':(3,2),'quarry':(3,2),'courier':(3,2),'barracks':(3,3),'butcher':(3,2),'ranch':(3,2)}
def building(kind,phase,opened=False):
 m=Mesh();w,d=SIZES[kind];w-=.26;d-=.26;door=(SIZES[kind][0]-1)/2
 if kind=='courier':
  hall(m,-.5,0,w-1,d,phase,door=None)
  m.object(f'courier_main_{phase}');m=Mesh()
  plinth(m,1,-.5,.78,.78)
  if phase>0:
   for xx in [.67,1.33]:m.box((xx,.51,-.82),(.055,.92,.055),'DarkWood')
  if phase>=3:roof(m,1,-.5,.86,.86,.94,.16,.5 if phase==3 else 1)
 elif kind=='barracks':
  plinth(m,0,0,w,d)
  hall(m,0,.78,w,.68,phase,None)
  for xx in [-1.03,1.03]:hall(m,xx,-.62,.63,.88,phase,None,loft=True)
  if phase>=2:
   for xx in [-.85,.85]:m.box((xx,.30,-1.27),(.50,.35,.07),'Stone')
   m.box((0,.13,-1.30),(1.18,.08,.18),'Stone')
   for i in range(3):m.beam((-.7+i*.20,.13,.10),(-.7+i*.20,.70,.10),.014,'Wood',6)
  if phase>=4:
   m.beam((1.02,1.05,-.62),(1.02,1.80,-.62),.018,'Wood',6)
   m.box((1.15,1.64,-.62),(.24,.21,.015),'Red')
 elif kind=='ranch':
  m.box((0,.045,0),(w,.07,d),'Earth')
  if phase>0:fence(m,0,0,w,d)
  if phase>=2:hall(m,-.71,.40,.95,.65,phase,None,True)
  if phase>=4:
   for xx,zz in [(.3,-.15),(.92,.30)]:
    m.ellipsoid((xx,.27,zz),(.25,.15,.14),'Pig');m.ellipsoid((xx+.23,.27,zz),(.13,.11,.11),'Pig')
    m.ellipsoid((xx+.32,.26,zz),(.04,.06,.07),'Skin')
    for s in [-1,1]:
     m.beam((xx+s*.14,.23,zz-.09),(xx+s*.14,.08,zz-.09),.031,'Pig',7)
     m.beam((xx+s*.14,.23,zz+.09),(xx+s*.14,.08,zz+.09),.031,'Pig',7)
     m.ellipsoid((xx+.22,.37,zz+s*.07),(.065,.055,.022),'Pig')
 elif kind=='woodcutter':
  plinth(m,0,0,w,d);hall(m,0,.31,w,d-.64,phase,None,True)
  if phase>=2:
   for row in range(2):
    for i in range(4-row):m.beam((-.96+i*.18+row*.09,.16+row*.15,-.75),(-.96+i*.18+row*.09,.16+row*.15,.20),.079,'Wood',10)
   m.box((.65,.36,-.41),(.70,.07,.33),'Wood')
   for xx in [.38,.92]:m.box((xx,.23,-.41),(.06,.36,.29),'DarkWood')
 elif kind=='quarry':
  plinth(m,0,0,w,d);hall(m,-.78,.16,1.00,1.23,phase,None,True)
  if phase>=2:
   for i in range(7):
    xx=.03+(i%3)*.36;zz=-.50+(i//3)*.35
    m.box((xx,.18+(i%2)*.08,zz),(.29,.30+(i%2)*.13,.28),'Stone')
   m.beam((.73,.10,.54),(.73,1.39,.54),.055,'DarkWood',6)
   m.beam((.18,1.35,.54),(1.13,1.35,.54),.04,'DarkWood',6)
   m.beam((.73,.65,.54),(1.08,1.35,.54),.025,'Wood',6)
   m.beam((.22,1.35,.54),(.22,.58,.54),.008,'Leather',6)
 else:
  front_open=kind in ['kitchen','butcher']
  hall(m,.22 if kind=='mill' else 0,.12,w-.44 if kind=='mill' else w,d-.23,phase,door if not front_open else None,front_open,kind=='store')
  if kind=='kitchen' and opened:
   # Regenerate the hall without its roof/front wall to expose the real seats.
   m=Mesh();hall(m,0,.12,w,d-.23,min(phase,2),None,True,cutaway=True)
  if kind in ['kitchen','butcher'] and phase>=2:
   m.box((-1.06,.45,.30),(.35,.66,.50),'Stone')
   m.beam((-1.05,.78,.48),(-1.05,1.65,.48),.085,'Stone',8)
   if phase>=4 and not opened:
    for xx in [-.77,.77]:m.box((xx,.48,-.83),(.045,.80,.045),'DarkWood')
    roof(m,0,-.68,1.65,.46,.92,.08)
  if kind=='kitchen' and phase>=2:
   # Dining coordinates intentionally match Meals.seatPosition, in ground units.
   m.box((0,.39,0),(.51,.055,1.10),'Wood')
   for xx in [-.47,.47]:
    for zz in [-.36,.36]:
     m.box((xx,.20,zz),(.23,.055,.23),'DarkWood')
     for dx in [-.075,.075]:
      for dz in [-.075,.075]:m.box((xx+dx,.10,zz+dz),(.025,.19,.025),'Wood')
     m.beam((xx*.35,.43,zz),(xx*.35,.47,zz),.052,'Bowl',12)
  if kind=='butcher' and phase>=2:
   m.box((.22,.42,-.58),(1.25,.065,.34),'Wood')
   for xx in [-.25,.72]:m.box((xx,.23,-.58),(.07,.38,.26),'DarkWood')
   for i in range(4):m.ellipsoid((-.25+i*.27,.72,-.55),(.06,.14,.04),'Russet')
  if kind in ['store','house'] and phase>=4:
   for i in range(3 if kind=='store' else 1):
    xx=-w/2+.20+i*.27;m.ellipsoid((xx,.24,-d/2-.02),(.11,.17,.11),'Grain')
   m.beam((door-.27,.95,-d/2),(door-.27,.79,-d/2),.008,'Iron',5)
   m.ellipsoid((door-.27,.74,-d/2),(.045,.075,.045),'Ochre')
  if kind=='mill' and phase>=2:
   m.beam((.38,.19,-1.04),(.38,.36,-1.04),.21,'Stone',18)
 if phase in [1,2,3] and kind!='courier':
  # Real scaffold poles, cross bracing and a small ladder during work.
  for xx in [-w/2+.04,w/2-.04]:
   for zz in [-d/2+.04,d/2-.04]:m.beam((xx,.10,zz),(xx,1.44,zz),.018,'PaleWood',6)
  for y in [.55,1.18]:m.box((0,y,-d/2+.02),(w,.035,.035),'PaleWood')
  m.beam((-w/2+.04,.20,-d/2+.01),(w/2-.04,1.18,-d/2+.01),.014,'PaleWood',6)
  for xx in [-.30,-.08]:m.beam((xx,.13,-d/2-.03),(xx,1.34,-d/2+.18),.018,'Wood',6)
  for i in range(6):m.box((-.19,.23+i*.17,-d/2+.012+i*.03),(.24,.018,.025),'PaleWood')
 m.object(f'{kind}_{"open" if opened else phase}')

for kind in SIZES:
 for phase in range(5):building(kind,phase)
building('kitchen',4,True)

# Field plants: actual bent stems, blade silhouettes and grain ears.
for stage,height in [('seed',.015),('sprout',.075),('green',.20),('ripe',.32)]:
 m=Mesh();m.box((0,.04,0),(1.73,.06,1.73),'Earth')
 for row in range(9):
  zz=-.75+row*.18;m.box((0,.078,zz),(1.66,.018,.035),'Earth')
  for col in range(13):
   xx=-.78+col*.13;lean=math.sin(row*11+col*3)*.028
   color='Wheat' if stage=='ripe' else 'Leaf'
   if stage=='seed':continue
   m.beam((xx,.08,zz),(xx+lean,.08+height,zz),.004,color,4)
   for side in [-1,1]:
    m.face([(xx,.09+height*.25,zz),(xx+side*.055,.08+height*.65,zz-.014),(xx+lean,.08+height*.55,zz)],color,[(0,0),(1,1),(0,1)])
   if stage=='ripe':
    for j in range(3):
     for sign in [-1,1]:m.ellipsoid((xx+lean+sign*.010,.08+height+j*.013,zz),(.012,.020,.009),'Wheat',6,4)
 m.object('field_'+stage)

# Hollow, open-spoke water wheel, independent rotating part.
m=Mesh()
for sign in [-1,1]:
 for i in range(24):
  a,b=i*math.tau/24,(i+1)*math.tau/24
  m.beam((sign*.105,.46*math.cos(a),.46*math.sin(a)),(sign*.105,.46*math.cos(b),.46*math.sin(b)),.033,'DarkWood',6)
for i in range(10):
 a=i*math.tau/10;y,z=.43*math.cos(a),.43*math.sin(a)
 m.box((0,y,z),(.29,.065,.12),'Wood')
 m.beam((-.10,0,0),(-.10,y,z),.022,'Wood',6);m.beam((.10,0,0),(.10,y,z),.022,'Wood',6)
m.beam((-.23,0,0),(.23,0,0),.055,'Iron',10);m.object('waterwheel')

def person(profile,color,female=False,elder=False,chef=False,butcher=False,guard=False):
 # Separate sculpted surfaces, authored relative to the real joint pivots.
 m=Mesh();m.loft([(-.13,.078,.050,0),(-.10,.080,.051,0),(-.03,.067,.045,0),(.035,.089,.046,0),(.09,.082,.041,0),(.115,.040,.030,0)],color,24,.055)
 # Cross-collar and waist sash have folded geometry, not a painted symbol.
 m.beam((-.055,.10,.038),(.040,-.025,.057),.010,'Ivory',5)
 m.beam((.052,.10,.038),(-.025,.025,.056),.010,'Ivory',5)
 m.loft([(-.095,.081,.053,0),(-.075,.079,.053,0)],'Leather',24)
 if female:
  m.loft([(-.19,.10,.067,0),(-.17,.098,.066,0),(-.10,.078,.053,0)],color,24,.06)
 if chef or butcher:
  m.box((0,-.055,.057),(.115,.22,.008),'Indigo' if chef else 'Leather')
  m.beam((-.048,.08,.043),(-.046,-.08,.061),.006,'Ivory',5)
 if guard:
  for row in range(5):
   for col in range(5):m.box((-.060+col*.03,-.070+row*.033,.051),(.026,.028,.014),'Iron')
 m.object(profile+'_torso')
 m=Mesh();m.ellipsoid((0,0,0),(.039,.053,.037),'Skin',16,12)
 # Cheek/jaw, brow, nose bridge, ears, lips and hair cap.
 m.ellipsoid((0,-.026,.012),(.029,.025,.025),'Skin',12,8)
 m.ellipsoid((0,.005,.034),(.008,.014,.010),'Skin',10,8)
 m.ellipsoid((0,-.004,.041),(.009,.006,.007),'Skin',10,6)
 for sign in [-1,1]:
  m.ellipsoid((sign*.040,0,0),(.008,.014,.007),'Skin',8,6)
  m.ellipsoid((sign*.015,.014,.032),(.007,.0025,.003),'Hair',8,4)
  m.beam((sign*.008,.024,.032),(sign*.023,.022,.030),.002,'GreyHair' if elder else 'Hair',6)
 m.beam((-.009,-.020,.034),(.009,-.020,.034),.0018,'Russet',6)
 hair='GreyHair' if elder else 'Hair'
 m.ellipsoid((0,.034,-.006),(.042,.027,.037),hair,16,8)
 if female:
  m.ellipsoid((0,.035,-.039),(.021,.022,.020),hair,12,8)
  for i in range(6):m.ellipsoid((.006*math.sin(i*2),.01-i*.015,-.035),(.009,.012,.010),hair,8,6)
 elif elder:
  m.loft([(-.09,.004,.008,.024),(-.055,.020,.015,.026),(-.032,.025,.019,.026)],'GreyHair',14,.05)
 elif chef:
  m.loft([(.030,.044,.038,0),(.050,.045,.038,0),(.075,.030,.028,0)],'Ivory',20,.035)
 elif guard:
  m.ellipsoid((0,.041,-.005),(.046,.030,.043),'Iron',14,8)
  m.beam((0,.045,-.032),(0,.10,-.020),.006,'Red',6)
 elif profile=='blue-man':
  m.loft([(.047,.087,.076,0),(.052,.088,.077,0),(.092,.015,.013,0)],'PaleWood',24,.018)
 else:m.loft([(.032,.042,.037,0),(.060,.037,.034,0),(.068,.012,.015,0)],hair,18)
 m.object(profile+'_head')
 for part,rings,mat in [
  ('upperarm',[(0,.027,.027,0),(-.045,.032,.030,0),(-.085,.026,.025,0),(-.125,.022,.022,0)],color),
  ('forearm',[(0,.020,.020,0),(-.035,.019,.019,0),(-.095,.013,.014,0)],'Skin'),
  ('thigh',[(0,.033,.035,0),(-.04,.036,.034,0),(-.10,.032,.031,0),(-.155,.024,.026,0)],'Pants'),
  ('shin',[(0,.024,.025,0),(-.04,.023,.024,0),(-.09,.019,.021,0),(-.135,.016,.018,0)],'Pants')]:
  m=Mesh();m.loft(rings,mat,16,.06 if mat!='Skin' else .01)
  if part=='shin':
   for i in range(3):m.loft([(-.114+i*.012,.020,.022,0),(-.111+i*.012,.020,.022,0)],'Grey',16)
   m.ellipsoid((0,-.143,.014),(.024,.021,.041),'Leather',12,8)
  if part=='forearm':
   m.ellipsoid((0,-.11,.004),(.017,.023,.012),'Skin',10,8)
   m.ellipsoid((.015,-.106,.010),(.008,.014,.007),'Skin',8,6)
   for i in range(3):m.beam((-.010+i*.008,-.12,.011),(-.010+i*.008,-.133,.012),.003,'Skin',6)
  m.object(profile+'_'+part)

for args in [('blue-man','Indigo'),('ochre-woman','Ochre',True),('grey-elder','Grey',False,True),('green-woman','Green',True),('chef','Ivory',True,False,True),('butcher','Russet',False,False,False,True),('guard-man','Indigo',False,False,False,False,True),('guard-woman','Indigo',True,False,False,False,True),('bandit','Russet')]:person(*args)

for kind in ['hammer','axe','hoe','sickle','watering','bowl','chopsticks']:
 m=Mesh()
 if kind in ['hammer','axe','hoe','sickle']:
  end=-.43 if kind=='hoe' else -.31
  m.beam((0,-.08,0),(0,end,0),.010,'Wood',8)
  if kind=='hammer':m.box((0,-.30,0),(.12,.045,.045),'Iron')
  if kind=='hoe':m.box((0,-.43,.040),(.13,.015,.10),'Iron')
  if kind=='axe':
   m.face([(-.017,-.28,0),(.10,-.25,0),(.11,-.34,0),(-.017,-.32,0)],'Iron')
   m.face([(-.017,-.32,.012),(.11,-.34,.012),(.10,-.25,.012),(-.017,-.28,.012)],'Iron')
  if kind=='sickle':
   for i in range(9):
    a,b=i*math.pi/10,(i+1)*math.pi/10
    m.beam((.065-.065*math.cos(a),-.31-.065*math.sin(a),0),(.065-.065*math.cos(b),-.31-.065*math.sin(b),0),.005,'Iron',5)
 elif kind=='watering':
  m.ellipsoid((0,-.17,.025),(.057,.065,.054),'Russet',14,10)
  m.beam((.04,-.17,.025),(.12,-.11,.025),.012,'Russet',8)
  m.beam((.12,-.11,.025),(.14,-.12,.025),.018,'Iron',8)
  for i in range(8):
   a,b=i*math.tau/8,(i+1)*math.tau/8
   m.beam((-.057,.035*math.sin(a)-.16,.035*math.cos(a)+.025),(-.057,.035*math.sin(b)-.16,.035*math.cos(b)+.025),.005,'Russet',6)
 elif kind=='bowl':
  m.loft([(-.15,.023,.023,.025),(-.12,.040,.040,.025),(-.116,.041,.041,.025)],'Bowl',16)
  m.ellipsoid((0,-.115,.025),(.035,.004,.035),'Ivory',12,6)
 else:
  for x in [-.006,.006]:m.beam((x,-.12,.012),(x,-.22,.046),.002,'Wood',6)
 m.object('tool_'+kind)

# A cutaway is useful only if its frame/awning cannot hide any seated head.
from mathutils.bvhtree import BVHTree
open_hall=AUTHORED['kitchen_open']
bvh=BVHTree.FromPolygons([Vector(v) for v in open_hall.v],open_hall.f,all_triangles=False)
for x in [-.47,.47]:
 for z in [-.36,.36]:
  hit=bvh.ray_cast(Vector((x,.62,z)),Vector((0,30,-math.sqrt(700))).normalized(),10)
  assert hit[0] is None, f'Open dining hall hides a seated head at {x},{z}: {hit[0]}'

OUT.mkdir(parents=True,exist_ok=True)
source=ROOT/'art-source/v3';source.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'village-models.blend'))
spec=importlib.util.spec_from_file_location('maker_exporter',ROOT/'.cli/blend_to_urhox.py')
export=importlib.util.module_from_spec(spec);sys.modules[spec.name]=export;spec.loader.exec_module(export)
args=export.parse_args(['--out-dir',str(OUT),'--scene-id','VillageV3','--resource-prefix',PREFIX,'--no-cameras','--no-lights'])
writer=export.UrhoXExporter(args)
result=writer.run()
if result:raise RuntimeError('Maker model export failed')
records={}
for obj,record in writer.mesh_exports.items():
 refs=record.material_refs
 records[obj.name]={'model':record.model_ref,'materials':refs}
styles={}
for record in writer.material_cache.values():
 name=record.info.name
 styles[record.resource_ref]={'name':name,'style':COLORS[name][1] if name in COLORS else None,'color':list(COLORS[name][0]) if name in COLORS else [1,1,1]}
def lua(v):
 if v is None:return 'nil'
 if isinstance(v,str):return json.dumps(v)
 if isinstance(v,(int,float)):return str(v)
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
 raise ValueError(v)
(ROOT/'scripts/game/VillageModelsManifest.lua').write_text('-- Generated by dev/create_village_models.py; do not edit resource names.\nreturn '+lua({'models':records,'materials':styles})+'\n')
print('VILLAGE_EXPORT_COMPLETE',len(records),'meshes',len(styles),'materials')
