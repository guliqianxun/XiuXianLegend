extends Node
## 势力动态状态 Autoload（spec §8.2）。
## 每"周"轮换 3 个势力进入 surge 状态（其客人 spawn 权重 ×2）。
## 状态由 unix 周序号确定性导出（同一周序号 → 同一组 surge 势力）。

const STATE_NONE := &"none"
const STATE_SURGE := &"surge"

const SURGE_COUNT_PER_WEEK: int = 3
const WEEK_SECONDS: int = 7 * 86400

## 当前周序号（unix / WEEK_SECONDS）
var current_week: int = -1

## faction_id -> StringName state（&"surge" / &"none"）
var active_states: Dictionary = {}


func _ready() -> void:
	_recompute_for(_week_of(int(Time.get_unix_time_from_system())))


## unix → 周序号（确定性）
static func _week_of(unix: int) -> int:
	return unix / WEEK_SECONDS


## 用 week 作 RNG seed 选 surge 势力
func _recompute_for(week: int) -> void:
	current_week = week
	active_states.clear()
	var ids: Array = []
	for fid in DataRegistry.ids_of(&"faction"):
		ids.append(fid)
		active_states[fid] = STATE_NONE
	if ids.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = week
	# Fisher-Yates 取前 N
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var n: int = mini(SURGE_COUNT_PER_WEEK, ids.size())
	for i in n:
		active_states[ids[i]] = STATE_SURGE


## 主对外接口：检查当前是否需要更新（按当前 unix 算的周和 current_week 不同）
func tick_to(now_unix: int) -> void:
	var w: int = _week_of(now_unix)
	if w != current_week:
		_recompute_for(w)


func state_of(faction_id: StringName) -> StringName:
	return active_states.get(faction_id, STATE_NONE)


func is_surge(faction_id: StringName) -> bool:
	return state_of(faction_id) == STATE_SURGE


func surge_factions() -> Array[StringName]:
	var out: Array[StringName] = []
	for fid in active_states:
		if active_states[fid] == STATE_SURGE:
			out.append(fid)
	return out


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var states_ser: Dictionary = {}
	for fid in active_states:
		states_ser[String(fid)] = String(active_states[fid])
	return {
		"current_week": current_week,
		"active_states": states_ser,
	}


func from_dict(d: Dictionary) -> void:
	current_week = int(d.get("current_week", -1))
	active_states.clear()
	var raw: Dictionary = d.get("active_states", {})
	for k in raw:
		active_states[StringName(k)] = StringName(raw[k])
	if active_states.is_empty():
		_recompute_for(_week_of(int(Time.get_unix_time_from_system())))
