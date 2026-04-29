class_name GearData
extends Resource
## 装备 *基础* 静态数据（模板）。具体词缀 roll 在 GearInstance（运行时）。

enum Slot { SWORD, TALISMAN, PUPPET_CORE, ELIXIR_FURNACE, EATING_VESSEL, DIVINATION_PLATE }

@export var id: StringName
@export var display_name: String
@export_multiline var flavor: String
@export var slot: Slot = Slot.SWORD
@export var path_affinity: StringName = &""           ## 道途亲和，空=通用
@export var icon: Texture2D
## 基础属性（不含词缀）
@export var base_attack: int = 0
@export var base_defense: int = 0
