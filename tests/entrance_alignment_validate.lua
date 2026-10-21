local Game=require 'network.Standalone'
local sim,view,roadCount,stock
V.atFrame(8,function()
 Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
 local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
 sim.started,sim.skipped,sim.population=true,true,40
 local kinds={'house','kitchen','barracks','courier','butcher','woodcutter','mill','quarry','ranch'}
 for i,kind in ipairs(kinds) do sim:addBuilding(kind,15+(i-1)*5,8,true) end
 for x=10,55 do sim.roads[x..':9']=true end
 sim.roadCount=46;roadCount=sim.roadCount;stock=cjson.encode(sim.stock)
 sim.paused=true;hud.update()
end)
V.atFrame(22,function()
 local total=0
 for _,b in ipairs(sim.buildings) do
  local record=view.modelWorld.buildings[b.id]
  local court=record and record.frontCourt
  V.assert(court~=nil,'The actual building has a fitted forecourt: '..b.kind)
  if court then
   total=total+1
   local roadX,roadZ=b.x-10,9-(b.y+1)
   V.assert(sim.roads[b.x..':'..(b.y+1)]==true,'A real front road exists beside the inspected building')
   local expected=Vector3(roadX,.018,roadZ)
   V.assert((court.finish-expected):Length()<.0001,'The continuous paving ends on the actual south road: '..b.kind)
   local p=court.paving
   local endPoint=p.worldPosition+p.worldRotation*Vector3(0,0,p.worldScale.z)
   V.assert((endPoint-expected):Length()<.01,'The actual paved geometry reaches that road instead of only its root: '..b.kind)
   local foot=require('game.PaintedArchitecture').groundPoint(view.modelWorld,b,court.spec.u,court.spec.v,.018)
   V.assert((court.start-foot):Length()<.0001 and (p.worldPosition-foot):Length()<.01,'The path starts flush with the illustrated doorway or gate: '..b.kind)
   V.assert(p:GetComponent('CustomGeometry'):GetNumVertices(0)==48,'The entrance is a continuous eight-section curved surface: '..b.kind)
   V.assert(p.worldScale.x<=1 and court.length>0 and court.length<3,'The approach stays narrow and stops at the real road: '..b.kind)
   V.assert(#court.thresholds==0,'The original painted stairs have no duplicated stone boxes: '..b.kind)
  end
 end
 V.assert(total==10,'Every completed building type including the ranch has its front gap closed')
 V.assert(sim.roadCount==roadCount and cjson.encode(sim.stock)==stock,'Visual forecourts do not grant free roads or change construction resources')
 V.finish()
end)
