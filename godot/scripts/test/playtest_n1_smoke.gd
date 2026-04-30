extends Node
## N1 烟测：所有 autoload 启动成功 + shop.tscn 可被 ResourceLoader 加载 + 实例化不崩。

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_autoloads()
	_test_data_registry_indexes()
	_test_shop_scene_loads()
	_test_old_iron_scene_loads()
	print("\n========== playtest_n1_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_autoloads() -> void:
	_assert(EventBus != null, "EventBus autoload alive")
	_assert(GameState != null, "GameState autoload alive")
	_assert(SaveSystem != null, "SaveSystem autoload alive")
	_assert(DataRegistry != null, "DataRegistry autoload alive")
	_assert(TimeLine != null, "TimeLine autoload alive")
	_assert(ShopState != null, "ShopState autoload alive")


func _test_data_registry_indexes() -> void:
	# 索引应包含新数据类目（即使空）
	for cat in [&"recipe", &"customer", &"gupu", &"su", &"narrative", &"gear", &"affix"]:
		var ids: Array = DataRegistry.ids_of(cat)
		_assert(ids != null, "DataRegistry has category '%s' (got %d ids)" % [cat, ids.size()])
	# 已删类目应不存在
	for cat in [&"card", &"sequence", &"anomaly", &"encounter"]:
		var ids: Array = DataRegistry.ids_of(cat)
		_assert(ids.is_empty(), "DataRegistry has no '%s'" % cat)


func _test_shop_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	_assert(pkd != null, "shop.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "shop.tscn instantiable")
	# 不 add_child（避免 _ready 触发完整流程）；instantiate 不崩就行
	inst.queue_free()


func _test_old_iron_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/actors/old_iron.tscn")
	_assert(pkd != null, "old_iron.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "old_iron.tscn instantiable")
	inst.queue_free()
