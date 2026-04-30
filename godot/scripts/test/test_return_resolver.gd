extends Node
## ReturnResolver 5 档结果分布按 tier 抽样验证。

const SAMPLES: int = 10000
const SEED: int = 42

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_outcome_enum()
	_test_regular_distribution()
	_test_weird_distribution()
	_test_outcome_text_nonempty()
	print("\n========== test_return_resolver ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_outcome_enum() -> void:
	_assert(ReturnResolver.Outcome.OK_RETURN == 0, "OK_RETURN=0")
	_assert(ReturnResolver.Outcome.GREAT_DEED == 1, "GREAT_DEED=1")
	_assert(ReturnResolver.Outcome.DAMAGED == 2, "DAMAGED=2")
	_assert(ReturnResolver.Outcome.MUTATED == 3, "MUTATED=3")
	_assert(ReturnResolver.Outcome.NOT_RETURNED == 4, "NOT_RETURNED=4")


func _test_regular_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0, 0, 0]
	for i in SAMPLES:
		counts[ReturnResolver.roll_outcome(CustomerData.Tier.REGULAR, rng)] += 1
	var expected := [7000, 1200, 1000, 500, 300]
	var tol := [120, 80, 70, 60, 50]
	for i in 5:
		var diff: int = absi(counts[i] - expected[i])
		_assert(diff < tol[i], "REGULAR tier %d: got %d expected %d (tol %d)" % [i, counts[i], expected[i], tol[i]])


func _test_weird_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0, 0, 0]
	for i in SAMPLES:
		counts[ReturnResolver.roll_outcome(CustomerData.Tier.WEIRD, rng)] += 1
	var expected := [2500, 2500, 1500, 2000, 1500]
	var tol := [120, 120, 100, 110, 100]
	for i in 5:
		var diff: int = absi(counts[i] - expected[i])
		_assert(diff < tol[i], "WEIRD tier %d: got %d expected %d (tol %d)" % [i, counts[i], expected[i], tol[i]])


func _test_outcome_text_nonempty() -> void:
	for o in 5:
		var t := ReturnResolver.outcome_text(o)
		_assert(t.length() > 0, "outcome %d text non-empty" % o)
