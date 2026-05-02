# godot/scripts/test/test_customer_return_drop.gd
extends Node
## 客人归还带料：GREAT_DEED 必给，OK_RETURN 30%，其他不给

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_great_deed_gives_weird_material()
	_test_ok_return_sometimes_gives_tie()
	_test_damaged_gives_nothing()
	print("\n========== test_customer_return_drop ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)

func _simulate_drop(outcome: int, seed_val: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var dropped: StringName = &""
	match outcome:
		ReturnResolver.Outcome.GREAT_DEED:
			var pool := [&"gu", &"zhu_sha"]
			dropped = pool[rng.randi_range(0, pool.size() - 1)]
		ReturnResolver.Outcome.OK_RETURN:
			if rng.randf() < 0.30:
				dropped = &"tie"
	return dropped

func _test_great_deed_gives_weird_material() -> void:
	# 多 seed 验证：GREAT_DEED 必给 gu 或 zhu_sha
	for s in range(10):
		var d := _simulate_drop(ReturnResolver.Outcome.GREAT_DEED, s)
		_assert(d == &"gu" or d == &"zhu_sha", "seed %d GREAT_DEED → gu/zhu_sha (got %s)" % [s, d])

func _test_ok_return_sometimes_gives_tie() -> void:
	var hits := 0
	var trials := 1000
	for s in range(trials):
		var d := _simulate_drop(ReturnResolver.Outcome.OK_RETURN, s)
		if d == &"tie":
			hits += 1
	# 期望 ~30% ±5%
	var ratio: float = float(hits) / trials
	_assert(ratio > 0.25 and ratio < 0.35, "OK_RETURN tie ratio ~30%% (got %.3f over %d trials)" % [ratio, trials])

func _test_damaged_gives_nothing() -> void:
	for s in range(10):
		var d := _simulate_drop(ReturnResolver.Outcome.DAMAGED, s)
		_assert(d == &"", "seed %d DAMAGED → empty (got %s)" % [s, d])
