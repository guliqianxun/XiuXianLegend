extends Node
## 存档系统（Autoload 单例）。
## - JSON 文本存档。
## - 带版本号 + migration 链。
## - 写入 5 秒最小间隔限流。

const SAVE_PATH := "user://save_main.json"
const SAVE_VERSION := 3
const WRITE_COOLDOWN_SEC := 5.0

var _last_write_msec: int = -10000


func save_now(force: bool = false) -> bool:
	var now_msec := Time.get_ticks_msec()
	if not force and now_msec - _last_write_msec < int(WRITE_COOLDOWN_SEC * 1000.0):
		return false
	# 写盘前刷 last_settle_unix 为现实时戳，下次启动用这个算离线时长
	GameState.last_settle_unix = int(Time.get_unix_time_from_system())
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
		"shop_state": ShopState.to_dict(),
		"codex_state": CodexState.to_dict(),
		"encounter_state": EncounterState.to_dict(),
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
	var ss: Dictionary = parsed.get("shop_state", {})
	ShopState.from_dict(ss)
	var cs: Dictionary = parsed.get("codex_state", {})
	CodexState.from_dict(cs)
	var es: Dictionary = parsed.get("encounter_state", {})
	EncounterState.from_dict(es)
	EventBus.save_loaded.emit()


func _init_new_game() -> void:
	GameState.last_settle_unix = int(Time.get_unix_time_from_system())


## 公开 wrapper，供测试与外部调用使用。
## 注意：直接对外暴露 schema 升级路径，签名变更视为破坏性变更。
## 注意：会原地修改 payload；如需保留原档，请先 .duplicate(true)。
func migrate(payload: Dictionary) -> Dictionary:
	var v := int(payload.get("version", 1))
	# 未来版本档案：不动数据，不改 version，记日志返回
	if v > SAVE_VERSION:
		push_warning("save: payload version v%d is newer than SAVE_VERSION v%d; returned as-is" % [v, SAVE_VERSION])
		return payload
	while v < SAVE_VERSION:
		match v:
			1:
				payload = _migrate_v1_to_v2(payload)
			2:
				payload = _migrate_v2_to_v3(payload)
			_:
				push_warning("save: no migration from v%d; aborting" % v)
				return payload  # 中途未知版本：保留原 version，不再前进
		v += 1
	payload["version"] = SAVE_VERSION
	return payload


## v2 → v3: GameState 加 offline_diary_pending 字段（默认空 []）
func _migrate_v2_to_v3(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	if not gs.has("offline_diary_pending"):
		gs["offline_diary_pending"] = []
	payload["game_state"] = gs
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
