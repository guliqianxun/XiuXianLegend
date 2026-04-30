extends Node
## 铺规 Autoload。
## - 持有当前启用的规则 id 列表（最多 3 条 v1）
## - 提供 evaluate / evaluate_offline 接口给 OfflineSimulator + UI
## - 4 条预设规则硬编码（v1 不允许玩家自创）

const MAX_SLOTS: int = 3

const PRESET_REFUSE_ALL := &"refuse_all"
const PRESET_LEND_ANY := &"lend_any"
const PRESET_REFUSE_WEIRD := &"refuse_weird"
const PRESET_LEND_REGULAR := &"lend_regular"

## id -> ShopRule
var _presets: Dictionary = {}

## 玩家当前启用的规则 id 列表（顺序敏感：评估时第一条命中即返回）
var enabled: Array[StringName] = [PRESET_REFUSE_ALL]


func _ready() -> void:
	_init_presets()


func _init_presets() -> void:
	_presets.clear()
	_presets[PRESET_REFUSE_ALL] = _make(PRESET_REFUSE_ALL, "全拒（避险）", &"any", &"refuse")
	_presets[PRESET_LEND_ANY] = _make(PRESET_LEND_ANY, "全接（激进）", &"any", &"lend")
	_presets[PRESET_REFUSE_WEIRD] = _make(PRESET_REFUSE_WEIRD, "拒怪客", &"is_weird", &"refuse")
	_presets[PRESET_LEND_REGULAR] = _make(PRESET_LEND_REGULAR, "接常客", &"is_regular", &"lend")


static func _make(id: StringName, name: String, cond: StringName, act: StringName) -> ShopRule:
	var r := ShopRule.new()
	r.id = id
	r.display_name = name
	r.condition = cond
	r.action = act
	return r


func get_preset(id: StringName) -> ShopRule:
	return _presets.get(id, null)


func all_preset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _presets:
		out.append(k)
	return out


## 在线评估：用客人真实 tier。
## c 可为 null（罕见，兜底返回 &"refuse"）
func evaluate(req: CustomerRequest, c: CustomerData) -> StringName:
	if c == null: return &"refuse"
	var shichen: int = TimeLine.shichen_of_unix(req.arrived_unix)
	return _evaluate_with_tier(int(c.tier), shichen)


## 离线评估：伪装客人按 disguise_tier 而不是真实 tier，这就是攻破点。
## 返回 (action, was_breached)：was_breached 表示规则按伪装数据判定，但真实身份不同 → 攻破
func evaluate_offline(req: CustomerRequest, c: CustomerData) -> Dictionary:
	if c == null:
		return {"action": &"refuse", "breached": false}
	var shichen: int = TimeLine.shichen_of_unix(req.arrived_unix)
	var disguised: bool = not c.disguise_name.is_empty()
	var perceived_tier: int = int(c.tier)
	if disguised and c.disguise_tier >= 0:
		perceived_tier = c.disguise_tier
	var act: StringName = _evaluate_with_tier(perceived_tier, shichen)
	# 攻破判定：客人有伪装 + 按伪装结果是 lend + 真实 tier 与伪装不同
	# （= 玩家以为是常客所以放行，结果是怪客）
	var breached: bool = disguised and act == &"lend" and perceived_tier != int(c.tier)
	return {"action": act, "breached": breached}


func _evaluate_with_tier(tier: int, shichen: int) -> StringName:
	for id in enabled:
		var rule: ShopRule = _presets.get(id, null)
		if rule == null: continue
		if rule.matches(tier, shichen):
			return rule.action
	return &"refuse"  # 无匹配兜底拒


# ── 启用列表读写 ──────────────────────────────

func enable(id: StringName) -> bool:
	if not _presets.has(id): return false
	if enabled.has(id): return true
	if enabled.size() >= MAX_SLOTS: return false
	enabled.append(id)
	return true


func disable(id: StringName) -> void:
	enabled.erase(id)


func is_enabled(id: StringName) -> bool:
	return enabled.has(id)


# ── 序列化 ────────────────────────────────────

func to_dict() -> Dictionary:
	var ser: Array = []
	for id in enabled:
		ser.append(String(id))
	return {"enabled": ser}


func from_dict(d: Dictionary) -> void:
	enabled = []
	var raw: Array = d.get("enabled", [])
	for s in raw:
		var id := StringName(s)
		if _presets.has(id):
			enabled.append(id)
	if enabled.is_empty():
		enabled = [PRESET_REFUSE_ALL]
