extends Control
class_name ForgeScreen
## 锻造弹窗（控制台日志风）。
## 协调 3 个子组件：TopBar / LogFlow / BottomBar；TimingWindow 嵌入 LogFlow 顶；
## ResultOverlay 浮屏。业务逻辑全在 ForgeSystem，本类只串信号。

@onready var _top_bar: ForgeTopBar = $Layout/TopBar
@onready var _log_flow: ForgeLogFlow = $Layout/LogFlow
@onready var _bottom_bar: ForgeBottomBar = $Layout/BottomBar
@onready var _timing_window: TimingWindow = $TimingWindow
@onready var _result_overlay: ForgeResultOverlay = $ResultOverlay

var _recipes: Array[RecipeData] = []
var _current_recipe: RecipeData = null
var _last_selected_optional: Array = []


func _ready() -> void:
	visible = false
	_top_bar.recipe_picked.connect(_on_recipe_picked)
	_top_bar.close_pressed.connect(_on_close)
	_bottom_bar.start_pressed.connect(_on_start)
	_timing_window.timing_finished.connect(_on_timing_finished)
	_result_overlay.animation_finished.connect(_on_overlay_done)


## 入口：从 ShopScreen 打开
func open() -> void:
	_load_recipes()
	if _recipes.is_empty():
		push_warning("forge: no recipes available")
		return
	_top_bar.set_recipes(_recipes)
	visible = true


func _load_recipes() -> void:
	_recipes.clear()
	for id in DataRegistry.ids_of(&"recipe"):
		var r := DataRegistry.get_resource(&"recipe", id) as RecipeData
		if r != null:
			_recipes.append(r)


func _on_recipe_picked(recipe_id: StringName) -> void:
	for r in _recipes:
		if r.id == recipe_id:
			_current_recipe = r
			break
	_last_selected_optional.clear()
	_bottom_bar.rebuild_chips(_current_recipe)


func _on_start(selected_optional: Array) -> void:
	if _current_recipe == null: return
	_last_selected_optional = selected_optional
	# 消耗必要材料 + 可选添料
	for mid in _current_recipe.required_materials:
		var need: int = int(_current_recipe.required_materials[mid])
		GameState.consume_material(mid, need)
	for mid in selected_optional:
		GameState.consume_material(mid, 1)
	# 投料 EventLog 行（forge_invest）
	var invest_text: String = _format_invest_text(_current_recipe, selected_optional)
	EventLog.add_entry(&"forge_invest", invest_text, &"normal")
	EventBus.forge_started.emit(_current_recipe.id)
	_timing_window.start()


static func _format_invest_text(recipe: RecipeData, optional: Array) -> String:
	var parts: Array[String] = ["投料 %s" % recipe.display_name]
	for mid in recipe.required_materials:
		parts.append("%s×%d" % [ForgeTopBar._short_name(mid), int(recipe.required_materials[mid])])
	if not optional.is_empty():
		var opts: Array[String] = []
		for mid in optional:
			opts.append(ForgeTopBar._short_name(mid))
		parts.append("+ " + " ".join(opts))
	return " ".join(parts)


func _on_timing_finished(score: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := ForgeSystem.forge_one(
		_current_recipe,
		_last_selected_optional,
		score,
		GameState.smith_hand_today,
		TimeLine.now_unix(),
		rng
	)
	if result.was_backlash:
		GameState.add_material(result.byproduct, result.byproduct_amount)
		_result_overlay.play(-1)
		Sfx.play_breach()
		ScreenFx.shake(14.0, 0.5)
		EventLog.add_entry(&"forge_backlash",
			"反噬！材料化作 %s ×%d" % [ForgeTopBar._short_name(result.byproduct), result.byproduct_amount],
			&"bad")
	else:
		GameState.add_to_inventory(result.equipment)
		_result_overlay.play(result.quality)
		Sfx.play_forge(int(result.quality))
		ScreenFx.shake(float(int(result.quality)) * 3.0, 0.3)
		var color: StringName = &"system" if result.quality >= 4 else (&"good" if (result.was_qiao_cheng or result.quality >= 3) else &"normal")
		var qiao: String = "（巧成）" if result.was_qiao_cheng else ""
		EventLog.add_entry(&"forge_done",
			"出炉：%s%s" % [result.equipment.display_full_name(), qiao],
			color)
	EventBus.forge_finished.emit(result.equipment, result.was_qiao_cheng, result.was_backlash)


func _on_overlay_done() -> void:
	# 注意：rebuild_chips 会清空 _chip_state — 这是设计意图（每次出炉后玩家重新选添料）
	# 刷新材料缩略 + chips 状态（消耗后数量变了）
	if _current_recipe != null:
		_top_bar.refresh_materials(_current_recipe)
		_bottom_bar.rebuild_chips(_current_recipe)


func _on_close() -> void:
	visible = false
