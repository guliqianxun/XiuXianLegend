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


func _ready() -> void:
	# 强制 ForgeScreen / CodexScreen 占满 viewport 并隐藏（Control 在 Node2D 父下
	# anchors 不工作，必须显式设 size 与 visible）
	var vp_size: Vector2 = get_viewport_rect().size
	for screen in [_forge_screen, _codex_screen]:
		screen.position = Vector2.ZERO
		screen.size = vp_size
		screen.visible = false
	# 老铁初始站在炉房（避开按钮位置）
	_old_iron.global_position = AREA_POSITIONS[&"furnace"]
	# 启动后立即载档
	SaveSystem.load_or_init()
	# 给玩家点初始材料用于试炉（仅在 inventory 为空时）
	_seed_starter_materials()
	# 接信号刷 HUD
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.forge_finished.connect(_on_forge_finished)
	# 炉房按钮 → 开锻造弹窗；阁楼按钮 → 开器谱
	_open_forge_btn.pressed.connect(_on_open_forge)
	_open_codex_btn.pressed.connect(_on_open_codex)
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
		var slot_kind: StringName = recipe.slot_kind if recipe != null else &"sword"
		CodexState.place_equipment(gear, slot_kind)
	# 出炉后存档（强制）
	SaveSystem.save_now(true)


func _on_open_codex() -> void:
	_codex_screen.open()


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
