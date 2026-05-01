# N8 计划：世面与叙事 v1（势力 + 手写卡）

> 起草日期：2026-05-01
> 分支：`feat/n8-factions-narrative`

## 目标

让"势力"作为天气背景板（spec §8）影响来客构成，同时把"手写叙事卡"系统从无到有铺起来（spec §9）。

## 不在 N8 v1 内
- 来料池权重 / 公榜配方需求（无系统支撑）
- 势力间事件 / 关系（spec 明令不做）
- 暗线碎片（spec §9.4，长尾，留 N9）
- 离线日记程序化模板（N5a 已是简化版；模板池扩到 30 个留 N9）

## 设计要点

### 6 势力数据
| id | 名 | 影响 |
|---|---|---|
| `wendao_zong` | 问道宗 | 来料/来单/常客 |
| `hanxing_zong` | 寒星宿宗 | 高酬客 |
| `kurong_gu` | 枯荣谷 | 主要供料商 |
| `wandan_men` | 万丹门 | 罕客 |
| `wuqiu_yexiu` | 雾丘野修 | 怪客 |
| `unknown` | ? | 深夜怪客 + 神秘料 |

新 Resource：`FactionData` { id, display_name, style, baseline_relation }

### 势力动态状态
每势力一个 `active_state: StringName`，每"周"轮换 2-3 个势力。
状态例：
- `surge` 上升期：该势力客人 +20% spawn 权重
- `quiet` 静期：该势力客人 -30% spawn 权重
- `none` 无特殊

简化：每周固定挑 3 个势力进入 `surge`，其余 `none`。
"周"用 unix 算（`unix / 86400 / 7`）。

新 Autoload `FactionState`：
- `state_of(faction_id) -> StringName`
- `is_surge(faction_id) -> bool`
- `surge_factions() -> Array[StringName]`
- 序列化：存当前周序号 + active_states dict（防止跨 session 突变）

### Spawner 接势力 bias
`CustomerGenerator.generate` 已经随机抽 faction（FACTIONS 池均匀）。
改为：surge faction 权重 ×2，让"上升期"势力的客人占比明显高。

### 手写叙事卡（v1：30 张）
新 Resource：`NarrativeCardData` { id, category, text }
- text 可含占位符 `{customer}` `{gear}` `{shichen}` 等

v1 类目（30 张）：
| 类目 | 数量 | 触发 |
|---|---|---|
| `first_visit` 首次到访 | 10 | customer_arrived 第一次见此 customer_id |
| `forge_backlash` 反噬异象 | 5 | forge_finished was_back |
| `forge_qiao` 巧成/秘品 | 5 | forge_finished quality≥3 OR qiao |
| `resonance` 共鸣激活 | 5 | resonance_activated |
| `shopkeeper_mutter` 老铁自言 | 5 | hour_passed 偶发 10% |

数据放 `godot/data/narrative_cards/*.tres`，用 DataRegistry 自动加载。

### NarrativeCardLibrary 服务
- `pick_card(category, vars: Dictionary) -> String`：按 category 抽一张，replace 占位符
- 内存里维护 `_seen_first_visit: Set` 避免某 customer 重复触发"首到"

### NarrativeOverlay UI
- 屏幕上方淡入淡出文本（位置类似 ReturnNotice 但单独 UI）
- 1.5s 显示 + 0.5s fade
- 不阻塞输入（mouse_filter=IGNORE）

### Save v6 → v7
- FactionState（current_week + active_states）
- Library 的 _seen_first_visit（避免重复触发）

## 任务分解
| T# | 任务 | 测试 |
|---|---|---|
| T1 | FactionData class + 6 .tres | test_faction_data |
| T2 | FactionState autoload + 周计算 + surge 选择 | test_faction_state |
| T3 | CustomerGenerator faction 权重 bias | test_faction_bias |
| T4 | NarrativeCardData class + 30 张内容 | test_narrative_cards_load |
| T5 | NarrativeCardLibrary autoload + pick_card 占位符替换 | test_narrative_library |
| T6 | NarrativeOverlay UI + 接 3 个触发点 | playtest_n8_smoke |
| T7 | Save v6→v7 + README | test_save_migration |

## DoD
1. 测试全 PASS，N0-N7 回归 0 FAIL
2. 100 抽样：surge 势力的客人占比 > 平均 1.5×
3. F5 验证：接客 / 出炉反噬 / 共鸣激活 都能弹叙事文本
4. README 进度行加 N8 ✅
