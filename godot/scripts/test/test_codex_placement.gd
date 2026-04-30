extends Node
## CodexPlacement.find_su_for_equipment：确定性入谱公式

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_iron_sword_q0_lands()
	_test_deterministic()
	_test_no_match_returns_empty()
	_test_quality_band_distinguishes()
	print("\n========== test_codex_placement ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_iron_sword_q0_lands() -> void:
	var gupu := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	_assert(gupu != null, "qing_long loads")
	if gupu == null: return
	var su_id := CodexPlacement.find_su_for_equipment(&"sword", 0, gupu)
	_assert(su_id == &"jiao", "sword Q0 -> jiao (got %s)" % su_id)


func _test_deterministic() -> void:
	var gupu := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	if gupu == null: return
	var a := CodexPlacement.find_su_for_equipment(&"talisman", 1, gupu)
	var b := CodexPlacement.find_su_for_equipment(&"talisman", 1, gupu)
	_assert(a == b, "deterministic: %s == %s" % [a, b])


func _test_no_match_returns_empty() -> void:
	var gupu := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	if gupu == null: return
	var su := CodexPlacement.find_su_for_equipment(&"unknown_slot", 0, gupu)
	_assert(su == &"", "unknown slot -> empty (got %s)" % su)


func _test_quality_band_distinguishes() -> void:
	var gupu := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	if gupu == null: return
	var q0 := CodexPlacement.find_su_for_equipment(&"sword", 0, gupu)
	var q1 := CodexPlacement.find_su_for_equipment(&"sword", 1, gupu)
	var q4 := CodexPlacement.find_su_for_equipment(&"sword", 4, gupu)
	_assert(q0 != q1, "Q0 and Q1 land different stars (%s vs %s)" % [q0, q1])
	_assert(q1 != q4, "Q1 and Q4 land different stars (%s vs %s)" % [q1, q4])
