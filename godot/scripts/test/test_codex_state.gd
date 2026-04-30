extends Node
## CodexState：当前古谱 + per-star 装备列表 + 序列化

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_default_gupu()
	_test_place_and_query()
	_test_multiple_at_same_star()
	_test_idempotent_double_place()
	_test_serialize_only_gupu_id()
	_test_rebuild_from_game_state()
	print("\n========== test_codex_state ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _make_gear(rarity: int) -> GearInstance:
	var g := GearInstance.new()
	g.base_id = &"iron_sword"
	g.rarity = rarity
	g.origin = {"unix": 1700000000, "recipe": "iron_sword"}
	return g


func _test_default_gupu() -> void:
	CodexState.reset()
	_assert(CodexState.current_gupu_id == &"qing_long", "default gupu = qing_long")


func _test_place_and_query() -> void:
	CodexState.reset()
	var g := _make_gear(0)
	var su_id := CodexState.place_equipment(g, &"sword")
	_assert(su_id != &"", "place returns su_id (got %s)" % su_id)
	_assert(CodexState.equipments_at_star(su_id).size() == 1, "1 equipment at %s" % su_id)
	_assert(str(g.star_position.get("gupu", "")) == "qing_long", "gear.star_position.gupu = qing_long")
	_assert(str(g.star_position.get("su", "")) == String(su_id), "gear.star_position.su = %s" % su_id)


func _test_multiple_at_same_star() -> void:
	CodexState.reset()
	var g1 := _make_gear(0)
	var g2 := _make_gear(0)
	var su1 := CodexState.place_equipment(g1, &"sword")
	var su2 := CodexState.place_equipment(g2, &"sword")
	_assert(su1 == su2, "same slot+quality lands same star")
	_assert(CodexState.equipments_at_star(su1).size() == 2, "2 equipments at star")


func _test_idempotent_double_place() -> void:
	# 同一装备两次 place 应只入一次（幂等）
	CodexState.reset()
	var g := _make_gear(0)
	var su1 := CodexState.place_equipment(g, &"sword")
	var count_after_1 := CodexState.equipments_at_star(su1).size()
	var su2 := CodexState.place_equipment(g, &"sword")
	var count_after_2 := CodexState.equipments_at_star(su1).size()
	_assert(su1 == su2, "second place returns same su_id")
	_assert(count_after_1 == count_after_2, "second place doesn't add duplicate (still %d)" % count_after_2)


func _test_serialize_only_gupu_id() -> void:
	# to_dict 只存 current_gupu_id（不存 _stars，避免与 GameState.inventory 重复持久化）
	CodexState.reset()
	var g := _make_gear(1)
	CodexState.place_equipment(g, &"talisman")
	var d: Dictionary = CodexState.to_dict()
	_assert(d.has("current_gupu_id"), "to_dict has current_gupu_id")
	_assert(not d.has("stars"), "to_dict does NOT contain stars (派生数据)")


func _test_rebuild_from_game_state() -> void:
	# 模拟 load 流程：CodexState.from_dict 后，_stars 应从 GameState.inventory 重建
	CodexState.reset()
	GameState.inventory.clear()
	# 准备一件装备：放进 GameState.inventory 并预设 star_position
	var g := _make_gear(0)
	g.star_position = {"gupu": "qing_long", "su": "jiao"}
	GameState.inventory.append(g)
	# 模拟 from_dict
	CodexState.from_dict({"current_gupu_id": "qing_long"})
	_assert(CodexState.equipments_at_star(&"jiao").size() == 1, "rebuild: jiao has 1 (got %d)" % CodexState.equipments_at_star(&"jiao").size())
	# 同一对象 reference（不是 copy）
	_assert(CodexState.equipments_at_star(&"jiao")[0] == g, "rebuild: same object reference")
