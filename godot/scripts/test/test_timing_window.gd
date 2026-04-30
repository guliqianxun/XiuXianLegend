extends Node
## TimingWindow.score_at_ratio：纯函数测试（不需要 UI 交互）。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_dead_center_full_score()
	_test_inside_target_full_score()
	_test_outside_target_decays()
	_test_far_from_target_zero()
	print("\n========== test_timing_window ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _approx(got: float, want: float, tol: float = 0.01) -> bool:
	return abs(got - want) < tol


func _test_dead_center_full_score() -> void:
	_assert(_approx(TimingWindow.score_at_ratio(0.65), 1.0), "center -> 1.0")


func _test_inside_target_full_score() -> void:
	_assert(_approx(TimingWindow.score_at_ratio(0.55), 1.0), "left edge -> 1.0")
	_assert(_approx(TimingWindow.score_at_ratio(0.75), 1.0), "right edge -> 1.0")
	_assert(_approx(TimingWindow.score_at_ratio(0.70), 1.0), "0.70 -> 1.0")


func _test_outside_target_decays() -> void:
	_assert(_approx(TimingWindow.score_at_ratio(0.50), 0.5, 0.05), "0.50 -> ~0.5")


func _test_far_from_target_zero() -> void:
	_assert(_approx(TimingWindow.score_at_ratio(0.0), 0.0), "0.0 -> 0.0")
	_assert(_approx(TimingWindow.score_at_ratio(1.0), 0.0), "1.0 -> 0.0")
