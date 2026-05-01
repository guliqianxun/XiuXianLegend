extends Node
## CustomerSpawner.spawn_one 抽样 + tier 分布

const SAMPLES: int = 1000
const SEED: int = 42

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_spawn_returns_request()
	_test_tier_distribution_60_30_10()
	print("\n========== test_customer_spawner ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_spawn_returns_request() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var req := CustomerSpawner.spawn_one(rng, 1700000000)
	_assert(req != null, "spawn returns non-null")
	if req == null: return
	_assert(req.customer_id != &"", "customer_id set (%s)" % req.customer_id)
	_assert(req.payment > 0, "payment > 0 (%d)" % req.payment)
	_assert(req.expected_duration_sec > 0, "duration > 0")


func _test_tier_distribution_60_30_10() -> void:
	# spec §6.1：常 60% 罕 30% 怪 10%；1000 抽样允许 ±15% 浮动
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := [0, 0, 0]
	for i in SAMPLES:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i)
		if req == null: continue
		# 优先 req.customer_data（生成器路径不入 DataRegistry）
		var c: CustomerData = req.customer_data
		if c == null:
			c = DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
		if c != null:
			counts[c.tier] += 1
	_assert(counts[CustomerData.Tier.REGULAR] >= 500, "REGULAR ~600 ±15%% (got %d)" % counts[0])
	_assert(counts[CustomerData.Tier.REGULAR] <= 700, "REGULAR <= 700 (got %d)" % counts[0])
	_assert(counts[CustomerData.Tier.RARE] >= 200, "RARE ~300 ±15%% (got %d)" % counts[1])
	_assert(counts[CustomerData.Tier.RARE] <= 400, "RARE <= 400 (got %d)" % counts[1])
	_assert(counts[CustomerData.Tier.WEIRD] >= 50, "WEIRD ~100 ±15%% (got %d)" % counts[2])
	_assert(counts[CustomerData.Tier.WEIRD] <= 200, "WEIRD <= 200 (got %d)" % counts[2])
