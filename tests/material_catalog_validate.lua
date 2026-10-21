local Craft=require "game.CraftMaterials"
local Catalog=require "game.WorldMaterialManifest"
local Game=require "network.Standalone"
local demo,view
V.atFrame(8,function()
    for style,paths in pairs(Catalog.materials) do
        for _,path in ipairs(paths) do
            local material=cache:GetResource("Material",path)
            V.assert(material and material:GetTechnique(0)~=nil,"Static material has a packaged technique: "..path)
            if style~="solid" then V.assert(material:GetTexture(TU_DIFFUSE)~=nil,"Textured material declares its albedo file: "..path) end
        end
    end
    local base=Craft.material(65,98,53)
    V.assert(base==cache:GetResource("Material",Catalog.materials.solid[6]),"Primitive colours load a real material asset")
    V.assert(Craft.apply(base,"leaf")==cache:GetResource("Material",Catalog.materials.leaf[6]),"Leaf material is loaded without cloning or uploading textures")
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud
    demo,view,hud=Game.Inspect();hud.dismissIntro();demo,view,hud=Game.Inspect();hud.dismissIntro()
    demo.skipped=true;demo.paused=true;hud.update()
    demo:addBuilding("house",8,8,true)
    demo:addBuilding("kitchen",11,13,true)
    demo:addBuilding("woodcutter",15,10,true)
    demo:addBuilding("farm",7,12,true)
    local update=view.modelWorld.update
    view.modelWorld.update=function(self,...)
        update(self,...)
        local center=Vector3(.25,.1,-1.2)
        self.cameraNode.position=center+Vector3(0,18,-math.sqrt(700)*18/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=7
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
V.atFrame(20,function() V.finish() end)
