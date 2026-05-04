extends Node2D
## 铺子主场景控制器。
## 4 区域 placeholder：炉房 / 柜台 / 阁楼 / 后院。
## N1 仅显示 + 老铁站位 + 时辰 HUD；交互留给后续 milestone。

## 4 区域中老铁的"站位"坐标（相对于场景原点；避开炉房中央按钮）
## 这些是 1280×720 基准；实际 viewport 不同时由 _layout_for_viewport 重算
const AREA_POSITIONS: Dictionary = {
	&"furnace": Vector2(150, 490),
	&"counter": Vector2(640, 490),
	&"loft":    Vector2(640, 110),
	&"yard":    Vector2(960, 490),
}

## 4 卷宗在 viewport 上的相对中心位置（vp 比例 0..1）+ 卡尺寸 base
const CARD_LAYOUT: Dictionary = {
	&"forge":   Vector2(0.20, 0.40),
	&"counter": Vector2(0.65, 0.40),
	&"codex":   Vector2(0.25, 0.75),
	&"rules":   Vector2(0.70, 0.75),
}

@onready var _old_iron: Node2D = $OldIron
@onready var _background: ColorRect = $Background
@onready var _hud_canvas: CanvasLayer = $HUD
@onready var _hud_time: Label = $HUD/HudFrame/VBox/TimeRow/TimeLabel
@onready var _hud_money: Label = $HUD/HudFrame/VBox/MoneyLabel
@onready var _hud_reputation: Label = $HUD/HudFrame/VBox/ReputationLabel
@onready var _hud_brush: Label = $HUD/HudFrame/VBox/BrushLabel
@onready var _hud_codex: Label = $HUD/HudFrame/VBox/CodexLabel
@onready var _hud_rules: Label = $HUD/RulesFrame/RulesLabel
@onready var _card_forge: ScrollCard = $ScrollCardForge
@onready var _forge_screen: ForgeScreen = $ForgeScreen
@onready var _card_codex: ScrollCard = $ScrollCardCodex
@onready var _codex_screen: CodexScreen = $CodexScreen
@onready var _card_counter: ScrollCard = $ScrollCardCounter
@onready var _door_visual: DoorVisual = $ScrollCardCounter/DoorVisual
@onready var _customer_panel: CustomerArrivalPanel = $CustomerArrivalPanel
@onready var _lend_dialog: LendDialog = $LendDialog
@onready var _return_notice: ReturnNotice = $ReturnNotice
@onready var _diary_screen: DiaryScreen = $DiaryScreen
@onready var _rules_screen: RulesScreen = $RulesScreen
@onready var _narrative_overlay: NarrativeOverlay = $NarrativeOverlay
@onready var _event_log_panel: EventLogPanel = $EventLogPanel
@onready var _event_log_screen: EventLogScreen = $EventLogScreen
@onready var _card_rules: ScrollCard = $ScrollCardRules


func _ready() -> void:
	# 强制所有覆盖层 UI 占满 viewport 并隐藏。
	# 即使 CustomerArrivalPanel/ReturnNotice 视觉只占部分屏幕，仍需 size = viewport
	# 让其内部 anchors_preset (12=底部宽 / 5=居中上) 正确定位（Control 在 Node2D
	# 父下 anchors 全失效）。
	var vp_size: Vector2 = get_viewport_rect().size
	for screen in [_forge_screen, _codex_screen, _lend_dialog, _customer_panel, _return_notice, _diary_screen, _rules_screen, _narrative_overlay]:
		screen.position = Vector2.ZERO
		screen.size = vp_size
		screen.visible = false
	# 多分辨率：响应窗口尺寸变化重布局（老铁位置由 _layout_for_viewport 安排）
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()
	# 全屏 modal 弹出时隐藏 HUD（避免与 modal 角部按钮重叠）
	for modal in [_forge_screen, _codex_screen, _diary_screen, _rules_screen]:
		modal.visibility_changed.connect(_refresh_hud_visibility)
	# 启动后立即载档
	SaveSystem.load_or_init()
	# 给玩家点初始材料用于试炉（仅在 inventory 为空时）
	_seed_starter_materials()
	# 离线积分：从 last_settle_unix 算到现在，模拟事件 → 写入 diary_pending
	_run_offline_settlement()
	# 接信号刷 HUD + 锻造完成 + 客人来访 + 装备归来
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.forge_finished.connect(_on_forge_finished)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.equipment_returned.connect(_on_equipment_returned)
	EventBus.resonance_activated.connect(_on_resonance_activated_narrative)
	EventBus.identity_fragment_unlocked.connect(_on_identity_fragment_unlocked)
	EventBus.traits_learned.connect(_on_traits_learned_sfx)
	EventBus.weird_codex_recorded.connect(_on_weird_codex_recorded_sfx)
	# HUD 刷新钩子（spec 反馈：状态全部常驻可见）
	EventBus.reputation_changed.connect(func(_v: int) -> void: _refresh_hud())
	EventBus.star_brushes_changed.connect(func(_v: int) -> void: _refresh_hud())
	EventBus.resonance_activated.connect(func(_g: StringName, _p: StringName) -> void: _refresh_hud())
	EventBus.weird_codex_recorded.connect(func(_f: StringName, _t: int) -> void: _refresh_hud())
	EventBus.shop_rule_changed.connect(func(_i: int) -> void: _refresh_hud())
	# 4 区域按钮
	_card_forge.opened.connect(_on_open_forge)
	_card_codex.opened.connect(_on_open_codex)
	_card_counter.opened.connect(_on_open_counter)
	_card_rules.opened.connect(_on_open_rules)
	# Customer 流程
	_customer_panel.lend_pressed.connect(_on_customer_lend)
	_customer_panel.refuse_pressed.connect(_on_customer_refuse)
	_lend_dialog.gear_chosen.connect(_on_gear_chosen)
	# 事件流"看全本"按钮：连到展开 screen
	if _event_log_panel != null:
		_event_log_panel.set_expand_handler(func() -> void: _event_log_screen.open())
	# 启动后弹出小本（如果有未读条目）
	if not GameState.offline_diary_pending.is_empty():
		_diary_screen.open(GameState.offline_diary_pending.duplicate())
	# 卷宗近况实时刷新
	EventBus.forge_finished.connect(func(_g: Variant, _q: bool, _b: bool) -> void: _refresh_card_forge())
	EventBus.resonance_activated.connect(func(_g: StringName, _p: StringName) -> void: _refresh_card_codex())
	EventBus.codex_changed.connect(func(_g: StringName) -> void: _refresh_card_codex())
	EventBus.shop_rule_changed.connect(func(_i: int) -> void: _refresh_card_rules())
	_refresh_card_forge()
	_refresh_card_codex()
	_refresh_card_rules()
	_refresh_hud()


const COUNTER_FAIL_THROTTLE_SEC := 1.5
const RECENT_FORGE_LOOKBACK := 10
var _last_counter_fail_unix: float = -10.0
const _GUPU_IDS: Array[StringName] = [&"qing_long", &"xuan_wu", &"zhu_que", &"bai_hu", &"zi_wei", &"xue_yao", &"can_xiu"]


func _refresh_hud_visibility() -> void:
	var any_modal_open: bool = false
	for modal in [_forge_screen, _codex_screen, _diary_screen, _rules_screen]:
		if modal != null and modal.visible:
			any_modal_open = true
			break
	_hud_canvas.visible = not any_modal_open


## 重布局以适应当前 viewport 尺寸（窗口缩放 / fullscreen 切换 / 不同分辨率启动）
func _layout_for_viewport() -> void:
	var vp: Vector2 = get_viewport_rect().size
	# 背景占满
	if _background != null:
		_background.position = Vector2.ZERO
		_background.size = vp
	# 4 卷宗按相对中心位置摆放
	var cards := {
		&"forge": _card_forge,
		&"counter": _card_counter,
		&"codex": _card_codex,
		&"rules": _card_rules,
	}
	for k in cards:
		var card: ScrollCard = cards[k]
		if card == null:
			continue
		var center: Vector2 = CARD_LAYOUT[k]
		var sz: Vector2 = card.card_size
		card.position = Vector2(vp.x * center.x - sz.x * 0.5, vp.y * center.y - sz.y * 0.5)
	# 老铁锚底中
	_old_iron.global_position = Vector2(vp.x * 0.5, vp.y - 180)


func _refresh_card_forge() -> void:
	var entries: Array = EventLog.entries
	var open_n: int = 0
	var bk_n: int = 0
	var seen: int = 0
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var k: String = String(e.get("kind", ""))
		if not k.begins_with("forge_"):
			continue
		seen += 1
		if k == "forge_done":
			open_n += 1
		elif k == "forge_backlash":
			bk_n += 1
		if seen >= RECENT_FORGE_LOOKBACK:
			break
	_card_forge.set_status("近 %d 条：开炉 %d · 反噬 %d" % [seen, open_n, bk_n])


func _refresh_card_codex() -> void:
	var resonant: int = 0
	for gid in _GUPU_IDS:
		if GameState.has_resonance(gid):
			resonant += 1
	var current: StringName = CodexState.current_gupu_id if CodexState.current_gupu_id != &"" else &"qing_long"
	var name: String = "—"
	var g := DataRegistry.get_resource(&"gupu", current) as GuPuData
	if g != null:
		name = g.display_name
	_card_codex.set_status("共鸣 %d/7 · 当前 %s" % [resonant, name])


func _refresh_card_rules() -> void:
	var n: int = ShopRules.enabled.size()
	_card_rules.set_status("%d 条铺规已立" % n)


func _run_offline_settlement() -> void:
	if GameState.last_settle_unix <= 0:
		return
	var real_now: int = int(Time.get_unix_time_from_system())
	var new_entries: Array = OfflineSimulator.simulate(GameState.last_settle_unix, real_now)
	if new_entries.is_empty():
		return
	GameState.offline_diary_pending.append_array(new_entries)
	# 不强制存档；diary 关闭时会 save_now(true)


func _seed_starter_materials() -> void:
	# 首次进入或清存档后给一把材料，避免玩家无米下锅
	if GameState.material_count(&"tie") == 0 and GameState.material_count(&"jin") == 0:
		GameState.add_material(&"tie", 8)
		GameState.add_material(&"jin", 16)
		GameState.add_material(&"zhu_sha", 6)
		GameState.add_material(&"huang_zhi", 6)
		GameState.add_material(&"gu", 4)


func _on_open_forge() -> void:
	_forge_screen.open()


func _on_forge_finished(inst: Variant, qiao: bool, was_back: bool) -> void:
	# N8 叙事卡触发 + flash（EventLog 由 ForgeScreen 写入，避免双源）
	if was_back:
		ScreenFx.flash(Color(0.65, 0.20, 0.18), 0.35, 0.5)
		var t: String = NarrativeLibrary.pick_card(NarrativeCard.Trigger.BACKLASH)
		if not t.is_empty():
			_narrative_overlay.show_text(t)
	elif inst is GearInstance:
		var g: GearInstance = inst
		# 秘品 flash 强 / 禁品+巧成 中 / 法以下不闪
		if g.rarity >= 4:
			ScreenFx.flash(Color(0.95, 0.78, 0.30), 0.40, 0.6)
		elif g.rarity >= 3 or qiao:
			ScreenFx.flash(Color(0.85, 0.70, 0.30), 0.22, 0.4)
		if qiao or g.rarity >= 3:
			var t2: String = NarrativeLibrary.pick_card(NarrativeCard.Trigger.QIAO_CHENG)
			if not t2.is_empty():
				_narrative_overlay.show_text(t2)
	# 反噬时无装备入谱 + 不入诡器谱
	if not was_back and inst is GearInstance:
		# 诡器谱记录（spec §5.5）— 新 fingerprint 命中阈值会通过 identity_fragment_unlocked 信号弹卡
		WeirdCodex.record_gear(inst as GearInstance)
		var gear: GearInstance = inst
		# slot_kind 反查自配方（N3 简化：inst.base_id 就是 recipe id）
		var recipe: RecipeData = DataRegistry.get_resource(&"recipe", gear.base_id) as RecipeData
		var slot_kind: StringName
		if recipe != null:
			slot_kind = recipe.slot_kind
		else:
			push_warning("forge: recipe %s not found, falling back slot_kind=sword" % gear.base_id)
			slot_kind = &"sword"
		CodexState.place_equipment(gear, slot_kind)
	# 出炉后存档（强制）
	SaveSystem.save_now(true)


func _on_open_codex() -> void:
	_codex_screen.open()


func _on_open_rules() -> void:
	_rules_screen.open()


# ── Customer 流程 ─────────────────────────────

func _on_open_counter() -> void:
	if CustomerSpawner.spawn_now():
		return
	# spawn_now == false：要么 pending 已存在（按钮本应 disabled，防意外），要么 spawn miss
	if EncounterState.pending_request != null:
		return
	_door_visual.flash_failed()
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if now - _last_counter_fail_unix >= COUNTER_FAIL_THROTTLE_SEC:
		EventLog.add_entry(&"counter_empty", "门外无人迹", &"normal")
		_last_counter_fail_unix = now


func _on_customer_arrived(_cid: StringName, req: Variant) -> void:
	if req is CustomerRequest:
		Sfx.play_door_bell()
		_customer_panel.show_request(req)
		# EventLog
		var c0: CustomerData = (req as CustomerRequest).customer_data
		var disp: String = "陌客"
		var color: StringName = &"normal"
		if c0 != null:
			disp = c0.disguise_name if not c0.disguise_name.is_empty() else c0.display_name
			if c0.tier == CustomerData.Tier.WEIRD:
				color = &"weird"
		EventLog.add_entry(&"customer_arrive", "来客：%s" % disp, color)
		# 首次到访叙事卡
		var c: CustomerData = (req as CustomerRequest).customer_data
		if c == null:
			c = DataRegistry.get_resource(&"customer", (req as CustomerRequest).customer_id) as CustomerData
		if c != null:
			var name: String = c.disguise_name if not c.disguise_name.is_empty() else c.display_name
			var card_text: String = NarrativeLibrary.pick_first_visit(c.id, name)
			if not card_text.is_empty():
				_narrative_overlay.show_text(card_text)


func _on_customer_lend(req: CustomerRequest) -> void:
	_lend_dialog.open(req)


func _on_customer_refuse(req: CustomerRequest) -> void:
	var cid: StringName = req.customer_id if req != null else &""
	EncounterState.pending_request = null
	GameState.add_reputation(-1)
	var name: String = "客人"
	if req != null and req.customer_data != null:
		name = req.customer_data.display_name
	EventLog.add_entry(&"refuse", "婉拒 %s（-1 名望）" % name, &"bad")
	EventBus.customer_left.emit(cid, true)


func _on_gear_chosen(gear: GearInstance, req: CustomerRequest) -> void:
	EncounterState.lend(req.customer_id, gear, TimeLine.now_unix(), req.expected_duration_sec)
	EncounterState.pending_request = null
	GameState.add_currency(&"spirit_stones", req.payment)
	var name: String = "客人"
	if req != null and req.customer_data != null:
		name = req.customer_data.display_name
	EventLog.add_entry(&"lend", "借出 %s 给 %s（+%d 灵石）" %
		[gear.display_full_name(), name, req.payment], &"good")
	SaveSystem.save_now(true)
	# N4 v1 简化：到时立即 resolve（玩家不用真等）；N5 改为正常计时
	_resolve_now(gear, req)


func _resolve_now(gear: GearInstance, req: CustomerRequest) -> void:
	var c: CustomerData = req.customer_data
	if c == null:
		c = DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	var tier: int = c.tier if c != null else 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# 传 gear 的 path（青龙宿 buff 用）
	var gear_recipe := DataRegistry.get_resource(&"recipe", gear.base_id) as RecipeData
	var path: StringName = gear_recipe.path_affinity if gear_recipe != null else &""
	var outcome := ReturnResolver.roll_outcome(tier, rng, path)
	EncounterState.resolve_return(gear, outcome, TimeLine.now_unix() + req.expected_duration_sec)
	# C · 客人归还带料：GREAT_DEED 100% / OK_RETURN 30%
	var dropped_material: StringName = &""
	match outcome:
		ReturnResolver.Outcome.GREAT_DEED:
			var pool := [&"gu", &"zhu_sha"]
			dropped_material = pool[rng.randi_range(0, pool.size() - 1)]
			GameState.add_material(dropped_material, 1)
		ReturnResolver.Outcome.OK_RETURN:
			if rng.randf() < 0.30:
				dropped_material = &"tie"
				GameState.add_material(dropped_material, 1)
	if dropped_material != &"":
		var md: MaterialData = DataRegistry.get_resource(&"material", dropped_material) as MaterialData
		var disp: String = md.display_name if md != null else String(dropped_material)
		EventLog.add_entry(&"customer_return_drop", "%s 顺手捎了 %s×1" % [c.display_name if c != null else "客人", disp], &"normal")
	if outcome == ReturnResolver.Outcome.GREAT_DEED:
		GameState.add_currency(&"spirit_stones", req.payment * 2)
		GameState.add_reputation(2)
		# spec §5.4：立大功 10% 留赠星轨笔
		if rng.randf() < 0.10:
			GameState.add_star_brushes(1)
	SaveSystem.save_now(true)


func _on_resonance_activated_narrative(gupu_id: StringName, _pattern_id: StringName) -> void:
	# 共鸣大爆点：金色 flash + 已有 sfx + shake（codex_screen 内部也响应）
	ScreenFx.flash(Color(0.98, 0.85, 0.45), 0.55, 0.9)
	var t: String = NarrativeLibrary.pick_card(NarrativeCard.Trigger.RESONANCE)
	if not t.is_empty():
		_narrative_overlay.show_text(t)
	var g := DataRegistry.get_resource(&"gupu", gupu_id) as GuPuData
	var name: String = g.display_name if g != null else String(gupu_id)
	EventLog.add_entry(&"resonance", "%s 共鸣激活！" % name, &"system")


func _on_traits_learned_sfx(ids: Array) -> void:
	Sfx.play_paper_flutter()
	var names: Array[String] = []
	for t in ids:
		var zh = ShopRules.TRAIT_LIBRARY.get(t, t)
		names.append(String(zh))
	EventLog.add_entry(&"trait_learn", "学到特征：%s" % " · ".join(names), &"weird")


func _on_weird_codex_recorded_sfx(_fp: StringName, total: int) -> void:
	Sfx.play_paper_flutter()
	# 仅当解锁阶梯前 N 步时记日志（避免每件出炉都刷屏）
	var next: int = WeirdCodex.next_threshold()
	if next > 0:
		EventLog.add_entry(&"weird_codex", "诡器谱 +1 = %d（下一段碎片需 %d）" % [total, next], &"normal")


func _on_identity_fragment_unlocked(index: int, _total: int) -> void:
	# 解锁段触发暗线碎片：稍延迟后弹（避免和共鸣/出炉文字撞车）
	EventLog.add_entry(&"identity", "暗线碎片 +1（%d/15）" % index, &"weird")
	var t: String = NarrativeLibrary.pick_card(NarrativeCard.Trigger.IDENTITY_FRAGMENT)
	if not t.is_empty():
		await get_tree().create_timer(2.5).timeout
		_narrative_overlay.show_text(t)
		Sfx.play_breach()  # 暗线 = 重份量声音


func _on_equipment_returned(_cid: StringName, gear: Variant, outcome_text: StringName) -> void:
	Sfx.play_door_knock()
	var name: String = "（装备）"
	if gear is GearInstance:
		name = (gear as GearInstance).display_full_name()
	_return_notice.show_notice("%s · %s" % [name, String(outcome_text)])
	# EventLog 颜色按 outcome 选
	var color: StringName = &"normal"
	var ot: String = String(outcome_text)
	if "立大功" in ot: color = &"good"
	elif "未归还" in ot or "损坏" in ot or "异变" in ot: color = &"bad"
	EventLog.add_entry(&"returned", "%s · %s" % [name, ot], color)


func _process(delta: float) -> void:
	TimeLine.tick(delta)


func _on_time_advanced(_new_unix: int, _delta: int) -> void:
	_refresh_hud()


func _on_currency_changed(_kind: StringName, _value: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	var shichen := TimeLine.shichen_of_unix(TimeLine.now_unix())
	const SHICHEN_NAMES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
	_hud_time.text = "时辰　%s" % SHICHEN_NAMES[shichen]
	_hud_money.text = "◇ 灵石　%d" % GameState.spirit_stones
	_hud_reputation.text = "○ 名望　%d" % GameState.reputation
	_hud_brush.text = "✦ 星轨笔　%d" % GameState.star_brushes
	_hud_codex.text = "☯ 诡器谱 %d · 共鸣 %d/7" % [
		WeirdCodex.count(), GameState.active_resonances.size(),
	]
	_hud_rules.text = "❖ 已立规：%s" % _format_active_rules()


func _format_active_rules() -> String:
	if ShopRules.enabled.is_empty():
		return "无"
	var names: Array[String] = []
	for rid in ShopRules.enabled:
		var r: ShopRule = ShopRules.get_preset(rid)
		if r != null:
			names.append(r.display_name)
	return " · ".join(names)
