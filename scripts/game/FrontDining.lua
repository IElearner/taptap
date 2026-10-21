-- Each occupation keeps its own face; four frames move the hands, not the body.
local F={material='art/v11/front-dining.material',frames=4}
local rows={['blue-man']=0,['ochre-woman']=1,chef=2,butcher=3,lumberjack=4,herder=5}
F.looks={}
for name,row in pairs(rows) do
 local frames={}
 for col=0,3 do frames[col+1]={(col*256+.5)/1024,(row*256+.5)/1536,((col+1)*256-.5)/1024,((row+1)*256-.5)/1536} end
 F.looks[name]={material=F.material,frames={frames}}
end
function F.frame(actor)
 local meal=actor.meal
 local elapsed=meal and meal.phase=='eat' and math.max(0,require('game.Meals').eatSeconds-(meal.timer or require('game.Meals').eatSeconds)) or 0
 return math.floor(elapsed/1.05)%4+1
end
-- The dish follows the same doorway fade as its diner. Reserving a seat
-- during the walk into the hall must not put food on an empty window table.
function F.presence(actor)
 local m=actor and actor.meal
 if not m then return 0 end
 local seconds=require('game.Meals').doorwaySeconds
 local progress=m.phase=='eat' and 1 or m.phase=='enter' and 1-m.timer/seconds or m.phase=='exit' and m.timer/seconds or 0
 return math.max(0,math.min(1,(progress-.74)/.13))
end
function F.createSettings(world,record)
 record.placeSettings={}
 for seat=1,4 do
  local node=record.node:CreateChild('PlaceSetting'..seat)
  local draw=node:CreateComponent('BillboardSet')
  draw.numBillboards=2;draw.relative=true;draw.scaled=false;draw.sorted=true;draw.faceCameraMode=FC_ROTATE_Y
  draw.material=cache:GetResource('Material','art/v12/place-settings.material'):Clone()
  draw.material.renderOrder=140
  record.placeSettings[seat]={node=node,draw=draw}
 end
end
function F.updateSettings(world,b,record)
 local Art=require 'game.PaintedArchitecture'
 local Meals=require 'game.Meals'
 local forward=world.cameraNode.worldRotation*Vector3.FORWARD
 local projection=math.max(.25,math.abs((world.cameraNode.worldRotation*Vector3.UP).y))
 local scale=((b.footprintW or 1)+.16)/3.16
 for seat,setting in ipairs(record.placeSettings) do
  local occupant=Meals.occupant(world.sim,b.id,seat)
  local alpha=F.presence(occupant)
  setting.occupant=occupant;setting.alpha=alpha
  setting.node.enabled=alpha>0;setting.draw.enabled=alpha>0
  local u=({565,688,1270,1400})[seat]/1701
  local v=seat<=2 and .675 or .685
  setting.node.worldPosition=Art.anchor(world,b,u,v)-forward*4.65
  setting.node.worldRotation=Quaternion.IDENTITY
  for i=0,1 do
   local q=setting.draw:GetBillboard(i)
   -- The diner already holds a rice bowl in every authored hand frame.
   -- Its personal side dish and tea sit on the table without a second bowl.
   local column=i==0 and 2 or 3
   q.uv=Rect((column*512+.5)/2048,.5/512,((column+1)*512-.5)/2048,511.5/512)
   q.size=Vector2((i==0 and .052 or .032)*scale,(i==0 and .052 or .032)*scale/projection)
   q.position=Vector3(i==0 and .028*scale or .089*scale,i==0 and 0 or -.008,0)
   q.color=Color(1,1,1,alpha);q.enabled=alpha>0
  end
  setting.draw:Commit()
 end
end
return F
