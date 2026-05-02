extends Node
## 屏幕反馈 Autoload。
## - shake(intensity_px, duration_sec)：随机抖动主场景根节点 position
## - flash(color, peak_alpha, duration_sec)：屏幕全屏色块淡入淡出（出炉/反噬）
## 仅依赖当前 scene 是 Node2D（Shop 主场景成立）；若主场景换 Control 需调整。

var _shake_target: Node2D = null
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_remaining: float = 0.0
var _shake_intensity: float = 0.0

var _flash_overlay: ColorRect = null
var _flash_canvas: CanvasLayer = null


func _process(delta: float) -> void:
	if _shake_remaining <= 0.0 or _shake_target == null:
		return
	_shake_remaining -= delta
	if _shake_remaining <= 0.0:
		_shake_target.position = _shake_origin
		_shake_target = null
		return
	var ratio: float = clampf(_shake_remaining / max(0.001, _shake_initial), 0.0, 1.0)
	var amp: float = _shake_intensity * ratio
	_shake_target.position = _shake_origin + Vector2(
		randf_range(-amp, amp),
		randf_range(-amp, amp),
	)


var _shake_initial: float = 0.0


## 全屏色块 flash：淡入到 peak_alpha 然后淡出。常用于反噬/出炉/共鸣。
## - color：颜色（建议低饱和；alpha 不被 peak_alpha 覆盖前会用 color.a）
## - peak_alpha：达到的最大 alpha 0..1
## - duration_sec：总时长（淡入 0.4 + 淡出 0.6 比例）
func flash(color: Color, peak_alpha: float, duration_sec: float = 0.4) -> void:
	if duration_sec <= 0.0 or peak_alpha <= 0.0:
		return
	_ensure_flash_overlay()
	if _flash_overlay == null: return
	var c: Color = color
	c.a = 0.0
	_flash_overlay.color = c
	_flash_overlay.visible = true
	var fade_in: float = duration_sec * 0.4
	var fade_out: float = duration_sec * 0.6
	var tw := create_tween()
	tw.tween_property(_flash_overlay, "color:a", peak_alpha, fade_in)
	tw.tween_property(_flash_overlay, "color:a", 0.0, fade_out)
	tw.tween_callback(func() -> void:
		if _flash_overlay != null:
			_flash_overlay.visible = false)


func _ensure_flash_overlay() -> void:
	if _flash_overlay != null and is_instance_valid(_flash_overlay):
		return
	var tree := get_tree()
	if tree == null or tree.root == null: return
	if _flash_canvas == null or not is_instance_valid(_flash_canvas):
		_flash_canvas = CanvasLayer.new()
		_flash_canvas.layer = 100  # 顶层
		tree.root.add_child(_flash_canvas)
	_flash_overlay = ColorRect.new()
	_flash_overlay.anchor_right = 1.0
	_flash_overlay.anchor_bottom = 1.0
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(0, 0, 0, 0)
	_flash_overlay.visible = false
	_flash_canvas.add_child(_flash_overlay)


func shake(intensity_px: float, duration_sec: float) -> void:
	if intensity_px <= 0.0 or duration_sec <= 0.0:
		return
	var tree := get_tree()
	if tree == null: return
	var root: Node = tree.current_scene
	if root == null or not (root is Node2D):
		return
	# 已有正在抖：先归零再叠新
	if _shake_target != null:
		_shake_target.position = _shake_origin
	_shake_target = root as Node2D
	_shake_origin = _shake_target.position
	_shake_intensity = intensity_px
	_shake_remaining = duration_sec
	_shake_initial = duration_sec
