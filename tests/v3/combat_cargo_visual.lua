local visualRun='d3-visual'
for _,arg in ipairs(GetArguments())do visualRun=arg:match('^-pixelqa%-run=([%w_-]+)$') or visualRun end
-- Real paid-unit combat and controlled cargo render fixtures. Explicit stocks
-- support visual isolation; this does not replace the earned campaign E2E.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
local s,view,hud,hall,pending
local renderHold=0
local history,records,seenAttack,seenMeal={}, {}, {}, {}
local attackSamples={archer=0,spearman=0}
local function shot(label,p)
 renderHold=3
 pending={delay=3,path='tests/v3/evidence/visual/'..visualRun..'-'..label..'.png',label=label,elapsed=s.elapsed,wave=s.wave,raid=s.raid,enemies={},militia=s.militia}
 for _,e in ipairs(s.enemies)do pending.enemies[#pending.enemies+1]={x=e.x,y=e.y,hp=e.hp}end
 if p then local sx,sy=view.worldToScreen(p.x,p.y);pending.projection={key=p.key,action=p.action,cargo=p.cargo,unit=p.actor.unit,screenX=sx,screenY=sy,sprite=A.actorSprite(p,s.elapsed)}end
end
function CaptureV3Combat()
 if not pending then return end
 pending.delay=pending.delay-1;if pending.delay>0 then return end
 local image=Image();if graphics:TakeScreenShot(image)then image:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function setup()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.menuOpen=true,true,false
 for _,r in ipairs(D.goods)do s.stock[r]=100 end;s.population=34
 for x=4,16 do s.roads[x..':9']=true end
 for y=10,13 do s.roads['13:'..y]=true end
 s.roadCount=0;for _ in pairs(s.roads)do s.roadCount=s.roadCount+1 end
 hall=s:addBuilding('kitchen',7,8,true);hall.workers=1;s:addBuilding('barracks',13,12,true)
 s.freePlay,s.defended=true,true;s.paused=true;view.zoom(-100);view.zoom(2);view.focus(11,8.5);hud.update();history={}
end
V.atFrame(6,function()
 SubscribeToEvent('EndAllViewsRender','CaptureV3Combat');setup()
 V.assert(s:train('archer') and s:train('spearman'),'Native battle uses actual paid archer and spearman actors')
 V.assert(s:startRaid() and #s.enemies==6 and s.enemies[1].hp==5,'Controlled post-victory battle starts six actual five-HP enemies')
 local idle=true
 for _,p in ipairs(Actors.collect(s,history))do if p.faction=='guard' and p.action=='attack'then idle=false end end
 V.assert(idle,'Distant enemies do not trigger fabricated early attack poses')
 shot('distant-wait',nil)
end)
for frame=7,1505 do V.atFrame(frame,function()
 if renderHold>0 then renderHold=renderHold-1;return end
 s.paused=false;for _=1,2 do s:update(.1)end;s.paused=true;hud.update()
 local projections=Actors.collect(s,history)
 for _,p in ipairs(projections)do
  if p.faction=='guard' then
   local unit=p.actor.unit
   if p.action=='attack'then
    seenAttack[unit]=true
    if attackSamples[unit]<4 and (frame%2==(unit=='archer' and 0 or 1))then
     attackSamples[unit]=attackSamples[unit]+1;view.focus(10,8.5);shot(unit..'-attack-'..attackSamples[unit],p)
    end
   elseif p.action=='eat' and not seenMeal[unit]then
    seenMeal[unit]=true;view.focus(p.x,p.y-.6);shot(unit..'-eat',p)
   end
  end
 end
end)end
V.atFrame(1506,function()
 V.assert(seenAttack.archer and seenAttack.spearman and attackSamples.archer==4 and attackSamples.spearman==4,'Both real regular unit identities show the actual close-enemy attack cycle')
 V.assert(seenMeal.archer and seenMeal.spearman,'Both regular units retain identity while actually eating after combat')
 V.assert(not s.raid and not s.defeat and s.wavesDefeated==1,'Actual regular army wins the controlled six-enemy five-HP battle')
end)
local goods={'wood','rawwood','bread','rawstone','ironore','coal','goldore','iron','gold','fish','hide','leather','bow','leatherarmor','ironspear','ironarmor'}
for i,r in ipairs(goods)do
 local frame=1510+i*6
 V.atFrame(frame,function()
  local a=s.carriers[1];a.meal=false;a.x,a.y=12,9;a.path={};a.index=1;a.phase='travel';a.carrying=true
  a.job={b=hall,inbound=false,resource=r,amount=1,pickedUp=true};a.handedOff=false
  s.elapsed=s.elapsed+.1;history={};view.focus(12,9)
  for _,p in ipairs(Actors.collect(s,history))do if p.key=='carrier1'then
   V.assert(p.cargo==r and A.goods[r]~=nil,'Actual carrier projection selects the registered cargo column: '..r)
   -- State is held through three complete renders before the image readback.
  end end
 end)
 V.atFrame(frame+3,function()for _,p in ipairs(Actors.collect(s,history))do if p.key=='carrier1'then shot('cargo-'..r,p)end end end)
end
V.atFrame(1613,function()
 local a=s.carriers[1];a.carrying=false;a.job=false;history={};s.elapsed=s.elapsed+.1
 for _,p in ipairs(Actors.collect(s,history))do if p.key=='carrier1'then V.assert(p.cargo==nil,'Actual unloaded carrier clears its visible cargo')end end
end)
V.atFrame(1616,function()for _,p in ipairs(Actors.collect(s,history))do if p.key=='carrier1'then shot('cargo-unloaded',p)end end end)
V.atFrame(1620,function()
 -- A lawful single-militia free-play defense creates a partial 4/5 enemy HP
 -- after the first real hit, allowing independent visual review of health bars.
 setup();V.assert(s:train('militia') and s:startRaid(),'Single militia legitimately starts a later free-play defense')
end)
local partialSeen=false;local partialFrames=0
for frame=1621,1740 do V.atFrame(frame,function()
 if partialSeen then partialFrames=partialFrames+1;if partialFrames==3 then shot('enemy-partial-four-of-five',nil)end;return end
 s.paused=false;s:update(.1);s.paused=true
 if s.enemies[1] and s.enemies[1].hp==4 then
  partialSeen=true;view.focus(s.enemies[1].x,s.enemies[1].y)
  local maxHP=require('game.PixelWorldView').enemyMaxHP(s)
  V.assert(maxHP==5 and math.floor(18*s.enemies[1].hp/maxHP)==14,'Actual advanced enemy four-of-five HP renders 14 of 18 pixels')
  print('VISUAL_HP_BOUNDARY',s.enemies[1].hp,'actualMaximum',maxHP)
 end
end)end
V.atFrame(1750,function()
 setup()
 for _,unit in ipairs({'militia','militia','militia','archer','spearman'})do V.assert(s:train(unit),'Mixed five-unit visual fixture pays each real recruit: '..unit)end
 V.assert(s:startRaid() and #s.guards==5,'Actual five-unit mixed army starts an advanced defense')
end)
local mixedSeen=false
for frame=1751,1840 do V.atFrame(frame,function()
 if renderHold>0 then renderHold=renderHold-1;return end
 s.paused=false;s:update(.1);s.paused=true
 if mixedSeen then return end
 for _,p in ipairs(Actors.collect(s,history))do if p.faction=='guard' and p.action=='attack' then
  mixedSeen=true;view.focus(10,8.5);shot('mixed-five-attack',p);break
 end end
end)end
V.atFrame(1845,function()
 V.assert(mixedSeen,'Actual mixed five-unit formation reaches enemy-triggered attack poses')
 V.assert(partialSeen,'Real single-militia damage reaches the four-of-five enemy health boundary')
 local f=File('tests/v3/evidence/visual/'..visualRun..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
