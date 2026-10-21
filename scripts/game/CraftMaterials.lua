-- File-backed materials keep shader/texture dependencies visible to mobile
-- builds. No runtime Image uploads, material clones or technique replacement.
local Catalog=require "game.WorldMaterialManifest"
local Craft={}
local bases=setmetatable({},{__mode="k"})
local loaded={}
local function resource(style,index)
    if style=='water' or style=='earth' then
        local path='art/v9/'..style..'.material'
        if not loaded[path] then loaded[path]=cache:GetResource('Material',path) end
        return loaded[path]
    end
    local path=Catalog.materials[style][index]
    local mat=loaded[path]
    if not mat then
        mat=cache:GetResource("Material",path)
        if style=="grass" then mat:SetUVTiling(Vector2(60,60)) end
        loaded[path]=mat
    end
    return mat
end
function Craft.material(r,g,b)
    local best,minimum=1,math.huge
    for i,c in ipairs(Catalog.palette) do
        local d=(r-c[1])^2+(g-c[2])^2+(b-c[3])^2
        if d<minimum then best,minimum=i,d end
    end
    local mat=resource("solid",best)
    bases[mat]=best
    return mat
end
function Craft.style(name)
    if name=='Water' then return 'water' end
    if name=='RiverBank' then return 'earth' end
    if name:find("Timber") or name:find("Beam") or name:find("Rafter") or name:find("Plank") or name:find("Door") or
        name:find("Crate") or name:find("Log") or name:find("Trunk") or name=="Branch" or name=="Supplies" or name:find("Fence") or name:find("Awning") then return "wood" end
    if name:find("Roof") or name=="RidgeCap" then return "roof" end
    if name:find("Foundation") or name:find("Stone") or name:find("Masonry") or name=="Step" or name=="Threshold" or name=="Paver" or name=="RoadCenter" or name=="RoadArm" then return "stone" end
    if name:find("Wall") then return "plaster" end
    if name=="Canopy" then return "leaf" end
    if name=="Meadow" then return "grass" end
    if name=="Torso" or name=="UpperArm" or name=="Thigh" or name=="Shin" then return "cloth" end
end
function Craft.apply(base,style)
    return resource(style,bases[base] or 1)
end
return Craft
