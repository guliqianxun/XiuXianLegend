# 主铺重做 v1 实施计划（桌面卷宗风）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 把 shop.tscn 从"4 块 ColorRect + 大按钮"改造为"老铁桌面 4 张卷宗"，每张卷宗 PanelContainer + 朱红汉字印章 + 实时近况。

**Architecture:** 新增 ScrollCard 组件（Control + signal opened）。shop.tscn 用 4 个 ScrollCard 替换 4 个 area 节点。shop_screen.gd 接 opened 信号直接调原有 popup 打开方法。业务逻辑零改动。

**Tech Stack:** Godot 4.6 GDScript, PanelContainer + StyleBoxFlat 自定义, ColorRect 印章, paper_grain.gdshader 复用, Tween hover 动画, EventBus 状态订阅。

**Spec ref:** `docs/superpowers/specs/2026-05-04-desk-scrolls-redesign.md`
**Branch:** `polish/desk-scrolls`（已创建）

---

### Task 1: ScrollCard 组件 + smoke test

**Files:**
- Create: `godot/scripts/ui/scroll_card.gd` + `.uid`
- Create: `godot/scenes/ui/scroll_card.tscn`
- Test: `godot/scripts/test/test_scroll_card_smoke.gd` + `.tscn` + `.uid`

- [ ] **Step 1: 写 scroll_card.gd**

```gdscript
class_name ScrollCard
extends Control
## 卷宗卡片：朱红印章 + 楷书标题 + 实时近况文字 + hover 抬起。
## 整张卷宗可点击 → emit opened。

signal opened

@export var seal_char: String = "炉"
@export var card_title: String = "今日炉记"
@export var card_size: Vector2 = Vector2(280, 160)
@export_range(-10.0, 10.0) var z_rotation_degrees: float = 0.0

const HOVER_LIFT_PX := 6.0
const HOVER_TWEEN_SEC := 0.15

var _hover: bool = false
var _origin_y: float = 0.0
var _active_tween: Tween

@onready var _frame: PanelContainer = $Frame
@onready var _seal_label: Label = $Frame/VBox/Header/Seal/Label
@onready var _title_label: Label = $Frame/VBox/Header/TitleLabel
@onready var _status_label: Label = $Frame/VBox/StatusLabel
@onready var _status_area: Control = $Frame/VBox/StatusArea


func _ready() -> void:
	custom_minimum_size = card_size
	rotation_degrees = z_rotation_degrees
	pivot_offset = card_size * 0.5
	_origin_y = position.y
	_seal_label.text = seal_char
	_title_label.text = card_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	gui_input.connect(_on_gui_input)


## 设置近况文本（外部按需调用）
func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


## 把外部 Control（如 DoorVisual）嵌入 StatusArea 替代 status text
func mount_status_widget(widget: Control) -> void:
	if _status_label != null:
		_status_label.visible = false
	if _status_area != null:
		_status_area.add_child(widget)


func _on_mouse_enter() -> void:
	_hover = true
	_animate_hover(true)


func _on_mouse_exit() -> void:
	_hover = false
	_animate_hover(false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			opened.emit()


func _animate_hover(on: bool) -> void:
	if _active_tween != null and _active_tween.is_running():
		_active_tween.kill()
	var t := create_tween()
	_active_tween = t
	var target_y: float = _origin_y - HOVER_LIFT_PX if on else _origin_y
	var target_mod: Color = Color(1.1, 1.05, 1.0, 1.0) if on else Color.WHITE
	t.set_parallel(true)
	t.tween_property(self, "position:y", target_y, HOVER_TWEEN_SEC)
	t.tween_property(_frame, "modulate", target_mod, HOVER_TWEEN_SEC)
```

- [ ] **Step 2: 写 scroll_card.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/scroll_card.gd" id="1"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_card"]
bg_color = Color(0.18, 0.14, 0.10, 0.95)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.545, 0.227, 0.165, 0.85)
corner_radius_top_left = 0
corner_radius_top_right = 0
corner_radius_bottom_left = 0
corner_radius_bottom_right = 0
shadow_color = Color(0, 0, 0, 0.5)
shadow_size = 6
content_margin_left = 12.0
content_margin_top = 10.0
content_margin_right = 12.0
content_margin_bottom = 10.0

[node name="ScrollCard" type="Control"]
custom_minimum_size = Vector2(280, 160)
script = ExtResource("1")

[node name="Frame" type="PanelContainer" parent="."]
offset_right = 280.0
offset_bottom = 160.0
mouse_filter = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_card")

[node name="VBox" type="VBoxContainer" parent="Frame"]
theme_override_constants/separation = 8

[node name="Header" type="HBoxContainer" parent="Frame/VBox"]
theme_override_constants/separation = 10

[node name="Seal" type="ColorRect" parent="Frame/VBox/Header"]
custom_minimum_size = Vector2(34, 34)
color = Color(0.78, 0.32, 0.22, 1)
mouse_filter = 2

[node name="Label" type="Label" parent="Frame/VBox/Header/Seal"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
text = "炉"
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 20
theme_override_colors/font_color = Color(0.98, 0.94, 0.78, 1)
mouse_filter = 2

[node name="TitleLabel" type="Label" parent="Frame/VBox/Header"]
text = "今日炉记"
size_flags_vertical = 4
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.940, 0.870, 0.685, 1)
mouse_filter = 2

[node name="Sep" type="HSeparator" parent="Frame/VBox"]

[node name="StatusLabel" type="Label" parent="Frame/VBox"]
text = "—— 暂无 ——"
theme_override_font_sizes/font_size = 13
theme_override_colors/font_color = Color(0.785, 0.720, 0.550, 1)
autowrap_mode = 2
mouse_filter = 2

[node name="StatusArea" type="Control" parent="Frame/VBox"]
custom_minimum_size = Vector2(0, 80)
size_flags_vertical = 3
mouse_filter = 2
```

- [ ] **Step 3: 写 smoke test**

```gdscript
# godot/scripts/test/test_scroll_card_smoke.gd
extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _test_scene_loads()
	await _test_set_status_updates_label()
	await _test_emits_opened_on_click()
	await _test_mount_status_widget_hides_label()
	print("\n========== test_scroll_card_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _make_card() -> ScrollCard:
	var pkd: PackedScene = load("res://scenes/ui/scroll_card.tscn")
	var card: ScrollCard = pkd.instantiate()
	add_child(card)
	return card

func _test_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/scroll_card.tscn")
	_assert(pkd != null, "scroll_card.tscn loadable")
	var card: ScrollCard = pkd.instantiate()
	_assert(card != null, "instantiable")
	card.queue_free()
	await get_tree().process_frame

func _test_set_status_updates_label() -> void:
	var card := _make_card()
	await get_tree().process_frame
	card.set_status("开炉 3 · 反噬 1")
	_assert(card._status_label.text == "开炉 3 · 反噬 1", "status text set (got %s)" % card._status_label.text)
	card.queue_free()
	await get_tree().process_frame

func _test_emits_opened_on_click() -> void:
	var card := _make_card()
	await get_tree().process_frame
	var emitted := [false]
	card.opened.connect(func() -> void: emitted[0] = true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card._on_gui_input(ev)
	_assert(emitted[0], "opened emitted on click")
	card.queue_free()
	await get_tree().process_frame

func _test_mount_status_widget_hides_label() -> void:
	var card := _make_card()
	await get_tree().process_frame
	var w := Control.new()
	card.mount_status_widget(w)
	_assert(not card._status_label.visible, "status label hidden after mount")
	_assert(card._status_area.get_child_count() == 1, "widget added to status area")
	card.queue_free()
	await get_tree().process_frame
```

`.tscn`：

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/test/test_scroll_card_smoke.gd" id="1"]
[node name="TestScrollCardSmoke" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: 跑测试**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_scroll_card_smoke.tscn 2>&1 | tail -10
```

期望 `PASS: 7  FAIL: 0`。如果 Godot 报"Could not find type ScrollCard"，先运行一次 `--headless --quit` 让 Godot 重建 class_cache，或手动加 ScrollCard 条目到 `godot/.godot/global_script_class_cache.cfg`（参考前几个 task 的同类处理）。

- [ ] **Step 5: 写 .uid 占位**

`scroll_card.gd.uid` 内容 `uid://scroll_card_v1`，`test_scroll_card_smoke.gd.uid` 内容 `uid://test_scroll_card_smoke_v1`。

- [ ] **Step 6: Commit（不要 git add -A）**

```bash
git add godot/scripts/ui/scroll_card.* godot/scenes/ui/scroll_card.tscn godot/scripts/test/test_scroll_card_smoke.* godot/scenes/test/test_scroll_card_smoke.tscn godot/.godot/global_script_class_cache.cfg
git commit -m "feat(ui): ScrollCard 组件 — 朱红印章 + 标题 + 近况 + hover 抬起"
```

---

### Task 2: shop.tscn 4 区域换 4 张卷宗

**Files:**
- Modify: `godot/scenes/shop.tscn`

- [ ] **Step 1: 备份理解现有结构**

打开 shop.tscn 对照 spec 布局：
- 删除 4 个 area 节点（AreaFurnace / AreaCounter / AreaLoft / AreaYard）及其全部子节点（Border / Button / Label）
- 注意 DoorVisual 当前挂在 AreaCounter 下，删 area 之前要把 DoorVisual 节点保留并移挂到 ScrollCardCounter 的 StatusArea
- OldIron 节点保留但 position 改为 (640, 540)
- Background 的 sub_resource bg_mat：`base_color=Color(0.082, 0.060, 0.038, 1.0)`, `vignette_strength=0.55`

- [ ] **Step 2: 加 ScrollCard ext_resource**

shop.tscn 顶部 ext_resource 列表加：
```
[ext_resource type="PackedScene" path="res://scenes/ui/scroll_card.tscn" id="18"]
```
load_steps 数加 1。

- [ ] **Step 3: 替换 4 个 area 节点为 4 个 ScrollCard**

新增节点（替换原 4 个 area）：

```
[node name="ScrollCardForge" parent="." instance=ExtResource("18")]
position = Vector2(120, 180)
seal_char = "炉"
card_title = "今日炉记"
z_rotation_degrees = -3.0

[node name="ScrollCardCounter" parent="." instance=ExtResource("18")]
position = Vector2(720, 180)
seal_char = "帖"
card_title = "门外牌示"
z_rotation_degrees = 3.0

[node name="DoorVisual" parent="ScrollCardCounter" instance=ExtResource("17")]
offset_left = 12.0
offset_top = 60.0
offset_right = 268.0
offset_bottom = 140.0

[node name="ScrollCardCodex" parent="." instance=ExtResource("18")]
position = Vector2(200, 420)
seal_char = "谱"
card_title = "古谱卷"
z_rotation_degrees = 2.0

[node name="ScrollCardRules" parent="." instance=ExtResource("18")]
position = Vector2(820, 420)
seal_char = "规"
card_title = "店铺规约"
z_rotation_degrees = -2.0
```

⚠️ 注意：ScrollCardCounter 内嵌 DoorVisual 的位置 offset 要在 ScrollCard 自己的 280×160 局部坐标系内，offset 是相对 ScrollCardCounter 的（不是 Frame）。本 step 直接挂在 ScrollCardCounter 下覆盖在 PanelContainer 上面。如果效果叠加问题，T3 调整为挂到 Frame/VBox/StatusArea 节点下。

- [ ] **Step 4: OldIron reposition**

```
[node name="OldIron" parent="." instance=ExtResource("2")]
position = Vector2(640, 540)
```

- [ ] **Step 5: Background bg_mat 调暖**

```
[sub_resource type="ShaderMaterial" id="bg_mat"]
shader = ExtResource("14")
shader_parameter/base_color = Color(0.082, 0.060, 0.038, 1.0)
shader_parameter/noise_strength = 0.06
shader_parameter/vignette_strength = 0.55
shader_parameter/grain_scale = 180.0
```

- [ ] **Step 6: 跑 main_menu_smoke + n4_smoke 验证 scene 至少能 load**

```bash
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/test_main_menu_smoke.tscn 2>&1 | tail -5
"/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot res://scenes/test/playtest_n4_smoke.tscn 2>&1 | tail -5
```

注意：T3 还没改 shop_screen.gd，所以 `@onready` ref 找不到 Open*Button 会报 null，但 scene 本身应该能 load。如果整个 scene load 都失败，说明 shop.tscn 改坏了，要先 fix。

- [ ] **Step 7: Commit**

```bash
git add godot/scenes/shop.tscn
git commit -m "feat(ui): shop.tscn 4 area 替换为 4 张 ScrollCard + 桌面色调暖化"
```

---

### Task 3: shop_screen.gd 信号 + 近况刷新

**Files:**
- Modify: `godot/scripts/ui/shop_screen.gd`

- [ ] **Step 1: @onready refs 替换**

把这 4 行删除：
```gdscript
@onready var _open_forge_btn: Button = $AreaFurnace/OpenForgeButton
@onready var _open_codex_btn: Button = $AreaLoft/OpenCodexButton
@onready var _open_counter_btn: Button = $AreaCounter/OpenCounterButton
@onready var _open_rules_btn: Button = $AreaYard/OpenRulesButton
```

替换为：
```gdscript
@onready var _card_forge: ScrollCard = $ScrollCardForge
@onready var _card_counter: ScrollCard = $ScrollCardCounter
@onready var _card_codex: ScrollCard = $ScrollCardCodex
@onready var _card_rules: ScrollCard = $ScrollCardRules
```

DoorVisual 路径调整：
```gdscript
@onready var _door_visual: DoorVisual = $ScrollCardCounter/DoorVisual
```

- [ ] **Step 2: _ready 信号绑定改写**

把这 4 行（约 line 72-75）：
```gdscript
_open_forge_btn.pressed.connect(_on_open_forge)
_open_codex_btn.pressed.connect(_on_open_codex)
_open_counter_btn.pressed.connect(_on_open_counter)
_open_rules_btn.pressed.connect(_on_open_rules)
```

替换为：
```gdscript
_card_forge.opened.connect(_on_open_forge)
_card_counter.opened.connect(_on_open_counter)
_card_codex.opened.connect(_on_open_codex)
_card_rules.opened.connect(_on_open_rules)
```

- [ ] **Step 3: _refresh_counter_button 适配**

原 `_refresh_counter_button` 操作 `_open_counter_btn.text` / `.disabled`。
卷宗模式下卷宗自己始终可点（点了走 spawn_now → 已 pending 时 spawn_now 内部返回 false 不会重复 spawn），所以可以简化为：把 pending 状态体现在 ScrollCard 的 status text 上，而不是 disable 卷宗。

修改 `_refresh_counter_button`（重命名为 `_refresh_card_counter`）：
```gdscript
func _refresh_card_counter() -> void:
	# 门外卷宗的状态由内嵌 DoorVisual 自行显示，无需文字状态
	pass
```

实际上既然 DoorVisual 已经显示状态，counter 卷宗可以完全省去 status_label refresh。`_card_counter` 不调 set_status，让它显示默认占位"—— 暂无 ——"被 DoorVisual 视觉覆盖。

更稳妥：counter 卷宗 _ready 时直接 `set_status("")` 或调 `mount_status_widget(_door_visual)` —— 但 DoorVisual 已经在 .tscn 里挂在 ScrollCardCounter 下了，不需要再 mount。简化为 set_status 空字符串。

- [ ] **Step 4: 删除原 _refresh_counter_button 旧逻辑，加新近况方法**

```gdscript
const RECENT_FORGE_LOOKBACK := 10

func _refresh_card_forge() -> void:
	var entries: Array = EventLog.entries
	var recent: Array = []
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		if String(e.get("kind", "")).begins_with("forge_"):
			recent.append(e)
			if recent.size() >= RECENT_FORGE_LOOKBACK:
				break
	var open_n: int = 0
	var bk_n: int = 0
	for e in recent:
		var k: String = String(e.get("kind", ""))
		if k == "forge_done":
			open_n += 1
		elif k == "forge_backlash":
			bk_n += 1
	_card_forge.set_status("近 %d 条：开炉 %d · 反噬 %d" % [recent.size(), open_n, bk_n])


func _refresh_card_codex() -> void:
	var resonant: int = 0
	for gid in [&"qing_long", &"xuan_wu", &"zhu_que", &"bai_hu", &"zi_wei", &"xue_yao", &"can_xiu"]:
		if GameState.has_resonance(gid):
			resonant += 1
	var current: StringName = CodexState.current_gupu if CodexState.current_gupu != &"" else &"qing_long"
	var name: String = "—"
	var g := DataRegistry.get_resource(&"gupu", current) as GuPuData
	if g != null:
		name = g.display_name
	_card_codex.set_status("共鸣 %d/7 · 当前: %s" % [resonant, name])


func _refresh_card_rules() -> void:
	var n: int = ShopRules.active_rule_count() if ShopRules.has_method("active_rule_count") else 0
	_card_rules.set_status("%d/4 规已立" % n)
```

⚠️ 实施前必须 grep 验证：
- `CodexState.current_gupu` 字段名（如不存在，去掉这行用占位 "—"）
- `ShopRules.active_rule_count()` 方法名（如不存在，简化为统计 ShopRules.slots 非空数）

- [ ] **Step 5: _ready 末尾加首次刷 + 信号订阅**

在原来 `_refresh_hud()` 之前加：

```gdscript
EventBus.forge_finished.connect(func(_g, _q, _b) -> void: _refresh_card_forge())
EventBus.resonance_activated.connect(func(_g, _p) -> void: _refresh_card_codex())
EventBus.codex_changed.connect(func(_g) -> void: _refresh_card_codex())
EventBus.shop_rule_changed.connect(func(_i) -> void: _refresh_card_rules())
_refresh_card_forge()
_refresh_card_codex()
_refresh_card_rules()
```

- [ ] **Step 6: 跑全套关键测试**

```bash
for t in test_scroll_card_smoke test_door_visual_smoke playtest_n4_smoke playtest_n2_smoke test_main_menu_smoke; do
  result=$("/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

期望全部 `FAIL: 0`。

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/ui/shop_screen.gd
git commit -m "feat(ui): shop_screen 接 ScrollCard.opened 信号 + 实时近况刷新"
```

---

### Task 4: 全套回归 + README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 全套回归**

```bash
for t in test_scroll_card_smoke test_door_visual_smoke test_material_data test_save_migration test_material_shop_dialog_smoke test_customer_return_drop test_affix_bias test_forge_console_smoke test_forge_one_full test_forge_quality_roll test_event_log test_hud_visibility test_main_menu_smoke test_codex_placement test_pause_menu_smoke test_shop_rules test_resonance test_pattern_buffs test_star_brushes test_sfx_screenfx test_affix_system test_materials_inventory test_forge_backlash test_forge_qiao_cheng test_offline_simulator test_recipe_data test_recipe_data_loads test_resonance_buffs playtest_n2_smoke playtest_n4_smoke playtest_n7_smoke playtest_n7b_smoke playtest_n8_smoke playtest_n9_weird_codex_smoke; do
  result=$("/d/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/${t}.tscn" 2>&1 | grep -E "PASS:|FAIL:" | tail -1)
  echo "${t}: ${result}"
done
```

期望全部 `FAIL: 0`。

- [ ] **Step 2: README 加进度行**

在 README "UI 易用性 v1" 行后插入：
```
- ✅ 主铺重做 v1：桌面卷宗风（4 张 PanelContainer 卷宗 + 朱红汉字印章 + 实时近况 + hover 抬起 -6px + ±3° 错落倾斜），老铁立绘居中，DoorVisual 内嵌门外卷宗
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(ui): README 进度更新（主铺重做 v1 桌面卷宗风）"
```

汇报：
- DoD 1-10 项过 / 没过的列出
- 全套测试 0 FAIL 数字
- 改动 stat
