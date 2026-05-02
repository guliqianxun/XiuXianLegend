# 材料经济 v1 实施计划（MaterialData + 灵石购料 + 客人带料 + 词缀挂钩）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 引入 MaterialData 资源化 + 命名统一（全拼音），加灵石购料 / 客人归还带料 / 投料影响词缀偏向三条经济回路。

**Architecture:** MaterialData 走 DataRegistry，与现有 affix/recipe/customer 同模式。SaveSystem 加 v10→v11 迁移。UI 层只在 ForgeTopBar 加 1 按钮 + 弹 1 modal，不动 LogFlow / BottomBar。

**Tech Stack:** Godot 4.6, GDScript, Resource (.tres), DataRegistry autoload, SaveSystem migration, ReturnResolver outcomes。

**Spec ref:** `docs/superpowers/specs/2026-05-02-material-economy-and-affix-bias.md`

**Branch:** `polish/material-economy`（已创建）

---

### Task 1: MaterialData 资源类 + 7 份 .tres + DataRegistry 注册

**Files:**
- Create: `godot/scripts/data/material_data.gd` + `.uid`
- Create: `godot/data/materials/{tie,jin,zhu_sha,huang_zhi,gu,hui,yi}.tres`
- Modify: `godot/scripts/core/data_registry.gd:11` — INDEX_DIRS 加 `&"material"`
- Test: `godot/scripts/test/test_material_data.gd` + `.tscn` + `.uid`

- [ ] **Step 1: 写 MaterialData 类**

```gdscript
# godot/scripts/data/material_data.gd
class_name MaterialData
extends Resource
## 材料静态数据。N6+ 经济：unit_price 决定可购买性，affix_bias 影响开炉词缀权重。

@export var id: StringName               ## 主键（全拼音 snake_case）
@export var display_name: String          ## 玩家可见中文名（如 "铁" / "朱砂"）
@export var short_name: String            ## 1 字简写，用于 LogFlow / TopBar 缩略
@export var unit_price: int = 0           ## 单价灵石；0 = 不可购买（如 hui/yi）
@export var category: StringName          ## &"common" / &"weird" / &"byproduct" / &"weird_byproduct"
@export var affix_bias: Dictionary = {}   ## { path StringName : int weight bonus }
```

`.uid` 文件内容 `uid://material_data_v1`（Godot 会重写实际 UID，先放占位）。

- [ ] **Step 2: 写 7 份 .tres（手写格式）**

每个 .tres 模板（以 tie.tres 为例）：

```
[gd_resource type="Resource" script_class="MaterialData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/material_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"tie"
display_name = "铁"
short_name = "铁"
unit_price = 3
category = &"common"
affix_bias = {
&"sword": 2,
&"axe": 1,
}
```

7 份完整数据：

| 文件 | id | display_name | short_name | unit_price | category | affix_bias |
|---|---|---|---|---|---|---|
| tie.tres | `&"tie"` | "铁" | "铁" | 3 | `&"common"` | `{&"sword":2, &"axe":1}` |
| jin.tres | `&"jin"` | "金" | "金" | 2 | `&"common"` | `{&"sword":1, &"talisman":1}` |
| zhu_sha.tres | `&"zhu_sha"` | "朱砂" | "朱" | 8 | `&"common"` | `{&"curse":3, &"talisman":2}` |
| huang_zhi.tres | `&"huang_zhi"` | "黄纸" | "纸" | 5 | `&"common"` | `{&"talisman":3, &"curse":1}` |
| gu.tres | `&"gu"` | "骨" | "骨" | 12 | `&"weird"` | `{&"curse":2, &"divination_plate":2}` |
| hui.tres | `&"hui"` | "灰" | "灰" | 0 | `&"byproduct"` | `{}` |
| yi.tres | `&"yi"` | "异种料" | "异" | 0 | `&"weird_byproduct"` | `{&"_weird":5}` |

- [ ] **Step 3: DataRegistry 注册**

修改 `godot/scripts/core/data_registry.gd:11`，在 INDEX_DIRS 字典加一行：

```gdscript
const INDEX_DIRS := {
	&"gear": "res://data/gear",
	&"affix": "res://data/affixes",
	&"recipe": "res://data/recipes",
	&"customer": "res://data/customers",
	&"gupu": "res://data/gupu",
	&"su": "res://data/sus",
	&"narrative": "res://data/narratives",
	&"faction": "res://data/factions",
	&"material": "res://data/materials",  # +
}
```

- [ ] **Step 4: 写测试 test_material_data**

```gdscript
# godot/scripts/test/test_material_data.gd
extends Node
## MaterialData 资源加载 + 字段校验

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_seven_materials_load()
	_test_field_values()
	_test_affix_bias_present()
	_test_only_purchasable_have_price()
	print("\n========== test_material_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)

func _test_seven_materials_load() -> void:
	for mid in [&"tie", &"jin", &"zhu_sha", &"huang_zhi", &"gu", &"hui", &"yi"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md != null, "%s loads" % mid)

func _test_field_values() -> void:
	var tie: MaterialData = DataRegistry.get_resource(&"material", &"tie") as MaterialData
	_assert(tie.display_name == "铁", "tie display_name=铁")
	_assert(tie.short_name == "铁", "tie short_name=铁")
	_assert(tie.unit_price == 3, "tie unit_price=3")
	_assert(tie.category == &"common", "tie category=common")

func _test_affix_bias_present() -> void:
	var zs: MaterialData = DataRegistry.get_resource(&"material", &"zhu_sha") as MaterialData
	_assert(zs.affix_bias.get(&"curse", 0) == 3, "zhu_sha curse bias=3")
	var hui: MaterialData = DataRegistry.get_resource(&"material", &"hui") as MaterialData
	_assert(hui.affix_bias.is_empty(), "hui affix_bias empty")

func _test_only_purchasable_have_price() -> void:
	for mid in [&"hui", &"yi"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md.unit_price == 0, "%s unit_price=0 (not purchasable)" % mid)
	for mid in [&"tie", &"jin", &"zhu_sha", &"huang_zhi", &"gu"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md.unit_price > 0, "%s unit_price>0 (purchasable)" % mid)
```

`.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/test/test_material_data.gd" id="1"]
[node name="TestMaterialData" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: 跑测试**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_material_data.tscn 2>&1 | tail -20
```

Expected: `PASS: 13  FAIL: 0`

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/data/material_data.gd* godot/data/materials/ godot/scripts/core/data_registry.gd godot/scripts/test/test_material_data* godot/scenes/test/test_material_data.tscn
git commit -m "feat(material): MaterialData 资源类 + 7 份 .tres + DataRegistry 注册"
```

---

### Task 2: 命名迁移（save_system v10→v11 + 全 codebase rename）

**Files:**
- Modify: `godot/scripts/core/save_system.gd:8` SAVE_VERSION → 11，加 `_migrate_v10_to_v11`
- Modify: `godot/scripts/systems/forge_system.gd:115-117` byproduct ID
- Modify: `godot/scripts/ui/shop_screen.gd:103-107` 首次馈赠 ID
- Modify: `godot/scripts/ui/forge_top_bar.gd._short_name` → 改读 MaterialData
- Modify: 7 份 `godot/data/recipes/*.tres` cost key 改名
- Modify: 受影响测试文件
- Test: 现有 test_save_migration 加 v10→v11 case

- [ ] **Step 1: SAVE_VERSION 提升 + 迁移函数**

`save_system.gd` 顶部：`const SAVE_VERSION := 11`

migrate while 循环加分支：
```gdscript
11:
    payload = _migrate_v10_to_v11(payload)
```

新函数：

```gdscript
const MATERIAL_ID_RENAME_V11 := {
	"iron": "tie",
	"zhusha": "zhu_sha",
	"yellow_paper": "huang_zhi",
	"bone": "gu",
	"yi_zhong_liao": "yi",
}

func _migrate_v10_to_v11(p: Dictionary) -> Dictionary:
	# 材料命名统一全拼音
	var mats: Dictionary = p.get("materials", {})
	var new_mats: Dictionary = {}
	for k in mats:
		var new_k: String = MATERIAL_ID_RENAME_V11.get(String(k), String(k))
		new_mats[new_k] = mats[k]
	p["materials"] = new_mats
	p["version"] = 11
	return p
```

- [ ] **Step 2: forge_system byproduct rename**

`forge_system.gd:115-117` 改：

```gdscript
result.byproduct = &"hui"   # 不变
# ...
result.byproduct = &"yi"    # 原 yi_zhong_liao
```

- [ ] **Step 3: shop_screen 首次馈赠 rename**

`shop_screen.gd:101-107`：

```gdscript
if GameState.material_count(&"tie") == 0 and GameState.material_count(&"jin") == 0:
	GameState.add_material(&"tie", 8)
	GameState.add_material(&"jin", 16)
	GameState.add_material(&"zhu_sha", 6)
	GameState.add_material(&"huang_zhi", 6)
	GameState.add_material(&"gu", 4)
```

- [ ] **Step 4: forge_top_bar._short_name → 读 MaterialData**

替换静态映射函数：

```gdscript
static func _short_name(material_id: StringName) -> String:
	var md: MaterialData = DataRegistry.get_resource(&"material", material_id) as MaterialData
	return md.short_name if md != null else String(material_id)
```

- [ ] **Step 5: 7 份 recipe .tres rename**

逐一打开 `godot/data/recipes/*.tres`，把 cost 字典 key 中的旧 ID 替换：
- `&"iron"` → `&"tie"`
- `&"zhusha"` → `&"zhu_sha"`
- `&"yellow_paper"` → `&"huang_zhi"`
- `&"bone"` → `&"gu"`
- `&"yi_zhong_liao"` → `&"yi"`
- 其他不变

可用 sed 批量但要确认范围：

```bash
for f in godot/data/recipes/*.tres; do
  sed -i 's/&"iron"/\&"tie"/g; s/&"zhusha"/\&"zhu_sha"/g; s/&"yellow_paper"/\&"huang_zhi"/g; s/&"bone"/\&"gu"/g; s/&"yi_zhong_liao"/\&"yi"/g' "$f"
done
```

⚠️ 注意：bone_blade.tres 的 `id = &"bone_blade"` **不动**（这是装备 id，不是材料 id），sed 会误伤吗？检查：sed 只换完整 `&"bone"` 字面（带引号），`&"bone_blade"` 不会被匹配。但保险起见，sed 后用 `git diff` 人工 check 这些文件。

- [ ] **Step 6: 受影响测试文件 rename**

```bash
for f in godot/scripts/test/test_forge_one_full.gd \
         godot/scripts/test/test_forge_quality_roll.gd \
         godot/scripts/test/test_forge_console_smoke.gd \
         godot/scripts/test/test_forge_backlash.gd \
         godot/scripts/test/test_forge_qiao_cheng.gd \
         godot/scripts/test/test_materials_inventory.gd \
         godot/scripts/test/test_offline_simulator.gd \
         godot/scripts/test/test_recipe_data.gd \
         godot/scripts/test/test_recipe_data_loads.gd \
         godot/scripts/test/test_resonance_buffs.gd \
         godot/scripts/generators/recipe_generator.gd \
         godot/scripts/systems/forge_result.gd; do
  sed -i 's/&"iron"/\&"tie"/g; s/&"zhusha"/\&"zhu_sha"/g; s/&"yellow_paper"/\&"huang_zhi"/g; s/&"bone"/\&"gu"/g; s/&"yi_zhong_liao"/\&"yi"/g' "$f"
done
```

⚠️ 同样：人工 grep 一遍 "iron"（不带 &）确保没漏字符串，比如 `"iron×2"` 类显示文本。

- [ ] **Step 7: 加 save_migration v10→v11 test case**

`godot/scripts/test/test_save_migration.gd` 末尾加：

```gdscript
func _test_v10_to_v11_material_rename() -> void:
	var v10 := {
		"version": 10,
		"materials": {
			"iron": 5,
			"zhusha": 3,
			"yellow_paper": 2,
			"bone": 1,
			"yi_zhong_liao": 1,
			"jin": 8,
			"hui": 2,
		},
	}
	var migrated := SaveSystem.migrate(v10)
	_assert(migrated.version == SaveSystem.SAVE_VERSION, "v10→latest version bumped")
	var m: Dictionary = migrated.materials
	_assert(m.get("tie", 0) == 5, "iron→tie value preserved")
	_assert(m.get("zhu_sha", 0) == 3, "zhusha→zhu_sha")
	_assert(m.get("huang_zhi", 0) == 2, "yellow_paper→huang_zhi")
	_assert(m.get("gu", 0) == 1, "bone→gu")
	_assert(m.get("yi", 0) == 1, "yi_zhong_liao→yi")
	_assert(m.get("jin", 0) == 8, "jin unchanged")
	_assert(m.get("hui", 0) == 2, "hui unchanged")
	_assert(not m.has("iron"), "old iron key removed")
```

并在 `_ready()` 加 `_test_v10_to_v11_material_rename()` 调用。

- [ ] **Step 8: 跑全套回归**

```bash
for t in test_material_data test_save_migration test_forge_console_smoke test_forge_one_full test_materials_inventory test_recipe_data test_recipe_data_loads test_resonance_buffs playtest_n2_smoke playtest_n4_smoke; do
  result=$("/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

Expected: 全 `FAIL: 0`

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(material): 命名统一全拼音 + save v10→v11 迁移"
```

---

### Task 3: MaterialShopDialog modal + TopBar 采办按钮（B）

**Files:**
- Create: `godot/scripts/ui/material_shop_dialog.gd` + `.tscn` + `.uid`
- Modify: `godot/scripts/ui/forge_top_bar.gd` 加采办按钮 + buy_pressed 信号
- Modify: `godot/scenes/ui/forge_top_bar.tscn` 加 BuyButton 节点
- Modify: `godot/scripts/ui/forge_screen.gd` 接 buy_pressed → 弹 modal
- Test: `godot/scripts/test/test_material_shop_dialog_smoke.gd` + `.tscn` + `.uid`

- [ ] **Step 1: MaterialShopDialog 脚本**

```gdscript
# godot/scripts/ui/material_shop_dialog.gd
class_name MaterialShopDialog
extends Control
## 灵石购料 modal。列出所有 unit_price > 0 的 MaterialData 行。

const MAX_QTY := 99

@onready var _list: VBoxContainer = $Frame/VBox/ScrollContainer/ListVBox
@onready var _stones_label: Label = $Frame/VBox/StonesLabel
@onready var _close_btn: Button = $Frame/VBox/HeaderHBox/CloseButton
var _qty_state: Dictionary = {}  # mid -> int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_btn.pressed.connect(_on_close)
	_refresh_stones()
	_build_rows()
	EventBus.spirit_stones_changed.connect(_on_stones_changed)
	EventBus.materials_changed.connect(_on_materials_changed)

func _on_close() -> void:
	queue_free()

func _refresh_stones() -> void:
	_stones_label.text = "灵石：%d" % GameState.spirit_stones

func _on_stones_changed(_v: int) -> void:
	_refresh_stones()
	_refresh_buy_buttons()

func _on_materials_changed(_mid: StringName, _v: int) -> void:
	_refresh_rows()

func _build_rows() -> void:
	for child in _list.get_children():
		child.queue_free()
	var ids: Array = DataRegistry.ids_of(&"material")
	ids.sort()
	for mid in ids:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		if md == null or md.unit_price <= 0:
			continue
		_qty_state[mid] = 1
		_list.add_child(_make_row(md))

func _make_row(md: MaterialData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = md.display_name
	name_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(name_label)
	var stock_label := Label.new()
	stock_label.name = "Stock"
	stock_label.text = "库存:%d" % GameState.material_count(md.id)
	stock_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(stock_label)
	var price_label := Label.new()
	price_label.text = "单价:%d" % md.unit_price
	price_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(price_label)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(28, 0)
	var captured_mid: StringName = md.id
	minus.pressed.connect(func() -> void: _adjust_qty(captured_mid, -1, row))
	row.add_child(minus)
	var qty_label := Label.new()
	qty_label.name = "Qty"
	qty_label.text = "1"
	qty_label.custom_minimum_size = Vector2(36, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 0)
	plus.pressed.connect(func() -> void: _adjust_qty(captured_mid, 1, row))
	row.add_child(plus)
	var buy := Button.new()
	buy.name = "Buy"
	buy.text = "买"
	buy.custom_minimum_size = Vector2(48, 0)
	buy.pressed.connect(func() -> void: _on_buy(captured_mid, md))
	row.add_child(buy)
	_update_buy_state(buy, md, _qty_state[md.id])
	return row

func _adjust_qty(mid: StringName, delta: int, row: HBoxContainer) -> void:
	var new_qty: int = clampi(_qty_state.get(mid, 1) + delta, 1, MAX_QTY)
	_qty_state[mid] = new_qty
	(row.get_node("Qty") as Label).text = str(new_qty)
	var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
	_update_buy_state(row.get_node("Buy"), md, new_qty)

func _update_buy_state(btn: Button, md: MaterialData, qty: int) -> void:
	var cost: int = md.unit_price * qty
	btn.disabled = GameState.spirit_stones < cost

func _on_buy(mid: StringName, md: MaterialData) -> void:
	var qty: int = _qty_state.get(mid, 1)
	var cost: int = md.unit_price * qty
	if GameState.spirit_stones < cost:
		return
	GameState.add_currency(&"spirit_stones", -cost)
	GameState.add_material(mid, qty)
	EventLog.add_entry(&"shop_buy", "采办 %s×%d（-%d灵石）" % [md.display_name, qty, cost], &"normal")
	Sfx.play_paper_flutter()

func _refresh_rows() -> void:
	# 每行 stock 标签按当前库存刷新
	for row in _list.get_children():
		var stock: Label = row.get_node("Stock")
		var name_label: Label = row.get_child(0)
		var md: MaterialData = _find_md_by_display(name_label.text)
		if md != null:
			stock.text = "库存:%d" % GameState.material_count(md.id)

func _refresh_buy_buttons() -> void:
	for row in _list.get_children():
		var name_label: Label = row.get_child(0)
		var md: MaterialData = _find_md_by_display(name_label.text)
		if md == null: continue
		var btn: Button = row.get_node("Buy")
		_update_buy_state(btn, md, _qty_state.get(md.id, 1))

func _find_md_by_display(disp: String) -> MaterialData:
	for mid in DataRegistry.ids_of(&"material"):
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		if md != null and md.display_name == disp:
			return md
	return null
```

- [ ] **Step 2: MaterialShopDialog .tscn**

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/ui/material_shop_dialog.gd" id="1"]

[node name="MaterialShopDialog" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
process_mode = 3
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.7)

[node name="Frame" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -180.0
offset_right = 200.0
offset_bottom = 180.0

[node name="VBox" type="VBoxContainer" parent="Frame"]
theme_override_constants/separation = 8

[node name="HeaderHBox" type="HBoxContainer" parent="Frame/VBox"]

[node name="Title" type="Label" parent="Frame/VBox/HeaderHBox"]
text = "—— 采　办 ——"
size_flags_horizontal = 3
horizontal_alignment = 1
theme_override_font_sizes/font_size = 18

[node name="CloseButton" type="Button" parent="Frame/VBox/HeaderHBox"]
text = "✕"
custom_minimum_size = Vector2(32, 28)

[node name="StonesLabel" type="Label" parent="Frame/VBox"]
text = "灵石：0"
horizontal_alignment = 1

[node name="Sep" type="HSeparator" parent="Frame/VBox"]

[node name="ScrollContainer" type="ScrollContainer" parent="Frame/VBox"]
custom_minimum_size = Vector2(380, 240)

[node name="ListVBox" type="VBoxContainer" parent="Frame/VBox/ScrollContainer"]
size_flags_horizontal = 3
theme_override_constants/separation = 6
```

- [ ] **Step 3: ForgeTopBar 加采办按钮**

`forge_top_bar.gd` 顶部 signal 加：

```gdscript
signal buy_pressed
```

`_ready` 末尾连接：

```gdscript
@onready var _buy_button: Button = $BuyButton
# ...
_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
```

修改 `forge_top_bar.tscn`，在 CloseButton **之前** 插入：

```
[node name="BuyButton" type="Button" parent="."]
text = "采办"
custom_minimum_size = Vector2(56, 28)
```

注意原 .tscn 是 HBox 排列，BuyButton 节点要插在 CloseButton 节点定义之前以保证显示顺序。

- [ ] **Step 4: ForgeScreen 接 buy_pressed**

`forge_screen.gd` 在 `_ready` connect 处加：

```gdscript
_top_bar.buy_pressed.connect(_on_buy_pressed)
```

新方法：

```gdscript
const _SHOP_DIALOG_SCENE := preload("res://scenes/ui/material_shop_dialog.tscn")

func _on_buy_pressed() -> void:
	var dlg := _SHOP_DIALOG_SCENE.instantiate()
	add_child(dlg)
```

- [ ] **Step 5: smoke test**

```gdscript
# godot/scripts/test/test_material_shop_dialog_smoke.gd
extends Node
## MaterialShopDialog 烟测

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _test_dialog_loads_and_shows_purchasable_only()
	await _test_buy_decrements_stones_increments_material()
	await _test_disabled_when_insufficient_stones()
	print("\n========== test_material_shop_dialog_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _test_dialog_loads_and_shows_purchasable_only() -> void:
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	_assert(pkd != null, "dialog scene loadable")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var list: VBoxContainer = dlg.get_node("Frame/VBox/ScrollContainer/ListVBox")
	# 5 个可购材料：tie/jin/zhu_sha/huang_zhi/gu
	_assert(list.get_child_count() == 5, "5 purchasable rows (got %d)" % list.get_child_count())
	dlg.queue_free()
	await get_tree().process_frame

func _test_buy_decrements_stones_increments_material() -> void:
	GameState.spirit_stones = 100
	var before_tie: int = GameState.material_count(&"tie")
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	dlg._on_buy(&"tie", DataRegistry.get_resource(&"material", &"tie"))
	_assert(GameState.material_count(&"tie") == before_tie + 1, "tie +1")
	_assert(GameState.spirit_stones == 97, "stones -3 (was 100)")
	dlg.queue_free()
	await get_tree().process_frame

func _test_disabled_when_insufficient_stones() -> void:
	GameState.spirit_stones = 1  # 不够买 tie (3)
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var list: VBoxContainer = dlg.get_node("Frame/VBox/ScrollContainer/ListVBox")
	for row in list.get_children():
		var btn: Button = row.get_node("Buy")
		_assert(btn.disabled, "buy disabled when stones insufficient")
		break  # 一行验证够了
	dlg.queue_free()
	await get_tree().process_frame
```

`.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/test/test_material_shop_dialog_smoke.gd" id="1"]
[node name="TestMaterialShopDialogSmoke" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 6: 跑测试**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_material_shop_dialog_smoke.tscn 2>&1 | tail -15
```

Expected: `PASS: 5  FAIL: 0`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(material): MaterialShopDialog modal + TopBar 采办按钮（B 灵石购料）"
```

---

### Task 4: 客人归还带料（C）

**Files:**
- Modify: `godot/scripts/ui/shop_screen.gd:226-234` 在 outcome 分支加给料 + EventLog 文本拼接
- Test: `godot/scripts/test/test_customer_return_drop.gd` + `.tscn` + `.uid`

- [ ] **Step 1: shop_screen 加给料逻辑**

定位 `shop_screen.gd:226` 起的 outcome 分支，在 `EncounterState.resolve_return(...)` 之后插入：

```gdscript
# C · 客人归还带料：GREAT_DEED 100% / OK_RETURN 30%
var dropped_material: StringName = &""
match outcome:
	ReturnResolver.Outcome.GREAT_DEED:
		var pool := [&"gu", &"zhu_sha"]
		dropped_material = pool[rng.randi_range(0, pool.size() - 1)]
		GameState.add_material(dropped_material, 1)
	ReturnResolver.Outcome.OK_RETURN:
		if rng.randf() < 0.30:
			dropped_material = &"tie"
			GameState.add_material(dropped_material, 1)

if dropped_material != &"":
	var md: MaterialData = DataRegistry.get_resource(&"material", dropped_material) as MaterialData
	var disp: String = md.display_name if md != null else String(dropped_material)
	EventLog.add_entry(&"customer_return_drop", "%s 顺手捎了 %s×1" % [c.display_name if c != null else "客人", disp], &"normal")
```

- [ ] **Step 2: 写测试**

```gdscript
# godot/scripts/test/test_customer_return_drop.gd
extends Node
## 客人归还带料：GREAT_DEED 必给，OK_RETURN 30%，其他不给

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_great_deed_gives_weird_material()
	_test_ok_return_sometimes_gives_tie()
	_test_damaged_gives_nothing()
	print("\n========== test_customer_return_drop ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _simulate_drop(outcome: int, seed_val: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var dropped: StringName = &""
	match outcome:
		ReturnResolver.Outcome.GREAT_DEED:
			var pool := [&"gu", &"zhu_sha"]
			dropped = pool[rng.randi_range(0, pool.size() - 1)]
		ReturnResolver.Outcome.OK_RETURN:
			if rng.randf() < 0.30:
				dropped = &"tie"
	return dropped

func _test_great_deed_gives_weird_material() -> void:
	# 多 seed 验证：GREAT_DEED 必给 gu 或 zhu_sha
	for s in range(10):
		var d := _simulate_drop(ReturnResolver.Outcome.GREAT_DEED, s)
		_assert(d == &"gu" or d == &"zhu_sha", "seed %d GREAT_DEED → gu/zhu_sha (got %s)" % [s, d])

func _test_ok_return_sometimes_gives_tie() -> void:
	var hits := 0
	var trials := 1000
	for s in range(trials):
		var d := _simulate_drop(ReturnResolver.Outcome.OK_RETURN, s)
		if d == &"tie":
			hits += 1
	# 期望 ~30% ±5%
	var ratio: float = float(hits) / trials
	_assert(ratio > 0.25 and ratio < 0.35, "OK_RETURN tie ratio ~30%% (got %.3f over %d trials)" % [ratio, trials])

func _test_damaged_gives_nothing() -> void:
	for s in range(10):
		var d := _simulate_drop(ReturnResolver.Outcome.DAMAGED, s)
		_assert(d == &"", "seed %d DAMAGED → empty (got %s)" % [s, d])
```

`.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/test/test_customer_return_drop.gd" id="1"]
[node name="TestCustomerReturnDrop" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: 跑测试 + n4 回归**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_customer_return_drop.tscn 2>&1 | tail -15
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/playtest_n4_smoke.tscn 2>&1 | tail -3
```

Expected: 烟测 21 PASS / 0 FAIL；n4 仍 0 FAIL。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(customer): 归还带料 — GREAT_DEED 必给诡材，OK_RETURN 30% 给铁（C）"
```

---

### Task 5: 词缀按投料偏向（D）

**Files:**
- Modify: `godot/scripts/systems/forge_system.gd` 加 `AFFIX_BIAS_COEFFICIENT` 常量 + roll 时 weight 注入
- Test: `godot/scripts/test/test_affix_bias.gd` + `.tscn` + `.uid`

- [ ] **Step 1: 读现有 forge_system roll 词缀代码**

打开 `godot/scripts/systems/forge_system.gd`，定位 roll 主词缀的函数（grep `roll_main_affix\|main_affix`）。**实施 agent 必须先读**，因为本 plan 没贴出该函数现状。

- [ ] **Step 2: 注入 affix_bias**

在 `forge_system.gd` 顶部加常量：

```gdscript
const AFFIX_BIAS_COEFFICIENT := 0.1   ## 调平衡只改这一行
```

新增辅助函数：

```gdscript
## 累加投料的 affix_bias，返回 { path: total_bonus }
static func _compute_affix_bias(materials_used: Dictionary) -> Dictionary:
	var total: Dictionary = {}
	for mid in materials_used:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		if md == null:
			continue
		for path in md.affix_bias:
			total[path] = total.get(path, 0) + int(md.affix_bias[path])
	return total

## 给定一组 affix 候选 + bias dict，返回各 affix 的修正权重
static func _apply_bias_to_weight(affix: AffixData, bias: Dictionary) -> float:
	var w: float = affix.weight
	# path_filter 命中
	for path in affix.path_filter:
		if bias.has(path):
			w *= 1.0 + float(bias[path]) * AFFIX_BIAS_COEFFICIENT
	# _weird 元 path：tier=ARCANE 的词缀视为命中
	if bias.has(&"_weird") and affix.min_tier == AffixData.Tier.ARCANE:
		w *= 1.0 + float(bias[&"_weird"]) * AFFIX_BIAS_COEFFICIENT
	return w
```

在 roll 主词缀的循环里把 `affix.weight` 替换为 `_apply_bias_to_weight(affix, bias_total)`，并在循环前调一次 `var bias_total := _compute_affix_bias(materials_used)`。

⚠️ 实施 agent 注意：`materials_used` 应来自 `forge_one(...)` 的入参 recipe.cost + selected_optional 合并。如现有 forge_one 没把这个 dict 传到 roll 函数，需要加参数链路。

- [ ] **Step 3: 写测试**

```gdscript
# godot/scripts/test/test_affix_bias.gd
extends Node
## ForgeSystem._apply_bias_to_weight：投料 → 词缀权重偏向

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_compute_bias_sums_materials()
	_test_apply_bias_increases_path_weight()
	_test_apply_bias_no_match_unchanged()
	_test_weird_arcane_match()
	print("\n========== test_affix_bias ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _test_compute_bias_sums_materials() -> void:
	var used := {&"zhu_sha": 2, &"huang_zhi": 1}
	var b := ForgeSystem._compute_affix_bias(used)
	# zhu_sha curse=3 + huang_zhi curse=1 = 4
	# zhu_sha talisman=2 + huang_zhi talisman=3 = 5
	_assert(b.get(&"curse", 0) == 4, "curse bias=4 (got %d)" % b.get(&"curse", 0))
	_assert(b.get(&"talisman", 0) == 5, "talisman bias=5 (got %d)" % b.get(&"talisman", 0))

func _test_apply_bias_increases_path_weight() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.path_filter = [&"curse"]
	var bias := {&"curse": 3}  # → ×(1 + 3*0.1) = ×1.3
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.3) < 0.001, "curse +30%% (got %.3f)" % w)

func _test_apply_bias_no_match_unchanged() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.path_filter = [&"sword"]
	var bias := {&"curse": 5}
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.0) < 0.001, "no path match → weight unchanged (got %.3f)" % w)

func _test_weird_arcane_match() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.min_tier = AffixData.Tier.ARCANE
	var bias := {&"_weird": 5}  # → ×(1 + 5*0.1) = ×1.5
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.5) < 0.001, "ARCANE matches _weird (got %.3f)" % w)
```

`.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/test/test_affix_bias.gd" id="1"]
[node name="TestAffixBias" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: 跑测试 + 全套回归**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_affix_bias.tscn 2>&1 | tail -10
for t in test_affix_system test_forge_one_full test_forge_quality_roll playtest_n2_smoke; do
  result=$("/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

Expected: affix_bias 5 PASS / 0 FAIL；其他 0 FAIL。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(forge): 投料 → 词缀权重偏向（D · 系数 0.1 温和默认）"
```

---

### Task 6: 全套回归 + README 进度

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 全套回归**

```bash
for t in test_material_data test_save_migration test_material_shop_dialog_smoke test_customer_return_drop test_affix_bias \
         test_forge_console_smoke test_forge_one_full test_forge_quality_roll test_event_log test_hud_visibility \
         test_main_menu_smoke test_codex_placement test_pause_menu_smoke test_shop_rules test_resonance \
         test_pattern_buffs test_star_brushes test_sfx_screenfx test_affix_system test_materials_inventory \
         playtest_n2_smoke playtest_n4_smoke playtest_n7_smoke playtest_n7b_smoke playtest_n8_smoke playtest_n9_weird_codex_smoke; do
  result=$("/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

Expected: 全部 `FAIL: 0`

- [ ] **Step 2: README 加进度行**

打开 `README.md`，在「炉房 UI 重构 v1」行后插入：

```
- ✅ 材料经济 v1：MaterialData 资源化 + 命名统一全拼音 + 灵石采办 modal + 客人 GREAT_DEED 必给诡材 / OK_RETURN 30% 给铁 + 投料偏向词缀（系数 0.1 可调）
```

- [ ] **Step 3: Commit + DoD 汇报**

```bash
git add README.md
git commit -m "docs(material): README 进度更新（材料经济 v1）"
```

汇报：
- DoD 1-9 项是否过
- 全套测试 0 FAIL 数字
- 文件改动 stat（git diff master..HEAD --stat）
