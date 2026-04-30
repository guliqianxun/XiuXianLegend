extends Node
## 客人召唤 Autoload。
## - 在线时按节奏 spawn（autospawn 关闭，玩家手动按"接客"触发；N5 加自动定时）
## - 抽 tier → 在该 tier 池里随机选 customer → 实例化 CustomerRequest
## - 离线节奏 N5 整合

## tier 抽样权重（v1 简化：无 RARE，常 80% 怪 20%）
const TIER_WEIGHTS: Array[float] = [0.80, 0.0, 0.20]

## 默认借出时长（秒）— 各 tier 不同（怪客拖更久）
const DURATION_BY_TIER: Array[int] = [600, 900, 1800]


## 召唤一位客人。返回 CustomerRequest 或 null（无可用客人）
static func spawn_one(rng: RandomNumberGenerator, now_unix: int) -> CustomerRequest:
	# 1. 抽 tier
	var u: float = rng.randf()
	var acc: float = 0.0
	var tier: int = CustomerData.Tier.REGULAR
	for i in TIER_WEIGHTS.size():
		acc += TIER_WEIGHTS[i]
		if u < acc:
			tier = i
			break
	# 2. 在该 tier 池里随机选 customer
	var pool: Array = []
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c != null and c.tier == tier:
			pool.append(c)
	if pool.is_empty():
		# 兜底：用 REGULAR 池
		for cid in DataRegistry.ids_of(&"customer"):
			var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
			if c != null and c.tier == CustomerData.Tier.REGULAR:
				pool.append(c)
	if pool.is_empty():
		return null
	var pick: CustomerData = pool[rng.randi() % pool.size()]
	# 3. 实例化 CustomerRequest
	var req := CustomerRequest.new()
	req.customer_id = pick.id
	req.arrived_unix = now_unix
	req.desired_slot = _slot_from_path(pick.path_affinity)
	req.min_quality = 0
	req.payment = pick.base_payment
	req.quest_label = "外勤" if tier == CustomerData.Tier.REGULAR else "夜事"
	req.expected_duration_sec = DURATION_BY_TIER[tier]
	return req


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
