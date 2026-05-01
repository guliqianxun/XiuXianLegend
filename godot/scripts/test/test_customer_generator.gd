extends Node
## CustomerGenerator：3 tier 命名 + 字段 + 多样性

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_regular_format()
	_test_rare_format()
	_test_weird_format()
	_test_id_unique()
	_test_payment_in_range()
	_test_traits_in_library()
	_test_only_weird_can_disguise()
	_test_diversity_100_samples()
	_test_determinism_same_seed()
	print("\n========== test_customer_generator ==========")
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


func _test_regular_format() -> void:
	var rng := _new_rng()
	var c := CustomerGenerator.generate(rng, 0, 1)
	_assert(c.tier == 0, "tier 0")
	_assert(c.display_name.length() >= 2, "name not empty")
	_assert(c.disguise_name.is_empty(), "regular no disguise")


func _test_rare_format() -> void:
	var rng := _new_rng(2)
	var c := CustomerGenerator.generate(rng, 1, 1)
	_assert(c.tier == 1, "tier 1")
	_assert(c.disguise_name.is_empty(), "rare no disguise")


func _test_weird_format() -> void:
	var rng := _new_rng(3)
	var c := CustomerGenerator.generate(rng, 2, 1)
	_assert(c.tier == 2, "tier 2")
	_assert(c.display_name.ends_with("客"), "weird name ends with 客 (got %s)" % c.display_name)


func _test_id_unique() -> void:
	# 100 次生成 id 全唯一
	var rng := _new_rng(4)
	var ids: Dictionary = {}
	for i in 100:
		var c := CustomerGenerator.generate(rng, i % 3, i)
		ids[c.id] = true
	_assert(ids.size() == 100, "100 ids unique (got %d)" % ids.size())


func _test_payment_in_range() -> void:
	var rng := _new_rng(5)
	for tier in 3:
		for i in 20:
			var c := CustomerGenerator.generate(rng, tier, i)
			_assert(c.base_payment >= CustomerGenerator.PAYMENT_MIN[tier],
				"tier %d payment >= min" % tier)
			_assert(c.base_payment <= CustomerGenerator.PAYMENT_MAX[tier],
				"tier %d payment <= max" % tier)


func _test_traits_in_library() -> void:
	var rng := _new_rng(6)
	for i in 50:
		var c := CustomerGenerator.generate(rng, i % 3, i)
		for t in c.traits:
			_assert(ShopRules.TRAIT_LIBRARY.has(t), "trait %s in library" % t)


func _test_only_weird_can_disguise() -> void:
	var rng := _new_rng(7)
	for i in 30:
		var c := CustomerGenerator.generate(rng, 0, i)
		_assert(c.disguise_name.is_empty(), "regular i=%d no disguise" % i)
	for i in 30:
		var c := CustomerGenerator.generate(rng, 1, i)
		_assert(c.disguise_name.is_empty(), "rare i=%d no disguise" % i)


func _test_diversity_100_samples() -> void:
	# 100 抽样 display_name 去重 ≥ 70
	var rng := _new_rng(42)
	var names: Dictionary = {}
	for i in 100:
		var c := CustomerGenerator.generate(rng, i % 3, i)
		names[c.display_name] = true
	_assert(names.size() >= 70, "diversity: 100 samples → ≥70 unique names (got %d)" % names.size())


func _test_determinism_same_seed() -> void:
	var rng1 := _new_rng(99)
	var rng2 := _new_rng(99)
	var c1 := CustomerGenerator.generate(rng1, 1, 100)
	var c2 := CustomerGenerator.generate(rng2, 1, 100)
	_assert(c1.display_name == c2.display_name, "same seed → same name")
	_assert(c1.base_payment == c2.base_payment, "same seed → same payment")
