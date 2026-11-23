# 天气效果 V2 · 游戏接入预览

这是可挑选的 Godot 4.7.2 源码，不是完整展厅或已接入所有游戏的插件。已有 2D 游戏想用完整环境节点，请先看 [Atmosphere2D V1](../atmosphere2d/README.md)。两版可独立使用。

## 最小接法：让一层雾随天气变化

把本目录复制到游戏工程的 `res://weather_v2/`。在世界画面上放一个有尺寸的 ColorRect，忽略鼠标输入，不要盖住 UI。把下面的脚本挂到这个矩形：

```gdscript
extends ColorRect
var weather = preload("res://weather_v2/weather_cycle.gd").new()
var mist := ShaderMaterial.new()
var travel := 0.0
func _ready():
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    mist.shader = preload("res://weather_v2/forest_mist.gdshader")
    material = mist
    weather.select_event("fog")
func _process(delta):
    weather.advance(delta)
    travel += delta * 0.035
    mist.set_shader_parameter("amount", weather.fog)
    mist.set_shader_parameter("wind_travel", travel)
```

`select_event("rain"/"snow"/"fog")` 切换事件但保留已有地表状态；`stop_event()` 停止新增降水，继续调用 `advance` 才会逐渐消退。`reset()` 用于需要清空地表的重置。脚本只提供雨量、积雪、湿度等数值，不会自行生成粒子。

## 按场景选用

- **2D 地面与雪**：`ground_2d`、`forest_snow_surface`、`forest_snow_receiver` 为材质程序；按源码 uniform 绑定相应地面或接雪图层。
- **3D 湿地、雾与浅水**：`wet_ground`、`bounded_mist`、`shallow_water` 由游戏配置材质、相机与范围。浅水材质的反射纹理须由宿主提供；没有自带反射场景。
- **遮挡与游戏规则**由宿主负责。不要在纯室内生成雨线，也不要将雨篷遮挡当作地面不会漫水。不要把示例地图的落点搬到自己的地图。

本次只发布自研状态脚本及材质源码，不含展厅、美术、音源、Bistro 地图和本机测试数据。原场景有无窗状态验证；这份独立接入示例未做前台画面、听感或帧耗验收。
