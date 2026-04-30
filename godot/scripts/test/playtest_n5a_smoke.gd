extends Node
## N5a 烟测：DiaryScreen 加载 + OfflineSimulator 端到端 + shop.tscn 含 DiaryScreen

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_diary_scene_loads()
	_test_offline_settle_writes_diary()
	_test_shop_loads_with_diary()
	print("\n========== playtest_n5a_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_diary_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/diary_screen.tscn")
	_assert(pkd != null, "diary_screen.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	inst.queue_free()


func _test_offline_settle_writes_diary() -> void:
	# 模拟"上次保存于 10 小时前"
	var real_now: int = int(Time.get_unix_time_from_system())
	var entries: Array = OfflineSimulator.simulate(real_now - 10 * 3600, real_now)
	_assert(not entries.is_empty(), "10h offline produces diary entries (got %d)" % entries.size())
	# 应该没有 sleep 卡（< 24h）
	for e in entries:
		_assert((e as Dictionary).get("kind", &"") != &"sleep", "no sleep card for 10h offline")


func _test_shop_loads_with_diary() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable (with DiaryScreen)")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	_assert(inst.has_node("DiaryScreen"), "shop has DiaryScreen child")
	inst.queue_free()
