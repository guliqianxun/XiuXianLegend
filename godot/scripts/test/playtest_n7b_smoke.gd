extends Node
## N7b 烟测：星轨笔 / 自连 / 图案命中端到端 + UI 加载

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_save_v9()
	_test_pattern_library_complete()
	await _test_codex_screen_has_brush_label()
	_test_full_loop_brush_to_pattern()
	print("\n========== playtest_n7b_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_save_v9() -> void:
	_assert(SaveSystem.SAVE_VERSION >= 9, "SAVE_VERSION ≥ 9 (got %d)" % SaveSystem.SAVE_VERSION)


func _test_pattern_library_complete() -> void:
	_assert(CodexState.PATTERN_LIBRARY.size() == 7, "7 古谱 each have pattern entry")


func _test_codex_screen_has_brush_label() -> void:
	var pkd: PackedScene = load("res://scenes/ui/codex_screen.tscn")
	var inst: CodexScreen = pkd.instantiate()
	add_child(inst)
	await get_tree().process_frame
	_assert(inst.has_node("Layout/BrushBar"), "codex_screen has BrushBar label")
	inst.queue_free()


func _test_full_loop_brush_to_pattern() -> void:
	# 共鸣激活获得 4 笔 → 画 3 条线凑齐 qing_long pattern
	GameState.activated_patterns = []
	GameState.active_resonances = []
	GameState.star_brushes = 0
	CodexState.reset()
	CodexState.current_gupu_id = &"qing_long"
	CodexState._stars[&"jiao"] = ["x"]
	CodexState._stars[&"kang"] = ["x"]
	CodexState._stars[&"di"] = ["x"]
	GameState.activate_resonance(&"qing_long")
	_assert(GameState.star_brushes == 4, "after resonance: 4 brushes")
	CodexState.add_player_line(&"qing_long", &"jiao", &"kang")
	CodexState.add_player_line(&"qing_long", &"kang", &"di")
	CodexState.add_player_line(&"qing_long", &"di", &"jiao")
	_assert(GameState.star_brushes == 1, "consumed 3 brushes")
	_assert(GameState.has_pattern(&"jiao_kang_di_triangle"), "pattern triggered")
	# 巧成率 +5%
	var c := ForgeSystem.compute_qiao_cheng_chance(0.0, 1.0, [])
	_assert(absf(c - 0.05) < 0.001, "qiao chance = 0.05 from pattern (got %.3f)" % c)
	# cleanup
	GameState.activated_patterns = []
	GameState.active_resonances = []
	GameState.star_brushes = 0
	CodexState.reset()
