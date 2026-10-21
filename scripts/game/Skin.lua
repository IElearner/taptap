-- PixelForge UI widgets; original pixel signs, no painted frame or atlas.
local UI = require "urhox-libs/UI"
local C = require("game.PixelTheme").colors
local Skin = {ink=C.text,muted=C.textSecondary,gold=C.warning,dark=C.background,accent=C.primary,green=C.success}
local function density() return UI.GetScale() / math.max(1, graphics:GetDPR()) end
function Skin.touchSize() return math.ceil(44 / density()) + 1 end
local function pointSize(size)
    local px = (size or 12)>=30 and 36 or (size or 12)>=22 and 24 or (size or 12)>=16 and 18 or 12
    return math.max(px*.75,9/density())
end
function Skin.panel(props)
    props=props or {};props.variant=props.variant or "outlined";props.showDividers=false
    props.padding=props.padding or 0;props.gap=props.gap or 0
    props.backgroundColor=props.backgroundColor or C.surface
    return UI.Card(props)
end
function Skin.label(text,size,color,id)
    return UI.Label{id=id,text=text,fontSize=pointSize(size),fontFamily="sans",fontColor=color or Skin.ink,
        fontWeight=(size or 12)>=16 and "bold" or "normal",flexShrink=1,lineHeight=1.35}
end
-- Seven-pixel signs assembled from integer UI rectangles, not smooth vectors.
local glyphs={
    wood={"0011100","0111110","1100011","1011101","1100011","0111110","0011100"},
    stone={"0001100","0011110","0111111","1111111","1110111","1111111","0111110"},
    food={"0010100","0111110","0011100","0001000","1111111","0111110","0011100"},
    build={"0011110","0011111","0001100","0011000","0110000","1100000","1000000"},
    village={"0001000","0011100","0111110","1100011","0111110","0101010","0111110"},
    army={"1111111","1101011","1101011","1111111","0111110","0011100","0001000"},
    system={"0011100","0111110","1110111","1100011","1110111","0111110","0011100"},
    home={"0001000","0011100","0111110","1111111","0101010","0101010","0111110"},
    save={"1111111","1100011","1100011","1111111","1100011","1100011","1111111"},
}
function Skin.icon(name,size)
    local pattern,width= glyphs[name],size or 21
    local cell,children=math.max(1,math.floor(width/7)),{}
    for y,line in ipairs(pattern or {}) do for x=1,#line do if line:sub(x,x)=="1" then
        children[#children+1]=UI.Panel{position="absolute",left=(x-1)*cell,top=(y-1)*cell,width=cell,height=cell,
            backgroundColor=name=="stone" and C.textSecondary or C.warning,pointerEvents="none"}
    end end end
    return UI.Panel{width=pattern and width or 0,height=width,flexShrink=0,pointerEvents="none",children=children}
end
function Skin.button(text,action,props)
    local p={};for key,value in pairs(props or {}) do p[key]=value end
    local icon=p.artIcon;p.artIcon=nil;p.text,p.onClick=text,action
    p.height=math.max(p.height or 44,Skin.touchSize());p.minHeight=p.height;p.minWidth=math.max(p.minWidth or 0,Skin.touchSize())
    p.fontSize,p.fontFamily,p.fontWeight=pointSize(p.fontSize or 12),"sans","bold";p.flexShrink=0
    p.textColor,p.fontColor=p.textColor or p.fontColor or Skin.ink,nil;p.variant=p.variant or "secondary"
    if icon and glyphs[icon] then p.paddingLeft=34 end
    local b=UI.Button(p)
    if icon and glyphs[icon] then local sign=Skin.icon(icon,21);sign:SetStyle{position="absolute",left=8,top="50%",marginTop=-10};b:AddChild(sign) end
    return b
end
return Skin
