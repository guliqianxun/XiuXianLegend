# N4 问道门客 v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 N3 留下的"装备入器谱然后呢"循环补完——客人推门进来求借兵器，玩家选一件装备借出，过一段时间客人带着履历归来（或不归来）。MVP 范围：**3 类客人节奏（常/罕/怪）+ 借出/拒绝/回信 5 档结果 + 装备 status 流转 + 履历追加 + 在线节奏定时器**。深夜/离线/打听/名望影响 延后到 N5；怪客盲盒身份 v2 延后到 N5。

**Architecture:**
- **数据**：3 个 starter CustomerData .tres（苏家娘子/小孟跑料/蒙面客）
- **逻辑层**：`CustomerSpawner`（autoload，在线 5-15 min 泊松节奏 emit customer_arrived）+ `EncounterState`（autoload，跟踪当前 pending 客人 + per-gear lent 记录）+ `ReturnResolver`（静态类，按 CustomerData.tier 概率表计算 outcome）
- **UI 层**：`CustomerArrivalPanel`（屏幕底部滑入，显示客人剪影+诉求+酬金+借/拒按钮）+ `LendDialog`（从 GameState.inventory 选 IN_SHOP 状态装备）+ `ReturnNotice`（浮窗：装备 X 归来 + outcome 描述）
- **集成**：客人借走 → `GearInstance.status = LENT` + history append；归还 → status 回 IN_SHOP + 履历追加；不归还 → status = NOT_RETURNED 不再可派
- **counter 区域**：加"接客"button（手动触发 spawn，便于调试 + 玩家主动招客）

**Tech Stack:**
- Godot 4.6 GDScript
- 测试：headless `.tscn` + `_assert/_ok/_bad`
- Godot binary: `D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe`
- 严格类型 `mini`/`maxi`/`clampi`；多行 `if/else`；`Variant` 接 RefCounted-via-Resource-signal

---

## 前置依赖检查

执行前请确认：
- 在 master 分支，最新 commit 应包含 `Merge branch 'refactor/n3-codex'`
- N3 全套 22 测试通过（`playtest_n3_smoke` 14 PASS）
- `godot/data/customers/` 当前只有 `.gdignore` 占位

---

## File Structure

### 新增

| 路径 | 责任 |
|---|---|
| `godot/scripts/core/customer_spawner.gd` (Autoload) | 在线时定时 emit customer_arrived；离线节奏 N5 接入 |
| `godot/scripts/core/encounter_state.gd` (Autoload) | 当前 pending 客人 + lent 装备记录（gear → {customer, due_unix, started_unix}）+ 序列化 |
| `godot/scripts/systems/return_resolver.gd` | 静态类：按 CustomerData.tier 5 档结果概率分布 + 注入 RNG |
| `godot/scripts/systems/customer_request.gd` | 值对象：访问者一次诉求（customer + path/quality 偏好 + 酬金）|
| `godot/scripts/ui/customer_arrival_panel.gd` | 底部滑入小卡：剪影/诉求/酬金/借按钮/拒按钮 |
| `godot/scenes/ui/customer_arrival_panel.tscn` | |
| `godot/scripts/ui/lend_dialog.gd` | 选 IN_SHOP 装备的下拉/列表对话框 |
| `godot/scenes/ui/lend_dialog.tscn` | |
| `godot/scripts/ui/return_notice.gd` | 装备归来浮窗（含 outcome 文字） |
| `godot/scenes/ui/return_notice.tscn` | |

### 数据

| 路径 | 内容 |
|---|---|
| `godot/data/customers/su_jia_niangzi.tres` | 常客 · 苏家娘子（剑系亲和 / hanxing_zong / 200 灵石）|
| `godot/data/customers/xiao_meng_pao_liao.tres` | 常客 · 小孟跑料（食系 / kurong_gu / 100 灵石）|
| `godot/data/customers/meng_mian_ke.tres` | 怪客 · 蒙面客（path 不明 / unknown / 600 灵石 + 高异变率）|

### 修改

| 路径 | 修改 |
|---|---|
| `godot/scripts/core/event_bus.gd` | 加 `customer_arrived(customer_id: StringName, request: Variant)` 重定义；加 `customer_left` 信号已有；保留 `equipment_lent/equipment_returned`（N1 既存）|
| `godot/scripts/core/game_state.gd` | 装备 LENT 时不能装备/不能再借（在 add_to_inventory 后状态过滤）|
| `godot/scripts/core/save_system.gd` | payload 加 `encounter_state` 段 |
| `godot/scripts/ui/shop_screen.gd` | 接 customer_arrived → 弹 CustomerArrivalPanel；柜台加"接客"按钮（手动 spawn 触发）|
| `godot/scenes/shop.tscn` | AreaCounter 加 OpenCounterButton + 3 个新 UI 实例 |

### 测试

| 路径 | 内容 |
|---|---|
| `godot/scripts/test/test_return_resolver.gd` + `.tscn` | 5 档 outcome 分布拟合（10000 sample） |
| `godot/scripts/test/test_customer_spawner.gd` + `.tscn` | spawn 节奏 + tier 分布 |
| `godot/scripts/test/test_encounter_state.gd` + `.tscn` | lend → return → 装备 status 流转 + 序列化 |
| `godot/scripts/test/test_customer_data_loads.gd` + `.tscn` | DataRegistry 扫到 3 个 customer |
| `godot/scripts/test/playtest_n4_smoke.gd` + `.tscn` | UI 加载 + 100 次 spawn-lend-return 循环不崩 |

---

## Phase A — 数据 + 逻辑核心

### Task 1: 3 个 starter customer .tres

**Files:**
- Create: `godot/data/customers/su_jia_niangzi.tres`, `xiao_meng_pao_liao.tres`, `meng_mian_ke.tres`
- Create: `godot/scripts/test/test_customer_data_loads.gd` + `.tscn`

- [ ] **Step 1: 写测试场景外壳**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_customer_data_loads.gd" id="1"]

[node name="TestCustomerDataLoads" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

```gdscript
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_three_customers_indexed()
	_test_su_jia_niangzi_loads()
	_test_meng_mian_ke_is_weird()
	print("\n========== test_customer_data_loads ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_three_customers_indexed() -> void:
	var ids: Array = DataRegistry.ids_of(&"customer")
	_assert(ids.size() >= 3, "customer index has >= 3 (got %d)" % ids.size())
	_assert(&"su_jia_niangzi" in ids, "su_jia_niangzi indexed")
	_assert(&"xiao_meng_pao_liao" in ids, "xiao_meng_pao_liao indexed")
	_assert(&"meng_mian_ke" in ids, "meng_mian_ke indexed")


func _test_su_jia_niangzi_loads() -> void:
	var c := DataRegistry.get_resource(&"customer", &"su_jia_niangzi") as CustomerData
	_assert(c != null, "su_jia_niangzi loads")
	if c == null: return
	_assert(c.display_name == "苏家娘子", "display_name correct")
	_assert(c.tier == CustomerData.Tier.REGULAR, "tier REGULAR")
	_assert(c.path_affinity == &"sword", "path sword")
	_assert(c.base_payment == 200, "payment 200")


func _test_meng_mian_ke_is_weird() -> void:
	var c := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	_assert(c != null, "meng_mian_ke loads")
	if c == null: return
	_assert(c.tier == CustomerData.Tier.WEIRD, "tier WEIRD")
	_assert(c.base_payment >= 500, "payment >= 500 (high)")
```

- [ ] **Step 3: Run test → confirm FAIL** (no .tres yet)

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_customer_data_loads.tscn
```

- [ ] **Step 4: 创建 su_jia_niangzi.tres**

```
[gd_resource type="Resource" script_class="CustomerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/customer_data.gd" id="1_c"]

[resource]
script = ExtResource("1_c")
id = &"su_jia_niangzi"
display_name = "苏家娘子"
tier = 0
path_affinity = &"sword"
faction = &"hanxing_zong"
base_payment = 200
allowed_shichen = Array[int]([])
faction_state_bonus = 0.0
portrait_path = ""
```

- [ ] **Step 5: 创建 xiao_meng_pao_liao.tres**

```
[gd_resource type="Resource" script_class="CustomerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/customer_data.gd" id="1_c"]

[resource]
script = ExtResource("1_c")
id = &"xiao_meng_pao_liao"
display_name = "小孟跑料"
tier = 0
path_affinity = &"eat"
faction = &"kurong_gu"
base_payment = 100
allowed_shichen = Array[int]([])
faction_state_bonus = 0.0
portrait_path = ""
```

- [ ] **Step 6: 创建 meng_mian_ke.tres**

```
[gd_resource type="Resource" script_class="CustomerData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/customer_data.gd" id="1_c"]

[resource]
script = ExtResource("1_c")
id = &"meng_mian_ke"
display_name = "蒙面客"
tier = 2
path_affinity = &"sword"
faction = &"unknown"
base_payment = 600
allowed_shichen = Array[int]([0, 1, 2, 3])
faction_state_bonus = 0.0
portrait_path = ""
```

- [ ] **Step 7: --import + Run → PASS**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_customer_data_loads.tscn
```

预期：`PASS: 11 FAIL: 0`

- [ ] **Step 8: 提交**

```bash
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/data/customers/*.tres godot/scripts/test/test_customer_data_loads.gd godot/scripts/test/test_customer_data_loads.gd.uid godot/scenes/test/test_customer_data_loads.tscn
git commit -m "feat(N4): 3 个 starter customer .tres（苏家娘子/小孟跑料/蒙面客）

- 苏家娘子: REGULAR tier / sword / hanxing_zong / 200 灵石
- 小孟跑料: REGULAR / eat / kurong_gu / 100 灵石
- 蒙面客: WEIRD / sword 但身份不明 / 600 灵石 / 仅深夜出没
- 测试: test_customer_data_loads 11 PASS"
```

---

### Task 2: CustomerRequest 值对象

**Files:** Create `godot/scripts/systems/customer_request.gd`

- [ ] **Step 1: 创建类**

```gdscript
class_name CustomerRequest
extends RefCounted
## 客人一次访问的诉求快照（运行时值对象）。
## 由 CustomerSpawner 生成；EncounterState/UI 持有引用直到结算。

## 客人模板 id（CustomerData id）
var customer_id: StringName = &""
## 来访时间戳
var arrived_unix: int = 0
## 诉求：希望借哪种 slot_kind 装备
var desired_slot: StringName = &"sword"
## 诉求：最低品质（0=凡）
var min_quality: int = 0
## 酬金（灵石）
var payment: int = 100
## 任务名（用于回信叙事 placeholder）
var quest_label: String = "外勤"
## 借出后预计回信秒数（在线/离线 1:1）
var expected_duration_sec: int = 600  # 默认 10 分钟


func _to_string() -> String:
	return "[CustomerRequest %s wants %s≥Q%d for %d 灵石]" % [
		customer_id, desired_slot, min_quality, payment
	]
```

- [ ] **Step 2: --import + commit**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/systems/customer_request.gd godot/scripts/systems/customer_request.gd.uid
git commit -m "feat(N4): CustomerRequest 值对象（一次访问的诉求快照）"
```

---

### Task 3: ReturnResolver 5 档 outcome 概率

**Files:**
- Create: `godot/scripts/systems/return_resolver.gd`
- Create: `godot/scripts/test/test_return_resolver.gd` + `.tscn`

- [ ] **Step 1: 写测试**

Create `godot/scenes/test/test_return_resolver.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_return_resolver.gd" id="1"]

[node name="TestReturnResolver" type="Node"]
script = ExtResource("1")
```

Create `godot/scripts/test/test_return_resolver.gd`:

```gdscript
extends Node
## ReturnResolver 5 档结果分布按 tier 抽样验证。

const SAMPLES: int = 10000
const SEED: int = 42

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_outcome_enum()
	_test_regular_distribution()
	_test_weird_distribution()
	_test_outcome_text_nonempty()
	print("\n========== test_return_resolver ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_outcome_enum() -> void:
	_assert(ReturnResolver.Outcome.OK_RETURN == 0, "OK_RETURN=0")
	_assert(ReturnResolver.Outcome.GREAT_DEED == 1, "GREAT_DEED=1")
	_assert(ReturnResolver.Outcome.DAMAGED == 2, "DAMAGED=2")
	_assert(ReturnResolver.Outcome.MUTATED == 3, "MUTATED=3")
	_assert(ReturnResolver.Outcome.NOT_RETURNED == 4, "NOT_RETURNED=4")


func _test_regular_distribution() -> void:
	# REGULAR tier: 70/12/10/5/3
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0, 0, 0]
	for i in SAMPLES:
		counts[ReturnResolver.roll_outcome(CustomerData.Tier.REGULAR, rng)] += 1
	# 容差 ±2σ
	var expected := [7000, 1200, 1000, 500, 300]
	var tol := [120, 80, 70, 50, 40]
	for i in 5:
		var diff: int = absi(counts[i] - expected[i])
		_assert(diff < tol[i], "REGULAR tier %d: got %d expected %d (tol %d)" % [i, counts[i], expected[i], tol[i]])


func _test_weird_distribution() -> void:
	# WEIRD tier: 25/25/15/20/15
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0, 0, 0]
	for i in SAMPLES:
		counts[ReturnResolver.roll_outcome(CustomerData.Tier.WEIRD, rng)] += 1
	var expected := [2500, 2500, 1500, 2000, 1500]
	var tol := [110, 110, 90, 100, 90]
	for i in 5:
		var diff: int = absi(counts[i] - expected[i])
		_assert(diff < tol[i], "WEIRD tier %d: got %d expected %d (tol %d)" % [i, counts[i], expected[i], tol[i]])


func _test_outcome_text_nonempty() -> void:
	for o in 5:
		var t := ReturnResolver.outcome_text(o)
		_assert(t.length() > 0, "outcome %d text non-empty" % o)
```

- [ ] **Step 2: Run test → FAIL**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_return_resolver.tscn
```

- [ ] **Step 3: 创建 return_resolver.gd**

```gdscript
class_name ReturnResolver
extends RefCounted
## 客人借出装备后的回信结果计算（spec §6.4 5 档分布）。

enum Outcome {
	OK_RETURN = 0,        ## 顺利归还
	GREAT_DEED = 1,       ## 立大功
	DAMAGED = 2,          ## 损坏归还
	MUTATED = 3,          ## 异变归还
	NOT_RETURNED = 4,     ## 不归还
}

## 概率表 [tier][outcome]，每行总和 1.0
const DISTRIBUTION: Array = [
	# REGULAR: 70 / 12 / 10 / 5 / 3
	[0.70, 0.12, 0.10, 0.05, 0.03],
	# RARE: 55 / 20 / 12 / 8 / 5
	[0.55, 0.20, 0.12, 0.08, 0.05],
	# WEIRD: 25 / 25 / 15 / 20 / 15
	[0.25, 0.25, 0.15, 0.20, 0.15],
]


## 按 tier 抽样一个 outcome
static func roll_outcome(tier: int, rng: RandomNumberGenerator) -> int:
	if tier < 0 or tier >= DISTRIBUTION.size():
		return Outcome.OK_RETURN
	var dist: Array = DISTRIBUTION[tier]
	var u: float = rng.randf()
	var acc: float = 0.0
	for i in dist.size():
		acc += float(dist[i])
		if u < acc:
			return i
	return Outcome.OK_RETURN


## outcome → 简短中文描述（用于 UI / 历史）
static func outcome_text(outcome: int) -> String:
	match outcome:
		Outcome.OK_RETURN: return "顺利归还"
		Outcome.GREAT_DEED: return "立大功归来"
		Outcome.DAMAGED: return "损坏归还"
		Outcome.MUTATED: return "异变归还"
		Outcome.NOT_RETURNED: return "未归还"
		_: return "未知"
```

- [ ] **Step 4: --import + Run → PASS**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_return_resolver.tscn
```

预期：`PASS: 16  FAIL: 0`

- [ ] **Step 5: 提交**

```bash
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/systems/return_resolver.gd godot/scripts/systems/return_resolver.gd.uid godot/scripts/test/test_return_resolver.gd godot/scripts/test/test_return_resolver.gd.uid godot/scenes/test/test_return_resolver.tscn
git commit -m "feat(N4): ReturnResolver 5 档 outcome（spec §6.4 概率分布）

- Outcome enum: OK_RETURN/GREAT_DEED/DAMAGED/MUTATED/NOT_RETURNED
- DISTRIBUTION[tier] 分布表：REGULAR 70/12/10/5/3 RARE 55/20/12/8/5 WEIRD 25/25/15/20/15
- 蒙特卡洛 10000 sample ±2σ 容差
- 测试: test_return_resolver 16 PASS"
```

---

### Task 4: EncounterState Autoload + SaveSystem 集成

**Files:**
- Create: `godot/scripts/core/encounter_state.gd`
- Modify: `godot/project.godot` (autoload + 8 entries)
- Modify: `godot/scripts/core/save_system.gd` (payload 加 encounter_state)
- Create: `godot/scripts/test/test_encounter_state.gd` + `.tscn`

- [ ] **Step 1: 写测试**

Create `godot/scenes/test/test_encounter_state.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_encounter_state.gd" id="1"]

[node name="TestEncounterState" type="Node"]
script = ExtResource("1")
```

Create `godot/scripts/test/test_encounter_state.gd`:

```gdscript
extends Node
## EncounterState lend → return → status 流转 + 序列化

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_lend_marks_status_lent()
	_test_return_ok_status_in_shop_with_history()
	_test_return_not_returned_status()
	_test_serialize_only_pending_lends()
	print("\n========== test_encounter_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_gear() -> GearInstance:
	var g := GearInstance.new()
	g.base_id = &"iron_sword"
	g.rarity = 1
	g.status = GearInstance.Status.IN_SHOP
	return g


func _test_lend_marks_status_lent() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	_assert(g.status == GearInstance.Status.LENT, "gear.status = LENT")
	_assert(g.history.size() >= 1, "history has lent entry")
	_assert(EncounterState.lent_count() == 1, "1 lent")


func _test_return_ok_status_in_shop_with_history() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	EncounterState.resolve_return(g, ReturnResolver.Outcome.OK_RETURN, 1700000700)
	_assert(g.status == GearInstance.Status.IN_SHOP, "status back to IN_SHOP")
	_assert(g.history.size() >= 2, "history has 2+ entries (lent + returned)")
	_assert(EncounterState.lent_count() == 0, "0 lent after return")


func _test_return_not_returned_status() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	EncounterState.resolve_return(g, ReturnResolver.Outcome.NOT_RETURNED, 1700000700)
	_assert(g.status == GearInstance.Status.NOT_RETURNED, "status = NOT_RETURNED")
	_assert(EncounterState.lent_count() == 0, "0 lent after not_returned (cleared from pending)")


func _test_serialize_only_pending_lends() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	var d := EncounterState.to_dict()
	_assert(d.has("pending_lends"), "to_dict has pending_lends")
	var pl: Array = d.get("pending_lends", [])
	_assert(pl.size() == 1, "1 pending lend serialized")
```

- [ ] **Step 2: Run test → FAIL**

- [ ] **Step 3: 创建 encounter_state.gd**

```gdscript
extends Node
## 客人遭遇状态 Autoload。
## - 当前 pending 客人请求（一次只能有一位访客等待回应；下一位排队）
## - 已借出装备的 pending 记录（gear → {customer_id, lent_unix, due_unix}）
## - 序列化只存 pending；装备本身在 GameState.inventory（同 N3 codex 模式）

## 当前等待玩家回应的客人请求（CustomerRequest 实例 或 null）
var pending_request: CustomerRequest = null

## 已借出 pending: gear (RefCounted weak via inventory ref) -> { customer_id, lent_unix, due_unix }
## 用 base_id+seed 复合 key 字符串化（避免对象 ref 在 Dict key 不稳）
## key 格式: "%s|%d" % [base_id, seed]
var _lent: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	pending_request = null
	_lent.clear()


# ── 借出 ──────────────────────────────────────

func lend(customer_id: StringName, gear: GearInstance, lent_unix: int, duration_sec: int) -> void:
	if gear == null: return
	gear.status = GearInstance.Status.LENT
	gear.history.append({
		"unix": lent_unix,
		"event": "lent",
		"detail": String(customer_id),
	})
	var key: String = _gear_key(gear)
	_lent[key] = {
		"customer_id": String(customer_id),
		"lent_unix": lent_unix,
		"due_unix": lent_unix + duration_sec,
	}
	EventBus.equipment_lent.emit(customer_id, gear)


# ── 归还 ──────────────────────────────────────

func resolve_return(gear: GearInstance, outcome: int, returned_unix: int) -> void:
	if gear == null: return
	var key: String = _gear_key(gear)
	var record: Dictionary = _lent.get(key, {})
	var customer_id: String = str(record.get("customer_id", ""))
	# 状态映射
	match outcome:
		ReturnResolver.Outcome.OK_RETURN, ReturnResolver.Outcome.GREAT_DEED:
			gear.status = GearInstance.Status.IN_SHOP
		ReturnResolver.Outcome.DAMAGED:
			gear.status = GearInstance.Status.DAMAGED
		ReturnResolver.Outcome.MUTATED:
			gear.status = GearInstance.Status.MUTATED
		ReturnResolver.Outcome.NOT_RETURNED:
			gear.status = GearInstance.Status.NOT_RETURNED
		_:
			gear.status = GearInstance.Status.IN_SHOP
	# 履历追加
	gear.history.append({
		"unix": returned_unix,
		"event": "returned",
		"detail": ReturnResolver.outcome_text(outcome),
	})
	# 移出 pending
	_lent.erase(key)
	EventBus.equipment_returned.emit(StringName(customer_id), gear, StringName(ReturnResolver.outcome_text(outcome)))


func lent_count() -> int:
	return _lent.size()


func is_lent(gear: GearInstance) -> bool:
	if gear == null: return false
	return _lent.has(_gear_key(gear))


# ── 序列化 ────────────────────────────────────

func to_dict() -> Dictionary:
	var pending: Array = []
	for key in _lent:
		var rec: Dictionary = _lent[key]
		pending.append({
			"gear_key": key,
			"customer_id": rec["customer_id"],
			"lent_unix": rec["lent_unix"],
			"due_unix": rec["due_unix"],
		})
	return {
		"pending_lends": pending,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	var pending: Array = d.get("pending_lends", [])
	for entry in pending:
		var key: String = str(entry.get("gear_key", ""))
		if key == "": continue
		_lent[key] = {
			"customer_id": str(entry.get("customer_id", "")),
			"lent_unix": int(entry.get("lent_unix", 0)),
			"due_unix": int(entry.get("due_unix", 0)),
		}


static func _gear_key(gear: GearInstance) -> String:
	return "%s|%d" % [String(gear.base_id), gear.seed]
```

- [ ] **Step 4: 注册 autoload**

In `godot/project.godot`, after `CodexState=...`, add:
```
EncounterState="*res://scripts/core/encounter_state.gd"
```

- [ ] **Step 5: SaveSystem 加 encounter_state 段**

In `save_system.gd` payload:
```gdscript
"encounter_state": EncounterState.to_dict(),
```

In `load_or_init`:
```gdscript
var es: Dictionary = parsed.get("encounter_state", {})
EncounterState.from_dict(es)
```

- [ ] **Step 6: --import + Run test → PASS**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -3
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_encounter_state.tscn
```

预期：`PASS: 11 FAIL: 0`

Plus 跑回归确保 N1-N3 不破：
```bash
for t in test_game_state test_save_with_shopstate test_codex_state playtest_n3_smoke; do
  echo "=== $t ==="
  "D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1
done
```

- [ ] **Step 7: 提交**

```bash
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/core/encounter_state.gd godot/scripts/core/encounter_state.gd.uid godot/scripts/core/save_system.gd godot/project.godot godot/scripts/test/test_encounter_state.gd godot/scripts/test/test_encounter_state.gd.uid godot/scenes/test/test_encounter_state.tscn
git commit -m "feat(N4): EncounterState Autoload + SaveSystem 集成

- pending_request: CustomerRequest（一次一位访客排队）
- _lent: gear_key (base_id|seed) -> {customer_id, lent_unix, due_unix}
- lend() 标 status=LENT + history append + emit equipment_lent
- resolve_return() 按 outcome 映射 status (IN_SHOP/DAMAGED/MUTATED/NOT_RETURNED)
- 序列化只存 pending_lends（装备 ref 由 GameState.inventory 提供）
- 测试: test_encounter_state 11 PASS；N1-N3 回归无破"
```

---

## Phase B — CustomerSpawner

### Task 5: CustomerSpawner Autoload

**Files:**
- Create: `godot/scripts/core/customer_spawner.gd`
- Modify: `godot/project.godot`
- Create: `godot/scripts/test/test_customer_spawner.gd` + `.tscn`

> **MVP**: 在线 + 玩家手动触发（柜台按钮）即可 spawn。离线节奏 N5 接入。

- [ ] **Step 1: 写测试**

Create `godot/scenes/test/test_customer_spawner.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_customer_spawner.gd" id="1"]

[node name="TestCustomerSpawner" type="Node"]
script = ExtResource("1")
```

Create `godot/scripts/test/test_customer_spawner.gd`:

```gdscript
extends Node
## CustomerSpawner.spawn_one 抽样 + tier 分布

const SAMPLES: int = 1000
const SEED: int = 42

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_spawn_returns_request()
	_test_tier_distribution_60_30_10()
	print("\n========== test_customer_spawner ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_spawn_returns_request() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var req := CustomerSpawner.spawn_one(rng, 1700000000)
	_assert(req != null, "spawn returns non-null")
	if req == null: return
	_assert(req.customer_id != &"", "customer_id set (%s)" % req.customer_id)
	_assert(req.payment > 0, "payment > 0 (%d)" % req.payment)
	_assert(req.expected_duration_sec > 0, "duration > 0")


func _test_tier_distribution_60_30_10() -> void:
	# spec §6.1: 常 60% / 罕 30% / 怪 10%
	# N4 v1: 我们只有 starter 客人覆盖 REGULAR 和 WEIRD（无 RARE）；
	# 简化分布：常 80% / 怪 20%（直到 RARE 客人补全）
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0]
	for i in SAMPLES:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i)
		if req == null: continue
		var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
		if c != null:
			counts[c.tier] += 1
	# v1 tolerance：无 RARE，REGULAR ≈ 800, WEIRD ≈ 200
	_assert(counts[CustomerData.Tier.REGULAR] >= 700, "REGULAR >= 700 (got %d)" % counts[0])
	_assert(counts[CustomerData.Tier.WEIRD] >= 100, "WEIRD >= 100 (got %d)" % counts[2])
	_assert(counts[CustomerData.Tier.WEIRD] <= 300, "WEIRD <= 300 (got %d)" % counts[2])
```

- [ ] **Step 2: Run test → FAIL**

- [ ] **Step 3: 创建 customer_spawner.gd**

```gdscript
extends Node
## 客人召唤 Autoload。
## - 在线时按节奏 spawn（autospawn 关闭，玩家手动按"接客"触发；N5 加自动定时）
## - 抽 tier → 在该 tier 池里随机选 customer → 实例化 CustomerRequest
## - 离线节奏 N5 整合

## tier 抽样权重（v1 简化：无 RARE，常 80% 怪 20%）
const TIER_WEIGHTS: Array[float] = [0.80, 0.0, 0.20]

## 默认借出时长（秒）— 各 tier 不同（怪客拖更久）
const DURATION_BY_TIER: Array[int] = [600, 900, 1800]


## 召唤一位客人。返回 CustomerRequest 或 null（无可用客人）
static func spawn_one(rng: RandomNumberGenerator, now_unix: int) -> CustomerRequest:
	# 1. 抽 tier
	var u: float = rng.randf()
	var acc: float = 0.0
	var tier: int = CustomerData.Tier.REGULAR
	for i in TIER_WEIGHTS.size():
		acc += TIER_WEIGHTS[i]
		if u < acc:
			tier = i
			break
	# 2. 在该 tier 池里随机选 customer
	var pool: Array = []
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null and c.tier == tier:
			pool.append(c)
	if pool.is_empty():
		# 兜底：用 REGULAR 池
		for cid in DataRegistry.ids_of(&"customer"):
			var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
			if c != null and c.tier == CustomerData.Tier.REGULAR:
				pool.append(c)
	if pool.is_empty():
		return null
	var pick: CustomerData = pool[rng.randi() % pool.size()]
	# 3. 实例化 CustomerRequest
	var req := CustomerRequest.new()
	req.customer_id = pick.id
	req.arrived_unix = now_unix
	req.desired_slot = _slot_from_path(pick.path_affinity)
	req.min_quality = 0
	req.payment = pick.base_payment
	req.quest_label = "外勤" if tier == CustomerData.Tier.REGULAR else "夜事"
	req.expected_duration_sec = DURATION_BY_TIER[tier]
	return req


## 玩家点"接客"时调用：spawn 一位 + 写入 EncounterState.pending_request
## 返回是否成功（已 pending 时返回 false）
func spawn_now() -> bool:
	if EncounterState.pending_request != null:
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var req := spawn_one(rng, TimeLine.now_unix())
	if req == null:
		return false
	EncounterState.pending_request = req
	EventBus.customer_arrived.emit(req.customer_id, req)
	return true


static func _slot_from_path(path: StringName) -> StringName:
	# path → 主要 slot 映射（粗略；同 N3 generate_sus.py 矩阵）
	match path:
		&"sword": return &"sword"
		&"curse": return &"talisman"
		&"puppet": return &"puppet_core"
		&"alchemy": return &"elixir_furnace"
		&"eat": return &"eating_vessel"
		&"divination": return &"divination_plate"
		_: return &"sword"
```

- [ ] **Step 4: 注册 autoload**

In `project.godot`, append:
```
CustomerSpawner="*res://scripts/core/customer_spawner.gd"
```

- [ ] **Step 5: --import + Run → PASS**

预期：`PASS: 7 FAIL: 0`

- [ ] **Step 6: 提交**

```bash
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/core/customer_spawner.gd godot/scripts/core/customer_spawner.gd.uid godot/project.godot godot/scripts/test/test_customer_spawner.gd godot/scripts/test/test_customer_spawner.gd.uid godot/scenes/test/test_customer_spawner.tscn
git commit -m "feat(N4): CustomerSpawner Autoload (v1 手动触发 + tier 80/0/20 简化分布)

- spawn_one(rng, now): 抽 tier → 池里选 customer → 实例化 CustomerRequest
- spawn_now(): 玩家"接客"按钮触发，写入 EncounterState.pending_request 并 emit customer_arrived
- DURATION_BY_TIER: REGULAR 10min / RARE 15min / WEIRD 30min
- 测试: test_customer_spawner 7 PASS"
```

---

## Phase C — UI 三件套

### Task 6: CustomerArrivalPanel 底部滑入小卡

**Files:**
- Create: `godot/scripts/ui/customer_arrival_panel.gd`
- Create: `godot/scenes/ui/customer_arrival_panel.tscn`

- [ ] **Step 1: 写脚本**

```gdscript
extends Control
class_name CustomerArrivalPanel
## 客人来访时屏幕底部滑入的小卡。
## 显示：剪影（占位 ColorRect）/ 客人名 / 诉求 / 酬金 / 借/拒按钮

signal lend_pressed(req: CustomerRequest)
signal refuse_pressed(req: CustomerRequest)

@onready var _name_label: Label = $Frame/Layout/NameLabel
@onready var _request_label: Label = $Frame/Layout/RequestLabel
@onready var _payment_label: Label = $Frame/Layout/PaymentLabel
@onready var _lend_btn: Button = $Frame/Layout/Buttons/LendBtn
@onready var _refuse_btn: Button = $Frame/Layout/Buttons/RefuseBtn

var _current: CustomerRequest = null


func _ready() -> void:
	visible = false
	_lend_btn.pressed.connect(_on_lend)
	_refuse_btn.pressed.connect(_on_refuse)


func show_request(req: CustomerRequest) -> void:
	_current = req
	visible = true
	var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	_name_label.text = c.display_name if c != null else String(req.customer_id)
	_request_label.text = "求借 %s ≥ Q%d  ·  %s" % [
		_slot_zh(req.desired_slot), req.min_quality, req.quest_label
	]
	_payment_label.text = "酬金 %d 灵石" % req.payment


func _on_lend() -> void:
	visible = false
	if _current != null:
		lend_pressed.emit(_current)


func _on_refuse() -> void:
	visible = false
	if _current != null:
		refuse_pressed.emit(_current)


static func _slot_zh(slot: StringName) -> String:
	match slot:
		&"sword": return "剑"
		&"talisman": return "符"
		&"puppet_core": return "傀核"
		&"elixir_furnace": return "丹炉"
		&"eating_vessel": return "食器"
		&"divination_plate": return "卦盘"
		_: return String(slot)
```

- [ ] **Step 2: 写场景**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/customer_arrival_panel.gd" id="1"]

[node name="CustomerArrivalPanel" type="Control"]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -160.0
script = ExtResource("1")

[node name="Frame" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -70.0
offset_right = 300.0
offset_bottom = 70.0

[node name="Layout" type="VBoxContainer" parent="Frame"]
theme_override_constants/separation = 6

[node name="NameLabel" type="Label" parent="Frame/Layout"]
text = ""
theme_override_font_sizes/font_size = 22
theme_override_colors/font_color = Color(0.95, 0.85, 0.55, 1)

[node name="RequestLabel" type="Label" parent="Frame/Layout"]
text = ""
theme_override_font_sizes/font_size = 16

[node name="PaymentLabel" type="Label" parent="Frame/Layout"]
text = ""
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.6, 0.95, 0.7, 1)

[node name="Buttons" type="HBoxContainer" parent="Frame/Layout"]
theme_override_constants/separation = 12

[node name="LendBtn" type="Button" parent="Frame/Layout/Buttons"]
text = "借"
custom_minimum_size = Vector2(90, 36)
theme_override_font_sizes/font_size = 18

[node name="RefuseBtn" type="Button" parent="Frame/Layout/Buttons"]
text = "拒"
custom_minimum_size = Vector2(90, 36)
theme_override_font_sizes/font_size = 18
```

- [ ] **Step 3: --import + commit**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/ui/customer_arrival_panel.gd godot/scripts/ui/customer_arrival_panel.gd.uid godot/scenes/ui/customer_arrival_panel.tscn
git commit -m "feat(N4): CustomerArrivalPanel 客人来访底部小卡

- 屏幕底部居中（width 600, height 140）
- 名称 / 诉求（slot+min_quality+quest）/ 酬金
- 借/拒两按钮 emit lend_pressed/refuse_pressed(req)"
```

---

### Task 7: LendDialog 装备选择对话框

**Files:**
- Create: `godot/scripts/ui/lend_dialog.gd`
- Create: `godot/scenes/ui/lend_dialog.tscn`

- [ ] **Step 1: 写脚本**

```gdscript
extends Control
class_name LendDialog
## 选 IN_SHOP 状态装备的对话框。

signal gear_chosen(gear: GearInstance, req: CustomerRequest)
signal cancelled

@onready var _title: Label = $Frame/Layout/Title
@onready var _list: ItemList = $Frame/Layout/List
@onready var _confirm_btn: Button = $Frame/Layout/Buttons/ConfirmBtn
@onready var _cancel_btn: Button = $Frame/Layout/Buttons/CancelBtn

var _candidates: Array[GearInstance] = []
var _current_req: CustomerRequest = null


func _ready() -> void:
	visible = false
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)


func open(req: CustomerRequest) -> void:
	_current_req = req
	visible = true
	_title.text = "借给 %s（求 %s ≥ Q%d）" % [
		_customer_name(req.customer_id),
		CustomerArrivalPanel._slot_zh(req.desired_slot),
		req.min_quality,
	]
	# 过滤候选：IN_SHOP + slot match + quality 满足
	_candidates.clear()
	_list.clear()
	for inst: GearInstance in GameState.inventory:
		if inst == null: continue
		if inst.status != GearInstance.Status.IN_SHOP: continue
		if inst.rarity < req.min_quality: continue
		# slot 匹配通过 base_id 反查 recipe.slot_kind
		var recipe := DataRegistry.get_resource(&"recipe", inst.base_id) as RecipeData
		if recipe != null and recipe.slot_kind != req.desired_slot:
			continue
		_candidates.append(inst)
		_list.add_item("%s（%s）" % [inst.display_full_name(), str(inst.history.size()) + " 次履历"])


func _on_confirm() -> void:
	var idx := _list.get_selected_items()
	if idx.is_empty(): return
	var i: int = idx[0]
	if i < 0 or i >= _candidates.size(): return
	visible = false
	gear_chosen.emit(_candidates[i], _current_req)


func _on_cancel() -> void:
	visible = false
	cancelled.emit()


func _customer_name(cid: StringName) -> String:
	var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
	return c.display_name if c != null else String(cid)
```

- [ ] **Step 2: 写场景**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/lend_dialog.gd" id="1"]

[node name="LendDialog" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.6)

[node name="Frame" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -240.0
offset_top = -180.0
offset_right = 240.0
offset_bottom = 180.0

[node name="Layout" type="VBoxContainer" parent="Frame"]
theme_override_constants/separation = 8

[node name="Title" type="Label" parent="Frame/Layout"]
text = ""
horizontal_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.95, 0.85, 0.55, 1)

[node name="List" type="ItemList" parent="Frame/Layout"]
custom_minimum_size = Vector2(440, 240)

[node name="Buttons" type="HBoxContainer" parent="Frame/Layout"]
theme_override_constants/separation = 12

[node name="ConfirmBtn" type="Button" parent="Frame/Layout/Buttons"]
text = "借出"
custom_minimum_size = Vector2(120, 32)

[node name="CancelBtn" type="Button" parent="Frame/Layout/Buttons"]
text = "取消"
custom_minimum_size = Vector2(120, 32)
```

- [ ] **Step 3: commit**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/ui/lend_dialog.gd godot/scripts/ui/lend_dialog.gd.uid godot/scenes/ui/lend_dialog.tscn
git commit -m "feat(N4): LendDialog 装备选择对话框

- 列 IN_SHOP + slot 匹配 + quality 满足的候选
- 显示装备全名 + 履历次数
- 确认 emit gear_chosen(gear, req)"
```

---

### Task 8: ReturnNotice 归来浮窗

**Files:**
- Create: `godot/scripts/ui/return_notice.gd`
- Create: `godot/scenes/ui/return_notice.tscn`

- [ ] **Step 1: 写脚本**

```gdscript
extends Control
class_name ReturnNotice
## 装备归来时屏幕中上浮窗，3 秒自动消失。

const DISPLAY_SEC: float = 3.5

@onready var _label: Label = $Frame/Label


func _ready() -> void:
	visible = false


func show_notice(text: String) -> void:
	_label.text = text
	visible = true
	# 3.5 秒后自动隐藏
	await get_tree().create_timer(DISPLAY_SEC).timeout
	visible = false
```

- [ ] **Step 2: 场景**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/return_notice.gd" id="1"]

[node name="ReturnNotice" type="Control"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -300.0
offset_top = 100.0
offset_right = 300.0
offset_bottom = 180.0
script = ExtResource("1")

[node name="Frame" type="PanelContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Label" type="Label" parent="Frame"]
text = ""
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.95, 0.85, 0.55, 1)
```

- [ ] **Step 3: commit**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
cd E:/Codes/github/XiuXianLegend && git checkout godot/icon.svg.import 2>/dev/null
git add godot/scripts/ui/return_notice.gd godot/scripts/ui/return_notice.gd.uid godot/scenes/ui/return_notice.tscn
git commit -m "feat(N4): ReturnNotice 归来浮窗（3.5 秒自动消失）"
```

---

## Phase D — 集成

### Task 9: 柜台"接客"按钮 + ShopScreen 接 customer 流程

**Files:**
- Modify: `godot/scenes/shop.tscn` (柜台加按钮 + 3 个 UI 实例)
- Modify: `godot/scripts/ui/shop_screen.gd` (接客/借/回信 完整流程)

- [ ] **Step 1: 修 shop.tscn**

更新 `[gd_scene load_steps=8 format=3]`，加 3 个 ext_resource (customer_arrival_panel/lend_dialog/return_notice)。

AreaCounter 加 OpenCounterButton（"接　客"，与"开炉""查谱"相似规格）。
末尾追加 3 个 UI 节点实例（CustomerArrivalPanel, LendDialog, ReturnNotice）。

(细节按 N2 N3 同样的 pattern 即可，不再重复粘贴 .tscn 全文。)

- [ ] **Step 2: 修 shop_screen.gd**

加新 @onready 引用：
```gdscript
@onready var _open_counter_btn: Button = $AreaCounter/OpenCounterButton
@onready var _customer_panel: CustomerArrivalPanel = $CustomerArrivalPanel
@onready var _lend_dialog: LendDialog = $LendDialog
@onready var _return_notice: ReturnNotice = $ReturnNotice
```

`_ready()` 把 4 个新 screen 一并 visible=false + 加 connect：
```gdscript
_open_counter_btn.pressed.connect(_on_open_counter)
_customer_panel.lend_pressed.connect(_on_customer_lend)
_customer_panel.refuse_pressed.connect(_on_customer_refuse)
_lend_dialog.gear_chosen.connect(_on_gear_chosen)
EventBus.customer_arrived.connect(_on_customer_arrived)
EventBus.equipment_returned.connect(_on_equipment_returned)
```

新 handlers：
```gdscript
func _on_open_counter() -> void:
    if not CustomerSpawner.spawn_now():
        push_warning("counter: pending request exists or spawn failed")


func _on_customer_arrived(_cid: StringName, req: Variant) -> void:
    if req is CustomerRequest:
        _customer_panel.show_request(req)


func _on_customer_lend(req: CustomerRequest) -> void:
    _lend_dialog.open(req)


func _on_customer_refuse(req: CustomerRequest) -> void:
    EncounterState.pending_request = null
    GameState.add_reputation(-1)


func _on_gear_chosen(gear: GearInstance, req: CustomerRequest) -> void:
    EncounterState.lend(req.customer_id, gear, TimeLine.now_unix(), req.expected_duration_sec)
    EncounterState.pending_request = null
    GameState.add_currency(&"spirit_stones", req.payment)
    SaveSystem.save_now(true)
    # N4 v1 简化：到时立即 resolve（玩家不用真等 10 分钟）
    # N5 改为正常计时
    _resolve_now(gear, req)


func _resolve_now(gear: GearInstance, req: CustomerRequest) -> void:
    var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
    var tier: int = c.tier if c != null else 0
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var outcome := ReturnResolver.roll_outcome(tier, rng)
    EncounterState.resolve_return(gear, outcome, TimeLine.now_unix() + req.expected_duration_sec)
    if outcome == ReturnResolver.Outcome.GREAT_DEED:
        GameState.add_currency(&"spirit_stones", req.payment * 2)
        GameState.add_reputation(2)
    SaveSystem.save_now(true)


func _on_equipment_returned(_cid: StringName, gear: Variant, outcome_text: StringName) -> void:
    var name: String = (gear as GearInstance).display_full_name() if gear is GearInstance else "（装备）"
    _return_notice.show_notice("%s · %s" % [name, String(outcome_text)])
```

- [ ] **Step 3: --import + 启动验证 EXIT=0**

- [ ] **Step 4: 提交**

```bash
git commit -m "feat(N4): 柜台接客按钮 + 完整 customer 流程集成

- AreaCounter 加 OpenCounterButton 接　客
- shop_screen wire: spawn_now → arrival → lend → gear chosen → resolve → notice
- v1 简化：lend 后立即 resolve（不等 expected_duration_sec），N5 改成真实计时
- 拒绝客人 -1 reputation；立功 +2 reputation + 2x payment"
```

---

### Task 10: N4 烟测 + 全量回归 + tag

**Files:**
- Create: `godot/scripts/test/playtest_n4_smoke.gd` + `.tscn`
- Modify: `README.md`

- [ ] **Step 1: 烟测**

Create `playtest_n4_smoke.gd`:

```gdscript
extends Node
## N4 烟测：customer UI 加载 + 100 次 spawn-lend-resolve 不崩

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_3_customers()
	_test_arrival_panel_loads()
	_test_lend_dialog_loads()
	_test_return_notice_loads()
	_test_full_cycle_100x()
	print("\n========== playtest_n4_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_3_customers() -> void:
	var ids: Array = DataRegistry.ids_of(&"customer")
	_assert(ids.size() >= 3, "customer >= 3")


func _test_arrival_panel_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	_assert(pkd != null, "arrival_panel loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_lend_dialog_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/lend_dialog.tscn")
	_assert(pkd != null, "lend_dialog loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_return_notice_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/return_notice.tscn")
	_assert(pkd != null, "return_notice loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_full_cycle_100x() -> void:
	# 100 次 spawn → lend a fake gear → resolve → 检查 status 流转无崩
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	for i in 100:
		EncounterState.reset()
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i * 600)
		_assert(req != null, "spawn iter %d" % i)
		if req == null: continue
		var g := GearInstance.new()
		g.base_id = &"iron_sword"
		g.rarity = 0
		g.status = GearInstance.Status.IN_SHOP
		EncounterState.lend(req.customer_id, g, 1700000000 + i * 600, req.expected_duration_sec)
		_assert(g.status == GearInstance.Status.LENT, "iter %d lent" % i)
		var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
		var outcome := ReturnResolver.roll_outcome(c.tier, rng)
		EncounterState.resolve_return(g, outcome, 1700000000 + i * 600 + 600)
		_assert(g.status != GearInstance.Status.LENT, "iter %d unlent" % i)
```

- [ ] **Step 2: Run 烟测 + 全量回归**

```bash
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --import 2>&1 | tail -2
"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/playtest_n4_smoke.tscn 2>&1 | grep -E "PASS:|FAIL:" | tail -2

# 全量回归
for t in test_game_state test_save_migration test_save_with_shopstate \
         test_recipe_data test_customer_data test_gupu_data test_narrative_card \
         test_time_line test_shop_state \
         test_gear_instance_extras test_materials_inventory test_recipe_data_loads \
         test_forge_quality_roll test_forge_qiao_cheng test_forge_backlash \
         test_forge_one_full test_timing_window \
         test_codex_placement test_codex_state \
         test_customer_data_loads test_return_resolver test_encounter_state test_customer_spawner \
         playtest_n1_smoke playtest_n2_smoke playtest_n3_smoke playtest_n4_smoke; do
  "D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn" 2>&1 | grep -E "PASS:.*FAIL:" | tail -1
done
```

- [ ] **Step 3: README 更新 + tag**

```markdown
- ✅ N4：问道门客 v1（3 客人 + 借出/拒绝/回信 5 档结果 + 装备 status 流转 + 履历追加）
```

```bash
git tag -a n4-customers -m "N4 v1 完成（3 starter customers + lend cycle）

延后 N5：怪客盲盒身份/打听/深夜节奏/离线访客/名望影响"
```

---

## Self-Review

### Spec 覆盖

| Spec §6 | 任务 |
|---|---|
| §6.1 三档 tier | T1 数据 + T5 spawner（v1 简化为 80/20 因 RARE 池为空）|
| §6.2 来访节奏 | T5 v1 仅手动；离线/在线节奏 N5 |
| §6.3 借/拒/打听 | T6 借/拒；打听延后 N5 |
| §6.4 5 档 outcome | T3 ReturnResolver |
| §6.5 名望声誉 | T9 拒/立功改 reputation |

### 已知妥协

- N4 v1 资源在 N9 内容填充时还会扩展（怪客身份盲盒、深夜窗口等）
- _resolve_now 立即结算（不真等 expected_duration_sec），N5 改正
- LendDialog 仅按 slot+quality 过滤，怪客的 path 不明 N5 处理
- starter customers 仅 3 个（缺 RARE tier），N9 补全

### 类型一致性

- `CustomerRequest` 字段命名前后一致 ✓
- `EncounterState.lend(cid, gear, unix, sec)` 4 参 ↔ shop_screen 调用 ✓
- `ReturnResolver.Outcome` enum ↔ `EncounterState.resolve_return` match ✓
- `EventBus.customer_arrived(cid, req)` 用 Variant（同 forge_finished 模式）✓

---

## 执行交接

**Plan complete and saved to `docs/superpowers/plans/2026-04-30-n4-customers.md`. Two execution options:**

**1. Subagent-Driven** — Fresh subagent per task

**2. Inline Execution (recommended)** — Auto mode 已验证 controller 直执行更稳

**Which approach?**
