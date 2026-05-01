extends Node
## 全局事件总线（Autoload 单例）。
## UI 与逻辑解耦的唯一通道。任何跨模块通信优先走这里，避免 get_node 耦合。
## 命名规范：信号名用过去时（forge_finished 而非 finish_forge）。

# ── 货币 / 声誉 / 材料 ────────────────────────
signal currency_changed(kind: StringName, value: int)
signal reputation_changed(value: int)
signal materials_changed(material_id: StringName, value: int)

# ── 装备 ──────────────────────────────────────
signal gear_equipped(slot: StringName, gear_id: StringName)
signal loot_dropped(items: Array)

# ── 时间线 ────────────────────────────────────
signal time_advanced(new_unix: int, delta_sec: int)   # 每次时间推进
signal hour_passed(shichen_index: int)                # 跨时辰（=2小时）触发，参数：当前时辰索引 0..11

# ── 铺子 ──────────────────────────────────────
signal shop_upgraded(area: StringName, new_level: int)  # 区域升级（炉房/柜台/阁楼/后院）
signal shop_rule_changed(slot_index: int)               # 铺规槽变更

# ── 锻造 ──────────────────────────────────────
signal forge_started(recipe_id: StringName)
signal forge_finished(gear_inst: Resource, was_qiao_cheng: bool, was_backlash: bool)

# ── 客人 / 派发 ────────────────────────────────
signal customer_arrived(customer_inst: Resource)
signal equipment_lent(customer_id: StringName, gear_inst: Resource)
signal equipment_returned(customer_id: StringName, gear_inst: Resource, outcome: StringName)
signal customer_left(customer_id: StringName, was_refused: bool)

# ── 器谱 / 共鸣 ────────────────────────────────
signal star_lit(gupu_id: StringName, su_id: StringName, gear_inst: Resource)
signal resonance_activated(gupu_id: StringName, pattern_id: StringName)
signal codex_changed(gupu_id: StringName)   # 切换当前古谱

# ── 知识 / 学习（spec §7.3）─────────────────────
signal traits_learned(trait_ids: Array)  # 一次学到的 trait id 列表（仅新学到的）

# ── 诡器谱 + 暗线（spec §5.5 / §9.4）─────────────
signal weird_codex_recorded(fingerprint: StringName, total: int)
signal identity_fragment_unlocked(fragment_index: int, total_fingerprints: int)

# ── 星轨笔 + 自连图案（spec §5.4）────────────────
signal star_brushes_changed(value: int)
signal player_line_drawn(gupu_id: StringName, su_a: StringName, su_b: StringName)
signal pattern_resonance_activated(pattern_id: StringName)

# ── 存档 ──────────────────────────────────────
signal save_loaded()
signal save_written()
