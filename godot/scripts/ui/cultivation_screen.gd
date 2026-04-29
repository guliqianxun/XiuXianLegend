extends Control
## 修炼面板（只读）：当前每小时灵石 / 见闻率 / 污染速率，HSlider 预览 1-12h 收益。

@onready var rate_label: RichTextLabel = %RateLabel
@onready var preview_label: RichTextLabel = %PreviewLabel
@onready var hours_slider: HSlider = %HoursSlider
@onready var hours_value: Label = %HoursValue
@onready var back_btn: Button = %BackBtn


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	hours_slider.min_value = 1.0
	hours_slider.max_value = 12.0
	hours_slider.step = 1.0
	hours_slider.value = 4.0
	hours_slider.value_changed.connect(_on_slider)
	_refresh_rates()
	_refresh_preview(hours_slider.value)


func _refresh_rates() -> void:
	var s: String = ""
	s += "[b]当前修炼速率（每小时）[/b]\n"
	s += "  · 灵石：[color=#e0c878]%d[/color]\n" % int(IdleSettlement.BASE_GEM_PER_H)
	s += "  · 修为：%d\n" % int(IdleSettlement.BASE_XP_PER_H)
	s += "  · 见闻率 λ：[color=#7fb6ff]%.2f / h[/color]（Poisson 采样）\n" % IdleSettlement.BASE_INSIGHT_RATE
	s += "  · 污染：[color=#c97cd9]%d[/color]\n" % int(IdleSettlement.BASE_POLLUTE_PER_H)
	s += "\n[i]软封顶 %d h 满速；超出至 %d h 半速衰减。每日首次结算 +%d%%。[/i]" % [
		int(IdleSettlement.SOFT_CAP_HOURS),
		int(IdleSettlement.HARD_CAP_HOURS),
		int(round((IdleSettlement.DAILY_FIRST_BONUS - 1.0) * 100.0)),
	]
	rate_label.text = s


func _refresh_preview(h: float) -> void:
	var eff: float = clampf(h, 0.0, IdleSettlement.SOFT_CAP_HOURS)
	var stones: int = int(IdleSettlement.BASE_GEM_PER_H * eff)
	var xp: int = int(IdleSettlement.BASE_XP_PER_H * eff)
	var pol: int = int(IdleSettlement.BASE_POLLUTE_PER_H * eff)
	var lam: float = IdleSettlement.BASE_INSIGHT_RATE * eff
	var s: String = ""
	s += "[b]预览：%d 小时收益（期望值）[/b]\n" % int(h)
	s += "  · 灵石  +%d\n" % stones
	s += "  · 修为  +%d\n" % xp
	s += "  · 见闻  ~ %.2f（Poisson(λ=%.2f)）\n" % [lam, lam]
	s += "  · 污染  +%d\n" % pol
	preview_label.text = s


func _on_slider(v: float) -> void:
	hours_value.text = "%d 小时" % int(v)
	_refresh_preview(v)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/city.tscn")
