extends Node
## N7：共鸣激活 + buff hook + 7 古谱加载

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_seven_gupu_loaded()
	_test_filter_accepts()
	_test_filter_rejects_wrong_path()
	_test_filter_rejects_wrong_quality()
	_test_resonance_activates_at_28()
	_test_resonance_idempotent()
	_test_xuan_wu_buff_reduces_damage()
	_test_serialization_roundtrip()
	print("\n========== test_resonance ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_seven_gupu_loaded() -> void:
	var ids := DataRegistry.ids_of(&"gupu")
	_assert(ids.size() == 7, "7 gupu loaded (got %d)" % ids.size())
	for need in [&"qing_long", &"xuan_wu", &"zhu_que", &"bai_hu", &"zi_wei", &"xue_yao", &"can_xiu"]:
		_assert(DataRegistry.get_resource(&"gupu", need) != null, "%s loaded" % need)


func _test_filter_accepts() -> void:
	var qing := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	_assert(qing.accepts(&"sword", 0), "qing_long accepts sword/0")
	_assert(qing.accepts(&"sword", 4), "qing_long accepts sword/4")


func _test_filter_rejects_wrong_path() -> void:
	var qing := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	_assert(not qing.accepts(&"curse", 1), "qing_long rejects curse")
	var zhu := DataRegistry.get_resource(&"gupu", &"zhu_que") as GuPuData
	_assert(zhu.accepts(&"curse", 1), "zhu_que accepts curse")
	_assert(zhu.accepts(&"alchemy", 2), "zhu_que accepts alchemy")
	_assert(not zhu.accepts(&"sword", 1), "zhu_que rejects sword")


func _test_filter_rejects_wrong_quality() -> void:
	var zi := DataRegistry.get_resource(&"gupu", &"zi_wei") as GuPuData
	_assert(not zi.accepts(&"sword", 0), "zi_wei rejects quality 0")
	_assert(not zi.accepts(&"sword", 2), "zi_wei rejects quality 2")
	_assert(zi.accepts(&"sword", 3), "zi_wei accepts quality 3")
	_assert(zi.accepts(&"sword", 4), "zi_wei accepts quality 4")


func _test_resonance_activates_at_28() -> void:
	# 把 _stars 强行填满 28 颗 → 触发激活
	GameState.active_resonances = []
	CodexState.reset()
	CodexState.current_gupu_id = &"qing_long"
	var qing := DataRegistry.get_resource(&"gupu", &"qing_long") as GuPuData
	for su in qing.stars:
		CodexState._stars[su.id] = ["dummy"]
	# 直接调 _check_resonance
	CodexState._check_resonance(&"qing_long", qing)
	_assert(GameState.has_resonance(&"qing_long"), "resonance activated at 28 stars")


func _test_resonance_idempotent() -> void:
	# 重复 activate 不重复加
	var before: int = GameState.active_resonances.size()
	GameState.activate_resonance(&"qing_long")
	GameState.activate_resonance(&"qing_long")
	_assert(GameState.active_resonances.size() == before, "activate idempotent (no dup)")


func _test_xuan_wu_buff_reduces_damage() -> void:
	# 启用玄武宿共鸣 → 1000 次 roll，DAMAGED 数量应明显减少
	GameState.active_resonances = []
	var rng_no := RandomNumberGenerator.new()
	rng_no.seed = 42
	var dmg_no_buff := 0
	for i in 1000:
		if ReturnResolver.roll_outcome(0, rng_no) == ReturnResolver.Outcome.DAMAGED:
			dmg_no_buff += 1
	GameState.activate_resonance(&"xuan_wu")
	var rng_yes := RandomNumberGenerator.new()
	rng_yes.seed = 42
	var dmg_buff := 0
	for i in 1000:
		if ReturnResolver.roll_outcome(0, rng_yes) == ReturnResolver.Outcome.DAMAGED:
			dmg_buff += 1
	GameState.active_resonances = []
	# REGULAR DAMAGED 基线 10%；buff 后应 ~5%
	_assert(dmg_buff < dmg_no_buff * 0.7,
		"xuan_wu buff: dmg %d → %d (≥30%% reduction)" % [dmg_no_buff, dmg_buff])


func _test_serialization_roundtrip() -> void:
	GameState.active_resonances = [&"xuan_wu", &"zi_wei"]
	var d := GameState.to_dict()
	GameState.active_resonances = []
	GameState.from_dict(d)
	_assert(GameState.active_resonances.size() == 2, "roundtrip: 2 resonances")
	_assert(GameState.has_resonance(&"xuan_wu"), "xuan_wu preserved")
	GameState.active_resonances = []
