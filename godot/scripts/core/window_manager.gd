extends Node
## 全局窗口管理 Autoload。
## - F11 切换 fullscreen / windowed
## - Alt+Enter 同效（PC 习惯）

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		var is_f11: bool = key.keycode == KEY_F11
		var is_alt_enter: bool = key.keycode == KEY_ENTER and key.alt_pressed
		if is_f11 or is_alt_enter:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var current: int = DisplayServer.window_get_mode()
	if current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
