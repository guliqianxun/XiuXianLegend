# 我在诡异修仙造兵器

一款 **诡异修仙世界 · 铁匠铺挂机** 的单机游戏。

> 你不记得自己是谁，但你的手记得怎么打铁。
> 每一炉都是一次开奖；每一位推门而入的访客都是一个盲盒；
> 每一件造出来的兵器都会带着自己的履历回到你的器谱里——
> 直到某一天，你从那本谱子上认出了自己。

## 玩法支柱

- **挂机时间线**：在线/离线产出一致，离线时系统按"铺规"自动跑铺子
- **造装备**：选配方、投料、捶打、出炉——凡 / 灵 / 法 / 禁 / 秘 五品质，附带巧成 + 反噬
- **28 宿器谱**：装备落入预设星位，凑齐古谱 → 共鸣，玩家自连支脉 → 隐藏图案
- **问道门客**：神秘访客求借兵器，常 / 罕 / 怪三档，怪客身份是盲盒
- **诡异叙事**：每段离线由系统拼出"老铁的小本"——你不在的时候，铺子也活着

## 技术栈

- **引擎**：Godot 4.6（GDScript）
- **架构**：Resource 数据驱动 + Autoload 服务 + 信号事件总线 + MVVM
- **运行时**：纯单机，零网络依赖（选配 Steam Cloud 同步）

## 目录

```
godot/                                                            Godot 项目（主体）
docs/superpowers/specs/2026-04-30-weird-cultivation-smith-design.md  ← 当前生效设计
docs/superpowers/plans/                                           ← 逐里程碑实现计划
DESIGN.md                                                         旧设计文档（已重定位）
```

## 开始

1. 安装 [Godot 4.6](https://godotengine.org/) 稳定版（本机验证路径：`D:\soft\GODOT\Godot_v4.6.2-stable_win64.exe`）
2. 启动 Godot，导入 `godot/project.godot`
3. F5 运行（当前 N5a 阶段：铺子 + 炉房开炉 + 阁楼查谱 + 柜台接客 → 借/回信循环 + 启动离线日记）

## 当前进度

- ✅ N0：旧战斗/塔/赛季/卡牌系统归档到 `_deprecated/`
- ✅ N1：铺子主场景 + TimeLine/ShopState Autoload + 5 个数据 Resource 类骨架
- ✅ N2：锻造 v2（火候窗口 + 巧成 + 反噬 + 5 档出炉动画 + 3 个开局配方）
- ✅ N3：器谱 v1（青龙宿 28 颗星 + 入谱公式 + 阁楼查谱）
- ✅ N4：问道门客 v1（3 客人 + 借/拒/回信 5 档结果 + 装备 status 流转 + 履历追加）
- ✅ N5a：离线积分 + 铁炉小本（OfflineSimulator + DiaryScreen + 老铁打盹 24/72h 衰减）
- ✅ N6：怪客盲盒身份 + 打听识破（disguise_name + 50 灵石揭真）
- ✅ N5b：铺规槽 + 怪客离线攻破（ShopRules 4 预设 + 后院立规 + 伪装放行 → diary 攻破事件）
- ✅ N5c：攻破学习 → 解锁精确铺规（trait 库 + 打听/攻破学 trait + RulesScreen 分组 + has_trait condition）
- ✅ Polish：出炉/反噬/攻破/打听 反馈包（程序合成 sfx + 屏震 + tween）
- ✅ Content Pack 01：客人 3→10，配方 3→7（覆盖 6 slot），trait 6→10，spawner 60/30/10
- ✅ 程序化生成器：CustomerGenerator + RecipeGenerator（70% 生成 + 30% 剧情池），id 全 snake_case (i18n key) / display_name 中文
- ✅ 怪客诡异副标题：24 + 7 条 eerie_note 池，伪装时藏 / 打听后现 / 攻破时附在 diary
- ✅ N7 共鸣与古谱 v1：7 张古谱 + 28 星全亮激活 + 全 7 张 buff 接齐 + UI tabs 切换
- ✅ N8 世面与叙事 v1：6 势力 + 周轮换 surge bias + 30 张手写卡 + NarrativeOverlay UI
- ✅ 诡器谱 + 暗线碎片：WeirdCodex (fingerprint 集合 + 15 段阶梯阈值) + 15 张手写身份碎片
- ✅ 词缀系统 v1：26 主题词缀（5 通用 + 18 path × 3 + 3 诡缀）+ ForgeSystem 主词缀 roll + fingerprint 升级三元组（910 装备空间）
- ✅ N7b 星轨笔 + 自连：GREAT_DEED 10% 留赠 / 共鸣 +4 / 选 2 星画线 / 7 张古谱各 1 个 secret pattern → buff（巧成 +5% 等）
- ✅ 炉房 UI 重构 v1：控制台日志风（3 段：TopBar 配方+材料 / LogFlow 时辰染色日志 / BottomBar chips+开炉），TimingWindow 嵌入 LogFlow 顶
- ✅ 材料经济 v1：MaterialData 资源化 + 命名统一全拼音（iron→tie / zhusha→zhu_sha 等，save v10→v11 自动迁移） + TopBar 采办 modal（5 种可购材料 × 灵石定价） + 客人 GREAT_DEED 必给诡材 / OK_RETURN 30% 给铁 + 投料偏向词缀（系数 0.1 温和默认，可调）
- ⏳ N6-N10：见 spec §13.2

> 延后到 N5：怪客盲盒身份/打听/深夜节奏/离线访客/名望影响。
> 延后到 N7：自连/星轨笔/共鸣/多古谱切换。

## 测试

跑全部测试（27 个测试场景，N0-N4 共 417 个断言）：

```bash
for t in test_game_state test_save_migration test_save_with_shopstate \
         test_recipe_data test_customer_data test_gupu_data test_narrative_card \
         test_time_line test_shop_state \
         test_gear_instance_extras test_materials_inventory test_recipe_data_loads \
         test_forge_quality_roll test_forge_qiao_cheng test_forge_backlash \
         test_forge_one_full test_timing_window \
         test_codex_placement test_codex_state \
         test_customer_data_loads test_return_resolver test_encounter_state test_customer_spawner \
         playtest_n1_smoke playtest_n2_smoke playtest_n3_smoke playtest_n4_smoke; do
  "D:/soft/GODOT/Godot_v4.6.2-stable_win64_console.exe" --headless --path godot "res://scenes/test/$t.tscn"
done
```
