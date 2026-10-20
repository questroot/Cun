# 商人、工种与神学：十位NPC像素图

2026-10-21补齐。来源为聊天《生成5个NPC人物剧情》中用户提出“增加商人，商会，各类工种人物，神学人物”后形成的十人草案。上一轮只检索到地图代码中五位人物，遗漏了该聊天中的十位新增人物；本轮按完整名单独立绘制十张，不把主城向导或通用商人凑入此名单。

| 人物 | 原图文件 | 造型重点 |
|---|---|---|
| 路盐 | masters/lu-yan.png | 旧斗笠、围巾、载货手推车 |
| 金算盘 | masters/jin-suanpan.png | 机械算盘本体、账簿投影、机械足 |
| 沈衡 | masters/shen-heng.png | 整齐外套、灰尘袖口、运输调度夹板 |
| 洛铸 | masters/luo-zhu.png | 灰短发、胡须、皮围裙、救援锤和铁钳 |
| 叶汀 | masters/ye-ting.png | 绿色药师衣、草叶发饰、药瓶和照护箱 |
| 乔簧 | masters/qiao-huang.png | 维修人偶、双目镜片、大工具包、扳手 |
| 岑尺 | masters/cen-chi.png | 蓝色披肩、罗盘、卷图、测绘三脚架 |
| 谢停舟 | masters/xie-tingzhou.png | 修补长衣、普通油灯、守夜姿态 |
| 闻昼 | masters/wen-zhou.png | 紫色学者长衣、眼镜、带书签古籍 |
| 长祷者 | masters/changdaozhe.png | 无固定面容的兜帽暗面、祈愿纸条长袍 |

全套48×64原生像素、透明背景、每图不超过12种颜色、左上光、深紫轮廓。`display/`提供最近邻8倍展示图；`npc-ten-overview.png`为带姓名与工种的总览；`npc-ten-atlas.png`为240×128的5列2行透明图集，JSON附坐标与脚底锚点(24,61)。`manifest.json`保存逐图统计。

所有新增人物都由`build.py`通过pixel-art-studio Sprite接口逐形绘制；本地`sources/artist.py`保存共用绘图类和色板。用已安装的pixel-art-studio及Codex内置Python执行build.py即可重建本套，与上一套源图无运行依赖。原七张保留在`../npc-cast/`。

新服装与具体形象是本轮美术设计，人物身份、主要道具沿用剧情草案。交付静态人物图；没有接入游戏、制作行走动画或实现相关剧情系统。
