# 主角八方向行走

- `source/E.png` 等8张：从 `card-demo/raw/` 原样迁入，原始文件未改动。E东、SE东南、S南、SW西南、W西、NW西北、N北、NE东北；每张4列2行，按从左到右、从上到下播放。
- `walk_E.png` 等8张：运行图集，4列2行，每格448×512，脚底锚点为格内 `(224, 504)`。原图个别披风越过等分网格，已按轮廓提取并对齐脚底，保留透明边缘。
- 重建：`python tools/prepare_hero_walk.py`（仓库根目录，需要 Pillow；运行游戏不需要 Python）。
- `scripts/scenes/hero_walk_sprite.gd` 在主城、外缘和漂流浮台复用：10帧/秒，按实际位移选八方向；停止使用 `../idle/hero_idle.png` 独立正面站立图，内部记住最后移动朝向。不镜像带武器的角色。
- 默认显示比例0.26；漂流浮台0.18。原战斗头像/立绘 `pet_hero.png` 保留。
- 来源为本次用户提供的 raw 文件；作者和许可尚未核验，登记保持 draft。
- `source/.gdignore` 让 Godot 跳过原始制作图；游戏只导入运行图集，资源登记仍保留原图。
