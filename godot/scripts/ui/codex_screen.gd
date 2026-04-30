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
@onready var _close_btn: Button = $Layout/CloseButton
@onready var _star_field: Control = $Layout/StarField
@onready var _line_canvas: CodexLineCanvas = $Layout/StarField/LineCanvas
@onready var _detail_panel: StarDetailPanel = $StarDetailPanel

var _gupu: GuPuData = null
var _star_nodes: Dictionary = {}  # su_id -> StarNode


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close)
	EventBus.star_lit.connect(_on_star_lit)


func open() -> void:
	# 强制 viewport size + position 0（与 ForgeScreen 同套防御）
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	visible = true
	# 加载当前古谱
	_gupu = DataRegistry.get_resource(&"gupu", CodexState.current_gupu_id) as GuPuData
	if _gupu == null:
		push_warning("codex: gupu %s not loaded" % CodexState.current_gupu_id)
		return
	_title.text = _gupu.display_name
	# 等一帧让 layout 计算 StarField.size
	await get_tree().process_frame
	_rebuild_star_field()


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
		node.setup(s.id, count)
		node.clicked.connect(_on_star_clicked)
		_star_nodes[s.id] = node
	# 重绘骨架
	_line_canvas.setup(_gupu, field_size)


func _on_star_lit(_gupu_id: StringName, su_id: StringName, _gear_inst: Resource) -> void:
	if not visible:
		return
	var node: StarNode = _star_nodes.get(su_id, null)
	if node != null:
		node.setup(su_id, CodexState.equipments_at_star(su_id).size())


func _on_star_clicked(su_id: StringName) -> void:
	if _gupu == null:
		return
	_detail_panel.open(_gupu, su_id)


func _on_close() -> void:
	visible = false
