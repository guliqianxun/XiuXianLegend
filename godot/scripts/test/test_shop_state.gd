extends Node
## ShopState：4 区域等级、铺规槽、序列化。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_default_levels()
	_test_upgrade_emits_signal()
	_test_max_level_clamp()
	_test_rule_slots_capacity()
	_test_serialize_roundtrip()
	print("\n========== test_shop_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_default_levels() -> void:
	ShopState.reset()
	_assert(ShopState.area_level(&"furnace") == 1, "furnace defaults to Lv.1")
	_assert(ShopState.area_level(&"counter") == 1, "counter defaults to Lv.1")
	_assert(ShopState.area_level(&"loft") == 1, "loft defaults to Lv.1")
	_assert(ShopState.area_level(&"yard") == 1, "yard defaults to Lv.1")


func _test_upgrade_emits_signal() -> void:
	ShopState.reset()
	var emitted: Array = []
	var cb := func(area: StringName, lvl: int) -> void:
		emitted.append({"area": area, "lvl": lvl})
	EventBus.shop_upgraded.connect(cb)
	var ok := ShopState.upgrade_area(&"furnace")
	_assert(ok, "upgrade_area returns true")
	_assert(ShopState.area_level(&"furnace") == 2, "furnace now Lv.2")
	_assert(emitted.size() == 1, "shop_upgraded emitted")
	_assert(emitted[0]["area"] == &"furnace" and emitted[0]["lvl"] == 2, "signal payload correct")
	EventBus.shop_upgraded.disconnect(cb)


func _test_max_level_clamp() -> void:
	ShopState.reset()
	# 升 3 次到 Lv.3 应该都成功；第 4 次应失败（封顶 Lv.3）
	# 当前实现：reset 后是 Lv.1，所以升 2 次到 Lv.3
	_assert(ShopState.upgrade_area(&"furnace"), "Lv1->Lv2 ok")
	_assert(ShopState.upgrade_area(&"furnace"), "Lv2->Lv3 ok")
	_assert(not ShopState.upgrade_area(&"furnace"), "Lv3->Lv4 rejected")
	_assert(ShopState.area_level(&"furnace") == 3, "stays at Lv.3")


func _test_rule_slots_capacity() -> void:
	ShopState.reset()
	# 默认 3 槽（柜台 Lv.1），升级柜台到 Lv.2 应给到 ?+ slots
	_assert(ShopState.rule_slot_count() == 3, "default 3 rule slots")
	ShopState.upgrade_area(&"counter")
	_assert(ShopState.rule_slot_count() == 5, "counter Lv.2 => 5 slots")
	ShopState.upgrade_area(&"counter")
	_assert(ShopState.rule_slot_count() == 8, "counter Lv.3 => 8 slots")


func _test_serialize_roundtrip() -> void:
	ShopState.reset()
	ShopState.upgrade_area(&"furnace")
	ShopState.upgrade_area(&"loft")
	var d: Dictionary = ShopState.to_dict()
	ShopState.reset()
	ShopState.from_dict(d)
	_assert(ShopState.area_level(&"furnace") == 2, "furnace lvl 2 restored")
	_assert(ShopState.area_level(&"loft") == 2, "loft lvl 2 restored")
	_assert(ShopState.area_level(&"counter") == 1, "counter still 1")
