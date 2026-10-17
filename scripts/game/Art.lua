-- Shared hand-painted resource cache. Paths here are virtual resource paths,
-- relative to settings.json asset_dirs, not files in the project checkout.
local Art = {}
local textures, context = {}, nil
local direct = {}
for _,name in ipairs({"login-painting","portrait-elder","atlas-buildings","atlas-environment",
    "atlas-villagers","atlas-workers","atlas-loaded","atlas-combatants","atlas-icons",
    "panel-wood","button-painting"}) do direct[name]=true end
local atlas = {}
local function register(prefix,atlasName,names,cols,rows,options)
    for i,name in ipairs(names) do
        atlas[prefix .. name]={source=atlasName,col=(i-1)%cols,row=math.floor((i-1)/cols),cols=cols,rows=rows,
            stretch=options and options.stretch,crop=options and options.crop}
    end
end
register("building-","atlas-buildings",{"store","house","farm","mill","kitchen","woodcutter","quarry","courier","barracks"},3,3)
register("","atlas-environment",{"tree-oak","tree-pine","tree-bamboo","rock-moss","bush-flowers","reeds",
    "ground-grass","ground-road","ground-water"},3,3)
for _,name in ipairs({"tree-oak","tree-pine","tree-bamboo","rock-moss","bush-flowers","reeds"}) do atlas[name].stretch=true end
for _,name in ipairs({"ground-grass","ground-road","ground-water"}) do
    atlas[name].stretch=true;atlas[name].crop={0,42,1,0.79}
end
local directions={"se","sw","ne","nw"}
for row,id in ipairs({"blue-man","ochre-woman","grey-elder","green-woman"}) do
    for col,dir in ipairs(directions) do
        local spec={source="atlas-villagers",col=col-1,row=row-1,cols=4,rows=4}
        atlas["person-civilian-" .. id .. "-" .. dir]=spec
        atlas["person-loaded-" .. id .. "-" .. dir]={source="atlas-loaded",col=col-1,row=row-1,cols=4,rows=4}
    end
end
for row,id in ipairs({"militia","bandit"}) do
    for col,dir in ipairs(directions) do
        atlas["person-" .. id .. "-" .. dir]={source="atlas-combatants",col=col-1,row=row-1,cols=4,rows=2}
    end
end
register("icon-","atlas-icons",{"build","village","army","system","wood","stone","grain","flour",
    "food","home","pause","save","idle","tutorial","map","supplies"},4,4)
for row,id in ipairs({"farmer","artisan","logger","guard"}) do
    for col,dir in ipairs(directions) do
        atlas["person-occupation-" .. id .. "-" .. dir]={source="atlas-workers",col=col-1,row=row-1,cols=4,rows=4}
    end
end
function Art.path(name) return "image/" .. name .. ".png" end
function Art.exists(name)
    return direct[name] == true or atlas[name] ~= nil
end
function Art.texture(vg, name)
    context = vg
    if not direct[name] then return nil end
    if textures[name] and textures[name] > 0 then return textures[name] end
    local flags = name == "panel-wood" and (NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY) or 0
    local handle = nvgCreateImage(vg, Art.path(name), flags)
    if handle and handle > 0 then textures[name] = handle end
    return textures[name]
end
function Art.draw(vg, name, x, y, w, h, alpha)
    local handle = Art.texture(vg, name)
    if handle and handle > 0 then
        nvgBeginPath(vg); nvgRect(vg, x, y, w, h)
        nvgFillPaint(vg, nvgImagePattern(vg, x, y, w, h, 0, handle, alpha or 1)); nvgFill(vg)
        return true
    end
    local spec=atlas[name]
    if not spec then return false end
    handle=Art.texture(vg,spec.source)
    if not handle or handle<=0 then return false end
    local imageW,imageH=nvgImageSize(vg,handle)
    local cellW,cellH=imageW/spec.cols,imageH/spec.rows
    local srcX,srcY=spec.col*cellW,spec.row*cellH
    local srcW,srcH=cellW,cellH
    if spec.crop then
        srcX=srcX+spec.crop[1]*cellW;srcY=srcY+spec.crop[2]
        srcW=srcW*spec.crop[3];srcH=srcH*spec.crop[4]
    end
    local dx,dy,dw,dh=x,y,w,h
    if not spec.stretch then
        local scale=math.min(w/srcW,h/srcH)
        dw,dh=srcW*scale,srcH*scale
        dx,dy=x+(w-dw)/2,y+h-dh
    end
    local sx,sy=dw/srcW,dh/srcH
    nvgBeginPath(vg);nvgRect(vg,dx,dy,dw,dh)
    nvgFillPaint(vg,nvgImagePattern(vg,dx-srcX*sx,dy-srcY*sy,imageW*sx,imageH*sy,0,handle,alpha or 1));nvgFill(vg)
    return true
end
function Art.wood(vg, x, y, w, h)
    local handle = Art.texture(vg, "panel-wood")
    if not handle or handle <= 0 then return false end
    nvgBeginPath(vg); nvgRect(vg, x, y, w, h)
    -- Keep brush grain at a stable scale across narrow headers and large drawers.
    nvgFillPaint(vg, nvgImagePattern(vg, x, y, 256, 256, 0, handle, 1)); nvgFill(vg)
    return true
end
function Art.release()
    if context then
        for _, handle in pairs(textures) do if handle > 0 then nvgDeleteImage(context, handle) end end
    end
    textures, context = {}, nil
end
return Art
