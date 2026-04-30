extends Node
## compute_qiao_cheng_chance：火候 + 手感 + 添料 三项贡献叠加。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_no_input_zero_chance()
	_test_perfect_timing_max_contribution()
	_test_smith_hand_contribution()
	_test_qiao_material_contribution()
	_test_capped_at_50pct()
	print("\n========== test_forge_qiao_cheng ==========")
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


func _test_no_input_zero_chance() -> void:
	var c := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [])
	_assert(_approx(c, 0.0), "0 timing + 1.0 hand + no mats -> 0.0 (got %.3f)" % c)


func _test_perfect_timing_max_contribution() -> void:
	var c := ForgeSystem.compute_qiao_cheng_chance(1.0, 1.0, [])
	_assert(_approx(c, 0.20), "perfect timing -> 0.20 (got %.3f)" % c)


func _test_smith_hand_contribution() -> void:
	var c1 := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.05, [])
	_assert(_approx(c1, 0.05), "hand 1.05 -> 0.05 (got %.3f)" % c1)
	var c2 := ForgeSystem.compute_qiao_cheng_chance(0.0, 0.95, [])
	_assert(_approx(c2, 0.0), "hand 0.95 floored to 0 (got %.3f)" % c2)


func _test_qiao_material_contribution() -> void:
	var c1 := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [&"hui"])
	_assert(_approx(c1, 0.10), "hui -> 0.10 (got %.3f)" % c1)
	var c2 := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [&"zhusha"])
	_assert(_approx(c2, 0.0), "zhusha (non-qiao) -> 0.0 (got %.3f)" % c2)
	var c3 := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [&"hui", &"hui"])
	_assert(_approx(c3, 0.20), "2x hui -> 0.20 (got %.3f)" % c3)


func _test_capped_at_50pct() -> void:
	var c := ForgeSystem.compute_qiao_cheng_chance(1.0, 1.05, [&"hui", &"hui", &"hui", &"hui", &"hui"])
	_assert(_approx(c, 0.50), "saturated input capped at 0.50 (got %.3f)" % c)
