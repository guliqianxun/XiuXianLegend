class_name OnboardingOverlay
extends Control
## 5 步新手引导：每步高亮一个目标 Control + 浮动 tooltip。
## shop_screen 首次进游戏（GameState.onboarding_done == false）触发 start()。
## 玩家点 「下一步」推进；最后一步 「开始」 完成 + 落 GameState.onboarding_done = true。

signal completed

const STEPS: Array = [
	{
		"target": "ScrollCardForge",
		"title": "炉房 · 开炉",
		"text": "点开炉房，从凡铁剑炼起。\n材料够了就能开炉。",
	},
	{
		"target": "ScrollCardCounter",
		"title": "门外 · 接客",
		"text": "客人会上门求兵器。\n点开柜台招呼他们。",
	},
	{
		"target": "ScrollCardCodex",
		"title": "古谱 · 入谱",
		"text": "你出炉的兵器会自动入谱。\n28 颗星点亮后触发共鸣。",
	},
	{
		"target": "ScrollCardRules",
		"title": "店规 · 立规",
		"text": "不愿接的客人可以预设规则拒绝。\n小心怪客披着熟客的皮。",
	},
	{
		"target": "HUD/HudFrame/VBox/QuestButton",
		"title": "老铁身世",
		"text": "随着你接客 / 开炉 / 入谱，\n老铁的身世碎片会一段段揭开。\n点这里随时回看进度。",
	},
]

@onready var _backdrop: ColorRect = $Backdrop
@onready var _spotlight: ReferenceRect = $Spotlight
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _title_label: Label = $Tooltip/VBox/Title
@onready var _text_label: Label = $Tooltip/VBox/Body
@onready var _next_btn: Button = $Tooltip/VBox/NextButton
@onready var _skip_btn: Button = $Tooltip/VBox/SkipButton

var _shop_root: Node = null
var _step_idx: int = 0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next_btn.pressed.connect(_on_next)
	_skip_btn.pressed.connect(_on_skip)


func start(shop_root: Node) -> void:
	_shop_root = shop_root
	_step_idx = 0
	visible = true
	_show_step(0)


func _show_step(idx: int) -> void:
	if idx < 0 or idx >= STEPS.size():
		_finish()
		return
	_step_idx = idx
	var step: Dictionary = STEPS[idx]
	_title_label.text = step["title"]
	_text_label.text = step["text"]
	_next_btn.text = "开始" if idx == STEPS.size() - 1 else "下一步 (%d/%d)" % [idx + 1, STEPS.size()]
	# 找目标 Control，把 spotlight 摆它的全局位置
	var target: Node = _shop_root.get_node_or_null(step["target"])
	if target == null:
		# 目标找不到 → spotlight 放屏中央 fallback
		_spotlight.position = Vector2(get_viewport_rect().size.x * 0.5 - 100, get_viewport_rect().size.y * 0.5 - 100)
		_spotlight.size = Vector2(200, 200)
	elif target is Control:
		var c: Control = target
		var rect := c.get_global_rect()
		_spotlight.position = rect.position - Vector2(8, 8)
		_spotlight.size = rect.size + Vector2(16, 16)
	else:
		_spotlight.position = Vector2(get_viewport_rect().size.x * 0.5 - 100, get_viewport_rect().size.y * 0.5 - 100)
		_spotlight.size = Vector2(200, 200)
	# 把 tooltip 放在 spotlight 旁（避免遮挡），简化：屏幕底部居中
	var vp: Vector2 = get_viewport_rect().size
	_tooltip.position = Vector2(vp.x * 0.5 - 200, vp.y - 200)


func _on_next() -> void:
	_show_step(_step_idx + 1)


func _on_skip() -> void:
	_finish()


func _finish() -> void:
	visible = false
	GameState.onboarding_done = true
	SaveSystem.save_now(true)
	completed.emit()
