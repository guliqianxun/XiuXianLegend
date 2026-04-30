class_name ShopRule
extends Resource
## 铺规：一条「条件 → 动作」。
## v1 简化：condition + action 都是固定枚举，不做 DSL parser。
## 攻破点：离线时按 disguise_tier 评估而非 tier，伪装怪客可被"拒怪客"规则放行。

## 唯一 id（玩家启用列表通过 id 引用）
@export var id: StringName = &""

## 显示名（中文短句）
@export var display_name: String = ""

## 条件枚举：
##   &"is_weird"     真实/伪装 tier == WEIRD
##   &"is_rare"      tier == RARE
##   &"is_regular"   tier == REGULAR
##   &"deep_night"   到访时辰在子-寅（0-2）
##   &"any"          匹配任何客人
##   &"has_trait"    客人 traits 包含 condition_arg（N5c trait 学习用）
@export var condition: StringName = &"any"

## condition 的参数（仅 has_trait 用，存 trait id 如 &"sole_dustless"）
@export var condition_arg: StringName = &""

## 动作枚举：
##   &"refuse"  拒
##   &"lend"    借
@export var action: StringName = &"refuse"


## 评估：客人是否匹配本条规则的 condition。
## - tier_to_use 由调用方决定（在线=真实 tier；离线=disguise_tier 或真实 tier）
## - traits：客人 CustomerData.traits，仅 has_trait condition 用
func matches(tier_to_use: int, shichen: int, traits: Array = []) -> bool:
	match condition:
		&"any":
			return true
		&"is_weird":
			return tier_to_use == 2
		&"is_rare":
			return tier_to_use == 1
		&"is_regular":
			return tier_to_use == 0
		&"deep_night":
			return shichen >= 0 and shichen <= 2
		&"has_trait":
			if condition_arg == &"": return false
			return traits.has(condition_arg)
		_:
			return false
