class_name IdleSettlement
extends RefCounted
## 离线挂机结算（纯公式 / 无回合模拟）。
## 输入：上次结算 unix + 当前 unix + 修炼参数。
## 输出：奖励 Dictionary，由 GameState 统一应用。

const SEC_PER_HOUR := 3600.0
const SOFT_CAP_HOURS := 12.0    ## 满速结算上限
const HARD_CAP_HOURS := 24.0    ## 衰减区上限（12-24h 按 50% 计）
const DAILY_FIRST_BONUS := 1.20 ## 每日首次结算 +20%

## 默认基础产出（每小时）
const BASE_XP_PER_H := 20.0
const BASE_GEM_PER_H := 50.0
const BASE_INSIGHT_RATE := 0.4   ## 见闻 = poisson(λ = h * rate)
const BASE_POLLUTE_PER_H := 2.0


static func settle(now_unix: int, last_unix: int, mods: Dictionary = {}) -> Dictionary:
	var elapsed_sec: int = max(0, now_unix - last_unix)
	var hours_raw: float = float(elapsed_sec) / SEC_PER_HOUR

	# 软/硬封顶
	var capped_hours: float = clampf(hours_raw, 0.0, SOFT_CAP_HOURS)
	var decayed_hours: float = clampf(hours_raw - SOFT_CAP_HOURS, 0.0, HARD_CAP_HOURS - SOFT_CAP_HOURS) * 0.5
	var effective_h: float = capped_hours + decayed_hours

	var xp_mult: float = 1.0 + float(mods.get("xp_bonus", 0.0))
	var gem_mult: float = 1.0 + float(mods.get("gem_bonus", 0.0))
	var pollute_mult: float = 1.0 - clampf(float(mods.get("pollute_resist", 0.0)), 0.0, 0.9)

	# 每日首次：上次结算到 now 跨过本地午夜则给 bonus
	var daily_bonus: float = DAILY_FIRST_BONUS if _crossed_local_midnight(last_unix, now_unix) else 1.0

	var xp: int = int(BASE_XP_PER_H * effective_h * xp_mult * daily_bonus)
	var gems: int = int(BASE_GEM_PER_H * effective_h * gem_mult * daily_bonus)
	var pollute: int = int(BASE_POLLUTE_PER_H * effective_h * pollute_mult)
	var insights: int = _poisson(BASE_INSIGHT_RATE * effective_h)
	var sanity_regen: int = int(round(effective_h * 5.0))

	return {
		"elapsed_sec": elapsed_sec,
		"hours_raw": hours_raw,
		"effective_hours": effective_h,
		"daily_bonus_applied": daily_bonus > 1.0,
		"xp": xp,
		"spirit_stones": gems,
		"insights": insights,
		"pollution": pollute,
		"sanity_regen": sanity_regen,
	}


static func _crossed_local_midnight(a_unix: int, b_unix: int) -> bool:
	if a_unix <= 0 or b_unix <= a_unix:
		return false
	var ad := Time.get_date_dict_from_unix_time(a_unix)
	var bd := Time.get_date_dict_from_unix_time(b_unix)
	return ad.year != bd.year or ad.month != bd.month or ad.day != bd.day


## 简易 Knuth Poisson 采样；λ 较大时退化为正态近似避免溢出
static func _poisson(lam: float) -> int:
	if lam <= 0.0:
		return 0
	if lam > 30.0:
		var z: float = randfn(0.0, 1.0)
		return int(maxf(0.0, lam + z * sqrt(lam)))
	var L: float = exp(-lam)
	var k: int = 0
	var p: float = 1.0
	while true:
		k += 1
		p *= randf()
		if p <= L:
			break
	return k - 1
