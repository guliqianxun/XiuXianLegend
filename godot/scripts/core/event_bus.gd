extends Node
## 全局事件总线（Autoload 单例）。
## UI 与逻辑解耦的唯一通道。任何跨模块通信优先走这里，避免 get_node 耦合。
## 命名规范：信号名用过去时（card_played 而非 play_card）。

# ── 玩家与挂机 ─────────────────────────────────
signal idle_settled(reward: Dictionary)            # 离线结算完成
signal currency_changed(kind: StringName, value: int)
signal pollution_changed(value: int, max_value: int)
signal sanity_changed(value: int, max_value: int)

# ── 战斗 ──────────────────────────────────────
signal combat_started(encounter_id: StringName)
signal combat_ended(victory: bool, loot: Array)
signal card_played(card_id: StringName, source, target)
signal unit_damaged(unit, amount: int, kind: StringName)
signal unit_died(unit)

# ── 装备 / 锻造 ────────────────────────────────
signal gear_equipped(slot: StringName, gear_id: StringName)
signal gear_reforged(gear_id: StringName)
signal loot_dropped(items: Array)

# ── 序列 / 突破 ────────────────────────────────
signal sequence_advanced(path: StringName, new_rank: int)
signal ritual_failed(path: StringName, reason: StringName)

# ── 事件 / 怪谈 ────────────────────────────────
signal anomaly_triggered(anomaly_id: StringName)
signal anomaly_resolved(anomaly_id: StringName, choice_id: StringName)

# ── 存档 / 赛季 ────────────────────────────────
signal save_loaded()
signal save_written()
signal season_rolled(season_id: StringName)
