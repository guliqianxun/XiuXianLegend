extends Node
## WeirdCodex：fingerprint + 阈值解锁 + 序列化

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_fingerprint_format()
	_test_record_dedup()
	_test_threshold_unlocks()
	_test_signal_emit()
	_test_15_thresholds_max()
	_test_15_identity_fragments_loaded()
	_test_serialization_roundtrip()
	print("\n========== test_weird_codex ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_gear(base_id: StringName, q: int) -> GearInstance:
	var g := GearInstance.new()
	g.base_id = base_id
	g.rarity = q
	return g


func _test_fingerprint_format() -> void:
	var g := _make_gear(&"iron_sword", 2)
	var fp := WeirdCodex.fingerprint_of(g)
	_assert(String(fp) == "iron_sword|2|_", "fingerprint = recipe|q|affix (got %s)" % fp)
	# 加 affix → 不同 fingerprint
	g.affix_ids = [&"feng_li"]
	g.affix_values = [5.0]
	var fp2 := WeirdCodex.fingerprint_of(g)
	_assert(String(fp2) == "iron_sword|2|feng_li", "with affix (got %s)" % fp2)
	_assert(fp != fp2, "different affix → different fingerprint")


func _test_record_dedup() -> void:
	WeirdCodex.reset()
	var g1 := _make_gear(&"iron_sword", 1)
	var g2 := _make_gear(&"iron_sword", 1)  # same fp
	var g3 := _make_gear(&"iron_sword", 2)  # different
	_assert(WeirdCodex.record_gear(g1), "first record returns true")
	_assert(not WeirdCodex.record_gear(g2), "duplicate fp returns false")
	_assert(WeirdCodex.record_gear(g3), "different fp returns true")
	_assert(WeirdCodex.count() == 2, "count = 2")


func _test_threshold_unlocks() -> void:
	WeirdCodex.reset()
	# 阈值 [5, 10, 18, ...]，造 5 个 → 解锁第 1 段
	for i in 5:
		WeirdCodex.record_gear(_make_gear(&"r_%d" % i, 0))
	_assert(WeirdCodex.unlocked_fragments == 1, "5 fingerprints → 1 fragment")
	# 再造 5 个（总 10）→ 解锁第 2 段
	for i in 5:
		WeirdCodex.record_gear(_make_gear(&"r2_%d" % i, 0))
	_assert(WeirdCodex.unlocked_fragments == 2, "10 fingerprints → 2 fragments")


func _test_signal_emit() -> void:
	WeirdCodex.reset()
	var sink := {"records": [], "fragments": []}
	var cb_rec := func(_fp: StringName, total: int) -> void: sink["records"].append(total)
	var cb_frag := func(idx: int, _t: int) -> void: sink["fragments"].append(idx)
	EventBus.weird_codex_recorded.connect(cb_rec)
	EventBus.identity_fragment_unlocked.connect(cb_frag)
	for i in 5:
		WeirdCodex.record_gear(_make_gear(&"sg_%d" % i, 0))
	_assert((sink["records"] as Array).size() == 5, "5 record signals fired")
	_assert((sink["fragments"] as Array).size() == 1, "1 fragment unlock signal at threshold")
	EventBus.weird_codex_recorded.disconnect(cb_rec)
	EventBus.identity_fragment_unlocked.disconnect(cb_frag)


func _test_15_thresholds_max() -> void:
	_assert(WeirdCodex.THRESHOLDS.size() == 15, "15 threshold steps (one per fragment)")


func _test_15_identity_fragments_loaded() -> void:
	# 15 张 if_*.tres 应都加载且 trigger=IDENTITY_FRAGMENT
	var ids := DataRegistry.ids_of(&"narrative")
	var if_count := 0
	for nid in ids:
		var c := DataRegistry.get_resource(&"narrative", nid) as NarrativeCard
		if c == null: continue
		if c.trigger == NarrativeCard.Trigger.IDENTITY_FRAGMENT:
			if_count += 1
	_assert(if_count == 15, "15 identity fragments in narratives (got %d)" % if_count)


func _test_serialization_roundtrip() -> void:
	WeirdCodex.reset()
	for i in 3:
		WeirdCodex.record_gear(_make_gear(&"sr_%d" % i, 0))
	var d := WeirdCodex.to_dict()
	WeirdCodex.reset()
	WeirdCodex.from_dict(d)
	_assert(WeirdCodex.count() == 3, "fingerprints roundtrip (got %d)" % WeirdCodex.count())
	# unlocked_fragments 应为 0（3 < 5 阈值）
	_assert(WeirdCodex.unlocked_fragments == 0, "unlocked_fragments roundtrip")
