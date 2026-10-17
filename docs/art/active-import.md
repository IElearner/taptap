# 已接入游戏的图片

2026-10-17 在本工作区重新生成并实际导入六张原画。原始输出保留在 `/workspace/generated_images/`，项目副本在 `assets/image/`；没有使用先前无法下载的 Maker 图集 URL。图集的实际尺寸及内容已经逐张目视检查，游戏直接按图集格子读取，不依赖预设的 101 张裁切文件。

| 游戏资源 | 图集内容 | 源文件 |
|---|---|---|
| `login-painting.png` | 河谷村落登录背景 | `exec-44a1c132-3fa5-47c9-87f3-6862dea8ce23.png` |
| `atlas-buildings.png` | 3×3 九种建筑 | `exec-afc7b06c-d63b-4033-b1be-c089de350ddf.png` |
| `atlas-villagers.png` | 4×4 四种村民与朝向 | `exec-8e58454f-0626-4644-a3b2-2ad6e9b087ae.png` |
| `atlas-workers.png` | 4×4 农夫、匠人、伐木工、女乡勇 | `exec-a659627c-dc10-4047-9b5f-02b56bb1842a.png` |
| `portrait-elder.png` | 谢伯对话肖像 | `exec-ba085438-c63b-403e-8045-418060279cf6.png` |
| `atlas-environment.png` | 树木、植被、草地、道路、水面 | `exec-0fb9ab32-46d9-4086-9575-07b1d0eccc80.png` |

六张图已有 Maker 官方 `.meta`。`Art.lua` 按实际图集位置和尺寸取样；搬运时仍使用各人身份的同一张人物图，并叠加货物表现。当前登录页、教程和地图截图已在真实引擎中核对；地图地面图集为减少重复纹理以较低透明度覆盖基础地块。

先前 `handpaint-layout.json` 对应的 Maker 输出仍未下载，`dev/check_art.py` 是那套完整裁切素材的验收脚本，不能用其缺失报告代替本次六张图片是否已接入的验证。
