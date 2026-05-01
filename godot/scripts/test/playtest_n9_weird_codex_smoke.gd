extends Node
## N9 烟测：诡器谱 + 暗线碎片端到端

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_save_v8()
	_test_weird_codex_autoload()
	_test_45_narratives_total()
	_test_full_loop_record_unlock_pick()
	print("\n========== playtest_n9_weird_codex_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_save_v8() -> void:
	_assert(SaveSystem.SAVE_VERSION >= 8, "SAVE_VERSION ≥ 8 (got %d)" % SaveSystem.SAVE_VERSION)


func _test_weird_codex_autoload() -> void:
	_assert(WeirdCodex != null, "WeirdCodex autoload present")
	_assert(WeirdCodex.next_threshold() > 0, "first threshold > 0")


func _test_45_narratives_total() -> void:
	# 30 (N8) + 15 (identity) = 45
	var n := DataRegistry.ids_of(&"narrative").size()
	_assert(n == 45, "45 narrative cards total (got %d)" % n)


func _test_full_loop_record_unlock_pick() -> void:
	WeirdCodex.reset()
	# 模拟造 5 件不同 fingerprint 装备 → 解锁第 1 段 → pick_card 能拿到 IDENTITY_FRAGMENT 文字
	for i in 5:
		var g := GearInstance.new()
		g.base_id = StringName("e2e_%d" % i)
		g.rarity = 0
		WeirdCodex.record_gear(g)
	_assert(WeirdCodex.unlocked_fragments == 1, "5 records → unlocked 1 fragment")
	var t := NarrativeLibrary.pick_card(NarrativeCard.Trigger.IDENTITY_FRAGMENT)
	_assert(not t.is_empty(), "pick_card IDENTITY_FRAGMENT returns text")
