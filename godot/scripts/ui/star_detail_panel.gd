extends Control
class_name StarDetailPanel
## 点击一颗星后显示的弹窗：列出该星位上的所有装备。

@onready var _title: Label = $Frame/Layout/Title
@onready var _list: ItemList = $Frame/Layout/List
@onready var _close_btn: Button = $Frame/Layout/CloseButton


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)


func open(gupu: GuPuData, su_id: StringName) -> void:
	visible = true
	var su_disp: String = String(su_id)
	for s: SuData in gupu.stars:
		if s != null and s.id == su_id:
			su_disp = s.display_name
			break
	_title.text = "%s · %s" % [gupu.display_name, su_disp]
	_list.clear()
	for inst: GearInstance in CodexState.equipments_at_star(su_id):
		var line: String = "%s（出炉于 %s）" % [
			inst.display_full_name(),
			str(inst.origin.get("unix", "?"))
		]
		_list.add_item(line)


func _on_close() -> void:
	visible = false
