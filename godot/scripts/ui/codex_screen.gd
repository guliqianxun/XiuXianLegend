extends Control
class_name CodexScreen
## 28 星图主 UI。
## - 顶部古谱名
## - 中央星图：按 SuData.position_x/y (0..1) 摆 28 个 StarNode
## - 主脉骨架线（按 GuPuData.preset_lines 画 Line2D）
## - 关闭按钮
## - 点击一颗星 → 打开 StarDetailPanel

const STAR_NODE_SCENE := preload("res://scenes/ui/star_node.tscn")

@onready var _title: Label = $Layout/Title
@onready var _gupu_tabs: HBoxContainer = $Layout/GupuTabs
@onready var _progress_label: Label = $Layout/Progress
@onready var _brush_label: Label = $Layout/BrushBar
@onready var _close_btn: Button = $Layout/CloseButton
@onready var _corner_close_btn: Button = $CornerCloseButton
@onready var _backdrop: ColorRect = $Backdrop
@onready var _seal_label: Label = $GupuSeal/Label
@onready var _star_field: Control = $Layout/StarField
@onready var _line_canvas: CodexLineCanvas = $Layout/StarField/LineCanvas
@onready var _detail_panel: StarDetailPanel = $StarDetailPanel

const GUPU_ORDER: Array[StringName] = [
	&"qing_long", &"xuan_wu", &"zhu_que", &"bai_hu", &"zi_wei", &"xue_yao", &"can_xiu",
]

var _gupu: GuPuData = null
var _star_nodes: Dictionary = {}  # su_id -> StarNode
var _selected_su: StringName = &""  # 第一颗已选星位（用于自连画线）


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)
	_corner_close_btn.pressed.connect(_on_close)
	EventBus.star_lit.connect(_on_star_lit)
	EventBus.resonance_activated.connect(_on_resonance_activated)
	EventBus.star_brushes_changed.connect(_on_brushes_changed)
	EventBus.player_line_drawn.connect(_on_player_line_drawn)
	EventBus.pattern_resonance_activated.connect(_on_pattern_activated)
	_build_gupu_tabs()


func open() -> void:
	# 强制 viewport size + position 0（与 ForgeScreen 同套防御）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	_load_current_gupu()
	# 等一帧让 layout 计算 StarField.size
	await get_tree().process_frame
	_rebuild_star_field()


func _build_gupu_tabs() -> void:
	for child in _gupu_tabs.get_children():
		child.queue_free()
	for gid in GUPU_ORDER:
		var g := DataRegistry.get_resource(&"gupu", gid) as GuPuData
		if g == null:
			continue
		var btn := Button.new()
		btn.text = g.display_name
		btn.custom_minimum_size = Vector2(96, 28)
		btn.add_theme_font_size_override("font_size", 13)
		var captured: StringName = gid
		btn.pressed.connect(func() -> void: _switch_to(captured))
		_gupu_tabs.add_child(btn)


func _switch_to(gupu_id: StringName) -> void:
	if gupu_id == CodexState.current_gupu_id:
		return
	CodexState.switch_gupu(gupu_id)
	_load_current_gupu()
	await get_tree().process_frame
	_rebuild_star_field()


func _load_current_gupu() -> void:
	_gupu = DataRegistry.get_resource(&"gupu", CodexState.current_gupu_id) as GuPuData
	if _gupu == null:
		push_warning("codex: gupu %s not loaded" % CodexState.current_gupu_id)
		return
	_apply_gupu_theme()
	_refresh_title_and_progress()


func _apply_gupu_theme() -> void:
	# 背景 ShaderMaterial.base_color 切到该谱 tint_color
	if _backdrop != null and _backdrop.material is ShaderMaterial:
		(_backdrop.material as ShaderMaterial).set_shader_parameter("base_color", _gupu.tint_color)
		_backdrop.color = Color(_gupu.tint_color.r, _gupu.tint_color.g, _gupu.tint_color.b, 0.95)
	# 印章单字
	if _seal_label != null:
		_seal_label.text = _gupu.glyph_char


func _refresh_title_and_progress() -> void:
	if _gupu == null:
		return
	var resonance_mark: String = " ✦" if GameState.has_resonance(_gupu.id) else ""
	_title.text = _gupu.display_name + resonance_mark
	_progress_label.text = "已点亮 %d / %d" % [CodexState.lit_star_count(), _gupu.stars.size()]
	_refresh_brush_label()


func _refresh_brush_label() -> void:
	if _brush_label == null: return
	var hint: String = ""
	if _selected_su != &"":
		hint = "  ·  已选 %s · 再点一颗连线" % _selected_su
	elif GameState.star_brushes > 0:
		hint = "  ·  点亮的星位上长按可连线"
	_brush_label.text = "星轨笔 %d%s" % [GameState.star_brushes, hint]


func _rebuild_star_field() -> void:
	# 清旧（保留 _line_canvas）
	for child in _star_field.get_children():
		if child != _line_canvas:
			child.queue_free()
	_star_nodes.clear()
	# 摆 28 颗星
	var field_size: Vector2 = _star_field.size
	if field_size.x < 100 or field_size.y < 100:
		field_size = Vector2(900, 540)
	for s: SuData in _gupu.stars:
		if s == null:
			continue
		var node: StarNode = STAR_NODE_SCENE.instantiate()
		_star_field.add_child(node)
		node.position = Vector2(s.position_x * field_size.x, s.position_y * field_size.y)
		var count: int = CodexState.equipments_at_star(s.id).size()
		node.setup(s.id, count, _gupu.accent_color)
		node.clicked.connect(_on_star_clicked)
		_star_nodes[s.id] = node
	# 重绘骨架
	_line_canvas.setup(_gupu, field_size)


func _on_star_lit(_gupu_id: StringName, su_id: StringName, _gear_inst: Resource) -> void:
	if not visible:
		return
	var node: StarNode = _star_nodes.get(su_id, null)
	if node != null:
		var c: Color = _gupu.accent_color if _gupu != null else StarNode.COLOR_LIT_GLOW
		node.setup(su_id, CodexState.equipments_at_star(su_id).size(), c)
	_refresh_title_and_progress()


func _on_resonance_activated(gupu_id: StringName, _pattern_id: StringName) -> void:
	# 触发反馈：屏震 + 嗡声 + 标题闪
	ScreenFx.shake(16.0, 0.6)
	Sfx.play_breach()
	if visible and gupu_id == CodexState.current_gupu_id:
		_refresh_title_and_progress()
		if _title != null:
			_title.scale = Vector2(0.85, 0.85)
			var tw := create_tween()
			tw.tween_property(_title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_star_clicked(su_id: StringName) -> void:
	if _gupu == null:
		return
	# N7b：如果有星轨笔 + 该星已点亮 → 进入"自连"模式；否则正常打开 detail
	var lit: bool = CodexState._stars.has(su_id)
	if GameState.star_brushes > 0 and lit:
		if _selected_su == &"":
			_selected_su = su_id
			_refresh_brush_label()
			Sfx.play_inspect()
			return
		if _selected_su == su_id:
			_selected_su = &""
			_refresh_brush_label()
			return
		# 第二颗 → 尝试画线
		var ok: bool = CodexState.add_player_line(_gupu.id, _selected_su, su_id)
		_selected_su = &""
		if ok:
			Sfx.play_forge(2)
		else:
			push_warning("draw line failed (条件不足)")
		_refresh_brush_label()
		return
	_detail_panel.open(_gupu, su_id)


func _on_brushes_changed(_n: int) -> void:
	_refresh_brush_label()


func _on_player_line_drawn(_g: StringName, _a: StringName, _b: StringName) -> void:
	if visible:
		_rebuild_star_field()  # 让 LineCanvas 重画含玩家线
		_refresh_title_and_progress()


func _on_pattern_activated(pattern_id: StringName) -> void:
	# 隐藏图案命中：屏震 + 嗡声 + 青色 flash（区别共鸣的金色）
	ScreenFx.shake(20.0, 0.8)
	ScreenFx.flash(Color(0.55, 0.85, 1.0), 0.45, 0.7)
	Sfx.play_breach()
	# 简单提示文本（无固定 NarrativeCard 类目，直接拼）
	if visible:
		var pattern_name: String = "图案"
		for gid in CodexState.PATTERN_LIBRARY:
			for p in CodexState.PATTERN_LIBRARY[gid]:
				if p["id"] == pattern_id:
					pattern_name = p["name"]
					break


func _on_close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
