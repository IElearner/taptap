# 已接入游戏的图片

2026-10-17 在本工作区重新生成并实际导入十一张原画。原始输出保留在 `/workspace/generated_images/`，项目副本在 `assets/image/`；没有使用先前无法下载的 Maker 图集 URL。图集的实际尺寸及内容已经逐张目视检查，游戏直接按图集格子读取，不依赖预设的 101 张裁切文件。

| 游戏资源 | 图集内容 | 源文件 |
|---|---|---|
| `login-painting.png` | 河谷村落登录背景 | `exec-44a1c132-3fa5-47c9-87f3-6862dea8ce23.png` |
| `atlas-buildings.png` | 3×3 九种建筑 | `exec-afc7b06c-d63b-4033-b1be-c089de350ddf.png` |
| `atlas-villagers.png` | 4×4 四种村民与朝向 | `exec-8e58454f-0626-4644-a3b2-2ad6e9b087ae.png` |
| `atlas-workers.png` | 4×4 农夫、匠人、伐木工、女乡勇 | `exec-a659627c-dc10-4047-9b5f-02b56bb1842a.png` |
| `portrait-elder.png` | 谢伯对话肖像 | `exec-ba085438-c63b-403e-8045-418060279cf6.png` |
| `atlas-environment.png` | 树木、植被、草地、道路、水面 | `exec-0fb9ab32-46d9-4086-9575-07b1d0eccc80.png` |
| `atlas-loaded.png` | 4×4 四种村民搬运物资 | `exec-f478340d-b5ef-4d96-881f-c16356c71f99.png` |
| `atlas-combatants.png` | 4×2 乡勇、山匪四方向 | `exec-7304bdcf-6dab-4a44-b795-a4ed103222b9.png` |
| `atlas-icons.png` | 4×4 菜单、物资及状态图标 | `exec-55a83b0a-3791-43bf-b90c-2bfe811e1a56.png` |
| `panel-wood.png` | 手绘深色木纹面板 | `exec-b8028b65-9a21-4312-8298-c67c3fa818a6.png` |
| `button-painting.png` | 铜饰木质按钮 | `exec-99b3e56b-52d6-4d1c-b578-6c429910bb22.png` |

十一张图已有 Maker 官方 `.meta`。`Art.lua` 按实际图集位置和尺寸取样；搬运人物、界面图标、木纹面板和按钮均读取图片。当前登录页、教程和地图截图已在真实引擎中核对；地图地面图集为减少重复纹理以较低透明度覆盖基础地块。

手机测试包的资源路径从 `asset_dirs` 根目录开始，使用 `image/*.png`，不能使用工作区文件路径 `assets/image/*.png` 或 `fileSystem:FileExists` 判断资源是否可用。`.project/resources.json` 把 `default` 加入 `preload_groups`，保证这些界面与地图图片在游戏启动前下载；生成测试二维码后应核对线上 manifest 的 `preload_groups` 和图片条目。

先前 `handpaint-layout.json` 对应的 Maker 输出仍未下载，`dev/check_art.py` 是那套完整裁切素材的验收脚本，不能用其缺失报告代替本次六张图片是否已接入的验证。
