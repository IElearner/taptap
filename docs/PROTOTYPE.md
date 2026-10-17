# 山河里 · 炊烟再起

接近经典《骑士与商人》的俯视等距建设玩法，原创中式村庄；以横屏手游操作为目标。当前为 Lua / TapTap Maker 单机原型，画面使用程序绘制的等距瓦片与中式建筑，不包含原作素材。

## 第一章

八步引导：接路 → 民居 → 稻田 → 磨坊 → 炊坊并送回新口粮 → 伐木场 → 乡勇营、训练三人 → 抵御山匪。

点击底部建筑后，点击地图空地放置；建筑的门位于地图坐标下方一格，必须接路通往义仓。道路免费且必须接着现有路铺设。单指拖动地图，双指捏合缩放；桌面可鼠标拖动并使用 ± 按钮。点击建筑查看状态与增减岗位。暂停、倍速、教程跳过和回看均可使用。

工人自动上岗，三名搬运工实际沿道路运送输入和产出。稻田产稻谷，磨坊加工成米粉，炊坊制作口粮，伐木场补充木料。民居增加人口，乡勇占用人口；教学救济粮避免初次尝试陷入断粮死局。守村由玩家手动开始，乡勇自动迎敌。

## 模块

- `scripts/main.lua`：Maker 入口。
- `scripts/network/Standalone.lua`：单机生命周期，基于官方 2D 脚手架。
- `scripts/game/Simulation.lua`：独立于引擎的经济、运输、建造、教程与战斗。
- `scripts/game/WorldView.lua`：等距地图、触控与程序美术。
- `scripts/game/Hud.lua`：安全区布局、资源、建筑、教程与结算。
- `tests/village_validate.lua`：生产链、教程闭环、资源约束、胜负的引擎断言。
- `tests/village_showcase.lua`：可复现的视觉检查场景。

## 本地验证

先安装运行时：`python3 .cli/install-urhox-runtime.py --dest .cli`。

在项目根目录执行（Linux 无窗口渲染）：

```bash
mkdir -p .tmp/acceptance
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe EGL_PLATFORM=surfaceless \
timeout 60 .cli/UrhoXRuntime main.lua -tapcode_dir="$PWD" -tool_mode \
  -graphicssurfaceless -nosound -validate -validate-frames=40 \
  -validate-timeout=50 -validate-spike-threshold=1000 \
  -validate-test="$PWD/tests/village_validate.lua" \
  -validate-output="$PWD/.tmp/acceptance/gameplay.json"
```

已增加有限关卡与无限拓荒两种模式，详见 [世界地图与玩法设计](WORLD_MODES.md)。新增采石场、驿站、义仓修缮、持续敌袭和探索成本。引擎验收已覆盖两种模式及手机操作回调。

当前原型不包含存档、正式图片/音效资源、联网或自由调兵。乡勇自动守卫是首关的简化战斗，不代表完整 RTS 战斗系统。部署与手机试玩入口见后续构建结果。
