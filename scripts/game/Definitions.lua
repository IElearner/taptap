local D = {}
D.title = "山河里"
D.size = 22
D.order = { "road", "house", "farm", "mill", "kitchen", "woodcutter", "quarry", "courier", "barracks" }
D.modes = {
    finite = { name = "有限 · 炊烟再起", description = "固定河谷 / 八步教学 / 重建并守村通关" },
    infinite = { name = "无限 · 山河拓荒", description = "逐圈开疆 / 持续经营 / 自动来袭与生存纪录" },
}
D.goods = { "wood", "stone", "grain", "flour", "food" }
D.names = { wood = "木料", stone = "石料", grain = "稻谷", flour = "米粉", food = "口粮" }
---@class VillageBuildingDefinition
---@field name string
---@field cost table<string,number>
---@field workers number
---@field color number[]
---@field description string
---@field input string?
---@field output string?
---@field amount number?
---@field period number?
---@type table<string,VillageBuildingDefinition>
D.buildings = {
    store = { name = "义仓", cost = {}, workers = 0, color = { 85, 103, 101 }, description = "村庄的中心。搬运工沿道路运送物资。" },
    road = { name = "道路", cost = {}, workers = 0, color = { 190, 166, 116 }, description = "免费铺路。点击空地逐格修建；拖动仍为移动地图。" },
    house = { name = "民居", cost = { wood = 8, stone = 2 }, workers = 0, color = { 97, 111, 114 }, description = "竣工后增加 4 名村民，无需另行招募。" },
    farm = { name = "稻田", cost = { wood = 8 }, workers = 1, output = "grain", amount = 3, period = 7, color = { 187, 157, 69 }, description = "每 7 秒收获 3 份稻谷，由搬运工送入义仓。" },
    mill = { name = "磨坊", cost = { wood = 10, stone = 4 }, workers = 1, input = "grain", output = "flour", amount = 2, period = 6, color = { 118, 100, 79 }, description = "搬入 1 份稻谷，加工为 2 份米粉。" },
    kitchen = { name = "炊坊", cost = { wood = 10, stone = 2 }, workers = 1, input = "flour", output = "food", amount = 4, period = 6, color = { 146, 78, 61 }, description = "搬入 1 份米粉，制作 4 份口粮。" },
    woodcutter = { name = "伐木场", cost = { wood = 6 }, workers = 1, output = "wood", amount = 3, period = 8, color = { 100, 116, 74 }, description = "每 8 秒产出 3 份木料，为村庄持续供材。" },
    quarry = { name = "采石场", cost = { wood = 8 }, workers = 1, output = "stone", amount = 3, period = 11, color = { 123, 129, 125 }, description = "开采本区域石料，每 11 秒产出 3 份；拓荒发现新储量。" },
    courier = { name = "驿站", cost = { wood = 10, stone = 2 }, workers = 0, color = { 152, 117, 74 }, description = "增加 1 名搬运工，占用 1 名村民。适合扩张后的长途运输。" },
    barracks = { name = "乡勇营", cost = { wood = 12, stone = 6 }, workers = 0, color = { 144, 65, 53 }, description = "选中后训练乡勇：每人消耗 2 木料、2 口粮和 1 村民。" },
}
---@type {title:string, lines:string[], kind:string, target:number}[]
D.lessons = {
    { title = "一 · 道通百业", lines = { "里正：先从义仓门前接出道路。", "选择「道路」，点击浅色空地铺设。", "再建 4 格连通的路，不必拖动涂画。" }, kind = "road", target = 4 },
    { title = "二 · 安居于此", lines = { "选择「民居」，在道路北侧建造。", "每栋建筑的门朝地图下方一格。", "竣工后增加 4 名可工作的村民。" }, kind = "house", target = 1 },
    { title = "三 · 耕者有粮", lines = { "沿路建一块稻田，等待竣工。", "农夫自动上岗；搬运工运回稻谷。", "点建筑可查看岗位与道路状态。" }, kind = "farm", target = 1 },
    { title = "四 · 谷成细粉", lines = { "在已连通的路边建一座磨坊。", "搬运工从义仓送谷，磨坊才能开工。", "等仓中有稻谷后便会自动加工。" }, kind = "mill", target = 1 },
    { title = "五 · 炊烟起处", lines = { "建炊坊，打通稻谷→米粉→口粮。", "等待 4 份新口粮送回义仓。", "教学期间会保留救济粮，放心尝试。" }, kind = "food", target = 4 },
    { title = "六 · 取材有度", lines = { "建一座伐木场，补充建设用木。", "建筑竣工与生产都需要道路连通。", "可暂停经营，慢慢规划村庄。" }, kind = "woodcutter", target = 1 },
    { title = "七 · 乡勇集结", lines = { "建乡勇营，选中后训练 3 名乡勇。", "每人需要 2 木料、2 口粮和 1 村民。", "乡勇会在义仓附近自动集结。" }, kind = "militia", target = 3 },
    { title = "八 · 守住炊烟", lines = { "准备好后，点击「开始守村」。", "乡勇会自动迎敌，战斗中可补员。", "守住义仓，完成本章。" }, kind = "victory", target = 1 },
}
return D
