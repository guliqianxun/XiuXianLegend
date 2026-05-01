extends Node
## 生成器集成烟测：spawn 走双路径 + UI 能消费生成的客人

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_spawner_yields_generator_customers()
	_test_spawner_yields_story_customers()
	await _test_panel_handles_generated_customer()
	print("\n========== playtest_generators_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_spawner_yields_generator_customers() -> void:
	# 200 spawn 应有相当比例 id 以 "gen:" 开头（70% 生成器）
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var gen_count := 0
	var story_count := 0
	for i in 200:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i)
		if req == null: continue
		if String(req.customer_id).begins_with("gen:"):
			gen_count += 1
		else:
			story_count += 1
	_assert(gen_count >= 100, "≥50%% generator (got %d/200)" % gen_count)
	_assert(story_count >= 30, "≥15%% story (got %d/200)" % story_count)


func _test_spawner_yields_story_customers() -> void:
	# 验证手写 .tres 仍能被抽中（剧情池路径）
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var saw_story := false
	var known_ids: Dictionary = {}
	for cid in DataRegistry.ids_of(&"customer"):
		known_ids[cid] = true
	for i in 500:
		var req := CustomerSpawner.spawn_one(rng, 1700000000 + i)
		if req == null: continue
		if known_ids.has(req.customer_id):
			saw_story = true
			break
	_assert(saw_story, "spawner reaches story pool customers")


func _test_panel_handles_generated_customer() -> void:
	# 实例化 panel 喂一个生成的客人，应正常渲染
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := CustomerGenerator.generate(rng, 1, 1)
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame
	var req := CustomerRequest.new()
	req.customer_id = c.id
	req.customer_data = c
	req.unmasked = true
	req.payment = c.base_payment
	panel.show_request(req)
	_assert(panel.visible, "panel shows generated customer")
	_assert(panel._name_label.text.contains(c.display_name),
		"panel name label contains generated name '%s'" % c.display_name)
	panel.queue_free()
