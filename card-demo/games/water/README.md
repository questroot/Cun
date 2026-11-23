# 海底水世界

在浮台经营补给，潜入浅滩、沉船和海沟搜寻资源；要在氧气耗尽前安全上浮，才能把本次收获带回浮台。

## 怎么玩

1. 使用公开 `main` 的仓库根 [Launch.cmd](../../../Launch.cmd)，选择「海底水世界」，从海面浮台开始。若看不到入口，核对是否在较旧分支，不要用旧版灵伴水门代替。
2. 在浮台完成准备，通过游戏内「下潜」进入水下。用 **WASD** 移动，靠近目标按 **E** 互动，**B** 查看网袋；以游戏内提示为准。
3. 留出返程氧气。关上网袋后，到安全光柱附近按 **E / Esc** 上浮结算。网袋打开时 **Esc** 先关网袋；氧气耗尽会触发救援，本潜的网袋收获和新核心不保留，不扣以前已入库的进度。在水下直接关游戏不算安全上浮；想带走收获，请先回浮台结算。

海上进度与灵伴回合进度分开保存。运行文件留在共用工程；此页只归拢水世界的玩法和开发资料。

**规则资料：** [V2 原始需求](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/%E6%B5%B7%E5%BA%95%E6%B0%B4%E4%B8%96%E7%95%8C-V2%E9%9C%80%E6%B1%82%E6%96%87%E6%A1%A3.md) · [V2.3 失败回滚变更](https://github.com/questroot/Cun/commit/c370bcfd8bfe7d007c93f73c68288656d729cf28)。后者更新了失败和正常中途退出时的资源点存量处理，不改变「本潜收获不入库」。原稿中的旧规则及候选不代表当前玩法。

[返回 Cun 游戏合集](../../../README.md)

**开发入口：** [Godot 工程](../../project.godot) · [海面场景](../../scenes/WaterActivity.tscn) · [共享状态](../../../PROJECT_STATUS.md)。

公开版的[下潜回归](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/tests/underwater.tests.ps1)在工程副本和独立存档里无头运行，检查下潜、上浮、救援和存档，不截图。[旧启动器冷启动回归](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/tests/launcher-cold.tests.ps1)的 `-Game Water` 会保存浮台和水下截图，不适用于无截图验收。这些回归不代替人工试玩。
