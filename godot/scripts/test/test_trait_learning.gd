extends Node
## N5c：trait 学习 + 动态规则注入 + has_trait 评估

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_customers_have_traits()
	_test_trait_library_covers_data()
	_test_learn_traits_dedup()
	_test_learn_traits_emits_signal()
	_test_serialization_roundtrip()
	_test_dynamic_rule_injection()
	_test_has_trait_evaluation()
	await _test_inspect_learns_traits()
	_test_breach_learns_traits()
	print("\n========== test_trait_learning ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_customers_have_traits() -> void:
	var meng := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	_assert(meng != null, "meng_mian_ke loadable")
	if meng != null:
		_assert(meng.traits.size() == 2, "meng has 2 traits (got %d)" % meng.traits.size())
		_assert(meng.traits.has(&"sole_dustless"), "meng has sole_dustless")
		_assert(meng.traits.has(&"hooded"), "meng has hooded")


func _test_trait_library_covers_data() -> void:
	# 所有客人 .tres 里出现的 trait 必须在 TRAIT_LIBRARY 注册
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c == null: continue
		for t in c.traits:
			_assert(ShopRules.TRAIT_LIBRARY.has(t),
				"trait '%s' (on %s) registered in TRAIT_LIBRARY" % [t, cid])


func _test_learn_traits_dedup() -> void:
	GameState.learned_traits = []
	GameState.learn_traits([&"sole_dustless", &"hooded"])
	_assert(GameState.learned_traits.size() == 2, "2 learned")
	GameState.learn_traits([&"hooded", &"speaks_old"])  # hooded 重复
	_assert(GameState.learned_traits.size() == 3, "dedup: 3 (not 4)")
	_assert(GameState.has_learned_trait(&"speaks_old"), "speaks_old learned")


func _test_learn_traits_emits_signal() -> void:
	GameState.learned_traits = []
	# 用 Dictionary 包裹解决闭包局部变量写回问题
	var sink := {"got": []}
	var cb := func(ids: Array) -> void: sink["got"] = ids
	EventBus.traits_learned.connect(cb)
	GameState.learn_traits([&"family_seal", &"badge_low"])
	_assert((sink["got"] as Array).size() == 2, "signal fired with 2 ids")
	# 重复学不发信号（因为没新东西）
	sink["got"] = []
	GameState.learn_traits([&"family_seal"])
	_assert((sink["got"] as Array).is_empty(), "no signal when nothing new")
	EventBus.traits_learned.disconnect(cb)


func _test_serialization_roundtrip() -> void:
	GameState.learned_traits = [&"sole_dustless", &"hooded"]
	var d: Dictionary = GameState.to_dict()
	GameState.learned_traits = []
	GameState.from_dict(d)
	_assert(GameState.learned_traits.size() == 2, "roundtrip: 2 traits")
	_assert(GameState.has_learned_trait(&"sole_dustless"), "first preserved")


func _test_dynamic_rule_injection() -> void:
	# 学到 trait 后，ShopRules 应能 get_preset(learned:xxx) 返回非空
	GameState.learned_traits = [&"sole_dustless"]
	var rule: ShopRule = ShopRules.get_preset(&"learned:sole_dustless")
	_assert(rule != null, "learned:sole_dustless rule retrievable")
	if rule != null:
		_assert(rule.condition == &"has_trait", "rule condition = has_trait")
		_assert(rule.condition_arg == &"sole_dustless", "rule arg = sole_dustless")
		_assert(rule.action == &"refuse", "default action = refuse")
		_assert(String(rule.display_name).contains("鞋底无尘"), "display name uses TRAIT_LIBRARY")
	# 未学到的 trait 不应可获取
	GameState.learned_traits = []
	_assert(ShopRules.get_preset(&"learned:sole_dustless") == null, "unlearned not retrievable")


func _test_has_trait_evaluation() -> void:
	# 启用 learned:sole_dustless → 蒙面客 (有该 trait) 应被拒
	GameState.learned_traits = [&"sole_dustless"]
	ShopRules.enabled = [&"learned:sole_dustless"]
	var meng := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	var req := CustomerRequest.new()
	req.customer_id = meng.id
	req.arrived_unix = 1700000000
	_assert(ShopRules.evaluate(req, meng) == &"refuse", "trait rule fires on meng")
	# 苏家娘子无该 trait → 兜底拒（无其他匹配规则）
	var su := DataRegistry.get_resource(&"customer", &"su_jia_niangzi") as CustomerData
	var req2 := CustomerRequest.new()
	req2.customer_id = su.id
	req2.arrived_unix = 1700000000
	_assert(ShopRules.evaluate(req2, su) == &"refuse", "su no match → fallback refuse")


func _test_inspect_learns_traits() -> void:
	# 模拟打听蒙面客
	GameState.learned_traits = []
	GameState.spirit_stones = 1000
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame
	var req := CustomerRequest.new()
	req.customer_id = &"meng_mian_ke"
	req.unmasked = false
	panel.show_request(req)
	panel._on_inspect()
	_assert(GameState.has_learned_trait(&"sole_dustless"), "inspect learned sole_dustless")
	_assert(GameState.has_learned_trait(&"hooded"), "inspect learned hooded")
	panel.queue_free()


func _test_breach_learns_traits() -> void:
	# 离线攻破时也应学到
	GameState.learned_traits = []
	var saved := ShopRules.enabled.duplicate()
	ShopRules.enabled = [&"lend_regular"]
	for s in [11, 22, 33, 44, 55, 66, 77, 88, 99]:
		var d := OfflineSimulator.simulate(s, s + 48 * 3600)
		var has_breach := false
		for e in d:
			if (e as Dictionary).get("kind", &"") == &"rule_breach":
				has_breach = true
				break
		if has_breach: break
	ShopRules.enabled = saved
	_assert(not GameState.learned_traits.is_empty(),
		"after offline breach: learned_traits non-empty (got %s)" % str(GameState.learned_traits))
