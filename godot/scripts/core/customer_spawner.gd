extends Node
## 客人召唤 Autoload。
## - 在线时按节奏 spawn（autospawn 关闭，玩家手动按"接客"触发；N5 加自动定时）
## - 抽 tier → 在该 tier 池里随机选 customer → 实例化 CustomerRequest
## - 离线节奏 N5 整合

## tier 抽样权重（spec §6.1：常 60% 罕 30% 怪 10%）
const TIER_WEIGHTS: Array[float] = [0.60, 0.30, 0.10]

## 默认借出时长（秒）— 各 tier 不同（怪客拖更久）
const DURATION_BY_TIER: Array[int] = [600, 900, 1800]

## 抽中"剧情池"的概率；其余走 generator（无尽流）
const STORY_POOL_RATIO: float = 0.30


## 召唤一位客人。返回 CustomerRequest 或 null
## 流程：抽 tier → 30% 概率从剧情池（手写 .tres）抽，70% 程序生成
## 剧情池此 tier 为空时直接走生成器
static func spawn_one(rng: RandomNumberGenerator, now_unix: int) -> CustomerRequest:
	var tier: int = _pick_tier(rng, now_unix)
	var c: CustomerData = null
	if rng.randf() < STORY_POOL_RATIO:
		c = _pick_from_story_pool(rng, tier)
	if c == null:
		c = CustomerGenerator.generate(rng, tier, now_unix)
	if c == null:
		return null
	# 实例化 CustomerRequest
	var req := CustomerRequest.new()
	req.customer_id = c.id
	req.customer_data = c
	req.arrived_unix = now_unix
	req.desired_slot = _slot_from_path(c.path_affinity)
	req.min_quality = 0
	var payment: int = c.base_payment
	# N7 白虎宿：怪客酬金 ×1.2；N7b bai_hu_fang pattern 再 +10% 叠加（先后乘）
	if tier == CustomerData.Tier.WEIRD:
		var mul: float = 1.0
		if GameState.has_resonance(&"bai_hu"): mul *= 1.2
		if GameState.has_pattern(&"bai_hu_fang"): mul *= 1.1
		if mul > 1.0:
			payment = int(round(float(payment) * mul))
	req.payment = payment
	req.quest_label = "外勤" if tier == CustomerData.Tier.REGULAR else "夜事"
	req.expected_duration_sec = DURATION_BY_TIER[tier]
	req.unmasked = (c.disguise_name.is_empty())
	return req


## 抽 tier。N7 血曜宿：深夜（子-寅时 0-2）怪客权重 ×2，从常客扣
static func _pick_tier(rng: RandomNumberGenerator, now_unix: int = 0) -> int:
	var weights: Array[float] = TIER_WEIGHTS.duplicate()
	if now_unix > 0 and GameState.has_resonance(&"xue_yao"):
		var shichen: int = TimeLine.shichen_of_unix(now_unix)
		if shichen >= 0 and shichen <= 2:
			var weird_orig: float = weights[CustomerData.Tier.WEIRD]
			var weird_new: float = weird_orig * 2.0
			weights[CustomerData.Tier.WEIRD] = weird_new
			weights[CustomerData.Tier.REGULAR] = maxf(0.0,
				weights[CustomerData.Tier.REGULAR] - (weird_new - weird_orig))
	var u: float = rng.randf()
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if u < acc:
			return i
	return CustomerData.Tier.REGULAR


static func _pick_from_story_pool(rng: RandomNumberGenerator, tier: int) -> CustomerData:
	var pool: Array = []
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null and c.tier == tier:
			pool.append(c)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


## 玩家点"接客"时调用：spawn 一位 + 写入 EncounterState.pending_request
## 返回是否成功（已 pending 时返回 false）
func spawn_now() -> bool:
	if EncounterState.pending_request != null:
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var req := spawn_one(rng, TimeLine.now_unix())
	if req == null:
		return false
	EncounterState.pending_request = req
	EventBus.customer_arrived.emit(req.customer_id, req)
	return true


static func _slot_from_path(path: StringName) -> StringName:
	# path → 主要 slot 映射
	match path:
		&"sword": return &"sword"
		&"curse": return &"talisman"
		&"puppet": return &"puppet_core"
		&"alchemy": return &"elixir_furnace"
		&"eat": return &"eating_vessel"
		&"divination": return &"divination_plate"
		_: return &"sword"
