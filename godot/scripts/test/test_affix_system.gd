extends Node
## 词缀系统：26 主题词缀加载 + roll + 集成 forge + 显示

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_thematic_affixes_loaded()
	_test_roll_main_affix_path_filter()
	_test_roll_main_affix_quality_gate()
	_test_arcane_only_high_quality()
	_test_forge_one_assigns_affix()
	_test_display_full_name_includes_affix()
	_test_fingerprint_diversifies_with_affix()
	_test_diversity_8_kinds()
	print("\n========== test_affix_system ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_thematic_affixes_loaded() -> void:
	# 主题词缀 = hooks 为空的 affix
	var thematic: int = 0
	for aid in DataRegistry.ids_of(&"affix"):
		var a := DataRegistry.get_resource(&"affix", aid) as AffixData
		if a != null and a.hooks.is_empty():
			thematic += 1
	_assert(thematic == 26, "26 thematic affixes loaded (got %d)" % thematic)


func _test_roll_main_affix_path_filter() -> void:
	# 100 次 roll sword 装备，结果都应是通用 OR sword path
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 100:
		var a := ForgeSystem.roll_main_affix(&"sword", 2, rng)
		if a == null: continue
		var ok: bool = a.path_filter.is_empty() or a.path_filter.has(&"sword")
		_assert(ok, "i=%d affix %s path_filter ok" % [i, a.id])


func _test_roll_main_affix_quality_gate() -> void:
	# Q0 凡品：只能拿 COMMON tier (即通用 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var a := ForgeSystem.roll_main_affix(&"sword", 0, rng)
		if a == null: continue
		_assert(int(a.min_tier) == AffixData.Tier.COMMON,
			"Q0 only common tier (got %s tier=%d)" % [a.id, a.min_tier])


func _test_arcane_only_high_quality() -> void:
	# Q0..2 应永远不出 ARCANE
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 200:
		for q in [0, 1, 2]:
			var a := ForgeSystem.roll_main_affix(&"sword", q, rng)
			if a == null: continue
			_assert(int(a.min_tier) != AffixData.Tier.ARCANE,
				"Q%d should never roll ARCANE (got %s)" % [q, a.id])


func _test_forge_one_assigns_affix() -> void:
	var recipe: RecipeData = DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	if recipe == null:
		_bad("iron_sword missing")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var with_affix := 0
	for i in 50:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = i
		var result := ForgeSystem.forge_one(recipe, [], 0.0, 1.0, 0, rng2)
		if result.was_backlash: continue
		if not result.equipment.affix_ids.is_empty():
			with_affix += 1
	_assert(with_affix >= 30, "forge_one assigns affix to ≥60%% (got %d/50)" % with_affix)


func _test_display_full_name_includes_affix() -> void:
	var g := GearInstance.new()
	g.base_id = &"iron_sword"
	g.rarity = 1
	g.affix_ids = [&"feng_li"]
	g.affix_values = [5.0]
	var name := g.display_full_name()
	_assert(name.contains("锋利"), "display_full_name includes affix '锋利' (got %s)" % name)


func _test_fingerprint_diversifies_with_affix() -> void:
	# 同 recipe + 同 quality 但不同 affix → 不同 fingerprint
	var g1 := GearInstance.new(); g1.base_id = &"iron_sword"; g1.rarity = 2
	g1.affix_ids = [&"feng_li"]; g1.affix_values = [3.0]
	var g2 := GearInstance.new(); g2.base_id = &"iron_sword"; g2.rarity = 2
	g2.affix_ids = [&"chen_wen"]; g2.affix_values = [3.0]
	_assert(WeirdCodex.fingerprint_of(g1) != WeirdCodex.fingerprint_of(g2),
		"different affix → different fingerprint")


func _test_diversity_8_kinds() -> void:
	# 100 次 roll → 至少 8 种不同 affix id
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen: Dictionary = {}
	for i in 100:
		for path in [&"sword", &"curse", &"alchemy", &"eat", &"divination", &"puppet"]:
			var a := ForgeSystem.roll_main_affix(path, i % 5, rng)
			if a != null:
				seen[a.id] = true
	_assert(seen.size() >= 8, "diversity ≥8 kinds (got %d)" % seen.size())
