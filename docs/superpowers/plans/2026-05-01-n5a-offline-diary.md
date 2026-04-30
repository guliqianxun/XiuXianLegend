# N5a 实施计划：离线积分 + 铁炉小本

> 起草日期：2026-05-01
> 分支：`refactor/n5a-timeline`
> 依赖：N0-N4 已合入 master
> 后续：N5b 铺规 / N6 怪客识破

## 目标

落地 spec §7「铺规与时间线」的**爽点核心链路**——玩家关闭游戏一段时间后，再开看到「这段时间发生过什么」。铺规 DSL 留给 N5b，N5a 用**默认行为**（自动开炉、自动拒客）跑通离线事件流。

不在 N5a 内：
- 铺规槽 / 接客规 / 开炉规 / 应料规
- 怪客识破 / 铺规攻破
- 倍速调节 UI（内部支持但不暴露）

## 设计要点

### 时间模型
- **现实秒 vs 游戏秒**：默认 `GAME_SECONDS_PER_REAL_SEC = 60`（在线 1 分钟现实 = 1 时辰游戏）。可调，测试用 1。
- TimeLine 仍持有 `_now_unix`（游戏时戳，UTC）。
- 替换现 `_process` 中 `int(delta * 1.0)` 的 1:1 hack：改用累加器 `_real_accum_sec`，到 1 现实秒发 advance_seconds(GAME_SECONDS_PER_REAL_SEC)。

### 离线积分流程
启动 → SaveSystem.load_or_init → 取 `GameState.last_settle_unix` → 算 `raw_offline = real_now - last_settle_unix`。

- raw ≤ 0：无离线，不跑 simulator。
- raw > 0：调 `OfflineSimulator.simulate(raw_offline)` →
  - 用 `TimeLine.effective_offline_seconds` 算有效秒
  - 推进 `TimeLine` 到 `last_settle_unix + effective`
  - 期间按节奏 emit 事件（不真改 inventory，全部走数据收集到 `OfflineReport`）
  - **本里程碑简化**：simulate 内部不真的写 GameState.inventory，只把"假装发生过的事"写成 diary 条目。这是有意的——避免离线产出和铺规未实装时 imbalance；N5b 加铺规后再让模拟器真改 inventory。
- simulate 结束 → 把 diary 条目存入 `GameState.offline_diary_pending`（list）→ save_now → 通知 UI 弹 DiaryScreen。

### Diary 数据模型
```gdscript
# OfflineEvent (Resource 或 Dictionary，v1 用 Dictionary 简化)
{
  "unix": int,                 # 事件发生的游戏时戳
  "shichen": int,              # 0..11
  "kind": StringName,          # &"forge" / &"customer_arrive" / &"customer_refuse" / &"sleep"
  "detail": String,            # "开炉一次，出灵·剑 Q2" / "雾丘野修来访，被拒" / "老铁趴在炉边睡过去了"
}
```
- 只持久化 list，不需要类型化资源
- DiaryScreen 关闭后清空 pending

### 老铁打盹叙事
simulate 入口检测 `raw > FULL_THRESHOLD_SEC`，在 diary 头部插一条 sleep 事件：
- 24-72h：「老铁趴在炉边睡过去了，错过了一些事。」
- >72h：「灶火早就凉了。老铁不知道睡了多久。」

### 节奏（v1 默认）
- 锻造事件：每 2 时辰 1 次（4h 游戏时间），需要至少 4 铁、4 金箔
- 客人事件：每 1-2 时辰 1 次，泊松式简化（用 RNG seed = last_settle_unix）

## 文件改动

### 新增
- `godot/scripts/core/offline_simulator.gd`（Autoload）
- `godot/scripts/ui/diary_screen.gd`
- `godot/scenes/ui/diary_screen.tscn`
- `godot/scripts/ui/diary_screen.gd.uid`
- `godot/scripts/core/offline_simulator.gd.uid`
- 测试：`scenes/test/test_offline_simulator.tscn` + `scripts/test/test_offline_simulator.gd`
- 测试：`scenes/test/test_diary_persistence.tscn` + script
- 烟测：`scenes/test/playtest_n5a_smoke.tscn` + script

### 修改
- `godot/scripts/core/time_line.gd`：新增 `GAME_SECONDS_PER_REAL_SEC` const 和 `tick(delta_real_sec)` 函数；移除外部 `advance_seconds` 由 _process 调用的耦合
- `godot/scripts/core/game_state.gd`：新增 `offline_diary_pending: Array`，序列化进 to_dict/from_dict
- `godot/scripts/core/save_system.gd`：SAVE_VERSION 升 v3，加 `_migrate_v2_to_v3`（仅添加 diary_pending=[]）
- `godot/scripts/ui/shop_screen.gd`：移除 `_process` 中的 1:1 hack，改为 `TimeLine.tick(delta)`；启动时检查 diary_pending → open DiaryScreen
- `godot/scenes/shop.tscn`：加 `DiaryScreen` instance
- `godot/project.godot`：注册 `OfflineSimulator` autoload

## 任务分解

| T# | 任务 | 文件 | 测试 |
|---|---|---|---|
| T1 | TimeLine 倍速 + tick(delta_real_sec) | time_line.gd | test_time_line.gd 加 tick 用例 |
| T2 | GameState.offline_diary_pending 字段 + 序列化 | game_state.gd | test_game_state.gd 加 diary 用例 |
| T3 | SaveSystem v3 migration | save_system.gd | test_save_migration.gd 加 v2→v3 |
| T4 | OfflineSimulator autoload + simulate 主流程 | offline_simulator.gd | test_offline_simulator.gd |
| T5 | OfflineSimulator 锻造事件 | offline_simulator.gd | 在 test_offline_simulator 内 |
| T6 | OfflineSimulator 客人事件 | offline_simulator.gd | 在 test_offline_simulator 内 |
| T7 | OfflineSimulator 老铁打盹叙事 | offline_simulator.gd | 在 test_offline_simulator 内 |
| T8 | DiaryScreen UI + 滚动列表 | diary_screen.gd/.tscn | scene 可加载/实例化 |
| T9 | shop_screen 集成（启动检 diary + tick） | shop_screen.gd, shop.tscn | playtest_n5a_smoke 验证 |
| T10 | 烟测 + README 进度更新 | playtest_n5a_smoke.gd | 全 PASS |

## 测试覆盖

- `test_time_line.gd`：tick 累加、advance_seconds 时辰边界、effective_offline_seconds 已有边界
- `test_offline_simulator.gd`：
  - 0 秒离线返回空 diary
  - 6h 离线产生若干事件
  - 25h 离线带打盹卡
  - 75h 离线 tier2 衰减
  - simulate 不修改 GameState.inventory（隔离）
- `test_diary_persistence.gd`：to_dict/from_dict round-trip
- `test_save_migration.gd`：v2 payload → v3 加 diary_pending=[]
- `playtest_n5a_smoke.gd`：场景加载 + DiaryScreen 实例化 + offline_simulator 在 -10h 注入 last_settle 后启动能产生 diary

## 完成标准（DoD）

1. 所有新 / 改动测试 PASS
2. 现有 N0-N4 测试 PASS（无回归）
3. 手动验证：F5 → 退出 → 改 last_settle_unix 倒退 6h → F5 → DiaryScreen 弹出有内容
4. README 进度行加 "N5a 离线日记 ✅"
5. PR/branch merge to master
