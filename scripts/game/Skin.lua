-- Original carved timber / hammered bronze skin, drawn at the UI logical scale.
local UI = require "urhox-libs/UI"
local Art = require "game.Art"
local Skin = { ink = { 235, 221, 183 }, muted = { 173, 160, 125 }, gold = { 208, 172, 99 }, dark = { 36, 38, 32 } }
local function rect(vg, x, y, w, h, c)
    nvgBeginPath(vg); nvgRect(vg, x, y, w, h); nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], c[4] or 255)); nvgFill(vg)
end
function Skin.frame(vg, l, light)
    local x, y, w, h = l.x, l.y, l.w, l.h
    rect(vg, x + 3, y + 5, w, h, { 0, 0, 0, 85 })
    rect(vg, x, y, w, h, { 27, 25, 20 })
    rect(vg, x + 1, y + 1, w - 2, h - 2, { 130, 109, 67 })
    rect(vg, x + 3, y + 3, w - 6, h - 6, light and { 92, 72, 43 } or { 45, 43, 33 })
    Art.wood(vg, x+4, y+4, w-8, h-8)
    for i = 6, h - 5, 5 do
        rect(vg, x + 5, y + i, w - 10, 1, { 158, 126, 75, (i % 3 + 1) * 5 })
    end
    rect(vg, x + 5, y + 5, w - 10, 1, { 206, 174, 111, 100 })
    rect(vg, x + 5, y + h - 6, w - 10, 1, { 12, 14, 10, 180 })
    for _, px in ipairs({ x + 7, x + w - 7 }) do
        for _, py in ipairs({ y + 7, y + h - 7 }) do
            nvgBeginPath(vg); nvgCircle(vg, px, py, 2); nvgFillColor(vg, nvgRGBA(183, 151, 88, 255)); nvgFill(vg)
            rect(vg, px - 1, py, 2, 1, { 65, 52, 30 })
        end
    end
end
function Skin.panel(props)
    local p = UI.Panel(props)
    function p:Render(vg) Skin.frame(vg, self:GetAbsoluteLayout()) end
    return p
end
local function density()
    return UI.GetScale() / math.max(1, graphics:GetDPR())
end
function Skin.label(text, size, c)
    return UI.Label { text = text, fontSize = math.max(size or 14, 12 / density()), fontColor = c or Skin.ink, flexShrink = 1 }
end
function Skin.button(text, action, props)
    local p = props or {}
    local icon = p.artIcon
    p.artIcon = nil
    if icon and Art.exists("icon-" .. icon) then p.paddingLeft = 34 end
    p.text, p.onClick = text, action
    p.height, p.minWidth, p.fontSize = p.height or 44, p.minWidth or 44, p.fontSize or 14
    p.minHeight, p.minWidth = math.max(p.height, 44 / density() + 1), math.max(p.minWidth, 44 / density() + 1)
    p.fontSize = math.max(p.fontSize, 13 / density())
    p.flexShrink = 0
    p.textColor, p.backgroundColor = p.fontColor or Skin.ink, p.backgroundColor or { 83, 69, 43 }
    p.fontColor = nil
    if Art.exists("button-painting") then
        p.backgroundImage = Art.path("button-painting")
        p.backgroundFit = "fill"
        p.pressedBackgroundImageOpacity, p.hoverBackgroundImageOpacity = 0.72, 0.9
    end
    p.borderColor, p.borderWidth, p.borderRadius = { 157, 130, 77 }, 1, 2
    p.paddingHorizontal = p.paddingHorizontal or 10
    p.pressedBackgroundColor, p.hoverBackgroundColor = { 116, 88, 45 }, { 99, 81, 47 }
    local b = UI.Button(p)
    local original = b.Render
    function b:Render(vg)
        original(self, vg)
        local l = self:GetAbsoluteLayout()
        if icon then Art.draw(vg, "icon-" .. icon, l.x+7, l.y+(l.h-24)/2, 24, 24) end
        rect(vg, l.x + 3, l.y + 3, l.w - 6, 1, { 218, 186, 116, 75 })
        rect(vg, l.x + 3, l.y + l.h - 4, l.w - 6, 1, { 20, 20, 16, 170 })
    end
    return b
end
function Skin.icon(name, size)
    local exists = Art.exists("icon-" .. name)
    local p = UI.Panel { width = exists and (size or 22) or 0, height = size or 22, flexShrink = 0, pointerEvents = "none" }
    function p:Render(vg)
        local l = self:GetAbsoluteLayout()
        if exists then Art.draw(vg, "icon-" .. name, l.x,l.y,l.w,l.h) end
    end
    return p
end
return Skin
