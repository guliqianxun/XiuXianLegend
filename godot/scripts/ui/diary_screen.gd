extends Control
class_name DiaryScreen
## 铁炉小本：玩家上线后弹出的离线日记面板。
## 显示 GameState.offline_diary_pending 全部条目；关闭时清空 pending 并存档。

signal closed

@onready var _title: Label = $Frame/Layout/Title
@onready var _list: ItemList = $Frame/Layout/List
@onready var _close_btn: Button = $Frame/Layout/Buttons/CloseBtn

const SHICHEN_NAMES: Array[String] = [
	"子", "丑", "寅", "卯", "辰", "巳",
	"午", "未", "申", "酉", "戌", "亥",
]


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)


## 弹出面板。entries 为 GameState.offline_diary_pending 的快照。
func open(entries: Array) -> void:
	# 防御性 size（防 anchor-on-Node2D 坑）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_title.text = "铁炉小本（你不在时发生过 %d 件事）" % entries.size()
	_list.clear()
	for e in entries:
		var ed: Dictionary = e
		var detail: String = String(ed.get("detail", ""))
		_list.add_item(detail)


func _on_close() -> void:
	visible = false
	GameState.offline_diary_pending = []
	SaveSystem.save_now(true)
	closed.emit()
