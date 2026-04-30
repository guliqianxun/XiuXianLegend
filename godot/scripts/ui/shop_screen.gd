extends Node2D
## 铺子主场景控制器。
## 4 区域 placeholder：炉房 / 柜台 / 阁楼 / 后院。
## N1 仅显示 + 老铁站位 + 时辰 HUD；交互留给后续 milestone。

## 4 区域中老铁的"站位"坐标（相对于场景原点；避开炉房中央按钮）
const AREA_POSITIONS: Dictionary = {
	&"furnace": Vector2(150, 490),  # 炉房：左下角（避开中央"开炉"按钮）
	&"counter": Vector2(640, 490),
	&"loft":    Vector2(640, 110),
	&"yard":    Vector2(960, 490),
}

@onready var _old_iron: Node2D = $OldIron
@onready var _hud_time: Label = $HUD/TimeLabel
@onready var _hud_money: Label = $HUD/MoneyLabel
@onready var _open_forge_btn: Button = $AreaFurnace/OpenForgeButton
@onready var _forge_screen: ForgeScreen = $ForgeScreen
@onready var _open_codex_btn: Button = $AreaLoft/OpenCodexButton
@onready var _codex_screen: CodexScreen = $CodexScreen
@onready var _open_counter_btn: Button = $AreaCounter/OpenCounterButton
@onready var _customer_panel: CustomerArrivalPanel = $CustomerArrivalPanel
@onready var _lend_dialog: LendDialog = $LendDialog
@onready var _return_notice: ReturnNotice = $ReturnNotice


func _ready() -> void:
	# 强制所有覆盖层 UI 占满 viewport 并隐藏。
	# 即使 CustomerArrivalPanel/ReturnNotice 视觉只占部分屏幕，仍需 size = viewport
	# 让其内部 anchors_preset (12=底部宽 / 5=居中上) 正确定位（Control 在 Node2D
	# 父下 anchors 全失效）。
	var vp_size: Vector2 = get_viewport_rect().size
	for screen in [_forge_screen, _codex_screen, _lend_dialog, _customer_panel, _return_notice]:
		screen.position = Vector2.ZERO
		screen.size = vp_size
		screen.visible = false
	# 老铁初始站在炉房（避开按钮位置）
	_old_iron.global_position = AREA_POSITIONS[&"furnace"]
	# 启动后立即载档
	SaveSystem.load_or_init()
	# 给玩家点初始材料用于试炉（仅在 inventory 为空时）
	_seed_starter_materials()
	# 接信号刷 HUD + 锻造完成 + 客人来访 + 装备归来
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.forge_finished.connect(_on_forge_finished)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.equipment_returned.connect(_on_equipment_returned)
	# 4 区域按钮
	_open_forge_btn.pressed.connect(_on_open_forge)
	_open_codex_btn.pressed.connect(_on_open_codex)
	_open_counter_btn.pressed.connect(_on_open_counter)
	# Customer 流程
	_customer_panel.lend_pressed.connect(_on_customer_lend)
	_customer_panel.refuse_pressed.connect(_on_customer_refuse)
	_lend_dialog.gear_chosen.connect(_on_gear_chosen)
	_refresh_hud()


func _seed_starter_materials() -> void:
	# 首次进入或清存档后给一把材料，避免玩家无米下锅
	if GameState.material_count(&"iron") == 0 and GameState.material_count(&"jin") == 0:
		GameState.add_material(&"iron", 8)
		GameState.add_material(&"jin", 16)
		GameState.add_material(&"zhusha", 6)
		GameState.add_material(&"yellow_paper", 6)
		GameState.add_material(&"bone", 4)


func _on_open_forge() -> void:
	_forge_screen.open()


func _on_forge_finished(inst: Variant, _qiao: bool, was_back: bool) -> void:
	# 反噬时无装备入谱
	if not was_back and inst is GearInstance:
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


# ── Customer 流程 ─────────────────────────────

func _on_open_counter() -> void:
	if not CustomerSpawner.spawn_now():
		push_warning("counter: pending request exists or spawn failed (pending=%s)" % EncounterState.pending_request)


func _on_customer_arrived(_cid: StringName, req: Variant) -> void:
	if req is CustomerRequest:
		_customer_panel.show_request(req)


func _on_customer_lend(req: CustomerRequest) -> void:
	_lend_dialog.open(req)


func _on_customer_refuse(_req: CustomerRequest) -> void:
	EncounterState.pending_request = null
	GameState.add_reputation(-1)


func _on_gear_chosen(gear: GearInstance, req: CustomerRequest) -> void:
	EncounterState.lend(req.customer_id, gear, TimeLine.now_unix(), req.expected_duration_sec)
	EncounterState.pending_request = null
	GameState.add_currency(&"spirit_stones", req.payment)
	SaveSystem.save_now(true)
	# N4 v1 简化：到时立即 resolve（玩家不用真等）；N5 改为正常计时
	_resolve_now(gear, req)


func _resolve_now(gear: GearInstance, req: CustomerRequest) -> void:
	var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	var tier: int = c.tier if c != null else 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var outcome := ReturnResolver.roll_outcome(tier, rng)
	EncounterState.resolve_return(gear, outcome, TimeLine.now_unix() + req.expected_duration_sec)
	if outcome == ReturnResolver.Outcome.GREAT_DEED:
		GameState.add_currency(&"spirit_stones", req.payment * 2)
		GameState.add_reputation(2)
	SaveSystem.save_now(true)


func _on_equipment_returned(_cid: StringName, gear: Variant, outcome_text: StringName) -> void:
	var name: String = "（装备）"
	if gear is GearInstance:
		name = (gear as GearInstance).display_full_name()
	_return_notice.show_notice("%s · %s" % [name, String(outcome_text)])


func _process(delta: float) -> void:
	# N1 简单：每个真实秒推进游戏时间 1 秒（1:1）
	# N5 改为可调倍速 + 离线时长积分
	TimeLine.advance_seconds(int(delta * 1.0))
	# 防止 0 -> 不发信号；只在每整秒 emit 一次靠 advance_seconds 内部判断
	# (此处 delta 通常 ~0.016，int 化后是 0，所以 advance 实际不会发——这是预期；下版会改)


func _on_time_advanced(_new_unix: int, _delta: int) -> void:
	_refresh_hud()


func _on_currency_changed(_kind: StringName, _value: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	var shichen := TimeLine.shichen_of_unix(TimeLine.now_unix())
	const SHICHEN_NAMES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
	_hud_time.text = "时辰：%s" % SHICHEN_NAMES[shichen]
	_hud_money.text = "灵石：%d" % GameState.spirit_stones
