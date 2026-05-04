class_name MainQuestPanel
extends Control
## 主线追踪面板：章节标 + 碎片进度 + 已解锁碎片列表 + 线索 hint。
## HUD 「☯ 老铁身世」按钮触发，ESC 关闭。

const HINTS_BY_FRAGMENT: Array[String] = [
	"传闻老铁年轻时曾在城南落剑，从此再不提那一战。",
	"你常在他打盹时看见他的影子比他多一只手——但只是看见。",
	"街坊说，三年前的那场暴雨夜，铺子里来过一个谁也看不见的客人。",
	"老铁的炉火，在出秘品时偶尔会自顾自地熄灭一瞬。",
	"案台抽屉最深处，有一封从未拆开的回帖。",
	"打更人路过铺前，会在你不注意时多瞥一眼炉口。",
	"客人留下的灰里，偶尔混着一缕青烟，方向不定。",
	"城北那座古塔的砖缝里，听说也藏着一颗星。",
	"老铁的师承，谱中无人提起；他的剑，也从无落款。",
	"曾有怪客献上过一柄断剑——它的另一半，在你这。",
	"七谱之外的第八谱，在最早被烧的那本古籍里。",
	"老铁不敢看镜子。",
	"店中所有反噬产出的「灰」，集起来也许能炼出别的东西。",
	"门外候客，究竟是客还是…",
	"——",
]

@onready var _chapter_label: Label = $Frame/VBox/ChapterLabel
@onready var _progress_label: Label = $Frame/VBox/ProgressLabel
@onready var _hint_label: Label = $Frame/VBox/HintLabel
@onready var _list: ItemList = $Frame/VBox/Scroll/FragmentList
@onready var _body_label: Label = $Frame/VBox/BodyLabel
@onready var _close_btn: Button = $Frame/VBox/CloseButton

var _fragment_ids: Array[String] = []


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_btn.pressed.connect(_on_close)
	_list.item_selected.connect(_on_fragment_selected)


func open() -> void:
	visible = true
	_refresh()


func _on_close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	# 章节
	_chapter_label.text = "—— %s ——" % StoryChapters.current_title()
	# 进度
	var unlocked: int = WeirdCodex.unlocked_fragments
	var fp: int = WeirdCodex.count()
	var next_th: int = WeirdCodex.next_threshold()
	if next_th < 0:
		_progress_label.text = "身份碎片 %d / 15 · 已收齐" % unlocked
	else:
		_progress_label.text = "身份碎片 %d / 15 · 当前 %d，下一段需 %d 个 fingerprint" % [unlocked, fp, next_th]
	# 线索
	var hint_idx: int = clampi(unlocked, 0, HINTS_BY_FRAGMENT.size() - 1)
	_hint_label.text = "线索：%s" % HINTS_BY_FRAGMENT[hint_idx]
	# 已解锁碎片列表
	_fragment_ids.clear()
	_list.clear()
	for i in unlocked:
		var fid: String = "if_%02d" % (i + 1)
		_fragment_ids.append(fid)
		_list.add_item("第 %d 段碎片" % (i + 1))
	if unlocked == 0:
		_body_label.text = "（尚无碎片，多接客 / 多开炉 / 多入谱以收集 fingerprint）"
	else:
		_show_fragment(0)


func _on_fragment_selected(idx: int) -> void:
	_show_fragment(idx)


func _show_fragment(idx: int) -> void:
	if idx < 0 or idx >= _fragment_ids.size():
		_body_label.text = ""
		return
	var card: NarrativeCard = DataRegistry.get_resource(&"narrative", StringName(_fragment_ids[idx])) as NarrativeCard
	if card == null:
		_body_label.text = "（碎片 %s 未找到）" % _fragment_ids[idx]
		return
	_body_label.text = card.body
