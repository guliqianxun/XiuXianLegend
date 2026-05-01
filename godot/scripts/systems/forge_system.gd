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
	# N7 紫微宿：秘品(Q4)权重 ×1.5；N7b zi_wei_zhao 再 ×1.2 叠加（先后乘）
	var working: PackedFloat32Array = dist.duplicate()
	if working.size() >= 5:
		var mul: float = 1.0
		if GameState.has_resonance(&"zi_wei"): mul *= 1.5
		if GameState.has_pattern(&"zi_wei_zhao"): mul *= 1.2
		if mul > 1.0:
			var mi_orig: float = working[4]
			var mi_new: float = mi_orig * mul
			var delta: float = mi_new - mi_orig
			working[4] = mi_new
			working[0] = maxf(0.0, working[0] - delta)
	var u: float = rng.randf()
	var acc: float = 0.0
	var q: int = 0
	for i in working.size():
		acc += working[i]
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
	# N7b 隐藏图案 buff：角亢氐三角 → 巧成率 +5%
	if GameState.has_pattern(&"jiao_kang_di_triangle"):
		c += 0.05
	return clampf(c, 0.0, 0.50)


const BACKLASH_BASE: float = 0.05
const BACKLASH_BOOST: float = 0.05
## 禁/秘料 ID 集合：添加这些材料反噬概率 +0.05（封顶 0.10）
const DANGEROUS_MATERIALS: Array[StringName] = [&"yi_zhong_liao", &"mi_pin_zhi_xie"]


## 计算反噬触发概率，封顶 0.10。
## - optional_materials: 玩家投入的可选添料 id 列表
## - N7b zhu_que_wing pattern: 反噬率 -0.02
static func compute_backlash_chance(optional_materials: Array) -> float:
	var c: float = BACKLASH_BASE
	for mid in optional_materials:
		if mid in DANGEROUS_MATERIALS:
			c = BACKLASH_BASE + BACKLASH_BOOST
			break  # 不重复累加
	if GameState.has_pattern(&"zhu_que_wing"):
		c = maxf(0.0, c - 0.02)
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
		# N7 朱雀宿：反噬副产物 ×2
		if GameState.has_resonance(&"zhu_que"):
			result.byproduct_amount = 2
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
	# N9 主词缀：按 path × quality roll 一个
	var main_affix: AffixData = roll_main_affix(recipe.path_affinity, q, rng)
	if main_affix != null:
		g.affix_ids = [main_affix.id]
		g.affix_values = [rng.randf_range(main_affix.value_min, main_affix.value_max)]
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


## 抽 1 个主词缀。
## - pool 来自 DataRegistry（hooks 为空 = 主题词缀，过滤旧战斗 affix）
## - path_filter 命中 path 或为空（通用）
## - min_tier <= quality
## - quality≥3（禁/秘）有 5% 概率从诡缀池抽（ARCANE）
## 返回 null 表示无 match（罕见）
static func roll_main_affix(path: StringName, quality: int, rng: RandomNumberGenerator) -> AffixData:
	var thematic: Array = []
	var arcane: Array = []
	for aid in DataRegistry.ids_of(&"affix"):
		var a := DataRegistry.get_resource(&"affix", aid) as AffixData
		if a == null: continue
		if not a.hooks.is_empty(): continue  # 排除旧战斗 affix
		if int(a.min_tier) > quality: continue
		var path_ok: bool = a.path_filter.is_empty() or a.path_filter.has(path)
		if not path_ok: continue
		if a.min_tier == AffixData.Tier.ARCANE:
			arcane.append(a)
		else:
			thematic.append(a)
	# 禁/秘品 + 5% → 诡缀池
	if quality >= 3 and not arcane.is_empty() and rng.randf() < 0.05:
		return _weighted_pick(arcane, rng)
	if thematic.is_empty():
		return null
	return _weighted_pick(thematic, rng)


static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> AffixData:
	var total: float = 0.0
	for a in pool:
		total += float((a as AffixData).weight)
	var u: float = rng.randf() * total
	var acc: float = 0.0
	for a in pool:
		acc += float((a as AffixData).weight)
		if u < acc:
			return a as AffixData
	return pool[0] as AffixData


static func _stringify_array(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		out.append(String(x))
	return out
