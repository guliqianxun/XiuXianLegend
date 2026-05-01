# N7b 计划：星轨笔 + 自连 + 隐藏图案

> 起草日期：2026-05-01
> 分支：`feat/n7b-star-brushes`

## 目标

落地 spec §5.4 自连机制——玩家用稀缺消耗品"星轨笔"在已点亮星位之间画自连，
撞中**隐藏图案** → 永久 buff（"共鸣暴击"）。

## 不在 v1 内
- "邪图案" → 永久负 buff（spec 说有但需要解除机制配套，留 N7c）
- "灰 ×5 → 1 支"炼笔交互（v1 玩家通过 GREAT_DEED + 共鸣获取）
- 多古谱图案集（v1 每张古谱 1 个 secret pattern；后续扩）

## 设计要点

### 星轨笔获取
| 来源 | 数量 | 实现位置 |
|---|---|---|
| GREAT_DEED 归还 | 10% 留赠 1 支 | shop_screen._resolve_now |
| 共鸣激活 | 1 + 完成奖励 3 = 4 支 | GameState.activate_resonance hook |

`GameState.star_brushes: int = 0`

### 自连
- `CodexState.player_lines: Dictionary { gupu_id → Array[[su_a, su_b]] }`
- `add_player_line(gupu_id, su_a, su_b)`：检查 1) 都点亮 2) 笔够 3) 不重复 → 消耗 + 加入
- 不允许同一对反向重复（normalize 顺序）

### 隐藏图案 PATTERN_LIBRARY
hardcoded const Dictionary in CodexState：
```
{
  &"qing_long": [
    {
      "id": &"jiu_xing_zhao_ming",
      "name": "九星照命",
      "lines": [["jiao","kang"], ["kang","di"], ...],  # 9 lines
      "buff_id": &"qiao_cheng_plus_5",
      "buff_desc": "巧成率 +5%",
    },
  ],
  &"xuan_wu": [...],
  ...
}
```

v1：每张古谱 1 个图案。共 7 个秘密图案。

### 命中检测
add_player_line 后扫所有 unactivated patterns：
- pattern.lines 是必需子集（每条线必须在 player_lines）
- 命中 → GameState.activate_pattern(pattern.id, buff_id) + emit signal

### Pattern buff
- `GameState.activated_patterns: Array[StringName]`
- v1：1 个 buff 接 ForgeSystem（巧成率 +5%）

### Save v8 → v9
- GameState.star_brushes
- GameState.activated_patterns
- CodexState.player_lines

## 任务

| T# | 任务 | 测试 |
|---|---|---|
| T1 | GameState.star_brushes + 获取 hook | test_star_brushes |
| T2 | CodexState.player_lines + add_player_line | test_self_connect |
| T3 | PATTERN_LIBRARY (7 个简单图案) + 检测 | test_pattern_match |
| T4 | GameState.activated_patterns + ForgeSystem 巧成 buff | test_pattern_buff |
| T5 | EventBus 加 star_brushes_changed / pattern_resonance_activated | — |
| T6 | UI（CodexScreen 选 2 星画线 + 笔数显示） | playtest_n7b_smoke |
| T7 | Save v8→v9 | test_save_migration |

## DoD
1. 测试全 PASS，回归 0 FAIL
2. 加 N 笔 → 画 N 条线，超 N 失败
3. 凑齐图案 → buff 永久启用 + 反映在巧成率
4. README 更新