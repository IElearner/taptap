local visualRun='d3-visual'
for _,arg in ipairs(GetArguments())do visualRun=arg:match('^-pixelqa%-run=([%w_-]+)$') or visualRun end
-- Explicit render/movement fixtures. Real generated workers and paid guards
-- traverse real road paths with Movement.step; controlled meal-travel state
-- exposes full identity atlases outdoors. These are not autonomous job proofs.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local Move=require 'game.Movement'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
local roles={{'forester','forester'},{'mason','mason'},{'ironmine','miner'},{'fishery','fisher'},{'smelter','smith'},{'tannery','leatherworker'},{'woodweapons','carpenter'},{'archer','archer'},{'spearman','spearman'}}
local route={{8,12,0},{10,12,2},{10,10,3},{8,10,1}}
local s,view,hud,a,b,actorKey,role,history,seen,pending
local records={}
local function shot(label,p)
 local sx,sy=view.worldToScreen(p.x,p.y)
 pending={path='tests/v3/evidence/visual/'..visualRun..'-'..label..'.png',role=role,key=p.key,direction=p.direction,frame=p.frame,action=p.action,cargo=p.cargo,actorX=a.x,actorY=a.y,screenX=sx,screenY=sy,sprite=A.actorSprite(p,s.elapsed)}
end
function CaptureV3Roles()
 if not pending then return end
 local image=Image();if graphics:TakeScreenShot(image)then image:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
V.atFrame(5,function()SubscribeToEvent('EndAllViewsRender','CaptureV3Roles')end)
for i,pair in ipairs(roles)do
 local start=8+(i-1)*125
 V.atFrame(start,function()
  Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
  s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.menuOpen=true,true,false
  for _,r in ipairs(D.goods)do s.stock[r]=100 end;s.population=34
  for x=8,14 do s.roads[x..':9']=true end
  for x=8,10 do for y=10,12 do s.roads[x..':'..y]=true end end
  s.roadCount=0;for _ in pairs(s.roads)do s.roadCount=s.roadCount+1 end
  local hall=s:addBuilding('kitchen',7,8,true);s.roads['7:9']=true;s.roadCount=s.roadCount+1
  local kind=pair[1];role=pair[2]
  if kind=='archer' or kind=='spearman'then
   s:addBuilding('barracks',14,8,true);V.assert(s:train(kind),'Visual role is a real paid '..kind);a=s.guards[1];actorKey='guard1'
  else
   b=s:addBuilding(kind,14,8,true);b.workers=1;s:update(.1);a=s.workers[b.id..':1'];actorKey='worker'..b.id..':1'
   V.assert(a~=nil,'Visual role exists as an actual assigned professional: '..role)
  end
  -- Controlled travelling-to-meal projection uses the actual actor identity.
  a.meal={phase='walk',target=hall.id,resumeX=14,resumeY=9};a.x,a.y=8,10;a.path={};a.index=1
  history={};seen={};s.paused=true;view.zoom(-100);view.zoom(2);view.focus(9,11);hud.update()
 end)
 for direction,target in ipairs(route)do
  local begin=start+1+(direction-1)*30
  V.atFrame(begin,function()
   V.assert(Move.route(s,a,target[1],target[2]),'Actual road route exists for '..role..' direction '..target[3]);seen={}
  end)
  for offset=1,28 do V.atFrame(begin+offset,function()
   s.elapsed=s.elapsed+.1;Move.step(a,.1,1,s)
   local p
   for _,q in ipairs(Actors.collect(s,history))do if q.key==actorKey then p=q;break end end
   if p and p.walking then seen[p.frame]=true end
   if p and (offset==13 or offset==17)then
    V.assert(p.direction==target[3] and A.actorSprite(p,s.elapsed).path==A.roles[role],'Native projection keeps the correct profession and movement direction: '..role..' '..target[3])
    shot(role..'-direction-'..target[3]..'-phase-'..offset,p)
   end
  end)end
  V.atFrame(begin+29,function()
   local n=0;for _ in pairs(seen)do n=n+1 end
   V.assert(n==4,'All four real walking frames advance for '..role..' direction '..target[3])
  end)
 end
end
V.atFrame(1135,function()
 local f=File('tests/v3/evidence/visual/'..visualRun..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close()
 V.assert(#records==72,'Nine identities retain two native samples in each of four walking directions')
 V.finish()
end)
