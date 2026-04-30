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
