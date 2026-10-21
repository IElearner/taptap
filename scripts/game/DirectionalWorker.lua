-- Detailed frame artwork in the 3D scene: normal world occlusion and picking
-- remain available; cargo stays independent of the character illustration.
local Animation=require "game.DirectionalAnimation"
local Cargo=require "game.Cargo"
local Pose=require "game.BuildingPose"
local Atlas=require "game.DirectionalWorkerManifest"
local Effects=require "game.ActorEffects"
local Interior=require 'game.InteriorActors'
local FrontDining=require 'game.FrontDining'
local Worker={}
function Worker.supports(profile,key,action)
    if not Atlas.looks[profile.id] then return false end
    if key:sub(1,5)=="enemy" or key:sub(1,5)=="guard" then return false end
    local actions={hammer=true,chop=true,cook=true,butcher=true,feed=true,eat=true,plow=true,tend=true,water=true,harvest=true,mill=true}
    return not action or actions[action]==true
end
function Worker.create(world,key,profile)
    local root=world.scene:CreateChild("Villager_"..key)
    local sprite=root:CreateChild("DirectionalBody")
    local draw=sprite:CreateComponent("BillboardSet")
    draw.numBillboards=1;draw.relative=true;draw.scaled=false;draw.sorted=true;draw.faceCameraMode=FC_ROTATE_Y
    local quad=draw:GetBillboard(0);quad.enabled=true;quad.color=Color(1,1,1,1)
    local height=.66
    -- BillboardSet stores half extents, unlike the full canvas dimensions.
    quad.size=Vector2(height*Atlas.cellWidth/Atlas.cellHeight*.5,height*.5)
    draw:Commit()
    local previousNode=root:CreateChild('PreviousPose')
    local previous=previousNode:CreateComponent('BillboardSet')
    previous.numBillboards=1;previous.relative=true;previous.scaled=false;previous.sorted=true;previous.faceCameraMode=FC_ROTATE_Y
    local previousQuad=previous:GetBillboard(0);previousQuad.enabled=true;previousQuad.color=Color(1,1,1,0)
    previousNode.enabled=false
    local pivot=root:CreateChild("CargoPivot")
    local load=pivot:CreateChild("CarriedLoad")
    local models=require "game.VillageModels"
    local crate=world:part(load,"Crate","Box",world:material(140,107,61),0,.015,0,.27,.17,.16)
    local cargo=require("game.CargoModels").add(world,load,{crate=crate},models.mesh)
    local shadow=world:part(root,"WorkerContactShadow","Sphere",cache:GetResource("Material","actors/directional-v6/shadow.material"),0,.004,0,.20,.004,.12)
    shadow:GetComponent("StaticModel").castShadows=false
    return {node=root,billboards=draw,quad=quad,shadow=shadow,previousNode=previousNode,previous=previous,previousQuad=previousQuad,height=height,cargoPivot=pivot,load=load,cargo=cargo,modelId=profile.id,directional=true}
end
function Worker.update(world,key,actor,profile,action,x,y,seed,hidden)
    local p=world.actors[key]
    if not p then p=Worker.create(world,key,profile);world.actors[key]=p end
    p.node.enabled=not hidden
    p.seen,p.actor,p.profile,p.action=true,actor,profile,action
    local dx,dy=x-(p.lastX or x),y-(p.lastY or y)
    local delta=math.sqrt(dx*dx+dy*dy)
    local walking=delta>.00001 and delta<1
    p.lastX,p.lastY=x,y;p.distance=(p.distance or 0)+(walking and delta or 0)
    local yaw=p.yaw or ({se=90,nw=-90,sw=180,ne=0})[actor.facing or "sw"]
    if walking then yaw=math.deg(math.atan(dx,-dy)) end
    local onSite=action=="hammer" or actor.phase=="unload" or actor.phase=="ready" or actor.phase=="recover" or actor.phase=="waitMaterials" or actor.phase=="waitSite" or actor.phase=="awaitStage"
    if onSite and actor.job then
        local j=actor.job
        if j.kind=="road" then yaw=math.deg(math.atan(j.x-x,y-j.y))
        elseif j.building and world.sim.buildings[j.building] then
            local tx,ty=Pose.workTarget(world.sim.buildings[j.building],j)
            yaw=math.deg(math.atan(tx-x,y-ty))
        else yaw=({south=0,north=180,west=90,east=-90})[j.side] or yaw end
    end
    local Meals=require("game.Meals")
    if actor.meal and (action=="eat" or actor.meal.phase=="enter" and actor.meal.timer<Meals.seatTransitionSeconds or actor.meal.phase=="exit" and actor.meal.timer>Meals.doorwaySeconds-Meals.seatTransitionSeconds) then
        local hall=world.sim.buildings[actor.meal.target]
        yaw=(((actor.meal.seat or 1)-1)%2==0 and 90 or -90)+(hall and Pose.yaw(hall) or 0)
    elseif actor.woodPhase=="stack" then
        local b=world.sim.buildings[actor.building]
        yaw=(b and Pose.yaw(b) or 0)
    elseif action=="chop" and actor.treeX then
        yaw=math.deg(math.atan(actor.treeX-x,y-actor.treeY))
    elseif action=="cook" or action=="butcher" or action=="feed" or action=="mill" then
        local b=world.sim.buildings[actor.building]
        yaw=(action=="cook" and 45 or 180)+(b and Pose.yaw(b) or 0)
    elseif action=="plow" or action=="tend" or action=="water" or action=="harvest" then
        yaw=math.floor((actor.workClock or 0)/4)%2==0 and 90 or -90
    end
    local dt=math.max(0,math.min(.25,world.sim.elapsed-(p.poseTime or world.sim.elapsed)))
    yaw=Animation.turn(p.yaw,yaw,dt)
    p.yaw=yaw
    local actionKey,frame=Animation.select(actor,action,walking,p.distance,world.sim.elapsed)
    -- Keep a paused walk on the last displayed frame.
    if world.sim.paused and not walking and p.actionKey==actionKey and p.frame and p.poseTime==world.sim.elapsed and p.poseTimer==actor.timer then frame=p.frame end
    local direction=Animation.stableDirection(yaw,p.direction)
    local interior=Interior.presentation(world.sim,actor,action)
    if interior=='chef' then
        direction=1;actionKey='work';frame=math.floor(world.sim.elapsed*.65)%2+1
    elseif interior=='diner' then
        direction=1;actionKey='front-dining';frame=FrontDining.frame(actor)
    end
    if actionKey=="eat" or actionKey=="sit" then
        actionKey=actionKey..((direction<=4 or direction==5) and "-west" or "-east")
    end
    local look=Atlas.looks[profile.id]
    local spec=actionKey=='front-dining' and FrontDining.looks[profile.id] or look[actionKey] or look.work or look.walk
    if not spec then return end
    if p.actionKey and (p.actionKey~=actionKey or p.direction~=direction) then
        p.previous.material=p.billboards.material
        p.previousQuad.uv=p.quad.uv
        p.blendAt,p.blendDuration=world.sim.elapsed,Animation.blendDuration(p.actionKey,actionKey)
    end
    if p.actionKey~=actionKey then p.billboards.material=cache:GetResource("Material",spec.material) end
    p.actionKey,p.frame,p.direction=actionKey,frame,direction
    ---@type {[1]:number,[2]:number,[3]:number,[4]:number}
    local rect=spec.frames[direction][frame]
    p.quad.uv=Rect(rect[1],rect[2],rect[3],rect[4])
    local up=world.cameraNode.worldRotation*Vector3(0,1,0)
    -- Keep the artwork upright in the world. A camera-facing ground quad
    -- puts the upper body behind its chair/roof, despite a correct 2D image.
    local projection=math.max(.25,math.abs(up.y))
    local physicalHeight=p.height/projection
    p.quad.size=Vector2(p.height*Atlas.cellWidth/Atlas.cellHeight*.5,physicalHeight*.5)
    p.quad.position=Vector3(0,physicalHeight*(Atlas.baseline/Atlas.cellHeight-.5),0)
    local blend=p.blendAt and math.max(0,math.min(1,(world.sim.elapsed-p.blendAt)/p.blendDuration)) or 1
    blend=blend*blend*(3-2*blend)
    p.quad.color=Color(1,1,1,blend)
    p.previousNode.enabled=blend<1
    p.previousQuad.size=p.quad.size;p.previousQuad.position=p.quad.position
    p.previousQuad.color=Color(1,1,1,1-blend)
    p.previous:Commit()
    p.billboards:Commit()
    local floor=0.0
    if actor.meal and (actor.meal.phase=="enter" or actor.meal.phase=="eat" or actor.meal.phase=="exit") then
        local m=actor.meal
        local t=m.phase=="enter" and 1-m.timer/require("game.Meals").doorwaySeconds or m.phase=="exit" and m.timer/require("game.Meals").doorwaySeconds or 1
        floor=.11*math.max(0,math.min(1,(t-.76)/.24))
    elseif actor.building and not actor.meal then
        local b=world.sim.buildings[actor.building]
        if b and b.kind~="farm" and b.kind~="woodcutter" then floor=b.kind=="ranch" and .08 or .11 end
        if b and b.kind=="woodcutter" then
            if actor.woodPhase=="toRack" then floor=.11*math.min(1,(actor.woodClock or 0)/1.2)
            elseif actor.woodPhase=="stack" then floor=.11
            elseif actor.woodPhase=="fromRack" then floor=.11*(1-math.min(1,(actor.woodClock or 0)/1.2)) end
        end
    elseif actor.building and actor.meal and (actor.meal.phase=="leaveWork" or actor.meal.phase=="returnWork") then
        local m=actor.meal
        local t=m.phase=="leaveWork" and 1-m.timer/require("game.Meals").workDoorSeconds or m.timer/require("game.Meals").workDoorSeconds
        floor=.11*(1-math.max(0,math.min(1,(t-.7)/.3)))
    end
    p.node.position=Vector3(x-10,floor,9-y)
    local offset=onSite and Quaternion(yaw,Vector3(0,1,0))*Vector3(0,0,.28) or Vector3(0,0,0)
    p.workOffset=p.workOffset and p.workOffset+(offset-p.workOffset)*math.min(1,dt/.25) or offset
    p.poseTime=world.sim.elapsed
    p.poseTimer=actor.timer
    p.node.position=p.node.position+p.workOffset
    -- The directional body is camera-facing art. Keep physical parcels in the
    -- same screen plane so long boards cannot turn edge-on and look upright.
    p.cargoPivot.rotation=Quaternion()
    local phase=p.distance/Animation.walkStride*math.pi*2
    local bob=walking and math.sin(phase)*.007 or 0
    local lower=actor.phase=="unload" and not key:match("^carrier%d+$") and math.max(0,1-(actor.timer or 0)/require("game.ActorMotion").unloadSeconds) or 0
    if actor.job and actor.job.b and not key:match("^carrier%d+$") and (actor.phase=="packing" or actor.phase=="unload") then
        lower=math.sin(math.max(0,math.min(1,1-(actor.timer or 0)/1.4))*math.pi)*.85
    end
    if actor.woodPhase=="gather" or actor.woodPhase=="stack" then lower=math.sin(math.min(1,(actor.woodClock or 0)/1.4)*math.pi)*.85 end
    -- Match the painted hand position in screen space while retaining real
    -- independent cargo geometry and direction. A world-Y-only anchor sinks
    -- a front-facing load below the hands in this oblique camera.
    local right=world.cameraNode.worldRotation*Vector3(1,0,0)
    local forward=world.cameraNode.worldRotation*Vector3(0,0,1)
    local horizontal=({0,-.08,-.13,-.07,0,.07,.13,.08})[direction]
    p.cargoPivot.position=up*(p.height*.40+bob-math.min(1,lower/.65)*.25)+right*horizontal-forward*.20
    p.load.position=Vector3(0,0,0)
    p.load.scale=Vector3(1.05,1.05,1.05)
    Cargo.apply(p,actor)
    Effects.update(world,p,actor,action,x,y)
    Interior.apply(world,p,actor,action)
    -- This runtime does not hide child drawables when only their container
    -- node is disabled. Apply visibility to the actual rendered components.
    local visible=p.node.enabled
    p.billboards.enabled=visible
    p.previous.enabled=visible and p.previousNode.enabled
    p.shadow:GetComponent('StaticModel').enabled=visible and p.shadow.enabled
    for _,node in pairs(p.cargo) do
        node:GetComponent('StaticModel').enabled=visible and p.load.enabled and node.enabled
    end
    for _,node in ipairs(p.impactDust or {}) do
        node:GetComponent('StaticModel').enabled=visible and node.enabled
    end
end
return Worker
