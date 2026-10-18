# 建筑占地、道路与施工参考

研究日期：2026-10-18。直接访问 KaM Remake 官网和 Reddit 时，环境代理返回了 403；本轮实际阅读和查看的是下列项目仓库资料，以及玩家提供的视频。

- [项目说明](https://github.com/Kromster80/kam_remake/blob/b199128f2ce826302a7626463018bfb88cfde032/README.md)：说明该项目与原作的关系，并列出官网及后续维护仓库。
- [建筑资源定义](https://github.com/Kromster80/kam_remake/blob/b199128f2ce826302a7626463018bfb88cfde032/src/res/KM_ResHouses.pas)：`PlanYX` 为逐格的建筑形状矩阵，多种建筑不是完整矩形；入口与建造区域另有定义。
- [道路绘制](https://github.com/Kromster80/kam_remake/blob/b199128f2ce826302a7626463018bfb88cfde032/src/render/KM_RenderTerrain.pas)：按北、东、南、西四邻域生成 16 种连接情况，再选择道路形状和方向。
- [食堂图片](https://github.com/Kromster80/kam_remake/blob/b199128f2ce826302a7626463018bfb88cfde032/Docs/Houses/htInn.png)：观察主屋、附属棚、台阶与木石材质的层次。
- [道路设计草图](https://github.com/Kromster80/kam_remake/blob/b199128f2ce826302a7626463018bfb88cfde032/Docs/Diagonal%20roads%20mockup/diag-4.jpg)：用于观察道路宽度、路缘和村落间距；这是仓库中的设计草图，不作为已发布游戏功能的证据。

本轮实现：

1. 建筑保存自己的占地单元，碰撞、索引、规划轮廓、施工工位和存档使用同一份形状；L 形的凹角可以走路。
2. 道路中心与各方向的支路分别建模，竖直道路不会固定附带一条横杠。
3. 无路时仅放测量桩和等待接路标记；道路建成后，原有任务调度派工，材料不重复扣除。
4. 木材、石材、灰泥、布料和瓦片的纹理由程序生成并附着在实际三维模型表面；增加附棚、木构件、水车及不同建筑比例。

参考图片与原项目代码未作为游戏资源导入。本项目的造型与实现独立制作。

验证与当前限制：

- 规划/道路形状/相机投影 75 项、完整教程 151 项、农田周期 19 项、触控与座位 28 项、角色身份 26 项、用餐关节动画 2 项断言通过；生产链、施工活动、存档另行回归通过。
- 本地无界面验证器的总状态仍受宿主日志路径 `/home/agent/logs/lua` 无法打开影响，不能将其描述为运行器整体通过；上述结果取自 `test_result` 与断言报告。
- 旧存档保留原建筑占地，避免扩容覆盖既有道路；新尺寸适用于新规划的建筑。
- 当前三维模型的美术精度仍低于此前的手绘素材方案。已尝试 Maker 高质量三维建筑预览生成，但服务返回 `INSUFFICIENT_BALANCE`、`execution_state=not_executed`，未生成新资产，未自动重试。

后续 3D-03 更新：已使用本地 Blender 制作并导出原创建筑与人物网格，不再依赖余额受限的 Maker 三维生成任务。来源、重建流程、节点关节动画与质量范围见 [三维模型说明](../art-source/v3/README.md)。
