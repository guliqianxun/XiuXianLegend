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

const LEARNED_PREFIX := "learned:"

## trait id → 中文显示名（玩家学到后会看到这个名字）
const TRAIT_LIBRARY: Dictionary = {
	&"sole_dustless": "鞋底无尘",
	&"hooded": "蒙面戴帽",
	&"speaks_old": "操古音",
	&"family_seal": "腰挂家纹",
	&"badge_low": "腰牌低品",
	&"smells_iron": "身有铁腥",
	&"pale_face": "面色青白",
	&"whispers_self": "自言自语",
	&"carries_doll": "怀中抱偶",
	&"gold_too_new": "金子太新",
}

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


## 取规则（4 预设 + 已学 trait 动态生成的 learned:<trait_id>）
func get_preset(id: StringName) -> ShopRule:
	if _presets.has(id):
		return _presets[id]
	var s := String(id)
	if s.begins_with(LEARNED_PREFIX):
		var trait_id := StringName(s.substr(LEARNED_PREFIX.length()))
		if TRAIT_LIBRARY.has(trait_id) and GameState.has_learned_trait(trait_id):
			return _make_learned_rule(trait_id)
	return null


## 列出所有可用规则 id（4 预设 + 玩家已学 trait）
func all_preset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _presets:
		out.append(k)
	for t in GameState.learned_traits:
		if TRAIT_LIBRARY.has(t):
			out.append(StringName(LEARNED_PREFIX + String(t)))
	return out


static func _make_learned_rule(trait_id: StringName) -> ShopRule:
	var r := ShopRule.new()
	r.id = StringName(LEARNED_PREFIX + String(trait_id))
	r.display_name = "「%s」的客人" % TRAIT_LIBRARY[trait_id]
	r.condition = &"has_trait"
	r.condition_arg = trait_id
	r.action = &"refuse"  # 学到 = 警惕信号；默认拒
	return r


## 在线评估：用客人真实 tier。
## c 可为 null（罕见，兜底返回 &"refuse"）
func evaluate(req: CustomerRequest, c: CustomerData) -> StringName:
	if c == null: return &"refuse"
	var shichen: int = TimeLine.shichen_of_unix(req.arrived_unix)
	return _evaluate_with_tier(int(c.tier), shichen, c.traits)


## 离线评估：伪装客人按 disguise_tier 而不是真实 tier，这就是攻破点。
## - has_trait 规则按真实 traits 评估（trait 没法伪装；学到 trait 就是为了识破伪装）
## 返回 {action, breached}
func evaluate_offline(req: CustomerRequest, c: CustomerData) -> Dictionary:
	if c == null:
		return {"action": &"refuse", "breached": false}
	var shichen: int = TimeLine.shichen_of_unix(req.arrived_unix)
	var disguised: bool = not c.disguise_name.is_empty()
	var perceived_tier: int = int(c.tier)
	if disguised and c.disguise_tier >= 0:
		perceived_tier = c.disguise_tier
	var act: StringName = _evaluate_with_tier(perceived_tier, shichen, c.traits)
	# 攻破判定：客人有伪装 + 按伪装结果是 lend + 真实 tier 与伪装不同
	# （= 玩家以为是常客所以放行，结果是怪客）
	var breached: bool = disguised and act == &"lend" and perceived_tier != int(c.tier)
	return {"action": act, "breached": breached}


func _evaluate_with_tier(tier: int, shichen: int, traits: Array = []) -> StringName:
	for id in enabled:
		var rule: ShopRule = get_preset(id)
		if rule == null: continue
		if rule.matches(tier, shichen, traits):
			return rule.action
	return &"refuse"  # 无匹配兜底拒


# ── 启用列表读写 ──────────────────────────────

func enable(id: StringName) -> bool:
	if get_preset(id) == null: return false
	if enabled.has(id): return true
	if enabled.size() >= MAX_SLOTS: return false
	enabled.append(id)
	EventBus.shop_rule_changed.emit(enabled.size() - 1)
	return true


func disable(id: StringName) -> void:
	if enabled.has(id):
		enabled.erase(id)
		EventBus.shop_rule_changed.emit(-1)


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
		# 注：learned trait 规则在 GameState.from_dict 之后才会被 get_preset 识别
		# SaveSystem.load_or_init 顺序保证 GameState 先 load
		if get_preset(id) != null:
			enabled.append(id)
	if enabled.is_empty():
		enabled = [PRESET_REFUSE_ALL]
