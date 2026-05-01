extends Control
class_name InventoryStrip
## 屏幕底部常驻的"在铺装备"小卡列表。
## 让玩家随时知道自己造出了什么 — Cultist Simulator 风格"状态全在桌面"。
## v1：纯显示，最多 MAX_SHOWN 张，超出加 +N 提示。

const MAX_SHOWN: int = 8

@onready var _list_root: HBoxContainer = $Frame/HBox
@onready var _label_count: Label = $Frame/HBox/Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 防 anchor-on-Node2D 坑：自行强制 size + position
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2(0, vp_size.y - 54)
	size = Vector2(vp_size.x, 54)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.equipment_lent.connect(func(_c: StringName, _g: Resource) -> void: _refresh())
	EventBus.equipment_returned.connect(func(_c: StringName, _g: Resource, _o: StringName) -> void: _refresh())
	EventBus.save_loaded.connect(_refresh)
	_refresh()


func _on_loot_dropped(_items: Array) -> void:
	_refresh()


func _refresh() -> void:
	if _list_root == null: return
	# 清旧（保留 Label 占位）
	for child in _list_root.get_children():
		if child != _label_count:
			child.queue_free()
	# 拿 IN_SHOP 装备
	var shop_gears: Array = []
	for inst in GameState.inventory:
		if inst is GearInstance and (inst as GearInstance).status == GearInstance.Status.IN_SHOP:
			shop_gears.append(inst)
	# 显示前 MAX_SHOWN 件
	var n: int = mini(shop_gears.size(), MAX_SHOWN)
	for i in n:
		var g: GearInstance = shop_gears[i]
		var card := _make_card(g)
		# 在 Label 之前插入
		_list_root.add_child(card)
		_list_root.move_child(card, _list_root.get_child_count() - 2)  # 把 Label 顶到末尾
	# Label 显示总数 + 超量
	if shop_gears.size() == 0:
		_label_count.text = "（铺中无器）"
	elif shop_gears.size() <= MAX_SHOWN:
		_label_count.text = "共 %d 件在铺" % shop_gears.size()
	else:
		_label_count.text = "+ %d 件" % (shop_gears.size() - MAX_SHOWN)


func _make_card(g: GearInstance) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(132, 36)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = g.display_full_name()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", _color_for_rarity(g.rarity))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(lbl)
	return p


static func _color_for_rarity(r: int) -> Color:
	match r:
		0: return Color(0.75, 0.72, 0.66)  # 凡 灰
		1: return Color(0.70, 0.85, 0.95)  # 灵 浅青
		2: return Color(0.85, 0.85, 0.55)  # 法 浅黄
		3: return Color(0.95, 0.65, 0.55)  # 禁 红
		4: return Color(0.95, 0.95, 0.55)  # 秘 金
		_: return Color(0.7, 0.7, 0.7)
