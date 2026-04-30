class_name StatsResolver
extends RefCounted
## 装备 → 战斗属性结算。MVP 只实装 stat_mod 类型词缀。
## 词缀 id 约定（与 .tres 对齐）：
##   atk_pct / atk_flat / crit_pct / hp_max_flat / qi_max_flat / pollute_resist_pct
##   neg_self_dmg_midnight / neg_atk_pct / neg_crit_pct / neg_extra_pollution
## hooks 含 "stat_mod" 时按 id 累加；含其他 hook（on_attack/midnight）暂记 TODO。

const DEFAULT_STATS: Dictionary = {
	"attack_mult": 1.0,
	"attack_flat": 0,
	"crit_chance": 0.0,
	"hp_max_bonus": 0,
	"qi_max_bonus": 0,
	"pollute_resist": 0.0,
}


static func resolve(equipped: Dictionary) -> Dictionary:
	var s: Dictionary = DEFAULT_STATS.duplicate()
	for slot_int in equipped:
		var inst: GearInstance = equipped[slot_int]
		if inst == null:
			continue
		var base: GearData = inst.get_base()
		if base != null:
			s["attack_flat"] = int(s["attack_flat"]) + int(base.base_attack)
		for i in inst.affix_ids.size():
			var a: AffixData = inst.get_affix(i)
			if a == null:
				continue
			var v: float = inst.affix_values[i]
			_apply_affix(s, a, v)
	return s


static func _apply_affix(s: Dictionary, a: AffixData, v: float) -> void:
	# stat_mod hook 才计入；非 stat_mod（on_attack / midnight 等）MVP 不实装
	var is_stat: bool = a.hooks.has("stat_mod")
	if not is_stat:
		# TODO: on_attack / midnight 等钩子在战斗系统接入后实装
		return
	var key: String = String(a.id)
	# 道途变种映射回基础 stat key（如 atk_pct_high -> atk_pct）
	if key.begins_with("atk_pct"):
		key = "atk_pct"
	elif key.begins_with("crit_pct"):
		key = "crit_pct"
	elif key.begins_with("hp_max"):
		key = "hp_max_flat"
	elif key.begins_with("qi_max") or key == "start_qi":
		key = "qi_max_flat"
	match key:
		"atk_pct":
			s["attack_mult"] = float(s["attack_mult"]) + v / 100.0
		"atk_flat":
			s["attack_flat"] = int(s["attack_flat"]) + int(round(v))
		"crit_pct":
			s["crit_chance"] = float(s["crit_chance"]) + v / 100.0
		"hp_max_flat":
			s["hp_max_bonus"] = int(s["hp_max_bonus"]) + int(round(v))
		"qi_max_flat":
			s["qi_max_bonus"] = int(s["qi_max_bonus"]) + int(round(v))
		"pollute_resist_pct":
			s["pollute_resist"] = float(s["pollute_resist"]) + v / 100.0
		"neg_atk_pct":
			s["attack_mult"] = float(s["attack_mult"]) - v / 100.0
		"neg_crit_pct":
			s["crit_chance"] = float(s["crit_chance"]) - v / 100.0
		"neg_hp_max":
			s["hp_max_bonus"] = int(s["hp_max_bonus"]) - int(round(v))
		"mix_glass_cannon":
			s["attack_mult"] = float(s["attack_mult"]) + v / 100.0
			s["hp_max_bonus"] = int(s["hp_max_bonus"]) - 10
		"mix_qi_for_pollution":
			s["qi_max_bonus"] = int(s["qi_max_bonus"]) + int(round(v))
			s["pollute_resist"] = float(s["pollute_resist"]) - 0.10
		_:
			pass
