-- Shared hand-painted resource cache. Missing assets remain explicit fallbacks during import.
local Art = {}
local textures, checked, available, context = {}, {}, {}, nil
function Art.path(name) return "assets/image/" .. name .. ".png" end
function Art.exists(name)
    if available[name] == nil then available[name] = fileSystem:FileExists(Art.path(name)) end
    return available[name]
end
function Art.texture(vg, name)
    context = vg
    if not checked[name] then
        checked[name] = true
        if Art.exists(name) then
            local flags = name == "panel-wood" and (NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY) or 0
            textures[name] = nvgCreateImage(vg, Art.path(name), flags)
        end
    end
    return textures[name]
end
function Art.draw(vg, name, x, y, w, h, alpha)
    local handle = Art.texture(vg, name)
    if not handle or handle <= 0 then return false end
    nvgBeginPath(vg); nvgRect(vg, x, y, w, h)
    nvgFillPaint(vg, nvgImagePattern(vg, x, y, w, h, 0, handle, alpha or 1)); nvgFill(vg)
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
    textures, checked, available, context = {}, {}, {}, nil
end
return Art
