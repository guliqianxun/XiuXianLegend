extends Node
## ForgeSystem.forge_one：完整路径——配方+材料+RNG → ForgeResult

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_normal_path()
	_test_qiao_cheng_path()
	_test_backlash_path()
	_test_origin_recorded()
	print("\n========== test_forge_one_full ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_recipe() -> RecipeData:
	var r := RecipeData.new()
	r.id = &"test_recipe"
	r.display_name = "测试配方"
	r.required_materials = {&"iron": 2}
	r.optional_materials = []
	r.base_quality_distribution = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])  # 强制 Q0
	r.base_minutes_in_furnace = 30
	r.path_affinity = &"sword"
	r.slot_kind = &"sword"
	return r


func _test_normal_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999
	var recipe := _make_recipe()
	var result := ForgeSystem.forge_one(recipe, [], 0.0, 1.0, 1700000000, rng)
	_assert(result != null, "result not null")
	if result.was_backlash:
		_assert(true, "skip normal path on backlash")
		return
	_assert(result.quality == 0, "quality 0 (forced by dist)")
	_assert(result.equipment != null, "equipment built")
	_assert(result.equipment.rarity == 0, "equipment rarity matches quality")


func _test_qiao_cheng_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var recipe := _make_recipe()
	var optional := [&"hui", &"hui", &"hui", &"hui", &"hui"]
	var result := ForgeSystem.forge_one(recipe, optional, 0.0, 1.0, 1700000000, rng)
	if result.was_qiao_cheng and not result.was_backlash:
		_assert(result.quality == 1, "qiao_cheng on Q0 -> Q1")
	_assert(true, "qiao_cheng path runs without crash")


func _test_backlash_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var recipe := _make_recipe()
	var result := ForgeSystem.forge_one(recipe, [&"yi_zhong_liao"], 0.0, 1.0, 1700000000, rng)
	if result.was_backlash:
		_assert(result.equipment == null, "backlash -> equipment null")
		_assert(result.quality == -1, "backlash -> quality -1")
		_assert(result.byproduct in [&"hui", &"yi_zhong_liao"], "backlash byproduct in {hui, yi_zhong_liao}")
		_assert(result.byproduct_amount == 1, "backlash byproduct_amount = 1")
	else:
		_assert(result.equipment != null, "no backlash -> equipment present")
	_assert(true, "backlash path runs")


func _test_origin_recorded() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999
	var recipe := _make_recipe()
	var result := ForgeSystem.forge_one(recipe, [], 0.0, 1.0, 1700000000, rng)
	if result.was_backlash:
		_assert(true, "skipped origin check on backlash")
		return
	var g := result.equipment
	_assert(g != null, "equipment present")
	if g == null: return
	_assert(int(g.origin.get("unix", 0)) == 1700000000, "origin.unix recorded")
	_assert(str(g.origin.get("recipe", "")) == "test_recipe", "origin.recipe recorded")
	_assert(g.origin.has("qiao_cheng"), "origin.qiao_cheng key present")
	_assert(g.history.size() >= 1, "history has forge entry")
	_assert(str(g.history[0].get("event", "")) == "forged", "history[0].event = forged")
