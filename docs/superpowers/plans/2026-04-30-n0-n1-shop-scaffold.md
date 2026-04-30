# N0 归档 + N1 铺子骨架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Godot 项目从"卡牌战斗挂机+赛季+修炼+妖谭塔"清场，搭建《我在诡异修仙造兵器》的核心骨架（4 区域铺子 + 时间线 Autoload + 老铁化身 placeholder + 全部新数据 Resource 类）。完成后 F5 能启动到一个空铺子，老铁剪影站在炉房，时间线在后台前进；旧战斗系统全部归档但不删除。

**Architecture:**
- 沿用现有 Autoload + Resource + 信号事件总线 + MVVM 架构（DESIGN.md §8 仍生效）。
- 新增 2 个 Autoload：`TimeLine`（时辰推进）、`ShopState`（铺子状态）。
- 新增 5 个 Resource 类：`RecipeData / CustomerData / GuPuData / SuData / NarrativeCard`。
- 旧战斗/塔/赛季/卡牌全部移到 `_deprecated/` 子目录（不删，便于回查）；`game_state.gd` 清理无关字段；`event_bus.gd` 清理无关信号；`save_system.gd` 升 v2 加 migration 把旧存档转成新格式（丢弃战斗字段）。
- 主场景从 `city.tscn` 改为 `shop.tscn`（2.5D 俯视铺子骨架，4 区域用 ColorRect placeholder）。

**Tech Stack:**
- Godot 4.6 (GDScript)
- 测试：headless 跑 `.tscn` 启动测试脚本（沿用现有 `playtest_loop.gd` 模式：`extends Node` + `_assert()` + `print` + `quit()`）
- 跑测命令：`"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/<name>.tscn`

---

## File Structure

### 新增（创建）

| 路径 | 责任 |
|---|---|
| `godot/scripts/core/time_line.gd` | Autoload。时间线推进、时辰判定、离线时长计算 |
| `godot/scripts/core/shop_state.gd` | Autoload。4 区域等级、铺规槽、声誉/名望、序列化 |
| `godot/scripts/data/recipe_data.gd` | Resource。锻造配方（材料/品质分布/时长） |
| `godot/scripts/data/customer_data.gd` | Resource。客人模板（流派亲和/品阶/酬金/出现条件） |
| `godot/scripts/data/gupu_data.gd` | Resource。古谱（28 颗 SuData 引用 + 共鸣效果） |
| `godot/scripts/data/su_data.gd` | Resource。单星宿（落点判定字段：道途/品类/品质） |
| `godot/scripts/data/narrative_card.gd` | Resource。叙事卡片（触发条件 + 文本） |
| `godot/scripts/actors/old_iron.gd` | 老铁化身节点脚本 |
| `godot/scenes/actors/old_iron.tscn` | 老铁场景（白发剪影 placeholder） |
| `godot/scenes/shop.tscn` | 主场景（2.5D 俯视铺子骨架） |
| `godot/scripts/ui/shop_screen.gd` | 主场景控制器 |
| `godot/scripts/test/test_time_line.gd` | TimeLine 单元测试脚本 |
| `godot/scenes/test/test_time_line.tscn` | TimeLine 测试场景外壳 |
| `godot/scripts/test/test_shop_state.gd` | ShopState 单元测试脚本 |
| `godot/scenes/test/test_shop_state.tscn` | ShopState 测试场景外壳 |
| `godot/scripts/test/playtest_n1_smoke.gd` | N1 烟测：autoload 启动 + 主场景能加载 |
| `godot/scenes/test/playtest_n1_smoke.tscn` | 烟测场景外壳 |
| `godot/data/recipes/.gdignore` | 占位（防 ResourceLoader 报错） |
| `godot/data/customers/.gdignore` | 占位 |
| `godot/data/gupu/.gdignore` | 占位 |
| `godot/data/sus/.gdignore` | 占位 |
| `godot/data/narratives/.gdignore` | 占位 |

### 修改

| 路径 | 修改 |
|---|---|
| `godot/project.godot` | 项目名改"我在诡异修仙造兵器"，主场景改 shop.tscn，加 TimeLine/ShopState autoload |
| `godot/scripts/core/game_state.gd` | 删除 `pollution / sanity / owned_cards / tower_* / sequence_ranks / season_*`；保留 `spirit_stones / insights / equipped / inventory / last_settle_unix`；新增 `reputation` |
| `godot/scripts/core/event_bus.gd` | 删除战斗/塔/赛季/序列/事件信号；新增 `time_advanced / shop_upgraded / customer_arrived / forge_finished / equipment_lent / equipment_returned` |
| `godot/scripts/core/data_registry.gd` | INDEX_DIRS 替换为新数据类目（recipe/customer/gupu/su/narrative/gear/affix） |
| `godot/scripts/core/save_system.gd` | SAVE_VERSION → 2，新增 `_migrate_v1_to_v2` 删除旧字段 |
| `DESIGN.md` | 顶部加重定位指引 |
| `README.md` | 简介改为新游戏名+一句话 |

### 归档（移动到 _deprecated 不删除）

| 原路径 | 归档位置 |
|---|---|
| `godot/scripts/combat/` (整个目录) | `godot/scripts/_deprecated/combat/` |
| `godot/scripts/ui/combat_screen.gd` | `godot/scripts/_deprecated/ui/combat_screen.gd` |
| `godot/scripts/ui/cultivation_screen.gd` | `godot/scripts/_deprecated/ui/cultivation_screen.gd` |
| `godot/scripts/ui/forge_screen.gd` | `godot/scripts/_deprecated/ui/forge_screen.gd` |
| `godot/scripts/ui/tower_screen.gd` | `godot/scripts/_deprecated/ui/tower_screen.gd` |
| `godot/scripts/ui/card_reward_dialog.gd` | `godot/scripts/_deprecated/ui/card_reward_dialog.gd` |
| `godot/scripts/ui/city.gd` | `godot/scripts/_deprecated/ui/city.gd` |
| `godot/scripts/ui/hud.gd` | `godot/scripts/_deprecated/ui/hud.gd` |
| `godot/scripts/data/card_data.gd` | `godot/scripts/_deprecated/data/card_data.gd` |
| `godot/scripts/data/encounter_data.gd` | `godot/scripts/_deprecated/data/encounter_data.gd` |
| `godot/scripts/data/sequence_data.gd` | `godot/scripts/_deprecated/data/sequence_data.gd` |
| `godot/scripts/data/anomaly_data.gd` | `godot/scripts/_deprecated/data/anomaly_data.gd` |
| `godot/scripts/idle/idle_settlement.gd` | `godot/scripts/_deprecated/idle/idle_settlement.gd` |
| `godot/scripts/systems/loot_roller.gd` | `godot/scripts/_deprecated/systems/loot_roller.gd` |
| `godot/scripts/systems/stats_resolver.gd` | `godot/scripts/_deprecated/systems/stats_resolver.gd` |
| `godot/scenes/combat.tscn` | `godot/scenes/_deprecated/combat.tscn` |
| `godot/scenes/cultivation.tscn` | `godot/scenes/_deprecated/cultivation.tscn` |
| `godot/scenes/tower.tscn` | `godot/scenes/_deprecated/tower.tscn` |
| `godot/scenes/forge.tscn` | `godot/scenes/_deprecated/forge.tscn` |
| `godot/scenes/city.tscn` | `godot/scenes/_deprecated/city.tscn` |
| `godot/scenes/playtest.tscn` | `godot/scenes/_deprecated/playtest.tscn` |
| `godot/scenes/ui/` (整个目录) | `godot/scenes/_deprecated/ui/` |
| `godot/scripts/test/playtest_loop.gd` | `godot/scripts/_deprecated/test/playtest_loop.gd` |
| `godot/data/cards/` | `godot/data/_deprecated/cards/` |
| `godot/data/encounters/` | `godot/data/_deprecated/encounters/` |
| `godot/data/sequences/` | `godot/data/_deprecated/sequences/` |
| `godot/data/anomalies/` | `godot/data/_deprecated/anomalies/` |

> 现有 `godot/data/affixes/` 和 `godot/data/gear/` **保留**——装备和词缀系统在 N2 锻造里会复用并扩展，不归档。

---

## Phase A — N0 归档与字段清理

### Task 1: 创建归档目录骨架 + 移动战斗/塔/赛季/卡牌脚本

**Files:**
- Create dirs: `godot/scripts/_deprecated/{combat,ui,data,idle,systems,test}/`, `godot/scenes/_deprecated/ui/`, `godot/data/_deprecated/`
- Move: 见上文"归档"表

- [ ] **Step 1: 创建归档目录骨架**

```bash
mkdir -p godot/scripts/_deprecated/combat
mkdir -p godot/scripts/_deprecated/ui
mkdir -p godot/scripts/_deprecated/data
mkdir -p godot/scripts/_deprecated/idle
mkdir -p godot/scripts/_deprecated/systems
mkdir -p godot/scripts/_deprecated/test
mkdir -p godot/scenes/_deprecated/ui
mkdir -p godot/data/_deprecated
```

- [ ] **Step 2: 移动战斗 / UI / 数据 / idle / systems 脚本**

```bash
git mv godot/scripts/combat godot/scripts/_deprecated/combat
git mv godot/scripts/ui/combat_screen.gd       godot/scripts/_deprecated/ui/combat_screen.gd
git mv godot/scripts/ui/cultivation_screen.gd  godot/scripts/_deprecated/ui/cultivation_screen.gd
git mv godot/scripts/ui/forge_screen.gd        godot/scripts/_deprecated/ui/forge_screen.gd
git mv godot/scripts/ui/tower_screen.gd        godot/scripts/_deprecated/ui/tower_screen.gd
git mv godot/scripts/ui/card_reward_dialog.gd  godot/scripts/_deprecated/ui/card_reward_dialog.gd
git mv godot/scripts/ui/city.gd                godot/scripts/_deprecated/ui/city.gd
git mv godot/scripts/ui/hud.gd                 godot/scripts/_deprecated/ui/hud.gd
git mv godot/scripts/data/card_data.gd         godot/scripts/_deprecated/data/card_data.gd
git mv godot/scripts/data/encounter_data.gd    godot/scripts/_deprecated/data/encounter_data.gd
git mv godot/scripts/data/sequence_data.gd     godot/scripts/_deprecated/data/sequence_data.gd
git mv godot/scripts/data/anomaly_data.gd      godot/scripts/_deprecated/data/anomaly_data.gd
git mv godot/scripts/idle/idle_settlement.gd   godot/scripts/_deprecated/idle/idle_settlement.gd
git mv godot/scripts/systems/loot_roller.gd    godot/scripts/_deprecated/systems/loot_roller.gd
git mv godot/scripts/systems/stats_resolver.gd godot/scripts/_deprecated/systems/stats_resolver.gd
git mv godot/scripts/test/playtest_loop.gd     godot/scripts/_deprecated/test/playtest_loop.gd
```

- [ ] **Step 3: 移动 scenes**

```bash
git mv godot/scenes/combat.tscn       godot/scenes/_deprecated/combat.tscn
git mv godot/scenes/cultivation.tscn  godot/scenes/_deprecated/cultivation.tscn
git mv godot/scenes/tower.tscn        godot/scenes/_deprecated/tower.tscn
git mv godot/scenes/forge.tscn        godot/scenes/_deprecated/forge.tscn
git mv godot/scenes/city.tscn         godot/scenes/_deprecated/city.tscn
git mv godot/scenes/playtest.tscn     godot/scenes/_deprecated/playtest.tscn
git mv godot/scenes/ui                godot/scenes/_deprecated/ui
```

- [ ] **Step 4: 移动 data .tres**

```bash
git mv godot/data/cards       godot/data/_deprecated/cards
git mv godot/data/encounters  godot/data/_deprecated/encounters
git mv godot/data/sequences   godot/data/_deprecated/sequences
git mv godot/data/anomalies   godot/data/_deprecated/anomalies
```

- [ ] **Step 5: 在归档根写一个 README 说明**

Create `godot/_deprecated_README.md`:

```markdown
# 归档说明

本目录下所有内容来自 2026-04-30 之前的"卡牌战斗挂机"版本。
《我在诡异修仙造兵器》重定位后已弃用，但保留以便回查实现细节。

参见 `docs/superpowers/specs/2026-04-30-weird-cultivation-smith-design.md`。
```

```bash
echo "# 归档说明..." > godot/_deprecated_README.md  # 用 Write 工具写完整内容
```

- [ ] **Step 6: 提交归档**

```bash
git add -A godot/scripts/_deprecated godot/scenes/_deprecated godot/data/_deprecated godot/_deprecated_README.md
git commit -m "chore(N0): archive combat/tower/cards/cultivation to _deprecated

为 N1 铺子骨架清场。所有归档文件保留，不删除。"
```

---

### Task 2: 清理 game_state.gd（删除战斗/塔/赛季字段，新增声誉）

**Files:**
- Modify: `godot/scripts/core/game_state.gd`（整文件重写——目前 211 行，新版 ~120 行）

- [ ] **Step 1: 写测试场景外壳（先建文件以便 step 后续 mv）**

Create `godot/scenes/test/test_game_state.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_game_state.gd" id="1"]

[node name="TestGameState" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试脚本验证新字段存在 + 序列化对称**

Create `godot/scripts/test/test_game_state.gd`:

```gdscript
extends Node
## 验证 GameState 新字段集合 + 序列化对称。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_fields_exist()
	_test_serialize_roundtrip()
	_test_no_deprecated_fields()
	print("\n========== test_game_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_fields_exist() -> void:
	GameState.spirit_stones = 100
	GameState.insights = 5
	GameState.reputation = 10
	GameState.last_settle_unix = 1700000000
	_assert(GameState.spirit_stones == 100, "spirit_stones writable")
	_assert(GameState.insights == 5, "insights writable")
	_assert(GameState.reputation == 10, "reputation writable")
	_assert(GameState.last_settle_unix == 1700000000, "last_settle_unix writable")


func _test_serialize_roundtrip() -> void:
	GameState.spirit_stones = 42
	GameState.insights = 7
	GameState.reputation = 15
	GameState.last_settle_unix = 1700001234
	var d: Dictionary = GameState.to_dict()
	# 重置后再读回
	GameState.spirit_stones = 0
	GameState.insights = 0
	GameState.reputation = 0
	GameState.last_settle_unix = 0
	GameState.from_dict(d)
	_assert(GameState.spirit_stones == 42, "spirit_stones roundtrip")
	_assert(GameState.insights == 7, "insights roundtrip")
	_assert(GameState.reputation == 15, "reputation roundtrip")
	_assert(GameState.last_settle_unix == 1700001234, "last_settle_unix roundtrip")


func _test_no_deprecated_fields() -> void:
	# 已删字段不应出现在 to_dict() 输出里
	var d: Dictionary = GameState.to_dict()
	for bad_key in ["pollution", "sanity", "owned_cards", "tower_floor",
			"tower_max_reached", "sequence_ranks", "season_id", "season_started_unix"]:
		_assert(not d.has(bad_key), "to_dict has no '%s'" % bad_key)
```

- [ ] **Step 3: 跑测试，确认它失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_game_state.tscn
```

预期：FAIL（旧 GameState 还有 pollution/sanity/owned_cards 等字段，且没有 reputation）

- [ ] **Step 4: 整文件重写 game_state.gd**

Replace entire content of `godot/scripts/core/game_state.gd`:

```gdscript
extends Node
## 游戏运行时状态（Autoload 单例）。
## 只持有"现在的事实"，不持有静态配置（配置在 DataRegistry）。
## 修改字段必须 emit 对应 EventBus 信号；UI 不得直接读后轮询。

# ── 货币 ──────────────────────────────────────
var spirit_stones: int = 0       # 灵石
var insights: int = 0            # 见闻

# ── 声誉 ──────────────────────────────────────
var reputation: int = 0          # 名望（接客/留赏积累，影响来客质量）

# ── 时间 ──────────────────────────────────────
var last_settle_unix: int = 0    # 上次结算时间戳（用于离线产出计算）

# ── 装备 / 库存 ────────────────────────────────
## slot_int -> GearInstance（保留供 N2 锻造使用）
var equipped: Dictionary = {}
## 库存：未派出的 GearInstance 列表
var inventory: Array = []


func add_currency(kind: StringName, amount: int) -> void:
	match kind:
		&"spirit_stones": spirit_stones += amount
		&"insights": insights += amount
		_:
			push_warning("unknown currency: %s" % kind)
			return
	EventBus.currency_changed.emit(kind, _read_currency(kind))


func spend_currency(kind: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var cur: int = _read_currency(kind)
	if cur < amount:
		return false
	add_currency(kind, -amount)
	return true


func add_reputation(delta: int) -> void:
	reputation = max(0, reputation + delta)
	EventBus.reputation_changed.emit(reputation)


# ── 装备方法 ──────────────────────────────────
func equip_gear(inst: GearInstance) -> void:
	if inst == null: return
	var base: GearData = inst.get_base()
	if base == null: return
	var slot: int = int(base.slot)
	if equipped.has(slot) and equipped[slot] != null:
		inventory.append(equipped[slot])
	inventory.erase(inst)
	equipped[slot] = inst
	EventBus.gear_equipped.emit(StringName(str(slot)), inst.base_id)


func unequip_slot(slot: int) -> void:
	if not equipped.has(slot) or equipped[slot] == null: return
	inventory.append(equipped[slot])
	equipped[slot] = null
	EventBus.gear_equipped.emit(StringName(str(slot)), &"")


func add_to_inventory(inst: GearInstance) -> void:
	if inst == null: return
	inventory.append(inst)
	EventBus.loot_dropped.emit([inst])


func _read_currency(kind: StringName) -> int:
	match kind:
		&"spirit_stones": return spirit_stones
		&"insights": return insights
		_: return 0


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var equipped_ser: Dictionary = {}
	for slot in equipped:
		var inst: GearInstance = equipped[slot]
		if inst != null:
			equipped_ser[str(slot)] = inst.to_dict()
	var inv_ser: Array = []
	for inst: GearInstance in inventory:
		if inst != null:
			inv_ser.append(inst.to_dict())
	return {
		"spirit_stones": spirit_stones,
		"insights": insights,
		"reputation": reputation,
		"last_settle_unix": last_settle_unix,
		"equipped": equipped_ser,
		"inventory": inv_ser,
	}


func from_dict(d: Dictionary) -> void:
	spirit_stones = int(d.get("spirit_stones", 0))
	insights = int(d.get("insights", 0))
	reputation = int(d.get("reputation", 0))
	last_settle_unix = int(d.get("last_settle_unix", 0))

	equipped = {}
	var eq_raw: Dictionary = d.get("equipped", {})
	for k in eq_raw:
		var inst := GearInstance.from_dict(eq_raw[k])
		equipped[int(str(k))] = inst
	inventory = []
	var inv_raw: Array = d.get("inventory", [])
	for it in inv_raw:
		inventory.append(GearInstance.from_dict(it))
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_game_state.tscn
```

预期：`PASS: 16  FAIL: 0`

> 此处会因 EventBus 还没有 `reputation_changed` 信号报错——这是预期，下一个 task 修。**先继续 task 3，task 3 完成后回来重跑此测试**。

- [ ] **Step 6: 暂不 commit**（等 task 3 修完 EventBus 一起 commit）

---

### Task 3: 清理 event_bus.gd（删除战斗/塔/赛季信号，新增铺子信号）

**Files:**
- Modify: `godot/scripts/core/event_bus.gd`（整文件重写）

- [ ] **Step 1: 整文件重写 event_bus.gd**

Replace entire content of `godot/scripts/core/event_bus.gd`:

```gdscript
extends Node
## 全局事件总线（Autoload 单例）。
## UI 与逻辑解耦的唯一通道。任何跨模块通信优先走这里，避免 get_node 耦合。
## 命名规范：信号名用过去时（forge_finished 而非 finish_forge）。

# ── 货币 / 声誉 ────────────────────────────────
signal currency_changed(kind: StringName, value: int)
signal reputation_changed(value: int)

# ── 装备 ──────────────────────────────────────
signal gear_equipped(slot: StringName, gear_id: StringName)
signal loot_dropped(items: Array)

# ── 时间线 ────────────────────────────────────
signal time_advanced(new_unix: int, delta_sec: int)   # 每次时间推进
signal hour_passed(shichen_index: int)                # 跨时辰（=2小时）触发，参数：当前时辰索引 0..11

# ── 铺子 ──────────────────────────────────────
signal shop_upgraded(area: StringName, new_level: int)  # 区域升级（炉房/柜台/阁楼/后院）
signal shop_rule_changed(slot_index: int)               # 铺规槽变更

# ── 锻造 ──────────────────────────────────────
signal forge_started(recipe_id: StringName)
signal forge_finished(gear_inst: Resource, was_qiao_cheng: bool, was_backlash: bool)

# ── 客人 / 派发 ────────────────────────────────
signal customer_arrived(customer_inst: Resource)
signal equipment_lent(customer_id: StringName, gear_inst: Resource)
signal equipment_returned(customer_id: StringName, gear_inst: Resource, outcome: StringName)
signal customer_left(customer_id: StringName, was_refused: bool)

# ── 器谱 / 共鸣 ────────────────────────────────
signal star_lit(gupu_id: StringName, su_id: StringName, gear_inst: Resource)
signal resonance_activated(gupu_id: StringName, pattern_id: StringName)

# ── 存档 ──────────────────────────────────────
signal save_loaded()
signal save_written()
```

- [ ] **Step 2: 跑 game_state 测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_game_state.tscn
```

预期：`PASS: 16  FAIL: 0`

- [ ] **Step 3: 验证旧引用都已断**

Run grep for any leftover deprecated signal/field references in non-`_deprecated/` paths:

```bash
grep -rn "EventBus\.\(combat_started\|combat_ended\|card_played\|unit_damaged\|unit_died\|sequence_advanced\|ritual_failed\|anomaly_triggered\|anomaly_resolved\|season_rolled\|pollution_changed\|sanity_changed\|gear_reforged\|idle_settled\)" godot/scripts --include="*.gd" | grep -v "_deprecated"
```

预期：无输出（任何输出都意味着有引用没清干净，需要修）

```bash
grep -rn "GameState\.\(pollution\|sanity\|owned_cards\|tower_\|sequence_ranks\|season_\|ensure_starter_deck\|tower_unlock_next\|add_pollution\|set_sanity\|add_card\)" godot/scripts --include="*.gd" | grep -v "_deprecated"
```

预期：无输出

- [ ] **Step 4: 提交 task 2 + task 3**

```bash
git add godot/scripts/core/game_state.gd godot/scripts/core/event_bus.gd \
        godot/scripts/test/test_game_state.gd godot/scenes/test/test_game_state.tscn
git commit -m "refactor(N0): GameState 清理战斗/塔/赛季字段；EventBus 重写信号集

- GameState 删除 pollution/sanity/owned_cards/tower_*/sequence_ranks/season_*
- 新增 reputation 字段及 add_reputation()
- EventBus 删除战斗/塔/赛季/序列/事件信号
- 新增时间线/铺子/锻造/客人/器谱信号集
- 测试: test_game_state 16 PASS"
```

---

### Task 4: 升级存档 v1→v2（迁移旧字段、新增 reputation）

**Files:**
- Modify: `godot/scripts/core/save_system.gd`
- Create: `godot/scripts/test/test_save_migration.gd`
- Create: `godot/scenes/test/test_save_migration.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_save_migration.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_save_migration.gd" id="1"]

[node name="TestSaveMigration" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写迁移测试（v1 老存档 → v2 新结构）**

Create `godot/scripts/test/test_save_migration.gd`:

```gdscript
extends Node
## 验证 v1 旧存档能被读取并迁移到 v2 结构。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_v1_payload_migrates()
	_test_v2_payload_unchanged()
	print("\n========== test_save_migration ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_v1_payload_migrates() -> void:
	var v1 := {
		"version": 1,
		"saved_at": 1700000000,
		"game_state": {
			"spirit_stones": 333,
			"insights": 11,
			"pollution": 50,
			"sanity": 80,
			"sequence_ranks": {"sword": 7},
			"last_settle_unix": 1700000000,
			"season_id": "s0_origin",
			"season_started_unix": 1700000000,
			"equipped": {},
			"inventory": [],
			"owned_cards": ["sword_strike"],
			"tower_floor": 3,
			"tower_max_reached": 5,
		}
	}
	var migrated := SaveSystem.migrate(v1)  # 测试用 public wrapper（task 3 要加）
	_assert(int(migrated.get("version", 0)) == SaveSystem.SAVE_VERSION, "version bumped to v2")
	var gs: Dictionary = migrated.get("game_state", {})
	_assert(int(gs.get("spirit_stones", 0)) == 333, "spirit_stones preserved")
	_assert(int(gs.get("insights", 0)) == 11, "insights preserved")
	_assert(int(gs.get("last_settle_unix", 0)) == 1700000000, "last_settle_unix preserved")
	_assert(int(gs.get("reputation", -1)) == 0, "reputation defaulted to 0")
	for bad in ["pollution", "sanity", "sequence_ranks", "season_id",
			"season_started_unix", "owned_cards", "tower_floor", "tower_max_reached"]:
		_assert(not gs.has(bad), "v1 field '%s' stripped" % bad)


func _test_v2_payload_unchanged() -> void:
	var v2 := {
		"version": 2,
		"saved_at": 1700001234,
		"game_state": {
			"spirit_stones": 100,
			"insights": 5,
			"reputation": 20,
			"last_settle_unix": 1700001234,
			"equipped": {},
			"inventory": [],
		}
	}
	var migrated := SaveSystem.migrate(v2)
	_assert(int(migrated.get("version", 0)) == 2, "v2 stays at 2")
	var gs: Dictionary = migrated.get("game_state", {})
	_assert(int(gs.get("reputation", 0)) == 20, "v2 reputation preserved")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_migration.tscn
```

预期：FAIL（`SaveSystem.migrate` 不存在；SAVE_VERSION 还是 1）

- [ ] **Step 4: 改写 save_system.gd 加迁移**

Replace entire content of `godot/scripts/core/save_system.gd`:

```gdscript
extends Node
## 存档系统（Autoload 单例）。
## - JSON 文本存档。
## - 带版本号 + migration 链。
## - 写入 5 秒最小间隔限流。

const SAVE_PATH := "user://save_main.json"
const SAVE_VERSION := 2
const WRITE_COOLDOWN_SEC := 5.0

var _last_write_msec: int = -10000


func save_now(force: bool = false) -> bool:
	var now_msec := Time.get_ticks_msec()
	if not force and now_msec - _last_write_msec < int(WRITE_COOLDOWN_SEC * 1000.0):
		return false
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	_last_write_msec = now_msec
	EventBus.save_written.emit()
	return true


func load_or_init() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_new_game()
		EventBus.save_loaded.emit()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save: corrupted, reinit")
		_init_new_game()
		EventBus.save_loaded.emit()
		return
	parsed = migrate(parsed)
	var gs: Dictionary = parsed.get("game_state", {})
	GameState.from_dict(gs)
	EventBus.save_loaded.emit()


func _init_new_game() -> void:
	GameState.last_settle_unix = int(Time.get_unix_time_from_system())


## 公开 wrapper，供测试与外部调用使用
func migrate(payload: Dictionary) -> Dictionary:
	var v := int(payload.get("version", 1))
	while v < SAVE_VERSION:
		match v:
			1:
				payload = _migrate_v1_to_v2(payload)
			_:
				push_warning("save: no migration from v%d" % v)
				break
		v += 1
	payload["version"] = SAVE_VERSION
	return payload


## v1 → v2: 删除战斗/塔/赛季字段；保留 spirit_stones/insights/last_settle_unix/equipped/inventory；
## 新增 reputation 默认 0
func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	for bad in ["pollution", "pollution_cap", "sanity", "sanity_cap",
			"sequence_ranks", "season_id", "season_started_unix",
			"owned_cards", "tower_floor", "tower_max_reached"]:
		gs.erase(bad)
	if not gs.has("reputation"):
		gs["reputation"] = 0
	payload["game_state"] = gs
	return payload
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_migration.tscn
```

预期：`PASS: 16  FAIL: 0`

- [ ] **Step 6: 提交**

```bash
git add godot/scripts/core/save_system.gd \
        godot/scripts/test/test_save_migration.gd godot/scenes/test/test_save_migration.tscn
git commit -m "feat(N0): SaveSystem v1→v2 迁移，剥离战斗/塔/赛季字段，引入 reputation

- SAVE_VERSION 升 v2
- _migrate_v1_to_v2 删除 pollution/sanity/owned_cards/tower_*/sequence_ranks/season_*
- 新增 reputation 字段默认 0
- 公开 migrate() 供测试调用
- 测试: test_save_migration 16 PASS"
```

---

### Task 5: 清理 data_registry.gd 索引（移除卡/序列/事件类目）

**Files:**
- Modify: `godot/scripts/core/data_registry.gd`

- [ ] **Step 1: 修改 INDEX_DIRS**

Replace lines 6-14 of `godot/scripts/core/data_registry.gd`:

Find:
```gdscript
const INDEX_DIRS := {
	&"card": "res://data/cards",
	&"gear": "res://data/gear",
	&"affix": "res://data/affixes",
	&"sequence": "res://data/sequences",
	&"anomaly": "res://data/anomalies",
	&"encounter": "res://data/encounters",
}
```

Replace with:
```gdscript
const INDEX_DIRS := {
	&"gear": "res://data/gear",
	&"affix": "res://data/affixes",
	&"recipe": "res://data/recipes",
	&"customer": "res://data/customers",
	&"gupu": "res://data/gupu",
	&"su": "res://data/sus",
	&"narrative": "res://data/narratives",
}
```

- [ ] **Step 2: 创建空数据目录的 .gdignore 占位（防 ResourceLoader 扫到不存在的目录报错）**

```bash
mkdir -p godot/data/recipes godot/data/customers godot/data/gupu godot/data/sus godot/data/narratives
```

For each empty dir, create a `.gdignore` placeholder:

```bash
touch godot/data/recipes/.gdignore
touch godot/data/customers/.gdignore
touch godot/data/gupu/.gdignore
touch godot/data/sus/.gdignore
touch godot/data/narratives/.gdignore
```

> `.gdignore` 是 Godot 4 约定：让目录被识别为非 Godot 资源目录，避免无 .tres 时引擎报警。但目录仍能被 DirAccess.list_dir 扫到——这正是我们要的：扫到空就返回空字典。

- [ ] **Step 3: 验证 DataRegistry 启动不崩**

Use existing autoload to confirm `_ready()` doesn't crash on empty dirs—快速跑一下任意 headless 测试：

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_migration.tscn
```

预期：测试照常 PASS（autoload 全部成功初始化，包括 DataRegistry）

- [ ] **Step 4: 提交**

```bash
git add godot/scripts/core/data_registry.gd godot/data/recipes godot/data/customers \
        godot/data/gupu godot/data/sus godot/data/narratives
git commit -m "chore(N0): DataRegistry 索引切到新数据类目（recipe/customer/gupu/su/narrative）

- 移除 card/sequence/anomaly/encounter
- 保留 gear/affix（N2 锻造仍用）
- 创建空目录 + .gdignore 占位"
```

---

### Task 6: 项目配置切换（项目名、临时移除已归档主场景的引用）

**Files:**
- Modify: `godot/project.godot`

- [ ] **Step 1: 编辑 project.godot**

Find:
```
config/name="仙兵传"
config/description="诡异修仙 + 挂机卡牌 + 暗黑 Build 构筑"
run/main_scene="res://scenes/city.tscn"
```

Replace with:
```
config/name="我在诡异修仙造兵器"
config/description="诡异修仙 + 造兵器 + 单机挂机"
run/main_scene="res://scenes/_deprecated/city.tscn"
```

> 主场景**先暂时**指向归档版 city.tscn（虽然能跑但 city.gd 还引用了已删信号会报警告——能跑就行）。Task 14 把它换成 shop.tscn。

- [ ] **Step 2: F5 / 命令行启动验证不崩**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --quit-after 2
```

预期：进程正常退出（exit code 0），可能有 warning 但不崩。

- [ ] **Step 3: 提交（N0 阶段收尾 commit）**

```bash
git add godot/project.godot
git commit -m "chore(N0): 项目名改为《我在诡异修仙造兵器》，主场景临时指向归档版

主场景将在 N1 task 14 切到 shop.tscn"
```

---

## Phase B — N1 数据 Resource Schema

> 这一阶段创建 5 个 Resource 类骨架。每个类先有字段定义和 to_dict/from_dict（如需要），暂不填业务方法。N2 起逐步使用时再扩展。

### Task 7: RecipeData Resource 类

**Files:**
- Create: `godot/scripts/data/recipe_data.gd`
- Create: `godot/scripts/test/test_recipe_data.gd`
- Create: `godot/scenes/test/test_recipe_data.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_recipe_data.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_recipe_data.gd" id="1"]

[node name="TestRecipeData" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_recipe_data.gd`:

```gdscript
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_quality_distribution_sum()
	print("\n========== test_recipe_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_basic() -> void:
	var r := RecipeData.new()
	r.id = &"sword_basic"
	r.display_name = "凡铁剑"
	r.required_materials = {&"iron": 2, &"jin": 4}
	r.optional_materials = [&"zhusha", &"hui"]
	r.base_quality_distribution = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])
	r.base_minutes_in_furnace = 30
	_assert(r.id == &"sword_basic", "id set")
	_assert(r.display_name == "凡铁剑", "display_name set")
	_assert(r.required_materials.has(&"iron"), "required_materials map")
	_assert(r.base_quality_distribution.size() == 5, "5-tier quality")
	_assert(r.base_minutes_in_furnace == 30, "base_minutes_in_furnace set")


func _test_quality_distribution_sum() -> void:
	var r := RecipeData.new()
	r.base_quality_distribution = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])
	var s: float = 0.0
	for x in r.base_quality_distribution:
		s += x
	_assert(abs(s - 1.0) < 0.001, "distribution sums to 1.0 (got %.3f)" % s)
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_recipe_data.tscn
```

预期：FAIL（RecipeData 不存在）

- [ ] **Step 4: 创建 recipe_data.gd**

Create `godot/scripts/data/recipe_data.gd`:

```gdscript
class_name RecipeData
extends Resource
## 锻造配方。每个配方 = 一种兵器型号的烧法。
## 静态资源，存为 .tres，运行时不变。

## 唯一 id（snake_case）
@export var id: StringName = &""

## 显示名（中文），如 "凡铁剑"
@export var display_name: String = ""

## 必要材料：material_id -> 数量
@export var required_materials: Dictionary = {}

## 可选添料 ID 列表（玩家选 0..N 件加入）
@export var optional_materials: Array[StringName] = []

## 基准品质分布 [凡, 灵, 法, 禁, 秘]，应总和 1.0
@export var base_quality_distribution: PackedFloat32Array = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])

## 离线模式下单炉所需分钟（在线手动开炉走另一套时长，与本字段无关）
@export var base_minutes_in_furnace: int = 30

## 该配方主要属于的道途（剑/咒/傀/丹/食/卜），用于客人匹配
@export var path_affinity: StringName = &"sword"

## 槽位类型（剑/符/傀核/丹炉/食器/卦盘）
@export var slot_kind: StringName = &"sword"
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_recipe_data.tscn
```

预期：`PASS: 6  FAIL: 0`

- [ ] **Step 6: 提交**

```bash
git add godot/scripts/data/recipe_data.gd \
        godot/scripts/test/test_recipe_data.gd godot/scenes/test/test_recipe_data.tscn
git commit -m "feat(N1): RecipeData Resource 类（锻造配方）"
```

---

### Task 8: CustomerData Resource 类

**Files:**
- Create: `godot/scripts/data/customer_data.gd`
- Create: `godot/scripts/test/test_customer_data.gd`
- Create: `godot/scenes/test/test_customer_data.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_customer_data.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_customer_data.gd" id="1"]

[node name="TestCustomerData" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_customer_data.gd`:

```gdscript
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_tier_enum()
	print("\n========== test_customer_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_basic() -> void:
	var c := CustomerData.new()
	c.id = &"su_jia_niangzi"
	c.display_name = "苏家娘子"
	c.tier = CustomerData.Tier.REGULAR
	c.path_affinity = &"sword"
	c.base_payment = 200
	c.faction = &"hanxing_zong"
	_assert(c.id == &"su_jia_niangzi", "id set")
	_assert(c.tier == CustomerData.Tier.REGULAR, "tier REGULAR")
	_assert(c.base_payment == 200, "base_payment set")


func _test_tier_enum() -> void:
	_assert(CustomerData.Tier.REGULAR == 0, "REGULAR=0")
	_assert(CustomerData.Tier.RARE == 1, "RARE=1")
	_assert(CustomerData.Tier.WEIRD == 2, "WEIRD=2")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_customer_data.tscn
```

预期：FAIL（CustomerData 不存在）

- [ ] **Step 4: 创建 customer_data.gd**

Create `godot/scripts/data/customer_data.gd`:

```gdscript
class_name CustomerData
extends Resource
## 客人模板。运行时实例化为"一次访问"。

enum Tier { REGULAR = 0, RARE = 1, WEIRD = 2 }

## 唯一 id
@export var id: StringName = &""

## 显示名
@export var display_name: String = ""

## 客人品阶
@export var tier: Tier = Tier.REGULAR

## 流派亲和（剑/咒/傀/丹/食/卜）
@export var path_affinity: StringName = &"sword"

## 所属势力 id（背景板）
@export var faction: StringName = &"unknown"

## 基础酬金（灵石）
@export var base_payment: int = 100

## 出现条件（spec §6 + §8）：
## 时辰范围（0=子, 1=丑..11=亥），空数组=任意时辰
@export var allowed_shichen: Array[int] = []

## 当此势力"动态状态"激活时来访权重 +N（N1 暂不实装动态状态，留字段）
@export var faction_state_bonus: float = 0.0

## 客人剪影/立绘资源路径（N1 用 placeholder）
@export var portrait_path: String = ""
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_customer_data.tscn
```

预期：`PASS: 6  FAIL: 0`

- [ ] **Step 6: 提交**

```bash
git add godot/scripts/data/customer_data.gd \
        godot/scripts/test/test_customer_data.gd godot/scenes/test/test_customer_data.tscn
git commit -m "feat(N1): CustomerData Resource 类（客人模板，3 档 Tier）"
```

---

### Task 9: SuData + GuPuData Resource 类（先 Su，因 GuPu 引用 Su）

**Files:**
- Create: `godot/scripts/data/su_data.gd`
- Create: `godot/scripts/data/gupu_data.gd`
- Create: `godot/scripts/test/test_gupu_data.gd`
- Create: `godot/scenes/test/test_gupu_data.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_gupu_data.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_gupu_data.gd" id="1"]

[node name="TestGuPuData" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_gupu_data.gd`:

```gdscript
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_su_basic()
	_test_gupu_basic()
	_test_gupu_holds_28_su()
	print("\n========== test_gupu_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_su_basic() -> void:
	var s := SuData.new()
	s.id = &"jiao_su"
	s.display_name = "角宿"
	s.match_path = &"sword"
	s.match_quality_min = 0   # 凡=0
	s.match_quality_max = 4   # 秘=4
	s.position_x = 0.2
	s.position_y = 0.3
	_assert(s.id == &"jiao_su", "id set")
	_assert(s.match_path == &"sword", "match_path set")
	_assert(s.position_x == 0.2 and s.position_y == 0.3, "position set")


func _test_gupu_basic() -> void:
	var g := GuPuData.new()
	g.id = &"qing_long"
	g.display_name = "青龙宿"
	g.theme = "剑系兵器"
	g.resonance_description = "出借兵器斩妖时回信故事强度 +1 级"
	_assert(g.id == &"qing_long", "id set")
	_assert(g.display_name == "青龙宿", "display_name set")


func _test_gupu_holds_28_su() -> void:
	var g := GuPuData.new()
	# 创建 28 颗占位 Su
	var sus: Array[SuData] = []
	for i in range(28):
		var s := SuData.new()
		s.id = StringName("su_%d" % i)
		sus.append(s)
	g.stars = sus
	_assert(g.stars.size() == 28, "gupu holds 28 stars")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_gupu_data.tscn
```

预期：FAIL（SuData / GuPuData 不存在）

- [ ] **Step 4: 创建 su_data.gd**

Create `godot/scripts/data/su_data.gd`:

```gdscript
class_name SuData
extends Resource
## 单星宿——古谱里的一颗预设星位。
## 装备出炉后按 (path, quality) 落入哪颗星，由本类的 match_* 字段决定。

## 唯一 id（在所属古谱内唯一）
@export var id: StringName = &""

## 显示名，如 "角宿"
@export var display_name: String = ""

## 落点匹配：必须满足装备的 path_affinity == match_path
@export var match_path: StringName = &"sword"

## 落点匹配：装备的 quality 必须 ∈ [match_quality_min, match_quality_max]
## 0=凡 1=灵 2=法 3=禁 4=秘
@export_range(0, 4) var match_quality_min: int = 0
@export_range(0, 4) var match_quality_max: int = 4

## 在星图上的归一化坐标 (0..1)
@export_range(0.0, 1.0) var position_x: float = 0.0
@export_range(0.0, 1.0) var position_y: float = 0.0
```

- [ ] **Step 5: 创建 gupu_data.gd**

Create `godot/scripts/data/gupu_data.gd`:

```gdscript
class_name GuPuData
extends Resource
## 古谱：28 颗 SuData 的集合 + 共鸣效果定义。
## 玩家可在多张古谱视图间切换；每张古谱独立计算"已点亮星位"。

## 唯一 id
@export var id: StringName = &""

## 显示名，如 "青龙宿"
@export var display_name: String = ""

## 主题描述，如 "剑系兵器"
@export var theme: String = ""

## 共鸣文字描述（凑齐 28 颗后触发的效果说明）
@export var resonance_description: String = ""

## 28 颗星宿（应固定 28 个，编辑器中保证）
@export var stars: Array[SuData] = []

## 主脉骨架连线：每对 (i, j) 表示 stars[i] 和 stars[j] 之间有预设主脉
## 用 PackedInt32Array 存 [i0, j0, i1, j1, ...]
@export var preset_lines: PackedInt32Array = PackedInt32Array()
```

- [ ] **Step 6: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_gupu_data.tscn
```

预期：`PASS: 6  FAIL: 0`

- [ ] **Step 7: 提交**

```bash
git add godot/scripts/data/su_data.gd godot/scripts/data/gupu_data.gd \
        godot/scripts/test/test_gupu_data.gd godot/scenes/test/test_gupu_data.tscn
git commit -m "feat(N1): SuData + GuPuData Resource 类（28 宿 / 古谱骨架）"
```

---

### Task 10: NarrativeCard Resource 类

**Files:**
- Create: `godot/scripts/data/narrative_card.gd`
- Create: `godot/scripts/test/test_narrative_card.gd`
- Create: `godot/scenes/test/test_narrative_card.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_narrative_card.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_narrative_card.gd" id="1"]

[node name="TestNarrativeCard" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_narrative_card.gd`:

```gdscript
extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_trigger_enum()
	print("\n========== test_narrative_card ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_basic() -> void:
	var n := NarrativeCard.new()
	n.id = &"first_weird_customer"
	n.trigger = NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST
	n.body = "丑时三刻，门外起雾。蒙面客以三百灵石求借兵器，他没踩出脚印。"
	_assert(n.id == &"first_weird_customer", "id set")
	_assert(n.trigger == NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST, "trigger set")
	_assert(n.body.length() > 0, "body has content")


func _test_trigger_enum() -> void:
	_assert(NarrativeCard.Trigger.CUSTOMER_FIRST == 0, "CUSTOMER_FIRST=0")
	_assert(NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST == 1, "WEIRD_CUSTOMER_FIRST=1")
	_assert(NarrativeCard.Trigger.BACKLASH == 2, "BACKLASH=2")
	_assert(NarrativeCard.Trigger.QIAO_CHENG == 3, "QIAO_CHENG=3")
	_assert(NarrativeCard.Trigger.RESONANCE == 4, "RESONANCE=4")
	_assert(NarrativeCard.Trigger.NOT_RETURNED == 5, "NOT_RETURNED=5")
	_assert(NarrativeCard.Trigger.OLD_IRON_MUTTER == 6, "OLD_IRON_MUTTER=6")
	_assert(NarrativeCard.Trigger.IDENTITY_FRAGMENT == 7, "IDENTITY_FRAGMENT=7")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_narrative_card.tscn
```

预期：FAIL（NarrativeCard 不存在）

- [ ] **Step 4: 创建 narrative_card.gd**

Create `godot/scripts/data/narrative_card.gd`:

```gdscript
class_name NarrativeCard
extends Resource
## 手写叙事卡片。一段文本 + 触发条件。
## 程序化拼装日记段落走另一套（N5 实现）。

enum Trigger {
	CUSTOMER_FIRST = 0,           ## 客人首次到访
	WEIRD_CUSTOMER_FIRST = 1,     ## 怪客离奇行为
	BACKLASH = 2,                 ## 反噬异象
	QIAO_CHENG = 3,               ## 巧成 / 秘品出炉
	RESONANCE = 4,                ## 共鸣激活
	NOT_RETURNED = 5,             ## 不归还回流
	OLD_IRON_MUTTER = 6,          ## 老铁自言自语
	IDENTITY_FRAGMENT = 7,        ## 老铁身份暗线碎片
}

@export var id: StringName = &""

@export var trigger: Trigger = Trigger.OLD_IRON_MUTTER

## 主体文本（可含 \n 换行；不超过 500 字符——见 spec §12.2）
@export_multiline var body: String = ""

## 触发条件附加：当 trigger 是 CUSTOMER_FIRST 时，限定特定客人 id（空=任意）
@export var customer_id_filter: StringName = &""

## 触发条件附加：触发后是否一次性消耗（true=只触发一次，false=可反复触发）
@export var one_shot: bool = false
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_narrative_card.tscn
```

预期：`PASS: 11  FAIL: 0`

- [ ] **Step 6: 提交**

```bash
git add godot/scripts/data/narrative_card.gd \
        godot/scripts/test/test_narrative_card.gd godot/scenes/test/test_narrative_card.tscn
git commit -m "feat(N1): NarrativeCard Resource 类（叙事卡片，8 类 Trigger）"
```

---

## Phase C — N1 TimeLine Autoload

### Task 11: TimeLine 核心实现

**Files:**
- Create: `godot/scripts/core/time_line.gd`
- Create: `godot/scripts/test/test_time_line.gd`
- Create: `godot/scenes/test/test_time_line.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_time_line.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_time_line.gd" id="1"]

[node name="TestTimeLine" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_time_line.gd`:

```gdscript
extends Node
## TimeLine：时间线推进、时辰判定、离线时长衰减。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_now_unix_positive()
	_test_shichen_index()
	_test_advance_emits_signal()
	_test_offline_decay()
	print("\n========== test_time_line ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_now_unix_positive() -> void:
	_assert(TimeLine.now_unix() > 0, "now_unix > 0")


func _test_shichen_index() -> void:
	# 时辰=2小时一个，索引 0..11
	# 给定 unix 时间戳，应返回正确索引
	# unix 时间戳 0 = 1970-01-01 00:00:00 UTC = 子时（0）
	_assert(TimeLine.shichen_of_unix(0) == 0, "unix 0 => 子时(0)")
	_assert(TimeLine.shichen_of_unix(2 * 3600) == 1, "unix 2h => 丑时(1)")
	_assert(TimeLine.shichen_of_unix(22 * 3600) == 11, "unix 22h => 亥时(11)")
	_assert(TimeLine.shichen_of_unix(24 * 3600) == 0, "unix 24h => 子时(0) again")


func _test_advance_emits_signal() -> void:
	var emitted: Array = []
	var cb := func(new_unix: int, delta: int) -> void:
		emitted.append({"unix": new_unix, "delta": delta})
	EventBus.time_advanced.connect(cb)
	TimeLine.set_now_unix(1700000000)
	TimeLine.advance_seconds(3600)
	_assert(emitted.size() == 1, "time_advanced emitted once")
	_assert(emitted[0]["delta"] == 3600, "delta = 3600")
	_assert(emitted[0]["unix"] == 1700003600, "new unix correct")
	EventBus.time_advanced.disconnect(cb)


func _test_offline_decay() -> void:
	# 单次离线 ≤24h 全额；24-72h 70% 衰减；>72h 30% 衰减
	# 函数 effective_offline_seconds(raw) 给出衰减后秒数
	var h := 3600
	_assert(TimeLine.effective_offline_seconds(12 * h) == 12 * h, "12h: full")
	_assert(TimeLine.effective_offline_seconds(24 * h) == 24 * h, "24h: full (boundary)")

	# 25h: 24h 全 + 1h × 0.7 = 24*3600 + 0.7*3600 = 24h + 2520s
	var got_25 := TimeLine.effective_offline_seconds(25 * h)
	var want_25 := 24 * h + int(round(1 * h * 0.7))
	_assert(got_25 == want_25, "25h: got %d want %d" % [got_25, want_25])

	# 72h: 24h 全 + 48h × 0.7 = 24h + 33.6h
	var got_72 := TimeLine.effective_offline_seconds(72 * h)
	var want_72 := 24 * h + int(round(48 * h * 0.7))
	_assert(got_72 == want_72, "72h: got %d want %d" % [got_72, want_72])

	# 100h: 24h 全 + 48h × 0.7 + 28h × 0.3
	var got_100 := TimeLine.effective_offline_seconds(100 * h)
	var want_100 := 24 * h + int(round(48 * h * 0.7)) + int(round(28 * h * 0.3))
	_assert(got_100 == want_100, "100h: got %d want %d" % [got_100, want_100])
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_time_line.tscn
```

预期：FAIL（TimeLine autoload 不存在）

- [ ] **Step 4: 创建 time_line.gd**

Create `godot/scripts/core/time_line.gd`:

```gdscript
extends Node
## 时间线 Autoload。
## 负责：当前游戏时间戳、时辰判定、advance_seconds 推进信号、离线时长衰减计算。
## 时辰 = 2 小时。索引 0=子, 1=丑, 2=寅, 3=卯, 4=辰, 5=巳, 6=午, 7=未, 8=申, 9=酉, 10=戌, 11=亥。

const SECONDS_PER_SHICHEN: int = 7200  # 2h

const FULL_THRESHOLD_SEC: int = 86400          # 24h
const DECAY_THRESHOLD_SEC: int = 259200        # 72h
const DECAY_RATE_TIER1: float = 0.7            # 24-72h
const DECAY_RATE_TIER2: float = 0.3            # >72h

var _now_unix: int = 0
var _last_shichen: int = -1


func _ready() -> void:
	# 启动时同步系统时间
	_now_unix = int(Time.get_unix_time_from_system())
	_last_shichen = shichen_of_unix(_now_unix)


## 当前游戏时间戳（unix 秒）
func now_unix() -> int:
	return _now_unix


## 测试/调试用：直接设置当前时间（不发信号）
func set_now_unix(unix: int) -> void:
	_now_unix = unix
	_last_shichen = shichen_of_unix(unix)


## 推进时间，发 time_advanced 信号；跨时辰额外发 hour_passed
func advance_seconds(delta: int) -> void:
	if delta <= 0: return
	var new_unix := _now_unix + delta
	_now_unix = new_unix
	EventBus.time_advanced.emit(new_unix, delta)
	var cur_shichen := shichen_of_unix(new_unix)
	if cur_shichen != _last_shichen:
		_last_shichen = cur_shichen
		EventBus.hour_passed.emit(cur_shichen)


## 给定 unix 时间戳，返回该时辰索引 0..11
static func shichen_of_unix(unix: int) -> int:
	# 一天 12 时辰，每时辰 2h；以 UTC 为准（不处理时区，单机够用）
	var seconds_in_day := unix % 86400
	if seconds_in_day < 0:
		seconds_in_day += 86400
	return int(seconds_in_day / SECONDS_PER_SHICHEN)


## 计算单次离线时长的"有效"秒数（spec §7.1 老铁打盹规则）
## ≤24h 全额；24-72h 区段 70%；>72h 区段 30%
static func effective_offline_seconds(raw_seconds: int) -> int:
	if raw_seconds <= 0: return 0
	if raw_seconds <= FULL_THRESHOLD_SEC:
		return raw_seconds

	var eff := FULL_THRESHOLD_SEC
	var remaining := raw_seconds - FULL_THRESHOLD_SEC

	# 24-72h 区段（最多 48h）按 70%
	var tier1_window := DECAY_THRESHOLD_SEC - FULL_THRESHOLD_SEC  # 48h
	var tier1_used := min(remaining, tier1_window)
	eff += int(round(tier1_used * DECAY_RATE_TIER1))
	remaining -= tier1_used

	# 72h+ 按 30%
	if remaining > 0:
		eff += int(round(remaining * DECAY_RATE_TIER2))
	return eff
```

- [ ] **Step 5: 注册到 project.godot**

Find in `godot/project.godot`:
```
[autoload]

EventBus="*res://scripts/core/event_bus.gd"
GameState="*res://scripts/core/game_state.gd"
SaveSystem="*res://scripts/core/save_system.gd"
DataRegistry="*res://scripts/core/data_registry.gd"
```

Replace with:
```
[autoload]

EventBus="*res://scripts/core/event_bus.gd"
GameState="*res://scripts/core/game_state.gd"
SaveSystem="*res://scripts/core/save_system.gd"
DataRegistry="*res://scripts/core/data_registry.gd"
TimeLine="*res://scripts/core/time_line.gd"
```

- [ ] **Step 6: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_time_line.tscn
```

预期：`PASS: 13  FAIL: 0`

- [ ] **Step 7: 提交**

```bash
git add godot/scripts/core/time_line.gd godot/project.godot \
        godot/scripts/test/test_time_line.gd godot/scenes/test/test_time_line.tscn
git commit -m "feat(N1): TimeLine Autoload（时辰判定 + advance + 离线衰减）

- 时辰=2h，索引 0..11
- advance_seconds() 发 time_advanced；跨时辰发 hour_passed
- effective_offline_seconds() 实现 spec §7.1 老铁打盹衰减曲线
- 测试: test_time_line 13 PASS"
```

---

## Phase D — N1 ShopState Autoload

### Task 12: ShopState 实现

**Files:**
- Create: `godot/scripts/core/shop_state.gd`
- Create: `godot/scripts/test/test_shop_state.gd`
- Create: `godot/scenes/test/test_shop_state.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_shop_state.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_shop_state.gd" id="1"]

[node name="TestShopState" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_shop_state.gd`:

```gdscript
extends Node
## ShopState：4 区域等级、铺规槽、序列化。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_default_levels()
	_test_upgrade_emits_signal()
	_test_max_level_clamp()
	_test_rule_slots_capacity()
	_test_serialize_roundtrip()
	print("\n========== test_shop_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_default_levels() -> void:
	ShopState.reset()
	_assert(ShopState.area_level(&"furnace") == 1, "furnace defaults to Lv.1")
	_assert(ShopState.area_level(&"counter") == 1, "counter defaults to Lv.1")
	_assert(ShopState.area_level(&"loft") == 1, "loft defaults to Lv.1")
	_assert(ShopState.area_level(&"yard") == 1, "yard defaults to Lv.1")


func _test_upgrade_emits_signal() -> void:
	ShopState.reset()
	var emitted: Array = []
	var cb := func(area: StringName, lvl: int) -> void:
		emitted.append({"area": area, "lvl": lvl})
	EventBus.shop_upgraded.connect(cb)
	var ok := ShopState.upgrade_area(&"furnace")
	_assert(ok, "upgrade_area returns true")
	_assert(ShopState.area_level(&"furnace") == 2, "furnace now Lv.2")
	_assert(emitted.size() == 1, "shop_upgraded emitted")
	_assert(emitted[0]["area"] == &"furnace" and emitted[0]["lvl"] == 2, "signal payload correct")
	EventBus.shop_upgraded.disconnect(cb)


func _test_max_level_clamp() -> void:
	ShopState.reset()
	# 升 3 次到 Lv.3 应该都成功；第 4 次应失败（封顶 Lv.3）
	# 当前实现：reset 后是 Lv.1，所以升 2 次到 Lv.3
	_assert(ShopState.upgrade_area(&"furnace"), "Lv1->Lv2 ok")
	_assert(ShopState.upgrade_area(&"furnace"), "Lv2->Lv3 ok")
	_assert(not ShopState.upgrade_area(&"furnace"), "Lv3->Lv4 rejected")
	_assert(ShopState.area_level(&"furnace") == 3, "stays at Lv.3")


func _test_rule_slots_capacity() -> void:
	ShopState.reset()
	# 默认 3 槽（柜台 Lv.1），升级柜台到 Lv.2 应给到 ?+ slots
	_assert(ShopState.rule_slot_count() == 3, "default 3 rule slots")
	ShopState.upgrade_area(&"counter")
	_assert(ShopState.rule_slot_count() == 5, "counter Lv.2 => 5 slots")
	ShopState.upgrade_area(&"counter")
	_assert(ShopState.rule_slot_count() == 8, "counter Lv.3 => 8 slots")


func _test_serialize_roundtrip() -> void:
	ShopState.reset()
	ShopState.upgrade_area(&"furnace")
	ShopState.upgrade_area(&"loft")
	var d: Dictionary = ShopState.to_dict()
	ShopState.reset()
	ShopState.from_dict(d)
	_assert(ShopState.area_level(&"furnace") == 2, "furnace lvl 2 restored")
	_assert(ShopState.area_level(&"loft") == 2, "loft lvl 2 restored")
	_assert(ShopState.area_level(&"counter") == 1, "counter still 1")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_shop_state.tscn
```

预期：FAIL（ShopState 不存在）

- [ ] **Step 4: 创建 shop_state.gd**

Create `godot/scripts/core/shop_state.gd`:

```gdscript
extends Node
## 铺子状态 Autoload。
## 负责：4 区域等级、铺规槽容量、（未来）铺规内容。
## 不持有具体客人/装备实例（那在 GameState）。

const AREAS: Array[StringName] = [&"furnace", &"counter", &"loft", &"yard"]
const MAX_LEVEL: int = 3

## 柜台等级 -> 铺规槽数
const COUNTER_LV_TO_SLOTS: Array[int] = [3, 5, 8]   # Lv.1=3, Lv.2=5, Lv.3=8

## area_id -> int
var _area_levels: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	_area_levels.clear()
	for a in AREAS:
		_area_levels[a] = 1


func area_level(area: StringName) -> int:
	return int(_area_levels.get(area, 1))


## 升级一区。成功返回 true。已达 MAX_LEVEL 返回 false（**不发信号**）。
func upgrade_area(area: StringName) -> bool:
	if not _area_levels.has(area):
		push_warning("unknown area: %s" % area)
		return false
	var cur: int = _area_levels[area]
	if cur >= MAX_LEVEL:
		return false
	_area_levels[area] = cur + 1
	EventBus.shop_upgraded.emit(area, cur + 1)
	return true


## 当前可用铺规槽数（由柜台等级决定）
func rule_slot_count() -> int:
	var counter_lv: int = area_level(&"counter")
	return COUNTER_LV_TO_SLOTS[counter_lv - 1]


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var lvls: Dictionary = {}
	for a in AREAS:
		lvls[String(a)] = _area_levels[a]
	return {"area_levels": lvls}


func from_dict(d: Dictionary) -> void:
	reset()
	var lvls: Dictionary = d.get("area_levels", {})
	for k in lvls:
		var area := StringName(k)
		if _area_levels.has(area):
			_area_levels[area] = clampi(int(lvls[k]), 1, MAX_LEVEL)
```

- [ ] **Step 5: 注册到 project.godot**

Find in `godot/project.godot`:
```
TimeLine="*res://scripts/core/time_line.gd"
```

Add a new line below it:
```
ShopState="*res://scripts/core/shop_state.gd"
```

Final autoload section should be:
```
[autoload]

EventBus="*res://scripts/core/event_bus.gd"
GameState="*res://scripts/core/game_state.gd"
SaveSystem="*res://scripts/core/save_system.gd"
DataRegistry="*res://scripts/core/data_registry.gd"
TimeLine="*res://scripts/core/time_line.gd"
ShopState="*res://scripts/core/shop_state.gd"
```

- [ ] **Step 6: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_shop_state.tscn
```

预期：`PASS: 18  FAIL: 0`

- [ ] **Step 7: 提交**

```bash
git add godot/scripts/core/shop_state.gd godot/project.godot \
        godot/scripts/test/test_shop_state.gd godot/scenes/test/test_shop_state.tscn
git commit -m "feat(N1): ShopState Autoload（4 区域等级 + 铺规槽容量）

- 4 区域 furnace/counter/loft/yard，每区 Lv.1-3
- 升级 emit shop_upgraded
- counter 等级 Lv.1/2/3 => 3/5/8 铺规槽
- 序列化 to_dict / from_dict
- 测试: test_shop_state 18 PASS"
```

---

### Task 13: ShopState 接入 SaveSystem

**Files:**
- Modify: `godot/scripts/core/save_system.gd`
- Create: `godot/scripts/test/test_save_with_shopstate.gd`
- Create: `godot/scenes/test/test_save_with_shopstate.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/test_save_with_shopstate.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_save_with_shopstate.gd" id="1"]

[node name="TestSaveWithShopState" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写测试**

Create `godot/scripts/test/test_save_with_shopstate.gd`:

```gdscript
extends Node
## 验证 ShopState 通过 SaveSystem 写盘并读回。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_save_load_with_shop_state()
	print("\n========== test_save_with_shopstate ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_save_load_with_shop_state() -> void:
	# 删除旧档
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))

	# 配置 ShopState
	ShopState.reset()
	ShopState.upgrade_area(&"furnace")    # Lv.2
	ShopState.upgrade_area(&"furnace")    # Lv.3
	ShopState.upgrade_area(&"loft")       # Lv.2
	GameState.spirit_stones = 555
	GameState.reputation = 88

	# 强制写盘
	SaveSystem.save_now(true)

	# 重置内存
	ShopState.reset()
	GameState.spirit_stones = 0
	GameState.reputation = 0

	# 读回
	SaveSystem.load_or_init()

	_assert(ShopState.area_level(&"furnace") == 3, "furnace Lv.3 restored")
	_assert(ShopState.area_level(&"loft") == 2, "loft Lv.2 restored")
	_assert(ShopState.area_level(&"counter") == 1, "counter Lv.1 default")
	_assert(GameState.spirit_stones == 555, "spirit_stones restored")
	_assert(GameState.reputation == 88, "reputation restored")
```

- [ ] **Step 3: 跑测试，确认失败**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_with_shopstate.tscn
```

预期：FAIL（ShopState 没接入 SaveSystem）

- [ ] **Step 4: 修改 save_system.gd 把 ShopState 加入 payload**

In `godot/scripts/core/save_system.gd`, find `save_now`:

```gdscript
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
	}
```

Replace with:
```gdscript
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
		"shop_state": ShopState.to_dict(),
	}
```

In the same file, find `load_or_init`, locate this part:
```gdscript
	parsed = migrate(parsed)
	var gs: Dictionary = parsed.get("game_state", {})
	GameState.from_dict(gs)
	EventBus.save_loaded.emit()
```

Replace with:
```gdscript
	parsed = migrate(parsed)
	var gs: Dictionary = parsed.get("game_state", {})
	GameState.from_dict(gs)
	var ss: Dictionary = parsed.get("shop_state", {})
	ShopState.from_dict(ss)
	EventBus.save_loaded.emit()
```

- [ ] **Step 5: 跑测试，确认通过**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_with_shopstate.tscn
```

预期：`PASS: 5  FAIL: 0`

- [ ] **Step 6: 重跑迁移测试，确保没回退**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_save_migration.tscn
```

预期：`PASS: 16  FAIL: 0`

- [ ] **Step 7: 提交**

```bash
git add godot/scripts/core/save_system.gd \
        godot/scripts/test/test_save_with_shopstate.gd godot/scenes/test/test_save_with_shopstate.tscn
git commit -m "feat(N1): ShopState 接入 SaveSystem

- save_now 把 shop_state 写入 payload
- load_or_init 读回 shop_state
- v1 老存档迁移自然 fallback 到 ShopState 默认（reset 后是全 Lv.1）
- 测试: test_save_with_shopstate 5 PASS"
```

---

## Phase E — N1 主场景 + 老铁化身

### Task 14: 老铁化身节点 + 场景

**Files:**
- Create: `godot/scripts/actors/old_iron.gd`
- Create: `godot/scenes/actors/old_iron.tscn`

> 老铁是一个 placeholder 剪影：白色椭圆头 + 灰色身体矩形。N1 不做动画，N9 后期换骨骼/帧动画。

- [ ] **Step 1: 创建脚本**

```bash
mkdir -p godot/scripts/actors godot/scenes/actors
```

Create `godot/scripts/actors/old_iron.gd`:

```gdscript
extends Node2D
class_name OldIron
## 老铁化身（白发老者剪影 placeholder）。
## N1 仅显示 + 简单移动；后续 milestone 接入动画与状态。

@export var move_speed: float = 80.0  # 像素/秒

var _target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_pos = global_position


func _process(delta: float) -> void:
	if global_position.distance_to(_target_pos) < 1.0:
		return
	var dir := (_target_pos - global_position).normalized()
	global_position += dir * move_speed * delta


## 设置目标位置（铺子内部坐标）；老铁会自动走过去
func walk_to(world_pos: Vector2) -> void:
	_target_pos = world_pos
```

- [ ] **Step 2: 创建场景（手写 .tscn）**

Create `godot/scenes/actors/old_iron.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/actors/old_iron.gd" id="1"]

[node name="OldIron" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="ColorRect" parent="."]
offset_left = -10.0
offset_top = -20.0
offset_right = 10.0
offset_bottom = 20.0
color = Color(0.25, 0.2, 0.18, 1)

[node name="Head" type="ColorRect" parent="."]
offset_left = -7.0
offset_top = -32.0
offset_right = 7.0
offset_bottom = -22.0
color = Color(0.95, 0.92, 0.88, 1)

[node name="HairTuft" type="ColorRect" parent="."]
offset_left = -8.0
offset_top = -36.0
offset_right = 8.0
offset_bottom = -32.0
color = Color(0.95, 0.95, 0.95, 1)
```

- [ ] **Step 3: 提交**

```bash
git add godot/scripts/actors/old_iron.gd godot/scenes/actors/old_iron.tscn
git commit -m "feat(N1): 老铁化身（白发老者剪影 placeholder）

- Node2D + 3 个 ColorRect 拼出剪影
- walk_to() 简单匀速移动到目标
- 后续 milestone 接动画"
```

---

### Task 15: 主场景 shop.tscn（4 区域 placeholder）

**Files:**
- Create: `godot/scripts/ui/shop_screen.gd`
- Create: `godot/scenes/shop.tscn`

- [ ] **Step 1: 创建主控脚本**

Create `godot/scripts/ui/shop_screen.gd`:

```gdscript
extends Node2D
## 铺子主场景控制器。
## 4 区域 placeholder：炉房 / 柜台 / 阁楼 / 后院。
## N1 仅显示 + 老铁站位 + 时辰 HUD；交互留给后续 milestone。

## 4 区域中心坐标（相对于场景原点；2.5D 俯视布局）
const AREA_POSITIONS: Dictionary = {
	&"furnace": Vector2(280, 380),  # 炉房：左下
	&"counter": Vector2(640, 380),  # 柜台：中下
	&"loft":    Vector2(640, 200),  # 阁楼：中上
	&"yard":    Vector2(960, 380),  # 后院：右下
}

@onready var _old_iron: Node2D = $OldIron
@onready var _hud_time: Label = $HUD/TimeLabel
@onready var _hud_money: Label = $HUD/MoneyLabel


func _ready() -> void:
	# 老铁初始站在炉房
	_old_iron.global_position = AREA_POSITIONS[&"furnace"]
	# 启动后立即载档
	SaveSystem.load_or_init()
	# 接信号刷 HUD
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.currency_changed.connect(_on_currency_changed)
	_refresh_hud()


func _process(delta: float) -> void:
	# N1 简单：每个真实秒推进游戏时间 1 秒（1:1）
	# N5 改为可调倍速 + 离线时长积分
	TimeLine.advance_seconds(int(delta * 1.0))
	# 防止 0 -> 不发信号；只在每整秒 emit 一次靠 advance_seconds 内部判断
	# (此处 delta 通常 ~0.016，int 化后是 0，所以 advance 实际不会发——这是预期；下版会改)


func _on_time_advanced(_new_unix: int, _delta: int) -> void:
	_refresh_hud()


func _on_currency_changed(_kind: StringName, _value: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	var shichen := TimeLine.shichen_of_unix(TimeLine.now_unix())
	const SHICHEN_NAMES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
	_hud_time.text = "时辰：%s" % SHICHEN_NAMES[shichen]
	_hud_money.text = "灵石：%d" % GameState.spirit_stones
```

- [ ] **Step 2: 创建主场景（手写 .tscn）**

Create `godot/scenes/shop.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/shop_screen.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/actors/old_iron.tscn" id="2"]

[node name="Shop" type="Node2D"]
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
offset_left = 0.0
offset_top = 0.0
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.06, 0.05, 0.04, 1)

[node name="AreaFurnace" type="ColorRect" parent="."]
offset_left = 80.0
offset_top = 240.0
offset_right = 480.0
offset_bottom = 520.0
color = Color(0.18, 0.10, 0.08, 1)

[node name="LabelFurnace" type="Label" parent="AreaFurnace"]
offset_left = 10.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 40.0
text = "炉房"
theme_override_colors/font_color = Color(0.78, 0.65, 0.5, 1)

[node name="AreaCounter" type="ColorRect" parent="."]
offset_left = 480.0
offset_top = 240.0
offset_right = 800.0
offset_bottom = 520.0
color = Color(0.20, 0.16, 0.10, 1)

[node name="LabelCounter" type="Label" parent="AreaCounter"]
offset_left = 10.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 40.0
text = "柜台"
theme_override_colors/font_color = Color(0.78, 0.65, 0.5, 1)

[node name="AreaLoft" type="ColorRect" parent="."]
offset_left = 480.0
offset_top = 80.0
offset_right = 800.0
offset_bottom = 240.0
color = Color(0.10, 0.08, 0.06, 1)

[node name="LabelLoft" type="Label" parent="AreaLoft"]
offset_left = 10.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 40.0
text = "阁楼"
theme_override_colors/font_color = Color(0.65, 0.55, 0.42, 1)

[node name="AreaYard" type="ColorRect" parent="."]
offset_left = 800.0
offset_top = 240.0
offset_right = 1200.0
offset_bottom = 520.0
color = Color(0.05, 0.05, 0.03, 1)

[node name="LabelYard" type="Label" parent="AreaYard"]
offset_left = 10.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 40.0
text = "后院"
theme_override_colors/font_color = Color(0.55, 0.50, 0.40, 1)

[node name="OldIron" parent="." instance=ExtResource("2")]
position = Vector2(280, 380)

[node name="HUD" type="CanvasLayer" parent="."]

[node name="TimeLabel" type="Label" parent="HUD"]
offset_left = 20.0
offset_top = 20.0
offset_right = 300.0
offset_bottom = 50.0
text = "时辰：子"
theme_override_colors/font_color = Color(0.85, 0.78, 0.65, 1)

[node name="MoneyLabel" type="Label" parent="HUD"]
offset_left = 20.0
offset_top = 50.0
offset_right = 300.0
offset_bottom = 80.0
text = "灵石：0"
theme_override_colors/font_color = Color(0.85, 0.78, 0.65, 1)
```

- [ ] **Step 3: 把主场景指向 shop.tscn**

In `godot/project.godot`, find:
```
run/main_scene="res://scenes/_deprecated/city.tscn"
```

Replace with:
```
run/main_scene="res://scenes/shop.tscn"
```

- [ ] **Step 4: F5 / 命令行启动验证**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot --quit-after 3
```

预期：进程正常退出，无 ERROR 输出。

> 因为是 headless，看不到画面。下一个 task 写自动化烟测；要看画面用 `--no-headless` 或在 IDE 里 F5。

- [ ] **Step 5: 提交**

```bash
git add godot/scripts/ui/shop_screen.gd godot/scenes/shop.tscn godot/project.godot
git commit -m "feat(N1): 铺子主场景 shop.tscn（4 区域 placeholder + 老铁站位 + HUD）

- 4 区域 ColorRect: 炉房/柜台/阁楼/后院
- 老铁初始在炉房
- HUD 显示当前时辰 + 灵石数
- 主场景切换到 shop.tscn"
```

---

### Task 16: N1 烟测脚本（autoload + 主场景能加载）

**Files:**
- Create: `godot/scripts/test/playtest_n1_smoke.gd`
- Create: `godot/scenes/test/playtest_n1_smoke.tscn`

- [ ] **Step 1: 写测试场景外壳**

Create `godot/scenes/test/playtest_n1_smoke.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/playtest_n1_smoke.gd" id="1"]

[node name="PlaytestN1Smoke" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: 写烟测脚本**

Create `godot/scripts/test/playtest_n1_smoke.gd`:

```gdscript
extends Node
## N1 烟测：所有 autoload 启动成功 + shop.tscn 可被 ResourceLoader 加载 + 实例化不崩。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_autoloads()
	_test_data_registry_indexes()
	_test_shop_scene_loads()
	_test_old_iron_scene_loads()
	print("\n========== playtest_n1_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_autoloads() -> void:
	_assert(EventBus != null, "EventBus autoload alive")
	_assert(GameState != null, "GameState autoload alive")
	_assert(SaveSystem != null, "SaveSystem autoload alive")
	_assert(DataRegistry != null, "DataRegistry autoload alive")
	_assert(TimeLine != null, "TimeLine autoload alive")
	_assert(ShopState != null, "ShopState autoload alive")


func _test_data_registry_indexes() -> void:
	# 索引应包含新数据类目（即使空）
	for cat in [&"recipe", &"customer", &"gupu", &"su", &"narrative", &"gear", &"affix"]:
		var ids: Array = DataRegistry.ids_of(cat)
		_assert(ids != null, "DataRegistry has category '%s' (got %d ids)" % [cat, ids.size()])
	# 已删类目应不存在
	for cat in [&"card", &"sequence", &"anomaly", &"encounter"]:
		var ids: Array = DataRegistry.ids_of(cat)
		_assert(ids.is_empty(), "DataRegistry has no '%s'" % cat)


func _test_shop_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "shop.tscn instantiable")
	# 不 add_child（避免 _ready 触发完整流程）；instantiate 不崩就行
	inst.queue_free()


func _test_old_iron_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/actors/old_iron.tscn")
	_assert(pkd != null, "old_iron.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "old_iron.tscn instantiable")
	inst.queue_free()
```

- [ ] **Step 3: 跑烟测**

```bash
"E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/playtest_n1_smoke.tscn
```

预期：`PASS: 21  FAIL: 0`

- [ ] **Step 4: 跑全部测试一遍确认整体不退化**

```bash
for t in test_game_state test_save_migration test_save_with_shopstate test_recipe_data test_customer_data test_gupu_data test_narrative_card test_time_line test_shop_state playtest_n1_smoke; do
  echo "=== $t ==="
  "E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn"
done
```

预期：每个测试都 `PASS: N  FAIL: 0`，没有崩溃。

- [ ] **Step 5: 提交**

```bash
git add godot/scripts/test/playtest_n1_smoke.gd godot/scenes/test/playtest_n1_smoke.tscn
git commit -m "test(N1): N1 烟测——验证 autoload + 数据索引 + 主场景加载

playtest_n1_smoke 21 PASS"
```

---

## Phase F — 收尾

### Task 17: 更新 DESIGN.md 与 README.md

**Files:**
- Modify: `DESIGN.md`
- Modify: `README.md`

- [ ] **Step 1: DESIGN.md 顶部加重定位指引**

In `DESIGN.md`, find the very first line:
```
# 仙兵传 设计文档（v0.1）
```

Replace with:
```
# 仙兵传 设计文档（v0.1）— **已重定位，请优先阅读新文档**

> ⚠ **2026-04-30 项目重定位**：本设计已被弃用。
> 当前生效设计：[`docs/superpowers/specs/2026-04-30-weird-cultivation-smith-design.md`](docs/superpowers/specs/2026-04-30-weird-cultivation-smith-design.md)
> 新项目名：《我在诡异修仙造兵器》
> 本文仅 §8（设计模式与资源约束）+ §10（命名约定）作为技术规范继续生效。
```

- [ ] **Step 2: README.md 全量重写**

Replace entire content of `README.md`:

```markdown
# 我在诡异修仙造兵器

一款 **诡异修仙世界 · 铁匠铺挂机** 的单机游戏。

> 你不记得自己是谁，但你的手记得怎么打铁。
> 每一炉都是一次开奖；每一位推门而入的访客都是一个盲盒；
> 每一件造出来的兵器都会带着自己的履历回到你的器谱里——
> 直到某一天，你从那本谱子上认出了自己。

## 玩法支柱

- **挂机时间线**：在线/离线产出一致，离线时系统按"铺规"自动跑铺子
- **造装备**：选配方、投料、捶打、出炉——凡 / 灵 / 法 / 禁 / 秘 五品质，附带巧成 + 反噬
- **28 宿器谱**：装备落入预设星位，凑齐古谱 → 共鸣，玩家自连支脉 → 隐藏图案
- **问道门客**：神秘访客求借兵器，常 / 罕 / 怪三档，怪客身份是盲盒
- **诡异叙事**：每段离线由系统拼出"老铁的小本"——你不在的时候，铺子也活着

## 技术栈

- **引擎**：Godot 4.6（GDScript）
- **架构**：Resource 数据驱动 + Autoload 服务 + 信号事件总线 + MVVM
- **运行时**：纯单机，零网络依赖（选配 Steam Cloud 同步）

## 目录

```
godot/        Godot 项目（主体）
docs/         设计文档与实现计划
  superpowers/specs/2026-04-30-weird-cultivation-smith-design.md  ← 当前生效设计
  superpowers/plans/                                              ← 逐里程碑实现计划
DESIGN.md     旧设计文档（已重定位，仅技术规范章节生效）
```

## 开始

1. 安装 [Godot 4.6](https://godotengine.org/) 稳定版
2. 启动 Godot，导入 `godot/project.godot`
3. F5 运行（当前为 N1 骨架阶段，仅显示空铺子 + 老铁剪影 + HUD）

## 当前进度

- ✅ N0：旧战斗/塔/赛季/卡牌系统归档
- ✅ N1：铺子主场景 + 时间线 Autoload + 数据 Resource 类骨架
- ⏳ N2：锻造 v2（火候窗口 + 巧成 + 反噬）
- ⏳ N3-N10：见 spec §13.2

## 测试

跑全部测试：
```bash
for t in test_game_state test_save_migration test_save_with_shopstate \
         test_recipe_data test_customer_data test_gupu_data test_narrative_card \
         test_time_line test_shop_state playtest_n1_smoke; do
  "E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn"
done
```
```

- [ ] **Step 3: 提交**

```bash
git add DESIGN.md README.md
git commit -m "docs(N1): 更新 DESIGN.md 重定位指引 + README 改写为新项目"
```

---

### Task 18: N0+N1 最终验证 + tag

**Files:** 无新增

- [ ] **Step 1: 跑全套测试一次**

```bash
for t in test_game_state test_save_migration test_save_with_shopstate test_recipe_data test_customer_data test_gupu_data test_narrative_card test_time_line test_shop_state playtest_n1_smoke; do
  echo "=== $t ==="
  "E:/soft/godot/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn"
done
```

预期：每个测试 `FAIL: 0`，10 个测试全部通过。

- [ ] **Step 2: 检查 git status 干净**

```bash
git -C E:/Codes/github/XiuXianLegend status
```

预期：`nothing to commit, working tree clean`

- [ ] **Step 3: 检查没有 deprecated 引用泄漏到非 _deprecated 目录**

```bash
grep -rn "EventBus\." godot/scripts --include="*.gd" | grep -v "_deprecated" | \
    grep -E "combat_started|combat_ended|card_played|unit_damaged|unit_died|sequence_advanced|ritual_failed|anomaly_triggered|anomaly_resolved|season_rolled|pollution_changed|sanity_changed|gear_reforged|idle_settled"
```

预期：无输出

```bash
grep -rn "GameState\." godot/scripts --include="*.gd" | grep -v "_deprecated" | \
    grep -E "pollution|sanity|owned_cards|tower_|sequence_ranks|season_|ensure_starter_deck|tower_unlock_next|add_pollution|set_sanity|add_card"
```

预期：无输出

- [ ] **Step 4: 打 tag**

```bash
git -C E:/Codes/github/XiuXianLegend tag -a n1-shop-scaffold -m "N1 完成：铺子主场景 + 时间线 + 数据类骨架"
```

- [ ] **Step 5: 在 IDE 里 F5 手动验证（推荐）**

打开 Godot 编辑器 → 导入 `godot/project.godot` → F5 → 应看到：
- 黑色背景上有 4 个深色矩形（炉房/柜台/阁楼/后院）
- 每个矩形左上角有中文标题
- 一个白发剪影站在炉房中央
- 左上角 HUD 显示"时辰：xxx" + "灵石：0"

如果以上都看到，N1 视觉验证通过。

---

## Self-Review

### Spec 覆盖检查

| Spec 章节 | 本计划任务覆盖 |
|---|---|
| §1 定位 | Task 17（README + DESIGN.md 同步项目名） |
| §2 核心循环 | 此 plan 仅搭骨架；循环实现在 N2-N5 |
| §3 铁匠铺结构（4 区域、3 阶升级） | Task 12（ShopState 4 区域 + Lv.1-3）+ Task 15（4 区域 placeholder 视觉） |
| §4 锻造 | 不在此 plan，留给 N2 |
| §5 器谱 | Task 9（SuData + GuPuData 数据类）；UI 留给 N3 |
| §6 问道门客 | Task 8（CustomerData 类）；流程留给 N4 |
| §7 铺规与时间线 | Task 11（TimeLine + 老铁打盹衰减）；铺规槽容量在 Task 12 |
| §8 世面 | Task 8（CustomerData.faction 字段）；动态状态留给 N6 |
| §9 诡异叙事 | Task 10（NarrativeCard 类）；触发流程留给 N5 |
| §10 数值 | TimeLine 衰减常量已实装；其余在后续 milestone |
| §11 长期目标 | 不在此 plan |
| §12 资源约束 / 技术 | Task 5（DataRegistry 索引）+ Task 11/12（轻量 autoload）+ 测试覆盖 |
| §12.4 Steam Cloud | 不在此 plan，留 N6+ |
| §13.1 路线图对照 | Task 1-4（旧系统归档） |
| §13.2 N0/N1 完成 | 全 plan 覆盖 |

### 留给后续 plan 的清单

- N2 锻造：使用 RecipeData，实现火候窗口 + 巧成 + 反噬 + 出炉动画
- N3 器谱 v1：使用 SuData + GuPuData，实现 28 宿星图 UI + 入谱公式 + 自连
- N4 问道门客：使用 CustomerData，客人生成器 + 借/拒/打听
- N5 铺规与时间线：用 ShopState 铺规槽 + 离线模拟器 + 日报 UI
- N6 世面：动态状态 + Steam Cloud + 6 势力影响
- N7-N10：见 spec §13.2

### 类型一致性

- `GameState.reputation` (Task 2) ↔ `EventBus.reputation_changed` (Task 3) ↔ `add_reputation()` (Task 2) ✓
- `ShopState.area_level(area: StringName)` (Task 12) ↔ `EventBus.shop_upgraded(area, lvl)` (Task 3) ✓
- `TimeLine.advance_seconds(delta)` (Task 11) ↔ `EventBus.time_advanced(unix, delta)` (Task 3) ✓
- `RecipeData.path_affinity` (Task 7) ↔ `SuData.match_path` (Task 9) ↔ `CustomerData.path_affinity` (Task 8) — 都用 `StringName`，词汇统一为 `&"sword"` 等 ✓
- 测试场景命名约定：`test_*.tscn` + `test_*.gd` 一一对应 ✓
- 所有 Resource 类用 `class_name` + `extends Resource` ✓
- 所有 autoload 在 project.godot 用 `*res://...` 启用 ✓

### 已知妥协

- Task 15 的 `_process` 里 `int(delta * 1.0)` 在 60fps 下永远是 0，主场景的"时间推进"在 N1 实际不工作——这是有意的占位，N5 重写为带倍速控制的真实推进。已在脚本注释里说明。
- 4 区域升级的灵石/材料成本未实装（Task 12 只暴露 `upgrade_area` API，不收钱）。N2 起接入。
- 烟测覆盖加载/索引/autoload 启动；不覆盖运行时 UI 渲染（headless 跑不了）。手动 F5 是必须的，已在 Task 18 step 5 列出。

---

## 执行交接

**Plan complete and saved to `docs/superpowers/plans/2026-04-30-n0-n1-shop-scaffold.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — 每个任务派一个 fresh subagent 执行，我在任务之间 review，迭代快、不污染上下文

**2. Inline Execution** — 在当前会话里逐任务跑，到 checkpoint 一起 review，更直接但会消耗更多上下文

**Which approach?**
