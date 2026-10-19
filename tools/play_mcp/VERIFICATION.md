# 验证记录（2026-10-19）

执行环境：Python 3.14（DSH内置），Godot `4.7.2.stable.official.ed1daf0bf`。以下是执行证据，不是协调者验收/用户验收，也不是完整游戏通关。

## 追加合同验证

- 新增受信任固定group `cun_play_visible` / `play_visible()`到 observation.visible，无任意调用入口；真实夹具已观察到屏幕描述。
- `cun_play_blocked`祖先继承、按钮disabled/blocked标记、click拒绝、坐标mouse拒绝已真实夹具通过。键盘面板/焦点防绕过实现，尚未专门断言焦点/面板路径。
- 实际Input.parse_input_event同时填keycode/physical_keycode，真实引擎夹具的 `Input.is_physical_key_pressed(KEY_W)` 按住6帧期间计数1..7并在返回观察时已释放，断言通过；非仅凭工具成功响应。
- 新夹具证据 `.runtime/bridge-35facccc42cf4c36b748ad80a38a411c/engine.log`；新增合同仍须协调者复制bridge到项目后复测最终集成。

## 协调者独立复核

- 已复制最终公共桥到原型，实际玩家输入验证：主城屏幕玩家x从334移动到390.25，y不变；依据可见描述确认角色确实移动，不只看按键回执。GM click被拒绝，原型自身也在AI模式拒绝打开GM。
- 最终协议5组、HTTP代理边界、真实引擎桥夹具（含可见描述、GM点击/坐标阻止、物理按键按住并释放）协调者独立复跑通过。
- 最终接入前的headless与窗口集成均通过；日志位于本地忽略目录。旧玩法隔离GM29项及smoke386项通过，有既有windup9021警告。
- 监督器原实现attempt有失败且因多条消息归属不清，未记原attempt为PASS；产物内容与协调者独立验证分开记录，不覆盖历史。

## 已通过

- `test_mcp.py` 5组测试全部通过：initialize 两版本/未知版本协商、initialized 通知门禁、tools/list、tools/call、真实stdio子进程、中文UTF-8 stdout、错误JSON、64KiB长度限制、未知方法、目录白名单、额外字段与输入边界。
- `test_http.py`：非标准MCP便利代理真实loopback服务 catalog / token拒绝 / 路径拒绝通过。
- `test_bridge.py`：真实Godot最小UI夹具通过：隐藏Label与隐藏父节点按钮排除、visible_characters尚未显示文本不暴露、鉴权、禁eval、帧数边界、不可见按钮、实际鼠标InputEvent经viewport输入改变Label、超长请求关闭、未配置token不监听。最终夹具证据 `.runtime/bridge-45126b222589481588c16fea2085dcf5/engine.log`。
- `test_engine.py`：已由协调者接入的card-demo，在真实Godot headless完成隔离副本导入→启动→观察可见UI→实际点击普通背包按钮（MainCity场景不变、UI文本变化）→Escape按键2帧→鉴权/重复启动/无效按钮拒绝→user://独立UUID目录核验→源工程内容hash不变→停止/重复停止。证据 `.runtime/c610e0b8f2f443d0bf48433da44a66d3/evidence.json`。
- `test_engine.py --render`：同闭环真实OpenGL窗口通过，未使用桌面捕获。证据 `.runtime/5c04bbd1b1d746f895c67a2bb39d42d9/evidence.json`。未以此宣称人工画面检查、音频体验或完整玩法已验收。

## 失败调查与修正

- 初始真实stdio输出中文受Windows默认代码页影响：已显式UTF-8，回归通过。
- 首次card-demo启动时协调者正接入Autoload，脚本尚未复制：明确File not found并失败，未计成功；增加缺脚本快速拒绝。该失败自有进程已停止。
- headless初始viewport只有64x64导致输入无效：桥按工程配置设置headless content scale size，鼠标经viewport.push_input(event,true)使用本地坐标；真实夹具按钮实际改变文本后才计通过。不直接调用button.pressed或任何管理器。
- 超长包Windows会ConnectionReset而非EOF：测试接受两种连接关闭结果。
- 初次无监听测试Windows connect以Timeout而非ConnectionRefused结束：两种都属未连接成功。

## 隔离的明确边界与未验证

- Windows Godot user://使用known-folder API，设置APPDATA环境不能改到tools目录；custom_user_dir_name绝对路径也会被净化为相对目录。最终使用 `%APPDATA%/CunPlay/<随机uuid>`；不会读写原玩家user://。源码交付/副本/日志只在tools/play_mcp，但游戏运行独立存档有这一明确目录外副作用；已通知协调者，未隐瞒/假称全路径限制。绝对路径试验曾产生独立 `%APPDATA%/E-/games-cun/tools/play_mcp/.runtime/<uuid>/user`，未清理以避免擅自操作外目录。
- 工具不是操作系统沙箱，不允许任意游戏路径，但白名单游戏代码本身仍具有本机用户权限；不应运行不可信游戏代码。
- 最终桥后补响应长度上限、visible_characters过滤，已真实夹具验证；协调者需复制最终bridge至工程后重跑完整card-demo以核对最终字节版本。
- 未验证第三方MCP客户端实际配置、长时间负载、其他OS、人工图像/音频/玩法体验、末班渡船接入；未提交/推送Git、未改宿主配置。
- bridge观察仅UI树可见性，非像素OCR；重叠遮挡/滚动裁剪存在语义局限，文档明确，不读取隐藏状态/线索。所有测试自有进程均已停止；证据不应提交。
