# Knights and Merchants 机制参考研究

研究时间：2026-10-19 UTC。源码基线：KaM Remake 公共仓库 `reyandme/kam_remake`，HEAD `c24539fd4a992850c83cf1d0c78ea0fb5a532bb5`。本文把原作兼容数据与 Remake 新增/调整明确分开；源码实证优先于记忆或二手概述。

## 来源与可访问性

- [KaM Remake 源码仓库](https://github.com/reyandme/kam_remake)（可访问）。README 将项目描述为对原作《The Shattered Kingdom》的 mod/remake，并说明其可扩展、修改游戏功能。
- [仓库 README](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/README.md)、[入门文档](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/Docs/Readme/getting-started_eng.md)、[技术文档](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/Docs/Readme/technical.md)。源码文件链接在各机制段落中。
- GitHub issue 搜索可访问；检索 `delivery` 找到 [Issue #338](https://github.com/reyandme/kam_remake/issues/338)，标题为“Add text description about red and yellow triangle in storehouse”，显示仓库存量/供应状态的可读性是有实际 UI 讨论的主题。检索 `production` 找到 [Issue #279](https://github.com/reyandme/kam_remake/issues/279)，议题为“Set Armory workshop to produce infinite Gambesons by default”，说明默认生产队列/无限生产设置会影响玩家经济管理。它们是社区/维护议题，不能当作普遍玩家共识或平衡数据。
- 访问限制实证（2026-10-19）：尝试 `https://www.reddit.com/r/KnightsAndMerchants/` 与 `https://knightsandmerchants.net` 均因当前环境网络策略在代理隧道阶段返回 403；未读取页面内容，不引用 Reddit/官网，也没有使用转发器、镜像或绕过代理。`https://github.com/reyandme/kam_remake/discussions` 返回 404，该仓库没有可读的 Discussions 页面。GitHub Issues 的公开网页可打开；搜索 `delivery`、`production` 能确认 #338、#279；后续批次查询收到 HTTP 429，故没有将其伪称为完整论坛调查。`/etc/codex/network-policy.json` 的允许域名包含 GitHub、raw GitHub，不包含 Reddit 或原作官网域名。

## 数量口径：建筑、物资、角色

`src/res/KM_ResTypes.pas` 的 `TKMHouseType` 含 `htNone`、`htAny` 两个非建筑值；Remake 可建范围 `HOUSE_MIN..HOUSE_MAX` 共 **29 类**。为免凭名称猜来源，下面直接展开 `KM_ResHouses.pas` 中机器可读的 `HOUSE_ID_TO_TYPE[0..29]` 映射，并对照 loader 的循环（`for i:=0 to 28 // KaM has only 28 houses`）：

| DAT/脚本 ID | 类型名 | 口径判断 |
|---:|---|---|
| 0 | htSawmill 锯木场 | 原 KaM House.Dat 读取 |
| 1 | htIronSmithy 铁匠铺 | 原 KaM House.Dat 读取 |
| 2 | htWeaponSmithy 武器铺 | 原 KaM House.Dat 读取 |
| 3 | htCoalMine 煤矿 | 原 KaM House.Dat 读取 |
| 4 | htIronMine 铁矿 | 原 KaM House.Dat 读取 |
| 5 | htGoldMine 金矿 | 原 KaM House.Dat 读取 |
| 6 | htFishermans 渔屋 | 原 KaM House.Dat 读取 |
| 7 | htBakery 面包房 | 原 KaM House.Dat 读取 |
| 8 | htFarm 农场 | 原 KaM House.Dat 读取 |
| 9 | htWoodcutters 伐木场 | 原 KaM House.Dat 读取 |
| 10 | htArmorSmithy 盔甲铺 | 原 KaM House.Dat 读取 |
| 11 | htStore 仓库 | 原 KaM House.Dat 读取 |
| 12 | htStables 马厩 | 原 KaM House.Dat 读取 |
| 13 | htSchool 学校 | 原 KaM House.Dat 读取 |
| 14 | htQuarry 采石场 | 原 KaM House.Dat 读取 |
| 15 | htMetallurgists 冶炼场 | 原 KaM House.Dat 读取 |
| 16 | htSwine 猪圈 | 原 KaM House.Dat 读取 |
| 17 | htWatchTower 瞭望塔 | 原 KaM House.Dat 读取 |
| 18 | htTownHall 市政厅 | 原 KaM House.Dat 读取 |
| 19 | htWeaponWorkshop 武器作坊 | 原 KaM House.Dat 读取 |
| 20 | htArmorWorkshop 盔甲作坊 | 原 KaM House.Dat 读取 |
| 21 | htBarracks 兵营 | 原 KaM House.Dat 读取 |
| 22 | htMill 磨坊 | 原 KaM House.Dat 读取 |
| 23 | htSiegeWorkshop 攻城器械作坊 | 原 KaM House.Dat 读取 |
| 24 | htButchers 屠夫铺 | 原 KaM House.Dat 读取 |
| 25 | htTannery 制革坊 | 原 KaM House.Dat 读取 |
| 26 | htNone 空占位，loader 跳过 | 不可建、不计建筑 |
| 27 | htInn 酒馆 | 原 KaM House.Dat 读取 |
| 28 | htVineyard 葡萄园 | 原 KaM House.Dat 读取；证据支持其属于经典 28 类之一 |
| 29 | htMarket 市场 | 类型表/House.Dat 槽存在，但不从原 DAT 读取；Remake 构造器单独初始化，故标为 Remake 新增 |

由 loader 注释和处理逻辑可证：经典 House.Dat 有 29 个编号位置（0–28），其中 ID26 是被跳过的空记录，因此有 **28 个经典房屋**，且包含葡萄园；Remake 当前类型再增加由代码初始化的市场，故是 29 个可建类型。`HOUSE_DAT_COUNT=30` 是 Remake/脚本映射表长度，不是 30 个经典建筑。`htAny` 仅为类型查询通配值。此计数依据的直接源码是 [House enum and ID tables](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResTypes.pas#L49-L60)、[ID map](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L190-L213)、[DAT loader](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L900-L925) 与 [Market custom initialization](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L796-L830)。

`src/res/KM_ResWares.pas` 的 `RES_COUNT=28`，含原料、半成品、食品和装备（含树干、石料、木材、煤铁矿/金矿、铁金、葡萄酒、玉米、面粉、面包、皮革、香肠、生猪、皮、盾甲、武器、马、鱼）。不是“28 种食物”。`TKMUnitType` 的代码注释把单位分为 Citizens、Warriors、TPR warriors、Animals；兵营有 9 种基本兵员类型，另有 Remake/资料包类型。文明风格改编要保留“一种货物跨多岗位、多工序”的结构，不必复刻全部 28 物资。

房屋的完整生产/服务输入输出如下（取 `HOUSE_DAT_X` hard-coded 表与 Market 特殊构造；`—` 代表无货物槽，`wtAll` 是通用收发）。岗位是职能概括；原始单位类型由 `House.Dat` 的 `WorkerType` 字段决定。该表避免把守备/训练建筑误看成普通加工厂。

| 房屋 | 输入 → 输出 | 岗位/备注 |
|---|---|---|
| 盔甲铺 | 煤+铁 → 铁甲、铁盾 | 盔甲匠；玩家下单 |
| 盔甲作坊 | 皮革+木材 → 木盾、皮甲 | 作坊工；玩家下单 |
| 面包房 | 面粉 → 面包 | 面包师 |
| 兵营 | 装备组 → 兵员 | 训练/装备；消耗多类军事货物 |
| 屠夫铺 | 猪 → 香肠 | 屠夫 |
| 煤矿 | — → 煤 | 矿工；资源点限制 |
| 农场 | — → 玉米 | 农夫；田地条件影响 |
| 渔屋 | — → 鱼 | 渔夫；靠水域 |
| 金矿 | — → 金矿石 | 矿工 |
| 酒馆 | 面包、香肠、葡萄酒、鱼 → 居民用餐 | 服务；按座位/食物类型记录 |
| 铁矿 | — → 铁矿石 | 矿工 |
| 铁匠铺 | 铁矿石+煤 → 铁 | 铁匠 |
| 市场 | 通用货物 → 通用货物 | Remake 新增；不是 House.Dat 生产链 |
| 冶炼场 | 金矿石+煤 → 金 | 冶炼工 |
| 磨坊 | 玉米 → 面粉 | 磨工 |
| 采石场 | — → 石料 | 石匠；石地限制 |
| 锯木场 | 树干 → 木材 | 锯木工 |
| 学校 | 无货物配方 → 教育/新工人能力 | 教育进度，不是普通货物链 |
| 攻城器械作坊 | 木材+铁 → 按订单制作器械 | 玩家下单 |
| 马厩 | 玉米 → 马 | 马夫；牲畜有生长 lag |
| 仓库 | 通用货物 → 通用货物 | 仓储/物流节点 |
| 猪圈 | 玉米 → 猪、皮 | 养猪工；两个产品同步产出 |
| 制革坊 | 皮 → 皮革 | 制革工 |
| 市政厅 | 金 → 兵员训练/晋升 | 黄金成本 |
| 瞭望塔 | 石料 → — | 守备设施/库存需求 |
| 武器铺 | 煤+铁 → 剑、长枪、弩 | 武器匠；玩家下单 |
| 武器作坊 | 木材 → 斧、枪、弓 | 木器匠；玩家下单 |
| 葡萄园 | — → 葡萄酒 | 园丁；原 House.Dat 记录 |
| 伐木场 | — → 树干 | 伐木工；树木位置/成熟影响 |

解锁关系、物资槽、人工订单旗标与建造字段可追溯 [HOUSE_DAT_X](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L234-L550)。实际岗位需资源包 `.dat` 数据才能完全还原；这里没有把无法从代码表读取的每个 House.Dat 工人名冒充源码确认值。

## 生产链、时长与产量

`KM_ResHouses.pas` 的 `HOUSE_DAT_X` 列明每种建筑的输入、输出、是否需玩家下单及解锁建筑；`KM_ResWares.pas` 定义 28 物资以及 `PRODUCTION_RATE`。源代码注释说明该数组来自测试地图实测 `WARE_COUNT / TIME`，单位为“每分钟平均产量”；`PRODUCTION_LAG` 表示新接管/建成后稳定生产前的分钟数估值，不是每件货物的直接工时。其中特别标出葡萄酒约 4 分钟、玉米 5 分钟、生猪/皮/马 6 分钟，树干 1–15 分钟（依树木环境）。这是平衡参考值，不可不经移植就照搬到手机实时制。

可从表中核对的典型链：

- 农田玉米 → 磨坊面粉 → 面包房面包 → 酒馆（输入面包、香肠、葡萄酒、鱼）。玉米还竞争供给猪圈和马厩。
- 玉米 → 猪圈同时产猪与皮 → 屠夫铺把猪变香肠；皮 → 制革坊皮革 → 盔甲作坊皮甲/木盾。
- 树林 → 伐木场树干 → 锯木场木材 → 武器作坊木制武器/武器材料、盔甲作坊木盾，也用于施工。
- 铁矿产铁矿石，煤矿产煤；铁矿石+煤 → 铁匠铺产铁；铁+煤在武器铺/盔甲铺转成铁制武器和盔甲；金矿石+煤 → 冶炼场产金，金供应市政厅招募兵员。
- 渔屋产鱼；葡萄园产葡萄酒；采石场产石料；市场可接收/提供多种货物以进行交换。

源码速率摘要（每分钟均值，直接计算数组分子/120；牲畜类 `84/180`，其余如数组）：树干 0.73（但环境 1–15 分钟）、石料 3.45、木材 3.25、铁矿石/金矿石各 1.33、煤 1.29、铁 1.82、金 2.75、葡萄酒 1、玉米 1.15、面包 2.8、面粉 1.35、皮革 2.7、香肠 4.25、生猪/皮各 0.47、马 0.58、鱼 1.02。此处只用于相对瓶颈判断：同一条链上的下游要有相近或更高吞吐；原作实际产量还受工人行走、休息、搬运、库存阈值、地块/树木和订单影响。

完整 `PRODUCTION_RATE` 数组展开如下。lag 表为稳定生产前分钟；未标明者均为 1 分钟。源码没有把这些平均值等价成每周期固定秒数，故每批周期应以实际建筑的工作动画/工人路径测量，不宜从速率反推为严格定时器。

| 物资 | 单位/分钟 | 稳定生产 lag（分钟） | 备注 |
|---|---:|---:|---|
| 树干 | 0.733 | 1–15 | 树木环境决定 |
| 石料 | 3.450 | 1 | 采石产量均值 |
| 木材 | 3.250 | 1 | 锯木 |
| 铁矿石 | 1.333 | 1 | 铁矿 |
| 金矿石 | 1.333 | 1 | 金矿 |
| 煤 | 1.292 | 1 | 煤矿 |
| 铁 | 1.817 | 1 | 铁匠铺 |
| 金 | 2.750 | 1 | 金矿石冶炼 |
| 葡萄酒 | 1.000 | 4 | 葡萄藤生长 |
| 玉米 | 1.150 | 5 | 农田生长 |
| 面包 | 2.800 | 1 | 面包房 |
| 面粉 | 1.350 | 1 | 磨坊 |
| 皮革 | 2.700 | 1 | 制革坊 |
| 香肠 | 4.250 | 1 | 屠夫铺 |
| 猪 | 0.467 | 6 | 畜养成长 |
| 皮 | 0.467 | 6 | 猪圈副产品 |
| 木盾 | 1.500 | 1 | 盔甲作坊 |
| 铁盾 | 1.292 | 1 | 盔甲铺 |
| 皮甲 | 1.500 | 1 | 盔甲作坊 |
| 铁甲 | 1.292 | 1 | 盔甲铺 |
| 斧 | 1.667 | 1 | 武器作坊 |
| 剑 | 1.625 | 1 | 武器铺 |
| 枪 | 1.667 | 1 | 武器作坊 |
| 长枪 | 1.625 | 1 | 武器铺 |
| 弓 | 1.667 | 1 | 武器作坊 |
| 弩 | 1.625 | 1 | 武器铺 |
| 马 | 0.575 | 6 | 马厩成长 |
| 鱼 | 1.017 | 1 | 捕鱼环境影响实际吞吐 |

上表里的产量是 Remake 注释所指“测试地图两小时计数/时间”的量级实测，不是原版单次配方定值。实际设计中还需区分：建筑配方每次消耗几件、生产动作时间、工人行走/休息、原料供给、成熟/资源环境、物流阻塞。比如 pig 与 skin 数值相同来自同步副产品，不意味着猪肉链能在无饲料时持续出产。

原作建筑输入/输出与解锁表可追溯至 [KM_ResHouses.pas#L234-L550](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L234-L550)，物资速率、lag、武器成本见 [KM_ResWares.pas#L50-L110](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResWares.pas#L50-L110)。

## 食物、士气/健康与兵装

原作把可由酒馆食用的种类作为面包、香肠、葡萄酒、鱼；进食不是“全村库存有食物”这样单一库存判断，而是居民/兵员寻找酒馆座位、酒馆逐席记食物种类，serf 按需求运送。`KM_Defaults.pas` 把 UNIT_MAX_CONDITION 定为 45×60 个状态点（注释称约45分钟生命）；一般单位低于 6×60 点会寻找酒馆，低于 90% condition 才继续吃。食物恢复单位最大状态的比例：面包 +40%、香肠 +60%、酒 +30%、鱼 +50%（源码注释称 KaM 原酒值 +20%，Remake 为平衡改 +30%）；入馆后按面包→香肠→酒→鱼顺序检查，直到超过90%或达单次进食上限。源码注释将原值出处指向 `knightsandmerchants.de` Tips & Tricks；该站本轮未访问，以上可验证的是当前 Remake 代码数值，不独立声称原版每一小数完全一致。

战士每秒检查饥饿状态（`HUNGER_CHECK_FREQ=10`，游戏 tick 10Hz）；低于 `UNIT_MAX_CONDITION*TROOPS_FEED_MAX`（45分钟量的55%）时向配送队列请求一份 `wtFood`，配送优先级 `diHigh2`（`KM_UnitWarrior.pas`）。配送员完成后把该战士喂至满状态；战斗损耗/饥饿因此与酒馆供餐共用 food demand。该链表明可达性和运送本身是生存/战斗准备的一部分。源码没有把食物设成营养素/饮食多样性指标；这些是《山河里》的原创层，不应说成原作机制。参考代码：[KM_Defaults.pas#L369-L386](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/common/KM_Defaults.pas#L369-L386)、[KM_UnitTaskGoEat.pas#L128-L180](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/units/tasks/KM_UnitTaskGoEat.pas#L128-L180)、[KM_UnitWarrior.pas#L290-L295](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/units/KM_UnitWarrior.pas#L290-L295)。

基本兵种与材料成本见 [KM_ResUnits.pas#L168-L178](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResUnits.pas#L168-L178)：民兵=斧；斧兵=木盾+皮甲+斧；剑士=铁盾+铁甲+剑；弓手=皮甲+弓；弩手=铁甲+弩；枪兵=皮甲+枪；长枪兵=铁甲+长枪；侦察骑兵=木盾+皮甲+斧+马；骑士=铁盾+铁甲+剑+马。装备是多工序、互相争夺铁/煤/木/皮革/金/玉米的跨链目标。

## 配送优先、供给阈值与堵塞

`KM_WareDistribution.pas` 的默认 4×4 目标库存矩阵按特定资源和消费建筑保存（数值 0–5）：铁→武器/盔甲铺默认 5/5；煤→铁匠/冶炼/武器铺/盔甲铺默认 3/5/3/3；木材→盔甲/武器作坊默认 2/5；玉米→磨坊/猪圈/马厩默认 4/5/3。源码注释明确：目标数量既是输入库存最大值，也影响配送优先级；其它未配置组合默认 5。Remake 还有按优先级、距离和竞争需求做的物流调度逻辑（`KM_HandLogistics.pas`）。

设计启示不是“配送自动就够了”，而是玩家能看见各消费点目标库存、正在路上的货、生产停工原因、队列/阻塞，并能调节配额。偏远/单通道路网会让运输员被远距离往返占用，货物在途增加周转时间；输入仓满也会反压上游，产生玩家可诊断的瓶颈。Issue #338 的仓库红黄三角说明题面给足可读提示是实用改进点；#279 的无限队列默认项体现持续生产授权也会影响经济节奏。

## 建造、拆除、有限与无限玩法

KaM 家族的施工玩法是先规划建筑，再由工人/运输将木材、石料送到计划点、builder 逐步施工；建筑 footprint、门口道路和供料距离因此都是经济问题，不是单纯装饰地块。源码房屋字段含 `WoodCost/StoneCost/BuildSupply`，`KM_Houses.pas` 中构建进度按每件资源 50 个进度单位分阶段；但具体各建筑的成本值保存在运行时加载的 `data/defines/houses.dat`，Git 源码没有该原版数据资产，故不编造完整成本数字。拆除会留下废墟，建材交付后已记作消耗，不回到库存；拆除还将屋内输入/输出货物计入消耗统计。源码未展示统一返还机制，因此本设计中的拆除 50% 回收是原创提案，不是 KaM 规则。可追溯：[KM_Houses.pas](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/houses/KM_Houses.pas#L730-L760)、[House construction progress](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/houses/KM_Houses.pas#L1190-L1265)、[house data loader](https://github.com/reyandme/kam_remake/blob/c24539fd4a992850c83cf1d0c78ea0fb5a532bb5/src/res/KM_ResHouses.pas#L900-L925)。

原作官方情景战役与 Remake skirmish/地图脚本目标各自不同，源码层不能概括成唯一“有限/无限胜负规则”。Remake README 证明其兼容战役、多人/脚本等，但未以通用经济“无限模式”作为官方定义。本项目应把目标定义为自己的模式：有限关卡有明确修复/送达/人口目标与失败条件；无限拓荒用渐进难度和可自选建造目标，且不假装等同 KaM 战役。

## 适用边界

本参考可验证的是 KaM Remake 的代码行为/兼容数据，不足以证明原作所有版本、资料片、地图脚本或玩家群体共识完全相同。原作数据从 Remake 的适配代码导出，不等同原版官方设计手册。中国风新作的数值须以新作品秒表、路径和吞吐实测重新定标。
