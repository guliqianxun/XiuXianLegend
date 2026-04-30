extends Node
## 怪客盲盒身份 + 打听识破：CustomerData / Spawner / Panel 三层验证

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_customer_data_disguise_fields()
	_test_meng_mian_ke_has_disguise()
	_test_spawner_unmasked_for_regular()
	_test_spawner_masked_for_disguised()
	await _test_panel_inspect_unmasks()
	await _test_panel_inspect_blocked_when_poor()
	print("\n========== test_disguise ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_customer_data_disguise_fields() -> void:
	var c := CustomerData.new()
	_assert(c.disguise_name == "", "default disguise_name empty")
	_assert(c.disguise_tier == -1, "default disguise_tier = -1")


func _test_meng_mian_ke_has_disguise() -> void:
	var c := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	_assert(c != null, "meng_mian_ke loadable")
	if c != null:
		_assert(not c.disguise_name.is_empty(), "meng_mian_ke has disguise_name")
		_assert(c.disguise_tier == 0, "meng_mian_ke disguised as tier 0 (REGULAR)")
		_assert(c.tier == CustomerData.Tier.WEIRD, "meng_mian_ke true tier = WEIRD")


func _test_spawner_unmasked_for_regular() -> void:
	# 强制找一个 disguise_name 空的客人，验证 spawn 后 unmasked = true
	for cid in DataRegistry.ids_of(&"customer"):
		var c := DataRegistry.get_resource(&"customer", cid) as CustomerData
		if c == null or not c.disguise_name.is_empty():
			continue
		# 模拟 spawner 输出
		var req := CustomerRequest.new()
		req.customer_id = c.id
		req.unmasked = c.disguise_name.is_empty()
		_assert(req.unmasked, "regular customer %s spawn unmasked = true" % cid)
		return
	_bad("no plain (non-disguised) customer to test")


func _test_spawner_masked_for_disguised() -> void:
	var c := DataRegistry.get_resource(&"customer", &"meng_mian_ke") as CustomerData
	if c == null:
		_bad("meng_mian_ke missing")
		return
	var req := CustomerRequest.new()
	req.customer_id = c.id
	req.unmasked = c.disguise_name.is_empty()
	_assert(not req.unmasked, "disguised meng_mian_ke spawn unmasked = false")


func _test_panel_inspect_unmasks() -> void:
	# 实例化 panel，喂一个伪装请求，调 _on_inspect → 应扣灵石 + req.unmasked = true
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame  # 让 _ready 跑

	GameState.spirit_stones = 1000
	var req := CustomerRequest.new()
	req.customer_id = &"meng_mian_ke"
	req.unmasked = false
	req.payment = 600
	panel.show_request(req)
	_assert(not req.unmasked, "before inspect: still masked")
	panel._on_inspect()
	_assert(req.unmasked, "after inspect: unmasked")
	_assert(GameState.spirit_stones == 1000 - CustomerArrivalPanel.INSPECT_COST,
		"spirit_stones deducted by %d" % CustomerArrivalPanel.INSPECT_COST)
	panel.queue_free()


func _test_panel_inspect_blocked_when_poor() -> void:
	# 灵石不够时打听不应改 unmasked
	var pkd: PackedScene = load("res://scenes/ui/customer_arrival_panel.tscn")
	var panel: CustomerArrivalPanel = pkd.instantiate()
	add_child(panel)
	await get_tree().process_frame

	GameState.spirit_stones = 10  # 不够 50
	var req := CustomerRequest.new()
	req.customer_id = &"meng_mian_ke"
	req.unmasked = false
	panel.show_request(req)
	panel._on_inspect()
	_assert(not req.unmasked, "broke: inspect blocked, still masked")
	_assert(GameState.spirit_stones == 10, "spirit_stones unchanged when poor")
	panel.queue_free()
