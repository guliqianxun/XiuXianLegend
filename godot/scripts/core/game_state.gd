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

# ── 材料栏 ────────────────────────────────────
## material_id (StringName) -> count (int)
var materials: Dictionary = {}

# ── 老铁今日手感 ──────────────────────────────
## 每日开局 ±5% 随机扰动，N2 暂用 1.0；N5 接入日历滚日触发
var smith_hand_today: float = 1.0

# ── 装备 / 库存 ────────────────────────────────
## slot_int -> GearInstance（保留供 N2 锻造使用）
var equipped: Dictionary = {}
## 库存：未派出的 GearInstance 列表
var inventory: Array = []

# ── 离线日记（铁炉小本）────────────────────────
## OfflineSimulator 在启动时填充，DiaryScreen 显示后清空。
## entry: { unix:int, shichen:int, kind:StringName, detail:String }
var offline_diary_pending: Array = []

# ── 已学到的客人特征（spec §7.3）─────────────────
## 打听 / 攻破后永久解锁；用于在 RulesScreen 生成精确条款
var learned_traits: Array[StringName] = []


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


# ── 材料栏 ────────────────────────────────────

func add_material(material_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var cur: int = int(materials.get(material_id, 0))
	materials[material_id] = cur + amount
	EventBus.materials_changed.emit(material_id, cur + amount)


## 尝试扣材料；不足返回 false，不修改任何字段
func consume_material(material_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var cur: int = int(materials.get(material_id, 0))
	if cur < amount:
		return false
	var new_val: int = cur - amount
	if new_val == 0:
		materials.erase(material_id)
	else:
		materials[material_id] = new_val
	EventBus.materials_changed.emit(material_id, new_val)
	return true


func material_count(material_id: StringName) -> int:
	return int(materials.get(material_id, 0))


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


# ── trait 学习 ────────────────────────────────
func learn_traits(list: Array) -> void:
	if list == null or list.is_empty(): return
	var added: Array[StringName] = []
	for t in list:
		var sn := StringName(t)
		if sn == &"": continue
		if not learned_traits.has(sn):
			learned_traits.append(sn)
			added.append(sn)
	if not added.is_empty():
		EventBus.traits_learned.emit(added)


func has_learned_trait(t: StringName) -> bool:
	return learned_traits.has(t)


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
	var mats_ser: Dictionary = {}
	for k in materials:
		mats_ser[String(k)] = materials[k]
	var diary_ser: Array = []
	for e in offline_diary_pending:
		var ed: Dictionary = e
		diary_ser.append({
			"unix": int(ed.get("unix", 0)),
			"shichen": int(ed.get("shichen", 0)),
			"kind": String(ed.get("kind", "")),
			"detail": String(ed.get("detail", "")),
		})
	var traits_ser: Array = []
	for t in learned_traits:
		traits_ser.append(String(t))
	return {
		"spirit_stones": spirit_stones,
		"insights": insights,
		"reputation": reputation,
		"last_settle_unix": last_settle_unix,
		"equipped": equipped_ser,
		"inventory": inv_ser,
		"materials": mats_ser,
		"smith_hand_today": smith_hand_today,
		"offline_diary_pending": diary_ser,
		"learned_traits": traits_ser,
	}


func from_dict(d: Dictionary) -> void:
	spirit_stones = int(d.get("spirit_stones", 0))
	insights = int(d.get("insights", 0))
	reputation = int(d.get("reputation", 0))
	last_settle_unix = int(d.get("last_settle_unix", 0))
	materials = {}
	var mats_raw: Dictionary = d.get("materials", {})
	for k in mats_raw:
		materials[StringName(k)] = int(mats_raw[k])
	smith_hand_today = float(d.get("smith_hand_today", 1.0))

	equipped = {}
	var eq_raw: Dictionary = d.get("equipped", {})
	for k in eq_raw:
		var inst := GearInstance.from_dict(eq_raw[k])
		equipped[int(str(k))] = inst
	inventory = []
	var inv_raw: Array = d.get("inventory", [])
	for it in inv_raw:
		inventory.append(GearInstance.from_dict(it))

	offline_diary_pending = []
	var diary_raw: Array = d.get("offline_diary_pending", [])
	for it in diary_raw:
		var ed: Dictionary = it
		offline_diary_pending.append({
			"unix": int(ed.get("unix", 0)),
			"shichen": int(ed.get("shichen", 0)),
			"kind": StringName(ed.get("kind", "")),
			"detail": String(ed.get("detail", "")),
		})

	learned_traits = []
	var traits_raw: Array = d.get("learned_traits", [])
	for s in traits_raw:
		learned_traits.append(StringName(s))
