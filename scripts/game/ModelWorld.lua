-- The playable world is geometry: no character, terrain, building or action sprites.
-- The orthographic camera matches the existing map/touch coordinate system.
local D=require "game.Definitions"
local Characters=require "game.Characters"
local Farm=require "game.FarmCycle"
local Meals=require "game.Meals"
local Craft=require "game.CraftMaterials"
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
    self.models.Tunic=LatheGeometry({Vector2(0.085,-0.14),Vector2(0.09,-0.08),Vector2(0.115,0.075),Vector2(0.075,0.14)},12):ToModel()
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
        local signature=(b.complete and "done" or tostring(math.floor((b.progress or 0)*16))) .. ":" ..
            (b.kind=="farm" and Farm.stage(b,D.buildings.farm.period) or "") .. ":" ..
            (b.kind=="kitchen" and tostring(Meals.occupancy(sim,b.id)>0) or "") .. ":" .. sim.roadCount .. ((b.progress or 0)>0 and ":started" or ":plan")
        if old and old.signature==signature then return end
        if old then old.node:Remove() end
        local root=self.scene:CreateChild("Building_" .. b.id .. "_" .. b.kind)
        local w,h=b.footprintW or 1,b.footprintH or 1
        root.position=position(b.x-(w-1)*0.5,b.y-(h-1)*0.5)
        self.buildings[b.id]={node=root,signature=signature}
        local wood,lightWood,stone,wall,roof=self:material(105,54,25),self:material(189,129,62),self:material(150,148,134),self:material(226,207,161),self:material(43,66,79)
        if b.kind=="house" then roof=self:material(67,71,68) end
        if b.kind=="mill" or b.kind=="courier" then roof=self:material(116,76,39) end
        if b.kind=="barracks" then roof=self:material(105,54,43) end
        local bw,bh=w-0.28,h-0.28
        local progress=b.complete and 1 or b.progress or 0
        if not b.complete and progress==0 then
            self:outline(root,b,lightWood,0.06,true)
            self.buildings[b.id].planned=true
            return
        end
        root.scale=Vector3(1,1.25,1)
        local irregular=#D.cells(b)<w*h
        if irregular then
            for _,c in ipairs(D.cells(b)) do
                self:part(root,"Foundation","Box",stone,c.x+(w-1)*0.5,0.045,-c.y-(h-1)*0.5,0.98,0.10,0.98)
            end
            -- The L-shaped courier has a two-cell-wide main hall and a separate
            -- covered loading bay; its north-east cut-out remains usable land.
            if b.kind=="courier" then
                local annex=root:CreateChild("LoadingBay")
                annex.position=Vector3((w-1)*0.5,0,-(h-1)*0.5)
                if progress>0.25 then
                    for _,x in ipairs({-0.36,0.36}) do self:part(annex,"TimberPost","Box",wood,x,0.42,-0.35,0.055,0.78,0.055) end
                end
                if progress>0.75 then self:part(annex,"Awning","Box",lightWood,0,0.90,0,0.90,0.065,0.92,Quaternion(-12,0,0)) end
                local main=root:CreateChild("MainHall");main.position=Vector3(-0.5,0,0)
                root=main;w=w-1;bw=w-0.28
            end
        else self:part(root,"Foundation","Box",stone,0,0.045,0,bw,0.10,bh) end
        if b.kind=="farm" then
            self:part(root,"TilledSoil","Box",self:material(156,130,93),0,0.06,0,bw,0.04,bh)
            local stage=Farm.stage(b,D.buildings.farm.period)
            local plantH=stage=="ripe" and 0.28 or stage=="green" and 0.18 or stage=="sprout" and 0.09 or 0.015
            local wheat=stage=="ripe" and self:material(213,180,87) or self:material(132,153,75)
            for ix=1,w*5 do for iz=1,h*4 do
                local px=-bw/2+ix*bw/(w*5+1)
                local pz=-bh/2+iz*bh/(h*4+1)
                self:part(root,"Wheat","Cylinder",wheat,px,0.08+plantH/2,pz,0.02,plantH,0.02)
                if stage=="ripe" then self:part(root,"WheatEar","Sphere",wheat,px,0.08+plantH,pz,0.045,0.08,0.04) end
            end end
            for _,edge in ipairs(Farm.exposedEdges(sim,b)) do
                local px=edge.x-b.x+(w-1)*0.5
                local pz=b.y-edge.y-(h-1)*0.5
                local vertical=edge.side=="east" or edge.side=="west"
                local side=edge.side=="east" and 0.48 or edge.side=="west" and -0.48 or 0
                local depth=edge.side=="north" and 0.48 or edge.side=="south" and -0.48 or 0
                self:part(root,"FenceRail","Box",lightWood,px+side,0.20,pz+depth,vertical and 0.035 or 0.97,0.035,vertical and 0.97 or 0.035)
            end
            return
        end
        if b.kind=="ranch" and b.complete then
            self:part(root,"PenGround","Box",self:material(176,158,116),0,0.08,0,bw,0.03,bh)
            for _,sign in ipairs({-1,1}) do
                self:part(root,"Fence","Box",lightWood,sign*bw/2,0.30,0,0.04,0.04,bh)
                self:part(root,"Fence","Box",lightWood,0,0.30,sign*bh/2,bw,0.04,0.04)
            end
            for i=1,2 do
                local x=(i-1.5)*0.55
                local pig=self:material(182,140,116)
                self:part(root,"Livestock","Sphere",pig,x,0.23,0,0.37,0.25,0.24)
                self:part(root,"Snout","Sphere",pig,x+0.20,0.23,0,0.13,0.12,0.14)
                for _,sign in ipairs({-1,1}) do self:part(root,"Leg","Box",pig,x+sign*0.11,0.13,0,0.05,0.15,0.15) end
            end
            return
        end
        local doorX=math.min((w-1)*0.5,bw/2-0.25)
        -- Build individual members; no swapping complete building pictures.
        local posts=math.floor(math.min(1,progress/0.28)*4+0.01)
        local corners={{-bw/2+0.06,-bh/2+0.06},{bw/2-0.06,-bh/2+0.06},{-bw/2+0.06,bh/2-0.06},{bw/2-0.06,bh/2-0.06}}
        for i=1,posts do
            local p=corners[i]
            self:part(root,"TimberPost","Box",wood,p[1],0.58,p[2],0.085,1.10,0.085)
        end
        if progress>=0.24 then
            for _,z in ipairs({-bh/2+0.05,bh/2-0.05}) do self:part(root,"CrossBeam","Box",lightWood,0,1.10,z,bw+0.04,0.09,0.09) end
            for _,x in ipairs({-bw/2+0.05,bw/2-0.05}) do self:part(root,"SideBeam","Box",wood,x,1.10,0,0.09,0.09,bh) end
        end
        local wallH=math.max(0,math.min(0.86,(progress-0.3)/0.37*0.86))
        local openKitchen=b.kind=="kitchen" and b.complete and Meals.occupancy(sim,b.id)>0
        if wallH>0 then
            for _,x in ipairs({-bw/2+0.06,bw/2-0.06}) do
                self:part(root,"SideWall","Box",wall,x,0.09+wallH/2,0,0.09,wallH,bh-0.12)
            end
            self:part(root,"RearWall","Box",wall,0,0.09+wallH/2,bh/2-0.06,bw-0.10,wallH,0.08)
            for i=1,math.floor(wallH/0.16) do
                self:part(root,"WallTimber","Box",lightWood,0,0.09+i*0.16,bh/2-0.005,bw,0.018,0.018)
            end
            if not openKitchen then
                local panels={{-bw/2+0.05,doorX-0.23},{doorX+0.23,bw/2-0.05}}
                for _,span in ipairs(panels) do
                    local panelW=span[2]-span[1]
                    local px=(span[1]+span[2])/2
                    if panelW>0.02 then
                        self:part(root,"FrontWall","Box",wall,px,0.09+wallH/2,-bh/2+0.05,panelW,wallH,0.09)
                        if wallH>0.65 and panelW>0.42 then
                            local windows=math.max(1,math.floor(panelW/0.85))
                            for i=1,windows do
                                local wx=span[1]+panelW*i/(windows+1)
                                self:part(root,"Window","Box",wood,wx,0.58,-bh/2-0.005,0.24,0.26,0.02)
                                for k=-1,1 do self:part(root,"WindowBar","Box",lightWood,wx+k*0.065,0.58,-bh/2-0.02,0.018,0.25,0.02) end
                                self:part(root,"WindowSill","Box",lightWood,wx,0.44,-bh/2-0.03,0.30,0.035,0.07)
                            end
                            self:beam(root,"FrontTimber",wood,Vector3(span[1]+0.02,0.22,-bh/2-0.01),Vector3(span[2]-0.02,0.86,-bh/2-0.01),0.035)
                            self:part(root,"FrontSill","Box",wood,px,0.35,-bh/2-0.01,panelW,0.035,0.035)
                        end
                    end
                end
                self:part(root,"DoorLintel","Box",wood,doorX,0.96,-bh/2,0.47,0.08,0.12)
                if b.complete then self:part(root,"Door","Box",self:material(94,67,43),doorX,0.41,-bh/2+0.035,0.36,0.72,0.05) end
            end
            if wallH>0.7 then
                -- Timber infill and stone courses provide actual surface relief.
                for _,sign in ipairs({-1,1}) do
                    self:part(root,"WallPlate","Box",wood,sign*(bw/2-0.04),0.94,0,0.10,0.07,bh)
                    for row=1,2 do for col=1,math.max(1,math.floor(bh/0.25)) do
                        self:part(root,"Masonry","Box",stone,sign*(bw/2+0.002),0.12+row*0.075,-bh/2+col*bh/(math.floor(bh/0.25)+1),0.025,0.065,0.22)
                    end end
                end
                self:part(root,"EaveBeam","Box",wood,0,1.06,-bh/2-0.04,bw+0.15,0.10,0.14)
            end
        end
        if progress>0.57 then
            for _,x in ipairs({-bw/2,bw/2}) do
                self:beam(root,"Rafter",lightWood,Vector3(x,1.08,-bh/2-0.09),Vector3(x,1.53,0),0.065)
                self:beam(root,"Rafter",lightWood,Vector3(x,1.08,bh/2+0.09),Vector3(x,1.53,0),0.065)
            end
            self:part(root,"RidgeBeam","Box",wood,0,1.53,0,bw+0.2,0.09,0.09)
        end
        if progress>0.72 and not openKitchen then
            local courses=math.floor(math.min(1,(progress-0.72)/0.28)*7)
            for side=-1,1,2 do for row=1,courses do
                local t=(row-0.5)/7
                local pz=side*t*(bh/2+0.14)
                local py=1.55-t*0.46
                self:part(root,"RoofCourse","Box",roof,0,py,pz,bw+0.35,0.065,(bh/2+0.14)/7+0.04,
                    Quaternion(side*math.deg(math.atan(0.46/(bh/2+0.14))),0,0))
                local columns=math.max(5,math.floor((bw+0.3)/0.12))
                local along=Vector3(0,-0.46,side*(bh/2+0.14)):Normalized()
                local tileLength=math.sqrt(0.46*0.46+(bh/2+0.14)^2)/7+0.045
                for col=1,columns do
                    local px=-(bw+0.3)/2+(col-0.5)*(bw+0.3)/columns
                    self:part(root,"RoofTile","Cylinder",roof,px,py+0.045,pz,0.065,tileLength,0.065,Quaternion(UP,along))
                end
            end end
            self:part(root,"RidgeCap","Cylinder",roof,0,1.60,0,0.105,bw+0.4,0.105,Quaternion(0,0,90))
            for _,sign in ipairs({-1,1}) do
                self:part(root,"RidgeFinial","Sphere",roof,sign*(bw/2+0.17),1.65,0,0.11,0.16,0.11)
            end
        end
        if not b.complete then
            for i=1,4 do self:part(root,"DeliveredPlank","Box",lightWood,-bw/2-0.17,0.08+i*0.025,-0.2,0.14,0.026,0.65) end
        else
            self:part(root,"Threshold","Box",stone,doorX,0.04,-bh/2-0.18,0.54,0.07,0.27)
            self:part(root,"Step","Box",stone,doorX,0.015,-bh/2-0.33,0.62,0.035,0.16)
            self:part(root,"DoorFrameLeft","Box",wood,doorX-0.21,0.46,-bh/2-0.02,0.045,0.79,0.06)
            self:part(root,"DoorFrameRight","Box",wood,doorX+0.21,0.46,-bh/2-0.02,0.045,0.79,0.06)
            if not openKitchen then
                for i=-2,2 do self:part(root,"DoorPlank","Box",lightWood,doorX+i*0.064,0.42,-bh/2-0.005,0.012,0.64,0.016) end
            end
            if b.kind=="store" or b.kind=="courier" then
                for i=1,3 do
                    local px=-bw/2+0.18+(i-1)*0.25
                    self:part(root,"Supplies","Cylinder",lightWood,px,0.20,-bh/2-0.12,0.19,0.32,0.19)
                    for _,height in ipairs({0.11,0.28}) do self:part(root,"BarrelHoop","Cylinder",self:material(75,70,57),px,height,-bh/2-0.12,0.195,0.016,0.195) end
                end
            elseif b.kind=="woodcutter" then
                for i=1,4 do self:part(root,"Logs","Cylinder",wood,-bw/2+0.1,0.10+i*0.08,0,0.14,0.7,0.14,Quaternion(90,0,0)) end
            elseif b.kind=="kitchen" then
                self:part(root,"Table","Box",lightWood,0,0.34,0,0.55,0.06,0.6)
                for _,x in ipairs({-0.47,0.47}) do for _,z in ipairs({-0.36,0.36}) do
                    self:part(root,"Seat","Box",wood,x,0.19,z,0.22,0.07,0.21)
                    self:part(root,"SeatLeg","Box",wood,x,0.08,z,0.07,0.16,0.07)
                end end
                self:part(root,"Chimney","Box",stone,bw/2-0.22,1.24,0.25,0.20,0.70,0.22)
                self:part(root,"CanvasAwning","Box",self:material(202,162,77),doorX,0.90,-bh/2-0.12,0.9,0.04,0.45,Quaternion(-12,0,0))
                for _,sign in ipairs({-1,1}) do self:part(root,"PorchPost","Box",wood,doorX+sign*0.40,0.43,-bh/2-0.28,0.045,0.86,0.045) end
            elseif b.kind=="mill" then
                self:part(root,"MillStone","Cylinder",stone,0,0.32,-bh/2-0.10,0.40,0.16,0.4)
                local wheel=root:CreateChild("WaterWheel");wheel.position=Vector3(-bw/2-0.04,0.46,0)
                for _,sign in ipairs({-1,1}) do
                    self:part(wheel,"WheelRim","Cylinder",wood,sign*0.09,0,0,0.72,0.055,0.72,Quaternion(0,0,90))
                end
                for i=1,10 do
                    local angle=i*math.pi/5
                    self:part(wheel,"WheelPaddle","Box",lightWood,0,math.cos(angle)*0.34,math.sin(angle)*0.34,0.25,0.065,0.16,Quaternion(i*36,0,0))
                end
                self.buildings[b.id].wheel=wheel
            elseif b.kind=="quarry" then
                for i=1,5 do self:part(root,"StoneHeap","Sphere",stone,-bw/2+(i-0.5)*bw/5,0.12,-bh/2-0.16,0.23,0.23+i%2*0.1,0.22) end
            elseif b.kind=="butcher" then
                self:part(root,"CuttingTable","Box",wood,0,0.30,-bh/2-0.1,0.52,0.15,0.23)
            elseif b.kind=="barracks" then
                self:part(root,"Flagpole","Cylinder",wood,bw/2+0.05,0.85,0.1,0.04,1.7,0.04)
                self:part(root,"Flag","Box",self:material(157,60,48),bw/2+0.2,1.48,0.1,0.3,0.24,0.025)
            end
        end
    end

    function self:person(key,actor,profile,action,x,y,seed)
        local person=self.actors[key]
        if not person then
            local root=self.scene:CreateChild("Villager_" .. key)
            local skin=self:material(194,150,109)
            local coat=self:material(profile.color[1],profile.color[2],profile.color[3])
            local trouser=self:material(79,75,65)
            local boot=self:material(66,52,41)
            local torso=self:part(root,"Torso","Tunic",coat,0,0.40,0,1,1,0.80)
            self:part(root,"Belt","Box",boot,0,0.30,0,0.21,0.028,0.15)
            self:part(root,"Head","Sphere",skin,0,0.62,0,0.125,0.15,0.13)
            self:part(root,"Nose","Sphere",skin,0,0.62,0.075,0.035,0.04,0.035)
            local hair=self:material(profile.age=="elder" and 145 or 54,profile.age=="elder" and 143 or 44,profile.age=="elder" and 131 or 33)
            self:part(root,"Hair","Sphere",hair,0,0.68,-0.018,0.145,0.10,0.13)
            for _,sign in ipairs({-1,1}) do self:part(root,"Eye","Sphere",self:material(45,37,30),sign*0.030,0.64,0.067,0.013,0.013,0.013) end
            local hat=self:material(profile.hat=="straw" and 189 or 74,profile.hat=="straw" and 157 or 65,profile.hat=="straw" and 92 or 52)
            if profile.hat=="straw" then
                self:part(root,"Hat","Cone",hat,0,0.72,0,0.25,0.10,0.23)
                self:part(root,"HatBrim","Cylinder",hat,0,0.695,0,0.29,0.016,0.27)
            elseif profile.hat=="braid" then
                self:part(root,"Braid","Sphere",hair,0,0.57,-0.08,0.045,0.17,0.05)
            else self:part(root,"Cap","Sphere",hat,0,0.70,-0.01,0.16,0.075,0.16) end
            if profile.age=="elder" then self:part(root,"Beard","Cone",hair,0,0.55,0.055,0.08,0.12,0.07,Quaternion(180,0,0)) end
            local shoulders,elbows,hips,knees={},{},{},{}
            for i,sign in ipairs({-1,1}) do
                local hip=root:CreateChild("Hip" .. i);hip.position=Vector3(sign*0.058,0.30,0)
                self:part(hip,"Thigh","Cylinder",trouser,0,-0.075,0,0.075,0.15,0.075)
                local knee=hip:CreateChild("Knee");knee.position=Vector3(0,-0.15,0)
                self:part(knee,"Shin","Cylinder",trouser,0,-0.065,0,0.064,0.13,0.064)
                self:part(knee,"Boot","Box",boot,0,-0.125,0.028,0.075,0.05,0.12)
                local shoulder=root:CreateChild("Shoulder" .. i);shoulder.position=Vector3(sign*0.125,0.51,0)
                self:part(shoulder,"UpperArm","Cylinder",coat,0,-0.07,0,0.067,0.14,0.067)
                local elbow=shoulder:CreateChild("Elbow");elbow.position=Vector3(0,-0.14,0)
                self:part(elbow,"Forearm","Cylinder",skin,0,-0.06,0,0.052,0.12,0.052)
                self:part(elbow,"Hand","Sphere",skin,0,-0.12,0,0.065,0.065,0.065)
                shoulders[i],elbows[i],hips[i],knees[i]=shoulder,elbow,hip,knee
            end
            local tool=elbows[2]:CreateChild("Tool")
            self:part(tool,"Handle","Cylinder",self:material(147,103,57),0,-0.23,0.035,0.024,0.25,0.024)
            self:part(tool,"HammerHead","Box",self:material(100,108,109),0,-0.35,0.035,0.15,0.065,0.065)
            local load=root:CreateChild("CarriedLoad")
            local planks=load:CreateChild("Planks")
            for i=1,3 do self:part(planks,"Plank","Box",self:material(188,146,89),0,0.42+i*0.03,0.20,0.47,0.028,0.12) end
            local sacks=load:CreateChild("Sacks")
            for i=1,2 do self:part(sacks,"Sack","Sphere",self:material(190,167,116),(i-1.5)*0.12,0.47,0.19,0.15,0.22,0.16) end
            local crate=self:part(load,"Crate","Box",self:material(140,107,61),0,0.45,0.20,0.29,0.20,0.18)
            person={node=root,actor=actor,torso=torso,shoulders=shoulders,elbows=elbows,hips=hips,knees=knees,tool=tool,load=load,planks=planks,sacks=sacks,crate=crate}
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
        person.node.position=position(x,y,walking and math.abs(math.sin(cycle))*0.012 or 0)
        person.node.rotation=Quaternion(yaw,UP)
        for i,sign in ipairs({-1,1}) do
            person.hips[i].rotation=Quaternion(stride*sign,0,0)
            person.knees[i].rotation=Quaternion(math.max(0,-stride*sign)*0.7,0,0)
            person.shoulders[i].rotation=Quaternion(-stride*sign*0.65,0,sign*5)
            person.elbows[i].rotation=Quaternion(-12,0,0)
        end
        person.torso.rotation=Quaternion(0,0,walking and math.sin(cycle)*2 or 0)
        person.tool.enabled=action=="hammer" or action=="chop" or action=="plow" or action=="harvest"
        person.load.enabled=actor.carrying==true
        local resource=actor.job and actor.job.resource or "wood"
        person.planks.enabled=resource=="wood"
        person.sacks.enabled=resource=="grain" or resource=="flour"
        person.crate.enabled=resource~="wood" and resource~="grain" and resource~="flour"
        if actor.carrying then
            for i=1,2 do person.shoulders[i].rotation=Quaternion(-58,0,0);person.elbows[i].rotation=Quaternion(-44,0,0) end
        elseif action=="hammer" or action=="chop" then
            local swing=math.sin(clock*3.8+(seed or 0))
            person.shoulders[2].rotation=Quaternion(-85-swing*57,0,-8)
            person.elbows[2].rotation=Quaternion(-35-swing*22,0,0)
            person.torso.rotation=Quaternion(5+swing*4,0,0)
        elseif action=="eat" then
            person.node.position=position(x,y,-0.03)
            for i=1,2 do person.hips[i].rotation=Quaternion(-85,0,0);person.knees[i].rotation=Quaternion(85,0,0) end
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
        for i,a in ipairs(sim.guards or {}) do local _,p=Characters.militia(i);add("guard" .. i,a,p,nil,i) end
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
