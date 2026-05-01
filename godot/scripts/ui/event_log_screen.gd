extends Control
class_name EventLogScreen
## 事件流全展开面板（最近 50 条）。
## 由 EventLogPanel 的 "看全本" 按钮打开。

@onready var _list: VBoxContainer = $Frame/Layout/Scroll/List
@onready var _close_btn: Button = $Frame/Layout/CloseButton


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)


func open() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	# 倒序展示（最新在上）
	for entry in EventLog.recent(EventLog.MAX_ENTRIES):
		var lbl := Label.new()
		var sh: int = int(entry["shichen"])
		var sname: String = EventLog.SHICHEN_NAMES[sh] if sh >= 0 and sh < 12 else "?"
		lbl.text = "[%s] %s" % [sname, String(entry["text"])]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", EventLog.color_of(StringName(entry["color_key"])))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(lbl)


func _on_close() -> void:
	visible = false
