# 福地

在十域之间徒步探索：调查当地见闻、采集资源、搜寻装备，与守卫和首领交手。福地是独立的动作试玩，不要求先完成灵伴的回合关卡。

## 怎么玩

- 从仓库根 [Launch.cmd](../../../Launch.cmd) 选择「福地」，或从旧游戏选择大厅进入。
- **WASD** 移动，**J / K / L** 攻击，**E** 调查或互动。
- **M** 开地图，**B** 看行囊和见闻，**C** 查看与穿戴装备，**Esc** 打开菜单。
- 在公开 `main` `12e71cc`，福地有独立存档，下次可继续；Esc 菜单可手动保存或确认重新开始。旧分支不一定具备此功能。参见[继续探索与祝婶委托](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/docs/fudi-progress.md)。
- 同一公开版本中，按 **B → 委托** 可追踪一个目标，按 **M** 看标记；在 **B → 物品** 可制作回血补给。普通守卫出招前有预警，先离开黄圈或冲锋直道。详见[守卫、追踪与补给](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/docs/fudi-refinements.md)。

## 玩法与制作资料

- **探索：** [十域地图](../../../docs/fudi-maps.md) · [天气与生态](../../../docs/weather-system.md) · [建筑](../../../docs/fudi-buildings.md) · [地图陷阱历史规则](../../../docs/map-traps.md)。旧版首页的快照标记陷阱停用，不把规则文档当作当前已开启的承诺。
- **战斗：** [首领](../../../docs/fudi-bosses.md) · [掉落](../../../docs/fudi-loot.md) · [宝箱](../../../docs/fudi-chests.md) · [装备、套装与融合](../../../docs/fudi-equipment.md)。
- **制作：** [音频来源与复现](../../../docs/fudi-audio.md) · [公开版本的 NPC 交流与商品](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/docs/fudi-npc-exchange.md) · [公开版本的地图美术与导航](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/card-demo/assets/backgrounds/fudi/README.md) · [公开版本的细绘建筑、植被、宝箱与药材](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/card-demo/assets/fudi/fine/README.md)。

地图与道具的[福地精细素材源稿批次](https://github.com/questroot/Cun/tree/940cadef814fa68b690d620e0e5e381bc11ae59b/output/imagegen/fudi-fine)暂留历史路径；不要把源稿和 Godot 正在加载的资源混着移动。归位范围见[仓库说明](../../../docs/repository-layout.md#福地源稿)。

功能启用状态以当前版本实际界面和[共享状态](../../../PROJECT_STATUS.md)为准。

[返回 Cun 游戏合集](../../../README.md)

**开发入口：** [Godot 工程](../../project.godot) · [福地场景](../../scenes/Fudi.tscn) · [隔离探索测试](../../../tests/exploration.tests.ps1) · [公开版福地存档回归](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/tests/fudi-progress.tests.ps1)。存档回归默认无头运行，在工程副本和独立用户目录中检查正常关闭与继续。
