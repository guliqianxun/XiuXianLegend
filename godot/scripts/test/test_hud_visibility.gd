extends Node
## HUD 升级 + InventoryStrip：场景能加载新节点 + InventoryStrip 自刷新

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_shop_has_new_hud_labels()
	_test_inventory_strip_loadable()
	_test_shop_rule_change_emits_signal()
	await _test_format_active_rules()
	print("\n========== test_hud_visibility ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_shop_has_new_hud_labels() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	for need in ["HUD/HudFrame/VBox/TimeLabel", "HUD/HudFrame/VBox/MoneyLabel",
			"HUD/HudFrame/VBox/ReputationLabel", "HUD/HudFrame/VBox/BrushLabel",
			"HUD/HudFrame/VBox/CodexLabel", "HUD/RulesFrame/RulesLabel"]:
		_assert(inst.has_node(need), "shop has %s" % need)
	_assert(inst.has_node("InventoryStrip"), "shop has InventoryStrip")
	inst.queue_free()


func _test_inventory_strip_loadable() -> void:
	var pkd: PackedScene = load("res://scenes/ui/inventory_strip.tscn")
	_assert(pkd != null, "inventory_strip.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_shop_rule_change_emits_signal() -> void:
	# enable / disable 应 emit shop_rule_changed
	var sink := {"count": 0}
	var cb := func(_i: int) -> void: sink["count"] += 1
	EventBus.shop_rule_changed.connect(cb)
	ShopRules.enabled = []
	ShopRules.enable(&"refuse_all")
	_assert(sink["count"] >= 1, "enable emits (got %d)" % sink["count"])
	ShopRules.disable(&"refuse_all")
	_assert(sink["count"] >= 2, "disable emits (got %d)" % sink["count"])
	EventBus.shop_rule_changed.disconnect(cb)
	ShopRules.enabled = [&"refuse_all"]


func _test_format_active_rules() -> void:
	# 加载 shop_screen 并验证 _format_active_rules 拼出可读字符串
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	add_child(inst)
	await get_tree().process_frame
	ShopRules.enabled = [&"refuse_all"]
	var s: String = inst._format_active_rules()
	_assert("全拒" in s, "active rules show 全拒 (got %s)" % s)
	ShopRules.enabled = [&"refuse_weird", &"lend_regular"]
	var s2: String = inst._format_active_rules()
	_assert("拒怪客" in s2 and "接常客" in s2, "shows both (got %s)" % s2)
	ShopRules.enabled = [&"refuse_all"]
	inst.queue_free()
