extends Node
## 器谱状态 Autoload。
## - 当前选中古谱 id
## - per-star 装备列表（star id -> Array[GearInstance]）— **派生自 GameState.inventory + .equipped**，不独立持久化
## - 序列化只存 current_gupu_id；_stars 在 from_dict 时从 GameState 中重建（避免 GearInstance 重复 deserialize 导致 status/history 不同步）
##
## N7 计划：当 §5.4 自连/星轨笔实装时，本类会增加 player_lines + resonance hooks。

const DEFAULT_GUPU: StringName = &"qing_long"

var current_gupu_id: StringName = DEFAULT_GUPU

## su_id (StringName) -> Array[GearInstance]
## **派生数据**，不独立持久化；reload 时从 GameState 重建
var _stars: Dictionary = {}

## 玩家自连线（spec §5.4）
## gupu_id (StringName) -> Array[[su_a:String, su_b:String]]
## 线方向无关，存储时按字典序 normalize
var player_lines: Dictionary = {}

## 隐藏图案库（spec §5.4：玩家不看，自己画线撞中）
## v1：每张古谱 1 个简单图案
const PATTERN_LIBRARY: Dictionary = {
	&"qing_long": [
		{
			"id": &"jiao_kang_di_triangle",
			"name": "角亢氐三角",
			"lines": [["jiao", "kang"], ["kang", "di"], ["di", "jiao"]],
			"buff_id": &"qiao_cheng_plus_5",
			"buff_desc": "巧成率 +5%",
		},
	],
	&"xuan_wu": [
		{
			"id": &"xuan_wu_quad",
			"name": "玄武四象",
			"lines": [["dou", "niu"], ["niu", "nv"], ["nv", "xu"], ["xu", "dou"]],
			"buff_id": &"damaged_minus_5",
			"buff_desc": "损坏率额外 -5%",
		},
	],
	&"zhu_que": [
		{
			"id": &"zhu_que_wing",
			"name": "朱雀展翼",
			"lines": [["jing", "gui"], ["gui", "liu"], ["liu", "xing"]],
			"buff_id": &"backlash_minus_2",
			"buff_desc": "反噬率 -2%",
		},
	],
	&"bai_hu": [
		{
			"id": &"bai_hu_fang",
			"name": "白虎方阵",
			"lines": [["kui", "lou"], ["lou", "wei3"], ["wei3", "mao"], ["mao", "kui"]],
			"buff_id": &"weird_payment_plus_10",
			"buff_desc": "怪客酬金额外 +10%",
		},
	],
	&"zi_wei": [
		{
			"id": &"zi_wei_zhao",
			"name": "紫微照命",
			"lines": [["jiao", "wei"], ["wei", "ji"]],
			"buff_id": &"mi_quality_plus",
			"buff_desc": "秘品权重再 ×1.2",
		},
	],
	&"xue_yao": [
		{
			"id": &"xue_yao_blood",
			"name": "血曜流转",
			"lines": [["xin", "wei"], ["wei", "ji"], ["ji", "dou"]],
			"buff_id": &"weird_inspect_half",
			"buff_desc": "打听怪客灵石半价",
		},
	],
	&"can_xiu": [
		{
			"id": &"can_xiu_bind",
			"name": "残宿牵连",
			"lines": [["yi", "zhen"], ["zhen", "jiao"]],
			"buff_id": &"not_returned_minus_5",
			"buff_desc": "不归还率额外 -5%",
		},
	],
}


func _ready() -> void:
	reset()


func reset() -> void:
	current_gupu_id = DEFAULT_GUPU
	_stars.clear()
	player_lines.clear()


# ── 自连（spec §5.4）──────────────────────────
## 标准化（按字典序）一对 su_id
static func _norm_pair(a: StringName, b: StringName) -> Array:
	var sa: String = String(a)
	var sb: String = String(b)
	if sa <= sb:
		return [sa, sb]
	return [sb, sa]


## 检查两颗星位是否都已点亮（在 _stars 字典里有装备）
func _both_lit(su_a: StringName, su_b: StringName) -> bool:
	return _stars.has(su_a) and _stars.has(su_b)


## 玩家画一条自连线。返回是否成功（笔够 + 都点亮 + 不重复）
func add_player_line(gupu_id: StringName, su_a: StringName, su_b: StringName) -> bool:
	if su_a == &"" or su_b == &"" or su_a == su_b:
		return false
	if gupu_id != current_gupu_id:
		return false
	if not _both_lit(su_a, su_b):
		return false
	var pair: Array = _norm_pair(su_a, su_b)
	var lines: Array = player_lines.get(gupu_id, [])
	for existing in lines:
		if existing[0] == pair[0] and existing[1] == pair[1]:
			return false
	if not GameState.consume_star_brush():
		return false
	if not player_lines.has(gupu_id):
		player_lines[gupu_id] = []
	(player_lines[gupu_id] as Array).append(pair)
	EventBus.player_line_drawn.emit(gupu_id, su_a, su_b)
	_check_pattern_match(gupu_id)
	return true


func lines_of(gupu_id: StringName) -> Array:
	return player_lines.get(gupu_id, [])


## 检查当前 gupu 的玩家线是否撞中任何 secret pattern
func _check_pattern_match(gupu_id: StringName) -> void:
	var patterns: Array = PATTERN_LIBRARY.get(gupu_id, [])
	if patterns.is_empty():
		return
	var lines: Array = player_lines.get(gupu_id, [])
	# 把现有 player lines 转 set 用于子集判定
	var line_set: Dictionary = {}
	for ln in lines:
		line_set["%s|%s" % [ln[0], ln[1]]] = true
	for p in patterns:
		var pid: StringName = p["id"]
		if GameState.has_pattern(pid):
			continue
		var required: Array = p["lines"]
		var all_in: bool = true
		for req_pair in required:
			var key := "%s|%s" % _norm_pair(StringName(req_pair[0]), StringName(req_pair[1]))
			if not line_set.has(key):
				all_in = false
				break
		if all_in:
			GameState.activate_pattern(pid)


## 把装备入谱：根据 slot_kind 和 gear.rarity 找落点 → 加入 _stars[su_id] → 同步写入 gear.star_position
## 返回落点 su_id（&"" 表示无 match）
##
## 幂等：如果 gear.star_position 已经设了（说明已入谱），直接返回原 su_id 不重复入。
func place_equipment(gear: GearInstance, slot_kind: StringName) -> StringName:
	if gear == null:
		return &""
	# 幂等检查：避免同一装备被两次 forge_finished 钩子触发后重复入谱
	if not gear.star_position.is_empty():
		return StringName(gear.star_position.get("su", ""))
	var gupu := DataRegistry.get_resource(&"gupu", current_gupu_id) as GuPuData
	if gupu == null:
		push_warning("codex: current_gupu %s not loaded" % current_gupu_id)
		return &""
	var su_id := CodexPlacement.find_su_for_equipment(slot_kind, gear.rarity, gupu)
	if su_id == &"":
		return &""
	if not _stars.has(su_id):
		_stars[su_id] = []
	(_stars[su_id] as Array).append(gear)
	gear.star_position = {"gupu": String(current_gupu_id), "su": String(su_id)}
	EventBus.star_lit.emit(current_gupu_id, su_id, gear)
	# N7：检测此谱是否共鸣（28 颗全亮）
	_check_resonance(current_gupu_id, gupu)
	return su_id


## 当前 _stars 字典 key 数 = 已点亮星位
func lit_star_count() -> int:
	return _stars.size()


## 检查 gupu_id 是否 28 颗全亮 → 激活共鸣（一次性）
func _check_resonance(gupu_id: StringName, gupu: GuPuData) -> void:
	if GameState.has_resonance(gupu_id):
		return
	if gupu == null or gupu.stars.is_empty():
		return
	if _stars.size() < gupu.stars.size():
		return
	GameState.activate_resonance(gupu_id)


func equipments_at_star(su_id: StringName) -> Array:
	return _stars.get(su_id, []) as Array


## 切换当前古谱（N3 仅支持 qing_long；保留接口）
## 切换当前古谱：重建 _stars（按 GameState.inventory 中 gear.star_position[gupu] 过滤）
## 注意：每件装备只入造出来时的那张谱，切谱看不见其他谱的装备
func switch_gupu(gupu_id: StringName) -> void:
	if gupu_id == current_gupu_id:
		return
	current_gupu_id = gupu_id
	rebuild_stars_from_game_state()
	EventBus.codex_changed.emit(gupu_id)


# ── 序列化 ────────────────────────────────────
## 只存 current_gupu_id；_stars 不进 payload（避免与 GameState.inventory 重复持久化）
func to_dict() -> Dictionary:
	var lines_ser: Dictionary = {}
	for gid in player_lines:
		var arr: Array = []
		for pair in player_lines[gid]:
			arr.append([pair[0], pair[1]])
		lines_ser[String(gid)] = arr
	return {
		"current_gupu_id": String(current_gupu_id),
		"player_lines": lines_ser,
	}


## 从 payload 读 current_gupu_id；_stars 从 GameState 重建（必须在 GameState.from_dict 之后调用）
func from_dict(d: Dictionary) -> void:
	current_gupu_id = StringName(d.get("current_gupu_id", String(DEFAULT_GUPU)))
	_stars.clear()
	player_lines.clear()
	var raw_lines: Dictionary = d.get("player_lines", {})
	for gid in raw_lines:
		var arr: Array = []
		for pair in raw_lines[gid]:
			arr.append([String(pair[0]), String(pair[1])])
		player_lines[StringName(gid)] = arr
	rebuild_stars_from_game_state()


## 扫描 GameState.inventory 和 GameState.equipped，把所有 star_position 已设的装备
## 重新填进 _stars。**不重新跑 placement 公式**——尊重每件装备已记录的入谱位
## （这样在 N7 多古谱切换时，已入谱装备不会因公式变化重新落到别处）。
func rebuild_stars_from_game_state() -> void:
	_stars.clear()
	var all_gears: Array = []
	for inst in GameState.inventory:
		if inst is GearInstance:
			all_gears.append(inst)
	for slot_key in GameState.equipped:
		var inst = GameState.equipped[slot_key]
		if inst is GearInstance:
			all_gears.append(inst)
	for g: GearInstance in all_gears:
		if g.star_position.is_empty():
			continue
		# 只重建当前古谱的星位（其它古谱的装备保留 star_position 但不进 _stars）
		var gupu_id: String = str(g.star_position.get("gupu", ""))
		if gupu_id != String(current_gupu_id):
			continue
		var su_id: StringName = StringName(str(g.star_position.get("su", "")))
		if su_id == &"":
			continue
		if not _stars.has(su_id):
			_stars[su_id] = []
		(_stars[su_id] as Array).append(g)
