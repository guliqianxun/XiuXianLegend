class_name ForgeSystem
extends RefCounted
## 锻造逻辑：纯函数 + 注入 RNG。所有产出可复现（同 seed 同结果）。

const QUALITY_FAN: int = 0  # 凡
const QUALITY_LING: int = 1
const QUALITY_FA: int = 2
const QUALITY_JIN: int = 3
const QUALITY_MI: int = 4


## 从基础品质分布抽样，巧成时升一阶（封顶 Q4）。
## - dist: [p_凡, p_灵, p_法, p_禁, p_秘]，应总和 1.0
## - qiao_cheng_hit: 是否触发巧成
## - rng: 调用方注入的 RandomNumberGenerator
static func roll_quality(dist: PackedFloat32Array, qiao_cheng_hit: bool, rng: RandomNumberGenerator) -> int:
	if dist.size() < 5:
		push_warning("forge: distribution has %d tiers, expected 5" % dist.size())
	var u: float = rng.randf()
	var acc: float = 0.0
	var q: int = 0
	for i in dist.size():
		acc += dist[i]
		if u < acc:
			q = i
			break
	if qiao_cheng_hit:
		q = mini(q + 1, 4)
	return q


## "巧成材料"id 集合：添加这些材料 +0.10 巧成率/件
const QIAO_MATERIALS: Array[StringName] = [&"hui", &"zhu_yu", &"yi_zhong_liao_qiao"]


## 计算巧成命中概率，封顶 0.50。
## - timing_score: 火候判定窗口得分 0..1（离线/无判定时传 0）
## - smith_hand: GameState.smith_hand_today，1.0 baseline，± 5%
## - optional_materials: 玩家投入的可选添料 id 列表
static func compute_qiao_cheng_chance(timing_score: float, smith_hand: float, optional_materials: Array) -> float:
	var c: float = 0.0
	# 火候：score 0..1 → 0..+0.20
	c += clampf(timing_score, 0.0, 1.0) * 0.20
	# 手感：(1.0 + delta) → +delta（baseline 1.0 贡献 0）
	c += smith_hand - 1.0
	# 加料：每个巧成材料 +0.10
	for mid in optional_materials:
		if mid in QIAO_MATERIALS:
			c += 0.10
	return clampf(c, 0.0, 0.50)


const BACKLASH_BASE: float = 0.05
const BACKLASH_BOOST: float = 0.05
## 禁/秘料 ID 集合：添加这些材料反噬概率 +0.05（封顶 0.10）
const DANGEROUS_MATERIALS: Array[StringName] = [&"yi_zhong_liao", &"mi_pin_zhi_xie"]


## 计算反噬触发概率，封顶 0.10。
## - optional_materials: 玩家投入的可选添料 id 列表
static func compute_backlash_chance(optional_materials: Array) -> float:
	var c: float = BACKLASH_BASE
	for mid in optional_materials:
		if mid in DANGEROUS_MATERIALS:
			c = BACKLASH_BASE + BACKLASH_BOOST
			break  # 不重复累加
	return c


## 完整锻造路径：roll backlash → roll qiao_cheng → roll quality → build GearInstance
## - recipe: RecipeData
## - optional_materials: 玩家选的可选添料 id 列表（一次性消费）
## - timing_score: 火候得分 0..1（离线传 0）
## - smith_hand: GameState.smith_hand_today
## - now_unix: 出炉时间戳
## - rng: 注入的 RandomNumberGenerator
##
## **不消耗** GameState 的材料 — 调用方负责消费（保持函数纯粹）
static func forge_one(
	recipe: RecipeData,
	optional_materials: Array,
	timing_score: float,
	smith_hand: float,
	now_unix: int,
	rng: RandomNumberGenerator
) -> ForgeResult:
	var result := ForgeResult.new()

	# 1. 反噬检定（先做，命中则提前返回）
	var backlash_chance := compute_backlash_chance(optional_materials)
	if rng.randf() < backlash_chance:
		result.was_backlash = true
		result.quality = -1
		result.equipment = null
		# 副产物：50% hui / 50% yi_zhong_liao
		if rng.randf() < 0.5:
			result.byproduct = &"hui"
		else:
			result.byproduct = &"yi_zhong_liao"
		result.byproduct_amount = 1
		return result

	# 2. 巧成检定
	var qiao_cheng_chance := compute_qiao_cheng_chance(timing_score, smith_hand, optional_materials)
	var qiao_cheng_hit: bool = rng.randf() < qiao_cheng_chance
	result.was_qiao_cheng = qiao_cheng_hit

	# 3. 品质抽样
	var q := roll_quality(recipe.base_quality_distribution, qiao_cheng_hit, rng)
	result.quality = q

	# 4. 建装备
	var g := GearInstance.new()
	g.base_id = recipe.id  # N2 临时：以配方 id 当 base_id；N3 引入 base_template_id 字段时改
	g.rarity = q
	g.seed = rng.seed
	g.origin = {
		"unix": now_unix,
		"recipe": String(recipe.id),
		"qiao_cheng": qiao_cheng_hit,
		"timing_score": timing_score,
		"smith_hand": smith_hand,
		"optional_materials": _stringify_array(optional_materials),
	}
	g.history = [{
		"unix": now_unix,
		"event": "forged",
		"detail": "巧成" if qiao_cheng_hit else ""
	}]
	g.status = GearInstance.Status.IN_SHOP
	result.equipment = g
	return result


static func _stringify_array(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		out.append(String(x))
	return out
