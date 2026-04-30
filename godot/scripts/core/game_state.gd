extends Node
## 游戏运行时状态（Autoload 单例）。
## 只持有"现在的事实"，不持有静态配置（配置在 DataRegistry）。
## 修改字段必须 emit 对应 EventBus 信号；UI 不得直接读后轮询。

# ── 货币 ──────────────────────────────────────
var spirit_stones: int = 0       # 灵石
var insights: int = 0            # 见闻

# ── 声誉 ──────────────────────────────────────
var reputation: int = 0          # 名望（接客/留赏积累，影响来客质量）

# ── 时间 ──────────────────────────────────────
var last_settle_unix: int = 0    # 上次结算时间戳（用于离线产出计算）

# ── 装备 / 库存 ────────────────────────────────
## slot_int -> GearInstance（保留供 N2 锻造使用）
var equipped: Dictionary = {}
## 库存：未派出的 GearInstance 列表
var inventory: Array = []


func add_currency(kind: StringName, amount: int) -> void:
	match kind:
		&"spirit_stones": spirit_stones += amount
		&"insights": insights += amount
		_:
			push_warning("unknown currency: %s" % kind)
			return
	EventBus.currency_changed.emit(kind, _read_currency(kind))


func spend_currency(kind: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var cur: int = _read_currency(kind)
	if cur < amount:
		return false
	add_currency(kind, -amount)
	return true


func add_reputation(delta: int) -> void:
	reputation = max(0, reputation + delta)
	EventBus.reputation_changed.emit(reputation)


# ── 装备方法 ──────────────────────────────────
func equip_gear(inst: GearInstance) -> void:
	if inst == null: return
	var base: GearData = inst.get_base()
	if base == null: return
	var slot: int = int(base.slot)
	if equipped.has(slot) and equipped[slot] != null:
		inventory.append(equipped[slot])
	inventory.erase(inst)
	equipped[slot] = inst
	EventBus.gear_equipped.emit(StringName(str(slot)), inst.base_id)


func unequip_slot(slot: int) -> void:
	if not equipped.has(slot) or equipped[slot] == null: return
	inventory.append(equipped[slot])
	equipped[slot] = null
	EventBus.gear_equipped.emit(StringName(str(slot)), &"")


func add_to_inventory(inst: GearInstance) -> void:
	if inst == null: return
	inventory.append(inst)
	EventBus.loot_dropped.emit([inst])


func _read_currency(kind: StringName) -> int:
	match kind:
		&"spirit_stones": return spirit_stones
		&"insights": return insights
		_: return 0


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var equipped_ser: Dictionary = {}
	for slot in equipped:
		var inst: GearInstance = equipped[slot]
		if inst != null:
			equipped_ser[str(slot)] = inst.to_dict()
	var inv_ser: Array = []
	for inst: GearInstance in inventory:
		if inst != null:
			inv_ser.append(inst.to_dict())
	return {
		"spirit_stones": spirit_stones,
		"insights": insights,
		"reputation": reputation,
		"last_settle_unix": last_settle_unix,
		"equipped": equipped_ser,
		"inventory": inv_ser,
	}


func from_dict(d: Dictionary) -> void:
	spirit_stones = int(d.get("spirit_stones", 0))
	insights = int(d.get("insights", 0))
	reputation = int(d.get("reputation", 0))
	last_settle_unix = int(d.get("last_settle_unix", 0))

	equipped = {}
	var eq_raw: Dictionary = d.get("equipped", {})
	for k in eq_raw:
		var inst := GearInstance.from_dict(eq_raw[k])
		equipped[int(str(k))] = inst
	inventory = []
	var inv_raw: Array = d.get("inventory", [])
	for it in inv_raw:
		inventory.append(GearInstance.from_dict(it))
