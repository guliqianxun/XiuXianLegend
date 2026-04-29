extends Node
## 游戏运行时状态（Autoload 单例）。
## 只持有"现在的事实"，不持有静态配置（配置在 DataRegistry）。
## 修改字段必须 emit 对应 EventBus 信号，禁止 UI 直接读取后轮询。

# ── 货币 / 资源 ────────────────────────────────
var spirit_stones: int = 0       # 灵石
var insights: int = 0            # 见闻
var pollution: int = 0           # 污染（累计）
var pollution_cap: int = 100

# ── 道心（战斗外的长期值，战斗内单独一份） ────
var sanity: int = 100
var sanity_cap: int = 100

# ── 序列进度 ──────────────────────────────────
## path -> rank（9..0），未解锁不在字典里
var sequence_ranks: Dictionary = {}

# ── 时间 ──────────────────────────────────────
var last_settle_unix: int = 0    # 上次结算时间戳

# ── 赛季 ──────────────────────────────────────
var season_id: StringName = &"s0_origin"
var season_started_unix: int = 0

# ── 装备 / 背包 ────────────────────────────────
## slot_int(GearData.Slot) -> GearInstance
var equipped: Dictionary = {}
## 背包：未穿戴的 GearInstance 列表
var inventory: Array = []

# ── 卡组 ──────────────────────────────────────
## 玩家拥有的卡牌 id 列表（多张相同卡 = 多个相同 id）
var owned_cards: Array = []
const DECK_HARD_CAP: int = 12

# ── 妖谭塔 ────────────────────────────────────
var tower_floor: int = 1            ## 当前可挑战层
var tower_max_reached: int = 1      ## 历史最高（=1 表示第 1 层可打）
var current_encounter_id: StringName = &""

const STARTER_CARD_IDS: Array = [
	&"sword_strike", &"sword_strike", &"sword_strike",
	&"sword_focus", &"sword_focus",
	&"sword_dance",
]


func add_currency(kind: StringName, amount: int) -> void:
	match kind:
		&"spirit_stones":
			spirit_stones += amount
		&"insights":
			insights += amount
		_:
			push_warning("unknown currency: %s" % kind)
			return
	EventBus.currency_changed.emit(kind, _read_currency(kind))


## 尝试扣除货币；不足返回 false，不修改任何字段
func spend_currency(kind: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var cur: int = _read_currency(kind)
	if cur < amount:
		return false
	add_currency(kind, -amount)
	return true


func add_pollution(amount: int) -> void:
	pollution = clampi(pollution + amount, 0, pollution_cap)
	EventBus.pollution_changed.emit(pollution, pollution_cap)


func set_sanity(value: int) -> void:
	sanity = clampi(value, 0, sanity_cap)
	EventBus.sanity_changed.emit(sanity, sanity_cap)
	# 失败惩罚：若道心归 0，强制把 last_settle_unix 后推 1h（玩家被强制挂机）
	if sanity == 0:
		last_settle_unix = int(Time.get_unix_time_from_system()) + 3600


# ── 装备方法（唯一改值入口） ────────────────
func equip_gear(inst: GearInstance) -> void:
	if inst == null:
		return
	var base: GearData = inst.get_base()
	if base == null:
		return
	var slot: int = int(base.slot)
	# 若该 slot 已有装备，先卸到背包
	if equipped.has(slot) and equipped[slot] != null:
		inventory.append(equipped[slot])
	# 从背包里移除新穿的（如果在）
	inventory.erase(inst)
	equipped[slot] = inst
	EventBus.gear_equipped.emit(StringName(str(slot)), inst.base_id)


func unequip_slot(slot: int) -> void:
	if not equipped.has(slot) or equipped[slot] == null:
		return
	inventory.append(equipped[slot])
	equipped[slot] = null
	EventBus.gear_equipped.emit(StringName(str(slot)), &"")


func add_to_inventory(inst: GearInstance) -> void:
	if inst == null:
		return
	inventory.append(inst)
	EventBus.loot_dropped.emit([inst])


# ── 卡组方法 ──────────────────────────────────
func add_card(card_id: StringName) -> bool:
	if owned_cards.size() >= DECK_HARD_CAP:
		return false
	owned_cards.append(card_id)
	return true


func ensure_starter_deck() -> void:
	if owned_cards.is_empty():
		owned_cards = STARTER_CARD_IDS.duplicate()


# ── 妖谭塔方法 ────────────────────────────────
func tower_unlock_next() -> void:
	tower_max_reached = max(tower_max_reached, tower_floor + 1)
	if tower_max_reached > 10:
		tower_max_reached = 10
	# MINOR-2: 同步推进 tower_floor 到下一层（不超过 max_reached / 10）
	tower_floor = min(tower_floor + 1, tower_max_reached, 10)


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
	var owned_ser: Array = []
	for cid in owned_cards:
		owned_ser.append(String(cid))
	return {
		"spirit_stones": spirit_stones,
		"insights": insights,
		"pollution": pollution,
		"pollution_cap": pollution_cap,
		"sanity": sanity,
		"sanity_cap": sanity_cap,
		"sequence_ranks": sequence_ranks,
		"last_settle_unix": last_settle_unix,
		"season_id": String(season_id),
		"season_started_unix": season_started_unix,
		"equipped": equipped_ser,
		"inventory": inv_ser,
		"owned_cards": owned_ser,
		"tower_floor": tower_floor,
		"tower_max_reached": tower_max_reached,
	}


func from_dict(d: Dictionary) -> void:
	spirit_stones = int(d.get("spirit_stones", 0))
	insights = int(d.get("insights", 0))
	pollution = int(d.get("pollution", 0))
	pollution_cap = int(d.get("pollution_cap", 100))
	sanity = int(d.get("sanity", 100))
	sanity_cap = int(d.get("sanity_cap", 100))
	sequence_ranks = d.get("sequence_ranks", {})
	last_settle_unix = int(d.get("last_settle_unix", 0))
	season_id = StringName(d.get("season_id", "s0_origin"))
	season_started_unix = int(d.get("season_started_unix", 0))

	equipped = {}
	var eq_raw: Dictionary = d.get("equipped", {})
	for k in eq_raw:
		var inst := GearInstance.from_dict(eq_raw[k])
		equipped[int(str(k))] = inst
	inventory = []
	var inv_raw: Array = d.get("inventory", [])
	for it in inv_raw:
		inventory.append(GearInstance.from_dict(it))

	owned_cards = []
	var oc_raw: Array = d.get("owned_cards", [])
	for s in oc_raw:
		owned_cards.append(StringName(s))
	if owned_cards.is_empty():
		ensure_starter_deck()

	tower_floor = int(d.get("tower_floor", 1))
	tower_max_reached = int(d.get("tower_max_reached", 1))
