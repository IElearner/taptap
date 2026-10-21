local Art=require 'game.PaintedArchitecture'
local R={width=.30}
function R.create(world,record)
 local gate=record.node:CreateChild('PenGate')
 for _,y in ipairs({.10,.21}) do
  local n=world:part(gate,'GateTimberRail','Box',world:material(118,86,48),R.width*.5,y,0,R.width,.035,.035)
  n:GetComponent('StaticModel').castShadows=false
 end
 for _,x in ipairs({.05,.15,.25}) do
  local n=world:part(gate,'GateTimberSlat','Box',world:material(118,86,48),x,.15,0,.026,.26,.026)
  n:GetComponent('StaticModel').castShadows=false
 end
 record.gate=gate
 record.entrance=world:part(record.node,'PenEntranceEarth','Box',cache:GetResource('Material','art/v9/earth.material'),0,0,0,1,.012,1)
 record.entrance:GetComponent('StaticModel').castShadows=false
 record.entrance.enabled=false
 record.entrance:GetComponent('StaticModel').enabled=false
 record.entranceStones={}
 for i=1,3 do
  local n=world:part(record.node,'EntranceStone','Box',world:material(197,182,149),0,0,0,.15,.018,.12)
  n:GetComponent('StaticModel').castShadows=false;record.entranceStones[i]=n
  n.enabled=false;n:GetComponent('StaticModel').enabled=false
 end
end
function R.update(world,b,record,angle)
 local forward=world.cameraNode.worldRotation*Vector3.FORWARD
 local scale=((b.footprintW or 1)+.16)/3.16
 record.gate.worldPosition=Art.anchor(world,b,.715,.798)-forward*4.35
 record.gate.worldScale=Vector3(scale,scale,scale)
 record.gate.worldRotation=Quaternion(angle,Vector3.UP)
 local first=Art.groundPoint(world,b,.765,.865,.024)
 local last=Vector3(b.x-10,.024,9-(b.y+1))
 local delta=last-first
 local length=math.min(1.25,delta:Length())
 if delta:Length()>1.25 then last=first+delta*(1.25/delta:Length());delta=last-first end
 record.entrance.worldPosition=(first+last)*.5
 record.entrance.worldScale=Vector3(.34*scale,.012,length+.04)
 record.entrance.worldRotation=Quaternion(math.deg(math.atan(delta.x,delta.z)),Vector3.UP)
 for i,n in ipairs(record.entranceStones) do
  n.worldPosition=first+delta*(i/4)+Vector3((i%2==0 and -.025 or .025)*scale,.015,0)
  n.worldScale=Vector3(.15*scale,.018,.12*scale)
  n.worldRotation=Quaternion((i-2)*7,Vector3.UP)
 end
end
---@param t number
---@param slot number
function R.caretaker(world,b,t,slot)
 local door=Art.groundPoint(world,b,.345,.805,.08)
 local feed=Art.groundPoint(world,b,.765-(slot-1)*.075,.83+(slot-1)*.025,.08)
 ---@type Vector3
 local point=door+(feed-door)*t
 return point.x+10,9-point.z
end
return R
