class_name FactionData
extends Resource
## 势力背景板（spec §8）。
## 玩家不能"经营"势力，势力是"天气"——影响来客构成 + 来料 + 公榜。
## v1：只用 active_state 影响 spawner 的 faction bias。

@export var id: StringName = &""
@export var display_name: String = ""
## 风格描述，UI / 叙事用
@export var style: String = ""
## 基线关系（中-友 / 中 / 中-敌 / 敌）— 当前仅描述用，N9+ 接关系数值
@export var baseline_relation: String = "中"
## 该势力影响维度描述（"高酬客" / "供料商" / "怪客" 等）
@export var influence: String = ""
