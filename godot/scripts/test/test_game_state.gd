extends Node
## 验证 GameState 新字段集合 + 序列化对称。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_fields_exist()
	_test_serialize_roundtrip()
	_test_no_deprecated_fields()
	print("\n========== test_game_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_fields_exist() -> void:
	GameState.spirit_stones = 100
	GameState.insights = 5
	GameState.reputation = 10
	GameState.last_settle_unix = 1700000000
	_assert(GameState.spirit_stones == 100, "spirit_stones writable")
	_assert(GameState.insights == 5, "insights writable")
	_assert(GameState.reputation == 10, "reputation writable")
	_assert(GameState.last_settle_unix == 1700000000, "last_settle_unix writable")


func _test_serialize_roundtrip() -> void:
	GameState.spirit_stones = 42
	GameState.insights = 7
	GameState.reputation = 15
	GameState.last_settle_unix = 1700001234
	var d: Dictionary = GameState.to_dict()
	# 重置后再读回
	GameState.spirit_stones = 0
	GameState.insights = 0
	GameState.reputation = 0
	GameState.last_settle_unix = 0
	GameState.from_dict(d)
	_assert(GameState.spirit_stones == 42, "spirit_stones roundtrip")
	_assert(GameState.insights == 7, "insights roundtrip")
	_assert(GameState.reputation == 15, "reputation roundtrip")
	_assert(GameState.last_settle_unix == 1700001234, "last_settle_unix roundtrip")


func _test_no_deprecated_fields() -> void:
	# 已删字段不应出现在 to_dict() 输出里
	var d: Dictionary = GameState.to_dict()
	for bad_key in ["pollution", "sanity", "owned_cards", "tower_floor",
			"tower_max_reached", "sequence_ranks", "season_id", "season_started_unix"]:
		_assert(not d.has(bad_key), "to_dict has no '%s'" % bad_key)
