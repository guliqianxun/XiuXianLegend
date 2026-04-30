extends Node
## 时间线 Autoload。
## 负责：当前游戏时间戳、时辰判定、advance_seconds 推进信号、离线时长衰减计算。
## 时辰 = 2 小时。索引 0=子, 1=丑, 2=寅, 3=卯, 4=辰, 5=巳, 6=午, 7=未, 8=申, 9=酉, 10=戌, 11=亥。

const SECONDS_PER_SHICHEN: int = 7200  # 2h

const FULL_THRESHOLD_SEC: int = 86400          # 24h
const DECAY_THRESHOLD_SEC: int = 259200        # 72h
const DECAY_RATE_TIER1: float = 0.7            # 24-72h
const DECAY_RATE_TIER2: float = 0.3            # >72h

var _now_unix: int = 0
var _last_shichen: int = -1


func _ready() -> void:
	# 启动时同步系统时间
	_now_unix = int(Time.get_unix_time_from_system())
	_last_shichen = shichen_of_unix(_now_unix)


## 当前游戏时间戳（unix 秒）
func now_unix() -> int:
	return _now_unix


## 测试/调试用：直接设置当前时间（不发信号）
func set_now_unix(unix: int) -> void:
	_now_unix = unix
	_last_shichen = shichen_of_unix(unix)


## 推进时间，发 time_advanced 信号；跨时辰额外发 hour_passed
func advance_seconds(delta: int) -> void:
	if delta <= 0: return
	var new_unix := _now_unix + delta
	_now_unix = new_unix
	EventBus.time_advanced.emit(new_unix, delta)
	var cur_shichen := shichen_of_unix(new_unix)
	if cur_shichen != _last_shichen:
		_last_shichen = cur_shichen
		EventBus.hour_passed.emit(cur_shichen)


## 给定 unix 时间戳，返回该时辰索引 0..11
static func shichen_of_unix(unix: int) -> int:
	# 一天 12 时辰，每时辰 2h；以 UTC 为准（不处理时区，单机够用）
	var seconds_in_day := unix % 86400
	if seconds_in_day < 0:
		seconds_in_day += 86400
	return int(seconds_in_day / SECONDS_PER_SHICHEN)


## 计算单次离线时长的"有效"秒数（spec §7.1 老铁打盹规则）
## ≤24h 全额；24-72h 区段 70%；>72h 区段 30%
static func effective_offline_seconds(raw_seconds: int) -> int:
	if raw_seconds <= 0: return 0
	if raw_seconds <= FULL_THRESHOLD_SEC:
		return raw_seconds

	var eff := FULL_THRESHOLD_SEC
	var remaining := raw_seconds - FULL_THRESHOLD_SEC

	# 24-72h 区段（最多 48h）按 70%
	var tier1_window := DECAY_THRESHOLD_SEC - FULL_THRESHOLD_SEC  # 48h
	var tier1_used: int = mini(remaining, tier1_window)
	eff += int(round(tier1_used * DECAY_RATE_TIER1))
	remaining -= tier1_used

	# 72h+ 按 30%
	if remaining > 0:
		eff += int(round(remaining * DECAY_RATE_TIER2))
	return eff
