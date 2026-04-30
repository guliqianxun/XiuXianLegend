extends Node
## N2 烟测：核心数据 + ForgeScreen 等场景能加载 + 一次完整 forge_one 不崩。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_recipe_count()
	_test_forge_screen_loads()
	_test_timing_window_loads()
	_test_overlay_loads()
	_test_full_forge_cycle_via_api()
	_test_shop_loads_with_forge()
	print("\n========== playtest_n2_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_recipe_count() -> void:
	var ids: Array = DataRegistry.ids_of(&"recipe")
	_assert(ids.size() >= 3, "recipe count >= 3 (got %d)" % ids.size())


func _test_forge_screen_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/forge_screen.tscn")
	_assert(pkd != null, "forge_screen.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "forge_screen.tscn instantiable")
	inst.queue_free()


func _test_timing_window_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/timing_window.tscn")
	_assert(pkd != null, "timing_window.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "timing_window.tscn instantiable")
	inst.queue_free()


func _test_overlay_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/forge_result_overlay.tscn")
	_assert(pkd != null, "forge_result_overlay.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "forge_result_overlay.tscn instantiable")
	inst.queue_free()


func _test_full_forge_cycle_via_api() -> void:
	var recipe := DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	_assert(recipe != null, "iron_sword recipe loads")
	if recipe == null: return
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var ok_count := 0
	var backlash_count := 0
	for i in 100:
		var result := ForgeSystem.forge_one(recipe, [], 0.5, 1.0, 1700000000 + i, rng)
		if result.was_backlash:
			backlash_count += 1
		else:
			_assert(result.equipment != null, "non-backlash equipment present (iter %d)" % i)
			ok_count += 1
	_assert(ok_count + backlash_count == 100, "100 forges accounted")
	_assert(backlash_count <= 15, "backlash count <= 15 (got %d)" % backlash_count)


func _test_shop_loads_with_forge() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable (with forge)")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "shop.tscn instantiable (with forge)")
	inst.queue_free()
