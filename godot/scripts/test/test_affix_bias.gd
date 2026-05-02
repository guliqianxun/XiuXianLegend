extends Node
## ForgeSystem._apply_bias_to_weight：投料 → 词缀权重偏向

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_compute_bias_sums_materials()
	_test_apply_bias_increases_path_weight()
	_test_apply_bias_no_match_unchanged()
	_test_weird_arcane_match()
	print("\n========== test_affix_bias ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)


func _test_compute_bias_sums_materials() -> void:
	var used := {&"zhu_sha": 2, &"huang_zhi": 1}
	var b := ForgeSystem._compute_affix_bias(used)
	# zhu_sha curse=3 + huang_zhi curse=1 = 4
	# zhu_sha talisman=2 + huang_zhi talisman=3 = 5
	_assert(b.get(&"curse", 0) == 4, "curse bias=4 (got %d)" % b.get(&"curse", 0))
	_assert(b.get(&"talisman", 0) == 5, "talisman bias=5 (got %d)" % b.get(&"talisman", 0))


func _test_apply_bias_increases_path_weight() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.path_filter = [&"curse"]
	var bias := {&"curse": 3}  # → ×(1 + 3*0.1) = ×1.3
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.3) < 0.001, "curse +30%% (got %.3f)" % w)


func _test_apply_bias_no_match_unchanged() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.path_filter = [&"sword"]
	var bias := {&"curse": 5}
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.0) < 0.001, "no path match → weight unchanged (got %.3f)" % w)


func _test_weird_arcane_match() -> void:
	var affix := AffixData.new()
	affix.weight = 1.0
	affix.min_tier = AffixData.Tier.ARCANE
	var bias := {&"_weird": 5}  # → ×(1 + 5*0.1) = ×1.5
	var w := ForgeSystem._apply_bias_to_weight(affix, bias)
	_assert(abs(w - 1.5) < 0.001, "ARCANE matches _weird (got %.3f)" % w)
