# Polish 计划：出炉 / 攻破 / 打听 反馈包

> 起草日期：2026-05-01
> 分支：`polish/feedback-fx`

## 目标

让 3 个核心爽点时刻**有声有动**，符合 spec §14 T10「凡-灵-法-禁-秘 五级铛声 + 屋震/起雾」基调。
当前 UI 完全静态——按按钮 = 状态变 = 完事。这次给玩家**击中感**。

## 三个事件 + 反馈

| 事件 | 现状 | 加什么 |
|---|---|---|
| **出炉** （forge_finished） | 直接关闭面板 / 静默 | 5 级品质对应 5 种铛声（频率递增）+ 屏幕震动（凡=0 / 秘=12px）+ 出炉 Label 缩放脉冲 |
| **攻破** （rule_breach 进 diary） | 普通条目，文字与其他无差 | 红字 + 条目背景脉冲 + 低沉嗡声（一次性，DiaryScreen 打开时若有 breach 条目就响） |
| **打听** （inspect 揭面） | 直接 setText | 名字 Label 透明度 0→1 fade + 0.95→1.05 缩放回弹 + 打听音（短脆铃） |

## 技术选择

### 屏幕震动
- 新 Autoload `ScreenFx`：`shake(intensity_px: float, duration_sec: float)`
- 内部用 Tween + 修改 main scene 的 position，结束归零
- 调用方：`ScreenFx.shake(8.0, 0.3)`

### 音效（程序化生成）
- 新 Autoload `Sfx`：维护若干 `AudioStreamPlayer` + 程序生成 sine `AudioStreamWAV`
- 5 个 forge tier 频率：`[220, 330, 440, 550, 880]`（A3 → A5）
- breach: 80Hz 嗡声 0.6s
- inspect: 880Hz 短铃 0.08s
- 不引入任何 wav 资源——纯代码合成，未来替换真音色只改 `Sfx._build_*` 函数

### Tween
- 直接在 UI 脚本里 `create_tween()`
- DiaryScreen / CustomerArrivalPanel 加 `_pulse_label(label, color)` 工具函数

## 文件改动

### 新增
- `godot/scripts/core/screen_fx.gd` + `.uid`（autoload）
- `godot/scripts/core/sfx.gd` + `.uid`（autoload）
- 测试：`scripts/test/test_sfx_screenfx.gd` + scene

### 修改
- `godot/project.godot`：注册 ScreenFx + Sfx
- `godot/scripts/ui/forge_screen.gd`：forge_finished 处加 shake + sfx + label pulse
- `godot/scripts/ui/diary_screen.gd`：open 时检测 breach → 红字 + 嗡声
- `godot/scripts/ui/customer_arrival_panel.gd`：inspect 后 name 脉冲 + sfx

## 任务分解

| T# | 任务 | 测试 |
|---|---|---|
| T1 | ScreenFx autoload | test_sfx_screenfx：shake 不崩 |
| T2 | Sfx autoload + 5+2 程序音色 | test_sfx_screenfx：play 不崩 |
| T3 | forge_finished 接反馈 | 烟测加载 |
| T4 | DiaryScreen breach 高亮 | 烟测加载 |
| T5 | inspect 揭面动效 | 烟测加载 |
| T6 | 烟测 + README | playtest |

## DoD
- 不破现有测试
- F5 试三个事件都能听到响声/看到动效
- 现有所有 UI 测试 0 FAIL
