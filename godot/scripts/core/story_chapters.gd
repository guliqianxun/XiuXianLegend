extends Node
## 章节系统 Autoload。
## 把 WeirdCodex 的 0-15 段身份碎片包装成 5 章，提供章节查询 + 跨章信号。

signal chapter_changed(new_index: int, prev_index: int)

## 5 章定义：[fragment_count_min（含）, name, subtitle]
const CHAPTERS: Array = [
	{"min": 0,  "name": "序章",   "subtitle": "旧债"},
	{"min": 3,  "name": "第一卷", "subtitle": "盈门"},
	{"min": 6,  "name": "第二卷", "subtitle": "破谱"},
	{"min": 9,  "name": "第三卷", "subtitle": "异种"},
	{"min": 12, "name": "终章",   "subtitle": "真相"},
]

var _last_chapter_index: int = 0


func _ready() -> void:
	EventBus.identity_fragment_unlocked.connect(_on_fragment_unlocked)
	EventBus.save_loaded.connect(_on_save_loaded)


## 给定身份碎片数（0..15），返回章节索引（0..4）
static func chapter_of(fragment_count: int) -> int:
	var idx: int = 0
	for i in CHAPTERS.size():
		if fragment_count >= int(CHAPTERS[i]["min"]):
			idx = i
		else:
			break
	return idx


## 当前章节索引（基于 WeirdCodex.unlocked_fragments）
func current_index() -> int:
	return chapter_of(WeirdCodex.unlocked_fragments)


## 当前章节标题：「序章·旧债」
func current_title() -> String:
	return chapter_title(current_index())


static func chapter_title(idx: int) -> String:
	if idx < 0 or idx >= CHAPTERS.size():
		return "?"
	var c: Dictionary = CHAPTERS[idx]
	return "%s · %s" % [String(c["name"]), String(c["subtitle"])]


func _on_fragment_unlocked(_fragment_index: int, _total_fingerprints: int) -> void:
	_check_chapter_change()


func _on_save_loaded() -> void:
	_last_chapter_index = current_index()


func _check_chapter_change() -> void:
	var new_idx: int = current_index()
	if new_idx != _last_chapter_index:
		var prev: int = _last_chapter_index
		_last_chapter_index = new_idx
		chapter_changed.emit(new_idx, prev)
