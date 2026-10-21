-- Explicitly controlled art/actor fixture, not an earned-resource playthrough.
-- Every building is constructed by real builders; every work/eating pose comes
-- from actual production and meal phases. Starter fixture stocks are disclosed.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local F=require 'game.Forestry'
local A=require 'game.PixelAssets'
local Actors=require 'game.PixelActors'
local Industry=require 'game.PixelIndustry'
local run='visual-mason'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local kind='forester'
local positions={forester={6,8},ironmine={9,4},coalmine={16,8},goldmine={18,21},fishery={21,19}}
local s,view,hud,b,pending,records=nil,nil,nil,nil,nil,{}
local seenWork,seenEat,seenReturn,workFrames,eatFrames=false,false,false,0,0
local lastPhase='';local history={}
local function key(x,y)return x..':'..y end
local function connect(x,y)
 local target=key(x,y);local q,seen,parent={}, {}, {};local head=1
 for k in pairs(s.roads)do local rx,ry=k:match('(%d+):(%d+)');q[#q+1]={tonumber(rx),tonumber(ry)};seen[k]=true end
 while not seen[target] and q[head]do
  local p=q[head];head=head+1
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=p[1]+d[1],p[2]+d[2];local k=key(nx,ny)
   if not seen[k] and s:terrain(nx,ny)=='grass' and not s:buildingAt(nx,ny)then seen[k]=true;parent[k]=key(p[1],p[2]);q[#q+1]={nx,ny}end
  end
 end
 if not seen[target]then error('Visual fixture door unreachable '..kind)end
 local k=target
 while not s.roads[k]do s.roads[k]=true;k=parent[k]end
 s.roadCount=0;for _ in pairs(s.roads)do s.roadCount=s.roadCount+1 end
end
local function capture(label,projection)
 local path='tests/v3/evidence/visual/'..run..'-'..label..'.png'
 local actor=s.workers[b.id..':1']
 pending={path=path,label=label,kind=kind,time=s.elapsed,complete=b.complete,progress=b.progress,workers=b.workers,active=b.activeWorkers,rate=b.workRate,timer=b.timer,inputs=b.inputGoods,outputs=b.outputGoods,buffer=b.buffer,meal=actor and actor.meal and actor.meal.phase,work=Industry.working(s,b),forestry=actor and actor.forestryPhase,sprite=projection and A.actorSprite(projection,s.elapsed)}
 if projection then
  local sx,sy=view.worldToScreen(projection.x,projection.y)
  pending.projection={key=projection.key,x=projection.x,y=projection.y,screenX=sx,screenY=sy,action=projection.action,walking=projection.walking}
 end
 if actor then pending.actor={x=actor.x,y=actor.y,meal=actor.meal,forestryTarget=actor.forestryTarget,forestryPhase=actor.forestryPhase}end
 pending=cjson.decode(cjson.encode(pending))
end
function CaptureV3Industry()
 if not pending then return end
 local image=Image();if graphics:TakeScreenShot(image)then image:SavePNG(pending.path);records[#records+1]=pending end
 pending=nil
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.menuOpen=true,true,false
 -- Controlled visual fixture only; these quantities are never E2E acceptance evidence.
 for _,resource in ipairs(D.goods)do s.stock[resource]=100 end;s.population=34
 for x=4,14 do s.roads[x..':9']=true end;s.roadCount=11
 local hall=s:addBuilding('kitchen',14,8,true);hall.workers=1
 local pos=positions[kind] or {14,8};local ok,msg
 ok,msg,b=s:build(kind,pos[1],pos[2]);V.assert(ok,'Legal real construction for native art fixture '..kind..': '..tostring(msg))
 if not b then V.finish();return end
 connect(b.x,b.y+1)
 if kind=='forester'then s.felledTrees['3:9']=true;F.fell(s,3,9)end
 s.paused=true;hud.update();view.zoom(-100);view.zoom(1);view.focus(b.x-1,b.y-1)
 SubscribeToEvent('EndAllViewsRender','CaptureV3Industry')
 V.assert(cache:Exists(A.root..A.buildings[kind].path),'Native runtime loads the official new building asset: '..kind)
 print('V3_VISUAL_FIXTURE',kind,cjson.encode({x=b.x,y=b.y,stock=s.stock,population=s.population,controlled=true}))
end)
for frame=12,1512 do V.atFrame(frame,function()
 if not b then return end
 s.paused=false
 for _=1,2 do s:update(.1)end
 if b.complete and D.buildings[kind].recipes and not b.recipe and not b.processingRecipe then s:setRecipe(b,1)end
 s.paused=true;hud.update()
 local a=s.workers[b.id..':1'];local p
 for _,projection in ipairs(Actors.collect(s,history))do if projection.key=='worker'..b.id..':1'then p=projection end end
 local phase=not b.complete and ('construction-'..math.min(3,math.floor((b.progress or 0)/9))) or a and a.meal and a.meal.phase or Industry.working(s,b) and 'work' or 'idle'
 if a and (a.meal or kind=='forester' and a.forestryPhase=='tend') then view.focus(a.x,a.y-.6)else view.focus(b.x-1,b.y-1)end
 if phase~=lastPhase then
  lastPhase=phase
  if not seenReturn or phase=='work'then capture('phase-'..frame..'-'..phase,p)end
 end
 if b.complete and p and (p.action=='work' or p.action=='plant') then
  seenWork=true
  if workFrames<8 then workFrames=workFrames+1;capture('work-'..workFrames,p)end
 end
 if a and a.meal and a.meal.phase=='eat' then
  seenEat=true
  if eatFrames<8 then eatFrames=eatFrames+1;capture('eat-'..eatFrames,p)end
 elseif seenEat and a and not a.meal then seenReturn=true end
 if frame==16 then capture('foundation',p)end
 if frame==1500 then view.focus(b.x-1,b.y-1);capture('complete-overview',p)end
end)end
V.atFrame(1518,function()
 V.assert(b and b.complete,'Actual builders complete the official '..kind..' footprint')
 V.assert(seenWork,'A real assigned professional performs the actual '..kind..' work/care pose')
 V.assert(seenEat and seenReturn,'The same '..kind..' professional eats at the actual hall and returns')
 V.assert(#records>=12,'Native '..kind..' sequence retains construction/work/eating/return frames')
 local f=File('tests/v3/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close()
 print('V3_VISUAL_RESULT',kind,#records,cjson.encode(s.produced))
end)

V.atFrame(1525,function()
 s:setWorking(b,false);s.felledTrees['3:9']=true;s.treeGrowth['3:9']={x=3,y=9,phase='stump',age=0}
 view.focus(3,9)
 V.assert(s:standingTree(3,9)==false,'A registered tree stump is not mature timber')
end)
V.atFrame(1528,function()capture('tree-stump',nil)end)
V.atFrame(1535,function()
 F.update(s,180);view.focus(3,9)
 V.assert(s.treeGrowth['3:9'].phase=='sapling' and not s:standingTree(3,9),'Natural 180 seconds produces a visible non-harvestable sapling')
end)
V.atFrame(1538,function()capture('tree-sapling',nil)end)
V.atFrame(1545,function()
 local raw,wood=s.stock.rawwood,s.stock.wood
 F.update(s,540);view.focus(3,9)
 V.assert(s:standingTree(3,9) and s.stock.rawwood==raw and s.stock.wood==wood,'Remaining natural 540 seconds restores mature standing timber without inventory gifts')
end)
V.atFrame(1548,function()capture('tree-mature',nil)end)
V.atFrame(1555,function()
 local f=File('tests/v3/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
