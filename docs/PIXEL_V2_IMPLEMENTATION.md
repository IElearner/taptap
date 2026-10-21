# 山河里像素 v1 — 13 类纵向切片开发记录

日期：2026-10-20。正式入口始终为 scripts/main.lua → network/Standalone.lua → Simulation/PixelWorldView/Hud/PixelSaveStore。没有切到 Godot；没有远程构建、commit、push，也没有启动 stopped preview。

## 本轮实现

- 新增锯木坊（4×3，10木6石，1原木→2木料/60秒）与饼坊（3×3，10木6石，1面粉→2面饼/40秒），沿用真实施工、岗位、饥饿、门口取放货和实体搬运系统。
- 原木、面饼独立库存与货物图集索引8、9；保留旧8格索引不变。伐木工每棵真实树产1原木，新厨房接面饼或鲜肉，旧v3厨房面粉继续兑现。
- 10课目标要求真实面饼/原木/木料交付；有限模式胜利要求新两工坊存在。初始库存仍72木40石28口粮10人口。基础两链费用62木，余10，乡勇营+3兵18木的缺口8由实际4根原木锯得。
- 新工坊设备动画由实际b.timer/workRate/inputs驱动；连接中断、无人或缺原料时不会空演。工作点使用原创新资产catalog坐标。实际sim.workers提供工作窗人员投影，不凭空加人口。
- 村务/义仓面板显示全部9种物资的仓储、待运、在途；选中建筑显示连路、岗位、原料/出货容量、工序进度与缺料/无工人/满库等卡点。
- 伐木选址预览显示附近余树与低资源警示，教学推荐西林6,4；已伐尽时提示另建林场。

## 存档与修复

- SaveData VERSION4兼容1/2/3；新资源只补0，旧wood仍为建筑木料。
- 旧樵夫货架或已经背着回场的木料采用legacyOutput='wood'。继续走完归营/堆架/旧货搬运，再切换原木，避免丢货或偷偷转义。
- 旧厨房typed flour、processingResource.flour与在途flour任务保留；新任务仅请求bread/meat。
- 修复安全减员后同帧存档worker slot无效：立即清除被撤岗位actor；负重、砍伐归营、付费进食/喂料中的岗位拒绝撤销并给说明，避免伐树材料丢失。
- 修复战斗伤亡同帧guards与militia不一致：死亡立即同步guard数组。

## 范围校准

保留P1既有施工36工秒、东南锚点、磨坊1麦→2粉/6秒、牧场麦粒饲料、厨房4口粮/批；32建筑GDD仍为长期提案，不把这些P1校准声称为完整GDD。新增两楼原创PNG、cargo与4×3施工图由parent负责资产流程，开发只统一编辑Lua。

## 开发验证

- 完整分段读取AGENTS.md 1150行、开发指南与相关UI/NanoVG/验证技能、3个相关示例。
- 每批实际运行官方0.0.37 preview status，始终install_state=missing,state=stopped,process_alive=false，遵规则不启动。
- 官方maker-lua-lsp --mode check无法运行，因为缺emmylua_check；切换已装官方watch/emmylua_ls路径完成诊断。最终2026-10-20 06:09:33报告：Errors0、Warnings0，/workspace/work/development/lsp-final/lua_diagnostics.log。
- git diff --check通过。
- 独立agent3 QA承担冻结版本原生首局、30分钟经济、旧真实v3迁移、减员与战斗存档、触摸及视觉序列验收。报告以QA最终结果为准，不将旧基线或中间2原木实验当最终通过证据。

## 冻结候选首局结果

最终源码/像素资源摘要：095b01960dc495208e10f006c50feb6d2e6bd016ac5d26d41eb8a86c2fd7309f。
独立QA `qa2026-final-newgame`：119/119断言通过；前后摘要相同；真实72木40石、1原木/树、西林6,4，完整10课、途中施工存档恢复、实体粮木链、等待施工队返仓后训练三兵、守村胜利。missing=[]，issues=[]。原始report仍FAIL/exit1，唯一raw error是宿主 /home/agent/logs/lua 日志文件写权限，未改写为PASS。

设施计数：13栋经营建筑＝12栋菜单可建楼＋预置义仓1；营造菜单13项＝12栋可建楼＋道路1。义仓不是新增可建选项，道路不计为经营建筑。

## 最终冻结逻辑回归

同一095b0196摘要的独立原生回归合计229/229断言通过：新档119、真实v3迁移50、岗位减员5、战斗同帧存档2、namespace/备份10、输入13、30分钟与离线30。所有manifest的sourceBefore/sourceAfter一致。原始raw FAIL均保留：唯一错误为宿主日志目录写权限，未隐藏或改为原生PASS。

30分钟测试关闭教学保障（skipped=true），按18000次普通online .1秒更新，含六次5分钟存档检查点恢复，餐食链继续生产且村民重复用餐返回岗位。离线检查覆盖新锯木/烘饼生产、战斗不推进、8小时封顶、未来时间戳/关闭离线不结算，以及同一时段不可重复领取。视觉与设计签字由独立验收记录承载。

## 旧档厨房库存文案补正

在095b0196冻结逻辑全部验收之后，追加仅Hud.lua的窄修：当旧厨房inputGoods.flour>0，库存与生产状态明确显示“旧档面粉 n（续用）”，避免把兼容旧原料误读为新面饼。配方、物资、存档及其余游戏代码未改；精确before/after补丁保留于 PIXEL_V2_LEGACY_FLOUR_HUD.diff。受影响的小屏HUD与真实v3迁移由QA在新摘要上复查，原095b逻辑结果仍保留。

同一HUD窄批另补正三项真实状态：牧场出栏缓冲2头已满，樵夫缓冲≥6暂停新采伐（明确为启工阈值，双人并发已在途可超过6），采石储量rock=0提示耗尽。仅显示逻辑与阈值说明调整，经济规则、资源数量与工人流程未变；QA对选中面板增加对应状态断言。

台账同批补记真实樵夫负重：仅carrying且未stockedLoad的woodcutter进入在途，数量取loadAmount或旧档默认1，资源取outputResource以保留旧wood迁移语义。物资交到buffer时已清carry，不重复统计；施工已预付材料不重新算作库存。QA增加rawwood/legacywood与交架后不双算的HUD断言。

## HUD第一批冻结（后续仅HUD继续补正）

该批生产摘要：3c00d0448466f9f48cb51fff6f4d1a7fb1de6580157efa62c28c97ffd798fd88。相对095b生产文件差异仅Hud.lua，精确补丁见本目录PIXEL_V2_LEGACY_FLOUR_HUD.diff。

此最终摘要下，独立QA追加验证：smallhud-complete 39/39（含旧面粉、牧场满栏、原木阈值、采石耗尽、工人负重与交架不双算）、east-recovery-frozen 104/104（低树量东林后的西林恢复）、migration-final 50/50、新工坊原生真实施工8/8，全部前后摘要一致、issues为空。保留095b的完整229项逻辑与5项连续生产视觉证据，不将不同摘要包装为一个原生PASS。所有raw宿主日志写权限FAIL保留原貌。

最终官方LSP诊断时间2026-10-20 06:21:43：Errors0、Warnings0，日志/workspace/work/development/lsp-release/lua_diagnostics.log。生产文件保持冻结，最终设计/QA签字与未实测边界以共同验收文档为准。


## 暂停读档显示补正后的候选

最终候选摘要：1fa74ea0db468efcd4ba52b74e9636aae5ba8077ff10f7cf4f77c04b7296549c。仍仅Hud.lua相对095b有差异，经济/存档/渲染未更改。暂停时状态优先明确“已暂停经营”，所有选中在岗数量显示“暂停中”；未暂停时必须activeWorkers与workRate同时大于0才报正在作业，避免读档后残留workRate配合尚未刷新activeWorkers产生误导。QA确认原生测试结束后才修改；补暂停读档断言与实际滚动截图后重新签字。

## 樵夫原木货物投影补正

候选摘要89df53b543d25eb04d80a4ba31407f948ff02db4280847ef279e0b6eab506e0a。相对095b最终桥接为Hud.lua与PixelActors.lua两个文件，不能再称全部只有HUD差异。PixelActors原先对没有job的樵夫使用Cargo.resource默认wood，现仅樵夫负重改用sim:outputResource(b)：新原木取图集第8列rawwood，旧档legacyOutput仍第0列wood，交架后carry=false不再绘货物；其他角色Cargo.resource不变。精确单行补丁见PIXEL_V2_LOGGER_CARGO.diff。无经济/存档改动；QA补两语义及交架不双算投影断言、实际背原木原生截图。
