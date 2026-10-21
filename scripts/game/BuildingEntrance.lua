-- Continuous worn approaches join the illustrated doorsteps to real roads.
local Art=require 'game.PaintedArchitecture'
local E={}
local profiles={
 house={u=.40,v=.96},store={u=.36,v=.96},kitchen={u=.55,v=.97},
 barracks={u=.47,v=.97},courier={u=.35,v=.96},butcher={u=.84,v=.95},
 woodcutter={u=.82,v=.94},mill={u=.78,v=.96},quarry={u=.70,v=.97},
 ranch={u=.765,v=.865,width=.78},
}
local function ribbon(parent,name,material,border)
 local node=parent:CreateChild(name)
 local draw=node:CreateComponent('CustomGeometry')
 draw.numGeometries=1;draw:BeginGeometry(0,TRIANGLE_LIST)
 -- A continuous strip with curved irregular sides. A wider earth strip
 -- underneath beds the paving into the grass without a hard rectangle.
 local sections={}
 for i=0,8 do
  local t=i/8
  local center=math.sin(t*math.pi)*.07
  local half=.20+.035*math.sin(t*math.pi)+.012*math.sin(i*2.3)+(border and .055 or 0)
  sections[i+1]={{center-half,t},{center+half,t}}
 end
 local function vertex(p)
  draw:DefineVertex(Vector3(p[1],0,p[2]));draw:DefineNormal(Vector3.UP)
  draw:DefineTexCoord(Vector2(p[1]*3,p[2]*3))
 end
 for i=1,8 do
  local a,z=sections[i],sections[i+1]
  for _,p in ipairs({a[1],z[1],a[2],a[2],z[1],z[2]}) do vertex(p) end
 end
 draw.material=material;draw.castShadows=false;draw:Commit()
 return node
end
function E.create(world,b,record)
 local spec=profiles[b.kind];if not spec then return end
 local root=record.node:CreateChild('EntranceApproach')
 local stone=cache:GetResource('Material','art/v12/approach-stones.material')
 record.frontCourt={node=root,spec=spec,thresholds={},
  earth=ribbon(root,'WornEarthBorder',cache:GetResource('Material','art/v9/earth.material'),true),
  paving=ribbon(root,'ContinuousEntrancePaving',stone,false)}
end
function E.update(world,b,record)
 local court=record.frontCourt;if not court or not record.painted then return end
 local foot=Art.groundPoint(world,b,court.spec.u,court.spec.v,.018)
 -- Join the actual south entrance road; it is the same point used by jobs.
 local last=Vector3(b.x-10,.018,9-(b.y+1))
 local delta=last-foot
 local length=math.sqrt(delta.x*delta.x+delta.z*delta.z)
 local yaw=math.deg(math.atan(delta.x,delta.z))
 for _,node in ipairs({court.earth,court.paving}) do
  node.worldPosition=foot+Vector3(0,node==court.paving and .008 or .003,0)
  node.worldRotation=Quaternion(yaw,Vector3.UP)
  node.worldScale=Vector3((court.spec.width or 1)*math.min(1,((b.footprintW or 1)+.16)/3.16),1,math.max(.05,length))
 end
 -- The original illustration already owns its worn stone steps. Keeping
 -- the new approach flat avoids doubling them with textured box risers.
 court.start,court.finish,court.length=foot,last,length
 court.gapToRoad=0
end
return E
