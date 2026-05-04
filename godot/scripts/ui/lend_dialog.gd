extends Control
class_name LendDialog
## 选 IN_SHOP 状态装备的对话框。

signal gear_chosen(gear: GearInstance, req: CustomerRequest)
signal cancelled

@onready var _title: Label = $Frame/Layout/Title
@onready var _list: ItemList = $Frame/Layout/List
@onready var _confirm_btn: Button = $Frame/Layout/Buttons/ConfirmBtn
@onready var _cancel_btn: Button = $Frame/Layout/Buttons/CancelBtn

var _candidates: Array[GearInstance] = []
var _current_req: CustomerRequest = null


func _ready() -> void:
	visible = false
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)


func open(req: CustomerRequest) -> void:
	_current_req = req
	visible = true
	var name: String = _resolve_name(req)
	_title.text = "借给 %s（求 %s ≥ Q%d）" % [
		name,
		CustomerArrivalPanel._slot_zh(req.desired_slot),
		req.min_quality,
	]
	_candidates.clear()
	_list.clear()
	# 分桶：按筛选原因分类，让"无道具"能解释为什么
	var skip_slot: int = 0
	var skip_quality: int = 0
	var skip_status: int = 0
	for inst: GearInstance in GameState.inventory:
		if inst == null: continue
		var recipe := DataRegistry.get_resource(&"recipe", inst.base_id) as RecipeData
		if recipe != null and recipe.slot_kind != req.desired_slot:
			skip_slot += 1
			continue
		if inst.status != GearInstance.Status.IN_SHOP:
			skip_status += 1
			continue
		if inst.rarity < req.min_quality:
			skip_quality += 1
			continue
		_candidates.append(inst)
		_list.add_item("%s（%d 次履历）" % [inst.display_full_name(), inst.history.size()])
	# 候选为空时，把"为什么"列在 list 中（grayed）
	if _candidates.is_empty():
		var reasons: Array[String] = []
		if skip_slot > 0:
			reasons.append("%d 件不合品类（求 %s）" % [skip_slot, CustomerArrivalPanel._slot_zh(req.desired_slot)])
		if skip_quality > 0:
			reasons.append("%d 件品阶不够（求 ≥Q%d）" % [skip_quality, req.min_quality])
		if skip_status > 0:
			reasons.append("%d 件不在铺中（已借出/损坏/异变/未还）" % skip_status)
		if reasons.is_empty():
			_list.add_item("—— 库中无任何兵器 ——")
		else:
			_list.add_item("—— 无可借兵器 ——")
			for r in reasons:
				_list.add_item("· " + r)
		# 禁用 list 选中
		for i in _list.item_count:
			_list.set_item_disabled(i, true)


func _on_confirm() -> void:
	var idx := _list.get_selected_items()
	if idx.is_empty(): return
	var i: int = idx[0]
	if i < 0 or i >= _candidates.size(): return
	visible = false
	gear_chosen.emit(_candidates[i], _current_req)


func _on_cancel() -> void:
	visible = false
	cancelled.emit()


func _resolve_name(req: CustomerRequest) -> String:
	if req.customer_data != null:
		return req.customer_data.display_name
	var c := DataRegistry.get_resource(&"customer", req.customer_id) as CustomerData
	return c.display_name if c != null else String(req.customer_id)
