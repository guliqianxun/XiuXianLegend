class_name EncounterData
extends Resource
## 遭遇 / 战斗模板（妖谭塔单层）。

@export var id: StringName
@export var display_name: String
@export var hp: int = 24
@export var atk: int = 4
@export var intent_pool: Array[String] = ["獠牙撕咬", "怨气呼啸", "残影一击"]

## slot_int(GearData.Slot) -> weight
@export var loot_table: Dictionary = {}

@export var tier: int = 1                ## 1 普通 2 精英
@export var rarity_hint: int = 0         ## 掉落基础品质（精英自动 +1）
@export var spirit_stones_min: int = 30
@export var spirit_stones_max: int = 50
@export var insight_chance: float = 0.33
