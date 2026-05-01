extends Node
## 诡异副标题：生成器注入 + UI 显示规则

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_field_default_empty()
	_test_weird_high_eerie_rate()
	_test_rare_low_eerie_rate()
	_test_regular_no_eerie()
	_test_eerie_notes_from_pool()
	await _test_panel_hides_eerie_when_disguised()
	await _test_panel_shows_eerie_when_unmasked()
	print("\n========== test_eerie_notes ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_field_default_empty() -> void:
	var c := CustomerData.new()
	_assert(c.eerie_note == "", "default eerie_note empty")


func _test_weird_high_eerie_rate() -> void:
	# 怪客 80% 应有 eerie_note；100 抽样应 ≥ 65 有
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var with_note := 0
	for i in 100:
		var c := CustomerGenerator.generate(rng, 2, i)
		if not c.eerie_note.is_empty():
			with_note += 1
	_assert(with_note >= 65, "weird tier eerie rate: %d/100 (≥65)" % with_note)


func _test_rare_low_eerie_rate() -> void:
	# 罕客 25% 应有；100 抽样应 10..40 之间
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var with_note := 0
	for i in 100:
		var c := CustomerGenerator.generate(rng, 1, i)
		if not c.eerie_note.is_empty():
			with_note += 1
	_assert(with_note >= 10 and with_note <= 40, "rare tier eerie rate: %d/100 (10..40)" % with_note)


func _test_regular_no_eerie() -> void:
	# 常客绝不应有 eerie_note
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 50:
		var c := CustomerGenerator.generate(rng, 0, i)
		_assert(c.eerie_note.is_empty(), "regular i=%d no eerie" % i)


func _test_eerie_notes_from_pool() -> void:
	# 生成的 eerie_note 都应在两个池子之一
	var pool: Dictionary = {}
	for s in CustomerGenerator.EERIE_NOTES_WEIRD:
		pool[s] = true
	for s in CustomerGenerator.EERIE_NOTES_RARE:
		pool[s] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 60:
		var c := CustomerGenerator.generate(rng, 1 + (i % 2), i)
		if not c.eerie_note.is_empty():
			_assert(pool.has(c.eerie_note), "eerie_note '%s' from pool" % c.eerie_note)


func _test_panel_hides_eerie_when_disguised() -> void:
	# 伪装客 unmasked=false 时不应显示 eerie_note
	var c := CustomerData.new()
	c.id = &"_test_disguised"
	c.display_name = "御重医"
	c.tier = 2
	c.disguise_name = "云游郎中"
	c.disguise_tier = 1
	c.eerie_note = "他的手是反的。"
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame
	var req := CustomerRequest.new()
	req.customer_id = c.id
	req.customer_data = c
	req.unmasked = false  # 伪装中
	panel.show_request(req)
	_assert(not panel._eerie_label.visible, "eerie label hidden when disguised")
	panel.queue_free()


func _test_panel_shows_eerie_when_unmasked() -> void:
	# 打听后 unmasked=true 应显示 eerie_note
	var c := CustomerData.new()
	c.id = &"_test_unmasked"
	c.display_name = "御重医"
	c.tier = 2
	c.disguise_name = "云游郎中"
	c.disguise_tier = 1
	c.eerie_note = "他的手是反的。"
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame
	var req := CustomerRequest.new()
	req.customer_id = c.id
	req.customer_data = c
	req.unmasked = true  # 已打听
	panel.show_request(req)
	_assert(panel._eerie_label.visible, "eerie label visible after unmasked")
	_assert(panel._eerie_label.text.contains("手是反的"), "eerie label shows note text")
	panel.queue_free()
