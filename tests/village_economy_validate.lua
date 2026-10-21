-- Sustained closed-loop production, rather than isolated infinite-stock jobs.
local Demo=require 'game.DemoVillage'
local Save=require 'game.SaveData'
local Meals=require 'game.Meals'
V.atFrame(8,function()
 local s=Demo.new();local peak=0
 for step=1,18000 do
  s:update(.1)
  if step%100==0 then
   for resource,amount in pairs(s.stock) do V.assert(amount>=0,'No negative warehouse '..resource) end
   for _,b in ipairs(s.buildings) do
    V.assert(b.buffer>=0 and b.inputs>=0,'Production respects physical stocks')
    if b.kind=='kitchen' then peak=math.max(peak,Meals.occupancy(s,b.id));V.assert(Meals.occupancy(s,b.id)<=4,'Sustained meals respect four real seats') end
   end
  end
  if step%3000==0 then
   local restored,reason=Save.restore(cjson.decode(cjson.encode(Save.capture(s,1000,1,true))),'finite')
   V.assert(restored~=nil,'A busy village remains loadable: '..tostring(reason))
   if restored then s=restored end
  end
 end
 for _,resource in ipairs({'wood','stone','grain','flour','livestock','meat','food'}) do
  V.assert((s.produced[resource] or 0)>0,'The sustained economy actually produces and transports '..resource)
 end
 V.assert((s.produced.grain or 0)>36,'New wheat harvests, rather than initial seed stocks, sustain the village')
 V.assert(s.mealsServed>30 and peak>1,'Hungry workers repeatedly eat and resume work')
 V.assert(not s.defeat and not s.victory,'The village continues to run throughout the observation')
 print('V7_ECONOMY_30_MINUTES',cjson.encode(s.produced),s.mealsServed,#s.jobs)
 V.finish()
end)
