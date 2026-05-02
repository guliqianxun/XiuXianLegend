extends Node
## OfflineSimulator：离线时长 → 日记条目。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_zero_offline_empty()
	_test_short_offline_no_sleep_card()
	_test_long_offline_has_sleep_card()
	_test_very_long_offline_tier2_text()
	_test_simulate_does_not_touch_inventory()
	_test_seed_deterministic()
	_test_rule_breach_recorded()
	print("\n========== test_offline_simulator ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_zero_offline_empty() -> void:
	var d := OfflineSimulator.simulate(1700000000, 1700000000)
	_assert(d.is_empty(), "0s offline → empty diary")
	var d2 := OfflineSimulator.simulate(1700000000, 1700000000 - 100)
	_assert(d2.is_empty(), "negative offline → empty diary")


func _test_short_offline_no_sleep_card() -> void:
	# 6h 离线（< 24h），不应有 sleep 卡
	var d := OfflineSimulator.simulate(1700000000, 1700000000 + 6 * 3600)
	for e in d:
		_assert((e as Dictionary).get("kind", &"") != &"sleep", "no sleep card under 24h")


func _test_long_offline_has_sleep_card() -> void:
	# 30h 离线，应有 sleep 卡且文案是 tier1
	var d := OfflineSimulator.simulate(1700000000, 1700000000 + 30 * 3600)
	_assert(not d.is_empty(), "30h offline produces entries")
	var first: Dictionary = d[0]
	_assert(first["kind"] == &"sleep", "first entry is sleep card")
	_assert(String(first["detail"]).contains("睡过去了"), "tier1 text says 睡过去了")


func _test_very_long_offline_tier2_text() -> void:
	# 100h 离线 (> 72h)，sleep 文案应是 tier2
	var d := OfflineSimulator.simulate(1700000000, 1700000000 + 100 * 3600)
	var first: Dictionary = d[0]
	_assert(first["kind"] == &"sleep", "first entry is sleep card")
	_assert(String(first["detail"]).contains("灶火早就凉了"), "tier2 text says 灶火早就凉了")


func _test_simulate_does_not_touch_inventory() -> void:
	# v1 模拟器不修改 inventory（避免无铺规时 imbalance）
	var inv_size_before: int = GameState.inventory.size()
	var iron_before: int = GameState.material_count(&"tie")
	OfflineSimulator.simulate(1700000000, 1700000000 + 48 * 3600)
	_assert(GameState.inventory.size() == inv_size_before, "inventory size unchanged")
	_assert(GameState.material_count(&"tie") == iron_before, "tie count unchanged")


func _test_seed_deterministic() -> void:
	# 同 last_settle_unix 跑两次，结果应完全一致
	var d1 := OfflineSimulator.simulate(1700001234, 1700001234 + 12 * 3600)
	var d2 := OfflineSimulator.simulate(1700001234, 1700001234 + 12 * 3600)
	_assert(d1.size() == d2.size(), "deterministic count")
	if d1.size() == d2.size() and not d1.is_empty():
		_assert(String((d1[0] as Dictionary)["detail"]) == String((d2[0] as Dictionary)["detail"]),
			"deterministic first entry")


func _test_rule_breach_recorded() -> void:
	# 启用「拒怪客 + 借常客」，跨多个 seed × 长时间，应至少出一次伪装攻破
	# （生成器：怪客 10% × 伪装 30% × 长跨度 → 概率累加）
	var saved := ShopRules.enabled.duplicate()
	ShopRules.enabled = [&"refuse_weird", &"lend_regular"]
	var found_breach := false
	for s in 30:
		var d := OfflineSimulator.simulate(s * 1000, s * 1000 + 72 * 3600)
		for e in d:
			if (e as Dictionary).get("kind", &"") == &"rule_breach":
				found_breach = true
				break
		if found_breach: break
	ShopRules.enabled = saved
	_assert(found_breach, "rule_breach diary entry produced (30 seeds × 72h)")
