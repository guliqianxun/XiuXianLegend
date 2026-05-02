# 炉房 UI 重构 · 控制台日志风 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `forge_screen.tscn` 从默认 Godot 表单重构为 3 段控制台日志风（TopBar / LogFlow / BottomBar），日志数据复用 EventLog（kind=`forge_*`）。

**Architecture:** ForgeScreen 拆为 3 个独立子组件 Control（forge_top_bar / forge_log_flow / forge_bottom_bar），ForgeScreen 仅做协调。LogFlow 监听 EventLog.log_added 信号，过滤 kind 前缀 `forge_` 的条目并按 color_key 染色 append。TimingWindow 不重写内部，只改实例化位置（LogFlow 顶部嵌入）。ForgeResultOverlay 完全不动。

**Tech Stack:** Godot 4.6 GDScript，已有的 main_theme.tres 接管所有 styling，已有的 EventLog autoload 作为日志数据源。

---

## File Structure

新增：
- `godot/scripts/ui/forge_log_flow.gd` + `.uid` — 自滚动日志 VBox
- `godot/scenes/ui/forge_log_flow.tscn`
- `godot/scripts/ui/forge_top_bar.gd` + `.uid` — 配方下拉 + 材料缩略 + 闭门
- `godot/scenes/ui/forge_top_bar.tscn`
- `godot/scripts/ui/forge_bottom_bar.gd` + `.uid` — 添料 chips + 开炉
- `godot/scenes/ui/forge_bottom_bar.tscn`
- `godot/scripts/test/test_forge_console_smoke.gd` + `.uid`
- `godot/scenes/test/test_forge_console_smoke.tscn`

修改：
- `godot/scenes/ui/forge_screen.tscn` — Layout 重排为 3 段嵌入
- `godot/scripts/ui/forge_screen.gd` — 协调子组件 + 调 EventLog
- `godot/scripts/ui/shop_screen.gd` — `_on_forge_finished` 文本格式微调（forge_invest/done/backlash 一致）

---

### Task 1: ForgeLogFlow 组件 — 自滚动日志 VBox（监听 EventLog 过滤 forge_*）

**Files:**
- Create: `godot/scripts/ui/forge_log_flow.gd`
- Create: `godot/scripts/ui/forge_log_flow.gd.uid`
- Create: `godot/scenes/ui/forge_log_flow.tscn`

- [ ] **Step 1: Write the .uid file**

```
uid://bp2forgelogflow
```

写到 `godot/scripts/ui/forge_log_flow.gd.uid`

- [ ] **Step 2: Write the gd script**

```gdscript
extends Control
class_name ForgeLogFlow
## 炉房日志流：从 EventLog 过滤 kind 前缀 forge_ 的条目，染色 append。
## ScrollContainer + VBox，自动滚到底；用户主动滚则暂停 auto-scroll。

const KIND_PREFIX: String = "forge_"
const SHICHEN_NAMES: Array[String] = [
	"子", "丑", "寅", "卯", "辰", "巳",
	"午", "未", "申", "酉", "戌", "亥",
]

@onready var _scroll: ScrollContainer = $Frame/Scroll
@onready var _list: VBoxContainer = $Frame/Scroll/List

var _user_scrolled_up: bool = false


func _ready() -> void:
	EventLog.log_added.connect(_on_log_added)
	# 监听用户滚动，决定是否暂停 auto-scroll
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	rebuild_from_event_log()


## 重建：扫 EventLog 全部 entries，过滤 forge_，append
func rebuild_from_event_log() -> void:
	if _list == null: return
	for child in _list.get_children():
		child.queue_free()
	for entry in EventLog.entries:
		if _is_forge_entry(entry):
			_append_label(entry)
	_scroll_to_bottom_deferred()


func _on_log_added(entry: Dictionary) -> void:
	if not _is_forge_entry(entry): return
	_append_label(entry)
	if not _user_scrolled_up:
		_scroll_to_bottom_deferred()


static func _is_forge_entry(entry: Dictionary) -> bool:
	return String(entry.get("kind", "")).begins_with(KIND_PREFIX)


func _append_label(entry: Dictionary) -> void:
	var lbl := Label.new()
	var sh: int = int(entry.get("shichen", 0))
	var sname: String = SHICHEN_NAMES[sh] if sh >= 0 and sh < 12 else "?"
	lbl.text = "[%s] %s" % [sname, String(entry.get("text", ""))]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EventLog.color_of(StringName(entry.get("color_key", "normal"))))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(lbl)


func _scroll_to_bottom_deferred() -> void:
	# 等 layout 算完再滚
	await get_tree().process_frame
	if _scroll != null:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_scroll_changed(value: float) -> void:
	if _scroll == null: return
	var sb := _scroll.get_v_scroll_bar()
	# 用户主动往上滚 = 不在底部
	_user_scrolled_up = value < sb.max_value - sb.page - 4.0
```

写到 `godot/scripts/ui/forge_log_flow.gd`

- [ ] **Step 3: Write the .tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/forge_log_flow.gd" id="1"]

[node name="ForgeLogFlow" type="Control"]
custom_minimum_size = Vector2(540, 240)
script = ExtResource("1")

[node name="Frame" type="PanelContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Scroll" type="ScrollContainer" parent="Frame"]
horizontal_scroll_mode = 0

[node name="List" type="VBoxContainer" parent="Frame/Scroll"]
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 2
```

写到 `godot/scenes/ui/forge_log_flow.tscn`

- [ ] **Step 4: Force class scan + verify scene loads**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --editor --path godot --quit-after 3 2>&1 | tail -3`
Expected: scan completes (warning OK)

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/ui/forge_log_flow.tscn 2>&1 | tail -10`
Expected: 加载不报 Parse Error

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ui/forge_log_flow.gd godot/scripts/ui/forge_log_flow.gd.uid godot/scenes/ui/forge_log_flow.tscn
git commit -m "feat(forge): ForgeLogFlow 组件 — 监听 EventLog 过滤 forge_* 染色 append + 自滚"
```

---

### Task 2: ForgeTopBar 组件 — 配方下拉 + 材料缩略 + 闭门按钮

**Files:**
- Create: `godot/scripts/ui/forge_top_bar.gd`
- Create: `godot/scripts/ui/forge_top_bar.gd.uid`
- Create: `godot/scenes/ui/forge_top_bar.tscn`

- [ ] **Step 1: Write the .uid file**

```
uid://bp2forgetopbar
```

写到 `godot/scripts/ui/forge_top_bar.gd.uid`

- [ ] **Step 2: Write the gd script**

```gdscript
extends Control
class_name ForgeTopBar
## 炉房顶栏：配方下拉 + 材料缩略 + 闭门按钮。
## ForgeScreen 提供 recipes 列表，TopBar emit 信号回去。

signal recipe_picked(recipe_id: StringName)
signal close_pressed

const COLOR_OK := Color(0.910, 0.846, 0.659, 1.0)
const COLOR_ABUNDANT := Color(0.745, 0.920, 0.650, 1.0)
const COLOR_LACK := Color(0.752, 0.345, 0.282, 1.0)

@onready var _recipe_picker: OptionButton = $HBox/RecipePicker
@onready var _materials_box: HBoxContainer = $HBox/MaterialsBox
@onready var _close_btn: Button = $HBox/CloseButton

var _recipes: Array[RecipeData] = []


func _ready() -> void:
	_recipe_picker.item_selected.connect(_on_picker_selected)
	_close_btn.pressed.connect(func() -> void: close_pressed.emit())


## ForgeScreen 调用：刷新可选配方列表
func set_recipes(recipes: Array[RecipeData]) -> void:
	_recipes = recipes
	_recipe_picker.clear()
	for r in _recipes:
		_recipe_picker.add_item(r.display_name)
	if not _recipes.is_empty():
		_on_picker_selected(0)


## ForgeScreen 调用：根据当前 recipe 刷新材料缩略颜色
func refresh_materials(recipe: RecipeData) -> void:
	for child in _materials_box.get_children():
		child.queue_free()
	if recipe == null: return
	for mid in recipe.required_materials:
		var need: int = int(recipe.required_materials[mid])
		var have: int = GameState.material_count(mid)
		var lbl := Label.new()
		lbl.text = "%s:%d" % [_short_name(mid), have]
		lbl.add_theme_font_size_override("font_size", 12)
		var col: Color
		if have >= need * 2:
			col = COLOR_ABUNDANT
		elif have >= need:
			col = COLOR_OK
		else:
			col = COLOR_LACK
		lbl.add_theme_color_override("font_color", col)
		_materials_box.add_child(lbl)


func _on_picker_selected(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size(): return
	var r := _recipes[idx]
	recipe_picked.emit(r.id)
	refresh_materials(r)


## 材料 id → 短名（铁/金/朱/纸/灰/骨...）
static func _short_name(material_id: StringName) -> String:
	match material_id:
		&"iron": return "铁"
		&"jin": return "金"
		&"zhusha": return "朱"
		&"yellow_paper": return "纸"
		&"hui": return "灰"
		&"bone": return "骨"
		&"yi_zhong_liao": return "异"
		_: return String(material_id)
```

写到 `godot/scripts/ui/forge_top_bar.gd`

- [ ] **Step 3: Write the .tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/forge_top_bar.gd" id="1"]

[node name="ForgeTopBar" type="Control"]
custom_minimum_size = Vector2(540, 36)
script = ExtResource("1")

[node name="HBox" type="HBoxContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/separation = 12

[node name="RecipePicker" type="OptionButton" parent="HBox"]
custom_minimum_size = Vector2(140, 0)

[node name="MaterialsBox" type="HBoxContainer" parent="HBox"]
size_flags_horizontal = 3
theme_override_constants/separation = 8

[node name="CloseButton" type="Button" parent="HBox"]
text = "闭门 ✕"
custom_minimum_size = Vector2(80, 0)
theme_override_font_sizes/font_size = 12
```

写到 `godot/scenes/ui/forge_top_bar.tscn`

- [ ] **Step 4: Verify scene loads**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --editor --path godot --quit-after 3 2>&1 | tail -3`
Then: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/ui/forge_top_bar.tscn 2>&1 | tail -10`
Expected: 无 Parse Error

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ui/forge_top_bar.gd godot/scripts/ui/forge_top_bar.gd.uid godot/scenes/ui/forge_top_bar.tscn
git commit -m "feat(forge): ForgeTopBar 组件 — 配方下拉 + 材料缩略色染 + 闭门按钮"
```

---

### Task 3: ForgeBottomBar 组件 — 添料 chips + 开炉按钮

**Files:**
- Create: `godot/scripts/ui/forge_bottom_bar.gd`
- Create: `godot/scripts/ui/forge_bottom_bar.gd.uid`
- Create: `godot/scenes/ui/forge_bottom_bar.tscn`

- [ ] **Step 1: Write the .uid file**

```
uid://bp2forgebottombar
```

写到 `godot/scripts/ui/forge_bottom_bar.gd.uid`

- [ ] **Step 2: Write the gd script**

```gdscript
extends Control
class_name ForgeBottomBar
## 炉房底栏：动态生成添料 chips + 大开炉按钮。
## 玩家点 chip → 切换 selected 状态；点开炉 → emit 信号，附 selected 列表。

signal start_pressed(selected_optional: Array)

@onready var _chips_box: HBoxContainer = $HBox/ChipsBox
@onready var _start_btn: Button = $HBox/StartButton

# material_id (StringName) → bool（是否选中）
var _chip_state: Dictionary = {}
var _current_recipe: RecipeData = null


func _ready() -> void:
	_start_btn.pressed.connect(_on_start)


## ForgeScreen 调用：根据新 recipe 重建 chips
func rebuild_chips(recipe: RecipeData) -> void:
	_current_recipe = recipe
	_chip_state.clear()
	for child in _chips_box.get_children():
		child.queue_free()
	if recipe == null:
		_start_btn.disabled = true
		return
	for mid in recipe.optional_materials:
		var have: int = GameState.material_count(mid)
		var btn := Button.new()
		btn.text = "+ %s" % ForgeTopBar._short_name(mid)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = have <= 0
		btn.custom_minimum_size = Vector2(80, 0)
		var captured: StringName = mid
		btn.pressed.connect(func() -> void: _toggle_chip(captured, btn))
		_chips_box.add_child(btn)
	refresh_start_enabled()


## ForgeScreen 调用：根据材料是否够用刷新 start 按钮
func refresh_start_enabled() -> void:
	if _current_recipe == null:
		_start_btn.disabled = true
		return
	var ok: bool = true
	for mid in _current_recipe.required_materials:
		if GameState.material_count(mid) < int(_current_recipe.required_materials[mid]):
			ok = false
			break
	_start_btn.disabled = not ok


func selected_optional() -> Array:
	var out: Array = []
	for mid in _chip_state:
		if _chip_state[mid]:
			out.append(mid)
	return out


func _toggle_chip(mid: StringName, btn: Button) -> void:
	var on: bool = not bool(_chip_state.get(mid, false))
	_chip_state[mid] = on
	if on:
		btn.text = "✓ %s" % ForgeTopBar._short_name(mid)
		btn.add_theme_color_override("font_color", Color(0.940, 0.685, 0.345, 1.0))
	else:
		btn.text = "+ %s" % ForgeTopBar._short_name(mid)
		btn.remove_theme_color_override("font_color")


func _on_start() -> void:
	start_pressed.emit(selected_optional())
```

写到 `godot/scripts/ui/forge_bottom_bar.gd`

- [ ] **Step 3: Write the .tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/forge_bottom_bar.gd" id="1"]

[node name="ForgeBottomBar" type="Control"]
custom_minimum_size = Vector2(540, 50)
script = ExtResource("1")

[node name="HBox" type="HBoxContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/separation = 8

[node name="ChipsBox" type="HBoxContainer" parent="HBox"]
theme_override_constants/separation = 6

[node name="StartButton" type="Button" parent="HBox"]
text = "─── 开　炉 ───"
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 40)
theme_override_font_sizes/font_size = 18
disabled = true
```

写到 `godot/scenes/ui/forge_bottom_bar.tscn`

- [ ] **Step 4: Verify scene loads**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --editor --path godot --quit-after 3 2>&1 | tail -3`
Then: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/ui/forge_bottom_bar.tscn 2>&1 | tail -10`
Expected: 无 Parse Error

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ui/forge_bottom_bar.gd godot/scripts/ui/forge_bottom_bar.gd.uid godot/scenes/ui/forge_bottom_bar.tscn
git commit -m "feat(forge): ForgeBottomBar 组件 — 添料 chips toggle + 大开炉按钮"
```

---

### Task 4: 重构 ForgeScreen.tscn 为 3 段 + ForgeScreen.gd 协调

**Files:**
- Modify: `godot/scenes/ui/forge_screen.tscn`
- Modify: `godot/scripts/ui/forge_screen.gd`

- [ ] **Step 1: 重写 forge_screen.tscn（3 段嵌入子组件）**

完整覆盖 `godot/scenes/ui/forge_screen.tscn`：

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/ui/forge_screen.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/timing_window.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/forge_result_overlay.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/forge_top_bar.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/ui/forge_log_flow.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/ui/forge_bottom_bar.tscn" id="6"]

[node name="ForgeScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.7)

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -220.0
offset_right = 300.0
offset_bottom = 220.0
theme_override_constants/separation = 8

[node name="TopBar" parent="Layout" instance=ExtResource("4")]
custom_minimum_size = Vector2(580, 36)

[node name="LogFlow" parent="Layout" instance=ExtResource("5")]
custom_minimum_size = Vector2(580, 280)

[node name="BottomBar" parent="Layout" instance=ExtResource("6")]
custom_minimum_size = Vector2(580, 50)

[node name="TimingWindow" parent="." instance=ExtResource("2")]

[node name="ResultOverlay" parent="." instance=ExtResource("3")]
```

- [ ] **Step 2: 重写 forge_screen.gd**

完整覆盖 `godot/scripts/ui/forge_screen.gd`：

```gdscript
extends Control
class_name ForgeScreen
## 锻造弹窗（控制台日志风）。
## 协调 3 个子组件：TopBar / LogFlow / BottomBar；TimingWindow 嵌入 LogFlow 顶；
## ResultOverlay 浮屏。业务逻辑全在 ForgeSystem，本类只串信号。

@onready var _top_bar: ForgeTopBar = $Layout/TopBar
@onready var _log_flow: ForgeLogFlow = $Layout/LogFlow
@onready var _bottom_bar: ForgeBottomBar = $Layout/BottomBar
@onready var _timing_window: TimingWindow = $TimingWindow
@onready var _result_overlay: ForgeResultOverlay = $ResultOverlay

var _recipes: Array[RecipeData] = []
var _current_recipe: RecipeData = null
var _last_selected_optional: Array = []


func _ready() -> void:
	visible = false
	_top_bar.recipe_picked.connect(_on_recipe_picked)
	_top_bar.close_pressed.connect(_on_close)
	_bottom_bar.start_pressed.connect(_on_start)
	_timing_window.timing_finished.connect(_on_timing_finished)
	_result_overlay.animation_finished.connect(_on_overlay_done)


## 入口：从 ShopScreen 打开
func open() -> void:
	_load_recipes()
	if _recipes.is_empty():
		push_warning("forge: no recipes available")
		return
	_top_bar.set_recipes(_recipes)
	visible = true


func _load_recipes() -> void:
	_recipes.clear()
	for id in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", id) as RecipeData
		if r != null:
			_recipes.append(r)


func _on_recipe_picked(recipe_id: StringName) -> void:
	for r in _recipes:
		if r.id == recipe_id:
			_current_recipe = r
			break
	_bottom_bar.rebuild_chips(_current_recipe)


func _on_start(selected_optional: Array) -> void:
	if _current_recipe == null: return
	_last_selected_optional = selected_optional
	# 消耗必要材料 + 可选添料
	for mid in _current_recipe.required_materials:
		var need: int = int(_current_recipe.required_materials[mid])
		GameState.consume_material(mid, need)
	for mid in selected_optional:
		GameState.consume_material(mid, 1)
	# 投料 EventLog 行（forge_invest）
	var invest_text: String = _format_invest_text(_current_recipe, selected_optional)
	EventLog.add_entry(&"forge_invest", invest_text, &"normal")
	EventBus.forge_started.emit(_current_recipe.id)
	_timing_window.start()


static func _format_invest_text(recipe: RecipeData, optional: Array) -> String:
	var parts: Array[String] = ["投料 %s" % recipe.display_name]
	for mid in recipe.required_materials:
		parts.append("%s×%d" % [ForgeTopBar._short_name(mid), int(recipe.required_materials[mid])])
	if not optional.is_empty():
		var opts: Array[String] = []
		for mid in optional:
			opts.append(ForgeTopBar._short_name(mid))
		parts.append("+ " + " ".join(opts))
	return " ".join(parts)


func _on_timing_finished(score: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := ForgeSystem.forge_one(
		_current_recipe,
		_last_selected_optional,
		score,
		GameState.smith_hand_today,
		TimeLine.now_unix(),
		rng
	)
	if result.was_backlash:
		GameState.add_material(result.byproduct, result.byproduct_amount)
		_result_overlay.play(-1)
		Sfx.play_breach()
		ScreenFx.shake(14.0, 0.5)
		EventLog.add_entry(&"forge_backlash",
			"反噬！材料化作 %s ×%d" % [ForgeTopBar._short_name(result.byproduct), result.byproduct_amount],
			&"bad")
	else:
		GameState.add_to_inventory(result.equipment)
		_result_overlay.play(result.quality)
		Sfx.play_forge(int(result.quality))
		ScreenFx.shake(float(int(result.quality)) * 3.0, 0.3)
		var color: StringName = &"system" if result.quality >= 4 else (&"good" if (result.was_qiao_cheng or result.quality >= 3) else &"normal")
		var qiao: String = "（巧成）" if result.was_qiao_cheng else ""
		EventLog.add_entry(&"forge_done",
			"出炉：%s%s" % [result.equipment.display_full_name(), qiao],
			color)
	EventBus.forge_finished.emit(result.equipment, result.was_qiao_cheng, result.was_backlash)


func _on_overlay_done() -> void:
	# 刷新材料缩略 + chips 状态（消耗后数量变了）
	if _current_recipe != null:
		_top_bar.refresh_materials(_current_recipe)
		_bottom_bar.rebuild_chips(_current_recipe)


func _on_close() -> void:
	visible = false
```

- [ ] **Step 3: 验证 shop.tscn 加载（forge_screen 仍能 instantiate）**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --editor --path godot --quit-after 3 2>&1 | tail -3`
Then: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/ui/forge_screen.tscn 2>&1 | tail -10`
Expected: 无 Parse Error

- [ ] **Step 4: 验证 shop.tscn 仍能加载（不破已有引用）**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/playtest_n2_smoke.tscn 2>&1 | grep -E "PASS:|FAIL:" | tail -1`
Expected: `PASS: 109  FAIL: 0`（无回归）

- [ ] **Step 5: Commit**

```bash
git add godot/scenes/ui/forge_screen.tscn godot/scripts/ui/forge_screen.gd
git commit -m "feat(forge): ForgeScreen 重构为 3 段控制台日志风（TopBar/LogFlow/BottomBar）

- 移除 RecipePicker/MaterialStatus/OptionalPicker/StartButton/ResultLabel/CloseButton 直接控制
- 改为协调 3 个子组件 + TimingWindow + ResultOverlay
- _on_start 投料 EventLog kind=forge_invest
- _on_timing_finished 出炉/反噬 EventLog kind=forge_done/forge_backlash
- 业务逻辑（ForgeSystem.forge_one / 材料消耗 / Sfx / ScreenFx）不变"
```

---

### Task 5: TimingWindow 嵌入 LogFlow 顶（重定位）

**Files:**
- Modify: `godot/scripts/ui/forge_screen.gd:_ready` 加 timing_window 重定位逻辑

- [ ] **Step 1: 在 forge_screen.gd 的 _ready 末尾加 timing_window 定位**

在 `godot/scripts/ui/forge_screen.gd` 的 `_ready()` 函数最末尾追加：

```gdscript
	# TimingWindow 嵌入 LogFlow 顶部内：自定义位置
	_position_timing_window()


func _position_timing_window() -> void:
	if _timing_window == null or _log_flow == null:
		return
	# 等 layout 算完
	await get_tree().process_frame
	var lf_global: Vector2 = _log_flow.global_position
	var lf_size: Vector2 = _log_flow.size
	# 居中在 LogFlow 顶部 30% 区域
	_timing_window.position = Vector2(
		lf_global.x + lf_size.x * 0.5 - 80,
		lf_global.y + 12
	)
```

完整 `_ready` 应为：

```gdscript
func _ready() -> void:
	visible = false
	_top_bar.recipe_picked.connect(_on_recipe_picked)
	_top_bar.close_pressed.connect(_on_close)
	_bottom_bar.start_pressed.connect(_on_start)
	_timing_window.timing_finished.connect(_on_timing_finished)
	_result_overlay.animation_finished.connect(_on_overlay_done)
	_position_timing_window()


func _position_timing_window() -> void:
	if _timing_window == null or _log_flow == null:
		return
	await get_tree().process_frame
	var lf_global: Vector2 = _log_flow.global_position
	var lf_size: Vector2 = _log_flow.size
	_timing_window.position = Vector2(
		lf_global.x + lf_size.x * 0.5 - 80,
		lf_global.y + 12
	)
```

- [ ] **Step 2: 验证 forge_screen 仍能 instantiate**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/ui/forge_screen.tscn 2>&1 | tail -10`
Expected: 无 Parse Error / Runtime Error

- [ ] **Step 3: 验证 N2 锻造完整流程（headless 跑核心）**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_forge_one_full.tscn 2>&1 | grep -E "PASS:|FAIL:" | tail -1`
Expected: `PASS: 14  FAIL: 0`

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/ui/forge_screen.gd
git commit -m "feat(forge): TimingWindow 嵌入 LogFlow 顶部居中（替代屏幕中央悬浮）"
```

---

### Task 6: 烟测 — test_forge_console_smoke

**Files:**
- Create: `godot/scripts/test/test_forge_console_smoke.gd`
- Create: `godot/scripts/test/test_forge_console_smoke.gd.uid`
- Create: `godot/scenes/test/test_forge_console_smoke.tscn`

- [ ] **Step 1: Write the .uid file**

```
uid://bp2forgeconsoletest
```

写到 `godot/scripts/test/test_forge_console_smoke.gd.uid`

- [ ] **Step 2: Write the test gd**

```gdscript
extends Node
## 炉房 console 重构烟测：3 子组件 + LogFlow 过滤 + chip toggle + invest text 拼装

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_three_components_loadable()
	_test_forge_screen_has_three_segments()
	_test_log_flow_filters_forge_only()
	_test_top_bar_short_name()
	_test_bottom_bar_chip_state()
	_test_invest_text_format()
	print("\n========== test_forge_console_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_three_components_loadable() -> void:
	for s in ["res://scenes/ui/forge_top_bar.tscn",
			"res://scenes/ui/forge_log_flow.tscn",
			"res://scenes/ui/forge_bottom_bar.tscn"]:
		var pkd: PackedScene = load(s)
		_assert(pkd != null, "%s loadable" % s)
		var inst: Node = pkd.instantiate()
		_assert(inst != null, "instantiable")
		inst.queue_free()


func _test_forge_screen_has_three_segments() -> void:
	var pkd: PackedScene = load("res://scenes/ui/forge_screen.tscn")
	var inst: Node = pkd.instantiate()
	_assert(inst.has_node("Layout/TopBar"), "forge_screen has TopBar")
	_assert(inst.has_node("Layout/LogFlow"), "forge_screen has LogFlow")
	_assert(inst.has_node("Layout/BottomBar"), "forge_screen has BottomBar")
	_assert(inst.has_node("TimingWindow"), "forge_screen still has TimingWindow")
	_assert(inst.has_node("ResultOverlay"), "forge_screen still has ResultOverlay")
	inst.queue_free()


func _test_log_flow_filters_forge_only() -> void:
	# 验证 _is_forge_entry 静态方法
	_assert(ForgeLogFlow._is_forge_entry({"kind": "forge_done"}),
		"forge_done is forge entry")
	_assert(ForgeLogFlow._is_forge_entry({"kind": "forge_backlash"}),
		"forge_backlash is forge entry")
	_assert(not ForgeLogFlow._is_forge_entry({"kind": "customer_arrive"}),
		"customer_arrive NOT forge entry")
	_assert(not ForgeLogFlow._is_forge_entry({"kind": "resonance"}),
		"resonance NOT forge entry")


func _test_top_bar_short_name() -> void:
	_assert(ForgeTopBar._short_name(&"iron") == "铁", "iron → 铁")
	_assert(ForgeTopBar._short_name(&"jin") == "金", "jin → 金")
	_assert(ForgeTopBar._short_name(&"zhusha") == "朱", "zhusha → 朱")
	_assert(ForgeTopBar._short_name(&"yellow_paper") == "纸", "yellow_paper → 纸")


func _test_bottom_bar_chip_state() -> void:
	# 直接 instantiate ForgeBottomBar，rebuild_chips 后验证 selected_optional 起初空
	var pkd: PackedScene = load("res://scenes/ui/forge_bottom_bar.tscn")
	var bb: ForgeBottomBar = pkd.instantiate()
	add_child(bb)
	await get_tree().process_frame
	var recipe: RecipeData = DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	if recipe == null:
		_bad("iron_sword recipe missing")
		bb.queue_free()
		return
	bb.rebuild_chips(recipe)
	_assert(bb.selected_optional().is_empty(), "selected_optional empty after rebuild")
	bb.queue_free()


func _test_invest_text_format() -> void:
	var recipe: RecipeData = DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	if recipe == null:
		_bad("iron_sword recipe missing")
		return
	var t := ForgeScreen._format_invest_text(recipe, [])
	_assert("投料" in t, "invest text has 投料 (got: %s)" % t)
	_assert("铁" in t, "invest text mentions 铁 (got: %s)" % t)
	var t2 := ForgeScreen._format_invest_text(recipe, [&"hui"])
	_assert("+" in t2 and "灰" in t2, "with optional + 灰 (got: %s)" % t2)
```

写到 `godot/scripts/test/test_forge_console_smoke.gd`

- [ ] **Step 3: Write the test scene**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/test/test_forge_console_smoke.gd" id="1"]

[node name="TestForgeConsoleSmoke" type="Node"]
script = ExtResource("1")
```

写到 `godot/scenes/test/test_forge_console_smoke.tscn`

- [ ] **Step 4: 把 _test_bottom_bar_chip_state 改为 await（caller await）**

Edit `_ready` to await that test:

```gdscript
func _ready() -> void:
	await get_tree().process_frame
	_test_three_components_loadable()
	_test_forge_screen_has_three_segments()
	_test_log_flow_filters_forge_only()
	_test_top_bar_short_name()
	await _test_bottom_bar_chip_state()
	_test_invest_text_format()
	print("\n========== test_forge_console_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
```

- [ ] **Step 5: 跑测试**

Run: `"D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_forge_console_smoke.tscn 2>&1 | tail -15`
Expected: `PASS: ≥18  FAIL: 0`

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/test/test_forge_console_smoke.gd godot/scripts/test/test_forge_console_smoke.gd.uid godot/scenes/test/test_forge_console_smoke.tscn
git commit -m "test(forge): test_forge_console_smoke — 3 子组件加载 + LogFlow 过滤 + chip 状态 + invest 文本"
```

---

### Task 7: 全套回归 + README 进度

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 全套回归跑**

Run:

```bash
for t in test_forge_console_smoke test_forge_one_full test_forge_quality_roll test_event_log test_hud_visibility test_main_menu_smoke test_codex_placement test_pause_menu_smoke test_save_migration test_shop_rules test_resonance test_pattern_buffs test_star_brushes test_sfx_screenfx playtest_n2_smoke playtest_n4_smoke playtest_n7_smoke playtest_n7b_smoke playtest_n8_smoke playtest_n9_weird_codex_smoke; do
  result=$("D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

Expected: 所有行 `FAIL: 0`

- [ ] **Step 2: README 进度行追加**

打开 `README.md`，在已有进度列表末尾追加一行：

```
- ✅ 炉房 UI 重构 v1：控制台日志风（3 段：TopBar 配方+材料 / LogFlow 时辰染色日志 / BottomBar chips+开炉），TimingWindow 嵌入 LogFlow 顶
```

- [ ] **Step 3: Commit README**

```bash
git add README.md
git commit -m "docs(forge): README 进度更新（炉房 console 重构）"
```

- [ ] **Step 4: Final**

汇报：
- 验收标准 1-7 项是否过（DoD checklist）
- 全套测试 0 FAIL
- 文件改动 stat

---

## DoD 对照（验收）

| # | DoD 条目 | 由哪个 Task 覆盖 |
|---|---|---|
| 1 | 3 段布局可见 | Task 4 (.tscn 重构) + Task 6 烟测 has_node |
| 2 | 选配方 → 材料缩略色染 | Task 2 ForgeTopBar.refresh_materials |
| 3 | 投料 → LogFlow 末追加 | Task 4 _on_start → EventLog.add_entry forge_invest |
| 4 | 火候 → LogFlow 顶 TimingWindow | Task 5 _position_timing_window |
| 5 | 反噬 → LogFlow 红字 | Task 4 _on_timing_finished forge_backlash 用 color_key=&"bad" |
| 6 | 关闭再开仍能看到 | EventLog 已持久化 + Task 1 ForgeLogFlow._ready 调 rebuild_from_event_log |
| 7 | test_forge_console_smoke PASS | Task 6 |
| 8 | 全套回归 0 FAIL | Task 7 |

所有 8 项有对应 task 覆盖。
