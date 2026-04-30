extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_three_customers_indexed()
	_test_su_jia_niangzi_loads()
	_test_meng_mian_ke_is_weird()
	print("\n========== test_customer_data_loads ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_three_customers_indexed() -> void:
	var ids: Array = DataRegistry.ids_of(&"customer")
	_assert(ids.size() >= 3, "customer index has >= 3 (got %d)" % ids.size())
	_assert(&"su_jia_niangzi" in ids, "su_jia_niangzi indexed")
	_assert(&"xiao_meng_pao_liao" in ids, "xiao_meng_pao_liao indexed")
	_assert(&"meng_mian_ke" in ids, "meng_mian_ke indexed")


func _test_su_jia_niangzi_loads() -> void:
	var c := DataRegistry.get_resource(&"customer", &"su_jia_niangzi") as CustomerData
	_assert(c != null, "su_jia_niangzi loads")
	if c == null: return
	_assert(c.display_name == "苏家娘子", "display_name correct")
	_assert(c.tier == CustomerData.Tier.REGULAR, "tier REGULAR")
	_assert(c.path_affinity == &"sword", "path sword")
	_assert(c.base_payment == 200, "payment 200")


func _test_meng_mian_ke_is_weird() -> void:
	var c := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	_assert(c != null, "meng_mian_ke loads")
	if c == null: return
	_assert(c.tier == CustomerData.Tier.WEIRD, "tier WEIRD")
	_assert(c.base_payment >= 500, "payment >= 500 (high)")
