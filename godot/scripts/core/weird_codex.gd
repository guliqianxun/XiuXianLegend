extends Node
## 诡器谱 Autoload（spec §5.5 + §9.4）。
## - 跟踪所有"独特装备 fingerprint"集合
## - 每达成阈值解锁一段身份碎片
## - v1 fingerprint = recipe_id|quality；v2+ 加 main_affix

const FINGERPRINT_SEP: String = "|"

## 阶梯阈值（spec 15 段碎片；v1 早期阈值小，N9 内容到位再调）
const THRESHOLDS: Array[int] = [5, 10, 18, 28, 40, 55, 70, 85, 100, 115, 130, 145, 160, 175, 190]

## 见过的 fingerprint 集合（去重，序列化）
var fingerprints: Array[StringName] = []

## 已解锁的身份碎片数（0..15）
var unlocked_fragments: int = 0


## 计算装备 fingerprint：recipe_id|quality|main_affix_id（N9 升级 v2）
## 主词缀为空时 affix 段写 "_"，保持格式稳定
static func fingerprint_of(gear: GearInstance) -> StringName:
	if gear == null: return &""
	var affix_part: String = "_"
	if not gear.affix_ids.is_empty():
		affix_part = String(gear.affix_ids[0])
	return StringName("%s%s%d%s%s" % [
		String(gear.base_id), FINGERPRINT_SEP,
		gear.rarity, FINGERPRINT_SEP,
		affix_part,
	])


## 记录装备：新加返回 true（带 emit + 阈值检查）；已有返回 false
func record_gear(gear: GearInstance) -> bool:
	var fp := fingerprint_of(gear)
	if fp == &"" or fingerprints.has(fp):
		return false
	fingerprints.append(fp)
	EventBus.weird_codex_recorded.emit(fp, fingerprints.size())
	_check_unlock_threshold()
	return true


func count() -> int:
	return fingerprints.size()


## 下一段碎片需要的 fingerprint 数；已全部解锁返回 -1
func next_threshold() -> int:
	if unlocked_fragments >= THRESHOLDS.size():
		return -1
	return THRESHOLDS[unlocked_fragments]


func _check_unlock_threshold() -> void:
	while unlocked_fragments < THRESHOLDS.size() and fingerprints.size() >= THRESHOLDS[unlocked_fragments]:
		unlocked_fragments += 1
		EventBus.identity_fragment_unlocked.emit(unlocked_fragments, fingerprints.size())


# ── 序列化 ────────────────────────────────────
func to_dict() -> Dictionary:
	var fps_ser: Array = []
	for f in fingerprints:
		fps_ser.append(String(f))
	return {
		"fingerprints": fps_ser,
		"unlocked_fragments": unlocked_fragments,
	}


func from_dict(d: Dictionary) -> void:
	fingerprints = []
	for s in d.get("fingerprints", []):
		fingerprints.append(StringName(s))
	unlocked_fragments = int(d.get("unlocked_fragments", 0))


func reset() -> void:
	fingerprints.clear()
	unlocked_fragments = 0
