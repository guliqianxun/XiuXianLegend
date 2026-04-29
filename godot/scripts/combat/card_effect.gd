class_name CardEffect
extends Resource
## 卡牌效果抽象基类（命令模式）。
## 每个具体效果一个子类，CardData.effect_scripts 为有序列表，依次执行。
## 子类覆写 apply() 即可，不要在子类持有运行时引用。

## ctx 字段约定：
##   "state":  CombatState
##   "source": CombatUnit  （出牌方）
##   "target": CombatUnit  （目标，可能为 null）
##   "log":    Callable(text: String) -> void  战斗日志回调
func apply(ctx: Dictionary) -> void:
	push_warning("CardEffect.apply not overridden")


func describe(_card: Resource) -> String:
	return ""
