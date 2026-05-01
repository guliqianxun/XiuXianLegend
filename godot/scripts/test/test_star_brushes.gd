extends Node
## N7b：星轨笔 + 自连 + 隐藏图案

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_star_brush_balance()
	_test_resonance_grants_brushes()
	_test_add_player_line_consumes_brush()
	_test_add_line_requires_both_lit()
	_test_add_line_no_duplicate()
	_test_add_line_no_brush_fail()
	_test_pattern_hit_activates_buff()
	_test_pattern_buff_affects_qiao_chance()
	_test_serialization_roundtrip()
	_test_pattern_library_7_gupu()
	print("\n========== test_star_brushes ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _setup_lit_stars(ids: Array) -> void:
	# 强行把指定 su_id 标记为已点亮（_stars 里塞个 dummy）
	CodexState.reset()
	for sid in ids:
		CodexState._stars[StringName(sid)] = ["dummy"]


func _test_star_brush_balance() -> void:
	GameState.star_brushes = 0
	GameState.add_star_brushes(3)
	_assert(GameState.star_brushes == 3, "add 3")
	_assert(GameState.consume_star_brush(), "consume ok")
	_assert(GameState.star_brushes == 2, "balance 2")
	GameState.star_brushes = 0
	_assert(not GameState.consume_star_brush(), "consume fail when 0")


func _test_resonance_grants_brushes() -> void:
	GameState.active_resonances = []
	GameState.star_brushes = 0
	GameState.activate_resonance(&"qing_long")
	_assert(GameState.star_brushes == 4, "resonance grants 4 brushes (got %d)" % GameState.star_brushes)
	GameState.active_resonances = []
	GameState.star_brushes = 0


func _test_add_player_line_consumes_brush() -> void:
	GameState.activated_patterns = []
	GameState.star_brushes = 5
	_setup_lit_stars(["jiao", "kang"])
	CodexState.current_gupu_id = &"qing_long"
	var ok: bool = CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	_assert(ok, "add_player_line success")
	_assert(GameState.star_brushes == 4, "consumed 1 brush")
	_assert(CodexState.lines_of(&"qing_long").size() == 1, "1 line stored")
	GameState.star_brushes = 0


func _test_add_line_requires_both_lit() -> void:
	GameState.star_brushes = 5
	_setup_lit_stars(["jiao"])  # only jiao lit
	CodexState.current_gupu_id = &"qing_long"
	var ok: bool = CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	_assert(not ok, "rejected (kang not lit)")
	_assert(GameState.star_brushes == 5, "no brush consumed on fail")
	GameState.star_brushes = 0


func _test_add_line_no_duplicate() -> void:
	GameState.activated_patterns = []
	GameState.star_brushes = 5
	_setup_lit_stars(["jiao", "kang"])
	CodexState.current_gupu_id = &"qing_long"
	CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	# 反向再画 — 应被 normalize 识别为同一条 → 拒绝
	var ok: bool = CodexState.add_player_line(&"qing_long", &"kang", &"jiao")
	_assert(not ok, "reverse pair rejected as duplicate")
	GameState.star_brushes = 0


func _test_add_line_no_brush_fail() -> void:
	GameState.star_brushes = 0
	_setup_lit_stars(["jiao", "kang"])
	CodexState.current_gupu_id = &"qing_long"
	var ok: bool = CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	_assert(not ok, "no brush → fail")


func _test_pattern_hit_activates_buff() -> void:
	# 凑齐 qing_long 的"角亢氐三角"图案 (jiao-kang, kang-di, di-jiao)
	GameState.activated_patterns = []
	GameState.star_brushes = 10
	_setup_lit_stars(["jiao", "kang", "di"])
	CodexState.current_gupu_id = &"qing_long"
	CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	CodexState.add_player_line(&"qing_long", &"kang", &"di")
	_assert(not GameState.has_pattern(&"jiao_kang_di_triangle"), "not yet (only 2 lines)")
	CodexState.add_player_line(&"qing_long", &"di", &"jiao")
	_assert(GameState.has_pattern(&"jiao_kang_di_triangle"), "3rd line completes pattern")
	GameState.activated_patterns = []
	GameState.star_brushes = 0


func _test_pattern_buff_affects_qiao_chance() -> void:
	GameState.activated_patterns = []
	var c_no := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [])
	GameState.activate_pattern(&"jiao_kang_di_triangle")
	var c_yes := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [])
	GameState.activated_patterns = []
	_assert(absf(c_yes - c_no - 0.05) < 0.001, "pattern adds 0.05 (got %.3f → %.3f)" % [c_no, c_yes])


func _test_serialization_roundtrip() -> void:
	GameState.star_brushes = 7
	GameState.activated_patterns = [&"jiao_kang_di_triangle"]
	CodexState.player_lines = {&"qing_long": [["jiao", "kang"], ["kang", "di"]]}
	var gd := GameState.to_dict()
	var cd := CodexState.to_dict()
	GameState.star_brushes = 0
	GameState.activated_patterns = []
	CodexState.player_lines = {}
	GameState.from_dict(gd)
	CodexState.from_dict(cd)
	_assert(GameState.star_brushes == 7, "star_brushes roundtrip")
	_assert(GameState.has_pattern(&"jiao_kang_di_triangle"), "pattern roundtrip")
	_assert(CodexState.lines_of(&"qing_long").size() == 2, "lines roundtrip")
	GameState.star_brushes = 0
	GameState.activated_patterns = []
	CodexState.player_lines = {}


func _test_pattern_library_7_gupu() -> void:
	# 7 张古谱每张至少 1 个 secret pattern
	for gid in [&"qing_long", &"xuan_wu", &"zhu_que", &"bai_hu", &"zi_wei", &"xue_yao", &"can_xiu"]:
		var patterns: Array = CodexState.PATTERN_LIBRARY.get(gid, [])
		_assert(patterns.size() >= 1, "%s has ≥1 pattern" % gid)
