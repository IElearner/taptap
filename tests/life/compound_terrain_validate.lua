-- Explicit obstruction/empty-resource boundary fixtures, not an earned village.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local run=C.runName('compound-terrain');local rows={};local done=false
local task=coroutine.create(function()
 for _,kind in ipairs({'quarry','ironmine','coalmine','goldmine','woodcutter','fishery'})do
  local s=C.new();local p,site=C.find(s,kind)
  V.assert(site and site.compound,kind..' has a positive real terrain-bound placement')
  assert(site and site.compound,'Terrain contract prerequisite')
  local original=C.copy(site);local reasons={}
  if kind=='woodcutter'then
   local tree=s:nearestTree({x=p.x,y=p.y,footprintW=H.D.footprint(kind)},6)
   V.assert(tree and s:forestPath(p.x,p.y+1,tree.x,tree.y),'New logger has a real route from its public door to mature forest')
   -- Keep terrain/trees intact, explicitly occupy each tree's target cell.
   -- This tests near-but-inaccessible forest rather than changing resource stock.
   local blocks={};local dummy={id=9999,kind='house'}
   for y=1,30 do for x=1,30 do if s:standingTree(x,y)then local k=C.key(x,y);blocks[k]=s.buildingIndex[k];s.buildingIndex[k]=dummy end end end
   local ok,why=s:canBuild(kind,p.x,p.y);V.assert(not ok and type(why)=='string','Nearby forest with no reachable mature tree rejects logger placement')
   reasons.blocked=why
  elseif kind=='fishery'then
   local bank,water=site.shoreCell,site.waterCell
   V.assert(bank and water and s:terrain(bank.x,bank.y)=='grass'and s:terrain(water.x,water.y)=='water'and math.abs(bank.x-water.x)+math.abs(bank.y-water.y)==1,'Fish compound binds a dry cardinal bank to genuine water')
   V.assert(H.Sites.path(s,p.x,p.y+1,bank.x,bank.y,nil)~=nil,'Fish compound entrance genuinely reaches its bank')
  else
   local source=site.compound.source;V.assert(source and source.id and source.x and source.y,kind..' binds a visible terrain/source coordinate')
   assert(source,'resource prerequisite')
   local probe={kind=kind,x=p.x,y=p.y,site=site};local before=H.Dep.source(s,probe,H.D.buildings[kind].output)
   V.assert(before and before.id==source.id,kind..' planner and production select the same existing pool')
   if source.id=='rawstone:valley'then s.rock=0 else s.minerals[source.id]=0 end
   local ok,why=s:canBuild(kind,p.x,p.y)
   -- Other nearby independent deposits may legitimately supply the anchor;
   -- either rejection or explicit selection of a different nonempty source is valid.
   local _,_,nextSite=s:canBuild(kind,p.x,p.y)
   local changed=nextSite and nextSite.compound and nextSite.compound.source and nextSite.compound.source.id~=source.id
   V.assert(not ok or changed,kind..' does not rebuild an exhausted source as newly full')
   reasons.depleted=why
  end
  rows[#rows+1]={kind=kind,anchor=p,site=original,reasons=reasons,controlledBoundary=true};coroutine.yield()
 end
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,rows=rows});done=true
end)
for frame=8,700 do V.atFrame(frame,function()
 if done or coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task)
 if not ok then V.assert(false,'Compound terrain: '..tostring(e));done=true;V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
V.atFrame(710,function()if not done then V.assert(false,'Compound terrain test did not finish');V.finish()end end)
