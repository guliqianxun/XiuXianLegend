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
	_title.text = "借给 %s（求 %s ≥ Q%d）" % [
		_customer_name(req.customer_id),
		CustomerArrivalPanel._slot_zh(req.desired_slot),
		req.min_quality,
	]
	_candidates.clear()
	_list.clear()
	for inst: GearInstance in GameState.inventory:
		if inst == null: continue
		if inst.status != GearInstance.Status.IN_SHOP: continue
		if inst.rarity < req.min_quality: continue
		var recipe := DataRegistry.get_resource(&"recipe", inst.base_id) as RecipeData
		if recipe != null and recipe.slot_kind != req.desired_slot:
			continue
		_candidates.append(inst)
		_list.add_item("%s（%d 次履历）" % [inst.display_full_name(), inst.history.size()])


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


func _customer_name(cid: StringName) -> String:
	var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
	return c.display_name if c != null else String(cid)
