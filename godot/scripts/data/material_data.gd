# godot/scripts/data/material_data.gd
class_name MaterialData
extends Resource
## 材料静态数据。N6+ 经济：unit_price 决定可购买性，affix_bias 影响开炉词缀权重。

@export var id: StringName               ## 主键（全拼音 snake_case）
@export var display_name: String          ## 玩家可见中文名（如 "铁" / "朱砂"）
@export var short_name: String            ## 1 字简写，用于 LogFlow / TopBar 缩略
@export var unit_price: int = 0           ## 单价灵石；0 = 不可购买（如 hui/yi）
@export var category: StringName          ## &"common" / &"weird" / &"byproduct" / &"weird_byproduct"
@export var affix_bias: Dictionary = {}   ## { path StringName : int weight bonus }
