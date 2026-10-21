-- Controlled completed compound/material fixture; every harvest, stack, pickup
-- and delivery below happens through the normal simulation. No phase/load edits.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local Actors=require 'game.PixelActors';local run=C.runName('compound-woodrack')
local done=false;local events={};local task=coroutine.create(function()
 local s=C.new();local b=C.add(s,'woodcutter');local id=b.id
 local hall=C.add(s,'kitchen');hall.mealStock=8
 s.stock.rawwood=0;assert(s:staff(b,1))
 local initialTimber=s.timber;local stopped=false;local conserved=true;local visible=true
 local phases,saves={},{};local stacked,picked,delivered=0,0,false;local maxStep=0;local last
 local function goods()
  local n=H.goods(s,'rawwood')
  for _,a in pairs(s.workers)do if a.building==id and not a.stockedLoad and(a.carrying or a.felledLoad)then n=n+(a.loadAmount or 1)end end
  return n
 end
 for i=1,6000 do
  local shelf=H.E.outputAmount(b,'rawwood');local stock=s.stock.rawwood
  local oldPicked={};for j,c in ipairs(s.carriers)do oldPicked[j]=c.job and c.job.pickedUp end
  H.step(s);b=s.buildings[id];local a=s.workers[id..':1'];local phase=a and a.woodPhase
  if a then
   if last then maxStep=math.max(maxStep,math.sqrt((a.x-last.x)^2+(a.y-last.y)^2))end
   last={x=a.x,y=a.y}
   if(a.felledLoad or a.carrying)and not stopped then assert(s:setWorking(b,false));stopped=true end
   if phase then phases[phase]=true end
   if phase=='stack'and not a.stockedLoad and not phases.stackContact then
    local p=H.Sites.pickupPoint(b)
    V.assert(p and math.abs(a.x-p.x)<1e-5 and math.abs(a.y-p.y)<1e-5,'Actual logger stack stands at registered rack contact, not the public door')
    -- Only assert once per genuine phase, then capture below.
    phases.stackContact=true
   end
   if H.E.outputAmount(b,'rawwood')>shelf then stacked=stacked+H.E.outputAmount(b,'rawwood')-shelf end
   if phase and not saves[phase]and(phase=='toRack'or phase=='stack'or phase=='fromRack')then
    saves[phase]=true
    local before={x=a.x,y=a.y,path=C.copy(a.path),index=a.index,phase=a.woodPhase,carrying=a.carrying,stockedLoad=a.stockedLoad,goods=goods(),site=C.copy(b.site)}
    events[#events+1]={time=s.elapsed,type='worker',state=C.copy(before)}
    local z,why=H.restore(s);V.assert(z~=nil,'Real logger '..phase..' JSON accepted: '..tostring(why));assert(z,why)
    s=z;b=s.buildings[id];a=s.workers[id..':1']
    V.assert(C.same({x=a.x,y=a.y},{x=before.x,y=before.y})and C.same(a.path,before.path)and a.index==before.index and a.woodPhase==before.phase and a.carrying==before.carrying and a.stockedLoad==before.stockedLoad and goods()==before.goods and C.same(b.site,before.site),'Logger JSON retains real rack path, held-versus-shelf status and exact goods')
   end
  end
  local projections={};for _,p in ipairs(Actors.collect(s,{}))do projections[p.key]=p end
  for j,c in ipairs(s.carriers)do if c.job and c.job.b==b and c.job.resource=='rawwood'then
   local state=c.sitePickup
   if state and state.phase=='loading'and c.job.pickedUp and not oldPicked[j]then
    picked=picked+c.job.amount;local p=H.Sites.pickupPoint(b)
    V.assert(c.job.sitePickup==true and c.carrying and p and math.abs(c.x-p.x)<1e-5 and math.abs(c.y-p.y)<1e-5,'Ordinary carrier takes real wood at the rack through new sitePickup')
    V.assert(H.E.outputAmount(b,'rawwood')==shelf-c.job.amount,'Loading midpoint deducts exact wood once from rack')
    local projection=projections['carrier'..j];visible=visible and projection~=nil and projection.cargo=='rawwood'
    events[#events+1]={time=s.elapsed,type='carrier-picked',actor=C.copy(c),projection=projection and {x=projection.x,y=projection.y,cargo=projection.cargo},shelf=H.E.outputAmount(b,'rawwood')}
   end
   if state and not saves['carrier-'..state.phase]then
    saves['carrier-'..state.phase]=true
    local before={site=C.copy(state),path=C.copy(c.path),index=c.index,picked=c.job.pickedUp,amount=c.job.amount,goods=goods()}
    local z,why=H.restore(s)
    if not z then
     local saved=H.Data.capture(s,1000+s.elapsed,1,true);C.write('tests/life/evidence/'..run..'-failed-save.json',saved)
     local encoded=C.copy(saved);local entry=encoded.world.buildings[id];local target=H.Sites.pickupPoint(entry);local actual=encoded.world.carriers[j].sitePickup.target
     print('RACK_JSON_COORDINATES',string.format('target x %.17g y %.17g saved x %.17g y %.17g',target.x,target.y,actual.x,actual.y))
    end
    V.assert(z~=nil,'Rack carrier '..state.phase..' JSON accepted: '..tostring(why));assert(z,why)
    s=z;b=s.buildings[id];local c2=s.carriers[j]
    V.assert(C.same(c2.sitePickup,before.site)and C.same(c2.path,before.path)and c2.index==before.index and c2.job.pickedUp==before.picked and c2.job.amount==before.amount and goods()==before.goods,'Rack carrier restore cannot repeat E.take or change route/amount')
   end
  end end
  if s.timber+goods()~=initialTimber then conserved=false end
  if s.stock.rawwood>stock then delivered=true end
  if delivered and stopped and a and not a.woodPhase then break end
 end
 V.assert(stopped and phases.chop and phases.stackContact,'Single genuine harvest safely stops after acquiring real timber')
 V.assert(stacked==H.D.buildings.woodcutter.amount and picked==stacked and s.stock.rawwood==stacked,'One log travels logger to rack to carrier to warehouse exactly once')
 V.assert(conserved and maxStep<=.2,'Timber plus all held/shelf/in-transit goods is conserved and worker never teleports')
 V.assert(visible and picked>0,'Rack pickup retains a visible ordinary carrier with correct rawwood cargo')
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,events=events,phases=phases,stacked=stacked,picked=picked,delivered=delivered,maxStep=maxStep,controlledMaterials=true,controlledCompletion=true})
 done=true
end)
for frame=8,900 do V.atFrame(frame,function()
 if done or coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Wood rack: '..tostring(e));done=true;V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
V.atFrame(910,function()if not done then V.assert(false,'Wood rack test incomplete');V.finish()end end)
