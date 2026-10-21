local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
V.atFrame(8,function()
 for _,case in ipairs({{kind='sawmill',resource='rawwood'},{kind='kitchen',resource='bread'}})do
  local s=Sim.new('finite');s.stock[case.resource]=1
  local b=s:addBuilding(case.kind,8,8,true)
  s:enqueue(b,true,case.resource)
  V.assert(s.stock[case.resource]==0 and #s.jobs==1,'New good is reserved from warehouse once: '..case.resource)
  local c=s.carriers[1];local seen={};local valid=true
  for step=1,600 do
   s:updateCarrier(c,.1,false)
   local total=s.stock[case.resource]+b.inputs
   for _,j in ipairs(s.jobs)do if j.resource==case.resource then total=total+j.amount end end
   if c.job and c.job.resource==case.resource and not c.handedOff then total=total+c.job.amount end
   if total~=1 then valid=false end
   local phase=c.phase or 'idle'
   local marker=phase..(c.handedOff and ':handed' or '')
   if c.job and not seen[marker]then
    seen[marker]=true
    local restored,err=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+step,1,true))),'finite')
    V.assert(restored~=nil,'New cargo save restores at '..case.resource..' '..marker..': '..tostring(err))
    if restored then s=restored;c=s.carriers[1];b=s.buildings[2]end
   end
   if not c.job and #s.jobs==0 then break end
  end
  V.assert(valid,'Warehouse, prepaid task and destination conserve exactly one '..case.resource..' at every step')
  V.assert(seen.packing and seen.travel and seen.unload and seen['unload:handed'],'Observed all loading/transit/unload and handed-off phases: '..case.resource)
  V.assert(b.inputs==1 and b.inputGoods[case.resource]==1 and s.stock[case.resource]==0 and not c.job,'Final resumed shipment delivers exactly one '..case.resource)
 end
 V.finish()
end)
