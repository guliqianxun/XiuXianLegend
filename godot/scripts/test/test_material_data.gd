# godot/scripts/test/test_material_data.gd
extends Node
## MaterialData 资源加载 + 字段校验

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_seven_materials_load()
	_test_field_values()
	_test_affix_bias_present()
	_test_only_purchasable_have_price()
	print("\n========== test_material_data ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)

func _test_seven_materials_load() -> void:
	for mid in [&"tie", &"jin", &"zhu_sha", &"huang_zhi", &"gu", &"hui", &"yi"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md != null, "%s loads" % mid)

func _test_field_values() -> void:
	var tie: MaterialData = DataRegistry.get_resource(&"material", &"tie") as MaterialData
	_assert(tie.display_name == "铁", "tie display_name=铁")
	_assert(tie.short_name == "铁", "tie short_name=铁")
	_assert(tie.unit_price == 3, "tie unit_price=3")
	_assert(tie.category == &"common", "tie category=common")

func _test_affix_bias_present() -> void:
	var zs: MaterialData = DataRegistry.get_resource(&"material", &"zhu_sha") as MaterialData
	_assert(zs.affix_bias.get(&"curse", 0) == 3, "zhu_sha curse bias=3")
	var hui: MaterialData = DataRegistry.get_resource(&"material", &"hui") as MaterialData
	_assert(hui.affix_bias.is_empty(), "hui affix_bias empty")

func _test_only_purchasable_have_price() -> void:
	for mid in [&"hui", &"yi"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md.unit_price == 0, "%s unit_price=0 (not purchasable)" % mid)
	for mid in [&"tie", &"jin", &"zhu_sha", &"huang_zhi", &"gu"]:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		_assert(md.unit_price > 0, "%s unit_price>0 (purchasable)" % mid)
