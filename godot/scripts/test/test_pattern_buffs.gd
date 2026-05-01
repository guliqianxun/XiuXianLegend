extends Node
## N7b：6 个 pattern buff 实战联动验证（jiao_kang_di_triangle 已在 test_star_brushes 测）

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_xuan_wu_quad_extra_damaged_reduction()
	_test_can_xiu_bind_extra_not_returned_reduction()
	_test_zhu_que_wing_reduces_backlash()
	_test_zi_wei_zhao_stacks_with_resonance()
	_test_bai_hu_fang_stacks_payment()
	_test_xue_yao_blood_halves_inspect_cost()
	print("\n========== test_pattern_buffs ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _count_outcome(samples: int, tier: int, outcome: int, seed: int, path: StringName = &"") -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := 0
	for i in samples:
		if ReturnResolver.roll_outcome(tier, rng, path) == outcome:
			n += 1
	return n


func _test_xuan_wu_quad_extra_damaged_reduction() -> void:
	GameState.activated_patterns = []
	GameState.active_resonances = []
	# 基线 REGULAR DAMAGED 10%（=1000 抽样 ~100）
	var base := _count_outcome(2000, 0, ReturnResolver.Outcome.DAMAGED, 42)
	GameState.activate_pattern(&"xuan_wu_quad")
	var with_buff := _count_outcome(2000, 0, ReturnResolver.Outcome.DAMAGED, 42)
	GameState.activated_patterns = []
	# 减幅 ~5%（绝对），2000 × 5% = 100
	_assert(with_buff < base - 50, "xuan_wu_quad: dmg %d → %d (-%d)" % [base, with_buff, base - with_buff])


func _test_can_xiu_bind_extra_not_returned_reduction() -> void:
	GameState.activated_patterns = []
	GameState.active_resonances = []
	var base := _count_outcome(2000, 2, ReturnResolver.Outcome.NOT_RETURNED, 7)
	GameState.activate_pattern(&"can_xiu_bind")
	var with_buff := _count_outcome(2000, 2, ReturnResolver.Outcome.NOT_RETURNED, 7)
	GameState.activated_patterns = []
	_assert(with_buff < base - 50, "can_xiu_bind: nr %d → %d (-%d)" % [base, with_buff, base - with_buff])


func _test_zhu_que_wing_reduces_backlash() -> void:
	GameState.activated_patterns = []
	var c_no := ForgeSystem.compute_backlash_chance([])
	GameState.activate_pattern(&"zhu_que_wing")
	var c_yes := ForgeSystem.compute_backlash_chance([])
	GameState.activated_patterns = []
	_assert(absf(c_no - c_yes - 0.02) < 0.001,
		"zhu_que_wing: backlash %.3f → %.3f (-0.02)" % [c_no, c_yes])


func _test_zi_wei_zhao_stacks_with_resonance() -> void:
	GameState.activated_patterns = []
	GameState.active_resonances = []
	var dist := PackedFloat32Array([0.5, 0.3, 0.13, 0.05, 0.02])
	# 基线 Q4 = 0.02；zi_wei alone ×1.5 → 0.03；+ pattern ×1.2 → 0.036
	var rng_a := RandomNumberGenerator.new(); rng_a.seed = 99
	var mi_a := 0
	for i in 5000:
		if ForgeSystem.roll_quality(dist, false, rng_a) == 4:
			mi_a += 1
	GameState.activate_resonance(&"zi_wei")
	GameState.activate_pattern(&"zi_wei_zhao")
	var rng_b := RandomNumberGenerator.new(); rng_b.seed = 99
	var mi_b := 0
	for i in 5000:
		if ForgeSystem.roll_quality(dist, false, rng_b) == 4:
			mi_b += 1
	GameState.activated_patterns = []
	GameState.active_resonances = []
	# 期望 mi_b ≈ mi_a × 1.8（ratio 1.5..2.5 容忍）
	var ratio: float = float(mi_b) / float(maxi(1, mi_a))
	_assert(ratio >= 1.4 and ratio <= 2.5,
		"zi_wei stack: mi %d → %d ratio %.2f (expect 1.4..2.5)" % [mi_a, mi_b, ratio])


func _test_bai_hu_fang_stacks_payment() -> void:
	GameState.activated_patterns = []
	GameState.active_resonances = []
	# 单独 pattern → +10%
	var c := CustomerData.new()
	c.id = &"_test"; c.tier = CustomerData.Tier.WEIRD; c.base_payment = 1000
	# 直接调 _pick_tier 不简单，改用 spawn_one；用足够抽样统计 weird payment 平均
	# 简化：直接构造 req，模拟 spawner 计算 payment
	var base_pay: int = c.base_payment
	GameState.activate_pattern(&"bai_hu_fang")
	# 期望 base × 1.1 = 1100
	# 因为 spawn_one 实现内部直接乘，我们走 spawner
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var sum_with := 0
	var n_with := 0
	for i in 200:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i)
		if req == null: continue
		var cd: CustomerData = req.customer_data
		if cd != null and cd.tier == CustomerData.Tier.WEIRD:
			sum_with += int(round(float(req.payment) / float(cd.base_payment) * 1000))
			n_with += 1
	GameState.activated_patterns = []
	GameState.active_resonances = []
	if n_with == 0:
		_bad("no weird spawned")
		return
	var avg_ratio: float = float(sum_with) / float(n_with) / 1000.0
	# 期望 ≈ 1.10（仅 pattern）
	_assert(avg_ratio >= 1.08 and avg_ratio <= 1.13,
		"bai_hu_fang alone payment ratio %.3f (~1.10)" % avg_ratio)


func _test_xue_yao_blood_halves_inspect_cost() -> void:
	var c := CustomerData.new()
	c.tier = CustomerData.Tier.WEIRD
	GameState.activated_patterns = []
	var no := CustomerArrivalPanel._inspect_cost_for(c)
	GameState.activate_pattern(&"xue_yao_blood")
	var yes := CustomerArrivalPanel._inspect_cost_for(c)
	GameState.activated_patterns = []
	_assert(yes == no / 2, "xue_yao_blood halves cost: %d → %d" % [no, yes])
	# REGULAR 不享受
	var creg := CustomerData.new()
	creg.tier = CustomerData.Tier.REGULAR
	GameState.activate_pattern(&"xue_yao_blood")
	var reg_cost := CustomerArrivalPanel._inspect_cost_for(creg)
	GameState.activated_patterns = []
	_assert(reg_cost == CustomerArrivalPanel.INSPECT_COST,
		"xue_yao_blood doesn't affect REGULAR (got %d)" % reg_cost)
