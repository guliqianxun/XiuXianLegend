class_name BlockEffect
extends CardEffect

@export var amount: int = 5


func apply(ctx: Dictionary) -> void:
	var source: CombatUnit = ctx.get("source")
	var log: Callable = ctx.get("log")
	source.add_block(amount)
	if log.is_valid():
		log.call("[color=#7fb6ff]%s 凝神格挡 +%d。[/color]" % [source.display_name, amount])


func describe(_card: Resource) -> String:
	return "获得 %d 点格挡" % amount
