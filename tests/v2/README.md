# 山河里 13 设施阶段：独立原生回归

这是 2026-10-20 的 **13 设施阶段基线**，不是用户最新要求的 24+ 建筑完整游戏验收。测试仅使用独立内存存档/夹具，不访问玩家存档、账号或云端。

在项目根运行，例如：

```bash
python tests/v2/run_native.py tests/v2/hud_v2.lua --run my-hud-01 --frames 165
python tests/v2/run_native.py tests/v2/newgame_v2_chunked.lua --run my-newgame-01 --frames 650
python tests/v2/run_native.py tests/v2/east_recovery.lua --run my-east-01 --frames 650
python tests/v2/run_native.py tests/v2/endurance_offline.lua --run my-endurance-01 --frames 300
python tests/v2/run_native.py tests/v2/migration_validate.lua --run my-migration-01 --frames 65
python tests/v2/run_native.py tests/v2/systems_validate.lua --run my-systems-01 --frames 300
python tests/v2/run_native.py tests/v2/new_goods_transit.lua --run my-transit-01 --frames 65
python tests/v2/run_native.py tests/v2/logger_cargo_visual.lua --run my-logger-01 --frames 525 --width 1280 --height 720
python tests/v2/run_native.py tests/v2/workshops_visual.lua --run my-workshops-01 --frames 835 --width 1280 --height 720
python tests/v2/run_native.py tests/v2/new_building_construction.lua --run my-construction-01 --frames 1035 --width 1280 --height 720
```

运行器从自身路径寻找项目，不依赖 `/workspace/work`。它要求本地 `.cli/UrhoXRuntime` 和已有 `.cli/ResCache`，不下载、不远程构建。重用 `--run` 会被拒绝，保护原始报告。原始 JSON、日志和前后源码摘要在 `evidence/raw/`。截图会按固定名字更新，正式保存证据前请复制对应目录并同时保留 manifest。

`fixtures/legacy_v3_fixture.json` 是真实旧像素版本保存的村庄，旧基础源摘要 cf5b9ac032110331a023a90ca7ccdf93233a873131c38ec857a4f464db059da0；`fixtures/v2_playable_fixture.json` 是 095b0196 新局通过真实道路、建造和生产得到的村庄。两者保持原始 `File.WriteString` 文件字节（末尾 NUL）；原生 `File.ReadString` 能正常读取，外部 JSON 工具可先去掉终止 NUL。新局测试生成的诊断快照另写 `evidence/generated_v2_fixture.json`，不覆盖夹具。

本宿主运行器会因不能写 `/home/agent/logs/lua/…` 而返回总 `FAIL`/退出码 1；原样保留。产品断言、额外 Lua 异常、资源缺失、尖峰与源码前后一致性须逐项审阅，不能把“断言全过”变为“运行器总 PASS”。44/46 个断言等于多少验收项并无直接换算关系。真实手机触控、帧率、功耗均未验证。

冻结哈希与受影响范围见项目 docs 的 `PIXEL_V2_LEGACY_FLOUR_HUD.diff`、`PIXEL_V2_LOGGER_CARGO.diff`；历史证据可通过精确文件差异桥接，不能冒称所有测试运行于同一个版本。
