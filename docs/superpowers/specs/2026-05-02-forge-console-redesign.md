# 炉房 UI 重构 · 控制台日志风（Forge Console Redesign）

> 起草日期：2026-05-02
> 类型：UI 打磨 / 重构（不改业务逻辑）
> 选定方向：方案 C（控制台日志），brainstorm 阶段已 user 选定。

## 背景与动机

当前 `forge_screen.tscn` 是默认 Godot 表单：单列 VBox 把 RecipePicker / MaterialStatus / OptionalPicker / StartButton / ResultLabel / CloseButton 竖排堆叠，没有信息分组、没有时辰感、和已建立的"墨色诡异修仙 + 纸纹 + 朱红"主题对比起来反而显得扎眼。

每次开炉只在 ResultLabel 改一行字，玩家看不到自己第几次开炉、上一次出了什么、本次火候打分历史。

## 目标
让炉房感觉像**老铁的工作日志台**：每次开炉 / 反噬 / 巧成都是日志流里一行带时辰前缀的文字，玩家随时能往上滚看几个时辰前发生过什么。

## 不在 scope 内
- 多炉同时开炉
- 配方详情对比页（点配方下拉看名字够了）
- 火候手感统计 / 巧成命中率展示
- 装备穿戴 / 出售（这是后续 N+ 的事）

## 布局（3 段竖排）

```
┌───────────────────────────────────────────────────────┐
│ 配方 [凡铁剑▾]  铁:5 金:8 朱:6 纸:6        闭门 ✕    │  ← TopBar 一行
├───────────────────────────────────────────────────────┤
│                                                         │
│  [辰] 投料 铁×2 金×4                                   │
│  [辰] 火候判定中…  ▓▓▓▓▓▓░░░  <空格>                │
│  [辰] 出炉：[灵] 凡铁剑 · 锋利                        │  ← LogFlow
│  [巳] 投料 铁×2 金×4 + 朱砂                           │     ScrollContainer + VBox
│  [巳] 反噬！材料化灰                                  │     按色染色，最新在底自动滚
│  [巳] 待 开炉 …                                        │
│                                                         │
├───────────────────────────────────────────────────────┤
│  + 朱砂   + 灰        [─── 开　炉 ───]                │  ← BottomBar 添料 + 大键
└───────────────────────────────────────────────────────┘
```

## 组件设计

### 1. TopBar（HBoxContainer，固定 ~30px 高）
- **配方下拉**：`OptionButton`，文本 + 朱红描边（theme 接管）
- **材料缩略**：横向 `HBox`，每种材料一个 Label `铁:5`，颜色按数量
  - 充足（≥ recipe 需求 ×2）：老纸黄
  - 刚够：标准
  - 不足：暗红 `#c05848`
- **闭门 ✕**：右对齐小按钮，hover 朱红描边

### 2. LogFlow（中央，~60% 高度）
- `PanelContainer`（墨色嵌入 inset 风格）→ `ScrollContainer` → `VBoxContainer`
- 每条日志是一个 Label：`[时辰] 文本`，根据类型染色：
  - `投料` / 一般操作：normal
  - `火候判定中`：暗灰 + progress 字符 `▓▓░░░`，等空格按下
  - `出炉` / 巧成：good 绿
  - `反噬`：bad 红
  - `秘品`：highlight 金
- **滚动条**：自动滚到底（用户主动滚则暂停 auto-scroll，新消息来了不抢屏）
- **复用 EventLog**：每条 forge 相关 entry 同时进 EventLog（kind 前缀 `forge_*`）。LogFlow 拉 `EventLog.entries.filter(kind starts_with forge_)` 显示，避免双源持久化

### 3. BottomBar（HBoxContainer，固定 ~50px 高）
- 左侧 **添料 chips** `HBox`：
  - 根据当前 recipe.optional_materials 动态生成 chip 按钮
  - 未投：`+ 朱砂`（默认 button 样式）
  - 已选：`✓ 朱砂`（朱红描边 + 字色金）
  - 再点取消
  - 玩家库存不够某料 → chip disabled + 字色暗
- 右侧 **大开炉按钮**：`Button`，`flex 1`（占余下宽度），字号 18，padding 大；hover 朱红描边亮
  - 材料不足 / 配方未选 → disabled

### 4. TimingWindow 整合
当前 `TimingWindow` 是悬浮 modal scene，自带圆形进度+空格判定。重构后：
- 仍由 ForgeScreen 控制实例化时机
- **位置**：不再屏幕中央悬浮，改为 LogFlow 顶部内嵌（占 LogFlow 高度的 ~30%）
- 显示时 LogFlow 上方滑出，占位 + 添 progress 行；判定完滑回，把判定结果写入 LogFlow 末行

简化实现：保留 TimingWindow.tscn 不动，只改 ForgeScreen 实例化时的位置（设到 LogFlow 顶部 absolute 定位）；不重写 TimingWindow 内部逻辑。

### 5. ResultOverlay 保留不动
当前 `ForgeResultOverlay` 是 5 级出炉视觉动画（凡-灵-法-禁-秘）。
- 屏幕级 ScreenFx.flash 已实装（金色/红色/etc）
- ResultOverlay 保留作为补充（如"秘品出炉"的特殊定格）
- v1 此次重构**不动 ResultOverlay**

## 数据流

```
玩家点配方下拉 → ForgeScreen._on_recipe_picked(id)
   → TopBar.refresh_materials(recipe)
   → BottomBar.rebuild_chips(recipe.optional_materials)

玩家点 + 朱砂 → BottomBar._toggle_chip(material_id)
   → ForgeScreen._selected_optional Set 增减

玩家点开炉 → ForgeScreen._on_start
   → 消耗材料；EventLog 加 forge_invest 条目
   → ForgeSystem.forge_one(...)
   → TimingWindow 嵌入 LogFlow 顶
   → 玩家空格判定
   → ForgeSystem.forge_one 算结果
   → EventLog 加 forge_done / forge_backlash
   → LogFlow 自动加新行
   → ResultOverlay.play(quality)
   → ScreenFx.flash + Sfx.play_forge
```

## EventLog kind 约定
| kind | 颜色 | 文本模板 |
|---|---|---|
| `forge_invest` | normal | `投料 铁×2 金×4 [+ 朱砂]` |
| `forge_timing` | dim | `火候判定中…  ▓▓░░  <空格>` (会被 LogFlow 重写) |
| `forge_done` | good 或 highlight | `出炉：[灵] 凡铁剑 · 锋利` |
| `forge_backlash` | bad | `反噬！材料化灰 +1` |

LogFlow 显示时只过滤 `kind` 以 `forge_` 开头的；其他 EventLog 条目（接客 / 共鸣 / etc）不显示在炉房 LogFlow。

## 文件改动

### 新增
- `godot/scripts/ui/forge_log_flow.gd` + `.tscn` + `.uid` — 自滚动 ScrollContainer + VBox + 染色 Label append
- `godot/scripts/ui/forge_top_bar.gd` + `.tscn` + `.uid`
- `godot/scripts/ui/forge_bottom_bar.gd` + `.tscn` + `.uid`
- `godot/scripts/test/test_forge_console_smoke.gd` + scene

### 修改
- `godot/scenes/ui/forge_screen.tscn` — 重构 Layout 为 3 段：TopBar / LogFlow / BottomBar
- `godot/scripts/ui/forge_screen.gd` — 移除 RecipePicker / MaterialStatus / OptionalPicker / StartButton / ResultLabel / CloseButton 直接控制；改为协调 3 个子组件 + 1 个 TimingWindow + 1 个 ResultOverlay
- `godot/scripts/ui/shop_screen.gd` — `_on_forge_finished` 加 EventLog kind=`forge_done`/`forge_backlash`（已有，可能微调文本格式）

### 不动
- `forge_system.gd`（业务逻辑）
- `timing_window.gd`（火候判定内部）
- `forge_result_overlay.gd`（5 级出炉动画）
- `gear_instance.gd`

## 验收标准（DoD）
1. F5 → 推门 → 开炉，看到 3 段布局：顶 TopBar / 中 LogFlow / 底 BottomBar
2. 选配方 → 材料缩略立刻更新，颜色按数量
3. 投料 → LogFlow 末追加 `[辰] 投料 …` 一行
4. 火候判定 → LogFlow 顶部插 TimingWindow 进度条，空格判定后该行变结果
5. 反噬 → LogFlow 红字 `反噬！…`
6. 关闭再开 → LogFlow 仍能看到上次的几行（EventLog persisted）
7. test_forge_console_smoke 全 PASS
8. 现有 N0-当前所有测试 0 FAIL
