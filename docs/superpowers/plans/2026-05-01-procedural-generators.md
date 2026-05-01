# 程序化生成器：Customer + Recipe

> 起草日期：2026-05-01
> 分支：`feat/procedural-generators`

## 目标

把 customer / recipe 从"手写 .tres 限量"升级到"生成器无尽"。
道途 / 28 宿星图 / trait 池保持手写（这些是**结构**，不是**内容**）。

## 设计哲学

- **id 全 snake_case 英文**（未来 i18n key），display_name 全中文
- 生成器 = 字典池子 × 组合规则 × tier 风味
- 现有 .tres 客人降级为"剧情池"（少数）+ "测试 fixture"（保留）
- 生成的 customer / recipe 是 ephemeral：`gen:<seed>` id，用完即弃，不进 DataRegistry

## 架构变化

### CustomerRequest 自带数据
- 新字段：`customer_data: CustomerData = null`（生成器塞进去）
- UI 优先 `req.customer_data`，回退 `DataRegistry.get_resource`
- 这让"手写"和"生成"客人走同一码路

### CustomerSpawner 双路径
```
spawn_one(rng, now_unix):
  tier = pick by TIER_WEIGHTS [0.60, 0.30, 0.10]
  if rng.randf() < STORY_POOL_RATIO (0.30):
      try pull from registered pool (此 tier)
      if found: use it
  fallback / generator path:
      c = CustomerGenerator.generate(rng, tier, now_unix)
      build req, embed c
```

### CustomerGenerator
**字典**（全在 `generators/customer_generator.gd` 里 const）：

| 池 | 规模 | 例 |
|---|---|---|
| SURNAMES_COMMON | 50 | 赵 钱 孙 李 周 吴... |
| SURNAMES_RARE | 16 | 东方 上官 欧阳 端木... |
| GIVEN_ROOTS_COMMON | 14 | 二 三 四 大 小 老 阿... |
| GIVEN_ROOTS_RARE | 20 | 云 风 雨 雪 霜 旸 曦 岚... |
| TITLES_COMMON | 14 | 跑腿 捕快 渔翁 掌柜... |
| TITLES_RARE | 12 | 道长 郎中 真人 散修... |
| TITLES_WEIRD | 12 | 蒙面 断指 独眼 跛足... |

**命名规则**：
- REGULAR: `{surname_common}{title_common}` → "赵捕快"
- RARE: `{surname_rare∪common}{given_root_rare}` → "东方云舟"
- WEIRD: `{title_weird}客` → "蒙面客"

**酬金/特征/伪装**：
- REGULAR：`payment 80-200` / `1 trait 70%` / 不伪装
- RARE：`payment 350-600` / `1-2 traits` / 不伪装
- WEIRD：`payment 600-1000` / `2-3 traits` / 30% 伪装为 RARE

### RecipeGenerator
**字典**：

| 池 | 例 |
|---|---|
| PREFIXES_LOW | 凡 粗 朴 土 |
| PREFIXES_MID | 灵 活 巧 细 |
| PREFIXES_HIGH | 法 古 异 诡 |
| MATERIAL_SHORT | iron→铁 / jin→金 / bone→骨 / zhusha→朱 / yellow_paper→纸 |
| SLOT_SHORT | sword→剑 talisman→符 puppet_core→偶 elixir_furnace→炉 eating_vessel→器 divination_plate→盘 |
| SLOT_MATERIAL_AFFINITY | slot → 主材料(s) 映射 |

**命名**：`{prefix}{primary_material}{slot}` → "凡铁剑" / "灵骨偶" / "古朱符"

**生成规则**：
- 选 slot_kind random
- 主料 + 次料按 slot 推荐池
- 品阶分布按 tier（low / mid / high）
- prefix 按 tier
- path_affinity 按 slot 1:1 推断

## 文件改动

### 新增
- `godot/scripts/generators/customer_generator.gd` + `.uid`
- `godot/scripts/generators/recipe_generator.gd` + `.uid`
- 测试：`scripts/test/test_customer_generator.gd` + scene
- 测试：`scripts/test/test_recipe_generator.gd` + scene
- 烟测：`scripts/test/playtest_generators_smoke.gd` + scene

### 修改
- `godot/scripts/systems/customer_request.gd`：加 `customer_data` 字段
- `godot/scripts/core/customer_spawner.gd`：双路径 spawn
- `godot/scripts/ui/customer_arrival_panel.gd`：优先 req.customer_data
- `godot/scripts/ui/lend_dialog.gd`：同上
- `godot/scripts/core/offline_simulator.gd`：用生成器（避免依赖 DataRegistry 池子）

### 不动
- TRAIT_LIBRARY（手写）
- ShopRules / ShopRule（结构不变）
- 28 宿 / 古谱（手写）
- 现有 .tres customers/recipes（降级为剧情池/测试 fixture）

## 任务分解

| T# | 任务 | 测试 |
|---|---|---|
| T1 | CustomerGenerator + 字典 + generate() | test_customer_generator |
| T2 | RecipeGenerator + 字典 + generate() | test_recipe_generator |
| T3 | CustomerRequest.customer_data 字段 | test_customer_data 加用例 |
| T4 | Spawner 双路径（70% gen + 30% pool） | test_customer_spawner 改 |
| T5 | UI 改用 req.customer_data 优先 | playtest_generators_smoke |
| T6 | OfflineSimulator 用生成器 | test_offline_simulator 加用例 |
| T7 | README 进度 + merge | — |

## DoD
1. 生成器输出有效 CustomerData / RecipeData
2. 1000 spawn：三 tier 都出，命名无明显重复（100 抽样去重 ≥ 70）
3. UI 烟测能加载现有手写客人 AND 生成客人
4. 全套 N0-Polish 回归 0 FAIL
5. README 进度行加 ✅
