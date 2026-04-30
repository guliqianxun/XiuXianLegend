extends Node
## DataRegistry 能扫到 3 个开局配方 .tres，并加载为 RecipeData 实例。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_three_recipes_indexed()
	_test_iron_sword_loads()
	_test_spirit_talisman_loads()
	_test_bone_blade_loads()
	print("\n========== test_recipe_data_loads ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_three_recipes_indexed() -> void:
	var ids: Array = DataRegistry.ids_of(&"recipe")
	_assert(ids.size() >= 3, "recipe index has >= 3 entries (got %d)" % ids.size())
	_assert(&"iron_sword" in ids, "iron_sword in index")
	_assert(&"spirit_talisman" in ids, "spirit_talisman in index")
	_assert(&"bone_blade" in ids, "bone_blade in index")


func _test_iron_sword_loads() -> void:
	var r := DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	_assert(r != null, "iron_sword loads")
	if r == null: return
	_assert(r.id == &"iron_sword", "iron_sword.id correct")
	_assert(r.display_name == "凡铁剑", "iron_sword.display_name 凡铁剑")
	_assert(r.path_affinity == &"sword", "iron_sword path=sword")
	_assert(r.required_materials.has(&"iron"), "iron_sword requires iron")
	_assert(r.required_materials.has(&"jin"), "iron_sword requires jin")
	_assert(int(r.required_materials.get(&"iron", 0)) == 2, "iron_sword needs 2 iron")
	_assert(int(r.required_materials.get(&"jin", 0)) == 4, "iron_sword needs 4 jin")
	var sum: float = 0.0
	for x in r.base_quality_distribution:
		sum += x
	_assert(abs(sum - 1.0) < 0.001, "iron_sword distribution sums to 1.0")


func _test_spirit_talisman_loads() -> void:
	var r := DataRegistry.get_resource(&"recipe", &"spirit_talisman") as RecipeData
	_assert(r != null, "spirit_talisman loads")
	if r == null: return
	_assert(r.path_affinity == &"curse", "spirit_talisman path=curse")
	_assert(r.required_materials.has(&"zhusha"), "spirit_talisman requires zhusha")


func _test_bone_blade_loads() -> void:
	var r := DataRegistry.get_resource(&"recipe", &"bone_blade") as RecipeData
	_assert(r != null, "bone_blade loads")
	if r == null: return
	_assert(r.path_affinity == &"eat", "bone_blade path=eat")
	_assert(r.required_materials.has(&"bone"), "bone_blade requires bone")
