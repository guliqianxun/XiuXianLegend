class_name ForgeResult
extends RefCounted
## 单次锻造的结算结果。值对象（不可变最佳，但 GDScript 没有 immutability 修饰，按约定不修改）。

## 出炉品质 0..4；反噬时为 -1
var quality: int = 0

## 是否触发巧成
var was_qiao_cheng: bool = false

## 是否触发反噬
var was_backlash: bool = false

## 出炉装备实例（反噬时为 null）
var equipment: GearInstance = null

## 反噬副产物 ID（反噬时为 &"hui" 或 &"yi"，否则为空）
var byproduct: StringName = &""

## 反噬副产物数量（反噬时 1，否则 0）
var byproduct_amount: int = 0


func _to_string() -> String:
	if was_backlash:
		return "[ForgeResult BACKLASH byproduct=%s x%d]" % [byproduct, byproduct_amount]
	var prefix := "巧成 " if was_qiao_cheng else ""
	return "[ForgeResult %sQ%d %s]" % [prefix, quality, equipment]
