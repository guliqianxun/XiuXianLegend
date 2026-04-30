extends Node2D
class_name OldIron
## 老铁化身（白发老者剪影 placeholder）。
## N1 仅显示 + 简单移动；后续 milestone 接入动画与状态。

@export var move_speed: float = 80.0  # 像素/秒

var _target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_pos = global_position


func _process(delta: float) -> void:
	if global_position.distance_to(_target_pos) < 1.0:
		return
	var dir := (_target_pos - global_position).normalized()
	global_position += dir * move_speed * delta


## 设置目标位置（铺子内部坐标）；老铁会自动走过去
func walk_to(world_pos: Vector2) -> void:
	_target_pos = world_pos
