local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
local s,view,hud,camp,actor,pending,held,unloaded
local pendingFrames=0
local function projected(a)
 for _,p in ipairs(Actors.collect(s,{}))do if p.actor==a then return p end end
end
function CaptureLoggerCargoQA()
 if not pending then pendingFrames=0;return end
 pendingFrames=pendingFrames+1;if pendingFrames<3 then return end;pendingFrames=0
 local im=Image();if graphics:TakeScreenShot(im)then V.assert(im:SavePNG('tests/v2/evidence/visual/logger-'..pending..'.png'),'Native logger cargo screenshot '..pending)end
 pending=nil
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started=true;s.skipped=true;s.menuOpen=false
 for x=13,17 do s.roads[x..':9']=true end;s.roadCount=5
 camp=s:addBuilding('woodcutter',17,8,true);camp.workers=1
 s:update(.1);actor=s.workers[camp.id..':1'];s.paused=true
 view.zoom(-100);view.zoom(1);view.focus(18,7)
 SubscribeToEvent('EndAllViewsRender','CaptureLoggerCargoQA')
 V.assert(A.goods.rawwood==8 and A.goods.wood==0 and A.cargoColumns==10,'Native rawwood and legacy wood map to distinct preserved atlas columns')
end)
for frame=12,510 do V.atFrame(frame,function()
 if pending then return end
 s.paused=false;s:update(.1);s.paused=true
 if actor.carrying and not held then
  local p=projected(actor);V.assert(p and p.cargo=='rawwood','Actual freshly felled logger projects rawwood rather than finished wood')
  held=true;view.focus(actor.x,actor.y);pending='new-rawwood-held'
 elseif held and not actor.carrying and not unloaded then
  local p=projected(actor);V.assert(p and p.cargo==nil and camp.buffer>=1,'Actual logger handoff clears rendered cargo and adds the shelf once')
  unloaded=true;view.focus(actor.x,actor.y);pending='new-unloaded'
 end
end)end
V.atFrame(514,function()
 V.assert(held and unloaded,'Real native logging recording includes both held rawwood and actual delivery')
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Close()
 s=Data.restore(data,'finite');for _,b in ipairs(s.buildings)do if b.kind=='woodcutter'then camp=b;break end end
 actor=s.workers[camp.id..':1'];actor.meal=nil;actor.carrying=true;actor.stockedLoad=false;actor.loadAmount=1;actor.woodPhase='toCamp';actor.path={};actor.index=1;actor.x=camp.x;actor.y=camp.y+1
 camp.legacyOutput='wood'
 local p=projected(actor);V.assert(p and p.cargo=='wood','Migrated legacy logger still projects the original finished wood icon')
 local before=camp.buffer;for _=1,100 do if camp.buffer>before then break end;s:updateWoodcutter(camp,.1)end
 p=projected(actor);V.assert(p and not p.cargo and camp.buffer==before+1,'Legacy wood handoff clears rendered cargo and preserves exactly one shelf item')
 V.finish()
end)
