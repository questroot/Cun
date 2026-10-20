# 福地九张场景成图

2026-10-20按用户要求，将已生成的前九张地图用于实际福地场景和小地图。原图来自已有图像网关 `gpt-image-2`，1536×1024；不再次生成或重绘。原始PNG、提示词及检查队列保留在仓库工作区 `output/imagegen/fudi-fine/`，运行目录仅放无损WebP。

| 运行资源 | 原始文件 | 区域 |
| --- | --- | --- |
| grove.webp | 01_maps_grove.png | 青岚灶街 |
| post.webp | 02_maps_post.png | 旧城邮驿 |
| quarry.webp | 03_maps_quarry.png | 赤岩钟楼 |
| ruins.webp | 04_maps_ruins.png | 灵泉记录站 |
| refuge.webp | 05_maps_refuge.png | 归航救援营 |
| wetland.webp | 06_maps_wetland.png | 雨灯湿地 |
| causeway.webp | 07_maps_causeway.png | 断桥驿路 |
| kilnwood.webp | 08_maps_kilnwood.png | 松烟炭林 |
| archive.webp | 09_maps_archive.png | 镜沙档案馆 |

使用 `tools/prepare_fudi_maps.py` 打包，逐张比较原PNG和WebP解码后的RGBA像素，必须完全相同；`manifest.json` 记录原图和运行图SHA256、尺寸及人工核对的归一化道路、入口、地标和地形主体矩形。原图需在上述目录才可重新打包；游戏只依赖本目录资源。九张共约27.8 MB，Godot按无损、无mipmap、最近邻方式显示，覆盖各区域原有世界尺寸，镜头范围不变。

通行范围沿成图中的道路、桥面和建筑前庭配置，不通过图片颜色自动猜测碰撞。道路第0条两端对应同环出口，第1条末端对应跨环出口；入口沿相连道路向内100世界单位落地。图片已包含建筑与地标主体，运行时仅叠加调查环、入口效果、角色和资源，避免重复绘制。本轮按指定九张替换，霜脊瞭望岭保留原程序绘制场景；美术聊天其后生成的第十张不在本次接入范围。十地总览同心圆及六首领分区不变。

来源登记在 `assets/registry.json`，状态为review，作者/发行许可尚无独立核验记录；接入试玩不视为发行许可批准。旧 `assets/pixel/fudi/` 代码绘制草稿保留，不作为本次场景背景。
