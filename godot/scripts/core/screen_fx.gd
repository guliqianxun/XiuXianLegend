extends Node
## 屏幕反馈 Autoload。
## - shake(intensity_px, duration_sec)：随机抖动主场景根节点 position
## 仅依赖当前 scene 是 Node2D（Shop 主场景成立）；若主场景换 Control 需调整。

var _shake_target: Node2D = null
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_remaining: float = 0.0
var _shake_intensity: float = 0.0


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
