# Atmosphere2D v1 · Godot 4.7.2

复制整个addon目录至任意普通Godot工程。不需autoload、末班渡船或外部依赖。CanvasModulate影响整个canvas而非world子树：attach_world不会自动创建隔离canvas，调用者必须把所有需调色世界内容放同一CanvasLayer/默认canvas，并把所有不应调色的标题/Marks/UI放另一个CanvasLayer；不能只把组件挂到Node2D就宣称子树隔离。一个world canvas只装一个CanvasModulate；UI必须放另一个CanvasLayer，世界Sprite2D/普通PNG/自绘几何留默认lit材质，unshaded材质会绕过灯光。世界坐标必须与组件局部坐标一致（world变换被继承）。

```gdscript
var atmosphere = preload("res://addon/atmosphere.gd").new()
atmosphere.attach_world(world) # Node2D，尚未挂树的组件；自动挂到world
atmosphere.set_environment({"preset":"rain"}, 1.2)
atmosphere.register_region("roof", Rect2(420,260,280,140), {"shelter":true})
atmosphere.register_region("room", Rect2(850,200,340,340), {"indoor":true,"blend":48,"ambient":Color(0.65,0.55,0.43)})
atmosphere.set_light("lamp", {"position":Vector2(665,440),"radius":240,"energy":1.4,"enabled":true,"seconds":0.5})
atmosphere.set_quality("low") # high / low / off，off返回白色ambient并隐藏灯/粒状天气
# 每帧更新观察者权威坐标，不回写游戏角色
atmosphere.observer = player.position
var surface = atmosphere.surface_at(player.position)
```

set_environment支持preset clear/rain/night/snow，或ambient:Color及rain/snow/fog/wind/wetness/snow_cover有限数。wind=-1..1，其余0..1。register_region为字典注册（同id替换）：shelter或indoor抑制降水/湿雪；indoor控制可选音频混音；blend控制边缘ambient混合；fog为局部雾矩形；snow_cover覆盖局部地面采样。局部区域ambient由observer进入时渐混全world canvas，这是v1观察者适应，不是每像素区域调色。

set_light同id为partial合并，只传position不会重开disabled灯，未传color/radius/energy/enabled/seconds均保留；默认值仅创建时应用一次。enabled=false保留配置energy，重新enabled=true恢复该目标。新增普通PointLight2D、径向纹理与shadow_enabled；光遮挡由宿主另建LightOccluder2D，挡雨矩形不产生光遮挡。调用方保证light/region属性类型与坐标有效，不将不可信网络输入直接传入。set_audio(outside:AudioStream,inside:AudioStream)是可选合法资源插槽，不随包附带音效/授权音源；声音资源应自身支持循环。

surface_at返回{wetness,snow_cover,sheltered}，供宿主材质/地面覆盖使用，不改变碰撞、速度或规则。demo用接触阴影椭圆示例；公共组件未自动追踪角色/物体。debug_regions=true画区域边框；bounds默认Rect2(0,0,1280,800)，移动相机项目应由宿主更新可视世界范围。无频闪/雷电。暂停设置frozen=true，冻结天气/过渡/灯渐变时钟并暂停音频；恢复false不补积压。宿主SceneTree暂停默认也会暂停该组件，UI需自行设置可暂停策略。同id注册覆盖、不累计；remove_region(id)/remove_light(id)移除注册；dispose()清理所有组件拥有的灯与区域并释放自身，_exit_tree也清灯，不删宿主其他节点。灯初始energy=0，关闭新灯无默认亮帧。

## 有效输入与所有权
本地可信API，不提供网络schema校验；先attach_world再调用灯/音频，world有效且每组件仅attach一次。bounds/region Rect2位置有限、宽高必须正且有限（bounds建议不超过8192×8192，避免绘制格数爆炸）；observer/灯position所有分量有限。Color各通道有限0..1；环境秒数有限≥0。region blend有限≥1、fog/snow_cover有限0..1、shelter/indoor为bool；light radius有限>0、energy有限0..16、seconds有限≥0（内部最低.02秒），enabled为bool。delta有限≥0（内部步长最多.1）。宿主不得直接free/queue_free组件拥有的lights节点，也不要直接改lights/config；使用set_light/remove_light/dispose，world销毁前可dispose。quality只传high/low/off；set_quality立即应用包括冻结中off白底/隐藏灯/暂停音频，冻结中high恢复当前ambient和可见灯但音频仍冻结，均不推进时钟/过渡/灯能量。直接赋quality不保证立即应用，请走setter。无音源时音频暂停状态测试只验证控制逻辑，不宣称听感通过。

## 当前范围（不要误称全功能）
- 已实现：world CanvasModulate平滑预设、PointLight渐变与原生遮挡、UI独立canvas、雨雪/风线/遮雨矩形、区域ambient/audio混合、局部二维低雾、地表湿雪数值采样、high/low/off。
- 简化：雨雪是确定性即时绘制点/线，不是GPUParticles；局部雾是缓慢漂移的径向软纹理簇并按区域采样降低室内/檐下密度，不是体积散射；雪覆盖是可控显示量，不是永久积雪模拟。低质量减少粒状天气数量，off恢复可对照。
- 未实现：贴图法线/湿反射shader、按真实屋顶形状溅水、动态雪堆/融雪、自动光遮挡生成、自动角色接触阴影注册、资源化preset编辑器、跨viewport同步、现成音效。正式视觉验收尚缺，状态探针不代眼看像素。

独立project位于上级，启动demo/main.tscn。WASD走动；晴雨夜雪、质量对照、渐变灯、门光遮挡与区域调试在UI。demo可由前端下一包接管，本包不改其他项目。
