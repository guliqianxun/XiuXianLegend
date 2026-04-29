class_name DamageEffect
extends CardEffect

@export var amount: int = 6
@export var kind: StringName = &"physical"


func apply(ctx: Dictionary) -> void:
	var target: CombatUnit = ctx.get("target")
	var source: CombatUnit = ctx.get("source")
	var log: Callable = ctx.get("log")
	if target == null or not target.is_alive():
		return

	var base_amt: int = amount
	var bonus_flat: int = 0
	var mult: float = 1.0
	if source != null:
		mult = source.attack_mult
		bonus_flat = source.attack_flat
	var raw: float = float(base_amt + bonus_flat) * mult
	var final_amt: int = int(round(raw))
	var crit: bool = source != null and source.crit_chance > 0.0 and randf() < source.crit_chance
	if crit:
		final_amt = int(round(final_amt * 1.5))

	var dealt: int = target.take_damage(final_amt, kind)
	if log.is_valid():
		var bonus_part: String = ""
		if source != null and (mult != 1.0 or bonus_flat != 0):
			var delta: int = final_amt - base_amt
			if delta != 0:
				bonus_part = " (%+d [装备])" % delta
		var crit_part: String = "  暴击!" if crit else ""
		log.call("[color=#e35d5d]%s 对 %s 造成 %d 点伤害%s%s。[/color]" % [
			source.display_name if source != null else "?", target.display_name, dealt, bonus_part, crit_part,
		])


func describe(_card: Resource) -> String:
	return "造成 %d 点伤害" % amount
