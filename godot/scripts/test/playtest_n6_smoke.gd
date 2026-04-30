extends Node
## N6 烟测：盲盒身份链路端到端

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_disguised_customer_exists()
	_test_spawner_yields_disguised_when_weird()
	_test_panel_loads_with_inspect_btn()
	_test_shop_loads()
	print("\n========== playtest_n6_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_disguised_customer_exists() -> void:
	var found_disguised := false
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null and not c.disguise_name.is_empty():
			found_disguised = true
			break
	_assert(found_disguised, "at least 1 customer has disguise data")


func _test_spawner_yields_disguised_when_weird() -> void:
	# 强抽 100 次，应至少 1 次出 disguised customer (req.unmasked=false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var disguised := 0
	for i in 100:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i * 60)
		if req == null: continue
		if not req.unmasked:
			disguised += 1
	_assert(disguised > 0, "100 spawns yielded %d disguised (>0)" % disguised)


func _test_panel_loads_with_inspect_btn() -> void:
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	_assert(pkd != null, "customer_arrival_panel.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	_assert(inst.has_node("Frame/Layout/Buttons/InspectBtn"), "panel has InspectBtn")
	inst.queue_free()


func _test_shop_loads() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()
