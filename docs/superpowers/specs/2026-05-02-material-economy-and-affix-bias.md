# 材料经济 v1 · 灵石购料 + 客人带料 + 词缀挂钩（Material Economy & Affix Bias）

> 起草日期：2026-05-02
> 类型：游戏经济循环 + 数据基础设施 + 词缀关联
> 来源：玩家发现"打光材料后游戏卡死"，无正向获取渠道

## 背景与动机

当前材料只来自 2 处：
1. 首次推门一次性馈赠（`shop_screen.gd:103-107`）
2. 反噬副产物 1×灰 / 1×异种料（`forge_system.gd:115-121`）

无购买、无补给、无回赠。打光后必须靠反噬续命，明显违反"开放沙盒铺子"的体感。

同时发现底层短板：**没有 MaterialData 资源类**，材料 ID 是裸 `StringName` 散落在
`forge_system.gd / shop_screen.gd / forge_top_bar.gd / 7 份 recipe .tres` 中，命名也混乱
（`iron / jin / zhusha / yellow_paper / bone / hui / yi_zhong_liao` 英文+拼音混用）。

本次改动一次性解决：
- 引入 `MaterialData` 资源化
- 命名统一全拼音 snake_case
- 加灵石购料渠道（B）
- 加客人归还带料（C）
- 词缀按投料偏向（D · 温和系数，可调）

## 不在 scope 内
- 离线小本掉料（D 待 N5a polish）
- 多铺/采办商人事件（待 N6 经济）
- 词缀诡缀池单独抽（保持现有抽法，只调权重）

---

## 1 · MaterialData 资源化

### 新增 `godot/scripts/data/material_data.gd`

```gdscript
class_name MaterialData
extends Resource

@export var id: StringName            # 主键，全拼音 snake_case
@export var display_name: String       # 中文展示名（玩家可见）
@export var short_name: String         # 1 字简写（用于 LogFlow / TopBar 缩略）
@export var unit_price: int = 0        # 0 = 不可购买
@export var category: StringName       # &"common" / &"weird" / &"byproduct" / &"weird_byproduct"
@export var affix_bias: Dictionary = {} # path StringName → int weight bonus
```

### 新增 `godot/data/materials/` 7 个 .tres

| 新 ID | 旧 ID | display_name | short | price | category | affix_bias |
|---|---|---|---|---|---|---|
| `tie` | iron | 铁 | 铁 | 3 | common | sword:2, axe:1 |
| `jin` | jin | 金 | 金 | 2 | common | sword:1, talisman:1 |
| `zhu_sha` | zhusha | 朱砂 | 朱 | 8 | common | curse:3, talisman:2 |
| `huang_zhi` | yellow_paper | 黄纸 | 纸 | 5 | common | talisman:3, curse:1 |
| `gu` | bone | 骨 | 骨 | 12 | weird | curse:2, divination_plate:2 |
| `hui` | hui | 灰 | 灰 | 0 | byproduct | （无） |
| `yi` | yi_zhong_liao | 异种料 | 异 | 0 | weird_byproduct | _weird:5 |

**展示原则**：所有 玩家可见文本（modal 列表 / 投料行 / EventLog）使用 `display_name`，不出现 ID。

### 命名迁移

`save_migration.gd` 加 v→v+1 步骤：旧 ID → 新 ID 字典映射，
扫描存档 `materials` 字段 + 历史 EventLog `kind=forge_invest` 文本中的旧 ID 全替换。

```gdscript
const MATERIAL_ID_RENAME := {
    &"iron": &"tie",
    &"zhusha": &"zhu_sha",
    &"yellow_paper": &"huang_zhi",
    &"bone": &"gu",
    &"yi_zhong_liao": &"yi",
}
```

### 改动连锁

- `forge_top_bar.gd._short_name` 静态映射 → 改为 `DataRegistry.get(&"material", id).short_name`
- `forge_system.gd:115` 反噬 byproduct ID 改名 (`hui`/`yi`)
- `shop_screen.gd:103-107` 首次馈赠 ID 改名
- 7 份 recipe .tres 的 cost 字典 key 改名
- 所有测试文件 grep 替换

---

## 2 · 灵石购料 modal（B）

### 触发：TopBar 右侧加「采办」按钮

布局：`[配方下拉] [材料缩略] [采办] [闭门 ✕]`

字体 14，hover 朱红描边亮。

点 → ForgeScreen 弹 `MaterialShopDialog`（modal，遮罩 + 中央 panel）。

### Dialog 结构

```
┌─ 采办 ───────────────── ✕ ─┐
│ 灵石：123                    │
│ ─────────────────────────── │
│ 铁    库存:5  单价:3  [-1+] [买]│
│ 金    库存:8  单价:2  [-1+] [买]│
│ 朱砂  库存:2  单价:8  [-1+] [买]│
│ 黄纸  库存:6  单价:5  [-1+] [买]│
│ 骨    库存:0  单价:12 [-1+] [买]│
└─────────────────────────────┘
```

- 列表来源：`DataRegistry.list(&"material") where unit_price > 0`
- 数量 ± 调（最小 1，最大 99）
- 点「买」：扣灵石 + 加材料 + emit `materials_changed` + `spirit_stones_changed`
- 灵石不足或灵石 < unit_price × qty → 「买」按钮 disabled
- 关闭按钮 ✕

### EventLog

- kind: `shop_buy`
- color_key: `&"normal"`
- 文本: `采办 {display_name}×{qty}（-{cost}灵石）`
- LogFlow 因前缀非 `forge_` 不显示在炉房 — 这是 feature

---

## 3 · 客人归还带料（C）

### 触发点：`customer_system.gd` 归还结算分支

5 档结果中的 perfect / good / normal 按概率给料：

| 归还档 | 概率 | 给料池 | 数量 |
|---|---|---|---|
| perfect | 100% | {`gu`, `zhu_sha`} 随机 1 | 1 |
| good | 60% | {`tie`, `jin`} 随机 1 | 1 |
| normal | 30% | `tie` | 1 |
| bad | 0% | — | — |
| disaster | 0% | — | — |

**理由**：贴"老熟客顺手捎"叙事，~0.5 单位料 / 客 平衡（接 1 客 ≈ 烧半把）。

### EventLog

- 复用现有 `customer_return` kind
- 文本末尾追加 `（顺手捎了 {display_name}×1）`

---

## 4 · 词缀按投料偏向（D · 温和默认）

### 注入点：`forge_system.gd` roll 主词缀阶段

伪代码：

```gdscript
const AFFIX_BIAS_COEFFICIENT := 0.1   # 暴露常量，可调
# weight = base_weight × (1 + bias × COEFFICIENT)
# 朱砂 affix_bias[curse] = 3 → curse 系词缀权重 ×1.3

var bias_total: Dictionary = {}
for mid in materials_used:
    var md: MaterialData = DataRegistry.get(&"material", mid)
    for path in md.affix_bias:
        bias_total[path] = bias_total.get(path, 0) + md.affix_bias[path]

# roll 时按 affix.path_filter 查 bias_total，命中则 weight 乘 (1 + bias × COEFFICIENT)
```

**温和系数 0.1**：bias=3 → +30% 权重，bias=5（异种料 _weird）→ +50%。
**可调性**：常量 `AFFIX_BIAS_COEFFICIENT` 在 forge_system.gd 顶部，未来调平衡只改一行。

### 词缀 path 命名约定

材料 affix_bias 中的 path 需匹配现有 `AffixData.path_filter` 中使用的值：
- `sword / axe / talisman / curse / divination_plate / alchemy / eat`（已在 codebase）
- 新增 `_weird` 元 path：词缀 path_filter 含 `_weird` 视为诡缀，异种料 +5 强偏

如现有 affix.path_filter 字段不能直接表达 `_weird`，则在 forge_system 注入逻辑里做：
"affix.tier == ARCANE 视为命中 _weird"。**实现选其一即可**，T4 实施时按现状最小改动选。

---

## 文件改动汇总

### 新增
- `godot/scripts/data/material_data.gd` + .uid
- `godot/data/materials/` 7 个 .tres（tie / jin / zhu_sha / huang_zhi / gu / hui / yi）
- `godot/scripts/ui/material_shop_dialog.gd` + .tscn + .uid
- `godot/scripts/test/test_material_data.gd` + .tscn + .uid（资源加载 + 字段校验）
- `godot/scripts/test/test_material_shop_dialog_smoke.gd` + .tscn + .uid
- `godot/scripts/test/test_customer_return_drop.gd` + .tscn + .uid
- `godot/scripts/test/test_affix_bias.gd` + .tscn + .uid

### 修改
- `godot/scripts/core/data_registry.gd` — 注册 material 类型
- `godot/scripts/core/save_migration.gd` — v→v+1 ID 迁移
- `godot/scripts/systems/forge_system.gd` — byproduct ID + affix bias 注入
- `godot/scripts/systems/customer_system.gd` — 归还带料
- `godot/scripts/ui/forge_top_bar.gd` — 采办按钮 + short_name 改读 MaterialData
- `godot/scripts/ui/forge_screen.gd` — buy_pressed 信号 → 弹 modal
- `godot/scripts/ui/shop_screen.gd` — 首次馈赠 ID 改名
- 7 份 `godot/data/recipes/*.tres` — cost key 改名

### 不动
- AffixData 类（仅利用 path_filter / tier 字段）
- ForgeResult 类
- TimingWindow / ResultOverlay / 所有炉房 UI（B 仅 TopBar 加 1 个按钮 + 1 个 modal）

---

## 验收标准（DoD）

1. 推门进铺，TopBar 右侧可见「采办」按钮
2. 点采办 → modal 列出 5 种可购材料（铁/金/朱砂/黄纸/骨），灰/异种料不显示
3. 选铁 ×2 点买 → 扣 6 灵石，铁 +2，EventLog 加 `采办 铁×2（-6灵石）`
4. 灵石不足时买按钮 disabled
5. 客人完美归还 → EventLog 文本末尾有「顺手捎了 骨×1」或「朱砂×1」
6. 投朱砂烧符篆 → 多次试验，咒/言系词缀比不投朱砂时显著高
7. 旧存档（含 `iron` 等旧 ID）打开后自动迁移为新 ID，材料数量保留
8. 全套测试 0 FAIL（含 4 个新 test）
9. README 进度行追加

---

## 风险与回滚

- **存档迁移破坏**：v→v+1 一次性单向。万一迁移脚本 bug，玩家旧档可能丢材料。**对冲**：迁移前自动备份 .save.bak.v{n}，迁移失败保留旧版本回滚
- **affix_bias 失衡**：温和 0.1 系数已留空间。如玩家反映"投朱砂没感觉"或"诡缀刷屏"，调常量
- **rename 漏改**：grep 全 codebase 后再加 1 个测试 `test_no_legacy_material_ids` 扫描所有 .gd / .tres 不出现旧 ID 字面量
