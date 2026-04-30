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
