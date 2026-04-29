class_name HealEffect
extends CardEffect

@export var amount: int = 4


func apply(ctx: Dictionary) -> void:
	var source: CombatUnit = ctx.get("source")
	var log: Callable = ctx.get("log")
	var healed: int = source.heal(amount)
	if log.is_valid():
		log.call("[color=#9cd97c]%s 调息回复 %d 生命。[/color]" % [source.display_name, healed])


func describe(_card: Resource) -> String:
	return "回复 %d 点生命" % amount
