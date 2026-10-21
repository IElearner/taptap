-- Exercise the delivered meshes and articulated poses, including all building
-- stages, material dependencies, a real four-person meal and role identities.
local Game=require "network.Standalone"
local Library=require "game.VillageModels"
local Manifest=require "game.VillageModelsManifest"
local Characters=require "game.Characters"
local sim,view,meshCount,poseBefore
V.atFrame(8,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local hud
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.started,sim.skipped,sim.menuOpen=true,true,false
    local intro=hud.root:FindById("modeScreen");if intro then intro:Hide() end
    local mentor=hud.root:FindById("mentorDialogue");if mentor then mentor:Hide() end
    local hall=sim:addBuilding("kitchen",8,8,true);hall.mealStock=8
    sim.militia=1;sim:update(0.1)
    for _,a in ipairs(sim.carriers) do a.hunger=92 end
    for _,a in ipairs(sim.guards) do a.hunger=92 end
    for _=1,300 do
        sim:update(0.1)
        if require("game.Meals").occupancy(sim,hall.id)==4 then break end
    end
    V.assert(require("game.Meals").occupancy(sim,hall.id)==4,"Four actual villagers enter the rebuilt dining hall")
    for _=1,18 do sim:update(0.1) end
    sim.paused=true
end)
V.atFrame(12,function()
    local model=view.modelWorld
    local originalUpdate=model.update
    model.update=function(self,...)
        originalUpdate(self,...)
        local center=Vector3(-3,0,1.5)
        self.cameraNode.position=center+Vector3(0,8,-math.sqrt(700)*8/30)
        self.cameraNode:LookAt(center)
        self.camera.orthoSize=3.4
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
    meshCount=0
    for name,spec in pairs(Manifest.models) do
        local mesh=cache:GetResource("Model",spec.model)
        V.assert(mesh~=nil,"Delivered mesh loads: " .. name)
        for _,ref in ipairs(spec.materials) do
            V.assert(cache:GetResource("Material",ref)~=nil,"Mesh material loads: " .. ref)
        end
        meshCount=meshCount+1
    end
    V.assert(meshCount>=116,"The delivery includes construction, architecture, people and distinct tools")
    local hall=model.buildings[2]
    V.assert(hall.authored and hall.stage==4 and hall.node:GetChild("AuthoredBuilding"):GetChild("ArchitectureMesh"),"Four seats are exposed by the authored open-hall mesh")
    local oldId
    for i=1,3 do
        local a=model.actors["carrier" .. i]
        V.assert(a and a.authored and a.node:GetChild("Head") and a.hips[1] and a.elbows[2],"A dining villager has sculpted meshes on real limb pivots")
        V.assert(a.bowl.enabled and a.tools.chopsticks.enabled and not a.tools.hammer.enabled,"Meals display a bowl and chopsticks rather than construction tools")
        V.assert(not a.tools.watering:GetComponent("StaticModel").enabled and not a.crate:GetComponent("StaticModel").enabled,
            "Unused tools and cargo are disabled at the actual drawable component")
        V.assert(a.modelId~=oldId,"Civilian mesh identities remain distinct through the meal")
        oldId=a.modelId
    end
    local guard=model.actors.guard1
    V.assert(guard and guard.action=="eat" and guard.bowl.enabled and guard.tools.chopsticks.enabled,
        "A militia diner sits and uses meal props just like civilian diners")
    poseBefore=model.actors.carrier1.hands[2].worldPosition
    sim.elapsed=sim.elapsed+0.8
    -- The stage models are different geometry, not a complete house under an overlay.
    local foundation=cache:GetResource("Model",Manifest.models.house_0.model)
    local frame=cache:GetResource("Model",Manifest.models.house_1.model)
    local complete=cache:GetResource("Model",Manifest.models.house_4.model)
    V.assert(foundation.boundingBox.max.y<frame.boundingBox.max.y and complete~=frame,"Construction grows from the low footing to timber and a separate finished mesh")
    for _,p in ipairs({{0.01,0},{0.3,1},{0.5,2},{0.85,3}}) do
        V.assert(Library.stage({complete=false,progress=p[1]})==p[2],"Worker progress selects construction stage " .. p[2])
    end
end)
V.atFrame(18,function()
    V.assert((view.modelWorld.actors.carrier1.hands[2].worldPosition-poseBefore):Length()>.001,"Rebuilt seated character moves its physical hand between bowl and mouth")
end)
V.atFrame(30,function() V.finish() end)
