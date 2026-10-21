-- Working positions, visible inventories and articulated animals share the
-- architecture transform. Nothing is drawn merely because a building exists.
local Pose=require "game.BuildingPose"
local D=require "game.Definitions"
local Ranch=require "game.RanchCycle"
local Cargo=require "game.Cargo"
local PigArt=require "game.PigArt"
local Routine=require 'game.WorkRoutine'
local Smoke=require 'game.ChimneySmoke'
local Entrance=require 'game.RanchEntrance'
local BuildingEntrance=require 'game.BuildingEntrance'
local Life={}
function Life.hidden(b,a)
    if a.meal then
        local m=a.meal
        local progress=m.phase=='leaveWork' and 1-m.timer/require('game.Meals').workDoorSeconds or
            m.phase=='returnWork' and m.timer/require('game.Meals').workDoorSeconds or nil
        return progress~=nil and (a.workPresence or 0)<.22 and progress<.22
    end
    if b.kind=='ranch' then return Ranch.presence(b)<.22 end
    return Routine.indoor(b.kind) and (a.workPresence or 0)<.22
end
function Life.position(b,a,world)
    local Meals=require 'game.Meals'
    if not a.meal and b.kind=='ranch' then
        local t=Ranch.presence(b)
        if world then return Entrance.caretaker(world,b,t,a.slot or 1) end
        local slot=(a.slot or 1)-1
        return Meals.porchPoint(b,-.94+(2.04-.38*slot)*t,.80+(.05+.27*slot)*t)
    end
    if not a.meal and Routine.indoor(b.kind) then
        local t=math.max(0,((a.workPresence or 0)-.22)/.78)
        local slot=(a.slot or 1)-1
        return Meals.porchPoint(b,.20-(1.15-.50*slot)*t,.88+(.30+.16*slot)*t)
    end
    if a.meal then
        local m=a.meal
        local t=m.phase=='leaveWork' and 1-m.timer/Meals.workDoorSeconds or
            m.phase=='returnWork' and m.timer/Meals.workDoorSeconds or nil
        if not t then return a.x,a.y end
        t=math.max(0,math.min(1,t))
        local dx=b.kind=='ranch' and -.94 or .20
        local x,y=Meals.porchPoint(b,dx,.88)
        if b.kind=='ranch' and world then x,y=Entrance.caretaker(world,b,0,a.slot or 1) end
        if Routine.indoor(b.kind) and (a.workPresence or 0)>.22 then
            local rest=((a.workPresence or 0)-.22)/.78
            x,y=Meals.porchPoint(b,.20-1.15*rest,.88+.30*rest)
        end
        return x+(a.x-x)*t,y+(a.y-y)*t
    end
    local offsets={butcher={0,.85},mill={.46,.90},quarry={.65,.85}}
    local p=offsets[b.kind]
    if not p then return a.x,a.y end
    return Pose.point(b,p[1],p[2])
end

function Life.action(b,a)
    if a.meal then return a.meal.phase=="eat" and "eat" or nil end
    if b.kind=="ranch" then return Ranch.action(b) end
    if not Routine.atWork(a,b.kind) then return nil end
    if b.kind=="kitchen" and b.inputs>0 and b.buffer<=8-D.buildings.kitchen.amount then return "cook" end
    if b.kind=="butcher" and b.inputs>0 and b.buffer<=8-D.buildings.butcher.amount then return "butcher" end
    if b.kind=="quarry" and b.buffer<=5 then return "hammer" end
    if b.kind=="mill" and b.inputs>0 then return "mill" end
    return nil
end
function Life.create(world,b,shape)
    local record=world.buildings[b.id]
    BuildingEntrance.create(world,b,record)
    record.stockRoot=shape:CreateChild("VisibleInventory")
    if b.kind=="kitchen" then
        require('game.FrontDining').createSettings(world,record)
        record.chairs={}
        for seat=1,4 do
            local chair=require("game.VillageModels").mesh(world,shape,"DiningChair"..seat,"dining_chair")
            chair.position=Vector3(((seat-1)%2-.5)*.94,.11,-(math.floor((seat-1)/2)-.5)*.72-.40)
            record.chairs[seat]=chair
        end
        record.smoke=Smoke.create(record.node)
    elseif b.kind=="butcher" then
        record.ingredients=shape:CreateChild("CuttingIngredients")
        for i=1,3 do world:part(record.ingredients,"FreshCut","Sphere",world:material(164,95,72),-.22+i*.10,.57,-.16,.09,.04,.07) end
    end
    if b.kind=="ranch" then
        Entrance.create(world,record)
        record.pigs={}
        local mesh=require("game.VillageModels").mesh
        for i=1,3 do
            local root=shape:CreateChild("Pig"..i)
            local body=mesh(world,root,"PigBody","pig_body");body.position=Vector3(0,.34,0)
            local head=mesh(world,root,"PigHead","pig_head");head.position=Vector3(0,.31,.25)
            local legs={}
            for j,p in ipairs({{-.128,-.19},{.128,-.19},{-.128,.20},{.128,.20}}) do
                local leg=mesh(world,root,"PigLeg"..j,"pig_leg");leg.position=Vector3(p[1],.27,p[2]);legs[j]=leg
            end
            local tail=mesh(world,root,"PigTail","pig_tail");tail.position=Vector3(0,.35,-.29)
            record.pigs[i]={node=root,head=head,legs=legs,tail=tail}
        end
        record.feedRoot=shape:CreateChild("TroughFeed")
        for i=1,18 do
            world:part(record.feedRoot,"GrainKernel","Sphere",world:material(209,174,91),.18+(i%6)*.12,.17,-.50+math.floor(i/6)*.04,.035,.012,.020)
        end
        record.scatter={}
        for i=1,7 do record.scatter[i]=world:part(shape,"ScatteredFeed","Sphere",world:material(209,174,91),0,0,0,.025,.014,.018) end
    end
end
local function pile(world,root,resource,count,x,z,height,scale)
    local profile=Cargo.profiles[resource]
    if not profile then return end
    local mesh=require("game.VillageModels").mesh
    scale=scale or .67
    for i=1,math.min(count,8) do
        local node=mesh(world,root,"Stock_"..resource.."_"..i,resource=="wood" and "log_bundle" or resource=="livestock" and "pig_crate" or "cargo_"..profile.mesh)
        if node then
            local col=(i-1)%3;local row=math.floor((i-1)/3)
            local bounds=node:GetComponent("StaticModel").model.boundingBox
            local floor=height or .11
            node.position=Vector3(x+col*scale*.28,floor-bounds.min.y*scale+row*((bounds.max.y-bounds.min.y)*scale+.01),z+row*.07)
            node.scale=Vector3(scale,scale,scale)
        end
    end
end
function Life.update(world,b)
    if not b.complete then return end
    local r=world.buildings[b.id]
    if not r or not r.stockRoot then return end
    BuildingEntrance.update(world,b,r)
    if b.kind=="store" then
        -- Supplies awaiting collection sit on the loading step. New arrivals
        -- appear there briefly after the worker has crossed the doorway.
        local queued={}
        local function waiting(job)
            if job and job.inbound and not job.pickedUp and #queued<3 then queued[#queued+1]=job.resource end
        end
        for _,a in ipairs(world.sim.carriers) do waiting(a.job) end
        for _,job in ipairs(world.sim.jobs) do waiting(job) end
        local arrival=world.sim.warehouseDisplay
        if arrival and world.sim.elapsed-arrival.at>=4 then arrival=nil end
        local signature=table.concat(queued,",")..":"..(arrival and arrival.resource..":"..arrival.at or "")
        if r.inventorySignature~=signature then
            r.inventorySignature=signature;r.stockRoot:RemoveAllChildren()
            for i,resource in ipairs(queued) do pile(world,r.stockRoot,resource,1,-.72+(i-1)*.25,-1.04,.11) end
            if arrival then pile(world,r.stockRoot,arrival.resource,math.min(3,arrival.amount),-.12,-1.04,.11) end
        end
        return
    end
    local def=D.buildings[b.kind]
    local signature=(b.buffer or 0)..":"..(b.inputs or 0)..":"..(b.mealStock or 0)
    for _,resource in ipairs({"grain","flour","livestock","meat"}) do signature=signature..":"..(b.inputGoods and b.inputGoods[resource] or 0) end
    if r.inventorySignature~=signature then
        r.inventorySignature=signature;r.stockRoot:RemoveAllChildren()
        local inputX=b.kind=='kitchen' and 1.02 or b.kind=='ranch' and -1.20 or .62
        local inputZ=b.kind=='kitchen' and -1.18 or b.kind=='ranch' and -.92 or -.95
        local stockScale=(b.kind=='kitchen' or b.kind=='ranch') and .4 or nil
        if def.output and b.buffer>0 then pile(world,r.stockRoot,def.output,b.buffer,-1.05,-.73,nil,b.kind=='kitchen' and .4 or nil) end
        if def.input and b.inputs>0 then
            local typed=false;local at=0
            for _,resource in ipairs({"grain","flour","livestock","meat"}) do
                local count=b.inputGoods and b.inputGoods[resource] or 0
                if count>0 then pile(world,r.stockRoot,resource,count,inputX,inputZ-at*.22,nil,stockScale);typed=true;at=at+1 end
            end
            if not typed then pile(world,r.stockRoot,def.input,b.inputs,inputX,inputZ,nil,stockScale) end
        end
        if b.kind=="kitchen" and (b.mealStock or 0)>0 then pile(world,r.stockRoot,"food",b.mealStock,-1.30,-1.05,.11,.40) end
    end
    if r.chairs then
        require('game.FrontDining').updateSettings(world,b,r)
        for seat,chair in ipairs(r.chairs) do
            local sx,sy=require('game.Meals').seatPosition(b,seat)
            chair.worldPosition=Vector3(sx-10,.11,9-sy)
            local occupant=require("game.Meals").occupant(world.sim,b.id,seat)
            local m=occupant and occupant.meal
            local illustrated=occupant and occupant.workerLook~=nil
            local Meals=require("game.Meals")
            local sitting=m and (m.phase=="eat" or m.phase=="enter" and m.timer<Meals.seatTransitionSeconds or m.phase=="exit" and m.timer>Meals.doorwaySeconds-Meals.seatTransitionSeconds)
            chair.enabled=false -- the new enclosed hall owns its indoor furniture
            chair:GetComponent('StaticModel').enabled=false
        end
        local cooking=b.inputs>0 and (b.workRate or 0)>0 and b.buffer<=8-D.buildings.kitchen.amount
        Smoke.update(world,b,r.smoke,cooking)
    end
    if r.ingredients then r.ingredients.enabled=b.inputs>0 and (b.activeWorkers or 0)>0 end
    if not r.pigs then return end
    r.feedRoot.enabled=(b.feedRemaining or 0)>0
    local Art=require 'game.PaintedArchitecture'
    for i,n in ipairs(r.feedRoot:GetChildren()) do
        n:GetComponent('StaticModel').enabled=r.feedRoot.enabled
        n.worldPosition=Art.groundPoint(world,b,.805+(i%6)*.018,.555+math.floor((i-1)/6)*.008,.17)
    end
    local clock=world.sim.elapsed
    local dt=math.max(0,math.min(.25,clock-(r.lastAnimalTime or clock)));r.lastAnimalTime=clock
    local feeding=(b.feedClock or 0)>0 and (b.activeWorkers or 0)>0
    local atTrough=feeding or (b.feedRemaining or 0)>Ranch.feedSeconds-3
    local gateOpen=b.ranchPhase=='exit' or b.ranchPhase=='return'
    for _,a in pairs(world.sim.workers) do
        if a.building==b.id and a.meal and (a.meal.phase=="leaveWork" or a.meal.phase=="returnWork") then gateOpen=true end
    end
    r.gateAngle=(r.gateAngle or 0)+((gateOpen and 82 or 0)-(r.gateAngle or 0))*math.min(1,dt*4)
    Entrance.update(world,b,r,r.gateAngle)
    for i,pig in ipairs(r.pigs) do
        local t=clock*.26+i*2.2
        -- Each pig owns a separate lane in the painted paddock. Convert
        -- illustration points to real ground before calculating speed/yaw.
        local u=.555+(i-1)*.135+math.sin(t)*.027
        local v=.650+math.sin(t*.73+i)*.008
        if atTrough then u,v=.565+(i-1)*.125,.642 end
        local target=Art.groundPoint(world,b,u,v,.025)
        pig.ground=pig.ground or target
        local dx,dz=target.x-pig.ground.x,target.z-pig.ground.z
        local distance=math.sqrt(dx*dx+dz*dz)
        local step=math.min(distance,dt*.19)
        if distance>.00001 then
            pig.ground=Vector3(pig.ground.x+dx/distance*step,.025,pig.ground.z+dz/distance*step)
        end
        pig.distance=(pig.distance or 0)+step
        local targetYaw=distance>.02 and math.deg(math.atan(dx,dz)) or atTrough and 0 or (pig.yaw or 0)
        local turn=(targetYaw-(pig.yaw or targetYaw)+180)%360-180
        pig.yaw=(pig.yaw or targetYaw)+turn*math.min(1,dt*3)
        pig.plotWidth=b.footprintW or 1
        pig.node.worldPosition=pig.ground
        pig.node.worldRotation=Quaternion(pig.yaw,Vector3.UP)
        pig.node.worldScale=Vector3.ONE
        pig.x,pig.z=pig.node.position.x,pig.node.position.z
        pig.penU,pig.penV=u,v
        local nibbling=atTrough and distance<.12
        if nibbling then pig.yaw=pig.yaw+((0-pig.yaw+180)%360-180)*math.min(1,dt*2) end
        pig.head.position=Vector3(0,nibbling and .27 or .31,.25)
        pig.head.rotation=Quaternion(nibbling and 30+math.sin(clock*3+i)*8 or math.sin(t*2)*5,math.sin(t)*5,0)
        for j,leg in ipairs(pig.legs) do
            leg.rotation=Quaternion(step>.00001 and math.sin(pig.distance/.18*math.pi*2+((j==1 or j==4) and 0 or math.pi))*18 or 0,0,0)
        end
        pig.tail.rotation=Quaternion(0,0,math.sin(clock*2+i)*12)
        PigArt.update(world,pig,i,step>.00001,nibbling)
    end
    for i,n in ipairs(r.scatter) do
        n.enabled=feeding
        n:GetComponent('StaticModel').enabled=feeding
        local t=((Ranch.scatterSeconds-(b.feedClock or 0))*.8+i*.11)%1
        local first=Art.groundPoint(world,b,.765,.83,.44)
        local last=Art.groundPoint(world,b,.85+(i%3-1)*.018,.55,.17)
        n.worldPosition=first+(last-first)*t+Vector3(0,math.sin(t*math.pi)*.15,0)
    end
end
return Life
