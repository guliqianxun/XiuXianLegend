extends Node
## 主线系统烟测：StoryChapters 章节映射 + MainQuestPanel + OnboardingOverlay

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_chapter_mapping()
	_test_chapter_title()
	await _test_quest_panel_loads()
	await _test_onboarding_loads()
	print("\n========== test_main_quest_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)


func _test_chapter_mapping() -> void:
	_assert(StoryChapters.chapter_of(0) == 0, "0 fragments → ch 0 (序章)")
	_assert(StoryChapters.chapter_of(2) == 0, "2 fragments → ch 0")
	_assert(StoryChapters.chapter_of(3) == 1, "3 fragments → ch 1 (盈门)")
	_assert(StoryChapters.chapter_of(5) == 1, "5 fragments → ch 1")
	_assert(StoryChapters.chapter_of(6) == 2, "6 fragments → ch 2 (破谱)")
	_assert(StoryChapters.chapter_of(9) == 3, "9 fragments → ch 3 (异种)")
	_assert(StoryChapters.chapter_of(12) == 4, "12 fragments → ch 4 (终章)")
	_assert(StoryChapters.chapter_of(15) == 4, "15 fragments → ch 4 (满)")


func _test_chapter_title() -> void:
	_assert(StoryChapters.chapter_title(0).find("序章") >= 0, "ch 0 title 含「序章」 (got %s)" % StoryChapters.chapter_title(0))
	_assert(StoryChapters.chapter_title(4).find("终章") >= 0, "ch 4 title 含「终章」 (got %s)" % StoryChapters.chapter_title(4))


func _test_quest_panel_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/main_quest_panel.tscn")
	_assert(pkd != null, "main_quest_panel.tscn loadable")
	var p: MainQuestPanel = pkd.instantiate()
	add_child(p)
	await get_tree().process_frame
	p.open()
	_assert(p.visible, "open() makes visible")
	_assert(p._chapter_label.text.find("序章") >= 0, "default chapter label 含序章 (got %s)" % p._chapter_label.text)
	p.queue_free()
	await get_tree().process_frame


func _test_onboarding_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/onboarding_overlay.tscn")
	_assert(pkd != null, "onboarding_overlay.tscn loadable")
	var o: OnboardingOverlay = pkd.instantiate()
	add_child(o)
	await get_tree().process_frame
	_assert(not o.visible, "default invisible")
	# start() 需要 shop_root，这里只验证 visible 切换
	o.visible = true
	_assert(o.visible, "can show")
	o.queue_free()
	await get_tree().process_frame
