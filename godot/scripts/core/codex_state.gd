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


func _ready() -> void:
	reset()


func reset() -> void:
	current_gupu_id = DEFAULT_GUPU
	_stars.clear()


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
	return su_id


func equipments_at_star(su_id: StringName) -> Array:
	return _stars.get(su_id, []) as Array


## 切换当前古谱（N3 仅支持 qing_long；保留接口）
## N7: 当多古谱实装时，切谱后 _stars 需要按新古谱重建（每件装备的 star_position 重算）。
func switch_gupu(gupu_id: StringName) -> void:
	if gupu_id == current_gupu_id:
		return
	current_gupu_id = gupu_id
	EventBus.codex_changed.emit(gupu_id)


# ── 序列化 ────────────────────────────────────
## 只存 current_gupu_id；_stars 不进 payload（避免与 GameState.inventory 重复持久化）
func to_dict() -> Dictionary:
	return {
		"current_gupu_id": String(current_gupu_id),
	}


## 从 payload 读 current_gupu_id；_stars 从 GameState 重建（必须在 GameState.from_dict 之后调用）
func from_dict(d: Dictionary) -> void:
	current_gupu_id = StringName(d.get("current_gupu_id", String(DEFAULT_GUPU)))
	_stars.clear()
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
