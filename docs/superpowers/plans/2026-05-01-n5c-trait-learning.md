# N5c 实施计划：攻破学习 → 解锁精确铺规

> 起草日期：2026-05-01
> 分支：`refactor/n5c-trait-learning`
> 依赖：N5b 铺规 + N6 盲盒已合入

## 目标

闭合 spec §7.3 的诡异循环：
> 攻破后玩家可学习新铺规条款（如"鞋底无尘 = 怪客 → 拒"），系统永久解锁

具体流程：
1. 玩家在线**打听**怪客 → 立即学到该客人的所有 traits
2. 怪客**离线攻破**铺规 → diary 写"事后才看清"+ 同时学到 traits
3. 学到的 trait 在 RulesScreen 显示为可启用规则（如"鞋底无尘的客人 → 拒"）
4. 玩家启用后，未来类似 trait 的客人在线 / 离线都会被拒（即使伪装名匹配常客）

## 设计要点

### 数据
- `CustomerData` 加 `traits: Array[StringName]`，例 `[&"sole_dustless", &"hooded", &"speaks_old"]`
- 3 个客人补：
  - 蒙面客：`[&"sole_dustless", &"hooded"]`
  - 苏家娘子：`[&"family_seal"]`
  - 小孟跑料：`[&"badge_low"]`
- **TRAIT_LIBRARY**：硬编码 trait id → 中文显示名 + 描述（在 `shop_rules.gd` 内静态字典）

### GameState
- `learned_traits: Array[StringName]`（持久化，去重）
- `learn_traits(list: Array)`：合并去重 + emit `traits_learned` 信号
- 序列化进 to_dict / from_dict

### ShopRule 扩展
- 新 condition：`&"has_trait"`
- 新字段 `condition_arg: StringName`（仅 `has_trait` 用，存 trait id）
- `matches()` 加分支：`&"has_trait"` → 检查 `c.traits.has(condition_arg)`
  - 注意：matches 现在签名只有 (tier, shichen)。需要扩展到接受 customer 引用，或者把 trait 检查放到 evaluate 层。
  - **简化**：把 trait 检查放到 evaluate / evaluate_offline 内部，matches 不变。

### ShopRules 自动生成已学 trait 的规则
- 在 `_init_presets` 后，根据 `GameState.learned_traits` 动态注入"trait 规则"
- 启用列表用 trait id 做规则 id（前缀 `learned:`）：例 `&"learned:sole_dustless"`
- 每条 trait 规则的 action 默认为 `&"refuse"`（学到 = 警惕信号）

### Learning 触发点
- **打听**：`CustomerArrivalPanel._on_inspect` 成功扣灵石后调 `GameState.learn_traits(c.traits)`
- **离线攻破**：`OfflineSimulator.simulate` 写 `rule_breach` 时调 `GameState.learn_traits(c.traits)`
  - 接受小破坏隔离原则——trait 是"知识"不是"物资"，不会导致数值膨胀

### Save v4 → v5
- GameState 加 `learned_traits: []`

### UI（RulesScreen 改）
- 顶部已有 4 预设保留
- 加分隔 + "已学到的特征"区块
- 每个学到的 trait 显示为一行 CheckBox：`「[trait 中文名]」 → 拒`
- 启用即写入 ShopRules.enabled

## 文件改动

### 新增
- `godot/scripts/test/test_trait_learning.gd` + scene
- `godot/scripts/test/playtest_n5c_smoke.gd` + scene

### 修改
- `godot/scripts/data/customer_data.gd`：加 traits
- `godot/scripts/data/shop_rule.gd`：加 condition_arg
- `godot/data/customers/*.tres`：补 traits
- `godot/scripts/core/game_state.gd`：learned_traits + learn_traits + 序列化
- `godot/scripts/core/event_bus.gd`：traits_learned 信号
- `godot/scripts/core/shop_rules.gd`：TRAIT_LIBRARY + 动态规则注入 + has_trait condition
- `godot/scripts/core/save_system.gd`：v5 + migration
- `godot/scripts/core/offline_simulator.gd`：breach 时 learn
- `godot/scripts/ui/customer_arrival_panel.gd`：inspect 时 learn
- `godot/scripts/ui/rules_screen.gd`：分组显示 + trait checkbox
- 测试更新：test_save_migration / test_shop_rules / test_game_state

## 任务分解

| T# | 任务 | 测试 |
|---|---|---|
| T1 | CustomerData.traits + 3 客人补数据 + TRAIT_LIBRARY | test_trait_learning |
| T2 | GameState.learned_traits 字段 + 序列化 | test_game_state |
| T3 | ShopRule.condition_arg + has_trait condition | test_shop_rules 加用例 |
| T4 | ShopRules 动态注入已学 trait 规则 | test_trait_learning |
| T5 | Save v4 → v5 migration | test_save_migration |
| T6 | inspect 学 trait + breach 学 trait | test_trait_learning |
| T7 | RulesScreen 分组 + trait checkbox | playtest_n5c_smoke |
| T8 | 烟测 + README | playtest_n5c_smoke |

## DoD
1. 测试全 PASS，N0-N6 / N5a-b 回归 0 FAIL
2. 链路验证：打听蒙面客 → learned_traits 包含 sole_dustless + hooded → RulesScreen 出现这两条可启用规则
3. README 进度行加 N5c ✅
4. merge to master
