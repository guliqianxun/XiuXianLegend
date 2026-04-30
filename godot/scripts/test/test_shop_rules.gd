extends Node
## ShopRules：4 预设 + evaluate / evaluate_offline / 序列化

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_4_presets_loaded()
	_test_default_enabled()
	_test_evaluate_refuse_all()
	_test_evaluate_lend_any()
	_test_evaluate_refuse_weird()
	_test_evaluate_priority_order()
	_test_evaluate_offline_breach_disguised_weird()
	_test_evaluate_offline_no_breach_when_refuse()
	_test_max_3_slots()
	_test_serialization_roundtrip()
	print("\n========== test_shop_rules ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_req(arrived_unix: int = 1700000000) -> CustomerRequest:
	var r := CustomerRequest.new()
	r.customer_id = &"_test"
	r.arrived_unix = arrived_unix
	return r


func _make_customer(tier: int, disguise_name: String = "", disguise_tier: int = -1) -> CustomerData:
	var c := CustomerData.new()
	c.id = &"_test"
	c.display_name = "测试客"
	c.tier = tier
	c.disguise_name = disguise_name
	c.disguise_tier = disguise_tier
	return c


func _test_4_presets_loaded() -> void:
	var ids := ShopRules.all_preset_ids()
	_assert(ids.size() == 4, "4 presets registered (got %d)" % ids.size())
	for need in [&"refuse_all", &"lend_any", &"refuse_weird", &"lend_regular"]:
		_assert(ShopRules.get_preset(need) != null, "preset %s exists" % need)


func _test_default_enabled() -> void:
	# 验证默认 enabled 包含 refuse_all
	_assert(ShopRules.is_enabled(&"refuse_all"), "default enabled has refuse_all")


func _test_evaluate_refuse_all() -> void:
	ShopRules.enabled = [&"refuse_all"]
	var req := _make_req()
	var c_reg := _make_customer(0)
	var c_weird := _make_customer(2)
	_assert(ShopRules.evaluate(req, c_reg) == &"refuse", "refuse_all → regular refused")
	_assert(ShopRules.evaluate(req, c_weird) == &"refuse", "refuse_all → weird refused")


func _test_evaluate_lend_any() -> void:
	ShopRules.enabled = [&"lend_any"]
	var req := _make_req()
	_assert(ShopRules.evaluate(req, _make_customer(0)) == &"lend", "lend_any → regular lent")
	_assert(ShopRules.evaluate(req, _make_customer(2)) == &"lend", "lend_any → weird lent")


func _test_evaluate_refuse_weird() -> void:
	# 单独 refuse_weird：怪客拒，常客无匹配 → 兜底拒（默认）
	ShopRules.enabled = [&"refuse_weird"]
	var req := _make_req()
	_assert(ShopRules.evaluate(req, _make_customer(2)) == &"refuse", "refuse_weird hits weird")
	_assert(ShopRules.evaluate(req, _make_customer(0)) == &"refuse", "no match → fallback refuse")


func _test_evaluate_priority_order() -> void:
	# refuse_weird 在前 + lend_regular 在后：怪客拒，常客借
	ShopRules.enabled = [&"refuse_weird", &"lend_regular"]
	var req := _make_req()
	_assert(ShopRules.evaluate(req, _make_customer(2)) == &"refuse", "weird refused (rule 1)")
	_assert(ShopRules.evaluate(req, _make_customer(0)) == &"lend", "regular lent (rule 2)")
	_assert(ShopRules.evaluate(req, _make_customer(1)) == &"refuse", "rare no match → fallback")


func _test_evaluate_offline_breach_disguised_weird() -> void:
	# 玩家启用拒怪客 + 借常客；伪装怪客（disguise=REGULAR）按伪装数据评估 → 借出 → 攻破
	ShopRules.enabled = [&"refuse_weird", &"lend_regular"]
	var req := _make_req()
	var c := _make_customer(2, "陌生剑客", 0)  # 真 weird，伪装 regular
	var result: Dictionary = ShopRules.evaluate_offline(req, c)
	_assert(result["action"] == &"lend", "disguised weird → action lend (按伪装放行)")
	_assert(result["breached"] == true, "breached = true (disguise hides true tier)")


func _test_evaluate_offline_no_breach_when_refuse() -> void:
	# 即使伪装客人，如果规则结果是 refuse，不算攻破（玩家没受损）
	ShopRules.enabled = [&"refuse_all"]
	var req := _make_req()
	var c := _make_customer(2, "陌生剑客", 0)
	var result: Dictionary = ShopRules.evaluate_offline(req, c)
	_assert(result["action"] == &"refuse", "refuse_all dominates")
	_assert(result["breached"] == false, "no breach when refused")


func _test_max_3_slots() -> void:
	ShopRules.enabled = []
	_assert(ShopRules.enable(&"refuse_all"), "enable 1")
	_assert(ShopRules.enable(&"lend_any"), "enable 2")
	_assert(ShopRules.enable(&"refuse_weird"), "enable 3")
	_assert(not ShopRules.enable(&"lend_regular"), "enable 4 rejected (cap=3)")
	ShopRules.disable(&"refuse_all")
	_assert(ShopRules.enable(&"lend_regular"), "after disable, can enable")


func _test_serialization_roundtrip() -> void:
	ShopRules.enabled = [&"refuse_weird", &"lend_regular"]
	var d := ShopRules.to_dict()
	ShopRules.enabled = []
	ShopRules.from_dict(d)
	_assert(ShopRules.enabled.size() == 2, "roundtrip: 2 entries")
	_assert(ShopRules.enabled[0] == &"refuse_weird", "first entry preserved")
	# 空列表 from_dict 应回退默认
	ShopRules.from_dict({"enabled": []})
	_assert(ShopRules.enabled == [&"refuse_all"], "empty roundtrip → default refuse_all")
