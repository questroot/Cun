# 福地攻击、天气特效与四招首领

2026-10-21按用户要求，用pixel-art-studio绘制38组8帧像素动画并接入福地：24种首领技能、7种小怪攻击和7种天气。美术源、原生图集、4倍图与GIF见 [素材说明](../pixel-art/combat-weather/README.md)，运行清单见 [manifest.json](../card-demo/assets/effects/pixel/manifest.json)。

| 首领 | 技能1 | 技能2 | 技能3 | 技能4 |
| --- | --- | --- | --- | --- |
| 残旗剑士 | 断旗斩：近身剑弧 | 破阵穿刺：直线剑气 | 血旗横扫：前方扇形 | 回身剑轮：外圈剑环 |
| 荆冠鹿骑 | 荆棘践踏：近身地刺 | 地脉藤枪：直线藤刺 | 飞种围猎：三处种荚 | 森冠禁环：外圈荆棘 |
| 沉潜重装 | 高压爆破：锁定水爆 | 深潜水炮：直线水柱 | 浮雷列阵：三处水雷 | 逆潮冲环：外圈潮浪 |
| 灰翼审判者 | 落羽裁决：锁定羽雨 | 灰翼肃清：前方扇形 | 十字圣枪：交叉枪击 | 天秤终审：三处裁决 |
| 霜典记录者 | 霜文封印：锁定霜印 | 冰页穿心：直线冰页 | 禁典十字：交叉符文 | 零度书环：外圈冰柱 |
| 锈钟守望者 | 震钟回响：近身钟波 | 铜锤撼地：前方扇形 | 锈链贯击：直线锁链 | 暮钟禁域：外圈钟域 |

每只按1→2→3→4循环，出招距离不够时先追踪。预警1.05–1.9秒、基础伤害16–25、恢复3.4–4.8秒；具体参数在 [boss_skills.gd](../card-demo/scripts/scenes/boss_skills.gd)。首招兼容原配置，原生命/落点/掉落不改。守箱首领继承对应造型的四招，沿用60%生命与逐招伤害向上取整规则；四只守箱小怪接触攻击播放阴属性特效。

预警在施放时锁定位置、朝向与全部落点，红色区域就是伤害区域：圆形/三点需走出，直线向侧面或身后移动，扇形绕到身后，十字进入夹角，环形贴近中心或离开外圈。命中与绘制复用同一几何配置，多个落点同次释放最多结算一次，并共享受伤无敌时间、装备减伤/护盾。0.70秒释放动画只负责表现，不重复伤害。M地图详情、B行囊列出四招/伤害/预警/闪避提示，附近首领栏显示正在施放的招式。

七属性小怪分别播放水花、叶刃、雾咒、旋风、火焰、雷击、冰刺，保留既有接触伤害。攻击发生时保存属性及落点，后续转天气不会中途换色。天气由润雨水线/涟漪、晴光闪芒、灵雾漂带、疾风风线/叶片、炎阳余烬、雷雨雨线/局部闪电、霜雪六角冰晶组成，沿用每75秒气候轮换；雷雨每8秒一处局部闪电，没有整屏闪白。

模态与结算暂停动画计时；旅行清空预警及战斗残留，小怪回图不播放旧攻击；死亡取消该首领剩余特效。重开重置四招轮换与所有短期状态；不写原灵伴存档，既有地图陷阱仍停用。运行代码见 [首领](../card-demo/scripts/scenes/fudi_bosses.gd)、[守箱敌人](../card-demo/scripts/scenes/fudi_chests.gd)、[天气](../card-demo/scripts/scenes/fudi_weather.gd)、[像素绘制](../card-demo/scripts/scenes/pixel_vfx.gd)。

验证命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/pixel-vfx.tests.ps1 -Render
powershell -NoProfile -ExecutionPolicy Bypass -File tests/boss.tests.ps1 -Render
powershell -NoProfile -ExecutionPolicy Bypass -File tests/weather.tests.ps1 -Render
powershell -NoProfile -ExecutionPolicy Bypass -File tests/chests.tests.ps1 -Render
powershell -NoProfile -ExecutionPolicy Bypass -File tests/exploration.tests.ps1 -Render
```

所有运行检查用独立工程与存档。专项覆盖38张图集、24招锁定/命中/安全区/暂停/轮换、弱化守箱24招、特效生命周期、七属性接触伤害/天气暂停、旅行与死亡清理；原回归覆盖实际JKL输入、沿道路闪避、天气生态、真实E开箱、掉落及重开。专项手动设置站位/冷却用于覆盖，不等于正常玩家连续通关；长期操作手感与平衡待试玩。最新检查结果与证据路径见 [共享状态](../PROJECT_STATUS.md)。
