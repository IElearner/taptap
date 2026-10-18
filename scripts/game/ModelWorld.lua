-- The playable world is geometry: no character, terrain, building or action sprites.
-- The orthographic camera matches the existing map/touch coordinate system.
local D=require "game.Definitions"
local Characters=require "game.Characters"
local Farm=require "game.FarmCycle"
local Meals=require "game.Meals"
local Craft=require "game.CraftMaterials"
local VillageModels=require "game.VillageModels"
local World={}
local UP=Vector3(0,1,0)
local function position(x,y,height) return Vector3(x-10,height or 0,9-y) end

function World.new(sim)
    local developmentCache=os.getenv and os.getenv("VILLAGE_SHADER_CACHE")
    if developmentCache and developmentCache~="" then graphics.shaderCacheDir=developmentCache end
    local self={scene=Scene(),buildings={},actors={},trees={},roads={},chunks={},materials={},surfaces={},models={},clock=0}
    -- Literal resource references let Maker include the engine meshes in Web builds.
    self.models.Box=cache:GetResource("Model","Models/Box.mdl")
    self.models.Sphere=cache:GetResource("Model","Models/Sphere.mdl")
    self.models.Cylinder=cache:GetResource("Model","Models/Cylinder.mdl")
    self.models.Cone=cache:GetResource("Model","Models/Cone.mdl")
    self.sim=sim
    self.scene:CreateComponent("Octree")
    local zone=self.scene:CreateComponent("Zone")
    zone.boundingBox=BoundingBox(-200,200)
    zone.ambientSource=AMBIENT_COLOR
    zone.ambientColor=Color(0.22,0.25,0.20)
    zone.depthFogStart,zone.depthFogEnd=80,160
    zone.fogColor=Color(0.73,0.78,0.68)
    local lightNode=self.scene:CreateChild("Daylight")
    lightNode.direction=Vector3(-0.5,-1,0.6)
    local sun=lightNode:CreateComponent("Light")
    sun.lightType=LIGHT_DIRECTIONAL
    sun.color=Color(1,0.95,0.83)
    sun.brightness=0.9
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
            local mat=Material:new()
            mat:SetTechnique(0,cache:GetResource("Technique","Techniques/PBR/PBRNoTexture.xml"))
            mat:SetShaderParameter("MatDiffColor",Variant(Color(r/255,g/255,b/255)))
            mat:SetShaderParameter("Roughness",Variant(0.94))
            mat:SetShaderParameter("Metallic",Variant(0.0))
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
                        if sim:terrain(x-1,y)~="water" then
                            self:part(root,"RiverBank","Box",self:material(198,187,144),x-10.48,0.005,9-y,0.12,0.05,1.03)
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
                    local root=self.scene:CreateChild("Tree_" .. key)
                    root.position=position(x+((x*13+y*7)%9-4)*0.025,y+((x*3+y*19)%7-3)*0.025)
                    local seed=(x*17+y*23)%9
                    local h=0.7+seed*0.035
                    self:part(root,"Trunk","Cylinder",self:material(112,83,52),0,h*0.45,0,0.095,h,0.095)
                    if seed%3==0 then
                        for i=1,3 do
                            local width=0.92-i*0.17
                            self:part(root,"Canopy","Cone",self:material(61+i*7,98+i*9,53+i*5),0,h*0.6+i*0.24,0,width,0.58,width)
                        end
                    else
                        for i=1,7 do
                            local leaf=self:material(66+i%3*13+seed,102+i%3*12,43+i%3*8)
                            local angle=i*2.4+seed
                            local spread=i==7 and 0 or 0.24
                            local px,pz=math.sin(angle)*spread,math.cos(angle)*spread
                            self:part(root,"Canopy","Sphere",leaf,px,h+0.15+i%3*0.13,pz,0.38+i%2*0.10,0.40+i%2*0.08,0.38+i%2*0.08,Quaternion(seed*7,i*23,i*13))
                            if i<=3 then self:beam(root,"Branch",self:material(103,73,42),Vector3(0,h*0.55,0),Vector3(px,h+0.15,pz),0.045) end
                        end
                    end
                    self.trees[key]=root
                end
            end
        end end
        for key,node in pairs(self.trees) do if not visible[key] then node:Remove();self.trees[key]=nil end end
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
        local road=self:material(planned and 161 or 135,planned and 141 or 126,planned and 106 or 104)
        self:part(node,"RoadCenter","Box",road,0,-0.005,0,0.34,0.026,0.34)
        for i,d in ipairs(directions) do if connected[i] then
            self:part(node,"RoadArm","Box",road,d[1]*0.25,-0.005,-d[2]*0.25,
                d[1]~=0 and 0.52 or 0.34,0.026,d[2]~=0 and 0.52 or 0.34)
        end end
        if not planned then
            for row=-3,3 do for col=-3,3 do
                local px,pz=col*0.14,row*0.14
                local onPath=math.abs(px)<0.17 and math.abs(pz)<0.17 or
                    connected[1] and pz>=0 and math.abs(px)<0.17 or
                    connected[2] and px>=0 and math.abs(pz)<0.17 or
                    connected[3] and pz<=0 and math.abs(px)<0.17 or
                    connected[4] and px<=0 and math.abs(pz)<0.17
                if onPath then
                    local hash=(x*17+y*31+col*13+row*7)%13
                    self:part(node,"Paver","Sphere",self:material(159+hash*2,154+hash*2,136+hash*2),
                        px+(hash%3-1)*0.012,0.008,pz,0.13,0.025,0.12,Quaternion(0,hash*7,0))
                end
            end end
        else
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
            (b.kind=="kitchen" and tostring(Meals.occupancy(sim,b.id)>0) or "") .. ((b.progress or 0)>0 and ":started" or ":plan")
        if old and old.signature==signature then return end
        if old then old.node:Remove() end
        local root=self.scene:CreateChild("Building_" .. b.id .. "_" .. b.kind)
        local w,h=b.footprintW or 1,b.footprintH or 1
        root.position=position(b.x-(w-1)*0.5,b.y-(h-1)*0.5)
        self.buildings[b.id]={node=root,signature=signature}
        if not b.complete and (b.progress or 0)==0 then
            self:outline(root,b,self:material(189,129,62),0.06,true)
            self.buildings[b.id].planned=true
            return
        end
        VillageModels.building(self,root,b)
    end

    function self:person(key,actor,profile,action,x,y,seed)
        local person=self.actors[key]
        if not person then
            person=VillageModels.person(self,key,profile)
            self.actors[key]=person
        end
        person.seen=true
        person.actor,person.profile,person.action=actor,profile,action
        local walking=actor.path and actor.path[actor.index]~=nil or
            actor.meal and (actor.meal.phase=="enter" or actor.meal.phase=="exit" or actor.meal.phase=="leaveWork" or actor.meal.phase=="returnWork") or
            (actor.farmPresence or 0)>0 and (actor.farmPresence or 0)<1
        local clock=sim.elapsed
        local cycle=clock*6+(seed or 0)*1.8
        local stride=walking and math.sin(cycle)*29 or 0
        local yaw=({se=90,nw=-90,sw=180,ne=0})[actor.facing or "sw"]
        if action=="hammer" and actor.job and actor.job.kind=="building" then
            yaw=({south=0,north=180,west=90,east=-90})[actor.job.side] or yaw
        end
        if action=="eat" and actor.meal then
            yaw=((actor.meal.seat or 1)-1)%2==0 and 90 or -90
        end
        person.node.position=position(x,y,walking and math.abs(math.sin(cycle))*0.012 or 0)
        person.node.rotation=Quaternion(yaw,UP)
        for i,sign in ipairs({-1,1}) do
            person.hips[i].rotation=Quaternion(stride*sign,0,0)
            person.knees[i].rotation=Quaternion(math.max(0,-stride*sign)*0.7,0,0)
            person.shoulders[i].rotation=Quaternion(-stride*sign*0.65,0,sign*5)
            person.elbows[i].rotation=Quaternion(-12,0,0)
        end
        person.torso.rotation=Quaternion(0,0,walking and math.sin(cycle)*2 or 0)
        local toolName=({hammer="hammer",chop="axe",plow="hoe",harvest="sickle",water="watering",eat="chopsticks"})[action]
        person.tool.enabled=toolName~=nil
        for name,node in pairs(person.tools) do VillageModels.visible(node,name==toolName) end
        VillageModels.visible(person.bowl,action=="eat")
        person.load.enabled=actor.carrying==true
        local resource=actor.job and actor.job.resource or "wood"
        VillageModels.visible(person.planks,actor.carrying==true and resource=="wood")
        VillageModels.visible(person.sacks,actor.carrying==true and (resource=="grain" or resource=="flour"))
        VillageModels.visible(person.crate,actor.carrying==true and resource~="wood" and resource~="grain" and resource~="flour")
        if actor.carrying then
            for i=1,2 do person.shoulders[i].rotation=Quaternion(-58,0,0);person.elbows[i].rotation=Quaternion(-44,0,0) end
        elseif action=="hammer" or action=="chop" then
            local swing=math.sin(clock*3.8+(seed or 0))
            person.shoulders[2].rotation=Quaternion(-85-swing*57,0,-8)
            person.elbows[2].rotation=Quaternion(-35-swing*22,0,0)
            person.torso.rotation=Quaternion(5+swing*4,0,0)
        elseif action=="eat" then
            person.node.position=position(x,y,-0.06)
            for i=1,2 do person.hips[i].rotation=Quaternion(-85,0,0);person.knees[i].rotation=Quaternion(85,0,0) end
            person.shoulders[1].rotation=Quaternion(-55,0,0)
            person.elbows[1].rotation=Quaternion(-80,0,0)
            person.shoulders[2].rotation=Quaternion(-68-math.sin(clock*2.5)*25,0,0)
            person.elbows[2].rotation=Quaternion(-80,0,0)
        elseif action=="plow" or action=="water" or action=="harvest" then
            person.torso.rotation=Quaternion(16+math.sin(clock*2)*6,0,0)
            for i=1,2 do person.shoulders[i].rotation=Quaternion(-38+math.sin(clock*2+i)*18,0,0) end
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
            local wheel=self.buildings[b.id].wheel
            if wheel and b.workers>0 and b.inputs>0 then wheel.rotation=Quaternion(sim.elapsed*20,0,0) end
        end
        for _,p in pairs(self.actors) do p.seen=false end
        local function add(key,a,profile,action,seed)
            if Meals.hidden(sim,a) then return end
            local x,y=a.x,a.y
            if a.meal and (a.meal.phase=="enter" or a.meal.phase=="eat" or a.meal.phase=="exit") then
                local hall=sim.buildings[a.meal.target]
                x,y=Meals.diningPosition(hall,a.meal.seat or 1,a.meal.phase,a.meal.timer)
            elseif a.building and (a.farmPresence or 0)>0 then
                local b=sim.buildings[a.building]
                local px=b.x-((b.footprintW or 1)-1)*0.5+math.sin((a.workClock or 0)*0.7)*0.30
                local py=b.y-((b.footprintH or 1)-1)*0.5+0.2
                x,y=x+(px-x)*a.farmPresence,y+(py-y)*a.farmPresence
            end
            self:person(key,a,profile,action,x,y,seed)
        end
        for i,a in ipairs(sim.carriers) do local _,p=Characters.carrier(i,a.carrying);add("carrier" .. i,a,p,a.meal and a.meal.phase=="eat" and "eat",i) end
        for i,a in ipairs(sim.builders) do
            if a.active or a.meal then local _,p=Characters.carrier(i,a.carrying);add("builder" .. i,a,p,a.phase=="hammer" and "hammer" or a.meal and a.meal.phase=="eat" and "eat",i) end
        end
        for key,a in pairs(sim.workers) do
            local b=sim.buildings[a.building]
            local _,p=Characters.worker(b,a.slot)
            if p then
                local action=a.meal and a.meal.phase=="eat" and "eat" or not a.meal and
                    (b.kind=="farm" and (a.farmPresence or 0)>0.9 and Farm.needsWork(b,D.buildings.farm.period) and Farm.action(b) or
                    b.kind=="woodcutter" and a.woodPhase=="chop" and "chop") or nil
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
        local hit=self.scene:GetComponent("Octree"):RaycastSingle(ray,RAY_TRIANGLE,180,DRAWABLE_GEOMETRY)
        local node=hit and hit.node
        while node do
            local id=node.name:match("^Building_(%d+)_")
            if id then return sim.buildings[tonumber(id)] end
            node=node.parent
        end
    end
    function self:dispose()
        renderer:SetViewport(0,nil)
        self.scene:RemoveAllChildren()
    end
    return self
end
return World
