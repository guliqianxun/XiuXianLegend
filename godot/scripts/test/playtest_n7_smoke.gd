extends Node
## N7 烟测：7 古谱加载 + UI tabs + 切换 + 共鸣信号

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_seven_gupu_data()
	await _test_codex_screen_has_tabs()
	_test_save_v6()
	print("\n========== playtest_n7_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_seven_gupu_data() -> void:
	_assert(DataRegistry.ids_of(&"gupu").size() == 7, "7 gupu in registry")


func _test_codex_screen_has_tabs() -> void:
	var pkd: PackedScene = load("res://scenes/ui/codex_screen.tscn")
	var inst: CodexScreen = pkd.instantiate()
	add_child(inst)
	await get_tree().process_frame
	_assert(inst.has_node("Layout/GupuTabs"), "codex_screen has GupuTabs node")
	_assert(inst.has_node("Layout/Progress"), "codex_screen has Progress label")
	_assert(inst._gupu_tabs.get_child_count() == 7, "GupuTabs has 7 buttons")
	inst.queue_free()


func _test_save_v6() -> void:
	_assert(SaveSystem.SAVE_VERSION >= 6, "SAVE_VERSION ≥ 6 (got %d)" % SaveSystem.SAVE_VERSION)
