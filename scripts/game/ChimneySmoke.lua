local Art=require 'game.PaintedArchitecture'
local S={}
function S.create(root)
    local node=root:CreateChild('ChimneySmoke')
    local draw=node:CreateComponent('BillboardSet')
    draw.numBillboards=3;draw.relative=true;draw.scaled=false;draw.sorted=true;draw.faceCameraMode=FC_ROTATE_XYZ
    draw.material=cache:GetResource('Material','art/v10/smoke.material')
    return {node=node,draw=draw,strength=0}
end
function S.update(world,b,smoke,cooking)
    local clock=world.sim.elapsed
    local dt=math.max(0,clock-(smoke.lastTime or clock))
    smoke.lastTime=clock
    smoke.strength=math.max(0,math.min(1,smoke.strength+(cooking and 1 or -1)*dt*2))
    local forward=world.cameraNode.worldRotation*Vector3.FORWARD
    local up=world.cameraNode.worldRotation*Vector3.UP
    local right=world.cameraNode.worldRotation*Vector3.RIGHT
    local plotScale=((b.footprintW or 1)+.16)/3.16
    smoke.node.worldPosition=Art.anchor(world,b,.117,.103)-forward*4.25
    smoke.node.worldRotation=Quaternion.IDENTITY
    smoke.node.enabled=smoke.strength>0
    for i=0,2 do
        local q=smoke.draw:GetBillboard(i)
        local t=(clock*.20+i/3)%1
        q.enabled=smoke.strength>0
        q.position=(up*(.09+t*.42)+right*(t*t*.16))*plotScale
        q.size=Vector2((.09+t*.075)*plotScale,(.13+t*.10)*plotScale)
        q.uv=Rect(0,0,1,1)
        q.color=Color(.82,.80,.77,smoke.strength*.30*math.sin(t*math.pi))
    end
    smoke.draw:Commit()
end
return S
