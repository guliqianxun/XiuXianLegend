extends Control
class_name ForgeScreen
## 锻造弹窗。
## 工作流：选配方 → 勾可选添料 → 点"开炉" → 火候判定 → 结算 → 出炉动画 → 关闭

@onready var _recipe_picker: OptionButton = $Layout/RecipePicker
@onready var _material_status: Label = $Layout/MaterialStatus
@onready var _optional_picker: ItemList = $Layout/OptionalPicker
@onready var _start_button: Button = $Layout/StartButton
@onready var _close_button: Button = $Layout/CloseButton
@onready var _result_label: Label = $Layout/ResultLabel
@onready var _timing_window: TimingWindow = $TimingWindow
@onready var _result_overlay: ForgeResultOverlay = $ResultOverlay

var _recipes: Array[RecipeData] = []
var _current_recipe: RecipeData = null
var _selected_optional: Array[StringName] = []


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close)
	_start_button.pressed.connect(_on_start)
	_recipe_picker.item_selected.connect(_on_recipe_selected)
	_optional_picker.multi_selected.connect(_on_optional_toggled)
	_timing_window.timing_finished.connect(_on_timing_finished)
	_result_overlay.animation_finished.connect(_on_overlay_done)


## 入口：从 ShopScreen 调用打开锻造弹窗
func open() -> void:
	_load_recipes()
	if _recipes.is_empty():
		push_warning("forge: no recipes available")
		return
	_recipe_picker.clear()
	for r in _recipes:
		_recipe_picker.add_item(r.display_name)
	_on_recipe_selected(0)
	_result_label.text = ""
	visible = true


func _load_recipes() -> void:
	_recipes.clear()
	for id in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", id) as RecipeData
		if r != null:
			_recipes.append(r)


func _on_recipe_selected(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size():
		return
	_current_recipe = _recipes[idx]
	_selected_optional.clear()
	_refresh_material_status()
	_refresh_optional_picker()


func _refresh_material_status() -> void:
	if _current_recipe == null:
		_material_status.text = ""
		return
	var lines: Array[String] = []
	var enough := true
	for mid in _current_recipe.required_materials:
		var need: int = int(_current_recipe.required_materials[mid])
		var have: int = GameState.material_count(mid)
		var marker := "✓" if have >= need else "✗"
		if have < need:
			enough = false
		lines.append("  %s %s ×%d (库存 %d)" % [marker, str(mid), need, have])
	_material_status.text = "材料：\n" + "\n".join(lines)
	_start_button.disabled = not enough


func _refresh_optional_picker() -> void:
	_optional_picker.clear()
	if _current_recipe == null:
		return
	for mid in _current_recipe.optional_materials:
		var have: int = GameState.material_count(mid)
		var label: String = "%s (库存 %d)" % [str(mid), have]
		_optional_picker.add_item(label)
		if have == 0:
			var idx := _optional_picker.item_count - 1
			_optional_picker.set_item_disabled(idx, true)


func _on_optional_toggled(_idx: int, _selected: bool) -> void:
	_selected_optional.clear()
	if _current_recipe == null: return
	for i in _optional_picker.item_count:
		if _optional_picker.is_selected(i) and not _optional_picker.is_item_disabled(i):
			_selected_optional.append(_current_recipe.optional_materials[i])


func _on_start() -> void:
	if _current_recipe == null: return
	# 消耗必要材料 + 可选添料
	for mid in _current_recipe.required_materials:
		var need: int = int(_current_recipe.required_materials[mid])
		GameState.consume_material(mid, need)
	for mid in _selected_optional:
		GameState.consume_material(mid, 1)
	_start_button.disabled = true
	EventBus.forge_started.emit(_current_recipe.id)
	_timing_window.start()


func _on_timing_finished(score: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := ForgeSystem.forge_one(
		_current_recipe,
		_selected_optional,
		score,
		GameState.smith_hand_today,
		TimeLine.now_unix(),
		rng
	)
	if result.was_backlash:
		GameState.add_material(result.byproduct, result.byproduct_amount)
		_result_label.text = "⚠ 反噬！材料化作 %s ×1" % str(result.byproduct)
		_result_overlay.play(-1)
		# 反噬反馈：低沉嗡声 + 大震
		Sfx.play_breach()
		ScreenFx.shake(14.0, 0.5)
	else:
		GameState.add_to_inventory(result.equipment)
		var qiao_str := "（巧成 +1 阶）" if result.was_qiao_cheng else ""
		_result_label.text = "出炉：%s %s" % [GearInstance.rarity_prefix(result.quality), qiao_str]
		_result_overlay.play(result.quality)
		# 出炉反馈：5 级铛声 + 渐强震动（凡 0px / 秘 12px）
		Sfx.play_forge(int(result.quality))
		ScreenFx.shake(float(int(result.quality)) * 3.0, 0.3)
		_pulse_label(_result_label)
	EventBus.forge_finished.emit(result.equipment, result.was_qiao_cheng, result.was_backlash)


func _pulse_label(label: Label) -> void:
	if label == null: return
	label.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_overlay_done() -> void:
	_refresh_material_status()
	_refresh_optional_picker()


func _on_close() -> void:
	visible = false
