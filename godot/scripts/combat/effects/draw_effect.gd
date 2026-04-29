class_name DrawEffect
extends CardEffect
## 抽 N 张牌。

@export var amount: int = 1


func apply(ctx: Dictionary) -> void:
	var state = ctx.get("state")
	var log: Callable = ctx.get("log")
	if state == null:
		return
	state._draw(amount)
	state.hand_changed.emit()
	if log.is_valid():
		log.call("[color=#cccccc]抽 %d 张牌。[/color]" % amount)


func describe(_card: Resource) -> String:
	return "抽 %d 张牌" % amount
