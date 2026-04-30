extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_tier_enum()
	print("\n========== test_customer_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_basic() -> void:
	var c := CustomerData.new()
	c.id = &"su_jia_niangzi"
	c.display_name = "苏家娘子"
	c.tier = CustomerData.Tier.REGULAR
	c.path_affinity = &"sword"
	c.base_payment = 200
	c.faction = &"hanxing_zong"
	_assert(c.id == &"su_jia_niangzi", "id set")
	_assert(c.tier == CustomerData.Tier.REGULAR, "tier REGULAR")
	_assert(c.base_payment == 200, "base_payment set")


func _test_tier_enum() -> void:
	_assert(CustomerData.Tier.REGULAR == 0, "REGULAR=0")
	_assert(CustomerData.Tier.RARE == 1, "RARE=1")
	_assert(CustomerData.Tier.WEIRD == 2, "WEIRD=2")
