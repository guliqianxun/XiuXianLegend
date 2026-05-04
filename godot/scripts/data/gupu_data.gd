class_name GuPuData
extends Resource
## 古谱：28 颗 SuData 的集合 + 共鸣效果定义。
## 玩家可在多张古谱视图间切换；每张古谱独立计算"已点亮星位"。

## 唯一 id
@export var id: StringName = &""

## 显示名，如 "青龙宿"
@export var display_name: String = ""

## 主题描述，如 "剑系兵器"
@export var theme: String = ""

## 共鸣文字描述（凑齐 28 颗后触发的效果说明）
@export var resonance_description: String = ""

## 28 颗星宿（应固定 28 个，编辑器中保证）
@export var stars: Array[SuData] = []

## 主脉骨架连线：每对 (i, j) 表示 stars[i] 和 stars[j] 之间有预设主脉
## 用 PackedInt32Array 存 [i0, j0, i1, j1, ...]
@export var preset_lines: PackedInt32Array = PackedInt32Array()

## 入谱 filter（spec §5.2 各古谱主题）
## - allowed_paths：允许的 path_affinity 列表；空 = 任意
## - quality_min/max：装备 quality 范围
## 装备入谱前先过 filter，不过则此谱不收（玩家可切谱后重造）
@export var allowed_paths: Array[StringName] = []
@export var quality_min: int = 0
@export var quality_max: int = 4

## 视觉主题（用于切谱时差异化背景/星点/主脉色）
@export var tint_color: Color = Color(0.022, 0.020, 0.045, 1.0)   ## 背景基调
@export var accent_color: Color = Color(0.940, 0.685, 0.345, 1.0) ## 主脉线 + 星点 glow
@export var glyph_char: String = "谱"                              ## 右上角印章单字


## 装备 (path, quality) 能否入此谱
func accepts(path_affinity: StringName, quality: int) -> bool:
	if not allowed_paths.is_empty() and not allowed_paths.has(path_affinity):
		return false
	if quality < quality_min or quality > quality_max:
		return false
	return true
