extends Node
## N3 烟测：CodexScreen/StarNode/StarDetailPanel 加载 + 100 次 forge → place 不崩

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_qing_long_loads()
	_test_28_sus_loaded()
	_test_codex_screen_loads()
	_test_star_node_loads()
	_test_detail_panel_loads()
	_test_full_forge_to_codex_cycle()
	_test_shop_loads_with_codex()
	print("\n========== playtest_n3_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_qing_long_loads() -> void:
	var g := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	_assert(g != null, "qing_long gupu loads")
	if g == null: return
	_assert(g.stars.size() == 28, "qing_long has 28 stars")


func _test_28_sus_loaded() -> void:
	var ids: Array = DataRegistry.ids_of(&"su")
	_assert(ids.size() == 28, "DataRegistry has 28 SuData (got %d)" % ids.size())


func _test_codex_screen_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/codex_screen.tscn")
	_assert(pkd != null, "codex_screen.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "codex_screen.tscn instantiable")
	inst.queue_free()


func _test_star_node_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/star_node.tscn")
	_assert(pkd != null, "star_node.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "star_node.tscn instantiable")
	inst.queue_free()


func _test_detail_panel_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/star_detail_panel.tscn")
	_assert(pkd != null, "star_detail_panel.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "star_detail_panel.tscn instantiable")
	inst.queue_free()


func _test_full_forge_to_codex_cycle() -> void:
	var recipe := DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	_assert(recipe != null, "iron_sword recipe loads")
	if recipe == null: return
	CodexState.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	var placed_count := 0
	for i in 100:
		var result := ForgeSystem.forge_one(recipe, [], 0.5, 1.0, 1700000000 + i, rng)
		if not result.was_backlash and result.equipment != null:
			var su_id := CodexState.place_equipment(result.equipment, recipe.slot_kind)
			if su_id != &"":
				placed_count += 1
	_assert(placed_count > 50, "place_count > 50 (got %d)" % placed_count)
	var nonempty: int = 0
	for ids in DataRegistry.ids_of(&"su"):
		if CodexState.equipments_at_star(ids).size() > 0:
			nonempty += 1
	_assert(nonempty >= 1, "at least 1 star has equipment (got %d)" % nonempty)


func _test_shop_loads_with_codex() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable (with codex)")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "shop.tscn instantiable (with codex)")
	inst.queue_free()
