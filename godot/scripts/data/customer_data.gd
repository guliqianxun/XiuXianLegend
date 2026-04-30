class_name CustomerData
extends Resource
## 客人模板。运行时实例化为"一次访问"。

enum Tier { REGULAR = 0, RARE = 1, WEIRD = 2 }

## 唯一 id
@export var id: StringName = &""

## 显示名
@export var display_name: String = ""

## 客人品阶
@export var tier: Tier = Tier.REGULAR

## 流派亲和（剑/咒/傀/丹/食/卜）
@export var path_affinity: StringName = &"sword"

## 所属势力 id（背景板）
@export var faction: StringName = &"unknown"

## 基础酬金（灵石）
@export var base_payment: int = 100

## 出现条件（spec §6 + §8）：
## 时辰范围（0=子, 1=丑..11=亥），空数组=任意时辰
@export var allowed_shichen: Array[int] = []

## 当此势力"动态状态"激活时来访权重 +N（N1 暂不实装动态状态，留字段）
@export var faction_state_bonus: float = 0.0

## 伪装名（spec §7.3：怪客可"伪装"成符合铺规的客人）
## 空 = 不伪装（常客真名公开）；非空 = 此名字会先显示给玩家，需"打听"识破
@export var disguise_name: String = ""

## 伪装看起来的 tier（仅当 disguise_name 非空时生效）
## -1 = 跟真实 tier 一致（仅改名）；0..2 = 显示成 REGULAR/RARE/WEIRD
@export var disguise_tier: int = -1
