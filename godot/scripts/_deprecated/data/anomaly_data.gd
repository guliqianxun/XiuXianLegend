class_name AnomalyData
extends Resource
## 怪谈事件（夜晚触发）。文本 + 选项分支 + 可选战斗。

@export var id: StringName
@export var title: String
@export_multiline var prologue: String

## 触发权重与门槛
@export_range(0.0, 10.0) var weight: float = 1.0
@export var min_pollution: int = 0
@export var required_path: StringName = &""           ## 空=任意

@export var choices: Array[AnomalyChoice] = []


class AnomalyChoice extends Resource:
	@export var label: String
	@export_multiline var outcome_text: String
	@export var check_attribute: StringName = &""     ## 留空表示不检定
	@export var check_dc: int = 0
	@export var combat_encounter: StringName = &""    ## 非空则进入战斗
	@export var rewards: Dictionary = {}              ## { "spirit_stones": 100, "insights": 1 }
	@export var penalties: Dictionary = {}            ## { "pollution": 5, "sanity": -10 }
