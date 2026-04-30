extends Node
## 验证 v1 旧存档能被读取并迁移到 v2 结构。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_v1_payload_migrates()
	_test_v2_payload_unchanged()
	_test_future_version_passthrough()
	print("\n========== test_save_migration ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_v1_payload_migrates() -> void:
	var v1 := {
		"version": 1,
		"saved_at": 1700000000,
		"game_state": {
			"spirit_stones": 333,
			"insights": 11,
			"pollution": 50,
			"pollution_cap": 200,
			"sanity": 80,
			"sanity_cap": 100,
			"sequence_ranks": {"sword": 7},
			"last_settle_unix": 1700000000,
			"season_id": "s0_origin",
			"season_started_unix": 1700000000,
			"equipped": {},
			"inventory": [],
			"owned_cards": ["sword_strike"],
			"tower_floor": 3,
			"tower_max_reached": 5,
		}
	}
	var migrated := SaveSystem.migrate(v1)  # 测试用 public wrapper
	_assert(int(migrated.get("version", 0)) == SaveSystem.SAVE_VERSION, "version bumped to v2")
	var gs: Dictionary = migrated.get("game_state", {})
	_assert(int(gs.get("spirit_stones", 0)) == 333, "spirit_stones preserved")
	_assert(int(gs.get("insights", 0)) == 11, "insights preserved")
	_assert(int(gs.get("last_settle_unix", 0)) == 1700000000, "last_settle_unix preserved")
	_assert(int(gs.get("reputation", -1)) == 0, "reputation defaulted to 0")
	for bad in ["pollution", "pollution_cap", "sanity", "sanity_cap",
			"sequence_ranks", "season_id", "season_started_unix",
			"owned_cards", "tower_floor", "tower_max_reached"]:
		_assert(not gs.has(bad), "v1 field '%s' stripped" % bad)


func _test_v2_payload_unchanged() -> void:
	var v2 := {
		"version": 2,
		"saved_at": 1700001234,
		"game_state": {
			"spirit_stones": 100,
			"insights": 5,
			"reputation": 20,
			"last_settle_unix": 1700001234,
			"equipped": {},
			"inventory": [],
		}
	}
	var migrated := SaveSystem.migrate(v2)
	_assert(int(migrated.get("version", 0)) == 2, "v2 stays at 2")
	var gs: Dictionary = migrated.get("game_state", {})
	_assert(int(gs.get("reputation", 0)) == 20, "v2 reputation preserved")


func _test_future_version_passthrough() -> void:
	# 未来版本（v99）的存档：migrate 必须保持原样，不改 version 也不动 game_state
	var future := {
		"version": 99,
		"saved_at": 1800000000,
		"game_state": {
			"spirit_stones": 999,
			"some_future_field": "abc",
		}
	}
	var migrated := SaveSystem.migrate(future)
	_assert(int(migrated.get("version", 0)) == 99, "future version preserved (not silently downgraded)")
	var gs: Dictionary = migrated.get("game_state", {})
	_assert(int(gs.get("spirit_stones", 0)) == 999, "future game_state untouched")
	_assert(str(gs.get("some_future_field", "")) == "abc", "future-only field preserved")
