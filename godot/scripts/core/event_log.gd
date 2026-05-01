extends Node
## 事件流 Autoload。
## 玩家可读的"今日发生过什么"日志，最近 N 条。
## 替代 NarrativeOverlay 弹完即逝的不可回看缺陷。

const MAX_ENTRIES: int = 50

const SHICHEN_NAMES: Array[String] = [
	"子", "丑", "寅", "卯", "辰", "巳",
	"午", "未", "申", "酉", "戌", "亥",
]

# 颜色 hint（StringName key → Color）
const COLOR_HINTS: Dictionary = {
	&"normal": Color(0.85, 0.80, 0.65),
	&"good": Color(0.75, 0.92, 0.65),     # 收益
	&"bad": Color(0.92, 0.55, 0.50),       # 亏损 / 攻破
	&"weird": Color(0.85, 0.65, 0.95),     # 怪客 / 暗线
	&"system": Color(0.65, 0.78, 0.92),    # 时辰 / 共鸣
}

## entries: Array[Dictionary]，每条 {unix:int, shichen:int, kind:StringName, text:String, color_key:StringName}
var entries: Array = []


signal log_added(entry: Dictionary)


## 添加一条
func add_entry(kind: StringName, text: String, color_key: StringName = &"normal") -> void:
	if text.is_empty(): return
	var unix: int = TimeLine.now_unix()
	var entry: Dictionary = {
		"unix": unix,
		"shichen": TimeLine.shichen_of_unix(unix),
		"kind": kind,
		"text": text,
		"color_key": color_key,
	}
	entries.append(entry)
	# Ring buffer trim
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(entries.size() - MAX_ENTRIES)
	log_added.emit(entry)


## 取最新 n 条（倒序）
func recent(n: int) -> Array:
	var k: int = mini(n, entries.size())
	if k <= 0:
		return []
	var slice: Array = entries.slice(entries.size() - k)
	slice.reverse()
	return slice


## 取颜色（从 hint key 解）
func color_of(color_key: StringName) -> Color:
	return COLOR_HINTS.get(color_key, COLOR_HINTS[&"normal"])


func clear() -> void:
	entries.clear()


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var ser: Array = []
	for e in entries:
		ser.append({
			"unix": int(e["unix"]),
			"shichen": int(e["shichen"]),
			"kind": String(e["kind"]),
			"text": String(e["text"]),
			"color_key": String(e["color_key"]),
		})
	return {"entries": ser}


func from_dict(d: Dictionary) -> void:
	entries.clear()
	for it in d.get("entries", []):
		entries.append({
			"unix": int(it.get("unix", 0)),
			"shichen": int(it.get("shichen", 0)),
			"kind": StringName(it.get("kind", "")),
			"text": String(it.get("text", "")),
			"color_key": StringName(it.get("color_key", "normal")),
		})
