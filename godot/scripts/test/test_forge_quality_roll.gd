extends Node
## ForgeSystem.roll_quality 蒙特卡洛分布拟合。RNG 用固定 seed 保证 deterministic。

const SAMPLES: int = 10000
const SEED: int = 42

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_distribution_baseline()
	_test_qiao_cheng_upgrades_one_tier()
	_test_qiao_cheng_caps_at_4()
	print("\n========== test_forge_quality_roll ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_distribution_baseline() -> void:
	var dist := PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0, 0, 0]
	for i in SAMPLES:
		var q := ForgeSystem.roll_quality(dist, false, rng)
		counts[q] += 1
	var tol := [120, 100, 80, 60, 30]
	var expected := [6000, 2500, 1000, 400, 100]
	for tier in 5:
		var diff: int = absi(counts[tier] - expected[tier])
		_assert(diff < tol[tier],
			"tier %d: got %d expected %d (diff %d, tol %d)" % [tier, counts[tier], expected[tier], diff, tol[tier]])


func _test_qiao_cheng_upgrades_one_tier() -> void:
	var dist := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var q := ForgeSystem.roll_quality(dist, true, rng)
	_assert(q == 1, "qiao_cheng on Q0 -> Q1 (got %d)" % q)


func _test_qiao_cheng_caps_at_4() -> void:
	var dist := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 1.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var q := ForgeSystem.roll_quality(dist, true, rng)
	_assert(q == 4, "qiao_cheng on Q4 -> Q4 (cap, got %d)" % q)
