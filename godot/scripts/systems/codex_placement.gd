class_name CodexPlacement
extends RefCounted
## 入谱公式：根据装备的 (slot_kind, quality, gupu) → 该装备应落入的 SuData id。
## 确定性公式，不随机。同 input 必返回同 output（玩家可学到规律）。
##
## v2（28 宿星宫图布局重排后）：path → 方位严格映射
## - sword (剑)       → 东方青龙 indices 0..4 (jiao/kang/di/fang/xin)，Q0..Q4
## - curse (符咒)     → 北方玄武 indices 7..11 (dou/niu/nv/xu/wei2)，Q0..Q4
## - puppet (傀核)    → 西方白虎 indices 14..18 (kui/lou/wei3/mao/bi2)，Q0..Q4
## - alchemy (丹)     → 南方朱雀 indices 21..25 (jing/gui/liu/xing/zhang)，Q0..Q4
## - eat (食器)       → 4 方位边缘 [5,6,12,13] (wei/ji/shi/bi)，Q0..Q3（Q4 不入）
## - divination (卜)  → 4 方位边缘 [19,20,26,27] (zi/shen/yi/zhen)，Q0..Q3（Q4 不入）
##
## 28 颗星全占满。"剑入青龙、咒入玄武" 视觉成立。

const PATH_BASE: Dictionary = {
	&"sword": 0,
	&"curse": 7,
	&"puppet": 14,
	&"alchemy": 21,
}

const PATH_SPARE: Dictionary = {
	&"eat": [5, 6, 12, 13],          # Q0=wei(东尾), Q1=ji(东末), Q2=shi(北右), Q3=bi(北末)
	&"divination": [19, 20, 26, 27], # Q0=zi(西下), Q1=shen(西末), Q2=yi(南左), Q3=zhen(南末)
}


## 给定装备的 slot 和品质，返回应落入的 SuData id。
## 不通过 gupu filter 或无对应位 → &""
static func find_su_for_equipment(slot_kind: StringName, quality: int, gupu: GuPuData) -> StringName:
	if gupu == null:
		return &""
	var path: StringName = _slot_to_path(slot_kind)
	if not gupu.accepts(path, quality):
		return &""
	var idx: int = _index_for(path, quality)
	if idx < 0 or idx >= gupu.stars.size():
		return &""
	var su: SuData = gupu.stars[idx]
	if su == null:
		return &""
	return su.id


## path × quality → su index in stars Array
static func _index_for(path: StringName, quality: int) -> int:
	if PATH_BASE.has(path):
		# 主 path：方位内 5 颗对应 Q0..Q4（封顶 4）
		var q: int = clampi(quality, 0, 4)
		return int(PATH_BASE[path]) + q
	if PATH_SPARE.has(path):
		# 次 path：4 颗对应 Q0..Q3，Q4 不入谱
		if quality > 3:
			return -1
		var arr: Array = PATH_SPARE[path]
		if quality < 0 or quality >= arr.size():
			return -1
		return int(arr[quality])
	return -1


static func _slot_to_path(slot_kind: StringName) -> StringName:
	match slot_kind:
		&"sword": return &"sword"
		&"talisman": return &"curse"
		&"puppet_core": return &"puppet"
		&"elixir_furnace": return &"alchemy"
		&"eating_vessel": return &"eat"
		&"divination_plate": return &"divination"
		_: return &""
