extends Node
## MVP 完整循环回归测试。
## 运行：godot --headless --path godot res://scenes/playtest.tscn
## 自动跑完后调 get_tree().quit()。

var _passed: int = 0
var _failed: int = 0
var _captured_log: Array[String] = []
var _last_inst: GearInstance = null


func _ready() -> void:
	# 让 autoload 走完 _ready
	await get_tree().process_frame
	_run_all()
	print("\n========== RESULT ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit()


func _ok(msg: String) -> void:
	_passed += 1
	print("[PASS] " + msg)


func _bad(msg: String) -> void:
	_failed += 1
	print("[FAIL] " + msg)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_ok(msg)
	else:
		_bad(msg)


func _run_all() -> void:
	_step_1_load_or_init()
	_step_2_starter_deck()
	_step_3_idle_settle()
	_step_4_first_combat()
	_step_5_loot_roll()
	_step_6_equip_stats()
	_step_7_combat_with_gear()
	_step_8_tower_progress()
	_step_9_defeat_sanity()
	_step_10_reroll()
	_step_11_persistence()


# ── 1 ────────────────────────────────────────────
func _step_1_load_or_init() -> void:
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	# 重置内存到初始
	GameState.spirit_stones = 0
	GameState.insights = 0
	GameState.pollution = 0
	GameState.sanity = 100
	GameState.equipped = {}
	GameState.inventory = []
	GameState.owned_cards = []
	GameState.tower_floor = 1
	GameState.tower_max_reached = 1
	GameState.last_settle_unix = 0
	SaveSystem.load_or_init()
	_assert(GameState.last_settle_unix > 0, "1) load_or_init 设定 last_settle_unix")


# ── 2 ────────────────────────────────────────────
func _step_2_starter_deck() -> void:
	_assert(GameState.owned_cards.size() == 6, "2) starter deck size == 6 (got %d)" % GameState.owned_cards.size())
	var miss: Array = []
	for cid in GameState.owned_cards:
		var c: Resource = DataRegistry.get_resource(&"card", cid)
		if c == null:
			miss.append(String(cid))
	_assert(miss.is_empty(), "2) starter cards 全部可加载 (missing: %s)" % str(miss))


# ── 3 ────────────────────────────────────────────
func _step_3_idle_settle() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	GameState.last_settle_unix = now - 7200
	var rep: Dictionary = IdleSettlement.settle(now, GameState.last_settle_unix)
	var stones: int = int(rep.get("spirit_stones", 0))
	GameState.add_currency(&"spirit_stones", stones)
	GameState.add_pollution(int(rep.get("pollution", 0)))
	GameState.last_settle_unix = now
	_assert(stones > 0, "3) 离线 2h 灵石 > 0 (got %d)" % stones)
	_assert(float(rep.get("effective_hours", 0.0)) > 1.5, "3) effective_hours ~ 2.0")


# ── 4 ────────────────────────────────────────────
func _build_deck() -> Array:
	var deck: Array = []
	for cid: StringName in GameState.owned_cards:
		var c: Resource = DataRegistry.get_resource(&"card", cid)
		if c != null:
			deck.append(c)
	return deck


func _make_combat_for_floor(floor_id: StringName, stats: Dictionary = {}) -> CombatState:
	var enc: EncounterData = DataRegistry.get_resource(&"encounter", floor_id) as EncounterData
	if enc == null:
		return null
	var st: Dictionary = stats.duplicate()
	st["display_name"] = "外勤·你"
	st["base_hp"] = 30
	st["base_qi"] = 3
	var player := CombatUnit.make_player(st)
	var enemy: CombatUnit = CombatUnit.make_enemy(enc.id, enc.display_name, enc.hp, enc.atk, enc.intent_pool[0])
	var cs := CombatState.new()
	cs.log_pushed.connect(func(s): _captured_log.append(s))
	cs.setup(player, enemy, _build_deck())
	return cs


func _ai_play_one_turn(cs: CombatState) -> void:
	var safety: int = 30
	while cs.phase == CombatState.Phase.PLAYER_TURN and safety > 0:
		safety -= 1
		var picked: int = -1
		for i in cs.hand.size():
			var c: Resource = cs.hand[i]
			if int(c.cost) > cs.player.qi:
				continue
			for fx in c.effects:
				if fx is DamageEffect:
					picked = i
					break
			if picked >= 0:
				break
		if picked < 0:
			for i in cs.hand.size():
				if int(cs.hand[i].cost) <= cs.player.qi:
					picked = i
					break
		if picked < 0:
			cs.end_turn()
			return
		cs.play_card(picked)


func _run_full_combat(cs: CombatState, max_turns: int = 60) -> bool:
	var turn: int = 0
	while cs.phase != CombatState.Phase.END and turn < max_turns:
		turn += 1
		_ai_play_one_turn(cs)
	return cs.phase == CombatState.Phase.END and (cs.enemy == null or not cs.enemy.is_alive())


func _step_4_first_combat() -> void:
	_captured_log.clear()
	var cs := _make_combat_for_floor(&"floor_01")
	if cs == null:
		_bad("4) 无法构造 combat for floor_01")
		return
	var seq_seen_player := cs.phase == CombatState.Phase.PLAYER_TURN
	cs.phase_changed.connect(func(p):
		if p == CombatState.Phase.PLAYER_TURN:
			seq_seen_player = true
	)
	var won := _run_full_combat(cs)
	_assert(seq_seen_player, "4) 进入过 PLAYER_TURN")
	_assert(cs.phase == CombatState.Phase.END, "4) 战斗到达 END")
	_assert(won, "4) 第 1 层胜利 (空装备 starter deck)")


# ── 5 ────────────────────────────────────────────
func _step_5_loot_roll() -> void:
	var inst: GearInstance = LootRoller.roll_gear(&"rusty_sword", 1)
	_assert(inst != null and inst.base_id == &"rusty_sword", "5) roll_gear 返回 instance")
	_assert(inst.affix_ids.size() == inst.affix_values.size(), "5) affix_ids/values 长度对齐")
	_assert(inst.affix_ids.size() == 2, "5) rarity=1 期望 2 词缀 (got %d)" % inst.affix_ids.size())
	_last_inst = inst


# ── 6 ────────────────────────────────────────────
func _step_6_equip_stats() -> void:
	var inst: GearInstance = LootRoller.roll_gear(&"bloodfang_sword", 2)
	GameState.add_to_inventory(inst)
	GameState.equip_gear(inst)
	var stats: Dictionary = StatsResolver.resolve(GameState.equipped)
	var amul: float = float(stats.get("attack_mult", 1.0))
	var afl: int = int(stats.get("attack_flat", 0))
	_assert(amul > 1.0 or afl > 0, "6) 装备产生加成 (mult=%.2f flat=%d)" % [amul, afl])


# ── 7 ────────────────────────────────────────────
func _step_7_combat_with_gear() -> void:
	_captured_log.clear()
	var stats: Dictionary = StatsResolver.resolve(GameState.equipped)
	var cs := _make_combat_for_floor(&"floor_01", stats)
	var won := _run_full_combat(cs)
	_assert(won, "7) 带装备再打 floor_01 仍胜利")
	var has_marker := false
	for line in _captured_log:
		if line.find("[装备]") >= 0 or line.find("暴击") >= 0:
			has_marker = true
			break
	_assert(has_marker, "7) 战斗日志含 [装备] 或 暴击 字样")


# ── 8 ────────────────────────────────────────────
func _step_8_tower_progress() -> void:
	GameState.tower_floor = 1
	GameState.tower_max_reached = 1
	for f in range(1, 6):
		GameState.tower_floor = f
		GameState.tower_unlock_next()
	_assert(GameState.tower_max_reached == 6, "8) 5 连胜 tower_max_reached==6 (got %d)" % GameState.tower_max_reached)


# ── 9 ────────────────────────────────────────────
func _step_9_defeat_sanity() -> void:
	GameState.sanity = 100
	var sanity_before: int = GameState.sanity
	var settle_before: int = GameState.last_settle_unix
	GameState.set_sanity(GameState.sanity - 10)
	_assert(GameState.sanity == sanity_before - 10, "9) 失败 sanity -10 (now %d)" % GameState.sanity)
	GameState.set_sanity(0)
	_assert(GameState.last_settle_unix > settle_before + 3500, "9) sanity==0 时 last_settle_unix 后推 1h")


# ── 10 ───────────────────────────────────────────
func _step_10_reroll() -> void:
	if _last_inst == null:
		_bad("10) 缺 _last_inst，跳过 reroll")
		return
	var before_ids: Array = _last_inst.affix_ids.duplicate()
	var before_vals: Array = _last_inst.affix_values.duplicate()
	var changed := false
	for i in 5:
		LootRoller.reroll(_last_inst)
		if _last_inst.affix_ids != before_ids or _last_inst.affix_values != before_vals:
			changed = true
			break
	_assert(changed, "10) reroll 后 affix 改变")


# ── 11 ───────────────────────────────────────────
func _step_11_persistence() -> void:
	GameState.spirit_stones = 12345
	GameState.tower_floor = 4
	GameState.tower_max_reached = 5
	if GameState.inventory.is_empty():
		GameState.add_to_inventory(LootRoller.roll_gear(&"warding_talisman", 1))

	var owned_before: Array = GameState.owned_cards.duplicate()
	var inv_count: int = GameState.inventory.size()
	var equipped_count: int = 0
	for k in GameState.equipped:
		if GameState.equipped[k] != null:
			equipped_count += 1

	SaveSystem.save_now(true)

	GameState.spirit_stones = 0
	GameState.owned_cards = []
	GameState.inventory = []
	GameState.equipped = {}
	GameState.tower_floor = 1
	GameState.tower_max_reached = 1

	SaveSystem.load_or_init()

	_assert(GameState.spirit_stones == 12345, "11) 灵石持久化 (got %d)" % GameState.spirit_stones)
	_assert(GameState.tower_floor == 4, "11) tower_floor==4")
	_assert(GameState.tower_max_reached == 5, "11) tower_max_reached==5")
	_assert(GameState.owned_cards == owned_before, "11) owned_cards 一致")
	_assert(GameState.inventory.size() == inv_count, "11) inventory 数量一致 (%d vs %d)" % [GameState.inventory.size(), inv_count])
	var eq_after := 0
	for k in GameState.equipped:
		if GameState.equipped[k] != null:
			eq_after += 1
	_assert(eq_after == equipped_count, "11) equipped 数量一致 (%d vs %d)" % [eq_after, equipped_count])
