extends Node
## 手写叙事卡片库 Autoload。
## - 按 trigger 分组缓存所有 NarrativeCard
## - pick_card(trigger, vars) 抽一张 + 占位符替换
## - _seen_first_visit 跟踪首次到访客人，避免重复触发同一 customer 的"首到"

# trigger int → Array[NarrativeCard]
var _by_trigger: Dictionary = {}
var _seen_first_visit: Dictionary = {}  # customer_id (String) -> true
var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_load_cards()


func _load_cards() -> void:
	_by_trigger.clear()
	for nid in DataRegistry.ids_of(&"narrative"):
		var c: NarrativeCard = DataRegistry.get_resource(&"narrative", nid) as NarrativeCard
		if c == null: continue
		var t: int = int(c.trigger)
		if not _by_trigger.has(t):
			_by_trigger[t] = []
		(_by_trigger[t] as Array).append(c)


## 按 trigger 抽一张，占位符 {key} 用 vars[key] 替换；返回空字符串表示无卡可用
func pick_card(trigger: int, vars: Dictionary = {}) -> String:
	var pool: Array = _by_trigger.get(trigger, [])
	if pool.is_empty():
		return ""
	var card: NarrativeCard = pool[_rng.randi() % pool.size()]
	return _format(card.body, vars)


## 首次到访专用：同 customer_id 不重复触发
func pick_first_visit(customer_id: StringName, customer_name: String) -> String:
	var key: String = String(customer_id)
	if _seen_first_visit.has(key):
		return ""
	_seen_first_visit[key] = true
	return pick_card(NarrativeCard.Trigger.CUSTOMER_FIRST, {"customer": customer_name})


static func _format(body: String, vars: Dictionary) -> String:
	var out: String = body
	for k in vars:
		out = out.replace("{%s}" % String(k), String(vars[k]))
	return out


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var seen_ser: Array = []
	for k in _seen_first_visit:
		seen_ser.append(k)
	return {"seen_first_visit": seen_ser}


func from_dict(d: Dictionary) -> void:
	_seen_first_visit.clear()
	for s in d.get("seen_first_visit", []):
		_seen_first_visit[String(s)] = true


func reset_seen() -> void:
	_seen_first_visit.clear()
