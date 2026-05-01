class_name ReturnResolver
extends RefCounted
## 客人借出装备后的回信结果计算（spec §6.4 5 档分布）。

enum Outcome {
	OK_RETURN = 0,        ## 顺利归还
	GREAT_DEED = 1,       ## 立大功
	DAMAGED = 2,          ## 损坏归还
	MUTATED = 3,          ## 异变归还
	NOT_RETURNED = 4,     ## 不归还
}

## 概率表 [tier][outcome]，每行总和 1.0
const DISTRIBUTION: Array = [
	# REGULAR: 70 / 12 / 10 / 5 / 3
	[0.70, 0.12, 0.10, 0.05, 0.03],
	# RARE: 55 / 20 / 12 / 8 / 5
	[0.55, 0.20, 0.12, 0.08, 0.05],
	# WEIRD: 25 / 25 / 15 / 20 / 15
	[0.25, 0.25, 0.15, 0.20, 0.15],
]


## 按 tier 抽样一个 outcome
## N7 共鸣 buff 钩子：
## - 玄武宿：DAMAGED -50%，剩余转入 OK_RETURN
## - 青龙宿：path=sword 时 GREAT_DEED +5%，从 OK_RETURN 扣
## - 残宿：NOT_RETURNED -30%，剩余转入 OK_RETURN
##
## path 可选（默认 &""）；shop_screen 调用时传入 gear path
static func roll_outcome(tier: int, rng: RandomNumberGenerator, path: StringName = &"") -> int:
	if tier < 0 or tier >= DISTRIBUTION.size():
		return Outcome.OK_RETURN
	var dist: Array = (DISTRIBUTION[tier] as Array).duplicate()
	# 玄武宿：损坏率 -50%
	if GameState.has_resonance(&"xuan_wu"):
		var dmg_orig: float = float(dist[Outcome.DAMAGED])
		dist[Outcome.DAMAGED] = dmg_orig * 0.5
		dist[Outcome.OK_RETURN] = float(dist[Outcome.OK_RETURN]) + dmg_orig * 0.5
	# 青龙宿：剑系装备立大功 +5%
	if path == &"sword" and GameState.has_resonance(&"qing_long"):
		var bonus: float = 0.05
		dist[Outcome.GREAT_DEED] = float(dist[Outcome.GREAT_DEED]) + bonus
		dist[Outcome.OK_RETURN] = maxf(0.0, float(dist[Outcome.OK_RETURN]) - bonus)
	# 残宿：未归还 -30%，转入 OK_RETURN
	if GameState.has_resonance(&"can_xiu"):
		var nr_orig: float = float(dist[Outcome.NOT_RETURNED])
		dist[Outcome.NOT_RETURNED] = nr_orig * 0.7
		dist[Outcome.OK_RETURN] = float(dist[Outcome.OK_RETURN]) + nr_orig * 0.3
	var u: float = rng.randf()
	var acc: float = 0.0
	for i in dist.size():
		acc += float(dist[i])
		if u < acc:
			return i
	return Outcome.OK_RETURN


## outcome → 简短中文描述（用于 UI / 历史）
static func outcome_text(outcome: int) -> String:
	match outcome:
		Outcome.OK_RETURN: return "顺利归还"
		Outcome.GREAT_DEED: return "立大功归来"
		Outcome.DAMAGED: return "损坏归还"
		Outcome.MUTATED: return "异变归还"
		Outcome.NOT_RETURNED: return "未归还"
		_: return "未知"
