extends Control
class_name ForgeTopBar
## 炉房顶栏：配方下拉 + 材料缩略 + 闭门按钮。
## ForgeScreen 提供 recipes 列表，TopBar emit 信号回去。

signal recipe_picked(recipe_id: StringName)
signal close_pressed

const COLOR_OK := Color(0.910, 0.846, 0.659, 1.0)
const COLOR_ABUNDANT := Color(0.745, 0.920, 0.650, 1.0)
const COLOR_LACK := Color(0.752, 0.345, 0.282, 1.0)

@onready var _recipe_picker: OptionButton = $HBox/RecipePicker
@onready var _materials_box: HBoxContainer = $HBox/MaterialsBox
@onready var _close_btn: Button = $HBox/CloseButton

var _recipes: Array[RecipeData] = []


func _ready() -> void:
	_recipe_picker.item_selected.connect(_on_picker_selected)
	_close_btn.pressed.connect(func() -> void: close_pressed.emit())


## ForgeScreen 调用：刷新可选配方列表
func set_recipes(recipes: Array[RecipeData]) -> void:
	_recipes = recipes
	_recipe_picker.clear()
	for r in _recipes:
		_recipe_picker.add_item(r.display_name)
	if not _recipes.is_empty():
		_on_picker_selected(0)


## ForgeScreen 调用：根据当前 recipe 刷新材料缩略颜色
func refresh_materials(recipe: RecipeData) -> void:
	for child in _materials_box.get_children():
		child.queue_free()
	if recipe == null: return
	for mid in recipe.required_materials:
		var need: int = int(recipe.required_materials[mid])
		var have: int = GameState.material_count(mid)
		var lbl := Label.new()
		lbl.text = "%s:%d" % [_short_name(mid), have]
		lbl.add_theme_font_size_override("font_size", 12)
		var col: Color
		if have >= need * 2:
			col = COLOR_ABUNDANT
		elif have >= need:
			col = COLOR_OK
		else:
			col = COLOR_LACK
		lbl.add_theme_color_override("font_color", col)
		_materials_box.add_child(lbl)


func _on_picker_selected(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size(): return
	var r := _recipes[idx]
	recipe_picked.emit(r.id)
	refresh_materials(r)


## 材料 id → 短名（铁/金/朱/纸/灰/骨...）
static func _short_name(material_id: StringName) -> String:
	match material_id:
		&"iron": return "铁"
		&"jin": return "金"
		&"zhusha": return "朱"
		&"yellow_paper": return "纸"
		&"hui": return "灰"
		&"bone": return "骨"
		&"yi_zhong_liao": return "异"
		_: return String(material_id)
