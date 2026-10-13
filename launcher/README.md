# Windows 游戏启动器

启动的是已有“灵伴回合冒险 MVP”，不是尚未实施的石化新游戏，也不是独立游戏安装包。

## 使用

1. 下载/克隆**完整仓库**，保留 `card-demo/` 和 `launcher/`；不要只下载一个脚本。
2. Windows 双击根 [Launch.cmd](../Launch.cmd)，进入原生桌面启动器。
3. 发现已有Godot则检测版本；完整仓库已包含 [4.7.2压缩包](../.setup/Godot/README.md)，没有已有引擎时会校验并解压到 `.local/godot/`，不联网。也可点“选择Godot”手动指定可信的Windows编辑器 `.exe`。
4. 环境就绪后点“启动游戏”。启动器先在后台执行Godot资源/脚本导入，完成且无错误后才打开游戏；界面会显示准备状态，首次需要等待。需要开发时点“在Godot编辑器打开”。

打开启动器只需要Windows自带 Windows PowerShell 5.1/.NET/WPF，不需要Python、Node或在线服务。当前仓库随附**Godot 4.7.2 Windows x64压缩包**，首次可自动校验解压；本次不联网下载安装、不导出独立游戏exe、不更改系统永久执行策略。

[项目配置](../card-demo/project.godot)声明Godot `4.7` 与 GL Compatibility。启动器接受同主版本且次版本不低于声明值；不能仅凭版本检测认定项目可运行，实际导入/脚本兼容还要检查。找不到引擎时启动按钮禁用，文档入口仍可用。

## 功能与本机文件

- 发现顺序：本机已记住路径、`GODOT_EXE` 环境变量、PATH中的godot/godot4，再检查仓库内约定引擎目录（.setup/Godot、Godot、Godot_v4.7.2、vendor/godot、tools/godot、.local/godot）。没有可用路径时尝试校验内置归档并解压本机缓存；不扫整台电脑。
- 通过 `--version` 验证输出，不符合/低版本/超时会显示原因。请选择你信任的可执行文件；本检测不是软件安全认证。
- 游戏启动前先执行 `--headless --path <仓库/card-demo> --editor --import`，生成贴图资源和脚本类型缓存；即使退出码0，只要输出含脚本/导入错误或缺缓存也会阻止启动并记录日志。之后游戏参数为 `--path <仓库/card-demo>`；编辑器额外 `--editor`。使用参数转义，支持空格与中文目录，不拼shell命令。
- 同一启动器一次运行一个受监督的游戏/编辑器，避免重复点击；进程退出后显示结果、记录stdout/stderr。关闭启动器不会杀游戏：有受监督进程时会要求先正常退出游戏/编辑器。
- “共享项目状态”“本机快照”“架构”“个人Agent材料”“讨论页”“日志”均有快捷入口。Markdown/日志用记事本打开，HTML用默认应用打开。
- 界面图片是仓库已有素材预览，**不是本次游戏实机截图**。

`.local/`为忽略目录：

| 文件 | 用途 |
| --- | --- |
| `launcher.settings.json` / `.bak` | 本机选择的引擎路径及上一次设置，不进入Git |
| `launcher.log` | 启动/退出和引擎输出；退出后查看详细错误 |
| `project-snapshot.md` | 打开/刷新/选择引擎时生成的本机快照 |
| `launcher-preview.png` | 仅界面检查时生成的WPF渲染证据 |
| `launcher-test-*` | 原生测试程序与临时项目，**不是游戏/引擎发行文件** |
| `godot/` | 内置归档校验后解压的本机引擎缓存，不重复提交裸exe |

快照只读项目配置与JSON数量，不写游戏存档，也不证明玩法通过。共享现状是根 [PROJECT_STATUS.md](../PROJECT_STATUS.md)，维护规则见 [AGENTS.md](../AGENTS.md) 和 [文档规划](../docs/documentation-plan.md)。没有常驻实时监听服务。

## 故障与边界

- 缺少项目/场景：重新获取完整仓库，不自动创建空场景掩盖错误。
- 版本不够：选择正确已有引擎；启动器不会降低项目声明或擅自升级。
- 设置损坏：本机设置忽略并记录原因，可重新选择；不会修改游戏存档。
- 灰色空窗且找不到BattleUnit或贴图：旧启动器遗漏首次导入。关闭旧游戏/启动器，更新后重新运行；无需删除存档，不要提交 `.godot/` 缓存。
- 导入失败：启动器会显示准备失败，不继续打开空白游戏；查看日志中的具体错误。准备最多等待3分钟，超时只结束本次导入进程。
- 启动后黑屏/退出/脚本错误：查看日志，记录引擎实际版本与复现步骤；创建进程成功不等于试玩成功。
- Windows安全/组织策略拦截：只运行可信来源文件，按组织策略处理；本程序不永久降低安全设置。`Launch.cmd`中的Bypass仅用于此次PowerShell进程。
- 不包含自动更新/登录/支付/补丁下载。它们不是当前需求，未来有必要另行设计。

## 开发与检查

```powershell
# JSON诊断；退出码0=仅环境版本就绪，2=引擎未就绪，1=启动器/项目错误。
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File launcher/Launcher.ps1 -Diagnose

# 原生参数、设置、失败路径测试（编译假的版本/参数夹具，不代表Godot实测）。
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/launcher.tests.ps1

# 真实冷启动检查：复制无缓存原型、隔离存档，经启动器导入再从实际主场景渲染截图。
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/launcher-cold.tests.ps1

# 构造真实WPF窗口并渲染本机截图，检查按钮状态和快照；不启动游戏。
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File launcher/Launcher.ps1 -SmokeTest
```

PS脚本保存为UTF-8 BOM，以兼容Windows PowerShell 5.1的中文解析。代码入口：[GUI](Launcher.ps1) / [核心帮助函数](Launcher.Core.ps1)。CI的Windows检查不会替代成员机器上的真实游戏试玩。
