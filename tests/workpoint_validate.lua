local Sim=require "game.Simulation"
local Sites=require "game.ConstructionSites"
local Data=require "game.SaveData"
local Characters=require "game.Characters"
local Game=require "network.Standalone"
local demo,view,house
V.atFrame(8,function()
    for _,kind in ipairs(require("game.Definitions").order) do if kind~="road" then
        local p=Sites.blueprint({kind=kind})
        local work,goods=0,{wood=0,stone=0}
        for _,point in ipairs(p) do work=work+point.required;goods[point.resource]=goods[point.resource]+point.amount end
        local cost=require("game.Definitions").buildings[kind].cost
        V.assert(#p>=4 and math.abs(work-36)<.00001,"Fixed total work is divided across real pieces: " .. kind)
        V.assert(math.abs(goods.wood-(cost.wood or 0))<.00001 and math.abs(goods.stone-(cost.stone or 0))<.00001,
            "Point deliveries conserve the original material budget: " .. kind)
    end end
    local function run(population)
        local s=Sim.new();s.started,s.skipped,s.population=true,true,population
        V.assert(s:build("house",8,8),"A real house can be planned")
        local b=s:buildingAt(8,8)
        local saved,returned,maximum=false,false,0
        local capturedPhases,hauls,seenLoads,previous,transfers={},{wood=0,stone=0},{},{},0
        for _=1,7000 do
            s:update(.1)
            local active=0
            for index,a in ipairs(s.builders) do
                if a.job and a.phase=="unload" and a.carrying and not seenLoads[a.job] then
                    seenLoads[a.job]=true;hauls[a.job.resource]=hauls[a.job.resource]+a.job.deliveryAmount
                end
                if a.job and previous[index] and previous[index]~=a.job.pointId and not a.job.delivery and a.phase=="approach" then transfers=transfers+1 end
                if a.job then previous[index]=a.job.pointId end
                if (a.phase=="ready" or a.phase=="recover" or a.phase=="waitMaterials" or a.phase=="waitSite" or a.phase=="refillExit") and not capturedPhases[a.phase] then
                    capturedPhases[a.phase]=true
                    V.assert(Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),"finite")~=nil,"New on-site workflow phase survives save/restore: "..a.phase)
                end
                if a.phase=="hammer" then
                    active=active+1
                    V.assert(a.job.pointId and b.buildPoints[a.job.pointId].delivered,"A point cannot be hammered without its own delivery")
                end
                if not saved and a.phase=="unload" then
                    local data=Data.capture(s,1000,1,true)
                    local loaded=Data.restore(cjson.decode(cjson.encode(data)),"finite")
                    V.assert(loaded and loaded.builders[1].workerLook==s.builders[1].workerLook,"Unloading and the random worker identity survive a save")
                    local corrupt=cjson.decode(cjson.encode(data))
                    corrupt.world.buildings[b.id].buildPoints[1].work=.5
                    corrupt.world.buildings[b.id].buildPoints[1].delivered=false
                    V.assert(not Data.restore(corrupt,"finite"),"Undelivered or inconsistent point work is rejected")
                    saved=true
                end
                if (a.phase=="collect" or a.phase=="packing") and (b.deliveredLoads or 0)>0 then returned=true end
            end
            for _,a in ipairs(s.carriers) do
                if a.job and a.job.construction and a.phase=="unload" and a.carrying and not seenLoads[a.job] then
                    seenLoads[a.job]=true;hauls[a.job.resource]=hauls[a.job.resource]+a.job.amount
                end
            end
            maximum=math.max(maximum,active)
            if b.complete then break end
        end
        V.assert(b.complete,"Prefetched stage batches let workers complete the site without redundant fetch trips")
        local work,count=0,0
        for _,p in ipairs(b.buildPoints) do
            work=work+p.work;if p.delivered then count=count+1 end
        end
        V.assert(math.abs(work-36)<.00001 and count==16 and b.deliveredLoads==4,"Four stage deliveries supply sixteen points and exactly thirty-six work seconds")
        print("WORKPOINT_METRICS",population,transfers,hauls.wood,hauls.stone,b.deliveredLoads,s.elapsed)
        V.assert(transfers>=8 and math.abs(hauls.wood-8)<.000001 and math.abs(hauls.stone-2)<.000001,"Workers transfer between supplied points without fetching; batches conserve all materials")
        V.assert(s.stock.wood==64 and s.stock.stone==38,"Repeated trips do not charge the material escrow again")
        return maximum
    end
    local one,many=run(4),run(10)
    V.assert(one==1 and many>one,"The same total work supports different crew sizes")
    local a={workerLook=1};local b={workerLook=2}
    local _,aa=Characters.carrier(99,false,a);local _,ab=Characters.carrier(1,true,a)
    local _,bb=Characters.carrier(99,false,b)
    V.assert(aa==ab and aa~=bb,"Two worker looks persist independently of carrying pose or job number")

    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud
    demo,view,hud=Game.Inspect();hud.dismissIntro();demo,view,hud=Game.Inspect();hud.dismissIntro();demo.skipped=true
    demo:build("house",8,8);house=demo:buildingAt(8,8)
    for _=1,3000 do
        demo:update(.1)
        local completed=0
        for _,p in ipairs(house.buildPoints or {}) do if p.work>=p.required-.000001 then completed=completed+1 end end
        if completed>=6 then break end
    end
    demo.paused=true;hud.update()
end)
V.atFrame(12,function()
    local model=view.modelWorld
    local shape=model.buildings[house.id].node:GetChild("AuthoredBuilding")
    local count=0
    for _,p in ipairs(house.buildPoints) do
        local chunk=shape:GetChild("CompletedPoint" .. p.id .. "house")
        V.assert((chunk~=nil)==(p.work>=p.required-.000001),"Visible building piece matches only its completed work point: " .. p.id)
        if chunk then count=count+1 end
    end
    V.assert(not house.complete and count>=6 and not shape:GetChild("ArchitectureMesh"),"An incomplete house consists of separate built pieces, never the whole finished mesh")
    local update=model.update
    model.update=function(self,...)
        update(self,...)
        local center=Vector3(-3,.20,1.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=3.8
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
V.atFrame(30,function() V.finish() end)
