-- Authored architecture and directional character animation share one depth-tested world.
-- The orthographic camera matches the existing map/touch coordinate system.
local D=require "game.Definitions"
local Characters=require "game.Characters"
local Farm=require "game.FarmCycle"
local Meals=require "game.Meals"
local Craft=require "game.CraftMaterials"
local VillageModels=require "game.VillageModels"
local Motion=require "game.ActorMotion"
local BuildingPose=require "game.BuildingPose"
local ConstructionSites=require "game.ConstructionSites"
local Cargo=require "game.Cargo"
local DirectionalWorker=require "game.DirectionalWorker"
local WorkshopLife=require "game.WorkshopLife"
local Wilderness=require "game.Wilderness"
local PaintedArchitecture=require "game.PaintedArchitecture"
local World={}
local UP=Vector3(0,1,0)
local function position(x,y,height) return Vector3(x-10,height or 0,9-y) end

function World.new(sim)
    local developmentCache=os.getenv and os.getenv("VILLAGE_SHADER_CACHE")
    if developmentCache and developmentCache~="" then
        graphics.shaderCacheDir=developmentCache
        cache:AddResourceDir(developmentCache..'/',true)
    end
    local self={scene=Scene(),buildings={},retiredBuildings={},actors={},trees={},stumps={},roads={},chunks={},materials={},surfaces={},models={},clock=0}
    -- Literal resource references let Maker include the engine meshes in Web builds.
    self.models.Box=cache:GetResource("Model","Models/Box.mdl")
    self.models.Sphere=cache:GetResource("Model","Models/Sphere.mdl")
    self.models.Cylinder=cache:GetResource("Model","Models/Cylinder.mdl")
    self.models.Cone=cache:GetResource("Model","Models/Cone.mdl")
    self.sim=sim
    self.scene:CreateComponent("Octree")
    local lighting=self.scene:CreateChild("VillageDaylight")
    lighting:LoadXML(cache:GetResource("XMLFile","lighting/VillageDay.xml"):GetRoot())
    local zone=lighting:GetComponent("Zone",true)
    zone.depthFogStart,zone.depthFogEnd=80,160
    local sun=lighting:GetComponent("Light",true)
    sun.node.direction=Vector3(-0.55,-1,0.7)
    sun.brightness=1.85
    sun.color=Color(1,0.96,0.86)
    sun.castShadows=true
    sun.shadowBias=BiasParameters(0.00025,0.5)
    sun.shadowCascade=CascadeParameters(10,30,70,0,0.8)
    self.cameraNode=self.scene:CreateChild("VillageCamera")
    self.camera=self.cameraNode:CreateComponent("Camera")
    self.camera.orthographic=true
    self.camera.autoAspectRatio=false
    self.camera.farClip=180
    renderer:SetViewport(0,Viewport:new(self.scene,self.camera))

    function self:material(r,g,b)
        local key=r .. ":" .. g .. ":" .. b
        if not self.materials[key] then
            local mat=Craft.material(r,g,b)
            self.materials[key]=mat
        end
        return self.materials[key]
    end
    function self:part(parent,name,shape,mat,x,y,z,sx,sy,sz,rotation)
        local node=parent:CreateChild(name)
        node.position=Vector3(x,y,z)
        node.scale=Vector3(sx,sy,sz)
        if rotation then node.rotation=rotation end
        local drawable=node:CreateComponent("StaticModel")
        if not self.models[shape] then self.models[shape]=cache:GetResource("Model","Models/" .. shape .. ".mdl") end
        drawable.model=self.models[shape]
        local style=Craft.style(name)
        if style then
            local key=tostring(mat) .. style
            if not self.surfaces[key] then self.surfaces[key]=Craft.apply(mat,style) end
            drawable.material=self.surfaces[key]
        else drawable.material=mat end
        drawable.castShadows=true
        return node
    end
    ---@param a Vector3
    ---@param b Vector3
    function self:beam(parent,name,mat,a,b,width)
        local delta=b-a
        local len=delta:Length()
        local n=self:part(parent,name,"Box",mat,0,0,0,width,len,width)
        n.position=(a+b)*0.5
        n.rotation=Quaternion(UP,delta/len)
        return n
    end
    local ground=self:part(self.scene,"Meadow","Box",self:material(155,173,125),0,-0.1,0,180,0.16,180)
    ground:GetComponent("StaticModel").castShadows=false
    self.ghost=self.scene:CreateChild("PlacementPreview")
    self.selection=self.scene:CreateChild("Selection")
    self.revision=-1

    function self:terrain(minX,maxX,minY,maxY)
        -- Cache small patches; work and memory stay bounded while panning an infinite map.
        for cy=math.floor(minY/4),math.floor(maxY/4) do for cx=math.floor(minX/4),math.floor(maxX/4) do
            local key=cx .. ":" .. cy
            if not self.chunks[key] then
                local root=self.scene:CreateChild("Terrain_" .. key)
                self.chunks[key]={node=root,x=cx,y=cy}
                for y=cy*4,cy*4+3 do for x=cx*4,cx*4+3 do
                    local terrain=sim:terrain(x,y)
                    if terrain=="water" then
                        local n=self:part(root,"Water","Box",self:material(110,161,170),x-10,-0.015,9-y,1.02,0.04,1.02)
                        n:GetComponent("StaticModel").castShadows=false
                        self.waterMaterial=n:GetComponent('StaticModel').material
                        for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
                            if sim:terrain(x+d[1],y+d[2])~='water' then
                                local bank=self:part(root,'RiverBank','Sphere',self:material(198,187,144),x-10+d[1]*.48,.005,9-y-d[2]*.48,
                                    d[1]~=0 and .18 or 1.08,.035,d[2]~=0 and .18 or 1.08)
                                bank:GetComponent('StaticModel').castShadows=false
                            end
                        end
                    elseif terrain=="grass" or terrain=="forest" then
                        -- A few tiny pebbles replace the high contrast blanket of grass.
                        if (x*19+y*13)%13==0 then
                            self:part(root,"Pebble","Sphere",self:material(165,162,134),x-9.8,0.012,9.2-y,0.09,0.045,0.07)
                        end
                    end
                end end
            end
        end end
        for key,chunk in pairs(self.chunks) do
            if chunk.x<math.floor(minX/4)-2 or chunk.x>math.floor(maxX/4)+2 or chunk.y<math.floor(minY/4)-2 or chunk.y>math.floor(maxY/4)+2 then
                chunk.node:Remove();self.chunks[key]=nil
            end
        end
        local visible={}
        for y=minY,maxY do for x=minX,maxX do
            if sim:standingTree(x,y) and not sim:buildingAt(x,y) then
                local key=x .. ":" .. y
                visible[key]=true
                if not self.trees[key] then
                    self.trees[key]=Wilderness.tree(self,key,x,y)
                end
                Wilderness.occlusion(self,self.trees[key])
            end
        end end
        for key,tree in pairs(self.trees) do
            if not visible[key] then
                local onScreen=tree.x>=minX and tree.x<=maxX and tree.y>=minY and tree.y<=maxY
                if onScreen and sim.felledTrees[key] then
                    if Wilderness.fall(self,tree) then tree.node:Remove();self.trees[key]=nil end
                else tree.node:Remove();self.trees[key]=nil end
            end
        end
        for key in pairs(sim.felledTrees) do
            local x,y=key:match("^(%-?%d+):(%-?%d+)$");x,y=tonumber(x),tonumber(y)
            if x and x>=minX and x<=maxX and y>=minY and y<=maxY and not self.stumps[key] then self.stumps[key]=Wilderness.stump(self,key,x,y) end
        end
        for key,node in pairs(self.stumps) do
            local x,y=key:match("^(%-?%d+):(%-?%d+)$");x,y=tonumber(x),tonumber(y)
            if not x or x<minX or x>maxX or y<minY or y>maxY then node:Remove();self.stumps[key]=nil end
        end
    end

    function self:road(x,y,planned,progress)
        local key=x .. ":" .. y
        local directions={{0,-1,1},{1,0,2},{0,1,4},{-1,0,8}}
        local mask=0
        local connected={}
        for i,d in ipairs(directions) do
            local k=(x+d[1]) .. ":" .. (y+d[2])
            connected[i]=sim.roads[k] or planned and sim:roadSiteAt(x+d[1],y+d[2])
            if connected[i] then mask=mask+d[3] end
        end
        local existing=self.roads[key]
        if existing and existing.planned==planned and existing.mask==mask then return end
        if existing then existing.node:Remove() end
        local node=self.scene:CreateChild("Road_" .. key)
        node.position=position(x,y)
        self.roads[key]={node=node,planned=planned,mask=mask}
        if not planned then
            self.roadArt=self.roadArt or {}
            if not self.roadArt[mask] then
                local material=cache:GetResource('Material','art/v12/road-surface.material'):Clone()
                material:SetShaderParameter('connections',Variant(Vector4(connected[1] and 1 or 0,connected[2] and 1 or 0,connected[3] and 1 or 0,connected[4] and 1 or 0)))
                self.roadArt[mask]=material
            end
            local surface=self:part(node,'PavedSurface','Plane',self.roadArt[mask],0,.031,0,1,1,1)
            surface:GetComponent('StaticModel').castShadows=false
            return
        end
        local road=self:material(planned and 161 or 200,planned and 141 or 196,planned and 106 or 182)
        self:part(node,"RoadCenter","Box",road,0,0.022,0,0.43,0.014,0.43)
        for i,d in ipairs(directions) do if connected[i] then
            self:part(node,"RoadArm","Box",road,d[1]*0.25,0.022,-d[2]*0.25,
                d[1]~=0 and 0.52 or 0.43,0.014,d[2]~=0 and 0.52 or 0.43)
        end end
        -- The painted surface supplies the stones. Hundreds of separate
        -- paver boxes per junction added visual noise and mobile draw calls.
        if planned then
            self:part(node,"SurveyStake","Box",self:material(139,100,56),-0.21,0.10,0.18,0.025,0.23,0.025)
        end
    end

    function self:outline(parent,b,mat,height,stakes)
        local w,h=b.footprintW or 1,b.footprintH or 1
        for _,edge in ipairs(D.edges(b)) do
            local vertical=edge.side=="west" or edge.side=="east"
            local dx=edge.side=="east" and 0.5 or edge.side=="west" and -0.5 or 0
            local dz=edge.side=="north" and 0.5 or edge.side=="south" and -0.5 or 0
            local x=edge.x+(w-1)*0.5+dx
            local z=-edge.y-(h-1)*0.5+dz
            self:part(parent,"PlotBoundary","Box",mat,x,height,z,vertical and 0.022 or 1,0.02,vertical and 1 or 0.022)
            if stakes then self:part(parent,"SurveyStake","Box",mat,x,height+0.10,z,0.035,0.22,0.035) end
        end
    end
    function self:building(b)
        local old=self.buildings[b.id]
        local signature=tostring(VillageModels.stage(b)) .. ":" .. tostring(b.complete) .. ":" ..
            (b.kind=="farm" and Farm.stage(b,D.buildings.farm.period) .. ":" .. sim.roadCount or "") .. ":" ..
            ((b.progress or 0)>0 and ":started" or ":plan") ..
            (not b.complete and ":" .. ConstructionSites.signature(b) or "")
        if old and old.signature==signature then return end
        local transition=old and not old.painted and PaintedArchitecture.supports(b)
        if old then
            if transition then self.retiredBuildings[#self.retiredBuildings+1]={node=old.node,at=sim.elapsed}
            else old.node:Remove() end
        end
        local root=self.scene:CreateChild("Building_" .. b.id .. "_" .. b.kind)
        local w,h=b.footprintW or 1,b.footprintH or 1
        root.position=position(b.x-(w-1)*0.5,b.y-(h-1)*0.5)
        self.buildings[b.id]={node=root,signature=signature,artBlendAt=transition and sim.elapsed or nil}
        local delivered=false
        for _,p in ipairs(b.buildPoints or {}) do if p.delivered then delivered=true end end
        if not b.complete and (b.progress or 0)==0 and not delivered then
            self:outline(root,b,self:material(189,129,62),0.06,true)
            self.buildings[b.id].planned=true
            return
        end
        VillageModels.building(self,root,b)
        if PaintedArchitecture.supports(b) then PaintedArchitecture.create(self,root,b) end
        if not b.complete and not b.buildPoints then
            for stack=1,math.min(3,b.deliveredLoads or 0) do
                for plank=1,math.max(1,math.ceil(4*(1-(b.progress or 0)))) do
                    self:part(root,"DeliveredPlank","Box",self:material(171,126,75),
                        -w/2+.24+(stack-1)*.18,.06+plank*.025,-h/2+.16,.15,.022,.34)
                end
            end
        end
    end

    function self:person(key,actor,profile,action,x,y,seed,hidden)
        -- Simulation predicates naturally yield false after a meal/assignment.
        -- False means idle, not "unsupported animation / change body model".
        action=action or nil
        local directional=DirectionalWorker.supports(profile,key,action)
        local previous=self.actors[key]
        if previous and (previous.directional==true)~=directional then
            previous.node:Remove();self.actors[key]=nil
        end
        if directional then
            DirectionalWorker.update(self,key,actor,profile,action,x,y,seed,hidden)
            return
        end
        local person=self.actors[key]
        if not person then
            person=VillageModels.person(self,key,profile)
            self.actors[key]=person
        end
        person.node.enabled=not hidden
        person.seen=true
        person.actor,person.profile,person.action=actor,profile,action
        if sim.paused and person.poseTime==sim.elapsed and person.poseAction==action and
            person.poseTimer==actor.timer and person.poseCarrying==actor.carrying and person.poseResource==Cargo.resource(actor) and person.lastX==x and person.lastY==y then return end
        person.poseTime,person.poseAction,person.poseTimer,person.poseCarrying=sim.elapsed,action,actor.timer,actor.carrying
        person.poseResource=Cargo.resource(actor)
        local dx,dy=x-(person.lastX or x),y-(person.lastY or y)
        local travelled=math.sqrt(dx*dx+dy*dy)
        local walking=travelled>0.00001 and travelled<1
        person.lastX,person.lastY=x,y
        person.distance=(person.distance or 0)+(walking and travelled or 0)
        local clock=sim.elapsed+(seed or 0)*.17
        ---@type number
        local yaw=({se=90,nw=-90,sw=180,ne=0})[actor.facing or "sw"]
        if walking then yaw=math.deg(math.atan(dx,-dy)) end
        if (action=="hammer" or actor.phase=="unload") and actor.job then
            yaw=({south=0,north=180,west=90,east=-90})[actor.job.side] or yaw
            if actor.job.kind=="road" then yaw=math.deg(math.atan(actor.job.x-x,y-actor.job.y)) end
            local site=actor.job.kind=="building" and sim.buildings[actor.job.building]
            if site and actor.job.workX then
                local tx,ty=BuildingPose.workTarget(site,actor.job)
                yaw=math.deg(math.atan(tx-x,y-ty))
            end
        end
        if action=="eat" and actor.meal then
            local hall=sim.buildings[actor.meal.target]
            yaw=(((actor.meal.seat or 1)-1)%2==0 and 90 or -90)+(hall and BuildingPose.yaw(hall) or 0)
        end
        if action=="chop" and actor.treeX then yaw=math.deg(math.atan(actor.treeX-x,y-actor.treeY)) end
        if action=="plow" or action=="tend" or action=="water" or action=="harvest" then
            yaw=math.floor((actor.workClock or 0)/4)%2==0 and 90 or -90
        end
        person.node.position=position(x,y,action=="eat" and -.15 or 0)
        person.node.rotation=Quaternion(yaw,UP)
        if action=="hammer" or actor.phase=="unload" then
            person.node.position=person.node.position+person.node.rotation*Vector3(0,0,.28)
        end
        local toolName=({hammer="hammer",chop="axe",plow="hoe",tend="hoe",harvest="sickle",water="watering",eat="chopsticks"})[action]
        if toolName=="hammer" and actor.job and actor.job.kind=="road" then toolName="mallet" end
        person.tool.enabled=toolName~=nil
        for name,node in pairs(person.tools) do VillageModels.visible(node,name==toolName) end
        VillageModels.visible(person.bowl,action=="eat")
        Cargo.apply(person,actor)
        local workClock=(action=="plow" or action=="tend" or action=="water" or action=="harvest") and (actor.workClock or clock) or clock
        Motion.apply(person,actor,action,walking,workClock,person.distance)
        for i,drop in ipairs(person.waterDrops) do
            VillageModels.visible(drop,action=="water" and person.pouring==true)
            if action=="water" then
                ---@type Node
                local hand=person.hands[2]
                local spout=hand.worldPosition+hand.worldRotation*Vector3(.14,.001,.020)
                drop.worldPosition=spout+Vector3(0,-((workClock*1.3+i*.07)%.28),0)
            end
        end

    end

    function self:update(camera,layout,mode,ghost,selected)
        local zoom=camera.zoom
        local center=Vector3(-camera.x/(56*zoom),0,camera.y/(42*zoom))
        self.cameraNode.position=center+Vector3(0,30,-math.sqrt(700))
        self.cameraNode:LookAt(center)
        self.camera.orthoSize=layout.h/(56*zoom)
        -- Assign the aspect after the scalar orthographic size: the latter
        -- resets it, which otherwise stretches the view and misaligns labels.
        self.camera.aspectRatio=layout.w/layout.h
        local halfX=layout.w/(112*zoom)+3
        local halfY=layout.h/(84*zoom)+3
        local cx,cy=10+center.x,9-center.z
        local minX,maxX,minY,maxY=math.floor(cx-halfX),math.ceil(cx+halfX),math.floor(cy-halfY),math.ceil(cy+halfY)
        self:terrain(minX,maxX,minY,maxY)
        if self.waterMaterial then self.waterMaterial:SetUVOffset(Vector2((sim.elapsed*.004)%1,(sim.elapsed*.0015)%1)) end
        if self.revision~=sim.roadCount or self.planCount~=#sim.pendingRoads then
            for _,r in pairs(self.roads) do r.node:Remove() end
            self.roads={};self.revision=sim.roadCount;self.planCount=#sim.pendingRoads
        end
        for key in pairs(sim.roads) do
            local x,y=key:match("^(%-?%d+):(%-?%d+)$")
            x,y=tonumber(x),tonumber(y)
            if x and x>=minX and x<=maxX and y>=minY and y<=maxY then self:road(x,y,false,1) end
        end
        for _,p in ipairs(sim.pendingRoads) do self:road(p.x,p.y,true,p.progress) end
        for _,b in ipairs(sim.buildings) do
            self:building(b)
            PaintedArchitecture.update(self,b)
            WorkshopLife.update(self,b)
            local wheel=self.buildings[b.id].wheel
            if wheel and (b.workRate or 0)>0 and b.inputs>0 then wheel.rotation=Quaternion(sim.elapsed*20,0,0) end
        end
        for i=#self.retiredBuildings,1,-1 do
            ---@type {node: Node, at: number}
            local r=self.retiredBuildings[i]
            if sim.elapsed-r.at>=.38 then r.node:Remove();table.remove(self.retiredBuildings,i) end
        end
        for _,p in pairs(self.actors) do p.seen=false end
        local function add(key,a,profile,action,seed)
            if Meals.hidden(sim,a) then return end
            local x,y=a.x,a.y
            if a.meal and (a.meal.phase=="enter" or a.meal.phase=="eat" or a.meal.phase=="exit") then
                local hall=sim.buildings[a.meal.target]
                x,y=Meals.diningPosition(hall,a.meal.seat or 1,a.meal.phase,a.meal.timer,a.meal)
            elseif a.meal and a.meal.phase=="queue" then
                local hall=sim.buildings[a.meal.target]
                x,y=Meals.queuePosition(sim,hall,a)
                local old=self.actors[key]
                if old and old.lastX then
                    local dx,dy=x-old.lastX,y-old.lastY
                    local distance=math.sqrt(dx*dx+dy*dy)
                    local step=math.max(0,math.min(.25,sim.elapsed-(old.poseTime or sim.elapsed)))*1.15
                    if distance>step and distance>.00001 then x,y=old.lastX+dx/distance*step,old.lastY+dy/distance*step end
                end
            elseif a.building and (a.farmPresence or 0)>0 then
                local b=sim.buildings[a.building]
                local row=((a.workClock or 0)/4)%2
                local pass=row<=1 and row or 2-row
                local px=b.x-((b.footprintW or 1)-1)*0.5-.45+pass*.90
                local py=b.y-((b.footprintH or 1)-1)*0.5+0.20
                x,y=x+(px-x)*a.farmPresence,y+(py-y)*a.farmPresence
            end
            if a.building and (not a.meal or a.meal.phase=="leaveWork" or a.meal.phase=="returnWork") then
                local b=sim.buildings[a.building]
                if b.kind~="farm" and b.kind~="woodcutter" then x,y=WorkshopLife.position(b,a,self) end
            end
            if a.building and not a.meal and (a.woodPhase=="toRack" or a.woodPhase=="stack" or a.woodPhase=="fromRack") then
                local b=sim.buildings[a.building]
                local rackX,rackY=BuildingPose.point(b,-.95+(a.slot or 1)*.35,.85)
                local presence=a.woodPhase=="toRack" and math.min(1,(a.woodClock or 0)/1.2) or
                    a.woodPhase=="fromRack" and 1-math.min(1,(a.woodClock or 0)/1.2) or 1
                x,y=a.x+(rackX-a.x)*presence,a.y+(rackY-a.y)*presence
            end
            local hidden=a.building and WorkshopLife.hidden(sim.buildings[a.building],a) or false
            if not a.meal and (key:match("^carrier%d+$") or key:match("^builder%d+$") and a.phase=='packing') then
                x,y,hidden=Cargo.doorPose(a,x,y)
            end
            self:person(key,a,profile,action,x,y,seed,hidden)
        end
        for i,a in ipairs(sim.carriers) do local _,p=Characters.carrier(i,a.carrying,a);add("carrier" .. i,a,p,a.meal and a.meal.phase=="eat" and "eat",i) end
        for i,a in ipairs(sim.builders) do
            if a.active or a.meal or a.restRequested then local _,p=Characters.carrier(i,a.carrying,a);add("builder" .. i,a,p,a.phase=="hammer" and "hammer" or a.meal and a.meal.phase=="eat" and "eat",i) end
        end
        for key,a in pairs(sim.workers) do
            local b=sim.buildings[a.building]
            local _,p=Characters.worker(b,a.slot,a)
            if p then
                local action=a.meal and a.meal.phase=="eat" and "eat" or not a.meal and
                    (b.kind=="farm" and (a.farmPresence or 0)>0.9 and Farm.needsWork(b,D.buildings.farm.period) and Farm.action(b) or
                    b.kind=="woodcutter" and a.woodPhase=="chop" and "chop" or WorkshopLife.action(b,a)) or nil
                add("worker" .. key,a,p,action,b.id+a.slot)
            end
        end
        for i,a in ipairs(sim.guards or {}) do
            local _,p=Characters.militia(i)
            add("guard" .. i,a,p,a.meal and a.meal.phase=="eat" and "eat",i)
        end
        for i,a in ipairs(sim.enemies or {}) do
            if a.hp>0 then self:person("enemy" .. i,a,{color={114,67,58},hat="cap"},nil,a.x,a.y,i) end
        end
        for key,p in pairs(self.actors) do if not p.seen then p.node:Remove();self.actors[key]=nil end end
        self.ghost:RemoveAllChildren()
        if ghost and mode~="inspect" then
            local w,h=D.footprint(mode)
            local valid=sim:canBuild(mode,ghost.x,ghost.y)
            local mat=valid and self:material(114,177,142) or self:material(195,112,93)
            self.ghost.position=position(ghost.x-(w-1)*0.5,ghost.y-(h-1)*0.5)
            self:outline(self.ghost,{kind=mode,footprintW=w,footprintH=h,footprintCells=D.cells(mode)},mat,0.035,false)
        end
        self.selection:RemoveAllChildren()
        if selected then
            local w,h=selected.footprintW or 1,selected.footprintH or 1
            self.selection.position=position(selected.x-(w-1)*0.5,selected.y-(h-1)*0.5)
            self:outline(self.selection,selected,self:material(217,176,85),0.04,false)
        end
    end
    function self:pick(x,y,layout)
        local ray=self.camera:GetScreenRay((x-layout.x)/layout.w,(y-layout.y)/layout.h)
        local hits=self.scene:GetComponent("Octree"):Raycast(ray,RAY_TRIANGLE,180,DRAWABLE_GEOMETRY)
        for _,hit in ipairs(hits) do
            local node=hit.node
            while node do
                local id=node.name:match("^Building_(%d+)_")
                if id then return sim.buildings[tonumber(id)] end
                node=node.parent
            end
        end
    end
    function self:dispose()
        renderer:SetViewport(0,nil)
        self.scene:RemoveAllChildren()
    end
    return self
end
return World
