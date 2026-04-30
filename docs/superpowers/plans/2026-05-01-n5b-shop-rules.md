# N5b 实施计划：铺规槽 + 离线决策 + 怪客攻破

> 起草日期：2026-05-01
> 分支：`refactor/n5b-rules`
> 依赖：N5a 离线模拟器 + N6 盲盒身份 已合入

## 目标

把 N5a 的"按规劝退默认行为"换成**玩家可设的铺规**，并在**离线**让 N6 的伪装怪客可**攻破**铺规——形成 spec §7.3 描述的**离线诡异感最大注入点**。

不在 N5b 内：
- 开炉规 / 应料规（先做接客规一种）
- 槽位升级（开局固定 3 槽）
- 攻破后"学习新条款"（属 N5c）
- 离线放行后的真实损失结算（diary 只描述事件，不改 inventory，与 N5a 一致）

## 设计要点

### 数据
- `ShopRule` Resource：
  - `id: StringName`
  - `display_name: String`
  - `condition: StringName` — 枚举值：`&"is_weird"` / `&"is_rare"` / `&"is_regular"` / `&"deep_night"` / `&"any"`
  - `action: StringName` — `&"refuse"` / `&"lend"`
  - condition + action 简单组合，不做 DSL parser
- 4 条预设规则（硬编码）：
  - `refuse_weird`（拒怪客）
  - `lend_regular`（接常客）
  - `refuse_all`（全拒，N5a 默认行为）
  - `lend_any`（全接，激进）
  
### Autoload `ShopRules`
- `var enabled: Array[StringName] = [&"refuse_all"]`（默认全拒）
- `evaluate(req: CustomerRequest, c: CustomerData) -> StringName`：按顺序遍历 enabled，第一条匹配的返回 action；无匹配返回默认 `&"refuse"`
- 序列化进 SaveSystem v3→v4

### 攻破逻辑（核心）
- 离线时，伪装客人按 `disguise_tier` 而不是 `tier` 评估
- 例：玩家启用 "拒怪客"，但伪装怪客 disguise_tier=REGULAR，规则按 disguise_tier 评估 → 放行 → 在 diary 写"放进了一个看起来寻常的客人，借走 [item]——后来才知是 [真名]，[结果]"
- 在线时使用真实 tier（玩家可识破）

### OfflineSimulator 改造
- 替换 v1 的「每时辰固定 50% 概率劝退」逻辑
- 每时辰 spawn 一位客人（用 CustomerSpawner.spawn_one + 离线 RNG）
- 调 `ShopRules.evaluate_offline(req, c)` 决定 lend / refuse
- lend 路径：写一条"借出"日记 + 若伪装攻破，再写一条"伪装攻破"特殊条目

### UI（最小可用）
- 后院 area 加"立规"按钮 → 打开 RulesScreen
- RulesScreen：
  - 列出 4 条预设规则（CheckBox）
  - 显示当前启用列表（最多 3 条）
  - 关闭时存档

### Save v3 → v4
- 加 `shop_rules.enabled: Array[String]`，默认 `["refuse_all"]`

## 文件改动

### 新增
- `godot/scripts/data/shop_rule.gd` + `.gd.uid`
- `godot/scripts/core/shop_rules.gd` + `.gd.uid` (autoload)
- `godot/scripts/ui/rules_screen.gd` + `.gd.uid`
- `godot/scenes/ui/rules_screen.tscn`
- 测试：`scripts/test/test_shop_rules.gd` + scene
- 烟测：`scripts/test/playtest_n5b_smoke.gd` + scene

### 修改
- `godot/project.godot`：注册 `ShopRules` autoload
- `godot/scripts/core/save_system.gd`：v4 + `_migrate_v3_to_v4`
- `godot/scripts/core/offline_simulator.gd`：用 ShopRules.evaluate_offline 决策 + 伪装攻破
- `godot/scenes/shop.tscn`：后院 area 加 RulesButton；加 RulesScreen instance
- `godot/scripts/ui/shop_screen.gd`：连按钮 + open RulesScreen

## 任务分解

| T# | 任务 | 测试 |
|---|---|---|
| T1 | ShopRule 数据类 + 4 预设硬编码 | test_shop_rules：rules 加载 |
| T2 | ShopRules autoload + evaluate | test_shop_rules：4 条规则匹配真值表 |
| T3 | Save v3→v4 migration | test_save_migration |
| T4 | OfflineSimulator 改用 evaluate_offline + 攻破事件 | test_offline_simulator 加用例 |
| T5 | RulesScreen UI + 后院按钮 | playtest_n5b_smoke |
| T6 | 烟测 + README | playtest_n5b_smoke + README |

## DoD
1. 测试全 PASS，N0-N6 回归 0 FAIL
2. 离线 12h 启用"拒怪客"规则 → diary 至少一条攻破事件（如 RNG 命中伪装客人）
3. README 进度行加 N5b ✅
4. merge to master
