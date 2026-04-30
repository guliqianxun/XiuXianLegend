extends Control
## 主城场景。
## 职责：进入即触发离线结算 → 显示弹窗 → HUD 反映新状态。
## 4 个入口按钮（修炼 / 锻造 / 序列 / 怪谈）暂为 placeholder。

@onready var settle_dialog: AcceptDialog = %SettleDialog
@onready var btn_cultivate: Button = %BtnCultivate
@onready var btn_forge: Button = %BtnForge
@onready var btn_sequence: Button = %BtnSequence
@onready var btn_anomaly: Button = %BtnAnomaly
@onready var btn_quick_idle: Button = %BtnQuickIdle


func _ready() -> void:
	SaveSystem.load_or_init()
	_run_idle_settlement()

	btn_cultivate.pressed.connect(_on_cultivate)
	btn_forge.pressed.connect(_on_forge)
	btn_sequence.pressed.connect(_todo.bind("序列"))
	btn_anomaly.pressed.connect(_on_enter_tower)
	btn_quick_idle.pressed.connect(_on_quick_idle)


func _run_idle_settlement() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	if GameState.last_settle_unix <= 0:
		GameState.last_settle_unix = now_unix
		SaveSystem.save_now(true)
		return

	var report: Dictionary = IdleSettlement.settle(now_unix, GameState.last_settle_unix)
	# MINOR-4: 间隔太短直接 return，不弹窗（每日首次跨午夜仍弹）
	if float(report.get("effective_hours", 0.0)) < 0.05 and not bool(report.get("daily_bonus_applied", false)):
		GameState.last_settle_unix = now_unix
		SaveSystem.save_now(true)
		return
	_apply_report(report)
	GameState.last_settle_unix = now_unix
	SaveSystem.save_now(true)
	EventBus.idle_settled.emit(report)
	_show_settle_dialog(report)


func _apply_report(r: Dictionary) -> void:
	GameState.add_currency(&"spirit_stones", int(r.get("spirit_stones", 0)))
	GameState.add_currency(&"insights", int(r.get("insights", 0)))
	GameState.add_pollution(int(r.get("pollution", 0)))
	var sanity_regen: int = int(r.get("sanity_regen", 0))
	if sanity_regen > 0:
		GameState.set_sanity(GameState.sanity + sanity_regen)


func _show_settle_dialog(r: Dictionary) -> void:
	var elapsed: int = int(r.get("elapsed_sec", 0))
	var eff_h: float = float(r.get("effective_hours", 0.0))
	var h := elapsed / 3600
	var m := (elapsed % 3600) / 60
	var lines: Array[String] = []
	lines.append("[闭关归来]  离线 %d 小时 %d 分钟" % [h, m])
	lines.append("有效结算时长：%.2f h%s" % [
		eff_h,
		"  (含每日首次 +20%)" if bool(r.get("daily_bonus_applied", false)) else "",
	])
	lines.append("")
	lines.append("· 灵石  +%d" % int(r.get("spirit_stones", 0)))
	lines.append("· 见闻  +%d" % int(r.get("insights", 0)))
	lines.append("· 修为  +%d  (待 M4 接入境界系统)" % int(r.get("xp", 0)))
	lines.append("")
	lines.append("· 污染  +%d" % int(r.get("pollution", 0)))
	var sanity_regen: int = int(r.get("sanity_regen", 0))
	if sanity_regen > 0:
		lines.append("· 道心  +%d" % sanity_regen)
	if eff_h <= 0.001:
		lines.append("")
		lines.append("（间隔太短，几乎无产出。试试关掉游戏几分钟再回来。）")
	settle_dialog.dialog_text = "\n".join(lines)
	settle_dialog.popup_centered()


func _on_enter_tower() -> void:
	get_tree().change_scene_to_file("res://scenes/tower.tscn")


func _on_forge() -> void:
	get_tree().change_scene_to_file("res://scenes/forge.tscn")


func _on_cultivate() -> void:
	get_tree().change_scene_to_file("res://scenes/cultivation.tscn")


func _on_quick_idle() -> void:
	## 调试用：把 last_settle_unix 倒拨 1 小时，立刻看一次结算
	GameState.last_settle_unix -= 3600
	SaveSystem.save_now(true)
	_run_idle_settlement()


func _todo(name: String) -> void:
	settle_dialog.dialog_text = "[%s]\n\n该模块在后续里程碑实装：\n  · 修炼 → M1 已用离线结算代替\n  · 锻造 → M3\n  · 序列 → M4\n  · 怪谈 → M5" % name
	settle_dialog.popup_centered()
