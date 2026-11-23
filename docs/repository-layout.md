# Cun · 项目归位与文件管理

先按归属找文件，再按用途决定是否移动。各成员维护自己的作品；[首页的必读清单](../README.md#哪些文件需要读)是阅读入口，下面是文件放置规则。

| 类别 | 位置和归属 |
| --- | --- |
| 根目录入口 | [首页](../README.md)面向访客；[参与指南](../CONTRIBUTING.md)是协作入口；[Agent 规则](../AGENTS.md)供使用 Agent 时阅读；[共享状态](../PROJECT_STATUS.md)只记结论和证据入口。保留 Windows 的 [Launch.cmd](../Launch.cmd) 与 Git/CI 配置。 |
| 独立作品 | `activities/<作品 ID>/`：作品 README、工程、运行素材、策划与复现资料随作品走，例如[末班渡船](../activities/last-ferry/README.md)。 |
| 仍共用工程的作品 | [既有共用工程](../card-demo/README.md)承载灵伴、福地和水世界。新增的作品说明归 `card-demo/games/<作品 ID>/`；现有代码和运行资源维持原路径。 |
| 公共工具和资产 | `launcher/` 放启动器；`tools/` 放跨作品工具，`tests/` 放仓库级回归，`skills/` 放项目共享技能。`shared/` 放复用组件；[资源登记](../assets/README.md)记录素材来源和使用位置，不为归档重复复制运行素材。 |
| 团队资料与对外分享 | [文档索引](README.md)收录规范、架构和按需资料；`docs/design/` 放共享设计与历史候选，`share/` 放供团队分发的页面。单款作品的资料从其 README 进入。 |
| 研发产物 | 已登记、有复现用途的源稿和生成批次先保留；缓存、临时输出、日志、截图和测试存档留 `.local/`，不提交。 |

本批先整理首页、必读索引和作品说明，不搬运行文件，也不把镜中大厅代码或玩法测试带进文档提交。下方待归位项不是本批已完成的迁移。

## 成员接入作品

给出稳定作品 ID、显示名、作品 README、预览图及现有启动目标。改自己的项目，不顺手动其他作品，也不要在大厅里复制游戏脚本或移植存档。由公共入口维护者核对入口后接入。

## 旧文件分批归位

先核对 Git 差异与依赖清单；识别哪些是运行资源、制作源稿、可再生成输出或临时文件。只移动已和负责人核对的文件；同步修正 README 链接、登记清单、复现工具和测试，不改变 Godot 的原有工程标识或玩家数据。对于根目录的历史说明，先为作品建立导航，再迁正文并保留旧路径指引。未经核实的临时文件、旧工具和生成输出不批量删除，也不改写历史。

### 首批待归位项

根据 [GitHub `main` 的根目录清单（940cade）](https://api.github.com/repos/questroot/Cun/git/trees/ddcd1944e876418d61710567a425142be98e989e) 核对：

| 根目录现有内容 | 归位方向 | 迁移前要确认 |
| --- | --- | --- |
| [海底水世界 V2 需求](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/%E6%B5%B7%E5%BA%95%E6%B0%B4%E4%B8%96%E7%95%8C-V2%E9%9C%80%E6%B1%82%E6%96%87%E6%A1%A3.md) | 随[水世界文档](../card-demo/games/water/README.md)归位，旧路径留入口 | 和负责人一起更新规则引用，保留原文及标题锚点 |
| [美术](https://github.com/questroot/Cun/tree/940cadef814fa68b690d620e0e5e381bc11ae59b/%E7%BE%8E%E6%9C%AF)、[生成输出](https://github.com/questroot/Cun/tree/940cadef814fa68b690d620e0e5e381bc11ae59b/output) | 单作源稿随作品；确属共用的登记到资源清单；纯临时品留本地 | 福地已有明确的制作批次候选，见下文；根美术另有动作、怪物、武器、物品四类，逐类核对。不能把输出一律当可删除缓存 |
| [hello.py](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/hello.py)、[.tmp-python.txt](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/.tmp-python.txt) | 从根目录退场的候选 | 公开 `hello.py` 只输出问候，提交 [df9cf5e](https://github.com/questroot/Cun/commit/df9cf5e914d6e4cbcd59bd11c0a91ed7f69fdcd8) 明确是连通测试；`.tmp-python.txt` 为 0 字节，最后一次触及为 [d1c72b6](https://github.com/questroot/Cun/commit/d1c72b6b22455b42fe7a14161afda07197c05786)。先在最新 `main` 核对脚本、CI、文档引用，单列清理提交，不和作品资源迁移混合 |

### 福地源稿

[福地精细素材批次](https://github.com/questroot/Cun/tree/940cadef814fa68b690d620e0e5e381bc11ae59b/output/imagegen/fudi-fine)包含地图、建筑、宝箱、药材等原图，以及提示词、队列、图廊、缩略图和衍生版本。它们是一组制作材料，不按图片扩展名拆开；候选归位为 `card-demo/games/fudi/art-source/fudi-fine/`。公开 `main` `12e71cc` 新增高清场景资产，仍从该批次选图；迁移必须同时核对图廊、队列、[生成脚本](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/tools/prepare_fudi_fine_materials.py)、[运行素材清单](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/card-demo/assets/fudi/fine/manifest.json)和资源登记。保持运行资产路径与 SHA-256 不变；负责人复核前不迁。

根美术中的 [H01.png](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/%E7%BE%8E%E6%9C%AF/%E6%80%AA%E7%89%A9boss/H01.png) 与 [w01-ashen-echo.png](https://github.com/questroot/Cun/blob/940cadef814fa68b690d620e0e5e381bc11ae59b/%E7%BE%8E%E6%9C%AF/%E6%AD%A6%E5%99%A8/w01-ashen-echo.png) 在本分支能对应到[首领表](../card-demo/scripts/scenes/boss_catalog.gd)和[掉落表](../card-demo/scripts/scenes/loot_catalog.gd)，运行脚本引用的是工程内资源，不是这些根文件。这是运行路径的样本，不是重复文件或删除依据。

| 根美术分组 | 已确认用途 | 随迁移一起处理 |
| --- | --- | --- |
| `物品/`、`武器/` | 福地的 15 件套装与 5 把武器原图；[图标生成器](../tools/prepare_loot_icons.py#L13-L23)从这两处读取，并向工程内写入 20 个运行图标。 | 修改生成器读取路径、[图标重建说明](../card-demo/assets/items/README.md)和[掉落文档](fudi-loot.md)，更新[资源登记](../assets/registry.json)的来源字段；对比重建前后的运行图标，不改运行目标。 |
| `怪物boss/` | 福地首领的六张在用原图，外加历史版 `H01.old.png`；[首领文档](fudi-bosses.md)记录了原图与引擎内副本的关系。 | 保留历史图，更新首领文档与资源来源记录；不动 `res://assets/characters/bosses/`。 |
| `动作/` | [公开基线的目录树](https://api.github.com/repos/questroot/Cun/git/trees/b5c5888019c1ddbc02d751762c7e7a18a08f64fa)有 11 张 PNG：一张基础姿势和五组武器动作图；[该目录唯一可查的提交](https://github.com/questroot/Cun/commit/24810ab209a2ce319cd45d2df66615d71c66fe6d)属于福地战斗改进。本地工程、文档和资源登记未找到代表文件名的直接引用，这不足以判定未使用。 | 找福地负责人核对源稿归属、复现工具和间接引用；确认前留原位，不删除或随大厅移动。 |

先在最新版用 Git 查引用和资源指纹，再按原图批次迁移到 `card-demo/games/fudi/art-source/`。迁移时核对源稿文件名、生成器、登记清单与 Godot 引用，比较迁移前后的运行素材指纹和重建结果。负责人复核前留在原位。

以上是公开目录盘点与归位建议，不表示文件已迁移。

## 首批文档交付

- 从最新 `origin/main` 建独立候选，不切换、不清理正在生产的工作树。候选只纳入首页、本文、团队文档索引、参与指南、共用工程索引和四款作品指南。对已存在的文件，以上游为底稿增补，保留伙伴新增链接和正文。
- 渡船只把「第一次试玩」和首页返回链接补到上游，不复制当前工作分支的章节进度；福地、水世界和灵伴仅整理指南，不改变旧启动路径。首页及各指南不链接尚未发布的镜中大厅文件。
- 提交前检查相对链接、必读分类和暂存路径；至少一位伙伴复核后再合入。启动器代码、作品工程、存档、运行素材、历史源稿和本机产物都不进入这批提交。负责人的旧文件迁移另列，先核引用再动。
