extends Node2D
## 铺子主场景控制器。
## 4 区域 placeholder：炉房 / 柜台 / 阁楼 / 后院。
## N1 仅显示 + 老铁站位 + 时辰 HUD；交互留给后续 milestone。

## 4 区域中心坐标（相对于场景原点；2.5D 俯视布局）
const AREA_POSITIONS: Dictionary = {
	&"furnace": Vector2(280, 380),  # 炉房：左下
	&"counter": Vector2(640, 380),  # 柜台：中下
	&"loft":    Vector2(640, 200),  # 阁楼：中上
	&"yard":    Vector2(960, 380),  # 后院：右下
}

@onready var _old_iron: Node2D = $OldIron
@onready var _hud_time: Label = $HUD/TimeLabel
@onready var _hud_money: Label = $HUD/MoneyLabel
@onready var _open_forge_btn: Button = $AreaFurnace/OpenForgeButton
@onready var _forge_screen: ForgeScreen = $ForgeScreen


func _ready() -> void:
	# 老铁初始站在炉房
	_old_iron.global_position = AREA_POSITIONS[&"furnace"]
	# 启动后立即载档
	SaveSystem.load_or_init()
	# 给玩家点初始材料用于试炉（仅在 inventory 为空时）
	_seed_starter_materials()
	# 接信号刷 HUD
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.forge_finished.connect(_on_forge_finished)
	# 炉房按钮 → 开锻造弹窗
	_open_forge_btn.pressed.connect(_on_open_forge)
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


func _on_forge_finished(_inst: Resource, _qiao: bool, _back: bool) -> void:
	# 出炉后存档（强制）
	SaveSystem.save_now(true)


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
