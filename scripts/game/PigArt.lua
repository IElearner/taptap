local Animation=require 'game.DirectionalAnimation'
local Pig={}
function Pig.create(world,pig)
    for _,child in ipairs(pig.node:GetChildren()) do
        child.enabled=false
        local drawable=child:GetComponent('StaticModel')
        if drawable then drawable.enabled=false end
    end
    local node=pig.node:CreateChild('PaintedPig')
    local draw=node:CreateComponent('BillboardSet')
    draw.numBillboards=1;draw.relative=true;draw.scaled=false;draw.sorted=true;draw.faceCameraMode=FC_ROTATE_Y
    draw.material=cache:GetResource('Material','art/v9/pigs.material')
    local q=draw:GetBillboard(0);q.enabled=true;q.color=Color(1,1,1,1)
    pig.art={node=node,draw=draw,quad=q}
    pig.art.shadow=world:part(pig.node,'PigContactShadow','Sphere',cache:GetResource('Material','actors/directional-v6/shadow.material'),0,.002,0,.22,.003,.12)
    pig.art.shadow:GetComponent('StaticModel').castShadows=false
end
function Pig.update(world,pig,index,moving,nibbling)
    if not pig.art then Pig.create(world,pig) end
    local p=pig.art
    -- The parent turns the physical animal. Facing is already painted into
    -- the atlas; inheriting that yaw would turn the art edge-on a second time.
    p.node.worldRotation=Quaternion.IDENTITY
    local direction=Animation.stableDirection(pig.yaw or 0,p.direction)
    local frame=moving and math.floor((pig.distance or 0)/.26*4)%4 or 0
    p.direction,p.frame=direction,frame+1
    p.quad.uv=Rect((frame*128+.5)/512,((direction-1)*128+.5)/1024,((frame+1)*128-.5)/512,(direction*128-.5)/1024)
    local size=(.285+index*.008)*((pig.plotWidth or 3)+.16)/3.16
    local up=world.cameraNode.worldRotation*Vector3(0,1,0)
    local height=size/math.max(.25,math.abs(up.y))
    p.quad.size=Vector2(size*.5,height*.5)
    p.quad.position=Vector3(0,height*(122/128-.5)+(nibbling and math.sin(world.sim.elapsed*2+index)*.004 or 0),0)
    p.draw:Commit()
end
return Pig
