-- Controlled four-direction carrier rendering: explicit cargo/job and road fixture.
-- These images test grips/occlusion, NOT earning or autonomous dispatch.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local A=require 'game.PixelAssets'
local Actors=require 'game.PixelActors'
local Move=require 'game.Movement'
local Cargo=require 'game.PixelCargo'
local run='life-cargo';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,view,hud,actor,history,pending;local records={}
function CaptureLifeCargo()
 if not pending then return end
 pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.menuOpen=true,true,false;s.paused=true
 for x=8,12 do for y=9,12 do s.roads[x..':'..y]=true end end
 actor=s.carriers[1];view.zoom(-100);view.zoom(2);view.focus(10,10);hud.update()
 SubscribeToEvent('EndAllViewsRender','CaptureLifeCargo')
end)
local dirs={{0,1,0},{-1,0,1},{1,0,2},{0,-1,3}}
for index,r in ipairs(D.goods)do for di,dir in ipairs(dirs)do
 local start=10+((index-1)*4+di-1)*12
 V.atFrame(start,function()
  actor.x,actor.y=10,10;actor.meal=false;actor.phase='travel';actor.carrying=true
  actor.job={b=s.buildings[1],inbound=false,resource=r,amount=1,pickedUp=true};actor.handedOff=false
  actor.path={{x=10,y=10},{x=10+dir[1],y=10+dir[2]}};actor.index=2;history={};s.elapsed=s.elapsed+.1
  Actors.collect(s,history)
 end)
 for o=1,5 do V.atFrame(start+o,function()
  s.elapsed=s.elapsed+.1;Move.step(actor,.1,1,s)
  local p;for _,q in ipairs(Actors.collect(s,history))do if q.key=='carrier1'then p=q;break end end
  if o==5 then
   V.assert(p and p.cargo==r and p.direction==dir[3]and Cargo.specs[r]~=nil,'Registered actual resource grip/direction '..r..' '..dir[3])
   view.focus(p.x,p.y-.3)
   pending={delay=3,path='tests/life/evidence/visual/'..run..'-'..r..'-direction-'..dir[3]..'.png',resource=r,direction=p.direction,pose=Cargo.pose(r,p.direction,false),sprite=A.actorSprite(p,s.elapsed),projection={x=p.x,y=p.y},controlled=true}
  end
 end)end
end end
V.atFrame(10+#D.goods*48,function()
 actor.carrying=false;actor.job=false;history={};s.elapsed=s.elapsed+.1
 for _,p in ipairs(Actors.collect(s,history))do if p.key=='carrier1'then V.assert(p.cargo==nil,'Unloaded carrier projection clears goods')end end
 V.assert(#records==#D.goods*4,'Every real goods type has four held native direction images')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode({records=records,count=#D.goods,controlled=true,meaning='grip rendering only, not autonomous transport'}));f:Close();V.finish()
end)
