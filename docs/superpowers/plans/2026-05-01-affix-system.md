# 词缀系统 v1（主词缀 + 主题池）

> 起草日期：2026-05-01
> 分支：`feat/n9-affixes`

## 目标

让"装备"真有差异 — 出炉时按 path × quality roll 一个**主词缀**，影响 fingerprint
（让 999 诡器谱真有空间）+ 显示中影响代入感。

不在 v1 内
- 副词缀（v2 加 0-2 副词缀）
- 词缀实战 buff（v1 仅显示，效果由共鸣 buff 系统承担；N10 数值 pass 时再接）
- 修复 / 重铸（玩家干预词缀）
- 删除旧 21 战斗 affixes（保留作 archive，rolling 通过 `hooks.is_empty()` 过滤排除）

## 设计要点

### Pool 过滤
新主题词缀都满足：
- `hooks.is_empty()` （非战斗系统钩子）
- `path_filter` 列出适用 path（空 = 通用）
- `min_tier` 决定最早能 roll 出来的 quality 档

ForgeSystem 抽样：
```
pool = affix.hooks.is_empty()
       AND (affix.path_filter.is_empty() OR recipe.path in affix.path_filter)
       AND quality_band >= affix.min_tier  (band 跟 quality 1:1)
```

### 26 主题词缀分布
| 类目 | 数量 | path | min_tier |
|---|---|---|---|
| 通用 POSITIVE | 5 | [] | COMMON |
| 剑系 | 3 | [sword] | UNCOMMON |
| 符咒 | 3 | [curse] | UNCOMMON |
| 傀核 | 3 | [puppet] | UNCOMMON |
| 丹炉 | 3 | [alchemy] | UNCOMMON |
| 食器 | 3 | [eat] | UNCOMMON |
| 卦盘 | 3 | [divination] | UNCOMMON |
| 诡缀 ARCANE | 3 | [] | FORBIDDEN |

### 抽样规则（ForgeSystem.roll_main_affix）
- 取 quality band → 决定 max tier
- COMMON pool（通用 5 个）始终在；高品质叠加同 path 池子；FORBIDDEN+ 加诡缀（5% 概率压倒一切）
- 单件装备恰好 1 个主词缀（v1）

### Fingerprint 升级
`WeirdCodex.fingerprint_of`：
```
"<recipe_id>|<quality>|<main_affix_id_or_empty>"
```
理论空间：~7 配方 × 5 quality × 26 affix = ~910 ≈ spec 999

### Display
`GearInstance.display_full_name`：
```
[凡] 凡铁剑 · 锋利
```

## 任务

| T# | 任务 | 测试 |
|---|---|---|
| T1 | 26 张新主题 affixes | test_affixes_load |
| T2 | ForgeSystem.roll_main_affix + forge_one 集成 | test_forge_affix_roll |
| T3 | GearInstance.display_full_name 接词缀 | test_gear_display |
| T4 | WeirdCodex fingerprint 升级 | test_weird_codex 加用例 |
| T5 | UI 同步（lend_dialog 显示） | playtest_n9_affix_smoke |
| T6 | 烟测 + README | — |

## DoD
- 测试全 PASS，N0-N8 + 诡器谱回归 0 FAIL
- 100 件出炉装备：主词缀填充率 100%，主词缀种类至少 8 种以上
- 同 recipe + 同 quality 但不同 affix → fingerprint 不同 → 各自记入诡器谱
- README 进度
