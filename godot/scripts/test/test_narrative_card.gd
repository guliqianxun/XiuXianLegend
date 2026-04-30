extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_basic()
	_test_trigger_enum()
	print("\n========== test_narrative_card ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_basic() -> void:
	var n := NarrativeCard.new()
	n.id = &"first_weird_customer"
	n.trigger = NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST
	n.body = "丑时三刻，门外起雾。蒙面客以三百灵石求借兵器，他没踩出脚印。"
	_assert(n.id == &"first_weird_customer", "id set")
	_assert(n.trigger == NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST, "trigger set")
	_assert(n.body.length() > 0, "body has content")


func _test_trigger_enum() -> void:
	_assert(NarrativeCard.Trigger.CUSTOMER_FIRST == 0, "CUSTOMER_FIRST=0")
	_assert(NarrativeCard.Trigger.WEIRD_CUSTOMER_FIRST == 1, "WEIRD_CUSTOMER_FIRST=1")
	_assert(NarrativeCard.Trigger.BACKLASH == 2, "BACKLASH=2")
	_assert(NarrativeCard.Trigger.QIAO_CHENG == 3, "QIAO_CHENG=3")
	_assert(NarrativeCard.Trigger.RESONANCE == 4, "RESONANCE=4")
	_assert(NarrativeCard.Trigger.NOT_RETURNED == 5, "NOT_RETURNED=5")
	_assert(NarrativeCard.Trigger.OLD_IRON_MUTTER == 6, "OLD_IRON_MUTTER=6")
	_assert(NarrativeCard.Trigger.IDENTITY_FRAGMENT == 7, "IDENTITY_FRAGMENT=7")
