extends Control
## 战斗场景 UI（纯文字版）。
## - View 只读 CombatState，写操作只调 play_card / end_turn。
## - 状态变化全靠 CombatState 信号驱动；不轮询。
## - 退出战斗：emit 全局 EventBus.combat_ended，由路由层（city）切回主城。

@onready var enemy_name_label: Label = %EnemyName
@onready var enemy_hp_label: Label = %EnemyHP
@onready var enemy_intent_label: Label = %EnemyIntent
@onready var player_status_label: Label = %PlayerStatus
@onready var qi_label: Label = %QiLabel
@onready var log_view: RichTextLabel = %LogView
@onready var hand_row: HBoxContainer = %HandRow
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var leave_btn: Button = %LeaveBtn
@onready var flee_btn: Button = %FleeBtn

var _flee_dialog: ConfirmationDialog

var state: CombatState
var _finished: bool = false
var _victory: bool = false
var _current_encounter: EncounterData
var _reward_dialog: CardRewardDialog


func _ready() -> void:
	state = CombatState.new()
	state.log_pushed.connect(_on_log)
	state.phase_changed.connect(_on_phase)
	state.hand_changed.connect(_refresh_hand)
	state.qi_changed.connect(_on_qi)
	state.combat_finished.connect(_on_combat_finished)

	end_turn_btn.pressed.connect(_on_end_turn)
	leave_btn.pressed.connect(_on_leave)
	flee_btn.pressed.connect(_on_flee_pressed)
	# 战斗未结束时 leave 不可见
	leave_btn.visible = false
	flee_btn.visible = true

	# 取 encounter（默认 floor_01）
	var enc_id: StringName = GameState.current_encounter_id
	if String(enc_id) == "":
		enc_id = &"floor_01"
	_current_encounter = DataRegistry.get_resource(&"encounter", enc_id) as EncounterData

	# 玩家：用装备结算
	GameState.ensure_starter_deck()
	var stats: Dictionary = StatsResolver.resolve(GameState.equipped)
	stats["display_name"] = "外勤·你"
	stats["base_hp"] = 30
	stats["base_qi"] = 3
	var player := CombatUnit.make_player(stats)

	var enemy: CombatUnit
	if _current_encounter != null:
		var intent: String = _current_encounter.intent_pool[0] if not _current_encounter.intent_pool.is_empty() else "獠牙撕咬"
		enemy = CombatUnit.make_enemy(_current_encounter.id, _current_encounter.display_name,
			_current_encounter.hp, _current_encounter.atk, intent)
	else:
		enemy = CombatUnit.make_enemy(&"wandering_ghoul", "诡修·游魂", 24, 4, "怨气呼啸")

	var deck: Array = []
	for cid: StringName in GameState.owned_cards:
		var c: Resource = DataRegistry.get_resource(&"card", cid)
		if c != null:
			deck.append(c)
	if deck.is_empty():
		_on_log("[color=#e35d5d]数据异常：未能加载任何卡牌。[/color]")
		return
	state.setup(player, enemy, deck)
	_refresh_player()


# ── State 信号 ────────────────────────────────
func _on_log(rich: String) -> void:
	log_view.append_text(rich + "\n")


func _on_phase(phase: int) -> void:
	end_turn_btn.disabled = phase != CombatState.Phase.PLAYER_TURN
	_refresh_enemy()


func _on_qi(value: int, _maxv: int) -> void:
	qi_label.text = "灵气 %d / %d" % [value, state.player.qi_max]
	_refresh_hand()


func _refresh_player() -> void:
	if state.player == null:
		return
	var p: CombatUnit = state.player
	var text: String = "%s    HP %d/%d    格挡 %d" % [
		p.display_name, p.hp, p.hp_max, p.block,
	]
	var extras: Array[String] = []
	if abs(p.attack_mult - 1.0) > 0.001:
		extras.append("攻×%.2f" % p.attack_mult)
	if p.attack_flat != 0:
		extras.append("攻+%d" % p.attack_flat)
	if p.crit_chance > 0.0001:
		extras.append("暴%.0f%%" % (p.crit_chance * 100.0))
	if p.pollute_resist > 0.0001:
		extras.append("污抗%.0f%%" % (p.pollute_resist * 100.0))
	if not extras.is_empty():
		text += "    [" + "  ".join(extras) + "]"
	player_status_label.text = text
	qi_label.text = "灵气 %d / %d" % [p.qi, p.qi_max]


func _refresh_enemy() -> void:
	if state.enemy == null:
		return
	enemy_name_label.text = state.enemy.display_name
	enemy_hp_label.text = "HP %d / %d" % [state.enemy.hp, state.enemy.hp_max]
	enemy_intent_label.text = "意图：%s（约 %d 伤害）" % [state.enemy.intent_text, state.enemy.intent_damage]


func _refresh_hand() -> void:
	for c in hand_row.get_children():
		c.queue_free()
	for i in state.hand.size():
		var card: Resource = state.hand[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 110)
		btn.theme_type_variation = "CardButton"
		btn.text = "《%s》  ⚡%d\n%s" % [card.display_name, int(card.cost), String(card.description)]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.disabled = state.phase != CombatState.Phase.PLAYER_TURN or state.player.qi < int(card.cost)
		var idx := i
		btn.pressed.connect(func(): _on_play_card(idx))
		hand_row.add_child(btn)
	_refresh_player()
	_refresh_enemy()


func _on_play_card(i: int) -> void:
	state.play_card(i)
	_refresh_player()
	_refresh_enemy()


func _on_end_turn() -> void:
	state.end_turn()
	_refresh_player()
	_refresh_enemy()


func _on_combat_finished(victory: bool, loot: Dictionary) -> void:
	_finished = true
	_victory = victory
	end_turn_btn.disabled = true
	flee_btn.visible = false
	leave_btn.visible = true
	for c in hand_row.get_children():
		(c as Button).disabled = true

	var loot_items: Array = []
	if victory:
		# 灵石 / 见闻：encounter 决定
		var stones_min: int = 30
		var stones_max: int = 50
		var insight_p: float = 0.33
		if _current_encounter != null:
			stones_min = _current_encounter.spirit_stones_min
			stones_max = _current_encounter.spirit_stones_max
			insight_p = _current_encounter.insight_chance
		var stones: int = stones_min + randi() % max(1, stones_max - stones_min + 1)
		var insights: int = 1 if randf() < insight_p else 0
		GameState.add_currency(&"spirit_stones", stones)
		if insights > 0:
			GameState.add_currency(&"insights", insights)
		_on_log("[color=#9cd97c]获得 %d 灵石%s。[/color]" % [stones, "，并悟见闻 +1" if insights > 0 else ""])

		# 装备掉落
		if _current_encounter != null and not _current_encounter.loot_table.is_empty():
			var pick: Dictionary = LootRoller.pick_slot_and_base(_current_encounter.loot_table)
			if not pick.is_empty():
				var rarity: int = _current_encounter.rarity_hint
				if _current_encounter.tier == 2:
					rarity += 1
				rarity = clampi(rarity, 0, 4)
				var inst: GearInstance = LootRoller.roll_gear(pick["base_id"], rarity)
				GameState.add_to_inventory(inst)
				loot_items.append(inst)
				var color: Color = GearInstance.rarity_color(inst.rarity)
				var hex: String = "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
				var line: String = "[color=%s]掉落：%s" % [hex, inst.display_full_name()]
				for ln in inst.affix_lines():
					line += " · " + ln
				line += "[/color]"
				_on_log(line)

		# 塔进度
		if _current_encounter != null and String(GameState.current_encounter_id).begins_with("floor_"):
			GameState.tower_unlock_next()

		# 三选一加卡（每 2 层）
		if GameState.tower_floor % 2 == 0 and GameState.owned_cards.size() < GameState.DECK_HARD_CAP:
			_show_card_reward()
		else:
			_on_victory_idle()
	else:
		GameState.set_sanity(GameState.sanity - 10)
		leave_btn.text = "返回主城"
		leave_btn.grab_focus()

	EventBus.combat_ended.emit(victory, loot_items)
	SaveSystem.save_now(true)


func _show_card_reward() -> void:
	_reward_dialog = preload("res://scenes/ui/card_reward_dialog.tscn").instantiate()
	add_child(_reward_dialog)
	_reward_dialog.picked.connect(_on_card_picked)
	_reward_dialog.closed.connect(_on_reward_closed)
	_reward_dialog.popup_three_choices()


func _on_card_picked(cid: StringName) -> void:
	if GameState.add_card(cid):
		_on_log("[color=#9cd97c]加入卡组：《%s》[/color]" % String(cid))
	SaveSystem.save_now(true)


func _on_reward_closed() -> void:
	_on_victory_idle()


func _on_victory_idle() -> void:
	leave_btn.text = "返回塔（继续）"
	leave_btn.grab_focus()


func _on_leave() -> void:
	if _finished and _victory and String(GameState.current_encounter_id).begins_with("floor_"):
		get_tree().change_scene_to_file("res://scenes/tower.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/city.tscn")


func _on_flee_pressed() -> void:
	if _finished:
		return
	if _flee_dialog == null:
		_flee_dialog = ConfirmationDialog.new()
		_flee_dialog.dialog_text = "主动撤退视为败北：\n  · 道心 -10\n  · 无奖励\n确认撤退？"
		_flee_dialog.title = "撤退确认"
		_flee_dialog.confirmed.connect(_on_flee_confirmed)
		add_child(_flee_dialog)
	_flee_dialog.popup_centered()


func _on_flee_confirmed() -> void:
	if _finished or state == null:
		return
	state.flee()
