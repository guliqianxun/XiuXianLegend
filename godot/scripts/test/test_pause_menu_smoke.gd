extends Node
## PauseMenu / InventoryStrip tooltip / placement v2 烟测

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_pause_menu_loadable()
	_test_shop_has_pause_menu()
	_test_inventory_strip_card_has_tooltip()
	_test_placement_path_to_direction()
	print("\n========== test_pause_menu_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_pause_menu_loadable() -> void:
	var pkd: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	_assert(pkd != null, "pause_menu.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	for need in ["Frame/VBox/ResumeButton", "Frame/VBox/MenuButton", "Frame/VBox/QuitButton"]:
		_assert(inst.has_node(need), "has %s" % need)
	inst.queue_free()


func _test_shop_has_pause_menu() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	_assert(inst.has_node("PauseMenu"), "shop has PauseMenu")
	inst.queue_free()


func _test_inventory_strip_card_has_tooltip() -> void:
	# 直接调 _tooltip_for 验证拼装
	var g := GearInstance.new()
	g.base_id = &"iron_sword"
	g.rarity = 2
	g.affix_ids = [&"feng_li"]
	g.affix_values = [5.0]
	g.origin = {"recipe": "iron_sword"}
	g.history = [{"event": "forged"}, {"event": "lent"}]
	var t := InventoryStrip._tooltip_for(g)
	_assert("锋利" in t, "tooltip mentions affix '锋利' (got: %s)" % t)
	_assert("出自 iron_sword" in t, "tooltip mentions origin (got: %s)" % t)
	_assert("履历 2 条" in t, "tooltip mentions history (got: %s)" % t)


func _test_placement_path_to_direction() -> void:
	var qing := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	# sword Q0..Q4 → jiao..xin (东方青龙 5 颗)
	var expected: Array[StringName] = [&"jiao", &"kang", &"di", &"fang", &"xin"]
	for q in 5:
		var got := CodexPlacement.find_su_for_equipment(&"sword", q, qing)
		_assert(got == expected[q], "sword Q%d → %s (got %s)" % [q, expected[q], got])
