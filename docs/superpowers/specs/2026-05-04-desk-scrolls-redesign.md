# 主铺重做 v1 · 桌面卷宗风（Desk Scrolls）

> 起草日期：2026-05-04
> 类型：UI 重构（不动业务逻辑）
> 选定方向：方案 B（桌面卷宗风），brainstorm 阶段 user 选定
> Logo 风格：方案 B（全 4 张卷宗用汉字朱红印章统一）

## 背景与动机

`shop.tscn` 是 1280×720 默认 Godot 表单：4 个 ColorRect 拼成"炉房 / 柜台 / 阁楼 / 后院"4 个区域，每个区域里放一个标签 + 一个大按钮（"❋ 开炉" / "✉ 接客" / "☷ 查谱" / "❖ 立规"）。这是项目最早期的 placeholder 风格。

P1+P2 polish 把各个**内层面板**（codex_screen / forge_screen / pause_menu / 各 modal）做精了，但**主铺这一层**完全没动过 — 玩家进游戏第一眼就是"4 块色块"的 Godot tutorial 感。

`✉` 信封符号是西式邮件视觉，跟"老铁修仙铺等客上门"的氛围明显出戏。

## 目标

把主铺改成**老铁的工作桌**：4 张"卷宗"散落桌面，每张是 `PanelContainer` + 纸纹 + **汉字朱红印章** + 实时近况文字。卷宗 hover 抬起 + 朱红描边亮，点开走原有 popup（forge_screen / customer_arrival_panel / codex_screen / rules_screen）。

## 不在 scope 内
- 内层面板再次重做（已经精修过）
- 新区域 / 新功能（保持 4 区域，业务逻辑不动）
- 老铁立绘换图（仍用 `old_iron.tscn`，仅 reposition）
- HUD 重做（HudFrame + RulesFrame 不动）

## 布局（1280×720）

```
┌───[HUD 12-260 × 12-192] ─── [RulesFrame 320-1260 × 12-44] ───┐
│                                                                │
│   [炉记 印章「炉」]              [门外 印章「帖」]               │
│    ScrollCard z-rot=-3°          ScrollCard z-rot=+3°          │
│    "开炉 N · 反噬 M（10条）"     [DoorVisual 嵌入]             │
│    朱红描边 + 纸纹                "门外有客"等                  │
│                                                                │
│              [OldIron NPC 居中偏下 y=540]                       │
│                                                                │
│        [古谱 印章「谱」]            [店规 印章「规」]            │
│        ScrollCard z-rot=+2°         ScrollCard z-rot=-2°       │
│        "共鸣 0/7 · 当前: 青龙"     "4/4 规已立"                 │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

桌面背景：复用 `paper_grain.gdshader`，`base_color` 调成更暖的深棕（`Color(0.082, 0.060, 0.038, 1.0)`），`vignette_strength` 0.55（暗角更深，营造"灯下桌面"）。

## 1 · ScrollCard 组件

### 新增 `godot/scripts/ui/scroll_card.gd`

```gdscript
class_name ScrollCard
extends Control

signal opened   ## 玩家点开此卷宗

@export var seal_char: String = "炉"             ## 印章单字
@export var card_title: String = "今日炉记"
@export var card_size: Vector2 = Vector2(280, 160)
@export var z_rotation_degrees: float = 0.0       ## 整张卷宗的视觉倾斜

var _hover: bool = false
@onready var _frame: PanelContainer = $Frame
@onready var _seal: ColorRect = $Frame/VBox/Header/Seal
@onready var _seal_label: Label = $Frame/VBox/Header/Seal/Label
@onready var _title_label: Label = $Frame/VBox/Header/TitleLabel
@onready var _status_label: Label = $Frame/VBox/StatusLabel
```

### `godot/scenes/ui/scroll_card.tscn`

`PanelContainer` 自定义 `StyleBoxFlat`：
- `bg_color = Color(0.18, 0.14, 0.10, 0.95)` 暗纸内底
- `border_color = Color(0.545, 0.227, 0.165, 0.85)` 朱红描边
- `border_width_* = 1` 0.5px 描边
- `corner_radius_* = 0` 直角（中文方匣感）
- `shadow_color = Color(0, 0, 0, 0.5)` 暗角阴影
- `shadow_size = 6`
- `content_margin_* = 12`

VBox 内部：
- **Header HBox**：左 `Seal`（28×28 ColorRect 朱红 + 白字楷书）+ 右 `TitleLabel`（楷书中字）
- **StatusLabel**：2-3 行小字（实时近况文本）

### Hover 效果

`_unhandled_input` 监听鼠标 enter/exit + click。Hover 时 tween：
- `position:y` -6（抬起）
- `_frame.modulate` × 1.1（轻微提亮）
- 朱红描边亮（border_color alpha 0.85 → 1.0）

点击 → emit `opened` 信号 → shop_screen 接到信号弹对应 popup。

整张卷宗（含 padding 区）可点；不依赖小按钮。

### 印章渲染

`Seal` 是 `ColorRect`：
- `color = Color(0.78, 0.32, 0.22, 1.0)` 朱红
- 内含 `Label` 居中：
  - `text = seal_char`
  - `font_size = 18`
  - `font_color = Color(0.98, 0.94, 0.78, 1.0)` 米黄白
  - 字体走 SystemFont 中文 fallback chain

## 2 · 状态数据源

| 卷宗 | seal | title | status 模板 | 数据源 |
|---|---|---|---|---|
| 炉记 | 炉 | 今日炉记 | "近 10 条：开炉 N · 反噬 M" | `EventLog.entries.filter(kind starts_with forge_)` |
| 门外 | 帖 | 门外牌示 | （空，由嵌入的 DoorVisual 显示） | `DoorVisual` 已有 |
| 古谱 | 谱 | 古谱卷 | "共鸣 N/7 · 当前: {gupu_name}" | `GameState.has_resonance(gupu_id)` 数 7 个古谱 + `CodexState.current_gupu` |
| 店规 | 规 | 店铺规约 | "{N}/{M} 规已立" | `ShopRules.active_rule_count()` |

刷新触发：
- 炉记：`EventBus.forge_finished.connect(...)` + 启动 once
- 门外：DoorVisual 自己驱动
- 古谱：`EventBus.resonance_activated.connect(...)` + `EventBus.codex_changed.connect(...)`
- 店规：`EventBus.shop_rule_changed.connect(...)`

## 3 · shop.tscn 改造

删除：
- `AreaFurnace` / `AreaCounter` / `AreaLoft` / `AreaYard` 4 个 ColorRect 及其 Border / Button / Label 子节点
- 现有 OpenForgeButton / OpenCounterButton / OpenCodexButton / OpenRulesButton

新增（4 个 ScrollCard 节点）：
- `ScrollCardForge`：x=120, y=180, rot=-3°, seal="炉", title="今日炉记"
- `ScrollCardCounter`：x=720, y=180, rot=+3°, seal="帖", title="门外牌示"，DoorVisual 嵌入其 StatusArea
- `ScrollCardCodex`：x=200, y=420, rot=+2°, seal="谱", title="古谱卷"
- `ScrollCardRules`：x=820, y=420, rot=-2°, seal="规", title="店铺规约"

OldIron `position` 从 `(150, 490)` 改为 `(640, 540)`（中心偏下）。

Background 的 ShaderMaterial 暖色调：`base_color=Color(0.082, 0.060, 0.038, 1.0)`, `vignette_strength=0.55`。

## 4 · shop_screen.gd 改造

`@onready` refs：
- 删除 4 个 OpenXxxButton 引用
- 新增 4 个 ScrollCard 引用 `_card_forge` / `_card_counter` / `_card_codex` / `_card_rules`
- DoorVisual 改为 `$ScrollCardCounter/...`

`_ready` 信号绑定：
- `_card_forge.opened.connect(_on_open_forge)`
- `_card_counter.opened.connect(_on_open_counter)`
- `_card_codex.opened.connect(_on_open_codex)`
- `_card_rules.opened.connect(_on_open_rules)`

新增近况刷新方法（首次 + 信号触发）：
```gdscript
func _refresh_card_forge() -> void:
    var entries := EventLog.entries.filter(...)
    var open_n := entries.filter(kind == &"forge_done" or &"forge_invest").size()
    var bk_n := entries.filter(kind == &"forge_backlash").size()
    _card_forge.set_status("近 10 条：开炉 %d · 反噬 %d" % [open_n, bk_n])
```

类似的 `_refresh_card_codex` / `_refresh_card_rules`。

## 文件改动汇总

### 新增
- `godot/scripts/ui/scroll_card.gd` + `.uid`
- `godot/scenes/ui/scroll_card.tscn`
- `godot/scripts/test/test_scroll_card_smoke.gd` + `.uid` + `.tscn`

### 修改
- `godot/scenes/shop.tscn`：4 个 ColorRect 区域换成 4 个 ScrollCard 实例 + 老铁 reposition + Background 色调
- `godot/scripts/ui/shop_screen.gd`：button refs → card refs，加 `_refresh_card_*` 方法 + 信号订阅

### 不动
- 4 个 popup 面板（forge_screen / customer_arrival_panel / codex_screen / rules_screen）
- HUD / RulesFrame / NarrativeOverlay / EventLogPanel / InventoryStrip
- DoorVisual 内部（仅迁移挂载点）
- `_seed_starter_materials` / `_run_offline_settlement` 等业务逻辑

## 验收标准（DoD）

1. F5 进游戏 → 主铺呈现 4 张卷宗（不是 4 块色块），错落 ±3° 倾斜
2. 每张卷宗有 朱红汉字印章 + 楷书标题 + 2-3 行近况文字
3. Hover 卷宗 → 抬起 -6px + 朱红描边亮 + 微提亮
4. 点卷宗任意位置（不只是按钮）→ 对应 popup 弹出
5. 门外卷宗内嵌 DoorVisual，pending/idle 状态联动正常
6. 炉房开 1 把炉 → 炉记卷宗近况 +1
7. 激活 1 个共鸣 → 古谱卷宗近况更新
8. 老铁立绘在中央偏下，4 卷宗围着他
9. test_scroll_card_smoke + 全套测试 0 FAIL
10. README 进度行追加
