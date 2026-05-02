# godot/scripts/ui/material_shop_dialog.gd
class_name MaterialShopDialog
extends Control
## 灵石购料 modal。列出所有 unit_price > 0 的 MaterialData 行。

const MAX_QTY := 99

@onready var _list: VBoxContainer = $Frame/VBox/ScrollContainer/ListVBox
@onready var _stones_label: Label = $Frame/VBox/StonesLabel
@onready var _close_btn: Button = $Frame/VBox/HeaderHBox/CloseButton
var _qty_state: Dictionary = {}  # mid -> int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_btn.pressed.connect(_on_close)
	_refresh_stones()
	_build_rows()
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.materials_changed.connect(_on_materials_changed)

func _on_close() -> void:
	queue_free()

func _refresh_stones() -> void:
	_stones_label.text = "灵石：%d" % GameState.spirit_stones

func _on_currency_changed(_kind: StringName, _v: int) -> void:
	_refresh_stones()
	_refresh_buy_buttons()

func _on_materials_changed(_mid: StringName, _v: int) -> void:
	_refresh_rows()

func _build_rows() -> void:
	for child in _list.get_children():
		child.queue_free()
	var ids: Array = DataRegistry.ids_of(&"material")
	ids.sort()
	for mid in ids:
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		if md == null or md.unit_price <= 0:
			continue
		_qty_state[mid] = 1
		_list.add_child(_make_row(md))

func _make_row(md: MaterialData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = md.display_name
	name_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(name_label)
	var stock_label := Label.new()
	stock_label.name = "Stock"
	stock_label.text = "库存:%d" % GameState.material_count(md.id)
	stock_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(stock_label)
	var price_label := Label.new()
	price_label.text = "单价:%d" % md.unit_price
	price_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(price_label)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(28, 0)
	var captured_mid: StringName = md.id
	minus.pressed.connect(func() -> void: _adjust_qty(captured_mid, -1, row))
	row.add_child(minus)
	var qty_label := Label.new()
	qty_label.name = "Qty"
	qty_label.text = "1"
	qty_label.custom_minimum_size = Vector2(36, 0)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 0)
	plus.pressed.connect(func() -> void: _adjust_qty(captured_mid, 1, row))
	row.add_child(plus)
	var buy := Button.new()
	buy.name = "Buy"
	buy.text = "买"
	buy.custom_minimum_size = Vector2(48, 0)
	buy.pressed.connect(func() -> void: _on_buy(captured_mid, md))
	row.add_child(buy)
	_update_buy_state(buy, md, _qty_state[md.id])
	return row

func _adjust_qty(mid: StringName, delta: int, row: HBoxContainer) -> void:
	var new_qty: int = clampi(_qty_state.get(mid, 1) + delta, 1, MAX_QTY)
	_qty_state[mid] = new_qty
	(row.get_node("Qty") as Label).text = str(new_qty)
	var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
	_update_buy_state(row.get_node("Buy"), md, new_qty)

func _update_buy_state(btn: Button, md: MaterialData, qty: int) -> void:
	var cost: int = md.unit_price * qty
	btn.disabled = GameState.spirit_stones < cost

func _on_buy(mid: StringName, md: MaterialData) -> void:
	var qty: int = _qty_state.get(mid, 1)
	var cost: int = md.unit_price * qty
	if GameState.spirit_stones < cost:
		return
	GameState.add_currency(&"spirit_stones", -cost)
	GameState.add_material(mid, qty)
	EventLog.add_entry(&"shop_buy", "采办 %s×%d（-%d灵石）" % [md.display_name, qty, cost], &"normal")
	Sfx.play_paper_flutter()

func _refresh_rows() -> void:
	# 每行 stock 标签按当前库存刷新
	for row in _list.get_children():
		var stock: Label = row.get_node("Stock")
		var name_label: Label = row.get_child(0)
		var md: MaterialData = _find_md_by_display(name_label.text)
		if md != null:
			stock.text = "库存:%d" % GameState.material_count(md.id)

func _refresh_buy_buttons() -> void:
	for row in _list.get_children():
		var name_label: Label = row.get_child(0)
		var md: MaterialData = _find_md_by_display(name_label.text)
		if md == null: continue
		var btn: Button = row.get_node("Buy")
		_update_buy_state(btn, md, _qty_state.get(md.id, 1))

func _find_md_by_display(disp: String) -> MaterialData:
	for mid in DataRegistry.ids_of(&"material"):
		var md: MaterialData = DataRegistry.get_resource(&"material", mid) as MaterialData
		if md != null and md.display_name == disp:
			return md
	return null
