extends Node
## EventLog：add / recent / 序列化 / ring buffer + UI 加载

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_add_entry_emits_signal()
	_test_recent_returns_reverse_order()
	_test_ring_buffer_caps_at_max()
	_test_color_of_lookup()
	_test_serialization_roundtrip()
	_test_panel_loadable()
	_test_screen_loadable()
	_test_save_v10()
	print("\n========== test_event_log ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_add_entry_emits_signal() -> void:
	EventLog.clear()
	var sink := {"got": 0}
	var cb := func(_e: Dictionary) -> void: sink["got"] += 1
	EventLog.log_added.connect(cb)
	EventLog.add_entry(&"test", "甲", &"good")
	EventLog.add_entry(&"test", "乙")
	_assert(sink["got"] == 2, "2 signals emitted")
	_assert(EventLog.entries.size() == 2, "2 entries")
	EventLog.log_added.disconnect(cb)


func _test_recent_returns_reverse_order() -> void:
	EventLog.clear()
	EventLog.add_entry(&"k", "甲")
	EventLog.add_entry(&"k", "乙")
	EventLog.add_entry(&"k", "丙")
	var r := EventLog.recent(2)
	_assert(r.size() == 2, "2 entries")
	_assert(String(r[0]["text"]) == "丙", "first = newest 丙")
	_assert(String(r[1]["text"]) == "乙", "second = 乙")


func _test_ring_buffer_caps_at_max() -> void:
	EventLog.clear()
	for i in 60:
		EventLog.add_entry(&"k", "x %d" % i)
	_assert(EventLog.entries.size() == EventLog.MAX_ENTRIES,
		"capped at %d (got %d)" % [EventLog.MAX_ENTRIES, EventLog.entries.size()])
	# 最新条目应是 x 59
	var last: Dictionary = EventLog.entries[-1]
	_assert(String(last["text"]) == "x 59", "newest preserved")


func _test_color_of_lookup() -> void:
	_assert(EventLog.color_of(&"good") != EventLog.color_of(&"bad"), "good != bad")
	_assert(EventLog.color_of(&"unknown") == EventLog.COLOR_HINTS[&"normal"],
		"unknown falls back to normal")


func _test_serialization_roundtrip() -> void:
	EventLog.clear()
	EventLog.add_entry(&"a", "首条", &"good")
	EventLog.add_entry(&"b", "次条", &"bad")
	var d := EventLog.to_dict()
	EventLog.clear()
	EventLog.from_dict(d)
	_assert(EventLog.entries.size() == 2, "2 entries roundtrip")
	_assert(String(EventLog.entries[0]["text"]) == "首条", "first roundtrip")
	_assert(StringName(EventLog.entries[1]["color_key"]) == &"bad", "color_key roundtrip")


func _test_panel_loadable() -> void:
	var pkd: PackedScene = load("res://scenes/ui/event_log_panel.tscn")
	_assert(pkd != null, "panel.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_screen_loadable() -> void:
	var pkd: PackedScene = load("res://scenes/ui/event_log_screen.tscn")
	_assert(pkd != null, "screen.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_save_v10() -> void:
	_assert(SaveSystem.SAVE_VERSION == 11, "SAVE_VERSION = 11 (got %d)" % SaveSystem.SAVE_VERSION)
