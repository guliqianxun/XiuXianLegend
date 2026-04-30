extends Node
## 客人遭遇状态 Autoload。
## - 当前 pending 客人请求（一次只能有一位访客等待回应；下一位排队）
## - 已借出装备的 pending 记录（gear → {customer_id, lent_unix, due_unix}）
## - 序列化只存 pending；装备本身在 GameState.inventory（同 N3 codex 模式）

## 当前等待玩家回应的客人请求（CustomerRequest 实例 或 null）
var pending_request: CustomerRequest = null

## 已借出 pending: gear_key (base_id|seed) -> { customer_id, lent_unix, due_unix }
var _lent: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	pending_request = null
	_lent.clear()


# ── 借出 ──────────────────────────────────────

func lend(customer_id: StringName, gear: GearInstance, lent_unix: int, duration_sec: int) -> void:
	if gear == null: return
	gear.status = GearInstance.Status.LENT
	gear.history.append({
		"unix": lent_unix,
		"event": "lent",
		"detail": String(customer_id),
	})
	var key: String = _gear_key(gear)
	_lent[key] = {
		"customer_id": String(customer_id),
		"lent_unix": lent_unix,
		"due_unix": lent_unix + duration_sec,
	}
	EventBus.equipment_lent.emit(customer_id, gear)


# ── 归还 ──────────────────────────────────────

func resolve_return(gear: GearInstance, outcome: int, returned_unix: int) -> void:
	if gear == null: return
	var key: String = _gear_key(gear)
	var record: Dictionary = _lent.get(key, {})
	var customer_id: String = str(record.get("customer_id", ""))
	# 状态映射
	match outcome:
		ReturnResolver.Outcome.OK_RETURN, ReturnResolver.Outcome.GREAT_DEED:
			gear.status = GearInstance.Status.IN_SHOP
		ReturnResolver.Outcome.DAMAGED:
			gear.status = GearInstance.Status.DAMAGED
		ReturnResolver.Outcome.MUTATED:
			gear.status = GearInstance.Status.MUTATED
		ReturnResolver.Outcome.NOT_RETURNED:
			gear.status = GearInstance.Status.NOT_RETURNED
		_:
			gear.status = GearInstance.Status.IN_SHOP
	# 履历追加
	gear.history.append({
		"unix": returned_unix,
		"event": "returned",
		"detail": ReturnResolver.outcome_text(outcome),
	})
	# 移出 pending
	_lent.erase(key)
	EventBus.equipment_returned.emit(StringName(customer_id), gear, StringName(ReturnResolver.outcome_text(outcome)))


func lent_count() -> int:
	return _lent.size()


func is_lent(gear: GearInstance) -> bool:
	if gear == null: return false
	return _lent.has(_gear_key(gear))


# ── 序列化 ────────────────────────────────────

func to_dict() -> Dictionary:
	var pending: Array = []
	for key in _lent:
		var rec: Dictionary = _lent[key]
		pending.append({
			"gear_key": key,
			"customer_id": rec["customer_id"],
			"lent_unix": rec["lent_unix"],
			"due_unix": rec["due_unix"],
		})
	return {
		"pending_lends": pending,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	var pending: Array = d.get("pending_lends", [])
	for entry in pending:
		var key: String = str(entry.get("gear_key", ""))
		if key == "": continue
		_lent[key] = {
			"customer_id": str(entry.get("customer_id", "")),
			"lent_unix": int(entry.get("lent_unix", 0)),
			"due_unix": int(entry.get("due_unix", 0)),
		}


static func _gear_key(gear: GearInstance) -> String:
	return "%s|%d" % [String(gear.base_id), gear.seed]
