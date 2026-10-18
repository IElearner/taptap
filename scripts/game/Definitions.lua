local D = {}
D.title = "山河里"
D.size = 22
D.order = { "road", "house", "farm", "ranch", "mill", "butcher", "kitchen", "woodcutter", "quarry", "courier", "barracks" }
D.modes = {
    finite = { name = "有限 · 炊烟再起", description = "固定河谷 / 八步教学 / 重建并守村通关" },
    infinite = { name = "无限 · 山河拓荒", description = "逐圈开疆 / 持续经营 / 自动来袭与生存纪录" },
}
D.goods = { "wood", "stone", "grain", "flour", "livestock", "meat", "food" }
D.topGoods = { "wood", "stone", "food" }
D.names = { wood = "木料", stone = "石料", grain = "麦粒", flour = "面粉", livestock = "牲畜", meat = "鲜肉", food = "口粮" }
D.jobs = { kitchen = "厨师", butcher = "屠夫" }
function D.job(kind) return D.jobs[kind] or "工人" end
---@class VillageBuildingDefinition
---@field name string
---@field cost table<string,number>
---@field workers number
---@field color number[]
---@field description string
---@field footprint number[]?
---@field input string?
---@field alternateInput string?
---@field output string?
---@field amount number?
---@field period number?
---@type table<string,VillageBuildingDefinition>
D.buildings = {
    store = { name = "义仓", cost = {}, workers = 0, footprint = { 2, 2 }, color = { 85, 103, 101 }, description = "村庄的中心。工人沿道路运送物资。" },
    road = { name = "道路", cost = {}, workers = 0, color = { 190, 166, 116 }, description = "免费规划道路；空闲村民将到场铺设，完工后才能运输。拖动可移动地图。" },
    house = { name = "民居", cost = { wood = 8, stone = 2 }, workers = 0, footprint = { 2, 2 }, color = { 97, 111, 114 }, description = "两格见方的院落；竣工后增加 4 名村民，无需另行招募。" },
    farm = { name = "麦田", cost = { wood = 8 }, workers = 1, footprint = { 2, 2 }, output = "grain", amount = 3, period = 90, color = { 187, 157, 69 }, description = "两格见方的围栏麦田；相邻麦田会连片，只保留外侧栅栏。工人犁地、浇水、照料，约 90 秒成熟后收割，每轮收获 3 袋麦粒。" },
    ranch = { name = "牧场", cost = { wood = 10 }, workers = 1, footprint = { 2, 1 }, output = "livestock", amount = 2, period = 12, color = { 129, 113, 68 }, description = "工人照料牲畜，每 12 秒出栏 2 头；工人送往屠宰场。" },
    mill = { name = "磨坊", cost = { wood = 10, stone = 4 }, workers = 1, input = "grain", output = "flour", amount = 2, period = 6, color = { 118, 100, 79 }, description = "搬入 1 袋麦粒，加工为 2 袋面粉。" },
    butcher = { name = "屠宰场", cost = { wood = 8, stone = 3 }, workers = 1, input = "livestock", output = "meat", amount = 3, period = 8, color = { 145, 79, 62 }, description = "屠夫加工工人送来的牲畜，每 8 秒产出 3 份鲜肉；工人再送往食堂。" },
    kitchen = { name = "食堂", cost = { wood = 10, stone = 2 }, workers = 1, footprint = { 2, 2 }, input = "flour", alternateInput = "meat", output = "food", amount = 4, period = 6, color = { 146, 78, 61 }, description = "宽敞食堂有 4 个可见座位、8 份店内储粮；厨师烹饪，工人补粮，村民入座吃饭后离席。" },
    woodcutter = { name = "伐木场", cost = { wood = 6 }, workers = 1, footprint = { 2, 1 }, output = "wood", amount = 1, period = 8, color = { 100, 116, 74 }, description = "建在树林六格内并接通道路；伐木工走到树前挥斧砍伐，背木回场，搬运工再送往义仓。附近树木砍尽后需另建伐木场。" },
    quarry = { name = "采石场", cost = { wood = 8 }, workers = 1, footprint = { 2, 1 }, output = "stone", amount = 3, period = 11, color = { 123, 129, 125 }, description = "开采本区域石料，每 11 秒产出 3 份；拓荒发现新储量。" },
    courier = { name = "驿站", cost = { wood = 10, stone = 2 }, workers = 0, color = { 152, 117, 74 }, description = "调配 1 名工人负责搬运，占用 1 名村民。适合扩张后的长途运输。" },
    barracks = { name = "乡勇营", cost = { wood = 12, stone = 6 }, workers = 0, footprint = { 1, 2 }, color = { 144, 65, 53 }, description = "选中后训练乡勇：每人消耗 2 木料、2 口粮和 1 村民。" },
}
function D.footprint(kind)
    local size = D.buildings[kind] and D.buildings[kind].footprint
    return size and size[1] or 1, size and size[2] or 1
end
---@type {title:string, lines:string[], complete:string, kind:string, target:number}[]
D.lessons = {
    { title = "一 · 道通百业", lines = { "孩子，义仓虽在，路不通，百事都慢。", "点右下「营造」选「道路」，沿旧路规划四格。", "工人会取材、举锤；铺好才算通路。" }, complete="好，脚下有路，乡亲们就能送货了。", kind = "road", target = 4 },
    { title = "二 · 安居于此", lines = { "有路了，先为新来的乡亲盖间屋吧。", "民居要占两格见方，门前留一格路。", "等工人建好，就能多住四个人。" }, complete="屋里有了灯火，咱们的人手也宽裕了。", kind = "house", target = 1 },
    { title = "三 · 耕者有粮", lines = { "人要吃饭，田里的麦子得先种起来。", "沿路建一块围栏麦田，安排工人播种。", "麦子会自己生长，工人中途照料，成熟后再收割。" }, complete="麦穗起来了，接着得把麦粒磨细。", kind = "farm", target = 1 },
    { title = "四 · 麦成细粉", lines = { "光有麦粒还不够，得有磨坊。", "在路边建一座磨坊，门前接上道路。", "工人会送麦粒进去，磨好后再运出来。" }, complete="磨坊转起来，村里离热饭又近一步。", kind = "mill", target = 1 },
    { title = "五 · 炊烟起处", lines = { "食堂里有火，乡亲们才吃得上热饭。", "建食堂，安排厨师把面粉和鲜肉烹成口粮。", "食堂有四席，工人会把口粮送来补满储粮。" }, complete="炊烟又起，先让大家吃饱。", kind = "food", target = 4 },
    { title = "六 · 取材有度", lines = { "营造离不开木料，先在「营造」里选伐木场。", "靠近树林六格内建造，门前道路接通义仓。", "工人走到树前挥斧、背木回场；搬运工再送入义仓。" }, complete="木料有了来路，后面的工程有底气了。", kind = "woodcutter", target = 1 },
    { title = "七 · 乡勇集结", lines = { "山外不总太平，得让村里有人守望。", "建乡勇营，选中后训练三名乡勇。", "每人要两木、两粮，还要一名空闲村民。" }, complete="三名乡勇已齐，村口总算有了守护。", kind = "militia", target = 3 },
    { title = "八 · 守住炊烟", lines = { "最后一关，咱们一起守住这片炊烟。", "备齐乡勇，在军务里点「开始守村」。", "守住后，这方水土就交给你经营了。" }, complete="这回守住了。山河里，往后托付给你。", kind = "victory", target = 1 },
}
return D
