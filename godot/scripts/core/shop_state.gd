extends Node
## 铺子状态 Autoload。
## 负责：4 区域等级、铺规槽容量、（未来）铺规内容。
## 不持有具体客人/装备实例（那在 GameState）。

const AREAS: Array[StringName] = [&"furnace", &"counter", &"loft", &"yard"]
const MAX_LEVEL: int = 3

## 柜台等级 -> 铺规槽数
const COUNTER_LV_TO_SLOTS: Array[int] = [3, 5, 8]   # Lv.1=3, Lv.2=5, Lv.3=8

## area_id -> int
var _area_levels: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	_area_levels.clear()
	for a in AREAS:
		_area_levels[a] = 1


func area_level(area: StringName) -> int:
	return int(_area_levels.get(area, 1))


## 升级一区。成功返回 true。已达 MAX_LEVEL 返回 false（**不发信号**）。
func upgrade_area(area: StringName) -> bool:
	if not _area_levels.has(area):
		push_warning("unknown area: %s" % area)
		return false
	var cur: int = _area_levels[area]
	if cur >= MAX_LEVEL:
		return false
	_area_levels[area] = cur + 1
	EventBus.shop_upgraded.emit(area, cur + 1)
	return true


## 当前可用铺规槽数（由柜台等级决定）
func rule_slot_count() -> int:
	var counter_lv: int = area_level(&"counter")
	return COUNTER_LV_TO_SLOTS[counter_lv - 1]


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var lvls: Dictionary = {}
	for a in AREAS:
		lvls[String(a)] = _area_levels[a]
	return {"area_levels": lvls}


func from_dict(d: Dictionary) -> void:
	reset()
	var lvls: Dictionary = d.get("area_levels", {})
	for k in lvls:
		var area := StringName(k)
		if _area_levels.has(area):
			_area_levels[area] = clampi(int(lvls[k]), 1, MAX_LEVEL)
