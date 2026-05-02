extends Node
## compute_backlash_chance：基础 5%，禁/秘料堆叠升至 10%。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_baseline_5pct()
	_test_jin_or_mi_material_doubles()
	_test_multiple_dangerous_no_extra_stack()
	print("\n========== test_forge_backlash ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _approx(got: float, want: float, tol: float = 0.001) -> bool:
	return abs(got - want) < tol


func _test_baseline_5pct() -> void:
	var c := ForgeSystem.compute_backlash_chance([])
	_assert(_approx(c, 0.05), "no materials -> 0.05 (got %.3f)" % c)
	var c2 := ForgeSystem.compute_backlash_chance([&"hui", &"zhu_sha"])
	_assert(_approx(c2, 0.05), "non-dangerous mats -> 0.05 (got %.3f)" % c2)


func _test_jin_or_mi_material_doubles() -> void:
	var c1 := ForgeSystem.compute_backlash_chance([&"yi"])
	_assert(_approx(c1, 0.10), "yi -> 0.10 (got %.3f)" % c1)
	var c2 := ForgeSystem.compute_backlash_chance([&"mi_pin_zhi_xie"])
	_assert(_approx(c2, 0.10), "mi_pin_zhi_xie -> 0.10 (got %.3f)" % c2)


func _test_multiple_dangerous_no_extra_stack() -> void:
	var c := ForgeSystem.compute_backlash_chance([&"yi", &"mi_pin_zhi_xie", &"yi"])
	_assert(_approx(c, 0.10), "stacked dangerous mats capped at 0.10 (got %.3f)" % c)
