-- Original Blender-authored meshes, exported with Maker's bundled exporter.
-- Character mesh parts are attached to persistent shoulder/elbow/hip/knee
-- pivots; the simulation drives joints, never pre-rendered action pictures.
local Manifest=require "game.VillageModelsManifest"
local Craft=require "game.CraftMaterials"
local D=require "game.Definitions"
local Farm=require "game.FarmCycle"
local Meals=require "game.Meals"
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
            local desc=Manifest.materials[ref]
            if desc and desc.style then
                mat=Craft.apply(mat,desc.style)
                if desc.style~="cloth" then
                    local c=desc.color
                    mat:SetShaderParameter("MatDiffColor",Variant(Color(c[1],c[2],c[3])))
                end
            end
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
    shape.scale=Vector3((b.footprintW or 1)/canonical[1],1,(b.footprintH or 1)/canonical[2])
    if b.kind=="farm" then
        local stage=b.complete and Farm.stage(b,D.buildings.farm.period) or "seed"
        Models.mesh(world,shape,"CropMesh","field_" .. stage)
        if phase>0 then
            local w,h=b.footprintW or 1,b.footprintH or 1
            -- Adjacent plots continue to share their outer boundary only.
            for _,edge in ipairs(Farm.exposedEdges(world.sim,b)) do
                local x=edge.x-b.x+(w-1)*0.5
                local z=b.y-edge.y-(h-1)*0.5
                local vertical=edge.side=="east" or edge.side=="west"
                local dx=edge.side=="east" and 0.48 or edge.side=="west" and -0.48 or 0
                local dz=edge.side=="north" and 0.48 or edge.side=="south" and -0.48 or 0
                for _,height in ipairs({0.20,0.32}) do
                    world:part(root,"FenceRail","Box",world:material(156,117,67),x+dx,height,z+dz,vertical and 0.025 or 0.98,0.025,vertical and 0.98 or 0.025)
                end
                world:part(root,"FencePost","Cylinder",world:material(113,78,43),x+dx,0.20,z+dz,0.045,0.38,0.045)
            end
        end
    elseif b.kind=="courier" then
        Models.mesh(world,shape,"MainHall","courier_main_" .. phase)
        Models.mesh(world,shape,"LoadingBay","courier_" .. phase)
    else
        local opened=b.kind=="kitchen" and b.complete and Meals.occupancy(world.sim,b.id)>0
        Models.mesh(world,shape,"ArchitectureMesh",b.kind .. "_" .. (opened and "open" or phase))
        if b.kind=="mill" and b.complete then
            local wheel=Models.mesh(world,shape,"WaterWheel","waterwheel")
            wheel.position=Vector3(-0.64,0.57,0.28)
            world.buildings[b.id].wheel=wheel
        end
    end
    world.buildings[b.id].stage=phase
    world.buildings[b.id].authored=true
end
function Models.person(world,key,profile)
    local id=profile.id
    if key:sub(1,5)=="enemy" then id="bandit" end
    if not id then id=profile.gender=="female" and "guard-woman" or "guard-man" end
    local root=world.scene:CreateChild("Villager_" .. key)
    local torso=Models.mesh(world,root,"Torso",id .. "_torso");torso.position=Vector3(0,0.48,0)
    local head=Models.mesh(world,root,"Head",id .. "_head");head.position=Vector3(0,0.665,0)
    local shoulders,elbows,hips,knees={},{},{},{}
    for i,sign in ipairs({-1,1}) do
        local hip=root:CreateChild("Hip" .. i);hip.position=Vector3(sign*0.048,0.33,0)
        Models.mesh(world,hip,"Thigh",id .. "_thigh")
        local knee=hip:CreateChild("Knee");knee.position=Vector3(0,-0.155,0)
        Models.mesh(world,knee,"Shin",id .. "_shin")
        local shoulder=root:CreateChild("Shoulder" .. i);shoulder.position=Vector3(sign*0.104,0.565,0)
        Models.mesh(world,shoulder,"UpperArm",id .. "_upperarm")
        local elbow=shoulder:CreateChild("Elbow");elbow.position=Vector3(0,-0.125,0)
        Models.mesh(world,elbow,"Forearm",id .. "_forearm")
        shoulders[i],elbows[i],hips[i],knees[i]=shoulder,elbow,hip,knee
    end
    local tool=elbows[2]:CreateChild("Tool")
    local tools={}
    for _,name in ipairs({"hammer","axe","hoe","sickle","watering","chopsticks"}) do
        tools[name]=Models.mesh(world,tool,name,"tool_" .. name)
    end
    local bowl=Models.mesh(world,elbows[1],"MealBowl","tool_bowl")
    local load=root:CreateChild("CarriedLoad")
    local planks=load:CreateChild("Planks")
    for i=1,3 do world:part(planks,"Plank","Box",world:material(188,146,89),0,0.46+i*0.03,0.20,0.47,0.028,0.12) end
    local sacks=load:CreateChild("Sacks")
    for i=1,2 do world:part(sacks,"Sack","Sphere",world:material(190,167,116),(i-1.5)*0.12,0.51,0.19,0.15,0.22,0.16) end
    local crate=world:part(load,"Crate","Box",world:material(140,107,61),0,0.49,0.20,0.29,0.20,0.18)
    return {node=root,torso=torso,head=head,shoulders=shoulders,elbows=elbows,hips=hips,knees=knees,tool=tool,tools=tools,bowl=bowl,load=load,planks=planks,sacks=sacks,crate=crate,authored=true,modelId=id}
end
return Models
