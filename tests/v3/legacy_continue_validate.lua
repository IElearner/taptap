-- Archived schema-three village with only its outcome flags changed to
-- represent an old victory. This is an explicit compatibility boundary fixture.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local s,hud,before,files,camp=nil,nil,nil,{},nil
local function inspect()s,_,hud=Game.Inspect()end
local function tap(id)
 local w=hud.root:FindById(id);V.assert(w and w:IsVisible(),'Actual legacy continuation control is visible: '..id)
 if not w then return end
 local p=w:GetAbsoluteLayout();local x,y=(p.x+p.w*.5)*UI.GetScale(),(p.y+p.h*.5)*UI.GetScale()
 UI.HandleTouchBegin(991,x,y);UI.HandleTouchEnd(991,x,y);inspect();hud.update()
end
V.atFrame(6,function()
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 raw.world.victory=true;raw.world.defeat=false;raw.world.raid=false;raw.world.enemies={}
 local old,why=Data.restore(raw,'finite')
 V.assert(old and old.victory and not old.campaignCompleted and old.map.worldSize==22,'Real old-schema village restores as a legacy victory, without invented industrial completion: '..tostring(why))
 local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 V.assert(store:save(old,true),'Migrated victory uses the real isolated pixel save encoder')
 Game.UseStore(store);inspect();before=Data.capture(s,1000,1,true)
end)
V.atFrame(12,function()tap('enterVillage')end)
V.atFrame(18,function()
 tap('continueFreePlay');s.paused=true;hud.update()
 V.assert(s.freePlay and not s.victory and not s.campaignCompleted and s.lesson==#D.lessons+1,'Actual old-victory Continue opens running free play, not the unfinished twenty-lesson campaign')
 V.assert(#s.buildings==#before.world.buildings and s.population==before.world.population and s.map.worldSize==22,'Legacy Continue preserves the entire village, residents and original 22 map')
 for _,r in ipairs(D.goods)do V.assert(s.stock[r]==before.world.stock[r],'Legacy Continue preserves stock exactly: '..r)end
 local loaded,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,2,true))),'finite')
 V.assert(loaded and loaded.freePlay and not loaded.campaignCompleted and not loaded.victory,'Continued old victory saves and reloads without relocking: '..tostring(why))
 s=loaded;s.paused=false
 before={elapsed=s.elapsed,produced=s.produced.food or 0}
end)
for frame=19,78 do V.atFrame(frame,function()for _=1,50 do s:update(.1)end end)end
V.atFrame(79,function()
 V.assert(s.elapsed>before.elapsed+299 and not s.victory and not s.defeat,'Legacy continued village advances ordinary online simulation after restore')
 V.assert((s.produced.food or 0)>before.produced,'Actual legacy food chain continues producing after victory continuation and reload')
 local road
 for k in pairs(s.roads)do local x,y=k:match('(-?%d+):(-?%d+)');x,y=tonumber(x),tonumber(y)
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if s:canBuild('road',x+d[1],y+d[2])then road={x+d[1],y+d[2]};break end end
  if road then break end
 end
 V.assert(road~=nil and s:build('road',road[1],road[2]),'Old-victory continuation accepts a real new road construction order')
 local best
 for y=1,21 do for x=1,22 do
  if s:canBuild('barracks',x,y)then
   local blocked={};for _,c in ipairs(D.cells('barracks'))do blocked[(x+c.x)..':'..(y+c.y)]=true end
   local q,seen,parents={}, {}, {};for k in pairs(s.roads)do local rx,ry=k:match('(-?%d+):(-?%d+)');q[#q+1]={tonumber(rx),tonumber(ry)};seen[k]=true end
   local target=x..':'..(y+1);local i=1
   while not seen[target]and q[i]do
    local p=q[i];i=i+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=p[1]+d[1],p[2]+d[2];local k=nx..':'..ny
     if not seen[k]and not blocked[k]and s:terrain(nx,ny)=='grass'and not s:buildingAt(nx,ny)and not s:roadSiteAt(nx,ny)then
      seen[k]=true;parents[k]=p[1]..':'..p[2];q[#q+1]={nx,ny}
     end
    end
   end
   if seen[target]then
    local route={};local k=target
    while not s.roads[k]do local rx,ry=k:match('(-?%d+):(-?%d+)');table.insert(route,1,{tonumber(rx),tonumber(ry)});k=parents[k]end
    if not best or #route<#best.route then best={x=x,y=y,route=route}end
   end
  end
 end end
 if best then
  for _,xy in ipairs(best.route)do V.assert(s:build('road',xy[1],xy[2]),'Legacy continuation actually plans each new connected route tile')end
  local ok,message,b=s:build('barracks',best.x,best.y);if ok then camp=b end
  print('LEGACY_REAL_NEW_CAMP',best.x,best.y,#best.route,ok,message,s.stock.wood,s.stock.food,s:availableWorkers())
 end
 V.assert(camp~=nil,'Continued old village can genuinely pay for a connected new barracks')
end)

for frame=80,239 do V.atFrame(frame,function()for _=1,50 do s:update(.1)end end)end
V.atFrame(240,function()
 V.assert(camp and camp.complete,'Actual builders finish the newly paid post-continue barracks')
 V.assert(s:train('militia'),'Continued old village can pay for a newly recruited defender')
 V.assert(s:startRaid() and s.raid,'Old-victory continuation permits a new actual defense without claiming industrial completion')
 V.finish()
end)
