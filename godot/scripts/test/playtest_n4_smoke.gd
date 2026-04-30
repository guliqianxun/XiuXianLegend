extends Node
## N4 烟测：customer UI 加载 + 100 次 spawn-lend-resolve 不崩

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_3_customers()
	_test_arrival_panel_loads()
	_test_lend_dialog_loads()
	_test_return_notice_loads()
	_test_full_cycle_100x()
	_test_shop_loads_with_customers()
	print("\n========== playtest_n4_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_3_customers() -> void:
	var ids: Array = DataRegistry.ids_of(&"customer")
	_assert(ids.size() >= 3, "customer >= 3 (got %d)" % ids.size())


func _test_arrival_panel_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	_assert(pkd != null, "arrival_panel loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_lend_dialog_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/lend_dialog.tscn")
	_assert(pkd != null, "lend_dialog loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_return_notice_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/return_notice.tscn")
	_assert(pkd != null, "return_notice loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_full_cycle_100x() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var unlent_count := 0
	for i in 100:
		EncounterState.reset()
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i * 600)
		if req == null: continue
		var g := GearInstance.new()
		g.base_id = &"iron_sword"
		g.rarity = 0
		g.status = GearInstance.Status.IN_SHOP
		EncounterState.lend(req.customer_id, g, 1700000000 + i * 600, req.expected_duration_sec)
		if g.status == GearInstance.Status.LENT:
			pass  # ok
		var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
		var outcome := ReturnResolver.roll_outcome(c.tier, rng)
		EncounterState.resolve_return(g, outcome, 1700000000 + i * 600 + 600)
		if g.status != GearInstance.Status.LENT:
			unlent_count += 1
	_assert(unlent_count == 100, "100 cycles all unlent (got %d)" % unlent_count)


func _test_shop_loads_with_customers() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable (with customer UIs)")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()
