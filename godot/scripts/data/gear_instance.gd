class_name GearInstance
extends RefCounted
## 装备 *运行时* 实例。基础模板取自 GearData，具体词缀在生成时 roll。
## 通过 to_dict / from_dict 支持 JSON 存档。

var base_id: StringName = &""          ## GearData id
var affix_ids: Array[StringName] = []  ## AffixData id 列表
var affix_values: Array[float] = []    ## 与 affix_ids 一一对应
var rarity: int = 0                    ## 0 凡 1 灵 2 法 3 禁 4 秘
var seed: int = 0                      ## 生成种子（用于复现）


func get_base() -> GearData:
	return DataRegistry.get_resource(&"gear", base_id) as GearData


## 取词缀 i 的 AffixData 资源
func get_affix(i: int) -> AffixData:
	if i < 0 or i >= affix_ids.size():
		return null
	return DataRegistry.get_resource(&"affix", affix_ids[i]) as AffixData


func display_full_name() -> String:
	var base := get_base()
	var name := base.display_name if base != null else String(base_id)
	return "%s %s" % [rarity_prefix(rarity), name]


static func rarity_prefix(r: int) -> String:
	match r:
		0: return "[凡]"
		1: return "[灵]"
		2: return "[法]"
		3: return "[禁]"
		4: return "[秘]"
		_: return ""


static func rarity_color(r: int) -> Color:
	match r:
		0: return Color(0.78, 0.78, 0.78)
		1: return Color(0.55, 0.85, 1.0)
		2: return Color(0.7, 0.55, 0.95)
		3: return Color(0.95, 0.55, 0.4)
		4: return Color(1.0, 0.85, 0.35)
		_: return Color.WHITE


## 词缀展示文本（含数值）
func affix_lines() -> Array[String]:
	var out: Array[String] = []
	for i in affix_ids.size():
		var a := get_affix(i)
		if a == null:
			continue
		var v: float = affix_values[i]
		var tmpl: String = a.description_template
		if tmpl == "":
			tmpl = a.display_name + " {value}"
		var v_str: String = "%.1f" % v
		# 整数化展示更整洁
		if absf(v - round(v)) < 0.01:
			v_str = "%d" % int(round(v))
		out.append(tmpl.replace("{value}", v_str))
	return out


func to_dict() -> Dictionary:
	var ids_str: Array = []
	for n in affix_ids:
		ids_str.append(String(n))
	return {
		"base_id": String(base_id),
		"affix_ids": ids_str,
		"affix_values": affix_values.duplicate(),
		"rarity": rarity,
		"seed": seed,
	}


static func from_dict(d: Dictionary) -> GearInstance:
	var g := GearInstance.new()
	g.base_id = StringName(d.get("base_id", ""))
	var ids_raw: Array = d.get("affix_ids", [])
	var ids_typed: Array[StringName] = []
	for s in ids_raw:
		ids_typed.append(StringName(s))
	g.affix_ids = ids_typed
	var vals_raw: Array = d.get("affix_values", [])
	var vals_typed: Array[float] = []
	for v in vals_raw:
		vals_typed.append(float(v))
	g.affix_values = vals_typed
	g.rarity = int(d.get("rarity", 0))
	g.seed = int(d.get("seed", 0))
	return g
