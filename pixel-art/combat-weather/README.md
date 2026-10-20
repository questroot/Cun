# 福地攻击与天气像素动画

使用已安装的 pixel-art-studio 技能的 Sprite 原生逐像素绘制，源文件为 [build.py](build.py)，不依赖图像模型。构建脚本从 `CODEX_HOME` 或用户目录下的 `.codex` 查找该技能，需要 Pillow。

- 共38组、304帧：六首领各四招、七属性小怪攻击、七天气粒子。
- 原生画布96×96，统一中心锚点48,48；每动画8帧，透明边缘至少2像素，每组最多7色，透明度仅0/255。能量自发光，亮芯与冷色边缘分离；实体种荚、羽毛、铜钟取左上方亮面。
- 攻击帧时长90/70/50/100/80/80/100/130毫秒，天气每帧120毫秒。爆发类单次播放；天气循环播放。
- 每组交付 `名称.png`（768×96原生横排图集）、同名JSON（帧坐标/时长/标签）、`名称-master.png`（第4帧96×96）、`名称-4x.png`（384×384）、`名称.gif`（4倍动画）。游戏目录只保留运行图集、JSON和清单。
- [manifest.json](manifest.json) 记录色板、锚点、时长、颜色数量及透明度检查；[检查记录](QA.md) 记录三轮查看和修整。

重建：

```powershell
python -W ignore pixel-art/combat-weather/build.py
```

工作预览：[首领总览](boss-preview.png)、[小怪与天气总览](elements-preview.png)、[动作帧检查](motion-preview.png)、[首领动画](boss-animation.gif)、[小怪与天气动画](elements-animation.gif)。可用游戏资产在 [effects/pixel](../../card-demo/assets/effects/pixel/)，技能与躲避方式见 [运行说明](../../docs/combat-weather-effects.md)。
