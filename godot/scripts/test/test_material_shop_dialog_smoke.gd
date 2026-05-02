# godot/scripts/test/test_material_shop_dialog_smoke.gd
extends Node
## MaterialShopDialog 烟测

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _test_dialog_loads_and_shows_purchasable_only()
	await _test_buy_decrements_stones_increments_material()
	await _test_disabled_when_insufficient_stones()
	print("\n========== test_material_shop_dialog_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _test_dialog_loads_and_shows_purchasable_only() -> void:
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	_assert(pkd != null, "dialog scene loadable")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var list: VBoxContainer = dlg.get_node("Frame/VBox/ScrollContainer/ListVBox")
	# 5 个可购材料：tie/jin/zhu_sha/huang_zhi/gu
	_assert(list.get_child_count() == 5, "5 purchasable rows (got %d)" % list.get_child_count())
	dlg.queue_free()
	await get_tree().process_frame

func _test_buy_decrements_stones_increments_material() -> void:
	GameState.spirit_stones = 100
	var before_tie: int = GameState.material_count(&"tie")
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	dlg._on_buy(&"tie", DataRegistry.get_resource(&"material", &"tie"))
	_assert(GameState.material_count(&"tie") == before_tie + 1, "tie +1")
	_assert(GameState.spirit_stones == 97, "stones -3 (was 100)")
	dlg.queue_free()
	await get_tree().process_frame

func _test_disabled_when_insufficient_stones() -> void:
	GameState.spirit_stones = 1  # 不够买 tie (3)
	var pkd: PackedScene = load("res://scenes/ui/material_shop_dialog.tscn")
	var dlg: Control = pkd.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var list: VBoxContainer = dlg.get_node("Frame/VBox/ScrollContainer/ListVBox")
	for row in list.get_children():
		var btn: Button = row.get_node("Buy")
		_assert(btn.disabled, "buy disabled when stones insufficient")
		break  # 一行验证够了
	dlg.queue_free()
	await get_tree().process_frame
