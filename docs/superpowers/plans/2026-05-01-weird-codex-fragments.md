# 暗线碎片 + 999 诡器谱框架 v1

> 起草日期：2026-05-01
> 分支：`feat/n9-weird-codex-fragments`

## 目标

铺 spec §5.5 + §9.4 的长尾系统：
- **诡器谱**：跟踪玩家见过的"独特装备 fingerprint"集合（spec 999 件）
- **身份碎片**：每 N 件 fingerprint 解锁一段老铁身份叙事（spec 15 段）

## 不在 v1 内
- 后院"不知何来"异物 6 件（需要 UI + 古谱 unlock 链路）
- 装备主词缀系统（用 recipe_id × quality 当 fingerprint，N10+ 加词缀后扩成三元组）
- 999 实际目标（v1 阈值改 5 → 75，内容到位再放）

## 设计要点

### Fingerprint
- 当前：`"<recipe_id>|<quality>"`（最多 7 × 5 = 35 unique，不到 999 但框架可演化）
- 未来：`"<recipe_id>|<quality>|<main_affix>"`

### WeirdCodex autoload
- `var fingerprints: Array[StringName] = []`（持久化，去重 set 风格）
- `record_gear(gear: GearInstance) -> bool`：算 fingerprint，新加返回 true，已有返回 false
- `count() -> int`
- `next_threshold() -> int`：返回下一段碎片需要的 fingerprint 数

### Identity fragment 阈值
| 段 # | fingerprint 累计 |
|---|---|
| 1 | 5 |
| 2 | 10 |
| 3 | 18 |
| 4 | 28 |
| 5 | 40 |
| 6+ | +15 each |

`THRESHOLDS = [5, 10, 18, 28, 40, 55, 70, 85, 100, 115, 130, 145, 160, 175, 190]`（共 15 段）

### 15 张身份碎片
NarrativeCard 已有 `IDENTITY_FRAGMENT = 7` enum trigger。写 15 张 `if_*.tres`。

### 触发链
- ForgeSystem.forge_one 不变（保持纯函数）
- shop_screen `_on_forge_finished` 命中 if not was_back: WeirdCodex.record_gear → 检查阈值 → 命中 → emit + 弹卡

### EventBus 信号
- `weird_codex_recorded(fingerprint, total)` — 新见装备
- `identity_fragment_unlocked(index, total)` — 第 index 段解锁

### Save v7 → v8
- WeirdCodex.fingerprints + unlocked_fragments_count

## 任务

| T# | 任务 | 测试 |
|---|---|---|
| T1 | WeirdCodex autoload + fingerprint 算法 | test_weird_codex |
| T2 | EventBus 加 2 信号 | — |
| T3 | 阈值检查 + 解锁逻辑 | test_weird_codex |
| T4 | 15 张 if_*.tres 身份碎片 | test_identity_fragments_load |
| T5 | shop_screen 接 record_gear | playtest_n9_smoke |
| T6 | NarrativeOverlay 触发 | playtest_n9_smoke |
| T7 | Save v7 → v8 + README | test_save_migration |

## DoD
1. 测试全 PASS，N0-N8 回归 0 FAIL
2. 100 次造不同装备 → fingerprint 增长 + 至少解锁 5 段
3. README 进度更新
