class_name CustomerRequest
extends RefCounted
## 客人一次访问的诉求快照（运行时值对象）。
## 由 CustomerSpawner 生成；EncounterState/UI 持有引用直到结算。

## 客人模板 id（CustomerData id）
var customer_id: StringName = &""
## 来访时间戳
var arrived_unix: int = 0
## 诉求：希望借哪种 slot_kind 装备
var desired_slot: StringName = &"sword"
## 诉求：最低品质（0=凡）
var min_quality: int = 0
## 酬金（灵石）
var payment: int = 100
## 任务名（用于回信叙事 placeholder）
var quest_label: String = "外勤"
## 借出后预计回信秒数（在线/离线 1:1）
var expected_duration_sec: int = 600  # 默认 10 分钟


func _to_string() -> String:
	return "[CustomerRequest %s wants %s>=Q%d for %d 灵石]" % [
		customer_id, desired_slot, min_quality, payment
	]
