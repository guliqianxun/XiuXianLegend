extends Node
## 验证 ShopState 通过 SaveSystem 写盘并读回。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_save_load_with_shop_state()
	print("\n========== test_save_with_shopstate ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_save_load_with_shop_state() -> void:
	# 删除旧档
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))

	# 配置 ShopState
	ShopState.reset()
	ShopState.upgrade_area(&"furnace")    # Lv.2
	ShopState.upgrade_area(&"furnace")    # Lv.3
	ShopState.upgrade_area(&"loft")       # Lv.2
	GameState.spirit_stones = 555
	GameState.reputation = 88

	# 强制写盘
	SaveSystem.save_now(true)

	# 重置内存
	ShopState.reset()
	GameState.spirit_stones = 0
	GameState.reputation = 0

	# 读回
	SaveSystem.load_or_init()

	_assert(ShopState.area_level(&"furnace") == 3, "furnace Lv.3 restored")
	_assert(ShopState.area_level(&"loft") == 2, "loft Lv.2 restored")
	_assert(ShopState.area_level(&"counter") == 1, "counter Lv.1 default")
	_assert(GameState.spirit_stones == 555, "spirit_stones restored")
	_assert(GameState.reputation == 88, "reputation restored")
