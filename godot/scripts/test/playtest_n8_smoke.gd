extends Node
## N8 烟测：shop 加载 + overlay 实例化 + autoload 工作

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_shop_loads_with_overlay()
	_test_overlay_instantiable()
	_test_autoloads_present()
	_test_save_v7()
	print("\n========== playtest_n8_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_shop_loads_with_overlay() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	_assert(inst.has_node("NarrativeOverlay"), "shop has NarrativeOverlay")
	inst.queue_free()


func _test_overlay_instantiable() -> void:
	var pkd: PackedScene = load("res://scenes/ui/narrative_overlay.tscn")
	_assert(pkd != null, "narrative_overlay.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_autoloads_present() -> void:
	_assert(FactionState != null, "FactionState autoload present")
	_assert(NarrativeLibrary != null, "NarrativeLibrary autoload present")
	_assert(FactionState.surge_factions().size() == 3, "FactionState yields 3 surge")


func _test_save_v7() -> void:
	_assert(SaveSystem.SAVE_VERSION >= 7, "SAVE_VERSION ≥ 7 (got %d)" % SaveSystem.SAVE_VERSION)
