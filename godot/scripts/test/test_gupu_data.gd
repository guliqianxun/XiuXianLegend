extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_su_basic()
	_test_gupu_basic()
	_test_gupu_holds_28_su()
	print("\n========== test_gupu_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_su_basic() -> void:
	var s := SuData.new()
	s.id = &"jiao_su"
	s.display_name = "角宿"
	s.match_path = &"sword"
	s.match_quality_min = 0   # 凡=0
	s.match_quality_max = 4   # 秘=4
	s.position_x = 0.2
	s.position_y = 0.3
	_assert(s.id == &"jiao_su", "id set")
	_assert(s.match_path == &"sword", "match_path set")
	_assert(s.position_x == 0.2 and s.position_y == 0.3, "position set")


func _test_gupu_basic() -> void:
	var g := GuPuData.new()
	g.id = &"qing_long"
	g.display_name = "青龙宿"
	g.theme = "剑系兵器"
	g.resonance_description = "出借兵器斩妖时回信故事强度 +1 级"
	_assert(g.id == &"qing_long", "id set")
	_assert(g.display_name == "青龙宿", "display_name set")


func _test_gupu_holds_28_su() -> void:
	var g := GuPuData.new()
	# 创建 28 颗占位 Su
	var sus: Array[SuData] = []
	for i in range(28):
		var s := SuData.new()
		s.id = StringName("su_%d" % i)
		sus.append(s)
	g.stars = sus
	_assert(g.stars.size() == 28, "gupu holds 28 stars")
