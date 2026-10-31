# 福地细绘场景素材

2026-10-25 按用户要求，把福地新一批细绘素材接入当前场景，替换原先代码绘制的宝箱、药材点与药圃草形。原始生成图保留在 `output/imagegen/fudi-fine/`，本目录只放透明运行图。

| 目录 | 内容 | 运行尺寸 |
| --- | --- | --- |
| `chests/` | 普通箱关闭/打开、异变箱关闭/守卫中/已净化/已领取 | 256×256 |
| `herbs/` | 11 种草药图标 | 128×128 |
| `plants/` | 10 种药圃三阶段生长图，横向 3 格 | 576×192（每格 192×192） |

宝箱状态对应：`sealed → mutated_closed`、`guarding → mutated_guarding`、`cleared → mutated_cleared`、`opened → mutated_open`；普通箱使用 `normal_closed / normal_open`。草药图标同时用于野外拾取和 B 行囊；药圃按生长进度显示三阶段，成熟时为第三格。

## 复现

```powershell
python tools/prepare_fudi_fine_materials.py
```

脚本需要 Pillow。它按源图边缘判断绿色或品红抠像底，移除右下角生成水印，裁掉透明留白并统一缩放；牛蒡根（`bitterroot`）暂无三阶段源图，运行时退回单张草药图标并按进度缩放。原始生成图不被修改。

运行映射集中在 `card-demo/scripts/scenes/fudi_material_art.gd`，由宝箱模块 `fudi_chests.gd`、野外/行囊 `fudi.gd` 和药圃 `fudi_weather.gd` 共用。`manifest.json` 记录每张运行图的来源、尺寸和 SHA256。

来源和许可尚未独立核验，登记保持 `review / license unknown`；接入试玩不视为商用或再分发授权。
