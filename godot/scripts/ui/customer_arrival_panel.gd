extends Control
class_name CustomerArrivalPanel
## 客人来访时屏幕底部滑入的小卡。
## 显示：客人名 / 诉求 / 酬金 / 借/拒按钮 + 打听（识破伪装）

signal lend_pressed(req: CustomerRequest)
signal refuse_pressed(req: CustomerRequest)

const INSPECT_COST: int = 50  # 打听一次的灵石

@onready var _name_label: Label = $Frame/Layout/NameLabel
@onready var _request_label: Label = $Frame/Layout/RequestLabel
@onready var _payment_label: Label = $Frame/Layout/PaymentLabel
@onready var _lend_btn: Button = $Frame/Layout/Buttons/LendBtn
@onready var _refuse_btn: Button = $Frame/Layout/Buttons/RefuseBtn
@onready var _inspect_btn: Button = $Frame/Layout/Buttons/InspectBtn

var _current: CustomerRequest = null


func _ready() -> void:
	visible = false
	_lend_btn.pressed.connect(_on_lend)
	_refuse_btn.pressed.connect(_on_refuse)
	_inspect_btn.pressed.connect(_on_inspect)


func show_request(req: CustomerRequest) -> void:
	_current = req
	# 防御性：每次 show 强制 size + position（防 anchor-on-Node2D 坑反复发作）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_render(req)


func _render(req: CustomerRequest) -> void:
	var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	if c == null:
		_name_label.text = String(req.customer_id)
		_request_label.text = "（未知客人）"
		_payment_label.text = "酬金 %d 灵石" % req.payment
		_inspect_btn.visible = false
		return

	# 显示名 + tier 标签
	var display: String
	var tier_for_label: int
	if req.unmasked or c.disguise_name.is_empty():
		display = c.display_name
		tier_for_label = int(c.tier)
	else:
		display = c.disguise_name
		tier_for_label = c.disguise_tier if c.disguise_tier >= 0 else int(c.tier)
	_name_label.text = "%s · %s" % [display, _tier_zh(tier_for_label)]

	_request_label.text = "求借 %s ≥ Q%d  ·  %s" % [
		_slot_zh(req.desired_slot), req.min_quality, req.quest_label
	]
	_payment_label.text = "酬金 %d 灵石" % req.payment

	# 打听按钮：只对未识破的伪装客人显示
	var disguised: bool = (not c.disguise_name.is_empty()) and (not req.unmasked)
	_inspect_btn.visible = disguised
	if disguised:
		_inspect_btn.text = "打听（%d 灵石）" % INSPECT_COST
		_inspect_btn.disabled = (GameState.spirit_stones < INSPECT_COST)


func _on_lend() -> void:
	visible = false
	if _current != null:
		lend_pressed.emit(_current)


func _on_refuse() -> void:
	visible = false
	if _current != null:
		refuse_pressed.emit(_current)


func _on_inspect() -> void:
	if _current == null: return
	if not GameState.spend_currency(&"spirit_stones", INSPECT_COST):
		push_warning("inspect: 灵石不足 %d" % INSPECT_COST)
		return
	_current.unmasked = true
	# 学到该客人的所有 trait（spec §7.3：打听后永久解锁特征条款）
	var c := DataRegistry.get_resource(&"customer", _current.customer_id) as CustomerData
	if c != null and not c.traits.is_empty():
		GameState.learn_traits(c.traits)
	_render(_current)
	# 反馈：短铃 + 名字脉冲
	Sfx.play_inspect()
	_pulse_name()


func _pulse_name() -> void:
	if _name_label == null: return
	_name_label.modulate = Color(1, 1, 1, 0)
	_name_label.scale = Vector2(1.05, 1.05)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_name_label, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_property(_name_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _slot_zh(slot: StringName) -> String:
	match slot:
		&"sword": return "剑"
		&"talisman": return "符"
		&"puppet_core": return "傀核"
		&"elixir_furnace": return "丹炉"
		&"eating_vessel": return "食器"
		&"divination_plate": return "卦盘"
		_: return String(slot)


static func _tier_zh(tier: int) -> String:
	match tier:
		0: return "凡品"
		1: return "罕品"
		2: return "怪品"
		_: return "?"
