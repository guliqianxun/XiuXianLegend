class_name DoorVisual
extends Control
## 柜台门帘指示器。两个 base 状态（idle / pending）+ 两个瞬态效果（just-arrived / just-failed）。
## idle: 暗灰静止 + "门外静寂"
## pending: 朱红浅亮 + "门外有客"
## just-arrived: 朱红 flash 0.3s + 帘横晃 1s → 落入 pending
## just-failed: 灰 flash 0.6s + "门外无人迹"

const COLOR_IDLE := Color(0.182, 0.142, 0.108, 1.0)
const COLOR_PENDING := Color(0.545, 0.227, 0.165, 0.85)
const COLOR_FAIL := Color(0.32, 0.32, 0.32, 0.85)
const TEXT_IDLE := "门外静寂"
const TEXT_PENDING := "门外有客"
const TEXT_ARRIVED := "来客了"
const TEXT_FAIL := "门外无人迹"

@onready var _curtain: ColorRect = $Curtain
@onready var _label: Label = $Curtain/Label

var _curtain_origin_x: float = 0.0
var _active_tween: Tween


func _ready() -> void:
	_curtain_origin_x = _curtain.position.x
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.equipment_returned.connect(_on_equipment_returned)
	EventBus.customer_left.connect(_on_customer_left)
	_refresh_base()


func _refresh_base() -> void:
	if EncounterState.pending_request != null:
		_apply_pending()
	else:
		_apply_idle()


func _apply_idle() -> void:
	_curtain.color = COLOR_IDLE
	_label.text = TEXT_IDLE
	_label.modulate = Color(0.6, 0.55, 0.45, 1.0)


func _apply_pending() -> void:
	_curtain.color = COLOR_PENDING
	_label.text = TEXT_PENDING
	_label.modulate = Color(0.95, 0.85, 0.65, 1.0)


func _on_customer_arrived(_a: Variant = null, _b: Variant = null) -> void:
	# 信号有 1-arg 和 2-arg 两种形态（spawner 实际 emit 2 个）；用变长接收
	flash_arrival()


func _on_equipment_returned(_cid: StringName, _gear: Variant, _outcome: StringName) -> void:
	# 客人归还后 pending 已清，回到 idle
	_refresh_base()


func _on_customer_left(_cid: StringName, _refused: bool) -> void:
	_refresh_base()


## 来客了：朱红 flash + 帘横晃 1s → 停在 pending 态
func flash_arrival() -> void:
	_kill_active_tween()
	_label.text = TEXT_ARRIVED
	_label.modulate = Color(1.0, 0.92, 0.55, 1.0)
	_curtain.color = Color(0.78, 0.32, 0.22, 1.0)
	var t := create_tween()
	_active_tween = t
	# 横晃 3 来回
	t.set_loops(3)
	t.tween_property(_curtain, "position:x", _curtain_origin_x + 6.0, 0.12)
	t.tween_property(_curtain, "position:x", _curtain_origin_x - 6.0, 0.12)
	t.set_loops(1)
	t.tween_property(_curtain, "position:x", _curtain_origin_x, 0.08)
	t.tween_callback(_apply_pending)


## 接客失败（spawn miss）：灰 flash + "门外无人迹" 0.6s
func flash_failed() -> void:
	_kill_active_tween()
	_label.text = TEXT_FAIL
	_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_curtain.color = COLOR_FAIL
	var t := create_tween()
	_active_tween = t
	t.tween_interval(0.6)
	t.tween_callback(_refresh_base)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_running():
		_active_tween.kill()
	_curtain.position.x = _curtain_origin_x
