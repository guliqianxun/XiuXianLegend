extends Control
class_name ForgeLogFlow
## 炉房日志流：从 EventLog 过滤 kind 前缀 forge_ 的条目，染色 append。
## ScrollContainer + VBox，自动滚到底；用户主动滚则暂停 auto-scroll。

const KIND_PREFIX: String = "forge_"
const SHICHEN_NAMES: Array[String] = [
	"子", "丑", "寅", "卯", "辰", "巳",
	"午", "未", "申", "酉", "戌", "亥",
]

@onready var _scroll: ScrollContainer = $Frame/Scroll
@onready var _list: VBoxContainer = $Frame/Scroll/List

var _user_scrolled_up: bool = false


func _ready() -> void:
	EventLog.log_added.connect(_on_log_added)
	# 监听用户滚动，决定是否暂停 auto-scroll
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	rebuild_from_event_log()


## 重建：扫 EventLog 全部 entries，过滤 forge_，append
func rebuild_from_event_log() -> void:
	if _list == null: return
	for child in _list.get_children():
		child.queue_free()
	for entry in EventLog.entries:
		if _is_forge_entry(entry):
			_append_label(entry)
	_scroll_to_bottom_deferred()


func _on_log_added(entry: Dictionary) -> void:
	if not _is_forge_entry(entry): return
	_append_label(entry)
	if not _user_scrolled_up:
		_scroll_to_bottom_deferred()


static func _is_forge_entry(entry: Dictionary) -> bool:
	return String(entry.get("kind", "")).begins_with(KIND_PREFIX)


func _append_label(entry: Dictionary) -> void:
	var lbl := Label.new()
	var sh: int = int(entry.get("shichen", 0))
	var sname: String = SHICHEN_NAMES[sh] if sh >= 0 and sh < 12 else "?"
	lbl.text = "[%s] %s" % [sname, String(entry.get("text", ""))]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EventLog.color_of(StringName(entry.get("color_key", "normal"))))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(lbl)


func _scroll_to_bottom_deferred() -> void:
	# 等 layout 算完再滚
	await get_tree().process_frame
	if _scroll != null:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_scroll_changed(value: float) -> void:
	if _scroll == null: return
	var sb := _scroll.get_v_scroll_bar()
	# 用户主动往上滚 = 不在底部
	_user_scrolled_up = value < sb.max_value - sb.page - 4.0
