-- Pending schema11 compound contract. Run only after production freeze.
-- Controlled materials/completion; actual canBuild/build/site/path/save APIs.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local run=C.runName('compound-model');local records={};local finished=false
local task=coroutine.create(function()
 for _,kind in ipairs(C.kinds)do
  local s=C.new();local before={wood=s.stock.wood,stone=s.stock.stone};local b,planned=C.add(s,kind);local site=b.site
  V.assert(site and site.compound and site.compound.version==1,kind..' is a real new compound')
  assert(site and site.compound,'compound prerequisite: '..kind)
  V.assert(C.same(site,planned),kind..' build uses the exact preview site')
  local bounds=site.compound.bounds
  V.assert(type(bounds)=='table'and #bounds==4 and bounds[1]<bounds[3]and bounds[2]<bounds[4],kind..' has finite relative pixel bounds')
  V.assert(site.compound.ground=='wood'or site.compound.ground=='stone'or site.compound.ground=='earth',kind..' declares one supported compound ground')
  V.assert(site.door.x==b.x and site.door.y==b.y+1,kind..' public road door remains unchanged')
  local seen,unique,doorClear={},true,true
  for _,p in ipairs(site.yardCells)do
   local k=C.key(p.x,p.y);if seen[k]then unique=false end;seen[k]=true
   if k==C.key(b.x,b.y+1)then doorClear=false end
   V.assert(p.x==math.floor(p.x)and p.y==math.floor(p.y)and H.Sites.owner(s,p.x,p.y)==b,kind..' rounded yard has real ownership')
   V.assert(not s:canBuild('road',p.x,p.y),kind..' reserved compound rejects a road through equipment')
  end
  V.assert(unique and doorClear,kind..' no duplicate yard keys or claimed public door')
  local points={};local bounded,reachable=true,true
  for _,v in ipairs(C.points(site))do
   local p=v.p;local px,py=(p.x-b.x)*64,(p.y-b.y)*48
   -- The actual shore is a resource excursion; it need not lie under the patio.
   if v.name~='shoreCell'and(px<bounds[1]or px>bounds[3]or py<bounds[2]or py>bounds[4])then bounded=false end
   local blocked={};for _,cell in ipairs(H.D.cells(b))do blocked[C.key(b.x+cell.x,b.y+cell.y)]=true end
   if not H.Sites.path(s,b.x,b.y+1,p.x,p.y,b,blocked)then reachable=false end
   points[#points+1]={name=v.name,x=p.x,y=p.y,rounded=C.key(p.x,p.y)}
  end
  V.assert(bounded and reachable,kind..' actual fixed work/storage/rest points belong to its compound and remain reachable')
  local cost=H.D.buildings[kind].cost
  V.assert(s.stock.wood==before.wood-(cost.wood or 0)and s.stock.stone==before.stone-(cost.stone or 0),kind..' pays structure cost once; compound supplies no stock')
  if kind=='quarry'or kind=='ironmine'or kind=='coalmine'or kind=='goldmine'then
   local rail=site.railRoute;local dx,dy=C.Layout.door(b)
   V.assert(type(rail)=='table'and #rail>=2,kind..' owns an actual shared rail polyline')
   assert(rail and #rail>=2,'rail prerequisite')
   V.assert(math.abs(rail[#rail].x-dx)<1e-6 and math.abs(rail[#rail].y-dy)<1e-6,kind..' last rail point is the registered mine-mouth anchor')
   local length=0
   for i=2,#rail do local a,p=rail[i-1],rail[i];length=length+math.sqrt((a.x-p.x)^2+(a.y-p.y)^2)end
   V.assert(length>0 and length<math.huge,kind..' rail is a finite route; renderer must draw these same segments')
   local source=site.compound.source;local actual=H.Dep.source(s,b,H.D.buildings[kind].output)
   V.assert(source and actual and source.id==actual.id and source.resource==actual.resource and type(source.x)=='number'and type(source.y)=='number',kind..' compound binds the actual shared finite resource, not an extra pool')
  end
  local restored,why=H.restore(s);V.assert(restored~=nil,kind..' compound JSON accepted: '..tostring(why));assert(restored,why)
  if not C.same(restored.buildings[b.id].site,site)then print('COMPOUND_RESTORE_DIFF',kind,C.diff(restored.buildings[b.id].site,site))end
  V.assert(C.same(restored.buildings[b.id].site,site)and C.same(restored.roads,s.roads),kind..' reload never replans the compound or road')
  records[#records+1]={kind=kind,anchor={x=b.x,y=b.y},site=C.copy(site),points=points,controlled=true}
  coroutine.yield()
 end
 -- Authentic historical village: includes two actual already-carried food jobs.
 local oldFile=File('tests/life/fixtures/schema8_earned35.json',FILE_READ);local old=cjson.decode(oldFile:ReadString());oldFile:Close()
 local s,why=H.Data.restore(old,'finite');V.assert(s~=nil,'Authentic schema8 village loads: '..tostring(why));assert(s,why)
 local loaded=0
 for i,a in ipairs(old.world.carriers)do if a.carrying then
  local actual=s.carriers[i];loaded=loaded+1
  V.assert(actual.carrying and C.same(actual.path,a.path)and actual.index==a.index and actual.job.resource==a.job.resource and actual.job.amount==a.job.amount,'Old loaded carrier keeps its exact path/index/goods without compound detour')
 end end
 V.assert(loaded>=1,'Archived fixture genuinely contains carried goods')
 V.assert(C.same(s.roads,old.world.roads),'Old roads remain byte-equivalent data')
 local captured=H.Data.capture(s,1000,1,true);local z,err=H.Data.restore(C.copy(captured),'finite');assert(z,err)
 V.assert(C.same(z.roads,s.roads)and #z.buildings==#s.buildings,'Migrated old village saves again without moving or dropping buildings')
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,records=records,oldLoadedCarriers=loaded,controlledMaterials=true,earnedConstruction=false})
 finished=true
end)
for frame=8,850 do V.atFrame(frame,function()
 if finished or coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Compound model: '..tostring(e));finished=true;V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
V.atFrame(860,function()if not finished then V.assert(false,'Compound coroutine did not finish within declared frame budget');V.finish()end end)
