extends Control
## 锻造界面：背包 + 槽位 + 装备/卸下/洗练。
## MVP 仅启用 3 槽：剑 / 符 / 丹炉。

const REROLL_COST: int = 200
const ENABLED_SLOTS: Array = [
	GearData.Slot.SWORD,
	GearData.Slot.TALISMAN,
	GearData.Slot.ELIXIR_FURNACE,
]
const SLOT_NAMES: Dictionary = {
	GearData.Slot.SWORD: "剑",
	GearData.Slot.TALISMAN: "符",
	GearData.Slot.ELIXIR_FURNACE: "丹炉",
}

@onready var inv_list: ItemList = %InvList
@onready var slot_box: VBoxContainer = %SlotBox
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var btn_equip: Button = %BtnEquip
@onready var btn_unequip: Button = %BtnUnequip
@onready var btn_reroll: Button = %BtnReroll
@onready var btn_back: Button = %BtnBack
@onready var stones_label: Label = %StonesLabel

var _selected_inv_index: int = -1
var _selected_slot: int = -1
var _reroll_dialog: ConfirmationDialog


func _ready() -> void:
	btn_equip.pressed.connect(_on_equip)
	btn_unequip.pressed.connect(_on_unequip)
	btn_reroll.pressed.connect(_on_reroll)
	btn_back.pressed.connect(_on_back)
	inv_list.item_selected.connect(_on_inv_selected)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.gear_equipped.connect(func(_a, _b): _refresh())
	EventBus.loot_dropped.connect(func(_a): _refresh())
	_refresh()


func _refresh() -> void:
	stones_label.text = "灵石 %d" % GameState.spirit_stones
	# 背包列表
	inv_list.clear()
	for i in GameState.inventory.size():
		var inst: GearInstance = GameState.inventory[i]
		if inst == null:
			continue
		inv_list.add_item(inst.display_full_name())
		var color := GearInstance.rarity_color(inst.rarity)
		inv_list.set_item_custom_fg_color(i, color)

	# 槽位
	for c in slot_box.get_children():
		c.queue_free()
	for slot in ENABLED_SLOTS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = "[%s]" % SLOT_NAMES.get(slot, "?")
		lbl.custom_minimum_size = Vector2(60, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		hb.add_child(lbl)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inst: GearInstance = GameState.equipped.get(int(slot), null)
		if inst != null:
			btn.text = inst.display_full_name()
		else:
			btn.text = "<空>"
		var slot_int := int(slot)
		btn.pressed.connect(func(): _on_slot_selected(slot_int))
		hb.add_child(btn)
		slot_box.add_child(hb)

	_refresh_detail()
	_refresh_buttons()


func _refresh_detail() -> void:
	var inst: GearInstance = _selected_instance()
	var s: String = ""
	if inst == null:
		s = "[i]选择一件装备查看详情。[/i]\n"
	else:
		var color := GearInstance.rarity_color(inst.rarity)
		var hex := "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
		s = "[color=%s][b]%s[/b][/color]\n" % [hex, inst.display_full_name()]
		var base := inst.get_base()
		if base != null:
			s += "基础攻击 %d  ·  道途：%s\n" % [base.base_attack, String(base.path_affinity)]
		for line in inst.affix_lines():
			s += "  · " + line + "\n"
	# 汇总加成（基于全部已装备）
	s += "\n[color=#9bb0c0][b]当前装备汇总[/b][/color]\n"
	s += _format_total_stats()
	detail_label.text = s


func _format_total_stats() -> String:
	var stats: Dictionary = StatsResolver.resolve(GameState.equipped)
	var lines: Array[String] = []
	var atk_mult: float = float(stats.get("attack_mult", 1.0))
	if abs(atk_mult - 1.0) > 0.001:
		lines.append("  · 攻击 %+.0f%%" % ((atk_mult - 1.0) * 100.0))
	var atk_flat: int = int(stats.get("attack_flat", 0))
	if atk_flat != 0:
		lines.append("  · 攻击 %+d" % atk_flat)
	var crit: float = float(stats.get("crit_chance", 0.0))
	if abs(crit) > 0.0001:
		lines.append("  · 暴击 %+.0f%%" % (crit * 100.0))
	var hp_b: int = int(stats.get("hp_max_bonus", 0))
	if hp_b != 0:
		lines.append("  · 气血上限 %+d" % hp_b)
	var qi_b: int = int(stats.get("qi_max_bonus", 0))
	if qi_b != 0:
		lines.append("  · 灵气上限 %+d" % qi_b)
	var pr: float = float(stats.get("pollute_resist", 0.0))
	if abs(pr) > 0.0001:
		lines.append("  · 污染抗性 %+.0f%%" % (pr * 100.0))
	if lines.is_empty():
		return "  [i]（无加成）[/i]\n"
	return "\n".join(lines) + "\n"


func _refresh_buttons() -> void:
	var inv_inst: GearInstance = _inv_inst_at(_selected_inv_index)
	var slot_inst: GearInstance = GameState.equipped.get(_selected_slot, null) if _selected_slot >= 0 else null
	btn_equip.disabled = inv_inst == null
	btn_unequip.disabled = slot_inst == null
	var sel: GearInstance = _selected_instance()
	btn_reroll.disabled = sel == null or GameState.spirit_stones < REROLL_COST


func _selected_instance() -> GearInstance:
	if _selected_inv_index >= 0:
		return _inv_inst_at(_selected_inv_index)
	if _selected_slot >= 0:
		return GameState.equipped.get(_selected_slot, null)
	return null


func _inv_inst_at(idx: int) -> GearInstance:
	if idx < 0 or idx >= GameState.inventory.size():
		return null
	return GameState.inventory[idx]


func _on_inv_selected(idx: int) -> void:
	_selected_inv_index = idx
	_selected_slot = -1
	_refresh_detail()
	_refresh_buttons()


func _on_slot_selected(slot: int) -> void:
	_selected_slot = slot
	_selected_inv_index = -1
	inv_list.deselect_all()
	_refresh_detail()
	_refresh_buttons()


func _on_equip() -> void:
	var inst: GearInstance = _inv_inst_at(_selected_inv_index)
	if inst == null:
		return
	GameState.equip_gear(inst)
	_selected_inv_index = -1
	SaveSystem.save_now(true)
	_refresh()


func _on_unequip() -> void:
	if _selected_slot < 0:
		return
	GameState.unequip_slot(_selected_slot)
	SaveSystem.save_now(true)
	_refresh()


func _on_reroll() -> void:
	var inst: GearInstance = _selected_instance()
	if inst == null:
		return
	if GameState.spirit_stones < REROLL_COST:
		return
	if _reroll_dialog == null:
		_reroll_dialog = ConfirmationDialog.new()
		_reroll_dialog.title = "洗练确认"
		_reroll_dialog.confirmed.connect(_on_reroll_confirmed)
		add_child(_reroll_dialog)
	_reroll_dialog.dialog_text = "消耗 %d 灵石重洗全部词缀，无保底。继续？" % REROLL_COST
	_reroll_dialog.popup_centered()


func _on_reroll_confirmed() -> void:
	var inst: GearInstance = _selected_instance()
	if inst == null:
		return
	if not GameState.spend_currency(&"spirit_stones", REROLL_COST):
		return
	LootRoller.reroll(inst)
	EventBus.gear_reforged.emit(inst.base_id)
	SaveSystem.save_now(true)
	_refresh()


func _on_currency_changed(_kind: StringName, _value: int) -> void:
	stones_label.text = "灵石 %d" % GameState.spirit_stones
	_refresh_buttons()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/city.tscn")
