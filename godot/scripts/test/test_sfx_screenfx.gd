extends Node
## ScreenFx + Sfx：autoload 加载 + 调用不崩 + 音色生成正确

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_sfx_streams_built()
	_test_play_no_crash()
	_test_screenfx_shake_no_crash()
	_test_sfx_invalid_tier_clamped()
	print("\n========== test_sfx_screenfx ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_sfx_streams_built() -> void:
	# 5 forge + breach + inspect + door_bell + door_knock + seal_stamp + paper_flutter = 11
	for n in [&"forge_0", &"forge_1", &"forge_2", &"forge_3", &"forge_4",
			&"breach", &"inspect",
			&"door_bell", &"door_knock", &"seal_stamp", &"paper_flutter"]:
		_assert(Sfx._streams.has(n), "stream %s built" % n)
		var s: AudioStreamWAV = Sfx._streams[n]
		_assert(s.data.size() > 0, "stream %s has data (size %d)" % [n, s.data.size()])


func _test_play_no_crash() -> void:
	Sfx.play_forge(0)
	Sfx.play_forge(4)
	Sfx.play_breach()
	Sfx.play_inspect()
	Sfx.play_door_bell()
	Sfx.play_door_knock()
	Sfx.play_seal_stamp()
	Sfx.play_paper_flutter()
	_ok("Sfx.play_* no crash (11 streams)")


func _test_screenfx_shake_no_crash() -> void:
	# headless 没有 current_scene 是 Node2D，shake 会 early-return；不应崩
	ScreenFx.shake(8.0, 0.3)
	ScreenFx.shake(0.0, 0.3)  # zero intensity
	ScreenFx.shake(8.0, 0.0)  # zero duration
	_ok("ScreenFx.shake no crash on edge cases")


func _test_sfx_invalid_tier_clamped() -> void:
	Sfx.play_forge(-5)  # clamp to 0
	Sfx.play_forge(99)  # clamp to 4
	_ok("invalid tier clamped, no crash")
