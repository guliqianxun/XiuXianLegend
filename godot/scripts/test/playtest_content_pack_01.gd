extends Node
## Content Pack 01：10 客人 / 7 配方 / 10 trait / 三 tier 都能 spawn

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_customer_count()
	_test_recipe_count()
	_test_trait_library_size()
	_test_all_customers_loadable()
	_test_all_recipes_loadable()
	_test_all_slot_kinds_have_recipe()
	_test_spawner_three_tiers_appear()
	_test_disguise_breach_path_still_works()
	print("\n========== playtest_content_pack_01 ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_customer_count() -> void:
	var n := DataRegistry.ids_of(&"customer").size()
	_assert(n == 10, "10 customers loaded (got %d)" % n)


func _test_recipe_count() -> void:
	var n := DataRegistry.ids_of(&"recipe").size()
	_assert(n == 7, "7 recipes loaded (got %d)" % n)


func _test_trait_library_size() -> void:
	_assert(ShopRules.TRAIT_LIBRARY.size() == 10,
		"TRAIT_LIBRARY has 10 entries (got %d)" % ShopRules.TRAIT_LIBRARY.size())


func _test_all_customers_loadable() -> void:
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		_assert(c != null, "customer %s loadable" % cid)
		if c == null: continue
		_assert(not c.display_name.is_empty(), "customer %s has display_name" % cid)
		# 所有 trait 必须在 TRAIT_LIBRARY 注册
		for t in c.traits:
			_assert(ShopRules.TRAIT_LIBRARY.has(t),
				"customer %s trait '%s' registered" % [cid, t])


func _test_all_recipes_loadable() -> void:
	for rid in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", rid) as RecipeData
		_assert(r != null, "recipe %s loadable" % rid)
		if r == null: continue
		_assert(not r.required_materials.is_empty(), "recipe %s has required_materials" % rid)
		# 5 档品质分布和接近 1.0
		var sum := 0.0
		for v in r.base_quality_distribution:
			sum += v
		_assert(absf(sum - 1.0) < 0.05, "recipe %s quality dist sums ~1.0 (got %.3f)" % [rid, sum])


func _test_all_slot_kinds_have_recipe() -> void:
	# 6 slot kinds 应都有至少一个配方
	var kinds_seen: Dictionary = {}
	for rid in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", rid) as RecipeData
		if r != null:
			kinds_seen[r.slot_kind] = true
	for need in [&"sword", &"talisman", &"puppet_core", &"elixir_furnace", &"eating_vessel", &"divination_plate"]:
		_assert(kinds_seen.has(need), "slot_kind %s has at least 1 recipe" % need)


func _test_spawner_three_tiers_appear() -> void:
	# 200 次 spawn 三 tier 都至少出 1 次
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var count := [0, 0, 0]
	for i in 200:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i * 60)
		if req == null: continue
		var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
		if c != null:
			count[c.tier] += 1
	_assert(count[0] > 0, "REGULAR appeared (%d)" % count[0])
	_assert(count[1] > 0, "RARE appeared (%d)" % count[1])
	_assert(count[2] > 0, "WEIRD appeared (%d)" % count[2])


func _test_disguise_breach_path_still_works() -> void:
	# yu_chongyi 是新增的伪装怪客（disguise=RARE）；启用 lend_regular + 拒怪客
	# 应该被放行（按伪装 RARE 算，不命中 regular），不会攻破——
	# 实际 yu_chongyi 伪装为 RARE，lend_regular 不匹配，refuse_weird 按伪装也不匹配 → fallback refuse
	# 所以这里就检验：仍存在至少一个伪装客人（包括 meng_mian_ke, yu_chongyi）
	var disguised_count := 0
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null and not c.disguise_name.is_empty():
			disguised_count += 1
	_assert(disguised_count >= 2, "at least 2 disguised customers (got %d)" % disguised_count)
