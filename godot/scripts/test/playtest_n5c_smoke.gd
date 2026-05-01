extends Node
## N5c 烟测：trait 学习 → RulesScreen 显示 → 启用规则生效

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_3_customers_have_traits()
	_test_trait_library_complete()
	_test_save_v5()
	_test_full_loop_inspect_and_use()
	print("\n========== playtest_n5c_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_3_customers_have_traits() -> void:
	# 设计：常客允许无 trait（"平凡到无特征"），但全体至少 70% 客人带 trait
	var total := 0
	var with_traits := 0
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c == null: continue
		total += 1
		if not c.traits.is_empty():
			with_traits += 1
	var ratio: float = float(with_traits) / float(max(1, total))
	_assert(ratio >= 0.70, "≥70%% customers have traits (got %d/%d = %.0f%%)" %
		[with_traits, total, ratio * 100.0])


func _test_trait_library_complete() -> void:
	# spec 列出至少 6 条 trait
	_assert(ShopRules.TRAIT_LIBRARY.size() >= 6,
		"TRAIT_LIBRARY has >= 6 entries (got %d)" % ShopRules.TRAIT_LIBRARY.size())


func _test_save_v5() -> void:
	# v5 introduced learned_traits; current version may have advanced (N7 → v6)
	_assert(SaveSystem.SAVE_VERSION >= 5, "SAVE_VERSION ≥ 5 (got %d)" % SaveSystem.SAVE_VERSION)


func _test_full_loop_inspect_and_use() -> void:
	# 完整链路：学到 sole_dustless → 启用 learned 规则 → 蒙面客被拒
	GameState.learned_traits = [&"sole_dustless"]
	ShopRules.enabled = [&"learned:sole_dustless"]
	var meng := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	var req := CustomerRequest.new()
	req.customer_id = meng.id
	req.arrived_unix = 1700000000
	# 在线评估（按真实 traits）
	_assert(ShopRules.evaluate(req, meng) == &"refuse", "online: meng refused via trait rule")
	# 离线评估（even with disguise，trait 不被伪装影响）
	var result: Dictionary = ShopRules.evaluate_offline(req, meng)
	_assert(result["action"] == &"refuse", "offline: meng refused via trait rule (disguise can't hide traits)")
	_assert(not result["breached"], "no breach: rule correctly refused (disguise+trait combo)")
