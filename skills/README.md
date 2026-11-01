# 团队 Agent 技能合集（第三方，随仓库分发）

本目录存放团队共用的 AI 编码 Agent 技能（Agent Skills）合集，供各成员自己的 Agent 按需加载。
**它是只读参考资料，不属于游戏工程**：不改动 `card-demo/` 代码、引擎版本、玩家存档或美术素材，也不代表这些技能已在本项目验证过。

## 收录内容

- 目录：[awesome-gamedev-agent-skills](awesome-gamedev-agent-skills/)
- 来源：上游仓库 `gamedev-skills/awesome-gamedev-agent-skills`（跨引擎游戏开发技能集，含 77 个 skill + 1 个 router）
- 许可：Apache License 2.0，Copyright 2026 Abhishek Barali and the awesome-gamedev-agent-skills contributors；
  全文见 [LICENSE](awesome-gamedev-agent-skills/LICENSE)、[NOTICE](awesome-gamedev-agent-skills/NOTICE)。本目录保留原许可文件，再分发时不得删除。

副本保持上游原貌：未改写任何上游文件，未复制上游 `.git` 与本机缓存。文件数与上游一致（251 个文件，约 3.5 MB）。

## 目录速览

| 位置 | 内容 |
|------|------|
| [`awesome-gamedev-agent-skills/router/`](awesome-gamedev-agent-skills/router/SKILL.md) | 路由技能：按项目文件判断引擎，再按任务加载对应技能 |
| `.../skills/godot/` | Godot：GDScript、节点场景、信号、移动、TileMap、物理、UI、动画、着色器、资源、音频、多人、导出、C#、headless 测试 |
| `.../skills/unity/`、`.../unreal/`、`.../ebitengine/` | 对应引擎的基础与专题技能 |
| `.../skills/web-engines/`、`.../other-engines/` | Phaser/PixiJS/three.js；Bevy、pygame-ce、LÖVE、Defold、Roblox |
| `.../skills/disciplines/`、`.../genres/`、`.../workflows/` | 跨引擎通用手艺（美术生产、AI、物理、音频、着色器、存档等）、类型玩法、原型/发布流程 |
| `.../docs/`、`.../templates/`、`.../scripts/`、`.../tests/` | 上游的格式说明、安装说明、技能模板、校验与测试脚本 |

每个技能是含 `SKILL.md` 的文件夹，文件夹名必须等于其 frontmatter 的 `name`。技能使用方式见上游
[README](awesome-gamedev-agent-skills/README.md) 与 [安装说明](awesome-gamedev-agent-skills/docs/INSTALLATION.md)。

## 怎么用

1. **就地读取（推荐，无需安装）**：让 Agent 先读
   [`router/SKILL.md`](awesome-gamedev-agent-skills/router/SKILL.md)，由它判断引擎与任务，再只加载相关的
   `SKILL.md`。现有原型的 `project.godot` 会被识别为 Godot。
2. **装进自己的 Agent**：按上游说明安装到个人环境（`npx skills add …` 或 Claude Code 插件），
   装的是上游最新版，可能比本副本新；装完的副本不进仓库。

引擎版本基线以技能内声明的为准（当前声明 Godot 4.7 / 4.7.2，与本仓库 `card-demo/project.godot` 的 4.7 标记一致）。
技能内容只作建议，引擎和版本仍以本项目实际配置、真实运行结果为准。

## 校验与更新

- 校验（可选，本地手动执行）：`python skills/awesome-gamedev-agent-skills/scripts/validate-skills.py`，
  当前结果：78 个 skill 文件与仓库接线全部通过。
- 该校验不加入项目 CI（`.github/workflows/foundation.yml`），避免为本项目的工具链引入上游依赖与门禁。
- 更新方式：整目录替换为上游新版本 → 重跑上面的校验 → 在提交说明里写清上游版本/日期与差异范围。
  不要在本副本里直接改上游文件，否则下次同步会冲突。

## 许可边界

本子目录按上游 Apache-2.0 分发，这只覆盖技能合集本身。**仓库其余部分仍无 LICENSE**，
不能据此推断游戏代码、美术、音频或策划文档获得开源或商用授权；详见[团队指南的授权边界](../docs/team-guide.md#授权边界)。
