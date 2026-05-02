class_name RecipeGenerator
extends RefCounted
## 程序化配方生成器。
## - prefix × 主材料 × slot 组合命名："凡铁剑" / "灵骨偶" / "古朱符"
## - 品阶分布按 tier（low / mid / high）
## - id 全 snake_case 英文（i18n key），display_name 中文

const PREFIXES_LOW: Array[String] = ["凡", "粗", "朴", "土"]
const PREFIXES_MID: Array[String] = ["灵", "活", "巧", "细"]
const PREFIXES_HIGH: Array[String] = ["法", "古", "异", "诡"]

const MATERIAL_SHORT: Dictionary = {
	&"tie": "铁",
	&"jin": "金",
	&"gu": "骨",
	&"zhu_sha": "朱",
	&"huang_zhi": "纸",
	&"hui": "灰",
}

const SLOT_SHORT: Dictionary = {
	&"sword": "剑",
	&"talisman": "符",
	&"puppet_core": "偶",
	&"elixir_furnace": "炉",
	&"eating_vessel": "器",
	&"divination_plate": "盘",
}

const SLOT_TO_PATH: Dictionary = {
	&"sword": &"sword",
	&"talisman": &"curse",
	&"puppet_core": &"puppet",
	&"elixir_furnace": &"alchemy",
	&"eating_vessel": &"eat",
	&"divination_plate": &"divination",
}

# slot → 推荐主材料 + 次材料 候选
const SLOT_MATERIAL_AFFINITY: Dictionary = {
	&"sword": {"primary": [&"tie"], "secondary": [&"jin", &"hui"]},
	&"talisman": {"primary": [&"zhu_sha"], "secondary": [&"huang_zhi", &"hui"]},
	&"puppet_core": {"primary": [&"tie"], "secondary": [&"zhu_sha", &"gu"]},
	&"elixir_furnace": {"primary": [&"tie"], "secondary": [&"jin", &"hui"]},
	&"eating_vessel": {"primary": [&"gu"], "secondary": [&"jin"]},
	&"divination_plate": {"primary": [&"jin"], "secondary": [&"huang_zhi", &"zhu_sha"]},
}

const SLOTS: Array[StringName] = [
	&"sword", &"talisman", &"puppet_core",
	&"elixir_furnace", &"eating_vessel", &"divination_plate",
]

# tier → quality_distribution（低/中/高 三档）
# 用 static var + 嵌套 Array：PackedFloat32Array 不能作 const 表达式
static var QUALITY_DIST_BY_TIER: Array = [
	[0.60, 0.25, 0.10, 0.04, 0.01],  # LOW
	[0.50, 0.30, 0.13, 0.05, 0.02],  # MID
	[0.40, 0.30, 0.18, 0.08, 0.04],  # HIGH
]

# tier → 炉时基线（分钟）
const MINUTES_BY_TIER: Array[int] = [25, 35, 50]


## 主入口：按 tier 生成一个 RecipeData
## tier: 0=LOW (凡品配方) / 1=MID (灵法品配方) / 2=HIGH (禁秘品配方)
static func generate(rng: RandomNumberGenerator, tier: int, gen_seed: int) -> RecipeData:
	var t: int = clampi(tier, 0, 2)
	var slot: StringName = SLOTS[rng.randi() % SLOTS.size()]
	var aff: Dictionary = SLOT_MATERIAL_AFFINITY[slot]
	var primary: StringName = (aff["primary"] as Array)[rng.randi() % (aff["primary"] as Array).size()]
	var secondary: StringName = (aff["secondary"] as Array)[rng.randi() % (aff["secondary"] as Array).size()]

	var r := RecipeData.new()
	r.id = StringName("gen:%d:%d" % [gen_seed, rng.randi() % 1000000])
	r.display_name = _make_name(rng, t, primary, slot)
	r.required_materials = {
		primary: rng.randi_range(2, 4),
		secondary: rng.randi_range(2, 6),
	}
	# 可选材料：从 secondary 池剩余抽 1-2
	var optional: Array[StringName] = []
	for m in (aff["secondary"] as Array):
		if m != secondary and rng.randf() < 0.5:
			optional.append(m)
	r.optional_materials = optional
	r.base_quality_distribution = PackedFloat32Array(QUALITY_DIST_BY_TIER[t])
	r.base_minutes_in_furnace = MINUTES_BY_TIER[t] + rng.randi_range(-5, 5)
	r.path_affinity = SLOT_TO_PATH[slot]
	r.slot_kind = slot
	return r


static func _make_name(rng: RandomNumberGenerator, tier: int, primary_mat: StringName, slot: StringName) -> String:
	var prefixes: Array[String]
	match tier:
		0: prefixes = PREFIXES_LOW
		1: prefixes = PREFIXES_MID
		2: prefixes = PREFIXES_HIGH
		_: prefixes = PREFIXES_LOW
	var prefix: String = prefixes[rng.randi() % prefixes.size()]
	var mat_zh: String = MATERIAL_SHORT.get(primary_mat, "")
	var slot_zh: String = SLOT_SHORT.get(slot, "")
	return prefix + mat_zh + slot_zh
