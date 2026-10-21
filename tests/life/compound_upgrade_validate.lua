-- Independent safe-upgrade contract. Synthetic legacy save omits site exactly
-- as pre-site saves did; authentic earned schema8 additionally covers live cargo.
-- Never edits runtime actor phases, jobs or loads to manufacture a successful upgrade.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local run=C.runName('compound-upgrade');local done=false;local records={}
local function stable(s)
 local d=H.Data.capture(s,1000,1,true)
 -- Notifications are intentionally outside SaveData; all persistent gameplay
 -- state remains in this snapshot, including jobs, actors, material and roads.
 return C.copy(d)
end
local function upgrade(s,b)
 assert(type(s.upgradeCompound)=='function','Final public upgradeCompound API must be present')
 return s:upgradeCompound(b)
end
local function legacy(kind)
 local s=C.new();local b=C.add(s,kind);local id=b.id
 local data=H.Data.capture(s,1000,1,true);data.version=8
 for _,entry in ipairs(data.world.buildings)do entry.site=nil;entry.lifeEnabled=nil end
 local z,why=H.Data.restore(C.copy(data),'finite');assert(z,why)
 return z,z.buildings[id]
end
local function reject(s,b,label)
 local before=stable(s);local ok,why=upgrade(s,b)
 V.assert(not ok and type(why)=='string'and #why>0,label..' rejects with a readable reason')
 V.assert(C.same(stable(s),before),label..' cannot mutate site, cargo, actors, stock or roads')
 records[#records+1]={label=label,accepted=ok,reason=why}
end
local task=coroutine.create(function()
 local s,b=legacy('mill')
 V.assert(not(b.site and b.site.compound),'Synthetic schema8 omission remains a legacy site until explicit upgrade')
 reject(s,b,'Running production')
 assert(s:setWorking(b,false));assert(s:staff(b,1));H.step(s)
 reject(s,b,'Stopped but staffed building')
 local released=false
 for i=1,3000 do if s:staff(b,-1)then released=true;break end;H.step(s)end
 V.assert(released,'Normal safe staff removal reaches an idle upgrade state');assert(released)
 local before=stable(s);local anchor={x=b.x,y=b.y};local cells=C.copy(H.D.cells(b));local ok,why=upgrade(s,b)
 V.assert(ok,'Idle legacy mill upgrades explicitly: '..tostring(why));assert(ok,why)
 V.assert(b.site and b.site.compound and b.site.compound.version==1,'Successful upgrade attaches a real registered compound')
 V.assert(b.x==anchor.x and b.y==anchor.y and C.same(H.D.cells(b),cells),'Upgrade never relocates structure or changes physical footprint')
 local after=stable(s)
 for _,k in ipairs({'stock','produced','roads','jobs','carriers','workers','guards','population','militia','timber','rock','minerals','felledTrees','treeGrowth'})do
  V.assert(C.same(before.world[k],after.world[k]),'Upgrade preserves '..k..' exactly')
 end
 local z,err=H.restore(s);V.assert(z~=nil,'Upgraded site save accepted: '..tostring(err));assert(z,err)
 V.assert(C.same(z.buildings[b.id].site,b.site)and C.same(z.roads,s.roads),'Reload retains explicit upgrade site and every road')
 reject(z,z.buildings[b.id],'Already upgraded site')
 reject(z,z.buildings[1],'Warehouse')
 records[#records+1]={label='idle-success',site=C.copy(b.site),syntheticLegacy=true}
 -- Authentic historical checkpoint, not the synthetic success fixture.
 local file=File('tests/life/fixtures/schema8_earned35.json',FILE_READ);local old=cjson.decode(file:ReadString());file:Close()
 local live,e=H.Data.restore(old,'finite');assert(live,e);local n=0
 for _,a in ipairs(live.carriers)do if a.carrying and a.job then n=n+1;reject(live,a.job.b,'Authentic legacy loaded carrier '..n)end end
 V.assert(n>=1,'Historical checkpoint genuinely covers already-carried goods')
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,records=records,controlledMaterials=true,controlledCompletion=true,syntheticLegacySuccess=true,authenticLegacyLoadedJobs=n})
 done=true
end)
for frame=8,600 do V.atFrame(frame,function()
 if done or coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Safe upgrade: '..tostring(e));done=true;V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
V.atFrame(610,function()if not done then V.assert(false,'Upgrade coroutine incomplete');V.finish()end end)
