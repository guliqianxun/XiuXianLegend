class_name GuPuData
extends Resource
## 古谱：28 颗 SuData 的集合 + 共鸣效果定义。
## 玩家可在多张古谱视图间切换；每张古谱独立计算"已点亮星位"。

## 唯一 id
@export var id: StringName = &""

## 显示名，如 "青龙宿"
@export var display_name: String = ""

## 主题描述，如 "剑系兵器"
@export var theme: String = ""

## 共鸣文字描述（凑齐 28 颗后触发的效果说明）
@export var resonance_description: String = ""

## 28 颗星宿（应固定 28 个，编辑器中保证）
@export var stars: Array[SuData] = []

## 主脉骨架连线：每对 (i, j) 表示 stars[i] 和 stars[j] 之间有预设主脉
## 用 PackedInt32Array 存 [i0, j0, i1, j1, ...]
@export var preset_lines: PackedInt32Array = PackedInt32Array()
