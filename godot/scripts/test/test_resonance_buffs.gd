extends Node
## N7：6 张古谱共鸣 buff 钩子（玄武在 test_resonance 已测，这里覆盖另 5 张）

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_qing_long_sword_great_deed_boost()
	_test_qing_long_doesnt_affect_non_sword()
	_test_can_xiu_reduces_not_returned()
	_test_zhu_que_doubles_byproduct()
	_test_zi_wei_boosts_mi_quality()
	_test_bai_hu_boosts_weird_payment()
	_test_xue_yao_deep_night_weird_x2()
	print("\n========== test_resonance_buffs ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _count_outcomes(samples: int, tier: int, path: StringName, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	for i in samples:
		counts[ReturnResolver.roll_outcome(tier, rng, path)] += 1
	return counts


func _test_qing_long_sword_great_deed_boost() -> void:
	GameState.active_resonances = []
	var no_buff := _count_outcomes(2000, 0, &"sword", 42)
	GameState.activate_resonance(&"qing_long")
	var with_buff := _count_outcomes(2000, 0, &"sword", 42)
	GameState.active_resonances = []
	# REGULAR GREAT_DEED 基线 12% → +5% = 17%；2000 抽样应明显增加
	_assert(with_buff[1] > no_buff[1] + 50,
		"qing_long sword GREAT_DEED: %d → %d" % [no_buff[1], with_buff[1]])


func _test_qing_long_doesnt_affect_non_sword() -> void:
	GameState.active_resonances = [&"qing_long"]
	var sword_great: int = _count_outcomes(2000, 0, &"sword", 7)[1]
	var talisman_great: int = _count_outcomes(2000, 0, &"curse", 7)[1]
	GameState.active_resonances = []
	# curse 不应享受 +5%；sword 应明显比 curse 高
	_assert(sword_great > talisman_great + 30,
		"qing_long affects sword only: sword=%d curse=%d" % [sword_great, talisman_great])


func _test_can_xiu_reduces_not_returned() -> void:
	GameState.active_resonances = []
	# 用 WEIRD tier (NOT_RETURNED 基线 15%)
	var no_buff := _count_outcomes(2000, 2, &"", 99)
	GameState.activate_resonance(&"can_xiu")
	var with_buff := _count_outcomes(2000, 2, &"", 99)
	GameState.active_resonances = []
	_assert(with_buff[4] < no_buff[4] * 0.85,
		"can_xiu NOT_RETURNED: %d → %d (≥15%% reduction)" % [no_buff[4], with_buff[4]])


func _test_zhu_que_doubles_byproduct() -> void:
	GameState.active_resonances = []
	# 强行触发反噬：用 yi_zhong_liao 风险料 + 高 RNG seed
	# 简化：直接用 forge_one + 一个会反噬的 RNG state
	var recipe: RecipeData = DataRegistry.get_resource(&"recipe", &"iron_sword") as RecipeData
	if recipe == null:
		_bad("iron_sword recipe missing")
		return
	# 多 seed 找一次反噬，验证 byproduct_amount = 1
	var no_buff_amount: int = _find_backlash_amount(recipe)
	GameState.activate_resonance(&"zhu_que")
	var with_buff_amount: int = _find_backlash_amount(recipe)
	GameState.active_resonances = []
	_assert(no_buff_amount == 1, "no buff: byproduct = 1 (got %d)" % no_buff_amount)
	_assert(with_buff_amount == 2, "zhu_que: byproduct = 2 (got %d)" % with_buff_amount)


func _find_backlash_amount(recipe: RecipeData) -> int:
	for s in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var result := ForgeSystem.forge_one(recipe, [&"yi_zhong_liao"], 0.0, 1.0, 0, rng)
		if result.was_backlash:
			return result.byproduct_amount
	return -1


func _test_zi_wei_boosts_mi_quality() -> void:
	# 用一个秘品基线 0.04 (高品质 recipe) 的配方
	# 现有 ling_jian_xian Q4 = 0.03；激活 zi_wei 后 → 0.045
	GameState.active_resonances = []
	var recipe: RecipeData = DataRegistry.get_resource(&"recipe", &"ling_jian_xian") as RecipeData
	if recipe == null:
		_bad("ling_jian_xian recipe missing")
		return
	var rng_no := RandomNumberGenerator.new()
	rng_no.seed = 42
	var mi_no := 0
	for i in 5000:
		if ForgeSystem.roll_quality(recipe.base_quality_distribution, false, rng_no) == 4:
			mi_no += 1
	GameState.activate_resonance(&"zi_wei")
	var rng_yes := RandomNumberGenerator.new()
	rng_yes.seed = 42
	var mi_yes := 0
	for i in 5000:
		if ForgeSystem.roll_quality(recipe.base_quality_distribution, false, rng_yes) == 4:
			mi_yes += 1
	GameState.active_resonances = []
	# 5000 × 0.03 = 150；5000 × 0.045 = 225。容忍 ±20%
	_assert(mi_yes >= mi_no + 30,
		"zi_wei mi-quality: %d → %d (≥30 increase)" % [mi_no, mi_yes])


func _test_bai_hu_boosts_weird_payment() -> void:
	# 反复 spawn 直到出 WEIRD，比较 payment
	GameState.active_resonances = []
	var no_buff_payments: Array = _spawn_weird_payments(50, 100)
	GameState.activate_resonance(&"bai_hu")
	var with_buff_payments: Array = _spawn_weird_payments(50, 100)
	GameState.active_resonances = []
	if no_buff_payments.is_empty() or with_buff_payments.is_empty():
		_bad("no WEIRD spawned in samples; can't verify bai_hu")
		return
	var avg_no: float = _avg(no_buff_payments)
	var avg_yes: float = _avg(with_buff_payments)
	_assert(avg_yes > avg_no * 1.10,
		"bai_hu WEIRD payment: avg %.0f → %.0f (≥10%% boost)" % [avg_no, avg_yes])


func _spawn_weird_payments(seed: int, attempts: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	for i in attempts:
		# Force WEIRD by manipulating: just call spawn_one many times
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i * 60)
		if req == null: continue
		var c: CustomerData = req.customer_data
		if c != null and c.tier == 2:
			out.append(req.payment)
	return out


func _avg(arr: Array) -> float:
	if arr.is_empty(): return 0.0
	var s: float = 0.0
	for v in arr: s += float(v)
	return s / float(arr.size())


func _test_xue_yao_deep_night_weird_x2() -> void:
	# 深夜（unix 对应 shichen 0..2）激活时 WEIRD 比例应 ~×2
	# 选一个 shichen=0 的时间戳
	var deep_night_unix: int = 0  # unix 0 = 子时
	GameState.active_resonances = []
	var no_buff_weird := _count_weird_at_unix(deep_night_unix, 1000, 7)
	GameState.activate_resonance(&"xue_yao")
	var with_buff_weird := _count_weird_at_unix(deep_night_unix, 1000, 7)
	GameState.active_resonances = []
	_assert(with_buff_weird > no_buff_weird * 1.5,
		"xue_yao deep night WEIRD: %d → %d (≥50%% boost)" % [no_buff_weird, with_buff_weird])


func _count_weird_at_unix(unix: int, samples: int, seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := 0
	for i in samples:
		var req := CustomerSpawner.spawn_one(rng, unix + i)  # +i 不影响 shichen 显著
		if req == null: continue
		var c: CustomerData = req.customer_data
		if c != null and c.tier == 2:
			n += 1
	return n
