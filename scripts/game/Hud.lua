local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
local Hud = {}
local ink, paper, muted, red = { 63, 58, 43 }, { 242, 230, 197, 249 }, { 125, 113, 86 }, { 143, 61, 43 }
local function label(text, size, c)
    return UI.Label { text = text, fontSize = size or 14, fontColor = c or ink, flexShrink = 1 }
end
local function button(text, action, props)
    local p = props or {}
    p.text, p.onClick = text, action
    p.height, p.minWidth, p.fontSize = p.height or 48, p.minWidth or 52, p.fontSize or 15
    p.backgroundColor, p.textColor = p.backgroundColor or { 224, 208, 166 }, p.fontColor or ink
    p.fontColor = nil
    p.borderWidth, p.borderColor = 1, { 164, 142, 99 }
    p.borderRadius, p.paddingHorizontal = 2, 12
    return UI.Button(p)
end
local function panel(props)
    props.backgroundColor, props.borderWidth, props.borderColor = paper, 1, { 161, 140, 95 }
    return UI.Panel(props)
end
local function costText(def)
    local parts = {}
    for _, resource in ipairs(D.goods) do if def.cost[resource] then parts[#parts + 1] = def.cost[resource] .. D.names[resource] end end
    return #parts > 0 and table.concat(parts, " · ") or "免费"
end
function Hud.create(sim, world, actions)
    local resources, buildButtons = {}, {}
    local modeLabel = label("", 13, muted)
    ---@type Widget[]
    local topChildren = { label("山河里", 23, red), modeLabel }
    for _, r in ipairs(D.goods) do
        resources[r] = label("", 14)
        topChildren[#topChildren + 1] = resources[r]
    end
    local people = label("", 13)
    topChildren[#topChildren + 1] = people
    local pause = button("暂停", function() sim.paused = not sim.paused end, { id = "pause" })
    local speed = button("1倍", function() sim.speed = sim.speed == 1 and 2 or 1 end)
    topChildren[#topChildren + 1], topChildren[#topChildren + 2] = pause, speed
    local title, line1, line2, line3 = label("", 17, red), label("", 13), label("", 13), label("", 13)
    for _, item in ipairs({ line1, line2, line3 }) do item:SetStyle({ width = "100%", whiteSpace = "normal" }) end
    local progress = label("", 13, muted)
    local next = button("完成后继续", function() sim:nextLesson() end, { backgroundColor = { 152, 73, 47 }, fontColor = { 255, 242, 212 } })
    local raid = button("开始守村", function() local _, message = sim:startRaid(); sim:notify(message) end)
    local worldInfo = label("", 12, muted)
    worldInfo:SetStyle({ width = "100%", whiteSpace = "normal" })
    local tutorial = panel { position = "absolute", left = 12, top = 76, width = 268, padding = 12, gap = 6,
        children = { worldInfo, title, line1, line2, line3, progress, next, raid } }
    local selectedTitle, selectedInfo, selectedState = label("村务", 18, red), label("点击建筑查看详情。", 13), label("", 13, muted)
    selectedInfo:SetStyle({ width = "100%", whiteSpace = "normal" })
    selectedState:SetStyle({ width = "100%", whiteSpace = "normal" })
    local minus = button("减岗", function() if actions.selected then sim:staff(actions.selected, -1) end end)
    local plus = button("加岗", function() if actions.selected then sim:staff(actions.selected, 1) end end)
    local train = button("训练乡勇", function() local _, message = sim:train(); sim:notify(message) end)
    local repair = button("修缮义仓", function() local _, message = sim:repair(); sim:notify(message) end)
    local selectedPanel = panel { position = "absolute", right = 12, top = 76, width = 246, padding = 12, gap = 9,
        children = { selectedTitle, selectedInfo, selectedState, UI.Panel { flexDirection = "row", gap = 8, children = { minus, plus, train, repair } } } }
    local buildItems = {}
    for _, kind in ipairs(D.order) do
        local def = D.buildings[kind]
        local btn = button(def.name, function() actions.setMode(kind) end, { id = "build_" .. kind, flexGrow = 1, minWidth = 56, paddingHorizontal = 4, height = 50, fontSize = 15 })
        buildButtons[kind] = btn
        buildItems[#buildItems + 1] = UI.Panel { flexGrow = 1, flexBasis = 0, gap = 4, alignItems = "stretch", children = { btn, label(costText(def), 11, muted) } }
    end
    local toolHint = label("点击建筑查看 · 单指拖动地图 · 双指缩放", 13, muted)
    local toast = label("", 14, { 255, 243, 212 })
    local notice = UI.Panel { position = "absolute", bottom = 160, alignSelf = "center", padding = 12,
        maxWidth = "80%", backgroundColor = { 53, 65, 46, 235 }, children = { toast }, pointerEvents = "none" }
    local expand = button("拓荒", function()
        local _, message = sim:expand(); sim:notify(message)
    end, { id = "expandWorld", height = 44 })
    expand:SetVisible(sim.mode == "infinite")
    local frontier = button("远方", function() world.frontier() end, { height = 44 })
    frontier:SetVisible(sim.mode == "infinite")
    local showModeMenu = function() end
    local buildBar = panel { position = "absolute", bottom = 8, left = 12, right = 12, padding = 10, gap = 8, children = {
        UI.Panel { flexDirection = "row", alignItems = "center", gap = 10, children = {
            label("营造", 18, red), toolHint,
            button("查看", function() actions.setMode("inspect") end, { height = 44 }),
            button("−", function() world.zoom(-0.15) end, { height = 44 }), button("+", function() world.zoom(0.15) end, { height = 44 }),
            button("归村", function() world.home() end, { height = 44 }),
            expand, frontier,
            button("教程", function()
                if sim.lesson > #D.lessons then sim.lesson = 1; sim.skipped = false; tutorial:Show()
                else tutorial:SetVisible(not tutorial:IsVisible()) end
            end, { height = 44 }),
            button("自由", function()
                sim.skipped = true; sim.lesson = #D.lessons + 1; tutorial:Hide()
                sim:notify("已跳过指引；点击「教程」可重新阅读。")
            end, { height = 44 }),
            button("模式", function() showModeMenu() end, { height = 44 }),
        } },
        UI.Panel { flexDirection = "row", gap = 8, children = buildItems },
    } }
    ---@type Panel
    local intro
    intro = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center",
        backgroundColor = { 30, 40, 29, 170 }, children = { panel { width = "86%", maxWidth = 510, padding = 28, gap = 16, children = {
            label("山 河 里", 30, red), label(D.modes[sim.mode].name, 19),
            label(D.modes[sim.mode].description, 14),
            label(sim.mode == "finite" and "固定 22×22 河谷，生产新口粮并守村即可通关。" or "没有最终边界；拓荒发现新区域，守住一波再迎下一波。", 14),
            UI.Panel { flexDirection = "row", gap = 10, children = {
                button("有限关卡", function() actions.changeMode("finite") end, { id = "modeFinite", flexGrow = 1, height = 44,
                    backgroundColor = sim.mode == "finite" and red or nil, fontColor = sim.mode == "finite" and { 255, 243, 212 } or nil }),
                button("无限拓荒", function() actions.changeMode("infinite") end, { id = "modeInfinite", flexGrow = 1, height = 44,
                    backgroundColor = sim.mode == "infinite" and red or nil, fontColor = sim.mode == "infinite" and { 255, 243, 212 } or nil }),
            } },
            label("横屏游玩 · 点击选中 · 单指拖动 · 双指缩放", 13, muted),
            button("随里正入村 / 继续", function() sim.started = true; sim.paused = false; intro:Hide() end, { id = "enterVillage", backgroundColor = red, fontColor = { 255, 243, 212 } }),
        } } } }
    showModeMenu = function() sim.paused = true; intro:Show() end
    local resultTitle, resultText = label("", 28, red), label("", 15)
    local ending = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = { 30, 40, 29, 150 }, children = { panel { width = "80%", maxWidth = 480, padding = 26, gap = 16, children = {
            resultTitle, resultText, button("重新开始", function() actions.restart() end),
            button("切换模式", function() actions.changeMode(sim.mode == "finite" and "infinite" or "finite") end),
        } } } }
    local root = UI.Panel { width = "100%", height = "100%", pointerEvents = "box-none", children = {
        world.panel, UI.SafeAreaView { width = "100%", height = "100%", pointerEvents = "box-none", children = {
            panel { position = "absolute", top = 8, left = 12, right = 12, height = 58, paddingHorizontal = 12,
                flexDirection = "row", alignItems = "center", justifyContent = "space-between", gap = 8, children = topChildren },
            tutorial, selectedPanel, notice, buildBar, intro, ending,
        } },
    } }
    local function update()
        for _, r in ipairs(D.goods) do resources[r]:SetText(D.names[r] .. " " .. sim.stock[r]) end
        modeLabel:SetText(sim.mode == "finite" and "有限 · 清溪里" or ("无限 · 拓荒 " .. sim.map.expansion))
        people:SetText("乡亲 " .. sim.population .. " / 闲 " .. sim:availableWorkers())
        pause:SetText(sim.paused and "继续" or "暂停"); speed:SetText(sim.speed .. "倍")
        local lesson = D.lessons[sim.lesson]
        if sim.mode == "infinite" then
            worldInfo:SetText("拓荒 " .. sim.map.expansion .. " 圈 · 已守 " .. sim.wavesDefeated .. " 波 · 耐久 " .. sim.health)
        else worldInfo:SetText("有限河谷 · 22×22 · 义仓 " .. sim.health) end
        local value, target = sim:lessonProgress()
        title:SetText(lesson and lesson.title or (sim.mode == "infinite" and "山河未尽，继续拓荒" or "重建并守住清溪里"))
        line1:SetText(lesson and lesson.lines[1] or (sim.mode == "infinite" and ("生存 " .. math.floor(sim.elapsed) .. " 秒 · 乡里分 " .. sim.score) or "民居、稻田、磨坊、炊坊须竣工。"))
        line2:SetText(lesson and lesson.lines[2] or (sim.mode == "infinite" and ("下次来袭 " .. math.ceil(sim.nextRaid) .. " 秒；断粮会损耗义仓。") or "至少送回 4 份新口粮，再击退山匪。"))
        local cost = sim:expansionCost()
        line3:SetText(lesson and lesson.lines[3] or (sim.mode == "infinite" and ("拓荒需 " .. cost.wood .. " 木 / " .. cost.food .. " 粮；余木 " .. sim.timber .. " 石 " .. sim.rock) or "在有限空间安排运输和岗位。"))
        progress:SetText(lesson and ("当前进度  " .. value .. " / " .. target) or "教程已结束 / 跳过")
        next:SetDisabled(value < target); next:SetVisible(lesson ~= nil)
        raid:SetVisible(sim.lesson >= 8 and not sim.raid and not sim.defended)
        if sim.mode == "infinite" then raid:SetVisible(sim.lesson >= 8 and not sim.raid); raid:SetText("提前迎敌") end
        toast:SetText(sim.message); notice:SetVisible(sim.messageTime > 0)
        local b = actions.selected
        selectedPanel:SetVisible(b ~= false and b ~= nil)
        if b then
            local def = D.buildings[b.kind]
            selectedTitle:SetText(def.name); selectedInfo:SetText(def.description)
            local state = b.complete and ("岗位 " .. b.workers .. " · " .. (sim:connected(b) and "道路畅通" or "尚未通路")) or ("修建中 " .. math.floor(b.progress * 100) .. "%")
            if def.input then state = state .. " · 待料 " .. b.inputs end
            selectedState:SetText(state)
            minus:SetVisible(def.output ~= nil); plus:SetVisible(def.output ~= nil)
            train:SetVisible(b.kind == "barracks")
            repair:SetVisible(b.kind == "store")
        end
        for kind, btn in pairs(buildButtons) do
            btn:SetBackgroundColor(actions.mode == kind and { 151, 78, 47 } or { 224, 208, 166 })
            btn:SetProp("textColor", actions.mode == kind and { 255, 243, 212 } or ink)
        end
        toolHint:SetText(actions.mode == "inspect" and "单指拖动 · 双指缩放" or (D.buildings[actions.mode].name .. "：点击空地放置 · 门前接路"))
        ending:SetVisible(sim.victory or sim.defeat)
        if sim.victory then resultTitle:SetText("炊烟又起，乡里安宁"); resultText:SetText("你已打通粮食生产链，并带领乡勇守住清溪里。")
        elseif sim.defeat then resultTitle:SetText("义仓失守"); resultText:SetText(sim.mode == "infinite" and ("本局生存 " .. math.floor(sim.elapsed) .. " 秒，拓荒 " .. sim.map.expansion .. " 圈，守住 " .. sim.wavesDefeated .. " 波。") or "重新规划生产与兵力，再带乡亲们守一次村。") end
    end
    ---@class VillageHud
    local result = { root = root, update = update, dismissIntro = function() sim.started = true; intro:Hide() end }
    return result
end
return Hud
