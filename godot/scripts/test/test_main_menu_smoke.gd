extends Node
## Main menu / 字体 / shader / dial 加载烟测

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_main_menu_loadable()
	_test_theme_has_default_font()
	_test_paper_grain_shader_exists()
	_test_shichen_dial_loadable_in_shop()
	_test_main_scene_is_main_menu()
	print("\n========== test_main_menu_smoke ==========")
	print("PASS: %d  FAIL: %d" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _ok(m: String) -> void: _passed += 1; print("[PASS] " + m)
func _bad(m: String) -> void: _failed += 1; print("[FAIL] " + m)
func _assert(c: bool, m: String) -> void:
	if c:
		_ok(m)
	else:
		_bad(m)


func _test_main_menu_loadable() -> void:
	var pkd: PackedScene = load("res://scenes/main_menu.tscn")
	_assert(pkd != null, "main_menu.tscn loadable")
	var inst: Node = pkd.instantiate()
	_assert(inst != null, "instantiable")
	_assert(inst.has_node("Layout/Panel/VBox/StartButton"), "has StartButton")
	_assert(inst.has_node("Layout/Panel/VBox/QuitButton"), "has QuitButton")
	inst.queue_free()


func _test_theme_has_default_font() -> void:
	var theme: Theme = load("res://data/theme/main_theme.tres")
	_assert(theme != null, "theme loadable")
	if theme != null:
		_assert(theme.default_font != null, "theme has default_font")


func _test_paper_grain_shader_exists() -> void:
	var sh: Shader = load("res://scripts/shaders/paper_grain.gdshader")
	_assert(sh != null, "paper_grain.gdshader loadable")


func _test_shichen_dial_loadable_in_shop() -> void:
	var pkd: PackedScene = load("res://scenes/shop.tscn")
	var inst: Node = pkd.instantiate()
	_assert(inst.has_node("HUD/HudFrame/VBox/TimeRow/ShichenDial"), "shop has ShichenDial in HUD")
	inst.queue_free()


func _test_main_scene_is_main_menu() -> void:
	# 通过 ProjectSettings 验证
	var main: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_assert(main.ends_with("main_menu.tscn"), "main_scene = main_menu.tscn (got %s)" % main)
