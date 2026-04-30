extends Node
## 器谱状态 Autoload。
## - 当前选中古谱 id
## - per-star 装备列表（star id -> Array[GearInstance]）
## - 序列化（GearInstance 序列化已由 to_dict 完成）

const DEFAULT_GUPU: StringName = &"qing_long"

var current_gupu_id: StringName = DEFAULT_GUPU

## su_id (StringName) -> Array[GearInstance]
var _stars: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	current_gupu_id = DEFAULT_GUPU
	_stars.clear()


## 把装备入谱：根据 slot_kind 和 gear.rarity 找落点 → 加入 _stars[su_id] → 同步写入 gear.star_position
## 返回落点 su_id（&"" 表示无 match）
func place_equipment(gear: GearInstance, slot_kind: StringName) -> StringName:
	if gear == null:
		return &""
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
func switch_gupu(gupu_id: StringName) -> void:
	if gupu_id == current_gupu_id:
		return
	current_gupu_id = gupu_id
	EventBus.codex_changed.emit(gupu_id)


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var stars_ser: Dictionary = {}
	for su_id in _stars:
		var arr: Array = _stars[su_id]
		var ser: Array = []
		for inst: GearInstance in arr:
			if inst != null:
				ser.append(inst.to_dict())
		stars_ser[String(su_id)] = ser
	return {
		"current_gupu_id": String(current_gupu_id),
		"stars": stars_ser,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	current_gupu_id = StringName(d.get("current_gupu_id", String(DEFAULT_GUPU)))
	_stars.clear()
	var stars_raw: Dictionary = d.get("stars", {})
	for k in stars_raw:
		var arr: Array = []
		var raw_arr: Array = stars_raw[k]
		for entry in raw_arr:
			arr.append(GearInstance.from_dict(entry))
		_stars[StringName(k)] = arr
