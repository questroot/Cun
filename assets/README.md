# 资源管理入口

此目录保存**登记信息**，不复制或搬走原型素材。现有实际文件仍在 `card-demo/assets/`。版本 1 图册是本地只读浏览器，维护操作通过 Python CLI；不是引擎运行时 AssetManager，也不支持在线多人编辑。

## 五分钟开始

需要 Python 3.10+，无第三方依赖。在仓库根目录运行（Windows 可把 `python` 换为 `py -3` 或 Python 可执行文件完整路径）：

```sh
python tools/assets.py scan card-demo/assets
python tools/assets.py check
python tools/assets.py catalog
```

双击打开 [catalog.html](catalog.html)：搜索名称、路径、标签、来源、许可；按分类和状态过滤；预览常见图片、打开原文件。模型和音频当前只有分类卡片和文件链接，不提供 3D / 音频内嵌预览。不需要服务器或联网。图册生成后不会自动更新，修改清单后再运行 `catalog`。

## 登记和维护

[registry.json](registry.json) 是团队唯一版本化清单。每项包含稳定 ID、仓库相对路径、名称、分类、标签、来源、许可、作者、状态、备注及 SHA256。

```sh
# 先从图册找资源 ID；以下 asset_ID 是占位符，不是实际 ID。
python tools/assets.py set asset_ID --name "主城背景" --tags "city,background" --author "作者名" --source "来源链接或团队原创说明" --license "实际许可或授权凭证位置" --status review
python tools/assets.py set asset_ID --status approved
python tools/assets.py refresh asset_ID
python tools/assets.py remove asset_ID
python tools/assets.py check --release
```

- `scan` 递归发现图片、音频、模型、字体和制作源文件；忽略 `.import` 等非素材文件。重复执行不覆盖已有元数据，也不默默接受内容变化。
- `set` 修改登记信息；tags 用逗号分隔。状态：`draft` 初稿、`review` 待审、`approved` 已核验、`deprecated` 弃用。手动批准代表操作者已核验，不是工具替你完成授权。
- `refresh` 在人工确认文件变化后更新指纹，状态退回 `review`；资源 ID 不变。
- `remove` 只移除登记，绝不删除原文件。再次扫描相同目录会重新登记；需长期保留历史的资源请改为 `deprecated`。
- 改名/迁移文件后，人工更新 JSON 中 `path`，保留 ID，再执行 `refresh`、`check`。不提供自动迁移与引用重写。
- `check` 检查清单字段、重复 ID/路径、越界路径、文件缺失、指纹变化；重复内容和未知来源给警告。
- `check --release` 额外要求**整个清单**都 approved 且来源/许可/作者非 unknown。它是保守的全库门禁，未来正式包确定后应创建只含发布素材的独立清单：`python tools/assets.py --manifest assets/release-registry.json check --release`。非空许可字符串不是法律判断，仍需人工核验。

## 来源与许可

第一次导入的原型素材统一为 `draft / unknown`，包括文件名看起来像 AI 生成的素材：文件名不能证明作者、模型条款或商用授权。补齐原始来源、生成工具及日期（如适用）、授权证明和改动说明，再由伙伴复核。

仓库公开不等于资源可商用或代码可自由再分发。正式项目的代码许可、素材许可与成员权利约定由团队决定，当前不自动添加 LICENSE。

## Git 与大文件

源文件和游戏导出文件分清；不提交导入缓存、临时图册以外的自动产物、密钥和本机引擎。超过 GitHub 单文件限制的内容不得直接推送。团队确定 Git LFS 后再追踪 PSD/BLEND/WAV 等大文件；**当前未启用 LFS**，不要只给部分伙伴加规则。二进制修改前在 Issue 留负责人，不同时编辑同一源文件。

清单 JSON 可合并但不适合多人同时批量格式化。资源 PR 附图册截图/预览、来源、许可、用途和是否被场景引用。图册 `catalog.html` 是忽略的本机产物；新克隆者执行生成命令即可。
