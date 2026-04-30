extends Control
class_name RulesScreen
## 立规面板（后院"立规"入口）。
## - 列出 4 条预设规则的 CheckBox
## - 玩家勾选 / 取消即时生效（最多 3 条）
## - 关闭时存档

signal closed

@onready var _title: Label = $Frame/Layout/Title
@onready var _list_root: VBoxContainer = $Frame/Layout/RulesList
@onready var _hint: Label = $Frame/Layout/Hint
@onready var _close_btn: Button = $Frame/Layout/Buttons/CloseBtn

var _checks: Dictionary = {}  # id -> CheckBox


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)


func open() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_rebuild()


func _rebuild() -> void:
	_title.text = "立铺规（最多 %d 条）" % ShopRules.MAX_SLOTS
	# 清旧
	for child in _list_root.get_children():
		child.queue_free()
	_checks.clear()
	# 重建
	for id in ShopRules.all_preset_ids():
		var rule: ShopRule = ShopRules.get_preset(id)
		if rule == null: continue
		var cb := CheckBox.new()
		cb.text = "%s   ·   [%s → %s]" % [rule.display_name, _cond_zh(rule.condition), _act_zh(rule.action)]
		cb.button_pressed = ShopRules.is_enabled(id)
		var captured_id: StringName = id
		cb.toggled.connect(func(on: bool) -> void: _on_toggle(captured_id, on))
		_list_root.add_child(cb)
		_checks[id] = cb
	_refresh_hint()


func _on_toggle(id: StringName, on: bool) -> void:
	if on:
		if not ShopRules.enable(id):
			# 满了，回滚 UI
			(_checks[id] as CheckBox).set_pressed_no_signal(false)
			_hint.text = "已达上限 %d 条" % ShopRules.MAX_SLOTS
			return
	else:
		ShopRules.disable(id)
	_refresh_hint()


func _refresh_hint() -> void:
	_hint.text = "已启用 %d / %d 条" % [ShopRules.enabled.size(), ShopRules.MAX_SLOTS]


func _on_close() -> void:
	visible = false
	SaveSystem.save_now(true)
	closed.emit()


static func _cond_zh(c: StringName) -> String:
	match c:
		&"any": return "任何客人"
		&"is_weird": return "怪客"
		&"is_rare": return "罕客"
		&"is_regular": return "常客"
		&"deep_night": return "深夜"
		_: return String(c)


static func _act_zh(a: StringName) -> String:
	match a:
		&"refuse": return "拒"
		&"lend": return "借"
		_: return String(a)
