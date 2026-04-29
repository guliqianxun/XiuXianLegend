class_name CardRewardDialog
extends PopupPanel
## 战斗后三选一加卡。MVP：从所有 path=sword 或 path="" 的卡里 roll。
## 已满 12 张则禁止加（在弹出前外层判断）。

signal picked(card_id: StringName)
signal closed()

const POOL_SIZE: int = 3

var _candidates: Array[StringName] = []


func _ready() -> void:
	exclusive = true
	close_requested.connect(func(): closed.emit())


func popup_three_choices() -> void:
	_candidates = _roll_three()
	_build_ui()
	popup_centered(Vector2i(560, 320))


func _roll_three() -> Array[StringName]:
	var pool: Array[StringName] = []
	for cid: StringName in DataRegistry.ids_of(&"card"):
		var c: CardData = DataRegistry.get_resource(&"card", cid) as CardData
		if c == null:
			continue
		if not c.rewardable:
			continue
		if c.path == &"sword" or c.path == &"":
			pool.append(cid)
	pool.shuffle()
	var n: int = mini(POOL_SIZE, pool.size())
	var out: Array[StringName] = []
	for i in n:
		out.append(pool[i])
	return out


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var title := Label.new()
	title.text = "三 选 一 · 加 入 卡 组"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	for cid in _candidates:
		var c: CardData = DataRegistry.get_resource(&"card", cid) as CardData
		if c == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 200)
		btn.text = "《%s》\n⚡%d\n\n%s" % [c.display_name, int(c.cost), c.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var picked_id := cid
		btn.pressed.connect(func(): _on_pick(picked_id))
		hb.add_child(btn)

	var skip := Button.new()
	skip.text = "跳过（不加卡）"
	skip.pressed.connect(_on_skip)
	vb.add_child(skip)


func _on_pick(cid: StringName) -> void:
	picked.emit(cid)
	hide()
	closed.emit()


func _on_skip() -> void:
	hide()
	closed.emit()
