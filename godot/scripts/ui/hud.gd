extends PanelContainer
## 顶栏 HUD：灵石 / 见闻 / 污染 / 道心。
## 严格订阅 EventBus，禁止轮询。GameState 改值后 emit 信号驱动 UI。

@onready var stones_label: Label = %StonesLabel
@onready var insights_label: Label = %InsightsLabel
@onready var pollution_bar: ProgressBar = %PollutionBar
@onready var pollution_label: Label = %PollutionLabel
@onready var sanity_bar: ProgressBar = %SanityBar
@onready var sanity_label: Label = %SanityLabel


func _ready() -> void:
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.pollution_changed.connect(_on_pollution_changed)
	EventBus.sanity_changed.connect(_on_sanity_changed)
	_refresh_all()


func _refresh_all() -> void:
	_on_currency_changed(&"spirit_stones", GameState.spirit_stones)
	_on_currency_changed(&"insights", GameState.insights)
	_on_pollution_changed(GameState.pollution, GameState.pollution_cap)
	_on_sanity_changed(GameState.sanity, GameState.sanity_cap)


func _on_currency_changed(kind: StringName, value: int) -> void:
	match kind:
		&"spirit_stones":
			stones_label.text = "灵石 %d" % value
		&"insights":
			insights_label.text = "见闻 %d" % value


func _on_pollution_changed(value: int, max_value: int) -> void:
	pollution_bar.max_value = max_value
	pollution_bar.value = value
	pollution_label.text = "污染 %d/%d" % [value, max_value]


func _on_sanity_changed(value: int, max_value: int) -> void:
	sanity_bar.max_value = max_value
	sanity_bar.value = value
	sanity_label.text = "道心 %d/%d" % [value, max_value]
