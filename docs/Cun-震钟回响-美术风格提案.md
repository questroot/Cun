# Cun 震钟回响 · 美术风格提案

> **结论**：前十几版失败的根因是「画什么」没变——一口钟 + 几道声波的组合元素数量天然少，换任何渲染通道都撑不起参考图的信息密度。本提案只解决造型设计：把震钟回响重构成**多主体、多层、高占格率**的繁复构图，先出 1 张静态造型稿确认，再谈动效与帧数。

## 一、风格锚点（逐字复用，不得改动）

```
高信息密度像素风技能特效锚点：
1. 复合主体：中心一个明确主物 + 6 层以上环绕结构 + 数十个次级碎片，三者同时存在。
2. 占格率 85% 以上，画面填满，四角也有内容，只留 2px 透明边距。
3. 连续色调与硬边像素块混合：主体有金属渐变与多级明暗，边缘保持像素块感。
4. 明度阶梯六级：暗底 / 暗铜 / 铜 / 金 / 浅金 / 米白，主体最亮，背景残影最暗。
5. 左上光源，所有实体有亮面、中间调、暗面、高光线四层。
6. 深蓝紫纯色底，自发光，无写实阴影、无环境光遮蔽。
```

## 二、6 色色彩板与明度阶梯

| 阶 | 色号 | 用途 |
|---|---|---|
| 1 最暗 | `#352d40` | 背景、钟影、暗部轮廓 |
| 2 | `#6b4a49` | 暗铜、锈蚀、碎片阴影 |
| 3 | `#a57350` | 铜、主体中间调 |
| 4 | `#d8aa63` | 金、声波亮部 |
| 5 | `#f2d697` | 浅金、高光带 |
| 6 最亮 | `#fff4ce` | 米白镜面高光、光尘 |

点缀色 `#789a9d`（灰青）仅用于冷色反光，面积不超过 5%。

## 三、构图分层（数值化，用于验收）

| 层 | 内容 | 元素数 | 占画面 |
|---|---|---|---|
| 中心主体 | 一口**破裂**的古铜巨钟：钟身密集铭文刻痕、铆钉排、锈蚀斑、悬挂链条、钟口裂纹 | 1 主物 + 30+ 细节 | 约 40% |
| 中层声波 | 6–8 层同心声波环，自钟口向下扇形扩散，每层带符文刻印、断裂缺口、细波纹 | 6–8 层 | 约 30% |
| 飞散碎片 | 铜屑、碎钟片、火星，沿声波方向向外抛射，大小递减 | 20+ | 约 10% |
| 背景残影 | 四角半透明钟影 / 声纹残像，最暗 | 4+ | 约 5% |
| 光尘 | 细微亮点散布全画面 | 30+ | — |

**关键：声波环必须破裂、有缺口、粗细不均**，不能是完整闭合的装饰圆环——这是上一轮「像 Buff 光圈」的病根。

## 四、禁忌清单

- 禁止简洁、极简、留白、大块纯色空背景
- 禁止单色平涂、无明暗层次
- 禁止完整闭合的完美圆环
- 禁止只有 1 个主体、禁止元素少于 3 类
- 禁止人物、可读文字、logo、水印、UI、边框
- 禁止 3D 渲染感、照片写实、柔焦摄影感
- 禁止现代工业设计感（保持古旧青铜器质感）

## 五、提示词包（四段，逐字复用）

**A · 风格锚点（固定不变）**
```
Pixel-art game skill VFX key frame, extremely high information density, 16-bit JRPG
pixel aesthetic with continuous tonal gradients on metal surfaces and crisp hard-edged
pixel clusters at contours. Six-step value ladder from dark violet to ivory, lit from
upper left, self-illuminated, deep blue-violet flat background. Frame filled to 85%,
content reaching all four corners, only 2px clear margin.
```

**B · 主体槽位**
```
Centre: an ancient cracked bronze bell, body covered with dense engraved rune bands,
rows of rivets, verdigris corrosion patches, hanging chains, a cracked flared mouth
with a visible clapper. Lit left face, mid-tone body, dark right face, bright specular
edge. Around it: 6 to 8 concentric sound-wave rings bursting down and outward from
the mouth, each ring broken with gaps and uneven thickness, inscribed with small
glyph marks and fine ripple lines. More than twenty bronze shards and sparks flying
outward along the wave direction, decreasing in size. Four faint bell silhouettes in
the corners, darkest value. Thirty or more tiny light motes scattered across the frame.
```

**C · 技术规格**
```
Square 1:1 composition, single static peak frame, centred anchor, no camera motion,
no depth of field, no motion blur, no soft glow fog outside the effect.
```

**D · 禁忌（负面）**
```
No minimalist composition, no empty negative space, no flat single-colour fills,
no perfect closed circular rings, no single isolated subject, no 3D render look,
no photorealism, no people, no legible text, no watermark, no logo, no UI, no frame.
```

## 六、交付规格

| 项 | 值 |
|---|---|
| 基准图 | 1024×1024 PNG，纯色底版 + 透明底抠图版，文件名带 `_v1` |
| 缩略复核 | 缩到 96×96 检查剪影可读性（10% 尺寸仍须认得出） |
| 用途 | 造型锚点稿，供确认后扩产 8 帧 |
| 运行可用 | ❌ 展示级，色数与 alpha 不进运行图集 |
| 生成方式 | AI 文生图（避免被简单首帧锁死造型） |

## 七、基准稿产出（v1，AI 生成）

目录：`pixel-art/combat-weather/showcase/echo_redesign/`

| 文件 | 说明 |
|---|---|
| `H06-echo_redesign_v1_clean.png` | 1024×1024 纯色底基准稿（已去水印） |
| `H06-echo_redesign_v1_alpha.png` | 透明底版（按亮度生成 alpha） |
| `H06-echo_redesign_v1_96.png` | 96×96 缩略复核图 |
| `old-vs-redesign.png` | 旧版（一口钟+弧线）与新版并排对比 |

生成方式：AI 文生图，high，1024×1024，成本约 5–10 积分。**未使用任何旧首帧**，避免被简单构图锁死。

### 锚点达成核对

| 锚点项 | 结果 |
|---|---|
| 复合主体：钟 + 6 层以上声波 + 20+ 碎片 | ✅ 7 层声波、20+ 铜屑、4 角钟影、悬挂链条 |
| 占格率 85%+ | ✅ 内容抵达四角 |
| 六级明度阶梯、左上光 | ✅ 暗紫→暗铜→铜→金→浅金→米白 |
| 钟身密集细节 | ✅ 铭文带、铆钉排、锈蚀斑、裂纹、钟舌 |
| 声波破裂不闭合 | ✅ 各层有缺口、粗细不均、带符文 |
| 缩到 96 剪影可读 | ✅ 钟形与声波层次仍可辨（细节必然丢失） |

### 后处理

- 水印「AI生成 WORKBUDDY>」位于 x904–1012 / y964–1012，颜色约 `(133,134,138)`；按局部背景色填充 `x896:1024, y956:1024` 清除。
- 透明底由亮度阈值 `alpha = clamp((lum-16)/46,0,1)×255` 生成，属近似抠图。

### 需要人工精修（不谎报可直接用）

- 水印填充区是平涂色块，1024 全尺寸下与原背景有轻微色差，需手工融合。
- 透明底为近似值，四角暗钟影保留偏弱，需人工修 alpha。
- 钟身铭文是 AI 生成的伪纹样，不可读；若需真实符文须人工绘制。
- 96×96 下细节糊成一团，作为运行资产需另做小尺寸重绘。

## 九、锚点复用验证 · H01-banner 血旗横扫（v1）

> **结论**：同一套锚点换主体与色板后依然成立，两张属同一画风，验证可批量。代价是 96×96 缩略下两张的「中心亮主体 + 环绕弧」剪影偏同族，需靠配色与主体朝向拉开区分度。

### 槽位表（一次只变两个变量）

| 槽位 | 震钟回响 | 血旗横扫 | 是否改动 |
|---|---|---|---|
| A 风格锚点 | 六条逐字 | **完全相同** | ❌ 不动 |
| B 主体 | 破裂古铜钟 + 7 层声波 | 撕裂战旗 + 6–8 层横扫弧 | ✅ 换 |
| 色板 | bell 六级（暗紫→金→米白） | sword 六级（暗紫→绯红→珊瑚→米白） | ✅ 换 |
| C 技术规格 | 1:1 静态峰值帧 | 完全相同 | ❌ 不动 |
| D 禁忌 | 同上 + 禁纸屑感 | 完全相同 | ❌ 不动 |

sword 六级：`#30243e` → `#70394f` → `#ba535e` → `#ed9572` → `#ffd5a0` → `#fff2d5`；点缀 `#8d7184`。

### 产出

目录：`pixel-art/combat-weather/showcase/banner_redesign/`

| 文件 | 说明 |
|---|---|
| `H01-banner_redesign_v1_clean.png` | 1024×1024 纯色底（去水印） |
| `H01-banner_redesign_v1_alpha.png` | 透明底版 |
| `H01-banner_redesign_v1_96.png` | 96×96 缩略复核 |
| `anchor-consistency.png` | 与钟锚点稿并排的一致性检查图 |

生成：AI 文生图，high，约 5–10 积分。水印位于 x903–1013 / y963–1013，按局部背景色填充清除。

### 六维核对

| 维度 | 结果 |
|---|---|
| 剪影可读性 | 96 缩略下可认出斜向战旗，但环形弧与钟版趋同 |
| 明度层级 | 六级拉开，旗面亮、四角旗影最暗 |
| 构图与负空间 | 占格率 85%+，四角有旗影，无大片空白 |
| 风格一致性 | ✅ 同底、同密度、同质感、同光向 |
| 技术合规 | 水印已清；透明底为近似值 |
| 可用性 | 横扫方向感偏弱（旗面呈斜向，弧线呈环绕） |

### 需要人工精修

- 水印填充区在 1024 全尺寸有轻微色差。
- 透明底按亮度阈值近似，四角暗旗影保留偏弱。
- 旗面纹章是 AI 伪纹样不可读。
- **横扫弧目前接近完整环绕**，与「血旗横扫」的单向扇形预警形状（`sector`）不完全一致；若要对齐玩法，需人工把弧线改为单向拖尾。

### 待确认

- 是否接受「旗面斜向 + 环绕弧」这一构图（原设定为左→右横扫扇形）
- 是否继续复用此锚点扩产其余 boss 招式（建议按色系分批，每批 5–6 张先复核一致性）
- 是否需要在 96 尺寸上强制做剪影差异化（例如钟版保留上钟下扇、旗版改为纯横向拖尾）

## 十、v2 修正 · 旗杆与旗面（用户验收反馈）

> **结论**：v1 存在两根斜杆交叉成 X、旗面残缺被裁切，是上一轮评审漏验。v2 只改旗与杆，锚点 A/C/D 逐字不动，三项问题全部修正。

| 用户指出的问题 | v1 | v2 |
|---|---|---|
| 旗杆出现 2 根 | 两根斜杆交叉成 X | **一根垂直旗杆**，位于左侧 1/3，顶端有帽与环箍 |
| 旗子显示不全 | 旗面被夹在两杆间、边缘裁切 | **一整块连续布面**向右展开，四边全在画内，留白充足 |
| 横扫方向（上轮遗留） | 环绕弧线 | **6–8 条水平平行拖尾**，带缺口与符文，单向由左向右 |

提示词变更仅两处：B 段主体改为「exactly ONE straight vertical pole + single continuous rectangular cloth extending right, fully visible」；D 段新增 `no second pole / no crossed poles / no X-shaped rods / no spear / no diagonal staff / no cropped cloth / no partial flag / no circular arcs`。

### 产出

| 文件 | 说明 |
|---|---|
| `H01-banner_redesign_v2_clean.png` | 1024×1024 纯色底（水印已清） |
| `H01-banner_redesign_v2_alpha.png` | 透明底版 |
| `H01-banner_redesign_v2_96.png` | 96×96 缩略复核 |
| `v1-vs-v2.png` | 修正前后对比 |
| `anchor-consistency.png` | 钟锚点 vs 修正旗，同族一致性复查 |

96 缩略复核：左侧竖杆 + 右侧旗面清晰可辨，水平拖尾与钟版扇形声波**剪影区分度已拉开**。

### 仍需人工精修

- 四角旗影在 v2 里呈矩形暗块，略像边框，需柔化。
- 水印填充区全尺寸有轻微色差；透明底为亮度阈值近似；旗面纹章仍是不可读的 AI 伪纹样。
- 旗面为静态飘扬姿态，尚未做 8 帧动效。

### 待确认

- 是否接受 v2 作为 H01-banner 的最终造型锚点
- 接受后是否出 8 帧动效，走 AI 视频还是本地绘制
- 是否按此锚点扩产其余 boss 招式（建议按色系 5–6 张一批，先复核一致性）

## 十一、旗帜挥动循环动效（v2 动效）

> **结论**：旗帜挥动动效已产出并可循环播放。**提示词写死背景恒定后，这次没有出现上一条 120 帧视频的逐帧退化**——8 个时间点抽样全部干净，旗杆全程单根不动。

### 产出

目录：`pixel-art/combat-weather/showcase/banner_motion/`

| 文件 | 说明 |
|---|---|
| `H01-banner_wave_loop.gif` | **循环动图**，256×256，14 帧，100ms/帧，1.4 秒 |
| `frames96/H01-banner_wave_01.png` … `_08.png` | 8 个挥动相位，96×96 |
| `H01-banner_wave_contact.png` | 8 相位横排接触表 |
| `H01-banner_motion.mp4` | AI 源视频 4 秒 / 107 帧 @24fps / 768×768 |
| `make_wave.py` | 可复跑脚本 |

### 规格

| 项 | 值 |
|---|---|
| 挥动相位 | 8（取自源视频第 0/13/27/41/54/68/82/95 帧） |
| 循环帧数 | 14（0→7→1 乒乓，无重复端点，首尾无缝） |
| 帧率 / 时长 | 10 fps / 100ms 每帧 / 1.4 秒循环 |
| 单帧尺寸 | 96×96（序列）/ 256×256（GIF） |
| 循环 | ✅ `loop=0` |
| 水印 | 左上角「AI生成」框，按局部背景色填充 `x0:108, y0:72` 清除 |
| 成本 | 约 50–100 积分（一条 4 秒视频） |
| 运行可用 | ❌ RGB 不透明、色数极高，展示级 |

### 与 120 帧那条的对比

| | 震钟回响 120 帧 | 旗帜挥动 |
|---|---|---|
| 源视频退化 | 第约 40 帧起紫色噪点扩散 | **无退化**，107 帧全程稳定 |
| 可用段 | 只剩前 34 帧 | 全段可用 |
| 循环 | 非严格循环 | ✅ 乒乓循环，首尾接得上 |
| 有效画面 | 120 帧容器 / 34 独立画面 | 14 帧 / 8 独立相位 |

关键差异在提示词：本条明确写了 `background absolutely constant / no new elements / no purple triangles / no glowing corners / no extra poles`，把上次的失效点逐条堵住。

### 诚实局限

- **挥动幅度偏小**：布料褶皱只是在起伏，没有大幅翻卷。AI 对「gentle waving」的执行偏保守。
- **造型被重新诠释**：AI 视频把 v2 静帧的旗面比例与金色纹章换成了较小的红旗 + 麦穗状纹章，与静帧不完全一致。若要严格保型，需人工逐帧修。
- 四角旗影仍是矩形暗块；透明底未做（本次输出为 RGB）。
- 展示级，不进运行图集。

### 待确认

- 是否接受当前挥动幅度，或需要重出一条「大幅翻卷」版（再花约 50–100 积分）
- 是否把这套「背景恒定 + 乒乓循环」流程复用到震钟回响，重做它的 120 帧
- 是否继续扩产其余 boss 招式
