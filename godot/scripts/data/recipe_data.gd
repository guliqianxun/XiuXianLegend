class_name RecipeData
extends Resource
## 锻造配方。每个配方 = 一种兵器型号的烧法。
## 静态资源，存为 .tres，运行时不变。

## 唯一 id（snake_case）
@export var id: StringName = &""

## 显示名（中文），如 "凡铁剑"
@export var display_name: String = ""

## 必要材料：material_id -> 数量
@export var required_materials: Dictionary = {}

## 可选添料 ID 列表（玩家选 0..N 件加入）
@export var optional_materials: Array[StringName] = []

## 基准品质分布 [凡, 灵, 法, 禁, 秘]，应总和 1.0
@export var base_quality_distribution: PackedFloat32Array = PackedFloat32Array([0.6, 0.25, 0.10, 0.04, 0.01])

## 离线模式下单炉所需分钟（在线手动开炉走另一套时长，与本字段无关）
@export var base_minutes_in_furnace: int = 30

## 该配方主要属于的道途（剑/咒/傀/丹/食/卜），用于客人匹配
@export var path_affinity: StringName = &"sword"

## 槽位类型（剑/符/傀核/丹炉/食器/卦盘）
@export var slot_kind: StringName = &"sword"
