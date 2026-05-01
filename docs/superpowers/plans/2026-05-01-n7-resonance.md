# N7 计划：共鸣与古谱（v1）

> 起草日期：2026-05-01
> 分支：`feat/n7-resonance`

## 目标

把 N3 单古谱（青龙宿）扩展到 spec §5.2 的 7 张古谱体系。
v1 聚焦"共鸣激活"闭环：装备入谱 → 28 星全亮 → 共鸣触发 → 永久 buff。

## 不在 N7 v1 内
- 星轨笔（StarBrush）+ 自连
- 隐藏图案表 + 共鸣暴击
- 装备多谱并行投影（一件装备只入造出来时选中的那张谱）
- 999 诡器谱（spec §5.5）

## 设计要点

### GuPuData 加 placement_filter
新增字段：
```gdscript
@export var placement_filter: Dictionary = {
    "paths": Array[StringName],     # 允许的 path_affinity；空=任意
    "quality_min": int,
    "quality_max": int,
}
```
- 装备入谱前先过 filter；不过则返回 &"" 不入此谱
- 保持现有 placement 公式（band×6 + slot_idx）不动，只在 filter 后跑

### 7 张古谱（v1 复用同 28 颗 sus）
| id | 名 | filter |
|---|---|---|
| `qing_long` | 青龙宿（剑系） | paths=[sword] |
| `xuan_wu` | 玄武宿（防具/护符） | paths=[talisman, eating_vessel, divination_plate] |
| `zhu_que` | 朱雀宿（火/咒） | paths=[curse, alchemy] |
| `bai_hu` | 白虎宿（兽皮/骨器） | paths=[eat] |
| `zi_wei` | 紫微宿（高品质） | quality_min=3 |
| `xue_yao` | 血曜宿（邪/血） | paths=[curse]，理论值（短期同 zhu_que） |
| `can_xiu` | 残宿（不归还） | 特殊：不靠 placement，gear status=NOT_RETURNED 直接入 |

简化：复用现有 28 颗 sus（path 全 sword 仅匹配视觉）；每张古谱独立计 placement → 装备落点不同。
**v1 已知妥协**：sus 元数据 path=sword 与 filter 不一致；视觉 ID 一样。N7b 重做 sus 池。

### 共鸣激活
- `CodexState.lit_star_count(gupu_id) -> int`
- `place_equipment` 入谱后调 `_check_resonance(gupu_id)`：
  - 若全 28 星都有 ≥1 件装备 + 该 gupu 不在 active_resonances → 加入 + emit `resonance_activated(gupu_id)`
- `GameState.active_resonances: Array[StringName]`（持久化）

### 共鸣 buff（v1 接 1 个具体 + 余作占位）
- **玄武宿**：损坏率 -50% — 在 ReturnResolver 加 modifier 接口
- 其他 6 张：emit + 写 diary，效果 TODO 注释

### CodexScreen 切换
- 顶部加 7 个古谱按钮
- 切谱时 emit `codex_changed` → 重建 _stars
- 进度条："已点亮 X / 28"
- 已共鸣的古谱按钮带 ✓ 标记

### Save v5 → v6
- GameState.active_resonances 序列化

## 任务分解
| T# | 任务 | 测试 |
|---|---|---|
| T1 | GuPuData.placement_filter + CodexPlacement 重写 | test_codex_placement 加用例 |
| T2 | 6 张新古谱 .tres | test_gupu_data_loads 加 |
| T3 | GameState.active_resonances + 序列化 | test_game_state |
| T4 | CodexState.check_resonance + emit | test_resonance |
| T5 | Save v5 → v6 | test_save_migration |
| T6 | ReturnResolver 接玄武宿 buff | test_return_resolver_buff |
| T7 | CodexScreen 古谱切换 + 进度 UI | playtest_n7_smoke |
| T8 | README + merge | — |

## DoD
1. 新增/改动测试全 PASS，N0-eerie 回归 0 FAIL
2. 链路验证：连续锻造造满 28 星 → 共鸣激活信号 emit + GameState.active_resonances 含 id
3. 玄武宿激活后 ReturnResolver 损坏率减半（统计验证）
4. README 进度行加 N7 ✅
