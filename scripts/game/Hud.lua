local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
local Farm = require "game.FarmCycle"
local Skin = require "game.Skin"
local PixelTheme = require "game.PixelTheme"
local Economy=require "game.Economy"
local Deposits=require "game.Deposits"
local Forestry=require "game.Forestry"
local Military=require "game.Military"
local IndustryPanel=require "game.IndustryPanel"
local label, button, panel = Skin.label, Skin.button, Skin.panel
local Hud = {}
local function prose(text,size,color,id)
    local item=label(text,size,color,id)
    item:SetStyle({width="100%",whiteSpace="normal"})
    return item
end
local function row(children, gap) return UI.Panel { flexDirection = "row", alignItems = "center", gap = gap or 8, children = children } end
local function costText(def)
    local parts = {}
    for _, r in ipairs(D.goods) do if def.cost[r] then parts[#parts + 1] = def.cost[r] .. D.names[r] end end
    return #parts > 0 and table.concat(parts, " / ") or "免费铺设"
end
function Hud.create(sim, world, actions)
    local touch = Skin.touchSize()
    local C = PixelTheme.colors
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
        local heading=label(name,20,Skin.gold,"drawerTitle_"..name)
        return row { heading, UI.Panel { flexGrow = 1 }, button("×", close, { width = touch, id = "closeDrawer" .. name }) }
    end
    local function drawer(name, title, items)
        local p = panel { id = "drawer_" .. name, position = "absolute", left = 12, top = 58, bottom = touch + 34, width = 320, maxWidth = "82%", padding = 12, gap = 8,
            visible = false, children = { header(title), UI.ScrollView { flexGrow = 1, flexBasis = 0, scrollY = true,
                children = { UI.Panel { gap = 9, paddingRight = 5, children = items } } } } }
        drawers[name] = p
        return p
    end
    ---@type Widget[]
    local top = {}
    for _, r in ipairs(D.topGoods) do
        resources[r] = label("", 13,nil,"stock_" .. r)
        top[#top + 1] = row({ Skin.icon(r, 22), resources[r] }, 3)
    end
    local people = label("", 12, Skin.muted,"population"); top[#top + 1] = people
    local brand=label("山河里 · 产业试玩 v3",17,Skin.gold,"hudVersion");brand:SetStyle({flexShrink=0})
    local topbar = panel { position = "absolute", top = 8, left = 12, right = 12, height = 42, paddingHorizontal = 12,
        flexDirection = "row", alignItems = "center", gap = 12, children = { brand,
        UI.ScrollView { height = 32, flexGrow = 1, flexBasis = 0, scrollX = true, scrollY = false, showScrollbar = false,
            children = { UI.Panel { flexDirection = "row", alignItems = "center", gap = 16, children = top } } },
    } }
    ---@type Widget[]
    local buildItems = { prose("楼房下蓝图扣一次全栋费用，施工分批搬运不再扣。道路免费但需劳力铺设；门前接路后才开工。", 12, Skin.muted) }
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
    local supplyInfo=prose("",12,Skin.muted)
    local ledger=prose("",12,Skin.gold,"warehouseLedger")
    local next = button("完成后继续 →", function() if sim:nextLesson() then close() end end, { id = "nextLesson" })
    local activityInfo=label("",12,Skin.muted)
    local jobInfo=label("",12,Skin.gold)
    jobInfo:SetStyle({width="100%",whiteSpace="normal"})
    local villageDrawer = drawer("village", "乡 里 事 务", {
        worldInfo, supplyInfo, ledger, jobInfo, activityInfo, title, line1, line2, line3, progress, next,
        prose("木料链：伐木场采原木 → 锯木坊锯木料 → 义仓。先补齐木链，再扩建村庄。",12,Skin.gold),
        prose("矿冶装备：矿石+煤 → 冶炼坊 → 铁器/铁甲；猪皮 → 皮革 → 皮甲，木作坊制弓，配金锭征募正规兵。",12,Skin.gold),
        prose("森林恢复：树桩180秒 → 幼苗540秒 → 成熟；护林人实际到场照护时×2。",12,Skin.gold),
        prose("主食链：麦田 → 磨坊 → 饼坊 → 食堂。肉食链：麦田供饲料 → 牧场喂养 → 屠宰场加工鲜肉 → 食堂烹制口粮。人口增加后，留意食堂是否缺料，及时扩田、增设食堂并留足搬运人手。磨坊和牧场共用麦粒；货物富余可停工，保留岗位的村民仍要吃饭。",12,Skin.gold),
        button("重新阅读教程", function() sim.lesson, sim.skipped = 1, false; mentorShownLesson=0; close() end,{id="restartMentor"}),
        button("结束教学 · 自由经营", function() sim.skipped, sim.lesson = true, #D.lessons + 1; close(); if dismissMentor then dismissMentor() end end),
    })
    local military = prose("", 14)
    local raid = button("开始守村", function() local _, msg = sim:startRaid(); sim:notify(msg) end, { id = "startRaid" })
    local expand = button("拓荒 · 发现新土地", function() local _, msg = sim:expand(); sim:notify(msg) end, { id = "expandWorld" })
    expand:SetVisible(sim.mode == "infinite")
    local frontier = button("前往边疆", function() world.frontier(); close() end)
    frontier:SetVisible(sim.mode == "infinite")
    local armyDrawer = drawer("army", "军 务 与 拓 荒", { military,
        prose("在乡勇营训练，义仓附近自动迎敌。", 12, Skin.muted),
        button("训练乡勇 · 2木 / 2粮 / 1人", function() local _, msg = sim:train(); sim:notify(msg) end, { id = "trainMilitia" }),
        prose("弓手：弓1、皮甲1、金锭1、口粮2、待命村民1。",12,Skin.muted),
        button("征募弓手",function()local _,msg=sim:train('archer');sim:notify(msg)end,{id='trainArcher'}),
        prose("长枪兵：铁枪1、铁甲1、金锭1、口粮2、待命村民1。",12,Skin.muted),
        button("征募长枪兵",function()local _,msg=sim:train('spearman');sim:notify(msg)end,{id='trainSpearman'}),
        raid, button("修缮义仓 · 4木 / 4石", function() local _, msg = sim:repair(); sim:notify(msg) end), expand, frontier,
    })
    local intro, confirmNew
    local status, summary = label("", 12, Skin.muted), label("", 12, Skin.muted)
    summary:SetStyle({ width = "100%", whiteSpace = "normal" })
    status:SetStyle({ width = "100%", whiteSpace = "normal" })
    local idle = button("", function() actions.toggleIdle() end, { id = "toggleIdle" })
    local pause = button("", function() sim.paused = not sim.paused end, { id = "pause", flexGrow = 1 })
    local speed = button("", function() sim.speed = sim.speed == 1 and 2 or 1 end, { flexGrow = 1 })
    local systemDrawer = drawer("system", "系 统 与 存 档", { label("清溪里 · 像素村庄",12,Skin.muted), status, summary,
        button(actions.saveInfo.demo and "返回我的村庄" or "参观演示村庄", function() actions.demo() end, {id="visitDemo"}),
        row { pause, speed }, button("保存进度", function() actions.save() end, { id = "saveGame", artIcon = "save" }), idle,
        button("返回模式选择", function() if info.demo then actions.demo();return end;sim.menuOpen = true; intro:Show(); close() end, { id = "showModes" }),
        button("重新开始本模式", function() confirmNew:Show() end, { id = "newGame" }),
    })
    local selectedTitle, selectedInfo, selectedState = label("", 18, Skin.gold), label("", 13), label("", 12, Skin.muted)
    selectedState:SetStyle({ width = "100%", whiteSpace = "normal" })
    selectedInfo:SetStyle({ width = "100%", whiteSpace = "normal" })
    local minus = button("减少岗位", function() if actions.selected then local _,message=sim:staff(actions.selected, -1);sim:notify(message) end end, { flexGrow = 1 })
    local plus = button("增加岗位", function() if actions.selected then local _,message=sim:staff(actions.selected, 1);sim:notify(message) end end, { flexGrow = 1 })
    local selectedFlow=prose("",12,Skin.gold,"selectedFlow")
    local selectedStock=prose("",12,Skin.muted,"selectedInventory")
    local train = button("训练乡勇", function() local _, msg = sim:train(); sim:notify(msg) end)
    local repair = button("修缮义仓", function() local _, msg = sim:repair(); sim:notify(msg) end)
    local upgrade=button("重整院落",function()if actions.selected then local _,msg=sim:upgradeCompound(actions.selected);sim:notify(msg)end end,{id="upgradeCompound"})
    local industryPanel=IndustryPanel.create(sim,function()return actions.selected end)
    local selectedDrawer = drawer("selected", "建 筑 详 情", { selectedTitle, selectedInfo, selectedFlow, selectedStock, selectedState, industryPanel.root, row { minus, plus }, train, repair, upgrade })
    local roadState=label("",14,Skin.gold)
    local roadDrawer=drawer("road","道 路 工 地",{roadState,prose("工人会先到义仓取材，再走到路段旁施工。规划路段完工前不能运输。",13)})
    local dockItems = {}
    for _, item in ipairs({ {"build","营造"}, {"village","村务"}, {"army","军务"}, {"system","系统"} }) do
        local name = item[1]
        local b = button(item[2], function() open(name) end, { id = "open_" .. name, width = 72, height = 46, fontSize = 14 })
        mainButtons[name] = b; dockItems[#dockItems + 1] = b
    end
    local dock = panel { position = "absolute", left = 12, bottom = 12, padding = 6, flexDirection = "row", gap = 6, children = dockItems }
    local controls = panel { id = "mapControls", position = "absolute", right = 12, bottom = 12, padding = 6,
        flexDirection = "row", alignItems = "center", gap = 8, children = {
        button("归村", function() world.home() end),
    } }
    local quest = button("", function()
        if sim.started and not sim.skipped and D.lessons[sim.lesson] then showMentor()
        else open("village") end
    end, { id = "questChip", position = "absolute", top = 58, left = 12, maxWidth = "64%", height = 44, fontSize = 13 })
    local placementText = prose("", 13)
    local placement = panel { position = "absolute", bottom = touch + 34, left = 12, width = 260, maxWidth="64%", padding = 10, gap = 8, visible = false,
        children = { placementText, button("结束营造", function() actions.setMode("inspect") end, { id = "cancelPlacement", width = 120 }) } }
    local toast = label("", 13)
    local notice = panel { id="notice", position = "absolute", bottom = touch + 34, left = "28%", maxWidth = "48%", padding = 12, visible = false, pointerEvents = "none", children = { toast } }
    local menuStatus = prose("", 12, Skin.muted)
    local enter = button("", function() if actions.enter() then intro:Hide() end end, { id = "enterVillage", width="100%", height = 46, variant = "primary" })
    intro = UI.Panel { id = "modeScreen", position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
        alignItems = "center", justifyContent = "center", backgroundColor = C.overlay, children = {
        panel { width = "76%", maxWidth = 460, padding = 22, gap = 12, children = {
            label("择 一 方 水 土", 25, Skin.gold), prose("从一缕炊烟，到万家灯火。", 13, Skin.muted),
            row {
                button("有限 · 炊烟再起", function() actions.changeMode("finite") end, { id = "modeFinite", flexGrow = 1, variant = sim.mode == "finite" and "primary" or "secondary" }),
                button("无限 · 山河拓荒", function() actions.changeMode("infinite") end, { id = "modeInfinite", flexGrow = 1, variant = sim.mode == "infinite" and "primary" or "secondary" }),
            },
            prose(D.modes[sim.mode].description, 14), menuStatus, enter,
        } },
    } }
    confirmNew = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = C.overlay, children = { panel { width = "80%", maxWidth = 430, padding = 24, gap = 14, children = {
            label("另起炉灶？", 24, Skin.gold), prose("入村后覆盖本模式旧档，另一模式不受影响。", 14),
            button("确认新局", function() actions.restart() end, { id = "confirmNewGame", variant = "primary" }), button("取消", function() confirmNew:Hide() end),
        } } } }
    local loginHint = label("", 12, Skin.muted)
    loginHint:SetStyle({ width = "100%", whiteSpace = "normal" })
    local login
    login = UI.Panel { id = "loginScreen", position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
        backgroundColor = { 31, 30, 25, 155 }, children = {
        UI.SafeAreaView { width = "100%", height = "100%", nativeMenuInset = true, justifyContent = "center", alignItems = "center", padding = 16, children = {
            panel { width = 320, maxWidth = "92%", padding = 20, gap = 10, children = {
                label("山河里", 34, Skin.gold), label("产业试玩 v3 · 清溪里", 16),
                label("耕田 · 营造 · 通商 · 守土", 12, Skin.muted),
                loginHint,
                button("TapTap 账号进入", function()
                    local ok, message = actions.login(false)
                    loginHint:SetText(message)
                    if ok then login:Hide() end
                end, { id = "loginTapTap", width="100%", height = 46, variant = "primary" }),
                button("游客试玩", function() local ok = actions.login(true); if ok then login:Hide() end end, { id = "loginGuest", width="100%", height = 44 }),
                prose("游客进度仅保存在当前设备。", 11, Skin.muted),
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
    end,{id="mentorGo",height=44,flexGrow=1,variant="primary"})
    local mentorSkip=button("跳过教程",function()
        sim.skipped,sim.lesson=true,#D.lessons+1
        sim:notify("谢伯拱手作别。村庄交给你了，随时可在村务重读教程。")
        dismissMentor()
    end,{id="mentorSkip",height=44})
    mentor=panel { id="mentorDialogue",position="absolute",right=12,bottom=touch+34,width="72%",maxWidth=500,height=touch+142,padding=10,gap=6,
        opacity=1,visible=false,
        children={mentorTitle,UI.ScrollView{flexGrow=1,flexBasis=0,scrollY=true,children={UI.Panel{gap=5,children={mentorLine1,mentorLine2,mentorLine3}}}},
            mentorProgress,row({mentorGo,mentorSkip},7)} }
    dismissMentor=function()
        mentorFade=0;mentor:SetVisible(false)
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
        backgroundColor = C.overlay, children = { panel { width = "80%", maxWidth = 430, padding = 24, gap = 12, children = {
            settlementText, prose("离线结算生产，乡亲们安心守候。", 13),
        } } } }
    local resultTitle, resultText = prose("", 25, Skin.gold), prose("", 14)
    local continueVillage=button('继续经营 · 保留村庄',function()
        local _,message=sim:continueFreePlay();sim:notify(message)
    end,{id='continueFreePlay'})
    local ending = UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, alignItems = "center", justifyContent = "center", visible = false,
        backgroundColor = C.overlay, children = { panel { width = "80%", maxWidth = 460, padding = 24, gap = 14, children = {
            resultTitle, resultText, continueVillage, button("重新开始", function() actions.restart() end),
            button("切换模式", function() actions.changeMode(sim.mode == "finite" and "infinite" or "finite") end),
        } } } }
    local chrome = UI.SafeAreaView { width = "100%", height = "100%", nativeMenuInset = true, pointerEvents = "box-none", children = {
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
        intro:SetVisible(session.accepted and sim.menuOpen and not info.loading and not info.settling)
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
                local lines=sim.mode=="infinite" and lesson.infiniteLines or lesson.lines
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
        local lessonLines=lesson and (sim.mode=="infinite" and lesson.infiniteLines or lesson.lines)
        line1:SetText(lessonLines and lessonLines[1] or "安排运输与岗位，保持粮食供给。")
        line2:SetText(lessonLines and lessonLines[2] or "麦田 → 磨坊 → 饼坊 → 食堂")
        line3:SetText(lessonLines and lessonLines[3] or "点击建筑可调整岗位。")
        progress:SetText(lesson and ("进度  " .. value .. " / " .. target) or "已完成或跳过产业教学")
        next:SetVisible(lesson ~= nil); next:SetDisabled(value < target)
        worldInfo:SetText(sim.mode == "finite" and ("清溪河谷 · 义仓 " .. sim.health) or ("拓荒 " .. sim.map.expansion .. " 圈 · 已守 " .. sim.wavesDefeated .. " 波"))
        supplyInfo:SetText("麦粒 " .. sim.stock.grain .. " · 面粉 " .. sim.stock.flour .. " · 牲畜 " .. sim.stock.livestock .. " · 鲜肉 " .. sim.stock.meat)
        military:SetText("乡勇 " .. Military.count(sim,"militia") .. " / 弓手 "..Military.count(sim,"archer").." / 长枪兵 "..Military.count(sim,"spearman").." · 义仓 " .. sim.health .. "/100" .. (sim.mode == "infinite" and ("\n下次来袭 " .. math.ceil(sim.nextRaid) .. " 秒") or ""))
        raid:SetText(sim.mode=="finite" and sim.defended and not sim.freePlay and "终章守村 · 百业共守" or sim.freePlay and "继续守村 · 下一波" or "开始守村")
        raid:SetVisible((sim.lesson>=10 or sim.skipped or sim.freePlay) and not sim.raid and not sim.victory and not sim.defeat)
        toast:SetText(sim.message or ""); notice:SetVisible((sim.message or ""):match("%S") ~= nil and sim.messageTime > 0 and not opened and not mentor:IsVisible())
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
        local labor,chefs,butchers,lumberjacks,herders=0,0,0,0,0
        for _,job in ipairs(sim.buildings) do
            if job.complete then
                if job.kind=="kitchen" then chefs=chefs+job.workers
                elseif job.kind=="butcher" then butchers=butchers+job.workers
                elseif job.kind=="woodcutter" then lumberjacks=lumberjacks+job.workers
                elseif job.kind=="ranch" then herders=herders+job.workers
                else labor=labor+job.workers end
            end
        end
        jobInfo:SetText("工人 " .. (#sim.carriers+labor+require("game.Construction").busy(sim)) ..
            "（搬运 " .. #sim.carriers .. " / 生产 " .. labor .. "） · 厨师 " .. chefs .. " · 屠夫 " .. butchers .. " · 樵夫 " .. lumberjacks .. " · 养殖户 " .. herders .. " · 空闲 " .. sim:availableWorkers())
        local stockLines={}
        for _,resource in ipairs(D.goods) do
            local shelf,transit=0,0
            for _,building in ipairs(sim.buildings) do
                shelf=shelf+Economy.outputAmount(building,resource)
            end
            local function cargo(job,picked,done)
                if job and not job.construction and not done and job.resource==resource and
                    (job.inbound or picked or job.pickedUp) then transit=transit+(job.amount or 0) end
            end
            for _,job in ipairs(sim.jobs) do cargo(job,false,false) end
            for _,actor in ipairs(sim.carriers) do cargo(actor.job,actor.carrying,actor.handedOff) end
            -- Logs still in a logger's hands have not reached the camp shelf.
            -- Legacy saved loads remain wood until their old batch is delivered.
            for _,actor in pairs(sim.workers) do
                local camp=sim.buildings[actor.building]
                if camp and camp.kind=="woodcutter" and actor.carrying and not actor.stockedLoad
                    and sim:outputResource(camp)==resource then transit=transit+(actor.loadAmount or 1) end
                if actor.workLoad then transit=transit+(actor.workLoad.goods[resource]or 0)end
                local load=actor.life and actor.life.load
                if load and load.resource==resource then transit=transit+load.amount end
            end
            stockLines[#stockLines+1]=D.names[resource] .. "  仓 " .. sim.stock[resource] .. " / 待运 " .. shelf .. " / 在途 " .. transit
        end
        ledger:SetText(table.concat(stockLines,"\n"))
        local b = actions.selected
        if b then
            local def = D.buildings[b.kind]
            local description=def.description
            if b.kind=="mill" then local r=Economy.recipe(b);description=(b.recipeVersion==1 and "旧档磨坊续用 · " or "磨坊 · ")..r.inputs.grain.."袋麦粒 → 2袋面粉 / "..r.period.."秒" end
            selectedTitle:SetText(def.name); selectedInfo:SetText(description .. "\n实际占地 " .. (b.footprintW or 1) .. "×" .. (b.footprintH or 1) .. "，共 " .. #D.cells(b) .. " 格。")
            local activeDisplay=sim.paused and "暂停中" or tostring(b.activeWorkers or 0)
            local connected=sim:connected(b)
            local outputCapacity=b.kind=="woodcutter" and 6 or Economy.capacity(b)
            local reason
            if sim.paused then reason="已暂停经营 · 恢复后继续作业"
            elseif not connected then reason="未连路 · 门前道路需接回义仓"
            elseif not b.complete then reason="施工中 · 材料已预留，等待工人取材"
            elseif b.stopped then reason="已停工 · 岗位和原料保留，货物继续运送"
            elseif (def.output or def.service) and b.workers==0 then reason="无工人 · 增加岗位后开工"
            elseif b.kind=="woodcutter" and sim:treeCount(b,6)==0 and b.buffer==0 and not b.outgoing then reason="附近成熟树已伐尽 · 等待再生或靠近其他树林扩建"
            elseif b.kind=="quarry" and sim.rock<=0 then reason="石料已采尽"..(sim.mode=="infinite" and " · 拓荒可发现新储量" or " · 请合理分配现有石料")
            elseif def.deposit and Deposits.stock(sim,b,def.deposit)<=0 then reason="资源点已采尽 · 另寻矿脉 / 水域或拓荒"
            elseif def.recipes and b.queuedRecipe~=nil and not b.processingRecipe then reason="待停单 / 改单 · 等待在途收料或退料货位"
            elseif def.recipes and not Economy.recipe(b) then reason="尚未排单 · 在下方选择生产订单"
            elseif def.output and (b.kind=="woodcutter" and b.buffer>=6 or b.kind~="woodcutter" and not Economy.canProduce(b)) then reason=b.kind=="ranch" and "出栏区已满 · 等搬运工取走" or b.kind=="woodcutter" and "原木待运 · 已暂停新采伐" or "产物待运 · 货架不足一整批空间"
            elseif def.input and not Economy.hasInputs(b) and not (b.kind=="ranch" and (b.feedRemaining or 0)>0) then reason=b.incoming and "原料在途 · 搬运工正在送达" or "缺原料 · 请检查上游与义仓"
            elseif def.output and ((b.activeWorkers or 0)==0 or (b.workRate or 0)==0) then reason="工人用餐 / 归岗中"
            elseif def.output then reason="正在作业 · 取放货由搬运工完成"
            elseif def.service=="forestry" then reason=Forestry.count(sim,b)>0 and "护林人寻找或照料再生树格" or "附近暂无待恢复树格 · 自然森林保留"
            else reason="道路畅通" end
            if b.lifeSiteReason then reason=reason..' · 旧址空间紧凑，保留原生产方式'end
            selectedFlow:SetText((connected and "已接通义仓" or "尚未接通义仓") .. " · " .. reason)
            local inventory={}
            if def.output or def.service then inventory[#inventory+1]=D.job(b.kind).."在岗 "..activeDisplay.." / "..b.workers.." 已安排 / "..(def.maxWorkers or 2).." 上限";if def.output then inventory[#inventory+1]="货架合计 "..(b.buffer or 0)..(b.kind=="woodcutter" and " · ≥6暂停新采伐" or (" / "..outputCapacity)) end end
            if def.input then inventory[#inventory+1]="原料 "..b.inputs.." / "..Economy.inputCapacity(b).." · "..(def.recipes and "按订单配料" or D.names[def.input]..(def.alternateInput and (" 或 "..D.names[def.alternateInput]) or "")) end
            local oldFlour=b.kind=="kitchen" and b.inputGoods and (b.inputGoods.flour or 0) or 0
            if oldFlour>0 then inventory[#inventory+1]="旧档面粉 "..oldFlour.."（续用，按原配方烹饪）" end
            if b.kind=="sawmill" or b.kind=="bakery" or b.kind=="mill" then local period=Economy.period(b);inventory[#inventory+1]="本轮 "..math.min(100,math.floor((b.timer or 0)/period*100)).."% · 每 "..period.." 秒 / "..def.amount.." "..D.names[def.output] end
            if b.kind=="store" then inventory=stockLines end
            selectedStock:SetText(table.concat(inventory,"\n"))
            local siteStatus=not sim:connected(b) and "待修建 · 等待门前接路" or b.progress==0 and "待修建 · 等待工人取材到场" or "修建中 " .. math.floor(b.progress*100) .. "%"
            selectedState:SetText(b.complete and (D.job(b.kind) .. "岗位 " .. b.workers .. " / 在岗 " .. activeDisplay .. " · " .. (sim:connected(b) and "道路畅通" or "尚未通路")) or siteStatus)
            if b.lifeEnabled and b.complete then
                local phases={rest='院中休息',rise='起身取工具',toShore='前往岸边',cast='抛竿',fish='静候鱼讯',reel='提鱼入篓',toStack='抱石前往码垛',toTank='携货归院',stow='货物入架',toChair='回院歇脚',toMeal='前往用餐',mealReady='准备吃饭',toBench='走向石台',cut='切割原石',toRail='前往矿车',rideIn='乘车入洞',mine='洞内采掘',rideOut='矿车出洞',blocked='通道受阻，保留货物等待'}
                local lines={}
                for slot=1,b.workers do local a=sim.workers[b.id..':'..slot];local l=a and a.life
                    if l then lines[#lines+1]=D.job(b.kind)..slot..' · '..(a.meal and '用餐往返中'or phases[l.phase]or '归岗中')end
                end
                selectedState:SetText(table.concat(lines,'\n'))
            end
            if require('game.WorkBreaks').kinds[b.kind]and b.complete then
                local phases={workApproach='走向真实工台',work='工位作业',finish='本批已成，整理负重',toStorage='携货送架',stow='放入货架',mealReady='返门就餐',walk='走向歇脚处',idle='院前等料 / 休息',['return']='沿路回门归岗',blocked='通道受阻，等待归岗'}
                local states={}
                for slot=1,b.workers do local a=sim.workers[b.id..':'..slot]
                    if a then states[#states+1]=D.job(b.kind)..slot..' · '..(a.meal and '用餐往返中'or(a.workFinishLeft or 0)>0 and '本批已成，收拾入架'or a.breaks and phases[a.breaks.phase]or '出工 / 工位作业中')end
                end
                selectedState:SetText(table.concat(states,'\n'))
            end
            if b.kind=="farm" and b.complete then
                local stage=Farm.stage(b,D.buildings.farm.period)
                local stageName=({seed="播种期",sprout="幼苗期",green="拔节期",ripe="成熟期"})[stage]
                local task=Farm.needsWork(b,D.buildings.farm.period) and
                    ({"犁地播种中","浇水中","照料麦苗中","收割中"})[Farm.step(b)+1] or "麦子生长中 · 工人在田边等待 / 休息"
                selectedState:SetText("在岗 " .. activeDisplay .. " · " .. stageName .. " " .. math.floor((b.timer or 0)/D.buildings.farm.period*100) .. "%\n" .. task .. "\n每轮收获 3 袋麦粒，工人运往磨坊或牧场，余粮入仓。")
            elseif b.kind=="ranch" and b.complete then
                selectedState:SetText("养殖户在岗 "..activeDisplay.." · 麦粒饲料 "..b.inputs.." 袋 · 已投喂 "..(b.feedVisits or 0).." 次\n饲槽余粮 "..math.ceil(b.feedRemaining or 0).." 秒 · 生长 "..math.floor(b.timer/105*100).."% · 待出栏 "..b.buffer.." 头\n麦田供料，养殖户定时撒料，成畜优先送屠宰场。")
            elseif b.kind=="butcher" and b.complete then
                selectedState:SetText("屠夫在岗 "..activeDisplay.." · 待加工牲畜 "..b.inputs.." 头\n加工 "..math.floor(b.timer/8*100).."% · 待运鲜肉 "..Economy.outputAmount(b,"meat").." / 猪皮 "..Economy.outputAmount(b,"hide").."\n鲜肉送食堂，猪皮送皮革坊。")
            elseif b.kind=='courier' and b.complete then
                local trips=0;local assigned=0
                for _,a in ipairs(sim.carriers)do if a.courier==b.id then assigned=assigned+1;trips=trips+(a.deliveryCount or 0)end end
                selectedState:SetText('驻站搬运员 '..assigned..' 人 · 已完成 '..trips..' 趟真实交付\n完工已调配1名居民，计入搬运人口，不额外占生产岗位。')
            elseif b.kind=="woodcutter" and b.complete then
                selectedState:SetText("樵夫在岗 " .. activeDisplay .. " · 待运"..D.names[sim:outputResource(b)].." " .. (b.buffer or 0) .. "\n附近余树 " .. sim:treeCount(b,6) .. " 棵 · 每树1根原木，送锯木坊加工。")
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
                selectedState:SetText("厨师在岗 " .. activeDisplay .. " · 供餐席位 " .. inside .. "/" .. Meals.seats .. " · 候餐 " .. queue .. "\n店内口粮 " .. (b.mealStock or 0) .. "/" .. Meals.pantryCapacity .. " · 灶房面饼 " .. (b.inputGoods and b.inputGoods.bread or 0) .. " / 鲜肉 " .. (b.inputGoods and b.inputGoods.meat or 0) .. " / 鲜鱼 "..(b.inputGoods and b.inputGoods.fish or 0) .. (oldFlour>0 and (" · 旧档面粉 "..oldFlour.."（续用）") or "") .. "\n工人送面饼、鲜肉或鲜鱼，村民入座吃饭。")
            end
            industryPanel.update(b)
            minus:SetVisible(def.output ~= nil or def.service~=nil); plus:SetVisible(def.output ~= nil or def.service~=nil)
            train:SetVisible(b.kind == "barracks"); repair:SetVisible(b.kind == "store")
            upgrade:SetVisible(b.complete and b.kind~="store"and(not(b.site and b.site.compound)or b.kind=="woodcutter"and not b.site.storageCell))
        end
        for name, p in pairs(drawers) do p:SetVisible(opened == name) end
        world.minimap:SetVisible(not opened)
        for name, btn in pairs(mainButtons) do btn:SetBackgroundColor(opened == name and C.primary or C.secondary) end
        placement:SetVisible(actions.mode ~= "inspect" and not opened)
        if actions.mode ~= "inspect" then
            local width,height=D.footprint(actions.mode)
            local hint=""
            if actions.mode=="woodcutter" then
                local ghost=world.previewState()
                if ghost then
                    local trees=sim:treeCount({x=ghost.x,y=ghost.y,footprintW=width},6)
                    hint="\n附近可伐 "..trees.." 棵"..(trees<4 and " · 木源少，建议西侧密林" or " · 木源充足")
                else hint="\n优先西侧林缘的合法预览位置，留出院落并查看余树。" end
            end
            placementText:SetText(D.buildings[actions.mode].name .. " " .. width .. "×" .. height .. " / " .. #D.cells(actions.mode) .. "格\n拖动选址，松手规划\n绿：可建  红：不可建"..hint)
        end
        ending:SetVisible(session.accepted and (sim.victory or sim.defeat))
        continueVillage:SetVisible(sim.victory and not sim.defeat)
        if sim.victory then resultTitle:SetText(sim.campaignCompleted and "山河共守，百业成村" or "炊烟又起，乡里安宁");resultText:SetText(sim.campaignCompleted and "产业已通，正规兵已成，终章来敌已退。保留全村继续经营，或重新开始。" or "旧存档的守村胜利已保留。继续经营可发展新产业，不会重置村庄。")
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
