# Content Pack 01：扩 customer / recipe / trait

> 起草日期：2026-05-01
> 分支：`content/pack-01`
> 类型：纯数据补充，不改逻辑

## 背景

当前 3 客人 / 3 配方 / 6 trait，spawner weights `[0.80, 0.0, 0.20]` 跳过 RARE 池。
玩家试两次就把内容看完了。先把"内容厚度"拉到能玩 10-15 分钟不重复。

## 增量目标

| 类目 | 当前 | 加 | 终态 | spec 目标 |
|---|---|---|---|---|
| 客人 | 3 | +7 | 10 | 100 |
| 配方 | 3 | +4 | 7 | 30 |
| trait | 6 | +4 | 10 | （未明确） |
| spawner weights | 80/0/20 | 改 60/30/10 | spec §6.1 对齐 | — |

## 内容设计

### 新客人（7）

| id | 名 | tier | path | 酬 | 伪装 | traits |
|---|---|---|---|---|---|---|
| zhao_buhuai | 赵捕快 | REGULAR | sword | 180 | — | family_seal, smells_iron |
| li_yuyi | 李渔翁 | REGULAR | eat | 120 | — | (无) |
| ma_chedeng | 马车灯 | REGULAR | divination | 150 | — | badge_low |
| dao_qingxia | 刀青霞 | RARE | sword | 450 | — | family_seal |
| qiu_yueshen | 邱越神 | RARE | curse | 500 | — | speaks_old |
| zhuren_buming | 主人不明 | RARE | divination | 550 | — | gold_too_new |
| yu_chongyi | 御重医 | WEIRD | alchemy | 800 | "云游郎中"（伪 RARE） | pale_face, carries_doll |

### 新配方（4）

| id | 名 | slot_kind | path | 必需料 | 可选 |
|---|---|---|---|---|---|
| ling_kuilei_xin | 灵傀儡心 | puppet_core | puppet | iron×3, zhusha×2 | bone, yi_zhong_liao |
| qing_dan_lu | 青丹炉 | elixir_furnace | alchemy | iron×4, jin×2 | hui |
| liu_tong_pan | 六通盘 | divination_plate | divination | jin×3, yellow_paper×2 | zhusha, hui |
| ling_jian_xian | 灵剑弦 | sword | sword | iron×4, jin×6 | zhusha, hui, bone |

### 新 trait（4）

| id | 中文名 |
|---|---|
| pale_face | 面色青白 |
| whispers_self | 自言自语 |
| carries_doll | 怀中抱偶 |
| gold_too_new | 金子太新 |

### Spawner weights 调整

`[0.80, 0.0, 0.20]` → `[0.60, 0.30, 0.10]`（spec §6.1 表）。

## 文件改动

### 新增
- `godot/data/customers/zhao_buhuai.tres` 等 7 个 .tres
- `godot/data/recipes/ling_kuilei_xin.tres` 等 4 个 .tres

### 修改
- `godot/scripts/core/shop_rules.gd`：TRAIT_LIBRARY 扩 4 条
- `godot/scripts/core/customer_spawner.gd`：TIER_WEIGHTS 改 60/30/10

### 测试
- `playtest_content_pack_01.gd` + scene：10 客人加载 / 7 配方加载 / 10 trait / 100 次 spawn 三 tier 都出现

## DoD
1. 新增内容能加载（DataRegistry 自动扫描 `data/customers` + `data/recipes`）
2. 100 次 spawn 三 tier 都有客人产出（验证 weights 生效 + RARE 池有客人）
3. 现有 N0-polish 全套测试 0 FAIL
4. README 进度行加 Content Pack 01 ✅
