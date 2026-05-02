extends Node
## 存档系统（Autoload 单例）。
## - JSON 文本存档。
## - 带版本号 + migration 链。
## - 写入 5 秒最小间隔限流。

const SAVE_PATH := "user://save_main.json"
const SAVE_VERSION := 11
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
		"shop_rules": ShopRules.to_dict(),
		"faction_state": FactionState.to_dict(),
		"narrative_library": NarrativeLibrary.to_dict(),
		"weird_codex": WeirdCodex.to_dict(),
		"event_log": EventLog.to_dict(),
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
	var sr: Dictionary = parsed.get("shop_rules", {})
	ShopRules.from_dict(sr)
	var fs: Dictionary = parsed.get("faction_state", {})
	FactionState.from_dict(fs)
	var nl: Dictionary = parsed.get("narrative_library", {})
	NarrativeLibrary.from_dict(nl)
	var wc: Dictionary = parsed.get("weird_codex", {})
	WeirdCodex.from_dict(wc)
	var el: Dictionary = parsed.get("event_log", {})
	EventLog.from_dict(el)
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
			3:
				payload = _migrate_v3_to_v4(payload)
			4:
				payload = _migrate_v4_to_v5(payload)
			5:
				payload = _migrate_v5_to_v6(payload)
			6:
				payload = _migrate_v6_to_v7(payload)
			7:
				payload = _migrate_v7_to_v8(payload)
			8:
				payload = _migrate_v8_to_v9(payload)
			9:
				payload = _migrate_v9_to_v10(payload)
			10:
				payload = _migrate_v10_to_v11(payload)
			_:
				push_warning("save: no migration from v%d; aborting" % v)
				return payload  # 中途未知版本：保留原 version，不再前进
		v += 1
	payload["version"] = SAVE_VERSION
	return payload


const MATERIAL_ID_RENAME_V11 := {
	"iron": "tie",
	"zhusha": "zhu_sha",
	"yellow_paper": "huang_zhi",
	"bone": "gu",
	"yi_zhong_liao": "yi",
}

## v10 → v11: 材料命名统一全拼音（materials 在 game_state 内）
func _migrate_v10_to_v11(p: Dictionary) -> Dictionary:
	var gs: Dictionary = p.get("game_state", {})
	var mats: Dictionary = gs.get("materials", {})
	var new_mats: Dictionary = {}
	for k in mats:
		var new_k: String = MATERIAL_ID_RENAME_V11.get(String(k), String(k))
		new_mats[new_k] = mats[k]
	gs["materials"] = new_mats
	p["game_state"] = gs
	p["version"] = 11
	return p


## v9 → v10: payload 顶层加 event_log（默认空）
func _migrate_v9_to_v10(payload: Dictionary) -> Dictionary:
	if not payload.has("event_log"):
		payload["event_log"] = {"entries": []}
	return payload


## v8 → v9: GameState 加 star_brushes / activated_patterns；CodexState player_lines（默认空 dict）
func _migrate_v8_to_v9(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	if not gs.has("star_brushes"):
		gs["star_brushes"] = 0
	if not gs.has("activated_patterns"):
		gs["activated_patterns"] = []
	payload["game_state"] = gs
	var cs: Dictionary = payload.get("codex_state", {})
	if not cs.has("player_lines"):
		cs["player_lines"] = {}
	payload["codex_state"] = cs
	return payload


## v7 → v8: payload 顶层加 weird_codex（fingerprints + unlocked_fragments）
func _migrate_v7_to_v8(payload: Dictionary) -> Dictionary:
	if not payload.has("weird_codex"):
		payload["weird_codex"] = {"fingerprints": [], "unlocked_fragments": 0}
	return payload


## v6 → v7: payload 顶层加 faction_state + narrative_library（启动时 autoload 重算 → 默认空兼容）
func _migrate_v6_to_v7(payload: Dictionary) -> Dictionary:
	if not payload.has("faction_state"):
		payload["faction_state"] = {}
	if not payload.has("narrative_library"):
		payload["narrative_library"] = {"seen_first_visit": []}
	return payload


## v5 → v6: GameState 加 active_resonances（默认空 []）
func _migrate_v5_to_v6(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	if not gs.has("active_resonances"):
		gs["active_resonances"] = []
	payload["game_state"] = gs
	return payload


## v4 → v5: GameState 加 learned_traits（默认空 []）
func _migrate_v4_to_v5(payload: Dictionary) -> Dictionary:
	var gs: Dictionary = payload.get("game_state", {})
	if not gs.has("learned_traits"):
		gs["learned_traits"] = []
	payload["game_state"] = gs
	return payload


## v3 → v4: payload 顶层加 shop_rules（默认 enabled=["refuse_all"]）
func _migrate_v3_to_v4(payload: Dictionary) -> Dictionary:
	if not payload.has("shop_rules"):
		payload["shop_rules"] = {"enabled": ["refuse_all"]}
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
