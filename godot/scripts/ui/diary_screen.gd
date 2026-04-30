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
	var has_breach: bool = false
	for i in entries.size():
		var ed: Dictionary = entries[i]
		var kind: StringName = StringName(ed.get("kind", ""))
		var detail: String = String(ed.get("detail", ""))
		var idx: int = _list.add_item(detail)
		# 攻破条目：红字
		if kind == &"rule_breach":
			_list.set_item_custom_fg_color(idx, Color(0.95, 0.35, 0.30))
			has_breach = true
		elif kind == &"sleep":
			_list.set_item_custom_fg_color(idx, Color(0.65, 0.55, 0.45))
	# 反馈：有攻破时低嗡 + 中等震动；普通日记轻震
	if has_breach:
		Sfx.play_breach()
		ScreenFx.shake(8.0, 0.5)
	else:
		ScreenFx.shake(3.0, 0.15)
	# Title 弹出脉冲
	if _title != null:
		_title.scale = Vector2(0.9, 0.9)
		var tw := create_tween()
		tw.tween_property(_title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_close() -> void:
	visible = false
	GameState.offline_diary_pending = []
	SaveSystem.save_now(true)
	closed.emit()
