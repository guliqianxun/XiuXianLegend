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
	_test_path_to_direction_mapping()
	_test_spare_path_q4_excluded()
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
	_assert(q0 == &"jiao", "sword Q0 → jiao")
	_assert(q1 == &"kang", "sword Q1 → kang")
	_assert(q4 == &"xin", "sword Q4 → xin")
	_assert(q0 != q1, "Q0 != Q1 (%s vs %s)" % [q0, q1])
	_assert(q1 != q4, "Q1 != Q4 (%s vs %s)" % [q1, q4])


func _test_path_to_direction_mapping() -> void:
	# 4 主 path 各落自己方位起始
	# qing_long 只允许 sword，验证 sword 落点
	var qing := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	_assert(CodexPlacement.find_su_for_equipment(&"sword", 0, qing) == &"jiao",
		"sword Q0 → jiao (东方青龙首)")
	# xuan_wu 允许 talisman/eating_vessel/divination_plate
	var xuan := DataRegistry.get_resource(&"gupu", &"xuan_wu") as GuPuData
	_assert(CodexPlacement.find_su_for_equipment(&"talisman", 0, xuan) == &"dou",
		"talisman Q0 → dou (北方玄武首)")
	# zhu_que 允许 curse/alchemy；talisman(=curse)Q4 → wei2 北方第5颗
	var zhu := DataRegistry.get_resource(&"gupu", &"zhu_que") as GuPuData
	var t4 := CodexPlacement.find_su_for_equipment(&"talisman", 4, zhu)
	_assert(t4 == &"wei2", "talisman Q4 → wei2 (got '%s')" % t4)
	var ef := CodexPlacement.find_su_for_equipment(&"elixir_furnace", 0, zhu)
	_assert(ef == &"jing", "elixir_furnace Q0 → jing (got '%s')" % ef)


func _test_spare_path_q4_excluded() -> void:
	# eat / divination 是次 path 仅 Q0..Q3 入谱；Q4 应返回 &""
	# bai_hu 允许 eat path
	var bai := DataRegistry.get_resource(&"gupu", &"bai_hu") as GuPuData
	_assert(CodexPlacement.find_su_for_equipment(&"eating_vessel", 0, bai) == &"wei",
		"eat Q0 → wei (东尾)")
	_assert(CodexPlacement.find_su_for_equipment(&"eating_vessel", 4, bai) == &"",
		"eat Q4 → 不入谱（spare path 没 Q4 位）")
