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
	await _test_bottom_bar_chip_state()
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
