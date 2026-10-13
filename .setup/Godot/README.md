# 随仓库提供的 Godot 4.7.2（Windows x64）

用户明确要求在仓库中提供该引擎。实际执行版本输出为 `4.7.2.stable.official.ed1daf0bf`，与当前原型声明的4.7匹配。

## 分发形式

- [gui.zip](gui.zip)：用户提供的原始压缩包，86,013,866字节（约82MiB），未修改归档内容。
- [manifest.json](manifest.json)：归档及其中两个exe的SHA256/大小清单，来自本次对原包与已解压文件的逐项核对。**这是完整性校验，不是官方签名或发行来源认证。**
- 裸主程序180,858,888字节，超过GitHub普通单文件100MiB限制，因此不提交裸exe。
- 控制台exe为配套入口，包含在同一压缩包内；不另重复提交。
- 同时保留 [Godot MIT许可证](LICENSE.txt) 与 [第三方版权/许可证声明](COPYRIGHT.txt)，取得自对应 `4.7.2-stable` 源码标签。

## 启动

完整获取仓库后双击根 [Launch.cmd](../../Launch.cmd)。启动器先找已选/已有引擎；没有时校验内置归档与文件白名单，将两个exe解压到忽略目录 `.local/godot/` 再检测版本，不联网下载。

首次解压需要本机磁盘空间与写权限。归档缺失、损坏、清单不符或越界条目会阻止自动解压/运行，并允许手动选择可信Godot。已有不符的缓存不会自动覆盖。

用户本机 `.setup/Godot/` 中已经解压的exe也能被发现，它们仍是忽略文件；仓库克隆只有压缩包、清单和说明/许可。不要为了方便把裸exe强制加入Git。

此包只用于Windows x64；启动器不是跨平台安装器。若之后频繁升级大文件，应评估GitHub Releases或Git LFS的成本与权限，避免在Git历史中不断堆积引擎版本；本次按用户要求上传现有压缩包。

## 许可证与来源

Godot可以在MIT条件下再分发；这**不改变Cun项目代码或美术的许可**，更不证明游戏素材可商用。

- [Godot官方许可说明](https://godotengine.org/license/)
- [4.7.2-stable LICENSE.txt来源](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/LICENSE.txt)
- [4.7.2-stable COPYRIGHT.txt来源](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/COPYRIGHT.txt)

原包、内嵌引擎版权信息和上述声明均保留。不要把校验清单当作安全认证，运行任何exe前仍须信任来源。
