class_name CombatState
extends RefCounted
## 战斗状态机（回合制简化版，ATB 后续再加）。
## 流程：start → player_turn (loop) → enemy_turn → ... → end(victory|defeat)
## UI 仅订阅信号 / 调用 play_card / end_turn / get_*，禁止改内部数组。

enum Phase { START, PLAYER_TURN, ENEMY_TURN, END }

signal log_pushed(rich_text: String)
signal phase_changed(phase: Phase)
signal hand_changed()
signal qi_changed(value: int, maxv: int)
signal combat_finished(victory: bool, loot: Dictionary)

const HAND_SIZE := 5

var phase: Phase = Phase.START
var player: CombatUnit
var enemy: CombatUnit

# 卡组 / 手牌 / 弃牌 — 元素都是 CardData
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

var _turn_count: int = 0
var _enemy_base_atk: int = 1


func setup(player_unit: CombatUnit, enemy_unit: CombatUnit, deck: Array) -> void:
	player = player_unit
	enemy = enemy_unit
	_enemy_base_atk = enemy.intent_damage
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	phase = Phase.START
	_emit_log("[color=#b0b0b0]—— 战斗开始：%s 现身 ——[/color]" % enemy.display_name)
	_roll_enemy_intent()
	_begin_player_turn()


func _begin_player_turn() -> void:
	_turn_count += 1
	player.start_turn()
	_draw(HAND_SIZE - hand.size())
	phase = Phase.PLAYER_TURN
	phase_changed.emit(phase)
	qi_changed.emit(player.qi, player.qi_max)
	hand_changed.emit()
	_emit_log("[color=#e0c878]── 第 %d 回合 · 你的回合（灵气 %d）──[/color]" % [_turn_count, player.qi])


func play_card(hand_index: int) -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Resource = hand[hand_index]
	var cost: int = int(card.cost)
	if player.qi < cost:
		_emit_log("[color=#a0a0a0]灵气不足，无法施展《%s》。[/color]" % card.display_name)
		return false

	player.qi -= cost
	hand.remove_at(hand_index)
	discard_pile.append(card)

	_emit_log("[color=#cccccc]你施展《%s》。[/color]" % card.display_name)
	var ctx := {
		"state": self,
		"source": player,
		"target": enemy,
		"log": Callable(self, "_emit_log"),
	}
	for fx: CardEffect in card.effects:
		fx.apply(ctx)

	# 卡内污染
	if int(card.pollute_on_play) > 0:
		GameState.add_pollution(int(card.pollute_on_play))

	qi_changed.emit(player.qi, player.qi_max)
	hand_changed.emit()
	EventBus.card_played.emit(card.id, player, enemy)

	if not enemy.is_alive():
		_finish(true)
		return true
	return true


func end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	# 弃光手牌（标准 deckbuilder 风格）
	for c in hand:
		discard_pile.append(c)
	hand.clear()
	hand_changed.emit()
	_run_enemy_turn()


func _run_enemy_turn() -> void:
	phase = Phase.ENEMY_TURN
	phase_changed.emit(phase)
	if not enemy.is_alive():
		_finish(true)
		return
	_emit_log("[color=#a060a0]%s：%s。[/color]" % [enemy.display_name, enemy.intent_text])
	var ctx := {
		"state": self,
		"source": enemy,
		"target": player,
		"log": Callable(self, "_emit_log"),
	}
	var atk: DamageEffect = DamageEffect.new()
	atk.amount = enemy.intent_damage
	atk.apply(ctx)

	if not player.is_alive():
		_finish(false)
		return
	_roll_enemy_intent()
	_begin_player_turn()


func _roll_enemy_intent() -> void:
	# 简单波动：以 setup 时记录的 base 为基线，避免逐回合通胀
	enemy.intent_damage = max(1, _enemy_base_atk + (randi() % 3) - 1)
	enemy.intent_text = ["獠牙撕咬", "怨气呼啸", "残影一击"].pick_random()


func _draw(n: int) -> void:
	for i in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
			_emit_log("[color=#888888]（弃牌堆洗回。）[/color]")
		hand.append(draw_pile.pop_back())


func _finish(victory: bool) -> void:
	phase = Phase.END
	phase_changed.emit(phase)
	# MINOR-6: loot 由 UI 层基于 encounter 发放，这里仅 emit 空 dict
	var loot := {}
	if victory:
		_emit_log("[color=#9cd97c]—— 胜！ ——[/color]")
	else:
		_emit_log("[color=#e35d5d]—— 败！道心受创 -10 ——[/color]")
	combat_finished.emit(victory, loot)


## MAJOR-3：玩家主动撤退，走完整失败流（落 sanity / 同 _finish(false)）
func flee() -> void:
	if phase == Phase.END:
		return
	_emit_log("[color=#a0a0a0]—— 你选择撤退 ——[/color]")
	_finish(false)


func _emit_log(s: String) -> void:
	log_pushed.emit(s)
