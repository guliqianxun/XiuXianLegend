extends Control
class_name EventLogPanel
## 屏幕右侧常驻的事件流条目 — 最新 N 条 + 全展开按钮。
## 每条文字根据 color_key 染色。

const SHOWN: int = 6

@onready var _list: VBoxContainer = $Frame/VBox/List
@onready var _expand_btn: Button = $Frame/VBox/ExpandButton

var _on_expand: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 防 anchor-on-Node2D 坑
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2(vp_size.x - 290, 150)
	size = Vector2(280, 220)
	EventLog.log_added.connect(_on_log_added)
	EventBus.save_loaded.connect(_refresh)
	if _expand_btn != null:
		_expand_btn.pressed.connect(_on_expand_pressed)
	_refresh()


func set_expand_handler(cb: Callable) -> void:
	_on_expand = cb


func _on_log_added(_e: Dictionary) -> void:
	_refresh()


func _on_expand_pressed() -> void:
	if _on_expand.is_valid():
		_on_expand.call()


func _refresh() -> void:
	if _list == null: return
	for child in _list.get_children():
		child.queue_free()
	for entry in EventLog.recent(SHOWN):
		var lbl := Label.new()
		var sh: int = int(entry["shichen"])
		var sname: String = EventLog.SHICHEN_NAMES[sh] if sh >= 0 and sh < 12 else "?"
		lbl.text = "[%s] %s" % [sname, String(entry["text"])]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", EventLog.color_of(StringName(entry["color_key"])))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(lbl)
