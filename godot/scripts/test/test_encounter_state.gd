extends Node
## EncounterState lend → return → status 流转 + 序列化

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_lend_marks_status_lent()
	_test_return_ok_status_in_shop_with_history()
	_test_return_not_returned_status()
	_test_serialize_only_pending_lends()
	print("\n========== test_encounter_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_gear() -> GearInstance:
	var g := GearInstance.new()
	g.base_id = &"iron_sword"
	g.rarity = 1
	g.status = GearInstance.Status.IN_SHOP
	return g


func _test_lend_marks_status_lent() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	_assert(g.status == GearInstance.Status.LENT, "gear.status = LENT")
	_assert(g.history.size() >= 1, "history has lent entry")
	_assert(EncounterState.lent_count() == 1, "1 lent")


func _test_return_ok_status_in_shop_with_history() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	EncounterState.resolve_return(g, ReturnResolver.Outcome.OK_RETURN, 1700000700)
	_assert(g.status == GearInstance.Status.IN_SHOP, "status back to IN_SHOP")
	_assert(g.history.size() >= 2, "history has 2+ entries (lent + returned)")
	_assert(EncounterState.lent_count() == 0, "0 lent after return")


func _test_return_not_returned_status() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	EncounterState.resolve_return(g, ReturnResolver.Outcome.NOT_RETURNED, 1700000700)
	_assert(g.status == GearInstance.Status.NOT_RETURNED, "status = NOT_RETURNED")
	_assert(EncounterState.lent_count() == 0, "0 lent after not_returned (cleared from pending)")


func _test_serialize_only_pending_lends() -> void:
	EncounterState.reset()
	var g := _make_gear()
	EncounterState.lend(&"su_jia_niangzi", g, 1700000000, 600)
	var d := EncounterState.to_dict()
	_assert(d.has("pending_lends"), "to_dict has pending_lends")
	var pl: Array = d.get("pending_lends", [])
	_assert(pl.size() == 1, "1 pending lend serialized")
