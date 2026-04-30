class_name LootRoller
extends RefCounted
## 装备 roll：按品质决定词缀条数 + 强制负词缀，按 weight + path_filter 抽词缀。
## 静态使用，不需要实例化。

## rarity -> [positive_count, negative_count]
const RARITY_AFFIX_COUNT: Dictionary = {
	0: [1, 0],
	1: [2, 0],
	2: [3, 0],
	3: [3, 1],   ## 禁 = 4 词缀，含 1 强制负
	4: [5, 0],   ## 秘
}


static func roll_gear(base_id: StringName, rarity_hint: int = 0) -> GearInstance:
	var inst := GearInstance.new()
	inst.base_id = base_id
	inst.rarity = clampi(rarity_hint, 0, 4)
	inst.seed = randi()
	_roll_affixes_into(inst)
	return inst


static func reroll(instance: GearInstance) -> void:
	if instance == null:
		return
	instance.affix_ids = []
	instance.affix_values = []
	instance.seed = randi()
	_roll_affixes_into(instance)


static func _roll_affixes_into(inst: GearInstance) -> void:
	var counts: Array = RARITY_AFFIX_COUNT.get(inst.rarity, [1, 0])
	var pos_n: int = int(counts[0])
	var neg_n: int = int(counts[1])

	var base: GearData = inst.get_base()
	var path: StringName = base.path_affinity if base != null else &""

	# 收集候选池
	var pool_pos: Array = []
	var pool_neg: Array = []
	for aid: StringName in DataRegistry.ids_of(&"affix"):
		var a: AffixData = DataRegistry.get_resource(&"affix", aid) as AffixData
		if a == null:
			continue
		if int(a.min_tier) > inst.rarity:
			continue
		if not _path_matches(a.path_filter, path):
			continue
		if a.polarity == AffixData.Polarity.NEGATIVE:
			pool_neg.append(a)
		else:
			pool_pos.append(a)

	var picked_ids: Array[StringName] = []
	var picked_vals: Array[float] = []
	for i in pos_n:
		var a: AffixData = _weighted_pick(pool_pos, picked_ids)
		if a == null:
			break
		picked_ids.append(a.id)
		picked_vals.append(_roll_value(a))
	for i in neg_n:
		var a: AffixData = _weighted_pick(pool_neg, picked_ids)
		if a == null:
			break
		picked_ids.append(a.id)
		picked_vals.append(_roll_value(a))

	inst.affix_ids = picked_ids
	inst.affix_values = picked_vals


static func _path_matches(filter: Array[StringName], path: StringName) -> bool:
	if filter.is_empty():
		return true
	return filter.has(path)


static func _weighted_pick(pool: Array, exclude: Array[StringName]) -> AffixData:
	var total: float = 0.0
	var avail: Array = []
	for a: AffixData in pool:
		if exclude.has(a.id):
			continue
		avail.append(a)
		total += a.weight
	if avail.is_empty() or total <= 0.0:
		return null
	var r: float = randf() * total
	for a: AffixData in avail:
		r -= a.weight
		if r <= 0.0:
			return a
	return avail.back()


static func _roll_value(a: AffixData) -> float:
	return randf_range(a.value_min, a.value_max)


## 按 encounter.loot_table 权重 roll 一个 slot，返回该 slot 下随机一个 base GearData
static func pick_slot_and_base(loot_table: Dictionary) -> Dictionary:
	if loot_table.is_empty():
		return {}
	var total: float = 0.0
	for k in loot_table:
		total += float(loot_table[k])
	if total <= 0.0:
		return {}
	var r: float = randf() * total
	var picked_slot: int = -1
	for k in loot_table:
		r -= float(loot_table[k])
		if r <= 0.0:
			picked_slot = int(k)
			break
	if picked_slot < 0:
		return {}
	# 找 slot 匹配的 GearData
	var candidates: Array[StringName] = []
	for gid: StringName in DataRegistry.ids_of(&"gear"):
		var gd: GearData = DataRegistry.get_resource(&"gear", gid) as GearData
		if gd == null:
			continue
		if int(gd.slot) == picked_slot:
			candidates.append(gid)
	if candidates.is_empty():
		return {}
	return {
		"slot": picked_slot,
		"base_id": candidates.pick_random(),
	}
