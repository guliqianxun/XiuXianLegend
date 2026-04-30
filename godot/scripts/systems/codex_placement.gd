class_name CodexPlacement
extends RefCounted
## 入谱公式：根据装备的 (slot_kind, quality, gupu) → 返回该装备应落入的 SuData id。
## 确定性公式，不随机。同 input 必返回同 output（玩家可学到规律）。

## 给定装备的 slot 和品质，在 gupu 中找到 match 的 SuData，返回其 id。
## 不 match 任何星位返回 &""。
## - slot_kind: 装备 slot 字符串（"sword"/"talisman"/...）
## - quality: 0..4
## - gupu: 当前选中的古谱
static func find_su_for_equipment(slot_kind: StringName, quality: int, gupu: GuPuData) -> StringName:
	if gupu == null:
		return &""
	# N3 简化：青龙宿 28 颗按 generate_sus.py 的 (slot_idx, quality_band) 矩阵布局
	# 索引规则与 generator 同步：i = band*6 + slot_idx
	var slot_idx: int = _slot_to_index(slot_kind)
	if slot_idx < 0:
		return &""
	var band: int = _quality_to_band(quality)
	var target_i: int = band * 6 + slot_idx
	if target_i < 0 or target_i >= gupu.stars.size():
		return &""
	var su: SuData = gupu.stars[target_i]
	if su == null:
		return &""
	return su.id


static func _slot_to_index(slot_kind: StringName) -> int:
	match slot_kind:
		&"sword": return 0
		&"talisman": return 1
		&"puppet_core": return 2
		&"elixir_furnace": return 3
		&"eating_vessel": return 4
		&"divination_plate": return 5
		_: return -1


static func _quality_to_band(quality: int) -> int:
	match quality:
		0: return 0  # 凡
		1: return 1  # 灵
		2: return 2  # 法
		3, 4: return 3  # 禁/秘合并
		_: return 0
