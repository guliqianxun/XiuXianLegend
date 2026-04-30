extends Node
## TimeLine：时间线推进、时辰判定、离线时长衰减。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_now_unix_positive()
	_test_shichen_index()
	_test_advance_emits_signal()
	_test_offline_decay()
	print("\n========== test_time_line ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_now_unix_positive() -> void:
	_assert(TimeLine.now_unix() > 0, "now_unix > 0")


func _test_shichen_index() -> void:
	# 时辰=2小时一个，索引 0..11
	# 给定 unix 时间戳，应返回正确索引
	# unix 时间戳 0 = 1970-01-01 00:00:00 UTC = 子时（0）
	_assert(TimeLine.shichen_of_unix(0) == 0, "unix 0 => 子时(0)")
	_assert(TimeLine.shichen_of_unix(2 * 3600) == 1, "unix 2h => 丑时(1)")
	_assert(TimeLine.shichen_of_unix(22 * 3600) == 11, "unix 22h => 亥时(11)")
	_assert(TimeLine.shichen_of_unix(24 * 3600) == 0, "unix 24h => 子时(0) again")


func _test_advance_emits_signal() -> void:
	var emitted: Array = []
	var cb := func(new_unix: int, delta: int) -> void:
		emitted.append({"unix": new_unix, "delta": delta})
	EventBus.time_advanced.connect(cb)
	TimeLine.set_now_unix(1700000000)
	TimeLine.advance_seconds(3600)
	_assert(emitted.size() == 1, "time_advanced emitted once")
	_assert(emitted[0]["delta"] == 3600, "delta = 3600")
	_assert(emitted[0]["unix"] == 1700003600, "new unix correct")
	EventBus.time_advanced.disconnect(cb)


func _test_offline_decay() -> void:
	# 单次离线 ≤24h 全额；24-72h 70% 衰减；>72h 30% 衰减
	# 函数 effective_offline_seconds(raw) 给出衰减后秒数
	var h := 3600
	_assert(TimeLine.effective_offline_seconds(12 * h) == 12 * h, "12h: full")
	_assert(TimeLine.effective_offline_seconds(24 * h) == 24 * h, "24h: full (boundary)")

	# 25h: 24h 全 + 1h × 0.7 = 24*3600 + 0.7*3600 = 24h + 2520s
	var got_25 := TimeLine.effective_offline_seconds(25 * h)
	var want_25 := 24 * h + int(round(1 * h * 0.7))
	_assert(got_25 == want_25, "25h: got %d want %d" % [got_25, want_25])

	# 72h: 24h 全 + 48h × 0.7 = 24h + 33.6h
	var got_72 := TimeLine.effective_offline_seconds(72 * h)
	var want_72 := 24 * h + int(round(48 * h * 0.7))
	_assert(got_72 == want_72, "72h: got %d want %d" % [got_72, want_72])

	# 100h: 24h 全 + 48h × 0.7 + 28h × 0.3
	var got_100 := TimeLine.effective_offline_seconds(100 * h)
	var want_100 := 24 * h + int(round(48 * h * 0.7)) + int(round(28 * h * 0.3))
	_assert(got_100 == want_100, "100h: got %d want %d" % [got_100, want_100])
