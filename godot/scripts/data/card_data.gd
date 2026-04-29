class_name CardData
extends Resource
## 卡牌静态数据。运行时实例数据另放（手牌/弃牌堆等用 dict 表示）。

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var path: StringName = &"sword"          ## 所属道途
@export_range(0, 9) var cost: int = 1            ## 灵气消耗
@export var rarity: int = 0                      ## 0 凡 / 1 灵 / 2 法 / 3 禁 / 4 秘
@export var pollute_on_play: int = 0             ## 出牌污染（污染牌 > 0）
@export var icon: Texture2D
@export var art: Texture2D

## 效果链（命令模式）。每个元素是一个 CardEffect 子资源，按序执行。
## 子资源可带参数（如 DamageEffect.amount = 5），同一卡可挂多个效果。
@export var effects: Array[CardEffect] = []

## 是否可作为战后三选一奖励候选（默认 true；惩罚类如 taint_lashout 设 false）
@export var rewardable: bool = true
