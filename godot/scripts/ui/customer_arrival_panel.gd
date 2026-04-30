extends Control
class_name CustomerArrivalPanel
## 客人来访时屏幕底部滑入的小卡。
## 显示：客人名 / 诉求 / 酬金 / 借/拒按钮

signal lend_pressed(req: CustomerRequest)
signal refuse_pressed(req: CustomerRequest)

@onready var _name_label: Label = $Frame/Layout/NameLabel
@onready var _request_label: Label = $Frame/Layout/RequestLabel
@onready var _payment_label: Label = $Frame/Layout/PaymentLabel
@onready var _lend_btn: Button = $Frame/Layout/Buttons/LendBtn
@onready var _refuse_btn: Button = $Frame/Layout/Buttons/RefuseBtn

var _current: CustomerRequest = null


func _ready() -> void:
	visible = false
	_lend_btn.pressed.connect(_on_lend)
	_refuse_btn.pressed.connect(_on_refuse)


func show_request(req: CustomerRequest) -> void:
	_current = req
	# 防御性：每次 show 强制 size + position（防 anchor-on-Node2D 坑反复发作）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	_name_label.text = c.display_name if c != null else String(req.customer_id)
	_request_label.text = "求借 %s ≥ Q%d  ·  %s" % [
		_slot_zh(req.desired_slot), req.min_quality, req.quest_label
	]
	_payment_label.text = "酬金 %d 灵石" % req.payment


func _on_lend() -> void:
	visible = false
	if _current != null:
		lend_pressed.emit(_current)


func _on_refuse() -> void:
	visible = false
	if _current != null:
		refuse_pressed.emit(_current)


static func _slot_zh(slot: StringName) -> String:
	match slot:
		&"sword": return "剑"
		&"talisman": return "符"
		&"puppet_core": return "傀核"
		&"elixir_furnace": return "丹炉"
		&"eating_vessel": return "食器"
		&"divination_plate": return "卦盘"
		_: return String(slot)
