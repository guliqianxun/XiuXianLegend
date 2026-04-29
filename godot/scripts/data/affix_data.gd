class_name AffixData
extends Resource
## 词缀静态数据。一件装备包含多条 AffixInstance（运行时数据）引用此。

enum Polarity { POSITIVE, NEGATIVE, MIXED }
enum Tier { COMMON, UNCOMMON, RARE, FORBIDDEN, ARCANE }

@export var id: StringName
@export var display_name: String
@export_multiline var description_template: String   ## 用 {value} 占位
@export var polarity: Polarity = Polarity.POSITIVE
@export var min_tier: Tier = Tier.COMMON              ## 该词缀最早出现的品质
@export_range(0.0, 1.0) var weight: float = 1.0       ## 词缀池权重
@export var value_min: float = 1.0
@export var value_max: float = 10.0

## 效果钩子点（战斗系统按 hook 查询）：
##   "on_attack" / "on_turn_start" / "stat_mod" / "on_card_played" / "midnight"
@export var hooks: PackedStringArray = []
@export var script_impl: Script                       ## 实现该词缀效果的脚本

## 道途亲和（仅出现在某道途装备上时启用），空数组=通用。
@export var path_filter: Array[StringName] = []
