extends Node
## N5b 烟测：ShopRules + RulesScreen + 离线攻破链路

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_rules_screen_loads()
	_test_shop_has_rules_button_and_screen()
	_test_offline_lend_with_lend_any()
	_test_offline_breach_under_disguise()
	print("\n========== playtest_n5b_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_rules_screen_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/rules_screen.tscn")
	_assert(pkd != null, "rules_screen.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_shop_has_rules_button_and_screen() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	_assert(inst.has_node("AreaYard/OpenRulesButton"), "shop has OpenRulesButton")
	_assert(inst.has_node("RulesScreen"), "shop has RulesScreen child")
	inst.queue_free()


func _test_offline_lend_with_lend_any() -> void:
	# 启用 lend_any，离线 6h 应至少出一条 customer_lend
	var saved := ShopRules.enabled.duplicate()
	ShopRules.enabled = [&"lend_any"]
	var d := OfflineSimulator.simulate(99999, 99999 + 6 * 3600)
	var lent := 0
	for e in d:
		if (e as Dictionary).get("kind", &"") == &"customer_lend":
			lent += 1
	ShopRules.enabled = saved
	_assert(lent > 0, "lend_any: %d lend events in 6h" % lent)


func _test_offline_breach_under_disguise() -> void:
	# 启用 lend_regular（让伪装客被放行），多 seed × 长跨度找 breach
	# 生成器：怪客 10% × 30% 伪装 → 概率较低，需要多次尝试
	var saved := ShopRules.enabled.duplicate()
	ShopRules.enabled = [&"lend_regular"]
	var found := false
	for s in 30:
		var d := OfflineSimulator.simulate(s * 1000 + 1, s * 1000 + 1 + 72 * 3600)
		for e in d:
			if (e as Dictionary).get("kind", &"") == &"rule_breach":
				found = true
				break
		if found: break
	ShopRules.enabled = saved
	_assert(found, "rule_breach event triggers under lend_regular (30 seeds × 72h)")
