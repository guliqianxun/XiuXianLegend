extends Node
## 存档系统（Autoload 单例）。
## - JSON 文本存档。
## - 带版本号 + migration 链。
## - 写入 5 秒最小间隔限流。

const SAVE_PATH := "user://save_main.json"
const SAVE_VERSION := 2
const WRITE_COOLDOWN_SEC := 5.0

var _last_write_msec: int = -10000


func save_now(force: bool = false) -> bool:
	var now_msec := Time.get_ticks_msec()
	if not force and now_msec - _last_write_msec < int(WRITE_COOLDOWN_SEC * 1000.0):
		return false
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	_last_write_msec = now_msec
	EventBus.save_written.emit()
	return true


func load_or_init() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_new_game()
		EventBus.save_loaded.emit()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save: corrupted, reinit")
		_init_new_game()
		EventBus.save_loaded.emit()
		return
	parsed = migrate(parsed)
	var gs: Dictionary = parsed.get("game_state", {})
	GameState.from_dict(gs)
	EventBus.save_loaded.emit()


func _init_new_game() -> void:
	GameState.last_settle_unix = int(Time.get_unix_time_from_system())


## 公开 wrapper，供测试与外部调用使用
func migrate(payload: Dictionary) -> Dictionary:
	var v := int(payload.get("version", 1))
	while v < SAVE_VERSION:
		match v:
			1:
				payload = _migrate_v1_to_v2(payload)
			_:
				push_warning("save: no migration from v%d" % v)
				break
		v += 1
	payload["version"] = SAVE_VERSION
	return payload


## v1 → v2: 删除战斗/塔/赛季字段；保留 spirit_stones/insights/last_settle_unix/equipped/inventory；
## 新增 reputation 默认 0
func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	for bad in ["pollution", "pollution_cap", "sanity", "sanity_cap",
			"sequence_ranks", "season_id", "season_started_unix",
			"owned_cards", "tower_floor", "tower_max_reached"]:
		gs.erase(bad)
	if not gs.has("reputation"):
		gs["reputation"] = 0
	payload["game_state"] = gs
	return payload
