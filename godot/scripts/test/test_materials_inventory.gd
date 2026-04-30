extends Node
## GameState materials 栏增删查 + 序列化 + smith_hand_today。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_default_state()
	_test_add_consume()
	_test_consume_insufficient()
	_test_signal_emits()
	_test_smith_hand_default()
	_test_serialize_roundtrip()
	print("\n========== test_materials_inventory ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _reset() -> void:
	GameState.materials.clear()
	GameState.smith_hand_today = 1.0


func _test_default_state() -> void:
	_reset()
	_assert(GameState.materials is Dictionary, "materials is Dictionary")
	_assert(GameState.material_count(&"iron") == 0, "missing material -> 0")


func _test_add_consume() -> void:
	_reset()
	GameState.add_material(&"iron", 5)
	_assert(GameState.material_count(&"iron") == 5, "iron=5 after add")
	GameState.add_material(&"iron", 3)
	_assert(GameState.material_count(&"iron") == 8, "iron=8 after add 3")
	var ok := GameState.consume_material(&"iron", 6)
	_assert(ok, "consume 6 returns true")
	_assert(GameState.material_count(&"iron") == 2, "iron=2 after consume 6")


func _test_consume_insufficient() -> void:
	_reset()
	GameState.add_material(&"jin", 3)
	var ok := GameState.consume_material(&"jin", 5)
	_assert(not ok, "consume 5 of 3 returns false")
	_assert(GameState.material_count(&"jin") == 3, "jin unchanged on failed consume")


func _test_signal_emits() -> void:
	_reset()
	var emitted: Array = []
	var cb := func(mid: StringName, val: int) -> void:
		emitted.append({"mid": mid, "val": val})
	EventBus.materials_changed.connect(cb)
	GameState.add_material(&"zhusha", 4)
	GameState.consume_material(&"zhusha", 1)
	_assert(emitted.size() == 2, "2 signals emitted")
	_assert(emitted[0]["mid"] == &"zhusha" and emitted[0]["val"] == 4, "first emit val=4")
	_assert(emitted[1]["mid"] == &"zhusha" and emitted[1]["val"] == 3, "second emit val=3")
	EventBus.materials_changed.disconnect(cb)


func _test_smith_hand_default() -> void:
	_reset()
	_assert(abs(GameState.smith_hand_today - 1.0) < 0.001, "smith_hand_today defaults to 1.0")


func _test_serialize_roundtrip() -> void:
	_reset()
	GameState.add_material(&"iron", 7)
	GameState.add_material(&"jin", 12)
	GameState.smith_hand_today = 1.03
	var d: Dictionary = GameState.to_dict()
	_reset()
	GameState.from_dict(d)
	_assert(GameState.material_count(&"iron") == 7, "iron roundtrip")
	_assert(GameState.material_count(&"jin") == 12, "jin roundtrip")
	_assert(abs(GameState.smith_hand_today - 1.03) < 0.001, "smith_hand_today roundtrip")
