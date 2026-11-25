# Cun · 一起做游戏

Cun 是一群伙伴共同制作的独立游戏合集。各作品有自己的玩法、开发资料和试玩入口；团队共用基础工具，不要求共用世界观或存档。

## 选一个世界

| 游戏 | 一句话介绍 |
| --- | --- |
| [灵伴回合冒险](card-demo/games/spirit/README.md) | 从主城出发，带着灵伴编队，在九宫格上打回合战。 |
| [福地](card-demo/games/fudi/README.md) | 徒步穿行十域，调查见闻、采集、找装备并挑战守卫与首领。 |
| [海底水世界](card-demo/games/water/README.md) | 在海面经营浮台，在氧气耗尽前把水下收获安全带回来。 |
| [末班渡船](activities/last-ferry/README.md) | 以不同身份走进一处渡口，听故事、找线索，决定如何介入。 |

## Windows 上怎么玩

第一次来？从 GitHub 下载完整仓库并解压，然后双击根目录的 [Launch.cmd](Launch.cmd)；只下载启动脚本不能运行。用 Git 的话，可在 PowerShell 中运行：

```powershell
git clone https://github.com/questroot/Cun.git
cd Cun
.\Launch.cmd
```

默认入口是《山海行卷·竹影》：启动后直接进入独立的 Windows 游戏大厅，不打开浏览器。卷轴展开，点画中一境就在原窗口里开始游戏。游戏中「返回游戏选择」回到卷轴；「退出游戏」或关闭窗口则退出整个应用。无需 Python、Node 或联网。想手动选择引擎或打开编辑器，可双击 [Launch-Classic.cmd](Launch-Classic.cmd)；末班渡船仍可独立用 [Play.cmd](activities/last-ferry/Play.cmd) 启动。仓库随附可校验解压的 [Godot 4.7.2](.setup/Godot/README.md)，首次导入需要等待。已有本地改动的成员请先保留改动，再同步 `main`；环境准备与排障见[启动器说明](launcher/README.md)。

## 哪些文件需要读？

| 你来做什么 | 必读 | 按需查 |
| --- | --- | --- |
| 只想试玩 | 本页的启动步骤、所选作品的指南 | 遇到启动问题再看[启动器说明](launcher/README.md)，不用读开发日志。 |
| 加入开发 | 首次读[参与指南](CONTRIBUTING.md)；每次开工读[共享状态](PROJECT_STATUS.md)中当前阶段及相关条目、所改作品的指南 | 其他作品、架构和工具说明按任务查。 |
| 新增或整理文件 | [文件归位规则](docs/repository-layout.md) | [团队文档索引](docs/README.md)按主题查询；单款作品从自己的指南进入。 |
| 用 Agent 协作 | 除开发必读外，再读 [Agent 工作入口](AGENTS.md) | 仅查本次任务相关的规格和工具说明。 |

## 共用资源

- [既有共用 Godot 工程](card-demo/README.md) · [共享组件演示](shared/godot/atmosphere2d/README.md) · [资源管理](assets/README.md)。
- [参与指南](CONTRIBUTING.md) · [共享进度](PROJECT_STATUS.md) · [团队文档](docs/README.md) · [公共 AI 游玩工具](tools/play_mcp/README.md)。
- [改版前首页存档](https://github.com/questroot/Cun/blob/12e71cc81a328d3757db4ea1caa71ce6aa75ad4a/README.md)：保留原型说明、规则索引和旧链接，不代表当前功能状态。

仓库可访问不等于获得开源、商用或再分发授权；素材与作品权利以相应许可及团队确认结果为准。
