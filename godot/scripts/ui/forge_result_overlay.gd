extends Control
class_name ForgeResultOverlay
## 出炉爆点遮罩。按品质 0-4 显示不同视觉强度的"开奖动画"。
## N2 用 ColorRect 渐变 + 持续时长差异；N9 接真音效与粒子。

## 5 档颜色（凡-灵-法-禁-秘）
const TIER_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85, 0.0),   # 凡 — 几乎不变
	Color(0.45, 0.95, 0.55, 0.45),  # 灵 — 绿光
	Color(0.45, 0.65, 0.95, 0.55),  # 法 — 蓝光
	Color(0.85, 0.40, 0.95, 0.65),  # 禁 — 紫光 + 屋震
	Color(1.00, 0.85, 0.35, 0.85),  # 秘 — 金光满屋
]

## 5 档持续时间（秒）
const TIER_DURATIONS: Array[float] = [0.4, 0.8, 1.2, 1.8, 2.6]

## 反噬专用色（暗红）
const BACKLASH_COLOR := Color(0.85, 0.20, 0.15, 0.55)
const BACKLASH_DURATION: float = 1.2

signal animation_finished

@onready var _flash: ColorRect = $Flash


func _ready() -> void:
	visible = false
	_flash.color = Color(0, 0, 0, 0)


## 播放出炉动画。quality: 0..4 = 凡灵法禁秘；-1 = 反噬
func play(quality: int) -> void:
	visible = true
	var color: Color
	var duration: float
	if quality < 0:
		color = BACKLASH_COLOR
		duration = BACKLASH_DURATION
	else:
		var t: int = clampi(quality, 0, 4)
		color = TIER_COLORS[t]
		duration = TIER_DURATIONS[t]
	# tween：颜色 fade in 30% / hold 40% / fade out 30%
	var tw := create_tween()
	tw.tween_property(_flash, "color", color, duration * 0.3)
	tw.tween_interval(duration * 0.4)
	tw.tween_property(_flash, "color", Color(color.r, color.g, color.b, 0.0), duration * 0.3)
	tw.tween_callback(_on_done)
	# Q3/Q4 屋震
	if quality >= 3:
		_shake(duration)


func _shake(duration: float) -> void:
	var origin := position
	var tw := create_tween()
	for i in 6:
		tw.tween_property(self, "position", origin + Vector2(randf_range(-6, 6), randf_range(-6, 6)), duration / 12.0)
	tw.tween_property(self, "position", origin, duration / 12.0)


func _on_done() -> void:
	visible = false
	_flash.color = Color(0, 0, 0, 0)
	animation_finished.emit()
