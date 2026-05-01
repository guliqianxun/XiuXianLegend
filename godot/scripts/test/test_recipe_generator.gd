extends Node
## RecipeGenerator：3 tier 配方生成 + 6 slot 覆盖 + 多样性

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic_fields()
	_test_id_unique()
	_test_quality_dist_sums_to_one()
	_test_path_matches_slot()
	_test_materials_non_empty()
	_test_six_slots_reachable()
	_test_diversity_60_samples()
	_test_determinism_same_seed()
	print("\n========== test_recipe_generator ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _new_rng(seed: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func _test_basic_fields() -> void:
	var rng := _new_rng()
	var r := RecipeGenerator.generate(rng, 1, 1)
	_assert(r != null, "generate non-null")
	_assert(r.display_name.length() >= 2, "display_name has chars")
	_assert(r.slot_kind != &"", "slot_kind set")
	_assert(r.path_affinity != &"", "path_affinity set")


func _test_id_unique() -> void:
	var rng := _new_rng(42)
	var ids: Dictionary = {}
	for i in 100:
		var r := RecipeGenerator.generate(rng, i % 3, i)
		ids[r.id] = true
	_assert(ids.size() == 100, "100 ids unique (got %d)" % ids.size())


func _test_quality_dist_sums_to_one() -> void:
	var rng := _new_rng(2)
	for i in 30:
		var r := RecipeGenerator.generate(rng, i % 3, i)
		var sum: float = 0.0
		for v in r.base_quality_distribution:
			sum += v
		_assert(absf(sum - 1.0) < 0.01, "quality dist sums to ~1.0 (got %.3f)" % sum)


func _test_path_matches_slot() -> void:
	var rng := _new_rng(3)
	for i in 30:
		var r := RecipeGenerator.generate(rng, 0, i)
		var expected_path: StringName = RecipeGenerator.SLOT_TO_PATH[r.slot_kind]
		_assert(r.path_affinity == expected_path, "path matches slot: %s → %s" % [r.slot_kind, expected_path])


func _test_materials_non_empty() -> void:
	var rng := _new_rng(4)
	for i in 30:
		var r := RecipeGenerator.generate(rng, i % 3, i)
		_assert(not r.required_materials.is_empty(), "required_materials non-empty")
		for k in r.required_materials:
			_assert(int(r.required_materials[k]) > 0, "material count > 0")


func _test_six_slots_reachable() -> void:
	var rng := _new_rng(5)
	var seen: Dictionary = {}
	for i in 200:
		var r := RecipeGenerator.generate(rng, 0, i)
		seen[r.slot_kind] = true
	for need in RecipeGenerator.SLOTS:
		_assert(seen.has(need), "slot %s reachable" % need)


func _test_diversity_60_samples() -> void:
	# 60 抽样 display_name 去重 ≥ 30（4 prefix × 6 mat × 6 slot = 144 max combos）
	var rng := _new_rng(6)
	var names: Dictionary = {}
	for i in 60:
		var r := RecipeGenerator.generate(rng, i % 3, i)
		names[r.display_name] = true
	_assert(names.size() >= 30, "diversity: 60 samples → ≥30 unique (got %d)" % names.size())


func _test_determinism_same_seed() -> void:
	var rng1 := _new_rng(99)
	var rng2 := _new_rng(99)
	var r1 := RecipeGenerator.generate(rng1, 1, 1)
	var r2 := RecipeGenerator.generate(rng2, 1, 1)
	_assert(r1.display_name == r2.display_name, "same seed → same name (%s)" % r1.display_name)
	_assert(r1.slot_kind == r2.slot_kind, "same seed → same slot")
