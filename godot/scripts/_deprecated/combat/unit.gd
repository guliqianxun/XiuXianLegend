class_name CombatUnit
extends RefCounted
## 战斗单位（玩家 / 敌人）。RefCounted 不进场景树，由 CombatState 管理生命周期。
## 任何状态变化通过 EventBus.unit_damaged / unit_died 广播给 UI，单位不持有 UI 引用。

enum Side { PLAYER, ENEMY }

var id: StringName
var display_name: String
var side: int = Side.ENEMY  ## 用 int 而非 Side：避免 class_name 自引用解析 quirk

var hp: int = 30
var hp_max: int = 30
var block: int = 0                    ## 临时格挡，回合开始清零

# 资源（仅玩家用）
var qi: int = 3
var qi_per_turn: int = 3
var qi_max: int = 9

# 攻击意图（敌人 AI）：每回合宣告一次
var intent_damage: int = 0
var intent_text: String = ""

# 装备衍生属性（仅玩家用，敌人保持默认值）
var attack_mult: float = 1.0
var attack_flat: int = 0
var crit_chance: float = 0.0
var extra_qi_max: int = 0
var pollute_resist: float = 0.0


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int, kind: StringName = &"physical") -> int:
	if amount <= 0:
		return 0
	var absorbed: int = mini(block, amount)
	block -= absorbed
	var actual: int = amount - absorbed
	hp = max(0, hp - actual)
	EventBus.unit_damaged.emit(self, actual, kind)
	if hp == 0:
		EventBus.unit_died.emit(self)
	return actual


func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var before: int = hp
	hp = mini(hp_max, hp + amount)
	return hp - before


func add_block(amount: int) -> void:
	block += max(0, amount)


func start_turn() -> void:
	block = 0
	if side == Side.PLAYER:
		qi = mini(qi_max, qi_per_turn)


static func make_player(stats: Dictionary = {}) -> CombatUnit:
	var u := CombatUnit.new()
	u.id = &"player"
	u.display_name = String(stats.get("display_name", "外勤·你"))
	u.side = Side.PLAYER
	var base_hp: int = int(stats.get("base_hp", 30))
	var hp_bonus: int = int(stats.get("hp_max_bonus", 0))
	u.hp_max = base_hp + hp_bonus
	u.hp = u.hp_max
	var base_qi: int = int(stats.get("base_qi", 3))
	var qi_bonus: int = int(stats.get("qi_max_bonus", 0))
	u.qi_per_turn = base_qi
	u.qi_max = max(base_qi, 9 + qi_bonus)
	u.qi = base_qi
	u.attack_mult = float(stats.get("attack_mult", 1.0))
	u.attack_flat = int(stats.get("attack_flat", 0))
	u.crit_chance = float(stats.get("crit_chance", 0.0))
	u.extra_qi_max = qi_bonus
	u.pollute_resist = float(stats.get("pollute_resist", 0.0))
	return u


static func make_enemy(id_: StringName, name: String, hp_v: int, atk: int, intent: String = "獠牙撕咬") -> CombatUnit:
	var u := CombatUnit.new()
	u.id = id_
	u.display_name = name
	u.side = Side.ENEMY
	u.hp = hp_v
	u.hp_max = hp_v
	u.intent_damage = atk
	u.intent_text = intent
	return u
