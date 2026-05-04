# godot/scripts/test/test_scroll_card_smoke.gd
extends Node

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _test_scene_loads()
	await _test_set_status_updates_label()
	await _test_emits_opened_on_click()
	await _test_mount_status_widget_hides_label()
	print("\n========== test_scroll_card_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(m): _passed += 1; print("[PASS] " + m)
func _bad(m): _failed += 1; print("[FAIL] " + m)
func _assert(c, m): (_ok if c else _bad).call(m)

func _make_card() -> ScrollCard:
	var pkd: PackedScene = load("res://scenes/ui/scroll_card.tscn")
	var card: ScrollCard = pkd.instantiate()
	add_child(card)
	return card

func _test_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/scroll_card.tscn")
	_assert(pkd != null, "scroll_card.tscn loadable")
	var card: ScrollCard = pkd.instantiate()
	_assert(card != null, "instantiable")
	card.queue_free()
	await get_tree().process_frame

func _test_set_status_updates_label() -> void:
	var card := _make_card()
	await get_tree().process_frame
	card.set_status("开炉 3 · 反噬 1")
	_assert(card._status_label.text == "开炉 3 · 反噬 1", "status text set (got %s)" % card._status_label.text)
	card.queue_free()
	await get_tree().process_frame

func _test_emits_opened_on_click() -> void:
	var card := _make_card()
	await get_tree().process_frame
	var emitted := [false]
	card.opened.connect(func() -> void: emitted[0] = true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card._on_gui_input(ev)
	_assert(emitted[0], "opened emitted on click")
	card.queue_free()
	await get_tree().process_frame

func _test_mount_status_widget_hides_label() -> void:
	var card := _make_card()
	await get_tree().process_frame
	var w := Control.new()
	card.mount_status_widget(w)
	_assert(not card._status_label.visible, "status label hidden after mount")
	_assert(card._status_area.get_child_count() == 1, "widget added to status area")
	card.queue_free()
	await get_tree().process_frame
