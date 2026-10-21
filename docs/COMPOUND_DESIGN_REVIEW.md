# 复合院落设计复核

最终设计签收对象：候选源码 `4946f47a59b228956275c3e757fa40f7c805315dc51a4ee0df0ac0ba4772cbd9`。四种固定镜头场地（渔屋、采石场、磨坊、伐木棚）的视觉复核采用 d186 原生帧；d186 到最终候选只有两文件精确修复桥，已验证的四场表现沿用。南岸台界另以 final4946 原生帧复核。本报告只签场地构图、地形结合和真实货架接触，不是全游戏验收。

## 设计结论

- **渔屋：通过。** 屋前主台缩小，水侧短指状码头抵达实际岸线；摇椅、水箱和屋体组成紧凑院落，门前石路连续。原生 stow 帧中渔夫站在水箱侧沿放鱼，身体和手部动作可读。见 [总览](../tests/life/evidence/visual/d186-compoundvisual-fishery-overview-1.png)、[入箱](../tests/life/evidence/visual/d186-compoundvisual-fishery-stow-2.png)。final4946 南岸场景也已复核：[南岸总览](../tests/life/evidence/visual/final4946-south-overview.png)、[实际岸钓](../tests/life/evidence/visual/final4946-south-actual-bank.png)。QA 捕获实际 maxY=120，yard bottom=120.4、shoreY=110.4，鱼夫 14.9 秒完成真实岸钓周期，未越院界或踩水。
- **采石场：通过。** 洞口、同一条矿车轨、车位和前院交料区连成一个场地。资源表现已改为草地上的低像素岩簇，避开公共石路；正常 tick 后洞口打开，和初始封洞立面状态有清楚区别。矿工沿轨出洞、在院内堆料，普通搬运者随后在同一堆位取走原石。见 [初始总览](../tests/life/evidence/visual/d186-compoundvisual-quarry-overview-1.png)、[开洞作业](../tests/life/evidence/visual/d186-compoundvisual-quarry-mine-2.png)、[骑车出洞](../tests/life/evidence/visual/d186-compoundvisual-quarry-rideOut-2.png)、[搬运取料](../tests/life/evidence/visual/d186-compoundvisual-quarry-carrier-picked-2.png)。QA manifest 为 5/5、状态完整。
- **磨坊：通过。** 磨盘、仓篮和门前路落在收紧后的同一院内；工人手部与低磨盘接触清晰。主屋墙面圆轮和院内工作磨盘都保留，但目前读作磨坊主体与院内作业设备，并未破坏建筑识别，不要求本轮再改美术。见 [总览](../tests/life/evidence/visual/d186-compoundvisual-mill-complete-overview-1.png)、[实际作业](../tests/life/evidence/visual/d186-compoundvisual-mill-complete-work-2.png)、[堆料](../tests/life/evidence/visual/d186-compoundvisual-mill-complete-stow-2.png)、[搬运取货](../tests/life/evidence/visual/d186-compoundvisual-mill-complete-carrier-picked-2.png)。完整组 1957 帧、47 图，manifest 5/5、状态完整。
- **伐木棚：通过，含真实货架交接。** 短台面与错列接缝已弱化矩形地毯感；棚旁木架位于左前檐，贴近林缘。伐木工在架边堆入 `rawwood`，同一位置的普通搬运者随后实际取货；画面可辨接触动作，状态快照显示货物类型和库存变化相符。见 [总览](../tests/life/evidence/visual/d186-compoundvisual-woodcutter-overview-1.png)、[堆料](../tests/life/evidence/visual/d186-compoundvisual-woodcutter-stack-2.png)、[搬运取货](../tests/life/evidence/visual/d186-compoundvisual-woodcutter-carrier-picked-2.png)。QA manifest 为 5/5、状态完整。

## 最终针对性回归与范围

最终 hash 下的六个 QA manifest 均 raw PASS 且 source 前后 hash 一致：模型 336/336、存档/货架失败档 16/16、矿车轨道 52/52、南岸台界 6/6、地形资源 22/22、木架交付 19/19，共 451 条定向断言。原 `SaveData` 私有 pickup destination 1 ULP 拒绝已由最终候选的 16/16 存档边界复测关闭；南岸台界限制由 6/6 原生场景与边界断言复测关闭。磨坊完整原生组为 5/5。

本签收只覆盖四个独立场地、南岸鱼场及上述真实作业/货架接触，不证明全部 25 类建筑可在同一城镇布局中摆放，不证明旧档安全重整的所有状态，也不代表全游戏 95% 或整体验收。手机真机表现未测。
