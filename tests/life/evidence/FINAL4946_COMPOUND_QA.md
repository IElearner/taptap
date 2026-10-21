# 最终复合院落独立 QA 签收

**本轮限定范围通过。** 最终源码 `4946f47a59b228956275c3e757fa40f7c805315dc51a4ee0df0ac0ba4772cbd9`，192 个生产文件、Save12。QA 已结束全部原生进程并正式释放窗口。这里签收房屋与院落整体化、真实木架交接、资源地形/矿轨约束及有明确前置条件的安全重整；**不签全游戏95%、旧经济耐久R02、军事或全部25设施同城容量。手机真机未测。**

## 原生结果与版本归属

最终源码下六组 **451/451** 独立断言通过，全部 raw PASS、完整结束、无产品错误/缺资源。另有 d186 六组 **66/66** 按明确差异范围继承，不能写成517条都在同一源码运行。

| 最终4946运行 | 断言 | 直接证明 |
|---|---:|---|
| final4946-woodrack | 19/19 | 正常砍树→负重停工→真实木架stack→普通搬运E.take→义仓；逐阶段JSON、守恒、可见取货 |
| final4946-pickup-save | 16/16 | 原d186真实失败档现可恢复；反复JSON不重复；错误坐标、门、ID、phase、负货量仍拒绝 |
| final4946-compound-model | 336/336 | 17类真实canBuild/build院落、预览一致、站点可达、门路/占地、费用、来源、保存，以及真实旧schema8带货村 |
| final4946-terrain | 22/22 | 森林存在但不可达拒建；干岸四邻真水/门到岸路径；矿源身份与耗尽不重建 |
| final4946-rail | 52/52 | 四采矿类别同一真实railRoute进出洞、阶段JSON、载货停工继续交料、有限池与货物守恒 |
| final4946-south | 6/6 | 合法南岸实际场景、生产绘制原语边界、两张持帧原生图 |

[完整运行/完成性索引](FINAL4946_COMPOUND_RUN_INDEX.json) 逐组列出 manifest、complete artifact、显式结束帧和source前后摘要。所有组还检查test/helper/fixture在运行中不变。宿主仅额外授权 `/home/agent/logs/lua` 写入，没有改HOME或放宽生产权限。

d186继承组为升级API34、实际HUD触控12、木/鱼/采石/磨坊四场各5，共66。QA从d186生产快照独立反算192文件：当前4946仅 `SaveData.lua` 和 `PixelLife.lua` 两文件变化，逆覆盖恰恢复完整d186摘要；见 [独立精确桥](FINAL4946_SOURCE_BRIDGE.json)。改变范围只有私路目标连续坐标比较与南岸指台末端，故不影响已复核的东岸鱼场、木场、采石、磨坊构图和升级按钮。**南岸画面单独新拍，存档相关行为单独重跑，不用桥接跳过受影响门。**

## 关闭的问题与保留的失败

- **真实存档阻断已关闭。** d186自然搬运approach阶段，cjson后重算target.y为`3.8916666666666666`，保存值为`3.8916666666666671`。生产严格相等导致有效存档被拒。原脚本最终19/19完整通过；原失败档另16/16重放/坏值边界通过。修复仅连续目标坐标`1e-9`格容差；身份、整数门点、货物与阶段约束仍严格。
- **木场空门点放货/隐藏搬运已关闭。** 真实架侧坐标`(3.8875,3.8916666667)`：23.9s樵夫仍持木进行stack；36.7s普通搬运在同点loading，实际projection可见且cargo为rawwood。仓架/手持/在途总账最终独立通过。
- **南岸木脚越保留界已关闭。** 实际合法场景shoreApproach`(26,9.3)`，相对shoreY110.4，保留底界120.4。直接调用生产ground绘制函数捕获所有矩形，最大底边120，包含木脚，未越界。14.9s实际角色进入`fish`垂钓阶段；该专项**不是完整捕鱼周期**，不宣称已经catch或入箱。
- **构图与地形表现已复核。** 小主院、错缝木板/短指台、自然像素岩及路面低矿纹取代先前大地毯和压路几何标记。设计独立签收四类固定场地及南岸图，见 [设计签收](../../../docs/COMPOUND_DESIGN_REVIEW.md)。

原 `d186-woodrack` 与 diagnostic 各7/9 FAIL完整保留，代表同一真实缺陷；不计入通过、不改原记录。`d186-compoundvisual-mill` 的1800帧预算截断只有自动1/1 PASS、无complete，明确排除；其后 `mill-complete` 在1957帧真实完成5/5和47图。更早c083的浮点夹具失败及视觉拒收仍在历史报告，不倒改为通过。

## 可复核的关键画面

| 场景 | 总览与实际交互 |
|---|---|
| 木场 | [院落](visual/d186-compoundvisual-woodcutter-overview-1.png) · [樵夫码架](visual/d186-compoundvisual-woodcutter-stack-2.png) · [普通搬运真实取木](visual/d186-compoundvisual-woodcutter-carrier-picked-2.png) |
| 渔屋 | [东岸院台](visual/d186-compoundvisual-fishery-overview-1.png) · [侧箱放鱼](visual/d186-compoundvisual-fishery-stow-2.png) · [最终南岸](visual/final4946-south-overview.png) · [实际岸钓阶段](visual/final4946-south-actual-bank.png) |
| 采石场 | [正常tick后洞口](visual/d186-compoundvisual-quarry-rest-2.png) · [同轨人车出洞](visual/d186-compoundvisual-quarry-rideOut-2.png) · [普通搬运取原石](visual/d186-compoundvisual-quarry-carrier-picked-2.png) |
| 磨坊 | [完整组总览](visual/d186-compoundvisual-mill-complete-overview-1.png) · [手接低磨](visual/d186-compoundvisual-mill-complete-work-2.png) · [真实侧篮入料](visual/d186-compoundvisual-mill-complete-stow-2.png) |
| 重整按钮 | [844×390可见按钮](visual/d186-upgrade-hud-before-busy-touch.png) · [忙态理由](visual/d186-upgrade-hud-busy-reason.png) · [成功后状态](visual/d186-upgrade-hud-success.png) |

QA亲自打开以上关键原图；设计独立逐图复核。采石t0 overview是未初始化旧岩堆立面，实际首tick选矿洞图，故签收以正常rest/mine/ride图为准。磨坊屋内原图大磨盘和院内真实低磨同时存在，设计判断当前主体/设备关系可接受。

HUD用真实地图触控选择、滚动及hit-test坐标点按钮，未直接调用upgradeCompound代替用户操作。首次点按钮给停工理由、持久状态不变；经正常公开setWorking(false)操作后再真实点按钮成功，按钮消失，库存/路/人口及存读保持。成功测试是明确的合成旧schema8缺site夹具；真实旧schema8已有负重搬运另测忙态拒绝。

## 证据边界与签字

这些是显式受控建材/完工道路、自然角色/真实工序的独立夹具，不是完整新局经济实得证明。17类院落几何与四类代表场地画面不是全部25楼同城验证，也不是每类每朝向完整视觉重复。当前直接存档证据包括Save12实际木架/矿轨阶段、原失败档以及真实schema8旧村；**未把旧的schema1–9硬编码测试冒充Save12对全部1–11历史版本与每种旧活跃木工状态的穷尽验证**。相关开发纯模型仅作为补充，不计入QA451。

**QA签字：agent3，通过本报告限定的本轮复合院落交互/地形/重整范围。设计签字：agent1，见独立设计报告。** 未发现该范围内仍未关闭的P1；已知旧R02失败保持原结论，本轮没有放宽任何旧验收门或宣称整游戏完成度。
