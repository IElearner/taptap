-- Small procedural albedo/normal maps for actual 3D surfaces. These are not
-- scene sprites: grain and relief stay attached to the rotating mesh and light.
local Craft={}
local maps={}
local atlasImage
local generatedCells={wood={0,0},plaster={1,0},roof={2,0},stone={3,0},grass={0,1},earth={1,1},leaf={3,1}}
local function paintedTexture(style)
    if style=="grass" and cache:Exists("image/meadow-v2.png") then
        local texture=Texture2D:new()
        texture:SetData(cache:GetResource("Image","image/meadow-v2.png"))
        return texture
    end
    local cell=generatedCells[style]
    if not cell or not cache:Exists("image/materials-v2.png") then return nil end
    atlasImage=atlasImage or cache:GetResource("Image","image/materials-v2.png")
    if not atlasImage then return nil end
    local w,h=atlasImage:GetWidth()/4,atlasImage:GetHeight()/2
    local image=atlasImage:GetSubimage(IntRect(math.floor(cell[1]*w)+2,math.floor(cell[2]*h)+2,
        math.floor((cell[1]+1)*w)-2,math.floor((cell[2]+1)*h)-2))
    local texture=Texture2D:new()
    texture:SetData(image)
    return texture
end
local function noise(x,y)
    local v=math.sin(x*127.1+y*311.7)*43758.5453
    return v-math.floor(v)
end
local function sample(style,u,v)
    local n=noise(math.floor(u*128),math.floor(v*128))
    if style=="wood" then
        local ripple=math.sin(v*15+math.sin(u*18)*0.6)
        local grain=math.sin(u*150+ripple*3+math.sin(v*7)*2)
        return 0.78+grain*0.12+(n-0.5)*0.12
    elseif style=="stone" then
        local row=math.floor(v*5)
        local x=(u*4+(row%2)*0.5)%1
        local y=(v*5)%1
        local mortar=x<0.035 or y<0.06
        if mortar then return 0.48+n*0.10 end
        return 0.76+noise(math.floor(u*4+(row%2)*0.5),row)*0.19+(n-0.5)*0.1
    elseif style=="plaster" then
        return 0.88+(n-0.5)*0.12+math.sin(u*12+v*4)*0.025
    elseif style=="roof" then
        return 0.76+math.sin(u*30)*0.06+(n-0.5)*0.19
    elseif style=="leaf" then
        return 0.72+n*0.24+math.sin(u*37+v*41)*0.04
    end
    return 0.89+((math.floor(u*64)+math.floor(v*64))%2)*0.07+(n-0.5)*0.04
end
local function textures(style)
    if maps[style] then return maps[style] end
    local diffuse,normal=Image(),Image()
    diffuse:SetSize(128,128,3);normal:SetSize(128,128,3)
    for y=0,127 do for x=0,127 do
        local u,v=x/128,y/128
        local value=sample(style,u,v)
        local dx=(sample(style,u+1/128,v)-value)*0.35
        local dy=(sample(style,u,v+1/128)-value)*0.35
        diffuse:SetPixel(x,y,Color(value,value,value))
        normal:SetPixel(x,y,Color(0.5-dx,0.5-dy,1))
    end end
    local albedo,bump=Texture2D:new(),Texture2D:new()
    albedo:SetData(diffuse);bump:SetData(normal)
    local painted=paintedTexture(style)
    maps[style]={albedo=painted or albedo,normal=bump,painted=painted~=nil}
    return maps[style]
end
function Craft.style(name)
    if name:find("Timber") or name:find("Beam") or name:find("Rafter") or name:find("Plank") or name:find("Door") or
        name:find("Crate") or name:find("Log") or name:find("Trunk") or name=="Branch" or name=="Supplies" or name:find("Fence") or name:find("Awning") then return "wood" end
    if name:find("Roof") or name=="RidgeCap" then return "roof" end
    if name:find("Foundation") or name:find("Stone") or name:find("Masonry") or name=="Step" or name=="Threshold" or name=="Paver" then return "stone" end
    if name:find("Wall") then return "plaster" end
    if name=="Canopy" then return "leaf" end
    if name=="Meadow" then return "grass" end
    if name=="Torso" or name=="UpperArm" or name=="Thigh" or name=="Shin" then return "cloth" end
end
function Craft.apply(base,style)
    local map=textures(style)
    local mat=base:Clone()
    mat:SetTechnique(0,cache:GetResource("Technique","Techniques/PBR/PBRDiffNormal.xml"))
    mat:SetTexture(TU_DIFFUSE,map.albedo)
    mat:SetTexture(TU_NORMAL,map.normal)
    -- The new albedo already contains the authored material color. Multiplying
    -- it by the old prototype tint would make it muddy and too dark.
    if map.painted then mat:SetShaderParameter("MatDiffColor",Variant(Color(1,1,1))) end
    if style=="grass" then mat:SetUVTiling(Vector2(36,36)) end
    return mat
end
return Craft
