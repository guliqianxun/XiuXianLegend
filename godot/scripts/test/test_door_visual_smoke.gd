extends Node
## DoorVisual 烟测：scene 加载 + 状态切换不崩 + label 文本符合预期

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_scene_loads()
	await _test_idle_initial_state()
	await _test_flash_arrival_changes_label()
	await _test_flash_failed_then_returns_idle()
	print("\n========== test_door_visual_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void: (_ok if c else _bad).call(m)


func _make_dv() -> DoorVisual:
	var pkd: PackedScene = load("res://scenes/ui/door_visual.tscn")
	var dv: DoorVisual = pkd.instantiate()
	add_child(dv)
	return dv


func _test_scene_loads() -> void:
	var pkd: PackedScene = load("res://scenes/ui/door_visual.tscn")
	_assert(pkd != null, "door_visual.tscn loadable")
	var dv: DoorVisual = pkd.instantiate()
	_assert(dv != null, "instantiable")
	_assert(dv.has_node("Curtain"), "has Curtain")
	_assert(dv.has_node("Curtain/Label"), "has Curtain/Label")
	dv.queue_free()
	await get_tree().process_frame


func _test_idle_initial_state() -> void:
	# 确保 EncounterState.pending_request 是 null（默认）
	EncounterState.pending_request = null
	var dv := _make_dv()
	await get_tree().process_frame
	var label: Label = dv.get_node("Curtain/Label")
	_assert(label.text == DoorVisual.TEXT_IDLE, "idle text=门外静寂 (got %s)" % label.text)
	dv.queue_free()
	await get_tree().process_frame


func _test_flash_arrival_changes_label() -> void:
	EncounterState.pending_request = null
	var dv := _make_dv()
	await get_tree().process_frame
	dv.flash_arrival()
	var label: Label = dv.get_node("Curtain/Label")
	_assert(label.text == DoorVisual.TEXT_ARRIVED, "arrival text=来客了 (got %s)" % label.text)
	dv.queue_free()
	await get_tree().process_frame


func _test_flash_failed_then_returns_idle() -> void:
	EncounterState.pending_request = null
	var dv := _make_dv()
	await get_tree().process_frame
	dv.flash_failed()
	var label: Label = dv.get_node("Curtain/Label")
	_assert(label.text == DoorVisual.TEXT_FAIL, "fail text=门外无人迹 (got %s)" % label.text)
	# 等 0.7s 让 tween 跑完回到 idle
	await get_tree().create_timer(0.75).timeout
	_assert(label.text == DoorVisual.TEXT_IDLE, "after 0.75s back to idle (got %s)" % label.text)
	dv.queue_free()
	await get_tree().process_frame
