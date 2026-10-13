# Cun

一个与伙伴共同打造游戏的工作空间。**正式游戏方向尚未确定，当前先搭建协作舞台，不提前锁定玩法、引擎或大型框架。**

已有 `card-demo` 是“灵伴回合冒险 MVP”Godot 原型，保留原样作为实验材料；它不自动代表项目最终方向。

## 启动当前原型

Windows 下载完整仓库后，双击 **[Launch.cmd](Launch.cmd)**。启动器会检测或让你选择已有Godot，并提供游戏/编辑器、文档、日志入口。无需Python即可打开启动器；仓库内置 [Godot 4.7.2压缩包](.setup/Godot/README.md)，首次可校验解压，无需联网下载。未打包独立游戏exe。详见 [启动器说明](launcher/README.md)。

启动器、内置Godot和文档均在默认主分支 `main`。首次获取：

```powershell
git clone https://github.com/questroot/Cun.git
cd Cun
.\Launch.cmd
```

已有仓库：先保留本地修改，再 `git switch main` 和 `git pull --ff-only`。无需切到历史功能分支。

## 每次工作先看这里

**[PROJECT_STATUS.md](PROJECT_STATUS.md)** 是共享现状入口：已做什么、实际验证、未验证、风险和下一步。成员/Agent先读它，工作结束核对并按事实更新；规则在 [AGENTS.md](AGENTS.md)，分工在 [文档维护规划](docs/documentation-plan.md)。

启动器打开/刷新会自动生成本机 `.local/project-snapshot.md`，不提交Git，也不是后台持续监控。正式新游戏方向仍未锁定。

## 第一次来，先做这三件事

1. 把 [完整Agent讨论材料](docs/design/agent-discussion-kit.md) 发给自己的Agent，按内置提示词梳理个人思路、自己看总结；无需统一填票或发回。
2. 新点子自愿分享后写进 [奇思妙想池](docs/design/ideas.md)；[问题总表](docs/design/questions.md)、[简短选择表](docs/design/ballot-round-1.md) 和 [脑图](docs/design/discussion-map.md) 是辅助，不是必交作业。
3. 再按需看 [参与指南](CONTRIBUTING.md)、[文档导航](docs/README.md) 和 [资源管理入口](assets/README.md)。当前先整理思路和问题，不急着认领新增玩法制作任务。

可直接转发给伙伴：[PNG脑图](share/cun-discussion-map.png) / [离线讨论与选择页](share/team-discussion.html)。离线页没有提交按钮，不会保存或上传回答，选择后请打印为PDF或按回复格式发回。

## 资源管理器：现在就能用

Python 3.10+，只用标准库，无需安装依赖。在仓库根目录运行：

```sh
python tools/assets.py check
python tools/assets.py catalog
```

然后双击打开 [资源图册](assets/catalog.html)（先生成，此文件不入 Git）。可以搜索、按分类/状态过滤、预览图片、打开文件。登记维护通过 [资源工具](tools/assets.py) 完成，操作示例见 [资源指南](assets/README.md)。

[资源清单](assets/registry.json) 已登记原型资源目录中的 36 项素材；全部初始标记 `draft / unknown`，**不推断已有素材的作者、许可或商用权限**。扫描新资源不会覆盖已登记的来源、标签或许可。

```sh
python tools/assets.py scan card-demo/assets
python tools/assets.py check --release
python -m unittest discover -s tests -v
```

普通检查允许未知许可但显示警告；发布检查会拦截未知来源和未批准条目，因此现有导入清单不会通过发布检查。这是工具门禁，不是法律授权证明。

## 舞台有哪些

| 入口 | 用途 |
| --- | --- |
| [架构边界](docs/architecture.md) | 规则/表现/内容/平台四个轻量职责；原型隔离；资源、数据、存档版本边界 |
| [团队指南](docs/team-guide.md) | 负责人、伙伴审核、小 PR、场景和二进制冲突、完成标准 |
| [路线图](docs/roadmap.md) | 方向探索 → 可玩闭环 → 纵切，按实际试玩推进 |
| [游戏简报](docs/templates/game-brief.md) / [实验](docs/templates/experiment.md) | 把想法变成低成本可验证实验 |
| [决策](docs/templates/decision.md) / [试玩](docs/templates/playtest.md) | 记住选择理由、实际观察和下一步 |
| [资源管理](assets/README.md) | 清单维护、来源许可、指纹校验、只读图册 |
| [基础自动检查](.github/workflows/foundation.yml) | 工具回归测试、资源检查、图册生成；推送后才会在 GitHub 执行 |
| [PR 模板](.github/pull_request_template.md) | 目标、实际验证、风险与回退 |

GitHub 的新 Issue 提供“想法或实验 / 制作任务 / 问题反馈”三个入口，不要求先建复杂看板。推荐 `main` 保持可理解、可验证；短分支 + 小 PR，由伙伴检查再合并。强制审核和分支保护须仓库维护者在 GitHub 设置，模板不会自动配置它们。

## 目录约定

```text
Launch.cmd   Windows可双击入口
launcher/    WPF启动器、核心函数和说明
AGENTS.md    成员/Agent工作入口规则
PROJECT_STATUS.md 共享现状，每轮核对维护
card-demo/   现有独立原型，不在本次底座搭建中改动
assets/      跨原型的资源登记信息和本机生成图册，不复制素材
docs/        架构、团队约定、路线图与四个短模板
tools/       资源/文档检查工具；讨论PNG导出另需Pillow
share/       自包含的讨论页和转发脑图
tests/       工具回归测试（不是游戏实机验收）
.github/     Issue、PR 模板与基础 CI
```

正式工程目录在方向与引擎确定后再建。现在不创建空游戏框架、联网、ECS、插件系统或全局事件总线。

## 想跑已有原型

可以通过 [Windows启动器](Launch.cmd)，或用兼容的 Godot 编辑器导入 [原型配置](card-demo/project.godot)。配置声明 `4.7`、`GL Compatibility`，入口是 `MainCity.tscn`。**配置声明不是运行验证**；本次启动器核心和WPF界面已检查；使用用户提供的Godot 4.7.2，隔离副本导入、入口启动与真实主城窗口检查通过，原有回归有1项战斗反馈断言失败，不能称完整试玩通过。没有升级引擎或修改原型场景。实际状态见 [共享现状](PROJECT_STATUS.md)。

## 接下来建议做什么

当前各自把完整材料交给自己的Agent，先整理问题、候选与个人偏好，自己看总结；无需集中填票或回收。个人愿意分享时再交流，个人结论和Agent建议都不是团队定案。后续明确选择路线再谈实验与制作，不因已有素材和模块被迫选某种游戏。

项目代码许可、素材权利、成员署名/作品归属与发布方式仍待团队确认。仓库公开不等于已授予开源、商用或再分发许可，当前不擅自添加 LICENSE。
