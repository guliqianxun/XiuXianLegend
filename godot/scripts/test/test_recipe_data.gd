extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_quality_distribution_sum()
	print("\n========== test_recipe_data ==========")
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
	var r := RecipeData.new()
	r.id = &"sword_basic"
	r.display_name = "凡铁剑"
	r.required_materials = {&"tie": 2, &"jin": 4}
	r.optional_materials = [&"zhu_sha", &"hui"]
	r.base_quality_distribution = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])
	r.base_minutes_in_furnace = 30
	_assert(r.id == &"sword_basic", "id set")
	_assert(r.display_name == "凡铁剑", "display_name set")
	_assert(r.required_materials.has(&"tie"), "required_materials map")
	_assert(r.base_quality_distribution.size() == 5, "5-tier quality")
	_assert(r.base_minutes_in_furnace == 30, "base_minutes_in_furnace set")


func _test_quality_distribution_sum() -> void:
	var r := RecipeData.new()
	r.base_quality_distribution = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])
	var s: float = 0.0
	for x in r.base_quality_distribution:
		s += x
	_assert(abs(s - 1.0) < 0.001, "distribution sums to 1.0 (got %.3f)" % s)
