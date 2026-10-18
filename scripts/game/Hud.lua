local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
local Farm = require "game.FarmCycle"
local Skin = require "game.Skin"
local Mentor = require "game.Mentor"
local Art = require "game.Art"
local label, button, panel = Skin.label, Skin.button, Skin.panel
local Hud = {}
local function row(children, gap) return UI.Panel { flexDirection = "row", alignItems = "center", gap = gap or 8, children = children } end
local function costText(def)
    local parts = {}
    for _, r in ipairs(D.goods) do if def.cost[r] then parts[#parts + 1] = def.cost[r] .. D.names[r] end end
    return #parts > 0 and table.concat(parts, " / ") or "免费铺设"
end
function Hud.create(sim, world, actions)
    local info, session = actions.saveInfo, actions.session
    local opened, selectedLast, roadLast = nil, false, false
    local mentor, mentorTitle, mentorLine1, mentorLine2, mentorLine3, mentorProgress, mentorGo
    local mentorFade, mentorShownLesson, mentorCompleteShown = 0, 0, 0
    local showMentor, dismissMentor
    local drawers, mainButtons, resources = {}, {}, {}
    local function close() opened = nil end
    local function open(name)
        if opened == name then opened = nil else opened = name end
    end
    local function header(name)
        return row { label(name, 20, Skin.gold), UI.Panel { flexGrow = 1 }, button("×", close, { width = 44, id = "closeDrawer" .. name }) }
    end
    local function drawer(name, title, items)
        local p = panel { id = "drawer_" .. name, position = "absolute", left = 106, top = 58, bottom = 24, width = 310, padding = 14, gap = 8,
            visible = false, children = { header(title), UI.ScrollView { flexGrow = 1, flexBasis = 0, scrollY = true,
                children = { UI.Panel { gap = 9, paddingRight = 5, children = items } } } } }
        drawers[name] = p
        return p
    end
    ---@type Widget[]
    local top = { label("山 河 里", 19, Skin.gold) }
    for _, r in ipairs(D.topGoods) do
        resources[r] = label("", 13)
        top[#top + 1] = row({ Skin.icon(r, 22), resources[r] }, 3)
    end
    local people = label("", 12, Skin.muted); top[#top + 1] = people
    local topbar = panel { position = "absolute", top = 8, left = 12, right = 12, height = 42, paddingHorizontal = 15,
        flexDirection = "row", alignItems = "center", justifyContent = "space-between", gap = 8, children = top }
    ---@type Widget[]
    local buildItems = { label("可以先规划建筑；接通门前道路后，工人才会取材施工。轮廓内的格子才算占地。", 12, Skin.muted) }
    for _, kind in ipairs(D.order) do
        local k, def = kind, D.buildings[kind]
        local width,height=D.footprint(k)
        buildItems[#buildItems + 1] = row {
            button(def.name, function() actions.setMode(k); close() end, { id = "build_" .. k, width = 100 }),
            UI.Panel { flexGrow = 1, flexBasis = 0, minWidth = 0, gap = 3, children = { label(costText(def), 12, Skin.gold), label("占地 " .. width .. "×" .. height .. " / " .. #D.cells(k) .. "格" .. (def.shape and " · L形" or "") .. " · " .. (def.output and ("生产 " .. D.names[def.output]) or (k == "road" and "运输的命脉" or "村庄设施")), 11, Skin.muted) } },
        }
    end
    local buildDrawer = drawer("build", "营 造 工 坊", buildItems)
    local title, line1, line2, line3 = label("", 17, Skin.gold), label("", 13), label("", 13), label("", 13)
    local progress, worldInfo = label("", 12, Skin.gold), label("", 12, Skin.muted)
    local supplyInfo=label("",12,Skin.muted)
    local next = button("完成后继续 →", function() if sim:nextLesson() then close() end end, { id = "nextLesson" })
    local activityInfo=label("",12,Skin.muted)
    local jobInfo=label("",12,Skin.gold)
    local villageDrawer = drawer("village", "乡 里 事 务", {
        worldInfo, supplyInfo, jobInfo, activityInfo, title, line1, line2, line3, progress, next,
        label("木材获取：营造 → 伐木场 → 门前接路 → 安排工人 → 工人运回义仓。",12,Skin.gold),
        label("肉食链：牧场养牲畜 → 屠宰场加工鲜肉 → 食堂烹制口粮。",12,Skin.gold),
        button("重新阅读教程", function() sim.lesson, sim.skipped = 1, false; mentorShownLesson=0; close() end,{id="restartMentor"}),
        button("结束教学 · 自由经营", function() sim.skipped, sim.lesson = true, #D.lessons + 1; close(); if dismissMentor then dismissMentor() end end),
    })
    local military = label("", 14)
    local raid = button("开始守村", function() local _, msg = sim:startRaid(); sim:notify(msg) end, { id = "startRaid" })
    local expand = button("拓荒 · 发现新土地", function() local _, msg = sim:expand(); sim:notify(msg) end, { id = "expandWorld" })
    expand:SetVisible(sim.mode == "infinite")
    local frontier = button("前往边疆", function() world.frontier(); close() end)
    frontier:SetVisible(sim.mode == "infinite")
    local armyDrawer = drawer("army", "军 务 与 拓 荒", { military,
        label("在乡勇营训练，义仓附近自动迎敌。", 12, Skin.muted),
        button("训练乡勇 · 2木 / 2粮 / 1人", function() local _, msg = sim:train(); sim:notify(msg) end, { id = "trainMilitia" }),
        raid, button("修缮义仓 · 4木 / 4石", function() local _, msg = sim:repair(); sim:notify(msg) end), expand, frontier,
    })
    local intro, confirmNew
    local status, summary = label("", 12, Skin.muted), label("", 12, Skin.muted)
    summary:SetStyle({ width = "100%", whiteSpace = "normal" })
    status:SetStyle({ width = "100%", whiteSpace = "normal" })
    local idle = button("", function() actions.toggleIdle() end, { id = "toggleIdle" })
    local pause = button("", function() sim.paused = not sim.paused end, { id = "pause", flexGrow = 1 })
    local speed = button("", function() sim.speed = sim.speed == 1 and 2 or 1 end, { flexGrow = 1 })
    local systemDrawer = drawer("system", "系 统 与 存 档", { status, summary,
        row { pause, speed }, button("保存进度", function() actions.save() end, { id = "saveGame", artIcon = "save" }), idle,
        button("返回模式选择", function() sim.menuOpen = true; intro:Show(); close() end, { id = "showModes" }),
        button("重新开始本模式", function() confirmNew:Show() end, { id = "newGame" }),
    })
    local selectedTitle, selectedInfo, selectedState = label("", 18, Skin.gold), label("", 13), label("", 12, Skin.muted)
    selectedState:SetStyle({ width = "100%", whiteSpace = "normal" })
    selectedInfo:SetStyle({ width = "100%", whiteSpace = "normal" })
    local minus = button("减少岗位", function() if actions.selected then sim:staff(actions.selected, -1) end end, { flexGrow = 1 })
    local plus = button("增加岗位", function() if actions.selected then sim:staff(actions.selected, 1) end end, { flexGrow = 1 })
    local train = button("训练乡勇", function() local _, msg = sim:train(); sim:notify(msg) end)
    local repair = button("修缮义仓", function() local _, msg = sim:repair(); sim:notify(msg) end)
    local selectedDrawer = drawer("selected", "建 筑 详 情", { selectedTitle, selectedInfo, selectedState, row { minus, plus }, train, repair })
    local roadState=label("",14,Skin.gold)
    local roadDrawer=drawer("road","道 路 工 地",{roadState,label("工人会先到义仓取材，再走到路段旁施工。规划路段完工前不能运输。",13)})
    local dockItems = {}
    for _, item in ipairs({ {"build","营造"}, {"village","村务"}, {"army","军务"}, {"system","系统"} }) do
        local name = item[1]
        local b = button(item[2], function() open(name) end, { id = "open_" .. name, artIcon = name, width = 84, height = 46, fontSize = 14 })
        mainButtons[name] = b; dockItems[#dockItems + 1] = b
    end
    local dock = panel { position = "absolute", left = 12, top = 112, padding = 7, flexDirection = "column", gap = 5, children = dockItems }
    local controls = panel { id = "mapControls", position = "absolute", left = 12, bottom = 12, padding = 6,
        flexDirection = "row", alignItems = "center", gap = 8, children = {
        button("归村", function() world.home() end, { artIcon = "home" }), label("双指缩放", 12, Skin.muted),
    } }
    local quest = button("", function()
        if sim.started and not sim.skipped and D.lessons[sim.lesson] then showMentor()
        else open("village") end
    end, { id = "questChip", position = "absolute", top = 60, left = 12, height = 44, fontSize = 13 })
    local placementText = label("", 13)
    local placement = panel { position = "absolute", bottom = 82, left = 12, width = 206, padding = 10, gap = 8, visible = false,
        children = { placementText, button("结束营造", function() actions.setMode("inspect") end, { id = "cancelPlacement", width = 120 }) } }
    local toast = label("", 13)
    local notice = panel { position = "absolute", bottom = 84, left = "26%", maxWidth = "42%", padding = 12, visible = false, pointerEvents = "none", children = { toast } }
    local menuStatus = label("", 12, Skin.muted)
    local enter = button("", function() if actions.enter() then intro:Hide() end end, { id = "enterVillage", height = 46, backgroundColor = { 91, 105, 65 } })
    intro = UI.Panel { id = "modeScreen", position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
        alignItems = "center", justifyContent = "center", backgroundColor = { 13, 21, 17, 180 }, children = {
        panel { width = "76%", maxWidth = 460, padding = 22, gap = 12, children = {
            label("择 一 方 水 土", 25, Skin.gold), label("从一缕炊烟，到万家灯火。", 13, Skin.muted),
            row {
                button("有限 · 炊烟再起", function() actions.changeMode("finite") end, { id = "modeFinite", flexGrow = 1, backgroundColor = sim.mode == "finite" and { 110, 91, 49 } or nil }),
                button("无限 · 山河拓荒", function() actions.changeMode("infinite") end, { id = "modeInfinite", flexGrow = 1, backgroundColor = sim.mode == "infinite" and { 110, 91, 49 } or nil }),
            },
            label(D.modes[sim.mode].description, 14), menuStatus, enter,
        } },
    } }
    confirmNew = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = { 13, 21, 17, 210 }, children = { panel { width = "80%", maxWidth = 430, padding = 24, gap = 14, children = {
            label("另起炉灶？", 24, Skin.gold), label("入村后覆盖本模式旧档，另一模式不受影响。", 14),
            button("确认新局", function() actions.restart() end, { id = "confirmNewGame" }), button("取消", function() confirmNew:Hide() end),
        } } } }
    local loginHint = label("", 12, Skin.muted)
    loginHint:SetStyle({ width = "100%", whiteSpace = "normal" })
    local login
    login = UI.Panel { id = "loginScreen", position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
        backgroundColor = { 30, 40, 29 }, backgroundImage = Art.path("login-painting"), backgroundFit = "cover", children = {
        UI.SafeAreaView { width = "100%", height = "100%", justifyContent = "center", alignItems = "flex-end", padding = 24, children = {
            panel { width = 294, marginRight = 24, padding = 20, gap = 9, children = {
                label("山  河  里", 34, Skin.gold), label("炊 烟 再 起", 16),
                label("耕田 · 营造 · 通商 · 守土", 12, Skin.muted),
                loginHint,
                button("TapTap 账号进入", function()
                    local ok, message = actions.login(false)
                    loginHint:SetText(message)
                    if ok then login:Hide() end
                end, { id = "loginTapTap", height = 46, backgroundColor = { 73, 105, 86 } }),
                button("游客试玩", function() local ok = actions.login(true); if ok then login:Hide() end end, { id = "loginGuest", height = 44 }),
                label("游客进度仅保存在当前设备。", 11, Skin.muted),
            } },
        } },
    } }
    login:SetVisible(not session.accepted)
    loginHint:SetText(session.userId > 0 and "已识别 TapTap 账号，可同步云存档。" or "从 TapTap 打开可使用账号；也可先游客试玩。")
    mentorTitle,mentorLine1,mentorLine2,mentorLine3=label("",18,Skin.gold),label("",13),label("",13),label("",13)
    mentorProgress=label("",12,Skin.muted)
    for _,item in ipairs({mentorLine1,mentorLine2,mentorLine3}) do item:SetStyle({width="100%",whiteSpace="normal"}) end
    mentorGo=button("",function()
        local value,target=sim:lessonProgress()
        if value>=target then
            if sim:nextLesson() then
                if D.lessons[sim.lesson] then mentorShownLesson=0
                else dismissMentor() end
            end
        else dismissMentor() end
    end,{id="mentorGo",height=44,flexGrow=1})
    local mentorSkip=button("跳过教程",function()
        sim.skipped,sim.lesson=true,#D.lessons+1
        sim:notify("谢伯拱手作别。村庄交给你了，随时可在村务重读教程。")
        dismissMentor()
    end,{id="mentorSkip",height=44})
    mentor=panel { id="mentorDialogue",position="absolute",left=12,bottom=76,width="70%",maxWidth=610,padding=12,
        transition="opacity 0.45s easeInOut",opacity=0,visible=false,
        children={ row({ Mentor.portrait(),UI.Panel { flexGrow=1,flexBasis=0,minWidth=0,gap=5,children={
            mentorTitle,mentorLine1,mentorLine2,mentorLine3,mentorProgress,
            row({mentorGo,mentorSkip},7),
        } } },12) } }
    dismissMentor=function()
        if mentor:IsVisible() and mentorFade==0 then mentorFade=0.45;mentor:SetStyle({opacity=0}) end
    end
    showMentor=function()
        local lesson=D.lessons[sim.lesson]
        if not lesson or sim.skipped or not sim.started or sim.menuOpen then return end
        mentorFade=0
        mentor:SetVisible(true);mentor:SetStyle({opacity=1})
        mentorShownLesson=sim.lesson
        local value,target=sim:lessonProgress()
        if value>=target then mentorCompleteShown=sim.lesson end
    end
    local settlementText = label("读取存档中…", 18, Skin.gold)
    local settlement = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = { 13, 21, 17, 210 }, children = { panel { width = "80%", maxWidth = 430, padding = 24, gap = 12, children = {
            settlementText, label("离线结算生产，乡亲们安心守候。", 13),
        } } } }
    local resultTitle, resultText = label("", 25, Skin.gold), label("", 14)
    local ending = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = { 13, 21, 17, 210 }, children = { panel { width = "80%", maxWidth = 460, padding = 24, gap = 14, children = {
            resultTitle, resultText, button("重新开始", function() actions.restart() end),
            button("切换模式", function() actions.changeMode(sim.mode == "finite" and "infinite" or "finite") end),
        } } } }
    local chrome = UI.SafeAreaView { width = "100%", height = "100%", pointerEvents = "box-none", children = {
        topbar, quest, world.minimap, controls, dock, placement, notice, buildDrawer, villageDrawer, armyDrawer, systemDrawer, selectedDrawer, roadDrawer,
    } }
    local root = UI.Panel { width = "100%", height = "100%", pointerEvents = "box-none", children = { world.panel, chrome, mentor, intro, ending, confirmNew, login, settlement } }
    local function update(dt)
        if mentorFade>0 then
            mentorFade=math.max(0,mentorFade-(dt or 0))
            if mentorFade==0 then mentor:SetVisible(false) end
        end
        for _, r in ipairs(D.topGoods) do resources[r]:SetText(D.names[r] .. "  " .. sim.stock[r]) end
        people:SetText("村民 " .. sim.population .. " / 闲 " .. sim:availableWorkers())
        status:SetText(info.status or "尚未保存"); menuStatus:SetText(info.status or "尚未保存")
        summary:SetText(info.summary or "离线生产最多累计 8 小时。")
        idle:SetText(info.idleEnabled and "离线生产：开启" or "离线生产：关闭")
        pause:SetText(sim.paused and "继续经营" or "暂停经营"); speed:SetText("速度 " .. sim.speed .. " 倍")
        enter:SetText((info.hasSave or sim.started) and "继续经营 →" or "随里正入村 →")
        enter:SetDisabled(not session.accepted or info.loading or info.settling)
        chrome:SetVisible(session.accepted and not sim.menuOpen)
        settlement:SetVisible(session.accepted and (info.loading or info.settling))
        settlementText:SetText(info.loading and "读取存档中…" or ("离线生产结算 " .. math.floor((info.progress or 0) * 100) .. "%"))
        local lesson = D.lessons[sim.lesson]
        local value, target = sim:lessonProgress()
        local teaching=sim.started and not sim.menuOpen and not sim.skipped and lesson~=nil and not info.loading and not info.settling
        if teaching then
            if mentorShownLesson~=sim.lesson or (value>=target and mentorCompleteShown~=sim.lesson) then showMentor() end
            mentorTitle:SetText("里正谢伯  ·  " .. lesson.title)
            if value>=target then
                mentorLine1:SetText(lesson.complete or "这一步做得好。")
                mentorLine2:SetText("咱们接着把村子经营起来。")
                mentorLine3:SetText("也可先看看地图，再来听下一步。")
            else
                ---@type string[]
                local lines=lesson.lines
                mentorLine1:SetText(lines[1]);mentorLine2:SetText(lines[2]);mentorLine3:SetText(lines[3])
            end
            mentorProgress:SetText("第 " .. sim.lesson .. " / " .. #D.lessons .. " 步  ·  " .. value .. " / " .. target)
            mentorGo:SetText(value>=target and (sim.lesson==#D.lessons and "谢谢谢伯 · 开始经营" or "听下一步 →") or "明白，去做")
        elseif mentor:IsVisible() then
            if sim.menuOpen then mentor:SetVisible(false);mentorFade=0;mentorShownLesson=0
            else dismissMentor() end
        end
        quest:SetText(lesson and ("里正手札  ·  " .. lesson.title .. "  ›") or "乡里近况  ›")
        title:SetText(lesson and lesson.title or "乡里安居，百业待兴")
        line1:SetText(lesson and lesson.lines[1] or "安排运输与岗位，保持粮食供给。")
        line2:SetText(lesson and lesson.lines[2] or "麦田 → 磨坊 → 食堂 → 义仓")
        line3:SetText(lesson and lesson.lines[3] or "点击建筑可调整岗位。")
        progress:SetText(lesson and ("进度  " .. value .. " / " .. target) or "已完成基础教学")
        next:SetVisible(lesson ~= nil); next:SetDisabled(value < target)
        worldInfo:SetText(sim.mode == "finite" and ("清溪河谷 · 义仓 " .. sim.health) or ("拓荒 " .. sim.map.expansion .. " 圈 · 已守 " .. sim.wavesDefeated .. " 波"))
        supplyInfo:SetText("麦粒 " .. sim.stock.grain .. " · 面粉 " .. sim.stock.flour .. " · 牲畜 " .. sim.stock.livestock .. " · 鲜肉 " .. sim.stock.meat)
        military:SetText("乡勇 " .. sim.militia .. " 人 · 义仓 " .. sim.health .. "/100" .. (sim.mode == "infinite" and ("\n下次来袭 " .. math.ceil(sim.nextRaid) .. " 秒") or ""))
        raid:SetVisible(sim.lesson >= 8 and not sim.raid and (sim.mode == "infinite" or not sim.defended))
        toast:SetText(sim.message); notice:SetVisible(sim.messageTime > 0 and not opened and not mentor:IsVisible())
        if actions.selected ~= selectedLast then
            selectedLast = actions.selected
            if selectedLast then opened = "selected" elseif opened == "selected" then close() end
        end
        if actions.road ~= roadLast then
            roadLast=actions.road
            if roadLast then opened="road" elseif opened=="road" then close() end
        end
        if actions.road then
            local p=actions.road
            local status="等待空闲村民到场"
            for _,a in ipairs(sim.builders) do
                if a.job and a.job.kind=="road" and a.job.x==p.x and a.job.y==p.y then
                    status=a.phase=="hammer" and "压实路面 · 举锤施工" or "工人正在取材 / 前往工地"
                end
            end
            if p.progress>=1 then status="已竣工，可以运输" end
            roadState:SetText("地块 " .. p.x .. "," .. p.y .. "\n进度 " .. math.floor(p.progress*100) .. "%\n" .. status)
        end
        activityInfo:SetText("待铺路 " .. #sim.pendingRoads .. " · 施工 " .. require("game.Construction").busy(sim) .. " 人 · 供餐 " .. sim.mealsServed)
        local labor,chefs,butchers=0,0,0
        for _,job in ipairs(sim.buildings) do
            if job.complete then
                if job.kind=="kitchen" then chefs=chefs+job.workers
                elseif job.kind=="butcher" then butchers=butchers+job.workers
                else labor=labor+job.workers end
            end
        end
        jobInfo:SetText("工人 " .. (#sim.carriers+labor+require("game.Construction").busy(sim)) ..
            "（搬运 " .. #sim.carriers .. " / 生产 " .. labor .. "） · 厨师 " .. chefs .. " · 屠夫 " .. butchers .. " · 空闲 " .. sim:availableWorkers())
        local b = actions.selected
        if b then
            local def = D.buildings[b.kind]
            selectedTitle:SetText(def.name); selectedInfo:SetText(def.description .. "\n实际占地 " .. (b.footprintW or 1) .. "×" .. (b.footprintH or 1) .. "，共 " .. #D.cells(b) .. " 格。")
            local siteStatus=not sim:connected(b) and "待修建 · 等待门前接路" or b.progress==0 and "待修建 · 等待工人取材到场" or "修建中 " .. math.floor(b.progress*100) .. "%"
            selectedState:SetText(b.complete and (D.job(b.kind) .. "岗位 " .. b.workers .. " / 在岗 " .. (b.activeWorkers or 0) .. " · " .. (sim:connected(b) and "道路畅通" or "尚未通路")) or siteStatus)
            if b.kind=="farm" and b.complete then
                local stage=Farm.stage(b,D.buildings.farm.period)
                local stageName=({seed="播种期",sprout="幼苗期",green="拔节期",ripe="成熟期"})[stage]
                local task=Farm.needsWork(b,D.buildings.farm.period) and
                    ({"犁地播种中","浇水中","照料麦苗中","收割中"})[Farm.step(b)+1] or "麦子生长中 · 工人在田边等待 / 休息"
                selectedState:SetText("工人 " .. (b.activeWorkers or 0) .. " 人 · " .. stageName .. " " .. math.floor((b.timer or 0)/D.buildings.farm.period*100) .. "%\n" .. task .. "\n每轮收获 3 袋麦粒，由工人送入义仓。")
            elseif b.kind=="woodcutter" and b.complete then
                selectedState:SetText("工人 " .. (b.activeWorkers or 0) .. " 人 · 待运木料 " .. (b.buffer or 0) .. "\n木材余量 " .. sim.timber .. " · 门前接路后工人送回义仓。")
            end
            if b.kind=="kitchen" and b.complete then
                local inside,queue=0,0
                local function visit(a)
                    local m=a.meal
                    if m and m.target==b.id then
                        if m.phase=="enter" or m.phase=="eat" or m.phase=="exit" then inside=inside+1
                        elseif m.phase=="queue" then queue=queue+1 end
                    end
                end
                for _,a in ipairs(sim.carriers) do visit(a) end
                for _,a in pairs(sim.workers) do visit(a) end
                for _,a in ipairs(sim.builders) do visit(a) end
                for _,a in ipairs(sim.guards or {}) do visit(a) end
                local Meals=require "game.Meals"
                selectedState:SetText("厨师 " .. (b.activeWorkers or 0) .. " 人 · 供餐席位 " .. inside .. "/" .. Meals.seats .. " · 候餐 " .. queue .. "\n店内口粮 " .. (b.mealStock or 0) .. "/" .. Meals.pantryCapacity .. " · 面粉 " .. sim.stock.flour .. " / 鲜肉 " .. sim.stock.meat .. "\n工人送粮，村民入座吃饭。")
            end
            minus:SetVisible(def.output ~= nil); plus:SetVisible(def.output ~= nil)
            train:SetVisible(b.kind == "barracks"); repair:SetVisible(b.kind == "store")
        end
        for name, p in pairs(drawers) do p:SetVisible(opened == name) end
        world.minimap:SetVisible(not opened)
        for name, btn in pairs(mainButtons) do btn:SetBackgroundColor(opened == name and { 124, 96, 48 } or { 83, 69, 43 }) end
        placement:SetVisible(actions.mode ~= "inspect" and not opened)
        if actions.mode ~= "inspect" then
            local width,height=D.footprint(actions.mode)
            placementText:SetText(D.buildings[actions.mode].name .. " " .. width .. "×" .. height .. " / " .. #D.cells(actions.mode) .. "格\n拖动选址，松手规划\n绿：可建  红：不可建")
        end
        ending:SetVisible(session.accepted and (sim.victory or sim.defeat))
        if sim.victory then resultTitle:SetText("炊烟又起，乡里安宁"); resultText:SetText("粮道已通，乡勇已成，清溪里再闻饭香。")
        elseif sim.defeat then resultTitle:SetText("义仓失守"); resultText:SetText("重新安排粮食生产与兵力，再守一次村。") end
    end
    ---@class VillageHud
    local result = { root = root, update = update, dismissIntro = function()
        if not session.accepted then actions.login(true) end
        if actions.enter() then intro:Hide() end
    end }
    return result
end
return Hud
