# Cun AI play MCP

Python 标准库实现，默认使用 **标准 MCP stdio（逐行 UTF-8 JSON-RPC 2.0）**。支持 `2024-11-05`、`2025-03-26` 版本协商；标准客户端启动 `python tools/play_mcp/server.py`，依次 `initialize` → `notifications/initialized` → `tools/list` / `tools/call`。stdout 仅协议；诊断 stderr，游戏输出进自有日志。

## 工具合同

| 名称 | 参数 | 结果 |
| --- | --- | --- |
| `catalog` | `{}` | 白名单入口列表，本分支为 `card-demo` 与 `last-ferry` |
| `launch` | `{"project":"card-demo","headless":false}` | 自有 PID、隔离运行目录、初始 observation |
| `observe` | `{}` | 标题、当前场景名、可见 Label/RichTextLabel 文本、可见按钮（id/text/disabled/rect）、viewport |
| `action` | `{"kind":"click","button_id":"…"}` | 实际鼠标输入后 observation；按钮必须仍可见且启用 |
| `action` | `{"kind":"key","key":"enter","frames":2}` | 实际 InputEventKey 按住 1–120 帧后释放 |
| `action` | `{"kind":"mouse","x":100,"y":200,"button":"left","frames":1}` | viewport 范围内实际鼠标输入，left/right/wheel_up/wheel_down；滚轮一次一格，可逐次观察后继续 |
| `stop` | `{}` | 仅结束当前服务器创建的游戏子进程；重复调用安全 |

键白名单：up/down/left/right/enter/escape/space/tab/w/a/s/d/e/j/k/l/i/m/b/c/1/2/3/4。工具输入额外字段拒绝；无路径、脚本、eval、GM、任意文件或隐藏状态接口。按钮 id 是当前存活 UI 节点的临时不透明 id，不跨启动保存。点击走真实 Godot 输入和 UI 命中检测，不直接 emit pressed，因此被遮挡按钮不会绕过上层 UI。observe 过滤 visible_in_tree、viewport 范围，并按 visible_characters 截断尚未打字显示的内容；它是 UI 树可见性而非像素OCR，不能证明文本未被其他窗口/控件遮挡或滚动容器精确裁切。标签可能由游戏自身写出内部信息，内容责任仍属游戏 UI；桥不扫描任意属性。

成功 action 的 observation 额外包含 `input_timing`：`held_process_frames` 是桥按请求等待的处理帧数，`held_wall_ms` 是事件按下之后至释放之前的实际墙钟毫秒（不含鼠标预移动及释放后的观察等待）。不是固定物理步长，也不保证位移；卡顿、相机跟随和游戏自身时钟应分别诊断。该字段不暂停模型思考期间的游戏，不代表实时闪避/战斗能力已验证。

RichText观察仅包含当前滚动窗口与祖先裁剪内的完整布局行，边缘残行暂省略；不再输出整篇前4096字。未完成排版、table/img等复杂富文本保守省略，需要专用可见provider；不承诺所有自定义文本效果。滚轮是实际鼠标事件，不是直接设置滚动值。


## 项目可见绘制物与玩家权限

对 Node2D `_draw` 等非Control内容，项目可将 **CanvasItem** 加入固定 group `cun_play_visible` 并实现无参数 `play_visible()`，返回 String/Dictionary/Array；observe 的 `visible` 数组收集这些结果（最多32项、每项8192字符，受总响应64KiB限制）。仅调用该固定方法，不允许调用方选任意对象/方法或传参数。项目实现须只返回当前屏幕可见描述/目标与坐标，不含隐藏剧情、内部状态或未来线索；visible_in_tree仅是可见前提，视野/遮挡由项目provider负责过滤。

节点 metadata `cun_play_blocked=true` 沿父节点继承：按钮保留可见提示并返回 `blocked:true,disabled:true`；click拒绝。坐标鼠标若落入可见标记Control子树拒绝；标记面板存在或标记按钮获焦时，键输入保守拒绝，防止绕过玩家GM禁用。普通可见GM按钮不会因为可见而自动获准操作。

按键同时设置 keycode/physical_keycode，真实夹具已验证 `Input.is_physical_key_pressed(KEY_W)` 在6帧按住期间成立、结束后释放；不是仅检查响应成功。

## Godot 接入

将 `bridge.gd` 复制至目标 Godot 项目 `scripts/ai_play_bridge.gd`，增加 Autoload：

```ini
AIPlayBridge="*res://scripts/ai_play_bridge.gd"
```

不使用 `class_name`，不调用游戏管理器。只在以下环境变量有效时监听：

- `CUN_PLAY_PORT`：1–65535，绑定固定 `127.0.0.1`。
- `CUN_PLAY_TOKEN`：至少 32 字符；服务器每次启动生成随机 64 字符 token。

桥协议是私有 loopback JSON Lines，**不是 MCP**：请求 `{"token":"…","method":"observe|action","params":{…}}`，响应 `{"ok":true,"result":{…}}` 或 `{"ok":false,"error":"…"}`。一次 TCP 连接一条请求，64KiB 上限，最多4连接，空闲连接8秒关闭，客户端6秒超时。bridge 未配置不监听。游戏卡顿超时是失败，不被认作动作成功。

launch 只允许仓库固定 card-demo 和固定 `.local/godot/Godot_v4.7.2-stable_win64_console.exe`；复制到本目录 `.runtime/<uuid>/project` 后导入再启动，不运行源工程，不读取原玩家存档。副本 override 指定唯一 custom user dir `CunPlay/<uuid>`，环境同时设置独立 APPDATA/LOCALAPPDATA/XDG/HOME/USERPROFILE；但 **Windows Godot 的 user:// 使用系统 known-folder API，实测仍位于 `%APPDATA%/CunPlay/<uuid>`，不会被环境变量重定向到工具目录**，不读取原玩家存档。绝对 custom dir 也被Godot净化为相对路径，不能借此重定向。日志和副本留在 `.runtime`（gitignore）；运行时的独立 user:// 存档目录是明确的目录外副作用，不属于仓库交付文件。不自动删除证据。服务器退出/stdio EOF 会清理自有游戏，stop 不枚举/终止其他用户进程。该工具不是 OS 沙箱：被白名单游戏自身具有当前用户原有权限，因此只应运行仓库受信任代码，不是执行不可信游戏的安全容器。

默认 launch 创建普通游戏窗口，可用 `headless:true` 做非渲染回归。不使用桌面捕获，未实现截图工具，不产生捕获边框闪烁。headless 的真实引擎执行并非图像/体验验收。

## 现有 Agent 的 HTTP 便利代理（非标准 MCP 传输）

可选 `python tools/play_mcp/server.py --http-port 8765`，环境须配置 `CUN_PLAY_HTTP_TOKEN` 至少32字符。仅绑定127.0.0.1，`POST /tool`，`Authorization: Bearer <token>`，body `{"name":"catalog","arguments":{}}`。同一 PlayService 处理器；不是 MCP Streamable HTTP / SSE，不能作为标准 MCP HTTP URL 填入客户端。

```powershell
# 使用同一个随机值配置代理和调用方；不要将值提交到仓库。
$env:CUN_PLAY_HTTP_TOKEN = '<至少32字符随机秘密>'
python tools/play_mcp/server.py --http-port 8765
# 另一个继承同token的终端：
python tools/play_mcp/client.py catalog
python tools/play_mcp/client.py launch '{"project":"card-demo","headless":true}'
python tools/play_mcp/client.py observe
python tools/play_mcp/client.py stop
```

## 验证

- `python tools/play_mcp/test_mcp.py`：标准握手/通知/工具列表/工具调用、真实 stdio 子进程、UTF-8、坏消息/长度限制、白名单和输入边界。
- `python tools/play_mcp/test_bridge.py`：真实Godot最小UI夹具8组安全断言（隐藏文本/按钮、token、eval、帧边界、不可见按钮、实际点击、超长包、未配置不监听），不冒充card-demo完整游戏。
- `python tools/play_mcp/test_http.py`：非MCP HTTP代理catalog/鉴权/路径拒绝。
- `python tools/play_mcp/test_engine.py`：需已接入 Autoload；真实Godot隔离启动、观察、点击普通背包/编队按钮并断言场景/UI变化、键按住、token拒绝、不可见按钮拒绝、重复启动拒绝、user://唯一目录核验、原工程内容哈希不变、停止/重复停止；证据留 `.runtime/*/evidence.json`。
- 加 `--render` 使用真实窗口，不截图；不等于人工画面或完整通关验收。

本机 Python/Godot 路径仅运行配置，不提交二进制；本工具不改宿主配置、不提交/推送Git、不自动接入未来末班渡船内容。
