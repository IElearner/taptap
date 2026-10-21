-- Original Blender-authored meshes, exported with Maker's bundled exporter.
-- Character mesh parts are attached to persistent shoulder/elbow/hip/knee
-- pivots; the simulation drives joints, never pre-rendered action pictures.
local Manifest=require "game.VillageModelsManifest"
local ArtSample=require "game.ArtSampleManifest"
for key,spec in pairs(ArtSample.models) do Manifest.models[key]=spec end
local Workers=require "game.WorkerManifest"
for key,spec in pairs(Workers.models) do Manifest.models[key]=spec end
local ConstructionParts=require "game.ConstructionParts"
for key,spec in pairs(ConstructionParts.models) do Manifest.models[key]=spec end
local CargoManifest=require "game.CargoManifest"
for key,spec in pairs(CargoManifest.models) do Manifest.models["cargo_" .. key]=spec end
local Workshops=require "game.WorkshopManifest"
for key,spec in pairs(Workshops.models) do Manifest.models[key]=spec end
for key,spec in pairs(require("game.LivestockManifest").models) do Manifest.models[key]=spec end
local D=require "game.Definitions"
local Farm=require "game.FarmCycle"
local Meals=require "game.Meals"
local BuildingPose=require "game.BuildingPose"
local Models={}
local sizes={store={2,2},house={3,2},mill={2,3},kitchen={3,2},woodcutter={3,2},quarry={3,2},courier={3,2},barracks={3,3},butcher={3,2},ranch={3,2},farm={2,2}}
function Models.visible(node,visible)
    node.enabled=visible
    local drawable=node:GetComponent("StaticModel")
    if drawable then drawable.enabled=visible end
    for _,child in ipairs(node:GetChildren()) do Models.visible(child,visible) end
end
function Models.stage(b)
    if b.complete then return 4 end
    local p=b.progress or 0
    return p<0.18 and 0 or p<0.42 and 1 or p<0.70 and 2 or 3
end
function Models.mesh(world,parent,label,key)
    local spec=assert(Manifest.models[key],"Missing authored model: " .. key)
    world.authoredModels=world.authoredModels or {}
    world.authoredMaterials=world.authoredMaterials or {}
    local node=parent:CreateChild(label)
    local drawable=node:CreateComponent("StaticModel")
    local model=world.authoredModels[key]
    if not model then model=cache:GetResource("Model",spec.model);world.authoredModels[key]=model end
    drawable.model=model
    for i,ref in ipairs(spec.materials) do
        local mat=world.authoredMaterials[ref]
        if not mat then
            mat=cache:GetResource("Material",ref)
            world.authoredMaterials[ref]=mat
        end
        drawable:SetMaterial(i-1,mat)
    end
    drawable.castShadows=true
    return node
end
function Models.building(world,root,b)
    local phase=Models.stage(b)
    local canonical=sizes[b.kind]
    -- Existing saves retain their reserved land. New games use canonical sizes.
    local shape=root:CreateChild("AuthoredBuilding")
    local fit=BuildingPose.fit(b)
    shape.scale=Vector3((b.footprintW or 1)/canonical[1]*fit,1,(b.footprintH or 1)/canonical[2]*fit)
    shape.rotation=Quaternion(BuildingPose.yaw(b),Vector3.UP)
    if not b.complete and b.buildPoints and b.kind~="farm" then
        local stock={wood=0,stone=0}
        for _,p in ipairs(b.buildPoints) do
            if p.work>=p.required-.000001 then
                for _,prefix in ipairs(b.kind=="courier" and {"courier","courier_main"} or {b.kind}) do
                    local key=prefix.."_site_"..p.part
                    if Manifest.models[key] then Models.mesh(world,shape,"CompletedPoint"..p.id..prefix,key) end
                end
            elseif require("game.ConstructionSites").supplied(b,p.phase,p.resource) then
                stock[p.resource]=stock[p.resource]+p.amount
            end
        end
        local w,h=canonical[1],canonical[2]
        for i=1,math.min(6,math.ceil(stock.wood)) do
            local col=(i-1)%2;local row=math.floor((i-1)/2)
            world:part(shape,"SuppliedPlank","Box",world:material(171,126,75),-w*.32+col*.15,.06+row*.035,-h*.5+.19,.13,.027,.40)
        end
        for i=1,math.min(5,math.ceil(stock.stone)) do
            world:part(shape,"SuppliedStone","Sphere",world:material(146,143,130),-w*.08+(i%2)*.12,.075+math.floor((i-1)/2)*.045,-h*.5+.18,.14,.09,.14)
        end
        world.buildings[b.id].stage=phase
        world.buildings[b.id].authored=true
        return
    end
    if b.kind=="farm" then
        local stage=b.complete and Farm.stage(b,D.buildings.farm.period) or "seed"
        if b.complete then Models.mesh(world,shape,"CropMesh","field_" .. stage) end
        if phase>0 then
            local w,h=b.footprintW or 1,b.footprintH or 1
            -- Adjacent plots continue to share their outer boundary only.
            for _,edge in ipairs(Farm.exposedEdges(world.sim,b)) do
                local built=b.complete or not b.buildPoints
                for _,p in ipairs(b.buildPoints or {}) do if p.side==edge.side and p.work>=p.required-.000001 then built=true end end
                if built then
                local x=edge.x-b.x+(w-1)*0.5
                local z=b.y-edge.y-(h-1)*0.5
                local vertical=edge.side=="east" or edge.side=="west"
                local dx=edge.side=="east" and 0.48 or edge.side=="west" and -0.48 or 0
                local dz=edge.side=="north" and 0.48 or edge.side=="south" and -0.48 or 0
                local gate=edge.side=="south" and edge.x==b.x and edge.y==b.y
                for _,height in ipairs({0.20,0.32}) do
                    if gate then
                        for _,sign in ipairs({-1,1}) do
                            world:part(root,"FenceRail","Box",world:material(156,117,67),x+sign*.36,height,z+dz,.24,.025,.025)
                        end
                    else
                        world:part(root,"FenceRail","Box",world:material(156,117,67),x+dx,height,z+dz,vertical and 0.025 or 0.98,0.025,vertical and 0.98 or 0.025)
                    end
                end
                world:part(root,"FencePost","Cylinder",world:material(113,78,43),x+dx,0.20,z+dz,0.045,0.38,0.045)
                end
            end
        end
    elseif b.kind=="courier" then
        Models.mesh(world,shape,"MainHall","courier_main_" .. phase)
        Models.mesh(world,shape,"LoadingBay","courier_" .. phase)
    else
        Models.mesh(world,shape,"ArchitectureMesh",b.kind .. "_" .. phase)
        if b.kind=="mill" and b.complete then
            local wheel=Models.mesh(world,shape,"WaterWheel","waterwheel")
            wheel.position=Vector3(-0.64,0.57,0.28)
            world.buildings[b.id].wheel=wheel
        end
    end
    if b.complete then require("game.WorkshopLife").create(world,b,shape) end
    world.buildings[b.id].stage=phase
    world.buildings[b.id].authored=true
end
function Models.person(world,key,profile)
    local id=profile.id
    if not Manifest.models[(id or "").."_torso"] then id=({lumberjack="blue-man",herder="ochre-woman"})[id] or id end
    if key:sub(1,5)=="enemy" then id="bandit" end
    if not id then id=profile.gender=="female" and "guard-woman" or "guard-man" end
    local root=world.scene:CreateChild("Villager_" .. key)
    local body=root:CreateChild("UpperBody");body.position=Vector3(0,.33,0)
    local torso=Models.mesh(world,body,"Torso",id .. "_torso");torso.position=Vector3(0,0.15,0)
    local neck=world:part(root,"Neck","Cylinder",world:material(176,120,79),0,0.606,0,0.038,0.050,0.038)
    local head=Models.mesh(world,root,"Head",id .. "_head");head.position=Vector3(0,0.665,0)
    local shoulders,elbows,hips,knees,hands,feet={},{},{},{},{},{}
    for i,sign in ipairs({-1,1}) do
        local hip=root:CreateChild("Hip" .. i);hip.position=Vector3(sign*0.048,0.33,0)
        Models.mesh(world,hip,"Thigh",id .. "_thigh")
        local knee=hip:CreateChild("Knee");knee.position=Vector3(0,-0.155,0)
        Models.mesh(world,knee,"Shin",id .. "_shin")
        if Manifest.models[id .. "_foot"] then
            feet[i]=Models.mesh(world,knee,"Foot",id .. "_foot");feet[i].position=Vector3(0,-.135,0)
        end
        local shoulder=body:CreateChild("Shoulder" .. i);shoulder.position=Vector3(sign*0.104,0.235,0)
        Models.mesh(world,shoulder,"UpperArm",id .. "_upperarm")
        local elbow=shoulder:CreateChild("Elbow");elbow.position=Vector3(0,-0.125,0)
        Models.mesh(world,elbow,"Forearm",id .. "_forearm")
        local hand=elbow:CreateChild("Wrist");hand.position=Vector3(0,-.111,.005)
        if Manifest.models[id .. "_hand"] then
            local skin=Models.mesh(world,hand,"Grip",id .. "_hand")
            if i==2 then skin.scale=Vector3(-1,1,1) end
        end
        hands[i]=hand
        shoulders[i],elbows[i],hips[i],knees[i]=shoulder,elbow,hip,knee
    end
    local tool=hands[2]:CreateChild("Tool");tool.position=Vector3(0,.111,-.005)
    local tools={}
    for _,name in ipairs({"hammer","axe","hoe","sickle","watering","chopsticks"}) do
        tools[name]=Models.mesh(world,tool,name,"tool_" .. name)
    end
    local mallet=tool:CreateChild("RoadMallet")
    world:part(mallet,"MalletHandle","Cylinder",world:material(156,113,64),0,-.195,0,.016,.23,.016)
    world:part(mallet,"MalletHead","Box",world:material(118,83,45),0,-.30,0,.11,.055,.06)
    tools.mallet=mallet
    local bowl=Models.mesh(world,hands[1],"MealBowl","tool_bowl");bowl.position=Vector3(0,.12,-.025)
    local load=body:CreateChild("CarriedLoad")
    local crate=world:part(load,"Crate","Box",world:material(140,107,61),0,.015,0,0.27,0.17,0.16)
    local cargo=require("game.CargoModels").add(world,load,{crate=crate},Models.mesh)
    local planks,sacks,stoneSack=cargo.planks,cargo.sacks,cargo.stoneSack
    local drops={}
    for i=1,4 do drops[i]=world:part(root,"PourWater","Cylinder",world:material(112,164,176),0,0,0,.006,.035,.006) end
    return {node=root,body=body,torso=torso,head=head,neck=neck,shoulders=shoulders,elbows=elbows,hips=hips,knees=knees,hands=hands,feet=feet,waterDrops=drops,tool=tool,tools=tools,bowl=bowl,load=load,cargo=cargo,planks=planks,sacks=sacks,crate=crate,stoneSack=stoneSack,authored=true,modelId=id}
end
return Models
