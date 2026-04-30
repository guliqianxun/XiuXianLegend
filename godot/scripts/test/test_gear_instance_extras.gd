extends Node
## GearInstance 扩展字段：origin / history / star_position / status + 序列化对称。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_default_extras()
	_test_status_enum()
	_test_history_append()
	_test_serialize_roundtrip()
	print("\n========== test_gear_instance_extras ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_default_extras() -> void:
	var g := GearInstance.new()
	_assert(g.origin is Dictionary, "origin is Dictionary")
	_assert(g.origin.is_empty(), "origin defaults empty")
	_assert(g.history is Array, "history is Array")
	_assert(g.history.is_empty(), "history defaults empty")
	_assert(g.star_position is Dictionary, "star_position is Dictionary")
	_assert(g.status == GearInstance.Status.IN_SHOP, "status defaults IN_SHOP=0")


func _test_status_enum() -> void:
	_assert(GearInstance.Status.IN_SHOP == 0, "IN_SHOP=0")
	_assert(GearInstance.Status.LENT == 1, "LENT=1")
	_assert(GearInstance.Status.NOT_RETURNED == 2, "NOT_RETURNED=2")
	_assert(GearInstance.Status.DAMAGED == 3, "DAMAGED=3")
	_assert(GearInstance.Status.MUTATED == 4, "MUTATED=4")


func _test_history_append() -> void:
	var g := GearInstance.new()
	g.history.append({"unix": 1700000000, "event": "forged", "detail": "巧成"})
	g.history.append({"unix": 1700001000, "event": "lent", "detail": "苏家娘子"})
	_assert(g.history.size() == 2, "history append works")
	_assert(g.history[0]["event"] == "forged", "first entry preserved")


func _test_serialize_roundtrip() -> void:
	var g := GearInstance.new()
	g.base_id = &"rusty_sword"
	g.affix_ids = [&"atk_flat"]
	g.affix_values = [5.0]
	g.rarity = 2
	g.seed = 42
	g.origin = {"unix": 1700000000, "recipe": "iron_sword", "qiao_cheng": true}
	g.history = [{"unix": 1700001000, "event": "forged", "detail": "巧成"}]
	g.star_position = {"gupu": "qing_long", "su": "jiao_su"}
	g.status = GearInstance.Status.LENT

	var d: Dictionary = g.to_dict()
	var g2 := GearInstance.from_dict(d)

	_assert(g2.base_id == &"rusty_sword", "base_id roundtrip")
	_assert(g2.rarity == 2, "rarity roundtrip")
	_assert(g2.seed == 42, "seed roundtrip")
	_assert(int(g2.origin.get("unix", 0)) == 1700000000, "origin.unix roundtrip")
	_assert(str(g2.origin.get("recipe", "")) == "iron_sword", "origin.recipe roundtrip")
	_assert(g2.history.size() == 1, "history len roundtrip")
	_assert(str(g2.history[0]["event"]) == "forged", "history[0].event roundtrip")
	_assert(str(g2.star_position.get("gupu", "")) == "qing_long", "star_position roundtrip")
	_assert(g2.status == GearInstance.Status.LENT, "status roundtrip")
