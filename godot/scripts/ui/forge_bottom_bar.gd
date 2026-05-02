extends Control
class_name ForgeBottomBar
## 炉房底栏：动态生成添料 chips + 大开炉按钮。
## 玩家点 chip → 切换 selected 状态；点开炉 → emit 信号，附 selected 列表。

signal start_pressed(selected_optional: Array)

@onready var _chips_box: HBoxContainer = $HBox/ChipsBox
@onready var _start_btn: Button = $HBox/StartButton

# material_id (StringName) → bool（是否选中）
var _chip_state: Dictionary = {}
var _current_recipe: RecipeData = null


func _ready() -> void:
	_start_btn.pressed.connect(_on_start)


## ForgeScreen 调用：根据新 recipe 重建 chips
func rebuild_chips(recipe: RecipeData) -> void:
	_current_recipe = recipe
	_chip_state.clear()
	for child in _chips_box.get_children():
		child.queue_free()
	if recipe == null:
		_start_btn.disabled = true
		return
	for mid in recipe.optional_materials:
		var have: int = GameState.material_count(mid)
		var btn := Button.new()
		btn.text = "+ %s" % ForgeTopBar._short_name(mid)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = have <= 0
		btn.custom_minimum_size = Vector2(80, 0)
		var captured: StringName = mid
		btn.pressed.connect(func() -> void: _toggle_chip(captured, btn))
		_chips_box.add_child(btn)
	refresh_start_enabled()


## ForgeScreen 调用：根据材料是否够用刷新 start 按钮
func refresh_start_enabled() -> void:
	if _current_recipe == null:
		_start_btn.disabled = true
		return
	var ok: bool = true
	for mid in _current_recipe.required_materials:
		if GameState.material_count(mid) < int(_current_recipe.required_materials[mid]):
			ok = false
			break
	_start_btn.disabled = not ok


func selected_optional() -> Array:
	var out: Array = []
	for mid in _chip_state:
		if _chip_state[mid]:
			out.append(mid)
	return out


func _toggle_chip(mid: StringName, btn: Button) -> void:
	var on: bool = not bool(_chip_state.get(mid, false))
	_chip_state[mid] = on
	if on:
		btn.text = "✓ %s" % ForgeTopBar._short_name(mid)
		btn.add_theme_color_override("font_color", Color(0.940, 0.685, 0.345, 1.0))
	else:
		btn.text = "+ %s" % ForgeTopBar._short_name(mid)
		btn.remove_theme_color_override("font_color")


func _on_start() -> void:
	start_pressed.emit(selected_optional())
