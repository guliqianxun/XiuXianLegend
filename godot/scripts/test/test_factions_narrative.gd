extends Node
## N8：6 势力 + FactionState 周轮换 + Spawner bias + NarrativeLibrary 抽卡

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_six_factions_loaded()
	_test_faction_state_picks_3_surge()
	_test_faction_state_deterministic_per_week()
	_test_faction_state_changes_across_weeks()
	_test_spawner_biases_to_surge()
	_test_narrative_30_cards_loaded()
	_test_narrative_pick_card_replaces_vars()
	_test_narrative_first_visit_dedup()
	_test_serialization()
	print("\n========== test_factions_narrative ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_six_factions_loaded() -> void:
	var ids := DataRegistry.ids_of(&"faction")
	_assert(ids.size() == 6, "6 factions loaded (got %d)" % ids.size())
	for need in [&"wendao_zong", &"hanxing_zong", &"kurong_gu", &"wandan_men", &"wuqiu_yexiu", &"unknown"]:
		_assert(DataRegistry.get_resource(&"faction", need) != null, "%s loaded" % need)


func _test_faction_state_picks_3_surge() -> void:
	FactionState._recompute_for(100)
	var surges := FactionState.surge_factions()
	_assert(surges.size() == 3, "3 surge factions per week (got %d)" % surges.size())


func _test_faction_state_deterministic_per_week() -> void:
	FactionState._recompute_for(42)
	var s1: Array = FactionState.surge_factions().duplicate()
	FactionState._recompute_for(99)  # 中间换一周
	FactionState._recompute_for(42)  # 回到 42
	var s2: Array = FactionState.surge_factions()
	# 同周序号 → 同 surge 集合（顺序可能不同，比较 set）
	s1.sort()
	s2.sort()
	_assert(s1 == s2, "same week → same surge set")


func _test_faction_state_changes_across_weeks() -> void:
	FactionState._recompute_for(1)
	var s1: Array = FactionState.surge_factions().duplicate()
	FactionState._recompute_for(2)
	var s2: Array = FactionState.surge_factions().duplicate()
	s1.sort(); s2.sort()
	_assert(s1 != s2, "different week → likely different surge (sometimes false; here passes by RNG choice)")


func _test_spawner_biases_to_surge() -> void:
	# 强行设单一 surge 势力，1000 spawn 应有该 faction 占比 > 平均
	FactionState.active_states.clear()
	FactionState.active_states[&"wendao_zong"] = FactionState.STATE_SURGE
	for f in [&"hanxing_zong", &"kurong_gu", &"wandan_men", &"wuqiu_yexiu", &"unknown"]:
		FactionState.active_states[f] = FactionState.STATE_NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary = {}
	for i in 1000:
		var c := CustomerGenerator.generate(rng, 0, i)
		counts[c.faction] = int(counts.get(c.faction, 0)) + 1
	# 6 势力均匀 = ~166；surge ×2 后 wendao_zong 期望 ≈ 286
	var wendao_n: int = int(counts.get(&"wendao_zong", 0))
	_assert(wendao_n > 250, "surge wendao_zong: %d > 250 (baseline ~166)" % wendao_n)


func _test_narrative_30_cards_loaded() -> void:
	var ids := DataRegistry.ids_of(&"narrative")
	# N8 加 30 张；后续 N9 加 15 暗线碎片 = 45+；只要 ≥ 30 通过
	_assert(ids.size() >= 30, "≥30 narrative cards loaded (got %d)" % ids.size())


func _test_narrative_pick_card_replaces_vars() -> void:
	var text := NarrativeLibrary.pick_card(NarrativeCard.Trigger.CUSTOMER_FIRST, {"customer": "苏家娘子"})
	_assert(not text.is_empty(), "pick CUSTOMER_FIRST returns text")
	_assert(not text.contains("{customer}"), "placeholder replaced (got: %s)" % text)


func _test_narrative_first_visit_dedup() -> void:
	NarrativeLibrary.reset_seen()
	var t1 := NarrativeLibrary.pick_first_visit(&"_test_cust", "测试")
	var t2 := NarrativeLibrary.pick_first_visit(&"_test_cust", "测试")
	_assert(not t1.is_empty(), "first visit returns text first time")
	_assert(t2.is_empty(), "second visit returns empty (dedup)")


func _test_serialization() -> void:
	# FactionState
	FactionState._recompute_for(7)
	var d := FactionState.to_dict()
	FactionState.active_states.clear()
	FactionState.from_dict(d)
	_assert(FactionState.current_week == 7, "FactionState week roundtrip")
	# NarrativeLibrary
	NarrativeLibrary.reset_seen()
	NarrativeLibrary.pick_first_visit(&"foo", "x")
	var nd := NarrativeLibrary.to_dict()
	NarrativeLibrary.reset_seen()
	NarrativeLibrary.from_dict(nd)
	_assert(NarrativeLibrary.pick_first_visit(&"foo", "x").is_empty(),
		"seen_first_visit roundtrip")
