extends Control
## 妖谭塔界面：列出 10 层，点当前层进战斗。

@onready var floor_list: VBoxContainer = %FloorList
@onready var back_btn: Button = %BackBtn
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_refresh()


func _refresh() -> void:
	for c in floor_list.get_children():
		c.queue_free()
	title_label.text = "妖 谭 塔   第 %d 层 / 已抵达 %d 层" % [GameState.tower_floor, GameState.tower_max_reached]
	for i in range(1, 11):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.theme_type_variation = "TowerFloor"
		btn.add_theme_font_size_override("font_size", 18)
		var enc_id := StringName("floor_%02d" % i)
		var enc: EncounterData = DataRegistry.get_resource(&"encounter", enc_id) as EncounterData
		var name_text: String = enc.display_name if enc != null else ("第 %d 层" % i)
		var tier_mark: String = "  ★精英" if enc != null and enc.tier == 2 else ""
		var status: String
		var disabled: bool = false
		if i < GameState.tower_max_reached:
			status = "✓ 已通关"
		elif i == GameState.tower_max_reached:
			status = "▶ 当前层"
		else:
			status = "🔒 锁定"
			disabled = true
		btn.text = "  %2d 层  · %s%s     %s" % [i, name_text, tier_mark, status]
		btn.disabled = disabled
		var floor_idx := i
		btn.pressed.connect(func(): _on_pick_floor(floor_idx))
		floor_list.add_child(btn)


func _on_pick_floor(i: int) -> void:
	GameState.tower_floor = i
	GameState.current_encounter_id = StringName("floor_%02d" % i)
	get_tree().change_scene_to_file("res://scenes/combat.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/city.tscn")
