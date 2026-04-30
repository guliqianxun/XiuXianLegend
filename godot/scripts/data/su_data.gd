class_name SuData
extends Resource
## 单星宿——古谱里的一颗预设星位。
## 装备出炉后按 (path, quality) 落入哪颗星，由本类的 match_* 字段决定。

## 唯一 id（在所属古谱内唯一）
@export var id: StringName = &""

## 显示名，如 "角宿"
@export var display_name: String = ""

## 落点匹配：必须满足装备的 path_affinity == match_path
@export var match_path: StringName = &"sword"

## 落点匹配：装备的 quality 必须 ∈ [match_quality_min, match_quality_max]
## 0=凡 1=灵 2=法 3=禁 4=秘
@export_range(0, 4) var match_quality_min: int = 0
@export_range(0, 4) var match_quality_max: int = 4

## 在星图上的归一化坐标 (0..1)
@export_range(0.0, 1.0) var position_x: float = 0.0
@export_range(0.0, 1.0) var position_y: float = 0.0
