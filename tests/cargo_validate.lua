local Cargo=require "game.Cargo"
local Characters=require "game.Characters"
local Game=require "network.Standalone"
V.atFrame(8,function()
    local sim,view=Game.Inspect()
    local world=view.modelWorld
    local a={x=10,y=9,workerLook=1,carrying=true,phase="toSite",timer=0,job={resource="wood"}}
    local _,profile=Characters.carrier(1,true,a)
    local identity
    local manifest=require "game.CargoManifest"
    for _,resource in ipairs({"wood","stone","grain","flour","meat","gold","food","coins","unregistered"}) do
        a.job.resource=resource
        world:person("cargoProbe",a,profile,nil,10,9,0)
        local p=world.actors.cargoProbe
        identity=identity or p.node
        V.assert(p.node==identity,"Changing cargo keeps the same character node: "..resource)
        local visible=0
        for key,node in pairs(p.cargo) do
            if node.enabled then visible=visible+1;V.assert(key==Cargo.profile(a).mesh,"Only the matching cargo is visible: "..resource) end
        end
        if manifest.models[Cargo.profile(a).mesh] then
            local drawable=p.cargo[Cargo.profile(a).mesh]:GetComponent("StaticModel")
            V.assert(drawable and drawable.model~=nil and drawable:GetMaterial(0)~=nil,"Authored mesh and texture material are loaded: "..resource)
        end
        V.assert(visible==1,"Exactly one cargo is attached: "..resource)
    end
    a.carrying=false
    world:person("cargoProbe",a,profile,nil,10,9,0)
    local p=world.actors.cargoProbe
    V.assert(not p.load.enabled,"Putting goods down hides the carried cargo")
    for _,node in pairs(p.cargo) do V.assert(not node.enabled,"No cargo remains visible after unloading") end
    p.node:Remove();world.actors.cargoProbe=nil
    V.finish()
end)
